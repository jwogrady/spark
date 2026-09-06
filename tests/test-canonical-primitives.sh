#!/usr/bin/env bash
# Behavioral suite for the canonical GitHub-graph and identity primitives (the
# v0.23 cleanup's duplicate-semantics consolidation): the runtime reads the
# native dependency graph, a parent's sub-issues and the repository's owner/name
# through ONE reader each, and every consumer applies its own filter to the same
# evidence. The contract each primitive carries — paginated, fail-closed, a fixed
# row shape — is asserted here against a recording gh stub, and the consumers'
# filters are driven over identical rows so the answers cannot drift apart again.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # source-guarded: loads the primitives and gov_collect without dispatching

repo="$WORK/repo"
make_repo "$repo"
cd "$repo"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}
lacks() { case "$3" in *"$2"*) bad "$1 — output contains '$2'" ;; *) ok ;; esac; }

# A recording gh: every invocation's arguments land in $CALLS; answers come from
# the scenario directory, one file per endpoint, so a test states exactly what
# GitHub "said" and nothing else.
STUB="$WORK/stub"; mkdir -p "$STUB"
CALLS="$WORK/gh-calls"; SC="$WORK/scenario"; mkdir -p "$SC"
cat > "$STUB/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
case "$*" in
  "auth status"*) exit 0 ;;
  "repo view --json nameWithOwner"*)
    [ -f "$SC/nwo.partial" ] && { cat "$SC/nwo.partial"; exit 1; }
    [ -f "$SC/nwo" ] || exit 1; cat "$SC/nwo" ;;
  *"dependencies/blocked_by"*)
    n="$(printf '%s' "$*" | sed -E 's|.*/issues/([0-9]+)/dependencies/blocked_by.*|\1|')"
    # ".partial": a first page answered, then a later page failed — rows on
    # stdout AND a non-zero exit, which is what gh --paginate does.
    [ -f "$SC/blocked_by.$n.partial" ] && { cat "$SC/blocked_by.$n.partial"; exit 1; }
    [ -f "$SC/blocked_by.$n" ] || exit 1; cat "$SC/blocked_by.$n" ;;
  *"/sub_issues"*)
    n="$(printf '%s' "$*" | sed -E 's|.*/issues/([0-9]+)/sub_issues.*|\1|')"
    [ -f "$SC/sub_issues.$n.partial" ] && { cat "$SC/sub_issues.$n.partial"; exit 1; }
    [ -f "$SC/sub_issues.$n" ] || exit 1; cat "$SC/sub_issues.$n" ;;
  *"issues?state=open"*) [ -f "$SC/issues" ] || exit 1; cat "$SC/issues" ;;
  *) exit 1 ;;
esac
GH
chmod +x "$STUB/gh"
export CALLS SC
PATH="$STUB:$PATH"
reset() { rm -rf "$SC"; mkdir -p "$SC"; : > "$CALLS"; }

# ======================== the primitives' contracts ========================
reset
printf '12\topen\to/self\n13\tclosed\tother/elsewhere\n' > "$SC/blocked_by.7"
out="$(gh_blocked_by 7)"; rc=$?
assert_rc "gh_blocked_by succeeds when the graph answers" 0 "$rc"
assert_eq "one row per blocker: number, state, owning repository" \
  "$(printf '12\topen\to/self\n13\tclosed\tother/elsewhere')" "$out"
assert_contains "the dependency graph is read paginated (a long list is never its first page)" \
  "--paginate" "$(grep 'issues/7/dependencies/blocked_by' "$CALLS")"
assert_eq "exactly one gh call answers one issue" "1" "$(grep -c 'dependencies/blocked_by' "$CALLS")"

reset
rc=0; out="$(gh_blocked_by 8)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "an unreadable graph fails the read (exit non-zero), never 'no prerequisite'"
assert_eq "and emits no rows to mistake for evidence" "" "$out"

# malformed rows: the primitive validates shape and vocabulary before emitting anything, so a consumer
# that keeps only "open" blockers can never read a malformed row as "not blocking"
for row in '12\tOPEN\to/self' '12\t\to/self' '12\tdraft\to/self' 'twelve\topen\to/self' '0\topen\to/self' '12\topen' '12\topen\to/self\textra' '12\topen\tnot a repo' '12\topen\tacme' '12\topen\t.' '12\topen\towner/.' '12\topen\t./name' '12\topen\ta/b/c' '12\topen\t/name' '12\topen\towner/'; do
  reset; printf '13\topen\to/self\n%b\n' "$row" > "$SC/blocked_by.7"
  rc=0; out="$(gh_blocked_by 7)" || rc=$?
  [ "$rc" -ne 0 ] && ok || bad "a malformed blocker row ($row) fails the whole read — a bad repository shape would otherwise read as foreign and drop a local edge"
  assert_eq "and nothing is emitted, not even the well-formed sibling row" "" "$out"
done
reset; printf '12\topen\t\n' > "$SC/blocked_by.7"
out="$(gh_blocked_by 7)" && ok || bad "control: an empty repository column (GitHub omitted it) is a valid row consumers treat as unknown"
assert_eq "and is emitted as read" "$(printf '12\topen\t')" "$out"
for row in 'abc' '0' '-1' '1 2'; do
  reset; printf '101\n%s\n' "$row" > "$SC/sub_issues.100"
  rc=0; out="$(plan_sub_issues 100)" || rc=$?
  [ "$rc" -ne 0 ] && ok || bad "a malformed sub-issue row ($row) fails the whole read"
  assert_eq "and nothing is emitted" "" "$out"
done

reset
printf '12\topen\to/self\n' > "$SC/blocked_by.9.partial"
rc=0; out="$(gh_blocked_by 9)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "a first page followed by a failed page fails the read"
assert_eq "and the rows already received are NOT emitted (buffered: all pages or nothing)" "" "$out"

reset
printf 'o/self\n' > "$SC/nwo"
out="$(di_repo_nwo)"; rc=$?
assert_rc "di_repo_nwo answers from gh" 0 "$rc"
assert_eq "with the owner/name exactly as GitHub spells it" "o/self" "$out"
reset
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "an unanswered identity fails the read rather than guessing"
assert_eq "and prints nothing" "" "$out"
reset; printf 'o/self\n' > "$SC/nwo.partial"
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "output beside a failure is a failed identity read"
assert_eq "and the leaked text is not printed" "" "$out"
reset; : > "$SC/nwo"
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "a successful but EMPTY answer is a failed identity read, never an identity"
assert_eq "and prints nothing" "" "$out"
reset; printf 'not a repository at all\n' > "$SC/nwo"
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "an answer that is not owner/name is a failed identity read"
reset; printf 'a/b/c\n' > "$SC/nwo"
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "three path segments are not an owner/name"
for bad_nwo in 'owner/.' './repo' '../repo' 'owner/..' '.' '/repo' 'owner/' 'o/self extra'; do
  reset; printf '%s\n' "$bad_nwo" > "$SC/nwo"
  rc=0; out="$(di_repo_nwo)" || rc=$?
  [ "$rc" -ne 0 ] && ok || bad "a malformed identity ($bad_nwo) is a failed read — non-empty but wrong would make every local blocker read as foreign"
  assert_eq "and nothing is printed" "" "$out"
done
reset; printf 'my.org/my-repo.js\n' > "$SC/nwo"
out="$(di_repo_nwo)" && ok || bad "control: dots inside real segments are a valid owner/name"
assert_eq "and are printed as read" "my.org/my-repo.js" "$out"

reset
printf '101\n999\n102\n' > "$SC/sub_issues.100"
out="$(plan_sub_issues 100)"; rc=$?
assert_rc "plan_sub_issues answers from gh" 0 "$rc"
assert_eq "in GitHub's own order, numbers only" "$(printf '101\n999\n102')" "$out"
assert_contains "sub-issues are read paginated" "--paginate" "$(grep 'issues/100/sub_issues' "$CALLS")"
reset
rc=0; out="$(plan_sub_issues 100)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "an unreadable sub-issue list fails the read"
reset
printf '101\n' > "$SC/sub_issues.100.partial"
rc=0; out="$(plan_sub_issues 100)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "a partial sub-issue read fails"
assert_eq "and emits nothing" "" "$out"

# ======================== the same rows, each consumer's own filter ========================
# governance validate builds the prerequisite graph from gh_blocked_by rows: OPEN,
# same-repository edges only, so a foreign #2 never fuses with the local #2.
model="$(resolve_governance)"
dep_rows() { gov_collect "$model" "$repo" 2>/dev/null | awk -F'\t' '$1 == "dependency"'; }
# Empty milestone on purpose: the default shape of an unmilestoned issue, whose
# blocked-by count the previous `read`-based loop collapsed into the milestone
# field (tab is IFS whitespace), so the issue was silently never probed.
issues_fixture() { printf 'issue\t1\t\t1\nissue\t2\t\t1\n'; }

reset; issues_fixture > "$SC/issues"; printf 'o/self\n' > "$SC/nwo"
printf '2\topen\to/self\n' > "$SC/blocked_by.1"; printf '1\topen\to/self\n' > "$SC/blocked_by.2"
out="$(dep_rows)"
assert_contains "two open same-repo blockers that point at each other are a cycle" "cannot be started" "$out"
[ "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "="' | wc -l | tr -d ' ')" = "0" ] && ok || bad "a cyclic graph is never reported correct"

reset; issues_fixture > "$SC/issues"; printf 'o/self\n' > "$SC/nwo"
printf '2\topen\tother/elsewhere\n' > "$SC/blocked_by.1"; printf '1\topen\tother/elsewhere\n' > "$SC/blocked_by.2"
out="$(dep_rows)"
lacks "the same numbers in ANOTHER repository fabricate no cycle" "cannot be started" "$out"
assert_eq "and the local graph is reported clean" "=" "$(printf '%s\n' "$out" | awk -F'\t' '{print $2; exit}')"

reset; issues_fixture > "$SC/issues"; printf 'o/self\n' > "$SC/nwo"
printf '2\tclosed\to/self\n' > "$SC/blocked_by.1"; printf '1\tclosed\to/self\n' > "$SC/blocked_by.2"
out="$(dep_rows)"
lacks "closed blockers are satisfied, not edges" "cannot be started" "$out"
assert_eq "so the graph is clean" "=" "$(printf '%s\n' "$out" | awk -F'\t' '{print $2; exit}')"

reset; issues_fixture > "$SC/issues"; printf 'o/self\n' > "$SC/nwo"
printf '2\topen\to/self\n' > "$SC/blocked_by.1"   # issue 2's probe has no answer
out="$(dep_rows)"
assert_eq "one failed probe makes the whole surface not assessed" "?" "$(printf '%s\n' "$out" | awk -F'\t' '{print $2; exit}')"
assert_contains "and says why" "probe failed" "$out"

reset; printf 'issue\t1\tv1.0\t1\nissue\t2\tv1.0\t1\n' > "$SC/issues"; printf 'o/self\n' > "$SC/nwo"
printf '2\topen\to/self\n' > "$SC/blocked_by.1"; printf '1\topen\to/self\n' > "$SC/blocked_by.2"
assert_contains "a milestoned issue is probed the same way" "cannot be started" "$(dep_rows)"

reset; issues_fixture > "$SC/issues"   # own identity unknown: edges are KEPT rather than dropped
printf '2\topen\to/self\n' > "$SC/blocked_by.1"; printf '1\topen\to/self\n' > "$SC/blocked_by.2"
out="$(dep_rows)"
assert_contains "an unknown own identity keeps the evidence (cycle still caught)" "cannot be started" "$out"

# plan verify asks a different question of the same rows — a blocker with the
# declared number AND this repository, whatever its state; a foreign #12 is not
# the local #12 (its coverage suite, tests/test-plan-verify-coverage.sh, drives
# the foreign-number, unknown-repository and unreadable-identity cases through
# the binary). `next` counts open blockers in any repository
# (tests/test-next-governance-gate.sh). Here: the consumers read one row shape.
reset; printf '12\topen\to/self\n12\topen\tother/elsewhere\n' > "$SC/blocked_by.7"
out="$(gh_blocked_by 7 | awk -F'\t' 'NF && $2 == "open"' | wc -l | tr -d ' ')"
assert_eq "next's open count counts every open blocker, whichever repository" "2" "$out"
out="$(gh_blocked_by 7 | awk -F'\t' -v me="o/self" 'NF && $1 == 12 && $3 == me' | wc -l | tr -d ' ')"
assert_eq "verify's match needs number AND repository: one of the two same-numbered rows is local" "1" "$out"

finish "canonical primitives"
