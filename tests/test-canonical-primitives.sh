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
  "repo view --json nameWithOwner"*) [ -f "$SC/nwo" ] || exit 1; cat "$SC/nwo" ;;
  *"dependencies/blocked_by"*)
    n="$(printf '%s' "$*" | sed -E 's|.*/issues/([0-9]+)/dependencies/blocked_by.*|\1|')"
    [ -f "$SC/blocked_by.$n" ] || exit 1; cat "$SC/blocked_by.$n" ;;
  *"/sub_issues"*)
    n="$(printf '%s' "$*" | sed -E 's|.*/issues/([0-9]+)/sub_issues.*|\1|')"
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

reset
printf 'o/self\n' > "$SC/nwo"
out="$(di_repo_nwo)"; rc=$?
assert_rc "di_repo_nwo answers from gh" 0 "$rc"
assert_eq "with the owner/name exactly as GitHub spells it" "o/self" "$out"
reset
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "an unanswered identity fails the read rather than guessing"
assert_eq "and prints nothing" "" "$out"

reset
printf '101\n999\n102\n' > "$SC/sub_issues.100"
out="$(plan_sub_issues 100)"; rc=$?
assert_rc "plan_sub_issues answers from gh" 0 "$rc"
assert_eq "in GitHub's own order, numbers only" "$(printf '101\n999\n102')" "$out"
assert_contains "sub-issues are read paginated" "--paginate" "$(grep 'issues/100/sub_issues' "$CALLS")"
reset
rc=0; out="$(plan_sub_issues 100)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "an unreadable sub-issue list fails the read"

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

# plan verify asks a different question of the same rows — membership by number,
# whatever the blocker's state — and its coverage suite (tests/test-plan-verify-coverage.sh)
# drives that through the binary; `next` counts open blockers in any repository
# (tests/test-next-governance-gate.sh). Here: the three consumers read one endpoint shape.
reset; printf '12\topen\to/self\n12\topen\to/self\n' > "$SC/blocked_by.7"
out="$(gh_blocked_by 7 | awk -F'\t' 'NF && $2 == "open"' | wc -l | tr -d ' ')"
assert_eq "next's open count is a count of rows, exactly what the primitive returned" "2" "$out"
out="$(gh_blocked_by 7 | awk -F'\t' 'NF { print $1 }' | grep -Fxc 12)"
assert_eq "plan verify's membership projection sees the number column" "2" "$out"

finish "canonical primitives"
