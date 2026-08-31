#!/usr/bin/env bash
# Behavioural suite for #628 — surface existing implementation PRs before work
# starts.
#
# v0.23 produced the same failure twice: the issue was known, an open PR already
# implemented it, and nothing surfaced that before a second branch was cut. The
# PR was mechanically discoverable the whole time. Nobody was asked to look.
#
# The properties that carry it, and the two ways a plausible implementation gets
# it wrong:
#
#   * a DECLARED closing reference (Closes/Fixes/Resolves #N) is strong evidence
#     and must be surfaced;
#   * a passing MENTION is not. The release PR lists every issue in its
#     changelog, so promoting mentions would report implementation in flight for
#     the entire milestone — noise that trains an operator to ignore the signal;
#   * two competing PRs are a decision, not a selection: reporting one would
#     quietly pick a winner;
#   * absence is only claimable after a COMPLETE read. A truncated list is
#     NOT ASSESSED, never "none found";
#   * discovery reads. It creates no branch, no PR, and mutates nothing.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "existing implementation discovery (#628)"
sandbox_init
make_repo "$WORK/proj"
cd "$WORK/proj"

mkdir -p "$WORK/bin"
export GH_PRS="$WORK/prs.tsv" GH_LOG="$WORK/gh.log" GH_FAIL=""
: > "$GH_PRS"; : > "$GH_LOG"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
printf '%s\n' "$*" >> "$GH_LOG"
[ -n "${GH_FAIL:-}" ] && exit 1
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "list" ]; then
  [ -s "$GH_PRS" ] && cat "$GH_PRS"
  exit 0
fi
exit 0
STUB
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"

. "$SPARK"

pr_row() { # pr_row <num> <branch> <head> <title> <body>
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"
}
kind_count() { printf '%s\n' "$1" | awk -F'\t' -v k="$2" '$1==k{n++} END{print n+0}'; }

# --- a declared closing reference is surfaced --------------------------------
pr_row 700 feat/500-thing abc123 "Implement the thing" "Closes #500." > "$GH_PRS"
OUT="$(next_impl_prs 500)"
[ "$(kind_count "$OUT" direct)" = "1" ] && ok || bad "a PR declaring 'Closes #500' must be surfaced as direct"
assert_contains "carrying the PR number" "700"             "$OUT"
assert_contains "the branch"             "feat/500-thing"  "$OUT"
assert_contains "and the exact head sha" "abc123"          "$OUT"

for kw in "Closes #500" "closes #500" "Fixes #500" "fixed #500" "Resolves #500" "resolved #500"; do
  pr_row 700 b abc "t" "$kw" > "$GH_PRS"
  [ "$(kind_count "$(next_impl_prs 500)" direct)" = "1" ] && ok \
    || bad "'$kw' must count as a declared closing reference"
done

# The number must end at a non-digit, or #50 would match #500 and every issue
# would appear to have implementations it does not have.
pr_row 700 b abc "t" "Closes #5001." > "$GH_PRS"
[ "$(kind_count "$(next_impl_prs 500)" direct)" = "0" ] && ok \
  || bad "'Closes #5001' must not match issue 500"

# --- a mention is not an implementation --------------------------------------
# The real case this prevents: the release PR lists every issue in its changelog.
pr_row 618 release-please--branches--master dd "chore: release v0.23.0" \
  "* thing (#500) * other (#501)" > "$GH_PRS"
OUT="$(next_impl_prs 500)"
[ "$(kind_count "$OUT" direct)" = "0" ] && ok || bad "a changelog mention must not be direct evidence"
[ "$(kind_count "$OUT" heuristic)" = "1" ] && ok || bad "a mention should still be reported, as heuristic"
assert_contains "and labelled as a mention" "without a closing reference" "$OUT"

# --- competing implementations are a decision, not a selection ---------------
{ pr_row 701 feat/500-a a1 "First attempt"  "Closes #500."
  pr_row 702 feat/500-b b1 "Second attempt" "Fixes #500."; } > "$GH_PRS"
OUT="$(next_impl_prs 500)"
[ "$(kind_count "$OUT" direct)" = "2" ] && ok || bad "both competing PRs must be reported"
assert_contains "the first is named"  "701" "$OUT"
assert_contains "the second is named" "702" "$OUT"

REPORT="$(next_report_impl_prs 500)"
assert_contains "the report says they compete" "competing implementations" "$REPORT"
assert_contains "and refuses to choose"        "nothing here chooses between them" "$REPORT"

# --- an open PR is evidence, never authority ---------------------------------
pr_row 700 feat/500-thing abc123 "Implement the thing" "Closes #500." > "$GH_PRS"
REPORT="$(next_report_impl_prs 500)"
assert_contains "the report says inspect first"      "Inspect before starting" "$REPORT"
assert_contains "and denies it is approval"          "never approval" "$REPORT"
assert_contains "or a claim on ownership"            "claim on ownership" "$REPORT"

# --- closed PRs are not open work --------------------------------------------
# The query asks for open PRs, so a closed one is absent by construction rather
# than by filtering — and absent work cannot block new work.
: > "$GH_PRS"
OUT="$(next_impl_prs 500)"
[ "$(kind_count "$OUT" direct)" = "0" ] && ok || bad "a closed PR must not appear as open implementation"
[ -z "$(next_report_impl_prs 500)" ] && ok || bad "no existing work means no section at all"
assert_contains "and the query asked only for open PRs" "--state open" "$(cat "$GH_LOG")"

# --- absence is only claimable after a complete read -------------------------
GH_FAIL=1
OUT="$(next_impl_prs 500)"
[ "$(kind_count "$OUT" unassessed)" = "1" ] && ok || bad "an API failure must be NOT ASSESSED"
assert_contains "naming what could not be read" "could not be read" "$OUT"
REPORT="$(next_report_impl_prs 500)"
assert_contains "the report says NOT ASSESSED"   "NOT ASSESSED" "$REPORT"
assert_contains "and that absence is unproven"   "absence is not established" "$REPORT"
case "$REPORT" in *"no existing"*) bad "an unreadable list must never read as 'none found'" ;; *) ok ;; esac
GH_FAIL=""

# A list that reached the scan bound may hide the answer past the boundary.
: > "$GH_PRS"
i=1
while [ "$i" -le 5 ]; do pr_row "$i" "b$i" "h$i" "t$i" "body" >> "$GH_PRS"; i=$((i + 1)); done
NEXT_PR_SCAN_LIMIT=5
OUT="$(next_impl_prs 500)"
[ "$(kind_count "$OUT" unassessed)" = "1" ] && ok || bad "hitting the scan bound must be NOT ASSESSED"
assert_contains "and say so explicitly" "scan bound" "$OUT"
NEXT_PR_SCAN_LIMIT=100

# --- discovery mutates nothing -----------------------------------------------
: > "$GH_LOG"
pr_row 700 feat/500-thing abc123 "t" "Closes #500." > "$GH_PRS"
tree_before="$(git -C "$WORK/proj" status --porcelain; git -C "$WORK/proj" branch --format='%(refname)')"
next_report_impl_prs 500 >/dev/null
tree_after="$(git -C "$WORK/proj" status --porcelain; git -C "$WORK/proj" branch --format='%(refname)')"
[ "$tree_before" = "$tree_after" ] && ok || bad "discovery must not create a branch or change the tree"

# No write verb may appear in what discovery asked GitHub to do.
if grep -qE 'pr create|issue create|-X (POST|PATCH|PUT|DELETE)|--method (POST|PATCH|PUT|DELETE)' "$GH_LOG"; then
  bad "discovery issued a mutating GitHub call: $(cat "$GH_LOG")"
else ok; fi

# --- the documented contract --------------------------------------------------
DOC="$repo_root/docs/ops/existing-implementation.md"
[ -f "$DOC" ] && ok || bad "the operator contract must be documented at docs/ops/existing-implementation.md"
if [ -f "$DOC" ]; then
  assert_contains "and state that existing work is evidence, not authority" \
    "evidence to inspect" "$(cat "$DOC")"
fi

# --- MUTATION CONTROL --------------------------------------------------------
# Promote every mention to a declared closing reference. The changelog fixture
# must then go red: that single change turns the release PR into an apparent
# implementation of every issue in the milestone.
mutant_runtime 's#(close\[sd\]?|fix(e\[sd\])?|resolve\[sd\]?)\[: \]\*\##\##'
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

pr_row 618 release-please--branches--master dd "chore: release" "* thing (#500)" > "$GH_PRS"
mout="$(bash -c '. "$1" >/dev/null 2>&1; next_impl_prs 500' _ "$MUT" 2>/dev/null || true)"
if [ "$(kind_count "$mout" direct)" = "0" ]; then
  bad "MUTATION control — a bare mention was still not promoted; the fixture does not discriminate"
else ok; fi

finish
