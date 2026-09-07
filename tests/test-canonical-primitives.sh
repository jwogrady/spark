#!/usr/bin/env bash
# Behavioral suite for the canonical GitHub-graph and identity primitives (the
# v0.23 cleanup's duplicate-semantics consolidation): the runtime reads the
# native dependency graph, a parent's sub-issues and the repository's owner/name
# through ONE reader each, and every consumer applies its own filter to the same
# evidence. The contract each primitive carries — paginated, fail-closed, a fixed
# row shape — is asserted here against a recording gh stub, and the consumers'
# filters are driven over identical rows so the answers cannot drift apart again.
#
# The stub answers with the JSON GitHub returns and applies the caller's own
# --jq to it (gh_stub_prelude), so the production jq programs are exercised
# rather than assumed: a stub that printed pre-shaped rows would agree with any
# jq, including a broken one. Only shapes no jq can produce (a row with too few
# or too many columns) are fed raw, and say so.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # source-guarded: loads the primitives and gov_collect without dispatching

repo="$WORK/repo"
make_repo "$repo"
cd "$repo"

lacks() { case "$3" in *"$2"*) bad "$1 — output contains '$2'" ;; *) ok ;; esac; }

# A recording gh: every invocation's arguments land in $CALLS; answers come from
# the scenario directory as JSON, one file per endpoint, shaped by the --jq the
# CALLER passed — so a test states exactly what GitHub "said" and nothing else.
STUB="$WORK/stub"; mkdir -p "$STUB"
CALLS="$WORK/gh-calls"; SC="$WORK/scenario"; mkdir -p "$SC"
stub_gh "$STUB/gh" <<'GH'
printf '%s\n' "$*" >> "$CALLS"
# answer <name>: <name>.raw is fed verbatim (a transport fault no jq produces);
# <name>.partial.json is answered through the caller's jq and then FAILS — a
# first page delivered, a later page lost, which is what gh --paginate does;
# <name>.json is the normal answer; nothing at all is an unreadable endpoint.
# The normal answer exits with jq's own status, as gh does: a program jq
# rejects is a failed call, never a silent success.
answer() {
  [ -f "$SC/$1.raw" ] && { cat "$SC/$1.raw"; exit 0; }
  [ -f "$SC/$1.partial.json" ] && { answer_json "$(cat "$SC/$1.partial.json")"; exit 1; }
  [ -f "$SC/$1.json" ] || exit 1
  answer_json "$(cat "$SC/$1.json")"
}
case "$*" in
  "auth status"*) exit 0 ;;
  "repo view --json nameWithOwner"*) answer nwo ;;
  *"dependencies/blocked_by"*) answer "blocked_by.$(printf '%s' "$*" | sed -E 's|.*/issues/([0-9]+)/dependencies/blocked_by.*|\1|')" ;;
  *"/sub_issues"*) answer "sub_issues.$(printf '%s' "$*" | sed -E 's|.*/issues/([0-9]+)/sub_issues.*|\1|')" ;;
  *"issues?state=open"*) answer issues ;;
  *) exit 1 ;;
esac
GH
export CALLS SC
PATH="$STUB:$PATH"
reset() { rm -rf "$SC"; mkdir -p "$SC"; : > "$CALLS"; }

# Scenario builders: the JSON GitHub returns for each endpoint.
#   bl <issue> [partial] <number|state|repo>...   blockers; number is emitted as given (quote it for a string)
#   si <parent> [partial] <number>...              sub-issues
#   nwo <owner/name>                               the repository node; nwo_fail <text> answers then fails
#   iss <number|milestone|count>...                the open-issue list (milestone and count may be empty)
bl() {
  local n="$1"; shift; local suffix="json"; [ "${1:-}" = "partial" ] && { suffix="partial.json"; shift; }
  local out="" r num st rp
  for r in "$@"; do IFS='|' read -r num st rp <<<"$r"; out="$out{\"number\":$num,\"state\":\"$st\",\"repository\":{\"full_name\":\"$rp\"}},"; done
  printf '[%s]' "${out%,}" > "$SC/blocked_by.$n.$suffix"
}
si() {
  local n="$1"; shift; local suffix="json"; [ "${1:-}" = "partial" ] && { suffix="partial.json"; shift; }
  local out="" x; for x in "$@"; do out="$out{\"number\":$x},"; done
  printf '[%s]' "${out%,}" > "$SC/sub_issues.$n.$suffix"
}
nwo() { jq -cn --arg v "$1" '{nameWithOwner: $v}' > "$SC/nwo.json"; }
nwo_fail() { jq -cn --arg v "$1" '{nameWithOwner: $v}' > "$SC/nwo.partial.json"; }
iss() {
  local out="" r num ms cnt
  for r in "$@"; do
    IFS='|' read -r num ms cnt <<<"$r"
    out="$out{\"number\":$num,\"pull_request\":null,\"labels\":[],\"milestone\":$([ -n "$ms" ] && printf '{"title":"%s"}' "$ms" || printf null)"
    case "$cnt" in '') ;; *[!0-9]*) out="$out,\"issue_dependencies_summary\":{\"blocked_by\":\"$cnt\"}" ;; *) out="$out,\"issue_dependencies_summary\":{\"blocked_by\":$cnt}" ;; esac
    out="$out},"
  done
  printf '[%s]' "${out%,}" > "$SC/issues.json"
}

# ======================== the primitives' contracts ========================
reset
bl 7 "12|open|o/self" "13|closed|other/elsewhere"
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
# that keeps only "open" blockers can never read a malformed row as "not blocking". These values reach
# the reader through the production jq exactly as GitHub's JSON would carry them.
for row in '12|OPEN|o/self' '12||o/self' '12|draft|o/self' '"twelve"|open|o/self' '0|open|o/self' '12|open|not a repo' '12|open|acme' '12|open|.' '12|open|owner/.' '12|open|./name' '12|open|a/b/c' '12|open|/name' '12|open|owner/'; do
  reset; bl 7 "13|open|o/self" "$row"
  rc=0; out="$(gh_blocked_by 7)" || rc=$?
  [ "$rc" -ne 0 ] && ok || bad "a malformed blocker row ($row) fails the whole read — a bad repository shape would otherwise read as foreign and drop a local edge"
  assert_eq "and nothing is emitted, not even the well-formed sibling row" "" "$out"
done
# shapes no jq program can produce — a transport fault delivering too few or too many columns — are fed raw
for row in '12\topen' '12\topen\to/self\textra'; do
  reset; printf '13\topen\to/self\n%b\n' "$row" > "$SC/blocked_by.7.raw"
  rc=0; out="$(gh_blocked_by 7)" || rc=$?
  [ "$rc" -ne 0 ] && ok || bad "a malformed blocker row ($row) fails the whole read — a bad repository shape would otherwise read as foreign and drop a local edge"
  assert_eq "and nothing is emitted, not even the well-formed sibling row" "" "$out"
done
reset; bl 7 "12|open|"
out="$(gh_blocked_by 7)" && ok || bad "control: an empty repository column (GitHub omitted it) is a valid row consumers treat as unknown"
assert_eq "and is emitted as read" "$(printf '12\topen\t')" "$out"
for row in '"abc"' '0' '-1' '"1 2"'; do
  reset; si 100 101 "$row"
  rc=0; out="$(plan_sub_issues 100)" || rc=$?
  [ "$rc" -ne 0 ] && ok || bad "a malformed sub-issue row ($row) fails the whole read"
  assert_eq "and nothing is emitted" "" "$out"
done

reset
bl 9 partial "12|open|o/self"
rc=0; out="$(gh_blocked_by 9)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "a first page followed by a failed page fails the read"
assert_eq "and the rows already received are NOT emitted (buffered: all pages or nothing)" "" "$out"

reset
nwo o/self
out="$(di_repo_nwo)"; rc=$?
assert_rc "di_repo_nwo answers from gh" 0 "$rc"
assert_eq "with the owner/name exactly as GitHub spells it" "o/self" "$out"
reset
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "an unanswered identity fails the read rather than guessing"
assert_eq "and prints nothing" "" "$out"
reset; nwo_fail o/self
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "output beside a failure is a failed identity read"
assert_eq "and the leaked text is not printed" "" "$out"
reset; nwo ""
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "a successful but EMPTY answer is a failed identity read, never an identity"
assert_eq "and prints nothing" "" "$out"
reset; nwo 'not a repository at all'
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "an answer that is not owner/name is a failed identity read"
reset; nwo 'a/b/c'
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "three path segments are not an owner/name"
for bad_nwo in 'owner/.' './repo' '../repo' 'owner/..' '.' '/repo' 'owner/' 'o/self extra'; do
  reset; nwo "$bad_nwo"
  rc=0; out="$(di_repo_nwo)" || rc=$?
  [ "$rc" -ne 0 ] && ok || bad "a malformed identity ($bad_nwo) is a failed read — non-empty but wrong would make every local blocker read as foreign"
  assert_eq "and nothing is printed" "" "$out"
done
reset; nwo "$(printf 'o/self\no/other')"
rc=0; out="$(di_repo_nwo)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "two valid identities are not ONE identity — a multi-line answer is a failed read"
assert_eq "and nothing is printed" "" "$out"
reset; nwo 'my.org/my-repo.js'
out="$(di_repo_nwo)" && ok || bad "control: dots inside real segments are a valid owner/name"
assert_eq "and are printed as read" "my.org/my-repo.js" "$out"

reset
si 100 101 999 102
out="$(plan_sub_issues 100)"; rc=$?
assert_rc "plan_sub_issues answers from gh" 0 "$rc"
assert_eq "in GitHub's own order, numbers only" "$(printf '101\n999\n102')" "$out"
assert_contains "sub-issues are read paginated" "--paginate" "$(grep 'issues/100/sub_issues' "$CALLS")"
reset
rc=0; out="$(plan_sub_issues 100)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "an unreadable sub-issue list fails the read"
reset
si 100 partial 101
rc=0; out="$(plan_sub_issues 100)" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "a partial sub-issue read fails"
assert_eq "and emits nothing" "" "$out"

# ======================== the same rows, each consumer's own filter ========================
# governance validate builds the prerequisite graph from gh_blocked_by rows: OPEN,
# same-repository edges only, so a foreign #2 never fuses with the local #2.
model="$(resolve_governance)"
dep_rows() { gov_collect "$model" "$repo" 2>/dev/null | awk -F'\t' '$1 == "dependency"'; }
# No milestone on purpose: the default shape of an unmilestoned issue, whose
# blocked-by count the previous `read`-based loop collapsed into the milestone
# field (tab is IFS whitespace), so the issue was silently never probed. The
# real issue-list jq shapes these rows now, so that collapse would show here.
issues_fixture() { iss "1||1" "2||1"; }

reset; issues_fixture; nwo o/self
bl 1 "2|open|o/self"; bl 2 "1|open|o/self"
out="$(dep_rows)"
assert_contains "two open same-repo blockers that point at each other are a cycle" "cannot be started" "$out"
[ "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "="' | wc -l | tr -d ' ')" = "0" ] && ok || bad "a cyclic graph is never reported correct"

reset; issues_fixture; nwo o/self
bl 1 "2|open|other/elsewhere"; bl 2 "1|open|other/elsewhere"
out="$(dep_rows)"
lacks "the same numbers in ANOTHER repository fabricate no cycle" "cannot be started" "$out"
assert_eq "and the local graph is reported clean" "=" "$(printf '%s\n' "$out" | awk -F'\t' '{print $2; exit}')"

reset; issues_fixture; nwo o/self
bl 1 "2|closed|o/self"; bl 2 "1|closed|o/self"
out="$(dep_rows)"
lacks "closed blockers are satisfied, not edges" "cannot be started" "$out"
assert_eq "so the graph is clean" "=" "$(printf '%s\n' "$out" | awk -F'\t' '{print $2; exit}')"

reset; issues_fixture; nwo o/self
bl 1 "2|open|o/self"   # issue 2's probe has no answer
out="$(dep_rows)"
assert_eq "one failed probe makes the whole surface not assessed" "?" "$(printf '%s\n' "$out" | awk -F'\t' '{print $2; exit}')"
assert_contains "and says why" "probe failed" "$out"

reset; iss "1|v1.0|1" "2|v1.0|1"; nwo o/self
bl 1 "2|open|o/self"; bl 2 "1|open|o/self"
assert_contains "a milestoned issue is probed the same way" "cannot be started" "$(dep_rows)"
# the endpoint's summary count is a SECOND source and never gates the canonical reader: a zero, empty or
# malformed count with real blockers behind it must still surface the cycle
for cnt in 0 '' x; do
  reset; iss "1||$cnt" "2||$cnt"; nwo o/self
  bl 1 "2|open|o/self"; bl 2 "1|open|o/self"
  assert_contains "a summary count of '$cnt' does not skip the probe — the cycle is still caught" "cannot be started" "$(dep_rows)"
done
reset; iss "1||0"; nwo o/self
out="$(dep_rows)"
assert_eq "an issue whose graph cannot be read is not assessed even when the summary says zero" "?" "$(printf '%s\n' "$out" | awk -F'\t' '{print $2; exit}')"

reset; issues_fixture   # own identity unknown: edges are KEPT rather than dropped
bl 1 "2|open|o/self"; bl 2 "1|open|o/self"
out="$(dep_rows)"
assert_contains "an unknown own identity keeps the evidence (cycle still caught)" "cannot be started" "$out"

# plan verify asks a different question of the same rows — a blocker with the
# declared number AND this repository, whatever its state; a foreign #12 is not
# the local #12 (its coverage suite, tests/test-plan-verify-coverage.sh, drives
# the foreign-number, unknown-repository and unreadable-identity cases through
# the binary). `next` counts open blockers in any repository
# (tests/test-next-governance-gate.sh). Here: the consumers read one row shape.
reset; bl 7 "12|open|o/self" "12|open|other/elsewhere"
out="$(gh_blocked_by 7 | awk -F'\t' 'NF && $2 == "open"' | wc -l | tr -d ' ')"
assert_eq "next's open count counts every open blocker, whichever repository" "2" "$out"
out="$(gh_blocked_by 7 | awk -F'\t' -v me="o/self" 'NF && $1 == 12 && $3 == me' | wc -l | tr -d ' ')"
assert_eq "verify's match needs number AND repository: one of the two same-numbered rows is local" "1" "$out"

finish "canonical primitives"
