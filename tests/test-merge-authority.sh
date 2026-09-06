#!/usr/bin/env bash
# Behavioral tests for bounded-increment merge authority (#726).
#
# The defect: PR #724 was a bounded, independently reviewed optimization that
# #722 authorized, reached exact-HEAD #584 PASS with green checks, and still
# could not merge — because #677 required the OWNING issue's acceptance to be
# true and the merge to make the OWNING issue true, and #722 ("prove the gate
# with equal-workload benchmarks") is deliberately not true yet. Every routine
# increment beneath a broad outcome hit a human stop. That is ceremony.
#
# The correction must not swing into the opposite defect. xr_stop_check (#690)
# fails toward CONTINUE because ITS defect was a false stop; this fails toward
# NOT ELIGIBLE because its defect would be MANUFACTURED MERGE AUTHORITY. So the
# weight here is on what must NOT merge, and on the rule successive reviews had
# to force in: THE CALLER SUPPLIES IDENTITY, NOT TRUTH. `review=pass`,
# `checks=green` and `stale-head=protected` were once caller tokens, so one
# valid grant let a caller self-assert every remaining gate.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/../plugins/spark/lib/execution.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

echo "Bounded-increment merge authority (#726)"

bash -n "$here/../plugins/spark/lib/execution.sh" && ok || bad "bash -n execution.sh"

# `gh` is stubbed ON PATH. There is deliberately no production env override that
# could substitute the evidence: a switch like that would be a merge-authority
# bypass shipped for the convenience of its own tests. The stub dispatches on
# the request so each fact can be failed or falsified independently.
STUB="$(mktemp -d)"
trap 'rm -rf "$STUB"' EXIT
mkdir -p "$STUB/bin"
cat > "$STUB/bin/gh" <<'EOS'
#!/usr/bin/env bash
sub="${1:-}"; shift || true
path=""; jq=""; json=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --paginate) PAGED=paginate; shift ;;
    --jq)   jq="$2"; shift 2 ;;
    --json) json="$2"; shift 2 ;;
    --repo) shift 2 ;;
    -*)     shift ;;
    *)      [ -z "$path" ] && path="$1"; shift ;;
  esac
done
[ "${GH_FAIL:-}" = all ] && exit 1
case "$sub" in
  repo) [ "${GH_FAIL:-}" = slug ] && exit 1; printf '%s' "${GH_SLUG:-}"; exit 0 ;;
  pr)   [ "${GH_FAIL:-}" = closing ] && exit 1; printf '%s' "${GH_CLOSING:-}"; exit 0 ;;
esac
printf '%s\n' "$jq${PAGED:+ }${PAGED:-}" >> "${GH_LOG:-/dev/null}"
case "$jq" in
  *integration_id*)      [ "${GH_FAIL:-}" = rules ] && exit 1; printf '%s' "${GH_RULECHECKS:-}" ;;
  *parameters.workflows*) [ "${GH_FAIL:-}" = rules ] && exit 1; printf '%s' "${GH_RULEFLOWS:-}" ;;
  *required_status_checks.checks*)
                         [ "${GH_FAIL:-}" = prot ] && exit 1; printf '%s' "${GH_PROT:-}" ;;
  ".protected"*)         [ "${GH_FAIL:-}" = protected ] && exit 1; printf '%s' "${GH_PROTECTED:-}" ;;
  *workflow_runs*)       [ "${GH_FAIL:-}" = runs ] && exit 1; printf '%s' "${GH_RUNS:-}" ;;
  ".statuses[]"*)        [ "${GH_FAIL:-}" = statuses ] && exit 1; printf '%s' "${GH_STATUSES:-}" ;;
  ".default_branch")     [ "${GH_FAIL:-}" = defbranch ] && exit 1; printf '%s' "${GH_DEFBRANCH:-}" ;;
  ".head.sha")           [ "${GH_FAIL:-}" = head ] && exit 1; printf '%s' "${GH_HEAD:-}" ;;
  ".head.sha, .state"*)  [ "${GH_FAIL:-}" = pr ] && exit 1; printf '%s' "${GH_PR:-}" ;;
  ".[].filename")        [ "${GH_FAIL:-}" = files ] && exit 1; printf '%s' "${GH_FILES:-}" ;;
  *check_runs*)          [ "${GH_FAIL:-}" = checks ] && exit 1; printf '%s' "${GH_CHECKS:-}" ;;
  ".parent_issue_url"*)  [ "${GH_FAIL:-}" = parent ] && exit 1; printf '%s' "${GH_PARENT:-}" ;;
  *author_association*)
      [ "${GH_FAIL:-}" = comments ] && exit 1
      case "$path" in
        *"/issues/${GH_PARENT_NUM:-0}/comments"*) printf '%s' "${GH_PARENT_COMMENTS:-}" ;;
        *) printf '%s' "${GH_PR_COMMENTS:-}" ;;
      esac ;;
  *) exit 1 ;;
esac
exit 0
EOS
chmod +x "$STUB/bin/gh"
export PATH="$STUB/bin:$PATH"
GH_LOG="$STUB/calls"
export GH_LOG GH_STATUSES GH_PROT GH_PROTECTED GH_RULECHECKS GH_RULEFLOWS GH_RUNS
export GH_SLUG GH_CLOSING GH_DEFBRANCH GH_HEAD GH_PR GH_FILES GH_CHECKS \
       GH_PARENT GH_PARENT_NUM GH_PARENT_COMMENTS GH_PR_COMMENTS GH_FAIL

TAB="$(printf '\t')"
# Observations carry four fields, the last being the app identity: name,
# status, conclusion, app. A commit status has no app, so its field is empty.
BASE_CHECKS="tests${TAB}completed${TAB}success${TAB}
doctor${TAB}completed${TAB}success${TAB}
gate${TAB}completed${TAB}success${TAB}15368
recover${TAB}completed${TAB}skipped${TAB}"
SHA="0123456789abcdef0123456789abcdef01234567"
SHA2="fedcba9876543210fedcba9876543210fedcba98"
ACC="memo-transparency-v1"

reset_world() {
  GH_FAIL=""
  GH_SLUG="jwogrady/spark"
  GH_DEFBRANCH="master"
  GH_CLOSING="724"
  GH_PARENT_NUM="722"
  GH_PARENT="https://api.github.com/repos/jwogrady/spark/issues/722"
  GH_PR="$SHA
open
false
master
feat/724-memo"
  GH_HEAD="$SHA"
  GH_FILES="plugins/spark/bin/spark
tests/test-hot-path-memo.sh"
  # The applicable requirement model. "gate" is bound to an app, because an
  # app-bound requirement is the one a same-named check cannot forge.
  GH_PROT="tests${TAB}
doctor${TAB}
gate${TAB}15368"
  GH_PROTECTED="true"
  GH_RULECHECKS=""
  GH_RULEFLOWS=""
  GH_RUNS=""
  GH_CHECKS="$BASE_CHECKS"
  GH_STATUSES=""
  : > "$GH_LOG"
  GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}Approving the bounded unit.\\nspark-authorizes child=#724 acceptance=$ACC"
  GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
}
reset_world

verdict() {
  local want="$1" wrc="$2" desc="$3"; shift 3
  local out rc=0
  out="$(xr_merge_check "$@" 2>&1)" || rc=$?
  local got; got="$(printf '%s\n' "$out" | head -1)"
  if [ "$got" != "$want" ]; then bad "$desc — want '$want' got '$got'"; return 0; fi
  if [ "$rc" != "$wrc" ]; then bad "$desc — want rc $wrc got $rc"; return 0; fi
  ok
}
ELIGIBLE=(--pr 727)

# Guard the guard: the base world must be eligible, or every control below
# passes for the wrong reason.
verdict "ROUTINE MERGE" 0 "the derived base world is eligible before any control changes it" "${ELIGIBLE[@]}"
# Every stubbed read must really be performed, or its controls are vacuous.
for ep in slug closing defbranch head pr files checks statuses parent comments prot rules; do
  GH_FAIL="$ep"
  verdict "NOT ELIGIBLE" 4 "the '$ep' read is really performed" "${ELIGIBLE[@]}"
  GH_FAIL=""
done

# --- the verdict says what it verified --------------------------------------
out="$(xr_merge_check "${ELIGIBLE[@]}")" || true
case "$out" in
  *"parent outcome: NOT closed and NOT satisfied"*) ok ;;
  *) bad "a routine merge must state the parent is neither closed nor satisfied" ;;
esac
case "$out" in
  *"release approval remains human-owned"*) ok ;;
  *) bad "a routine merge must restate that release approval stays human-owned" ;;
esac
case "$out" in
  *"closes the parent"*|*"parent satisfied"*) bad "a verdict must not claim parent completion" ;;
  *) ok ;;
esac
case "$out" in *"$SHA"*) ok ;; *) bad "a routine merge must name the exact commit verified" ;; esac

# --- THE CALLER SUPPLIES IDENTITY, NOT TRUTH --------------------------------
# The old self-certification tokens must be unrecognised arguments, not shortcuts.
for forged in review=pass checks=green stale-head=protected scope=routine-reversible \
              acceptance-true=yes --review=pass --checks=green --stale-head=protected; do
  verdict "NOT ELIGIBLE" 4 "a forged '$forged' claim is refused as input" "${ELIGIBLE[@]}" "$forged"
done

# --- derived: the exact-HEAD reviewer verdict -------------------------------
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA2 verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "a PASS for an older HEAD does not apply to this one" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=CHANGES REQUIRED -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "CHANGES REQUIRED on this HEAD does not merge" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="OWNER${TAB}jwogrady${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "a PASS written by a human is not the reviewer's verdict" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}LGTM, looks fine to me
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "reviewer prose without the structured marker is not a verdict" "${ELIGIBLE[@]}"
reset_world

# --- derived: the bounded acceptance is TRUE at that exact commit -----------
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->"
verdict "NOT ELIGIBLE" 4 "an authorized acceptance that is never proven true does not merge" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA2 contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "acceptance proof bound to another HEAD does not merge" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=other-v1 verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "acceptance proof for another contract does not merge" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=NOT-MET -->"
verdict "NOT ELIGIBLE" 4 "an attestation that acceptance is NOT met does not merge" "${ELIGIBLE[@]}"
REV="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#725 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "acceptance proof for the wrong child does not merge" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=other/repo#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "acceptance proof from another repository does not merge" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=999 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "acceptance proof naming another PR does not merge" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET extra=1 -->"
verdict "NOT ELIGIBLE" 4 "an acceptance proof with an unknown field is refused" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=met -->"
verdict "NOT ELIGIBLE" 4 "a lowercase verdict does not affirm" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "two acceptance proofs are ambiguous and decline" "${ELIGIBLE[@]}"

for assoc in NONE CONTRIBUTOR FIRST_TIME_CONTRIBUTOR MANNEQUIN; do
  GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
$assoc${TAB}drive-by${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
  verdict "NOT ELIGIBLE" 4 "an acceptance attested by '$assoc' does not merge" "${ELIGIBLE[@]}"
done
for assoc in OWNER MEMBER COLLABORATOR; do
  GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
$assoc${TAB}someone${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
  verdict "ROUTINE MERGE" 0 "an acceptance attested by $assoc is accepted" "${ELIGIBLE[@]}"
done
reset_world

# --- derived: checks for that exact HEAD ------------------------------------
OK2="tests${TAB}completed${TAB}success${TAB}
doctor${TAB}completed${TAB}success${TAB}"
GH_CHECKS="$OK2
gate${TAB}completed${TAB}failure${TAB}15368"
verdict "NOT ELIGIBLE" 4 "a required check that failed is not green" "${ELIGIBLE[@]}"
GH_CHECKS="$OK2
gate${TAB}in_progress${TAB}none${TAB}15368"
verdict "NOT ELIGIBLE" 4 "a required check still pending is not green" "${ELIGIBLE[@]}"
GH_CHECKS="tests${TAB}queued${TAB}none${TAB}"
verdict "NOT ELIGIBLE" 4 "a queued required check is not green" "${ELIGIBLE[@]}"
GH_CHECKS="tests${TAB}completed${TAB}cancelled${TAB}"
verdict "NOT ELIGIBLE" 4 "a cancelled required check is not green" "${ELIGIBLE[@]}"
GH_CHECKS=""
verdict "NOT ELIGIBLE" 4 "absent check evidence is not green evidence" "${ELIGIBLE[@]}"

# --- required checks: presence, not merely cheerful noise -------------------
# A single unrelated success must never stand in for a required check that
# never ran. This is the shape that made "green" meaningless.
GH_CHECKS="something-unrelated${TAB}completed${TAB}success${TAB}"
verdict "NOT ELIGIBLE" 4 "an unrelated success does not satisfy a missing required check" "${ELIGIBLE[@]}"
GH_CHECKS="$OK2"
verdict "NOT ELIGIBLE" 4 "a required check absent from the run list declines" "${ELIGIBLE[@]}"
# A REQUIRED check that skipped did not do its job.
GH_CHECKS="$OK2
gate${TAB}completed${TAB}skipped${TAB}15368"
verdict "NOT ELIGIBLE" 4 "a required check that skipped is not green" "${ELIGIBLE[@]}"
GH_CHECKS="$OK2
gate${TAB}completed${TAB}neutral${TAB}15368"
verdict "NOT ELIGIBLE" 4 "a required check concluding neutral is not green" "${ELIGIBLE[@]}"
reset_world

# --- an app-bound requirement is not satisfied by a same-named check --------
# Branch protection's `.checks[]` binds a context to an app. Reading only the
# legacy `.contexts[]` threw that binding away, so any producer that could
# report a same-named check satisfied a requirement that was never theirs.
GH_CHECKS="$OK2
gate${TAB}completed${TAB}success${TAB}99999"
verdict "NOT ELIGIBLE" 4 "another app's check of the same name does not satisfy an app-bound requirement" "${ELIGIBLE[@]}"
GH_CHECKS="$OK2
gate${TAB}completed${TAB}success${TAB}"
verdict "NOT ELIGIBLE" 4 "an unbound observation does not satisfy an app-bound requirement" "${ELIGIBLE[@]}"
# A commit status carries no app identity at all, so it can never satisfy one.
GH_CHECKS="$OK2"
GH_STATUSES="gate${TAB}completed${TAB}success${TAB}"
verdict "NOT ELIGIBLE" 4 "a commit status cannot satisfy an app-bound requirement" "${ELIGIBLE[@]}"
reset_world

# --- a required context may arrive as a commit status ----------------------
GH_PROT="tests${TAB}
doctor${TAB}
gate${TAB}"
GH_CHECKS="$OK2"
GH_STATUSES="gate${TAB}completed${TAB}success${TAB}"
verdict "ROUTINE MERGE" 0 "a required context satisfied by a commit status counts" "${ELIGIBLE[@]}"
GH_STATUSES="gate${TAB}completed${TAB}failure${TAB}"
verdict "NOT ELIGIBLE" 4 "a failing commit status for a required context declines" "${ELIGIBLE[@]}"
reset_world

# --- EVERY observation of a required check counts --------------------------
# Accepting the first success let a failing or still-running re-run of the same
# required check sit quietly behind it.
GH_CHECKS="tests${TAB}completed${TAB}success${TAB}
tests${TAB}completed${TAB}failure${TAB}
doctor${TAB}completed${TAB}success${TAB}
gate${TAB}completed${TAB}success${TAB}15368"
verdict "NOT ELIGIBLE" 4 "a failing second observation of a required check declines" "${ELIGIBLE[@]}"
GH_CHECKS="tests${TAB}completed${TAB}failure${TAB}
tests${TAB}completed${TAB}success${TAB}
doctor${TAB}completed${TAB}success${TAB}
gate${TAB}completed${TAB}success${TAB}15368"
verdict "NOT ELIGIBLE" 4 "the order of conflicting observations does not matter" "${ELIGIBLE[@]}"
GH_CHECKS="tests${TAB}completed${TAB}success${TAB}
tests${TAB}in_progress${TAB}none${TAB}
doctor${TAB}completed${TAB}success${TAB}
gate${TAB}completed${TAB}success${TAB}15368"
verdict "NOT ELIGIBLE" 4 "a re-run still in progress behind a success declines" "${ELIGIBLE[@]}"
# A commit status contradicting a passing check run of the same context is the
# same conflict from the other surface.
GH_CHECKS="$BASE_CHECKS"
GH_STATUSES="tests${TAB}completed${TAB}failure${TAB}"
verdict "NOT ELIGIBLE" 4 "a failing commit status contradicting a passing check run declines" "${ELIGIBLE[@]}"
# Two identical successful observations are a re-run, not a conflict.
GH_STATUSES=""
GH_CHECKS="tests${TAB}completed${TAB}success${TAB}
tests${TAB}completed${TAB}success${TAB}
doctor${TAB}completed${TAB}success${TAB}
gate${TAB}completed${TAB}success${TAB}15368"
verdict "ROUTINE MERGE" 0 "two successful observations of one required check are not a conflict" "${ELIGIBLE[@]}"
reset_world

# --- rulesets require checks branch protection never mentions --------------
# Branch protection is not the whole requirement model. A repository or
# organization ruleset can require a context of its own, and a requirement
# model that omits it is a permissive one.
GH_RULECHECKS="ruleset-gate${TAB}"
verdict "NOT ELIGIBLE" 4 "a ruleset-required check with no observation declines" "${ELIGIBLE[@]}"
GH_CHECKS="$BASE_CHECKS
ruleset-gate${TAB}completed${TAB}failure${TAB}"
verdict "NOT ELIGIBLE" 4 "a failing ruleset-required check declines" "${ELIGIBLE[@]}"
GH_CHECKS="$BASE_CHECKS
ruleset-gate${TAB}completed${TAB}success${TAB}"
verdict "ROUTINE MERGE" 0 "a satisfied ruleset-required check counts" "${ELIGIBLE[@]}"
# A ruleset requirement can be bound to an integration, exactly as branch
# protection binds to an app.
GH_RULECHECKS="ruleset-gate${TAB}424242"
verdict "NOT ELIGIBLE" 4 "a ruleset requirement bound to an integration needs that integration's check" "${ELIGIBLE[@]}"
GH_CHECKS="$BASE_CHECKS
ruleset-gate${TAB}completed${TAB}success${TAB}424242"
verdict "ROUTINE MERGE" 0 "the bound integration's check satisfies a ruleset requirement" "${ELIGIBLE[@]}"
reset_world
GH_FAIL=rules
verdict "NOT ELIGIBLE" 4 "an unreadable ruleset requirement model declines" "${ELIGIBLE[@]}"
GH_FAIL=""

# --- rulesets can require a whole WORKFLOW, stated as a path ---------------
# No check-run name mentions a workflow path, so a required workflow is
# verified against the workflow runs for this exact commit.
GH_RULEFLOWS=".github/workflows/openai-review.yml"
verdict "NOT ELIGIBLE" 4 "a ruleset-required workflow with no run on this commit declines" "${ELIGIBLE[@]}"
GH_RUNS=".github/workflows/openai-review.yml${TAB}in_progress${TAB}none"
verdict "NOT ELIGIBLE" 4 "a ruleset-required workflow still running declines" "${ELIGIBLE[@]}"
GH_RUNS=".github/workflows/openai-review.yml${TAB}completed${TAB}failure"
verdict "NOT ELIGIBLE" 4 "a failing ruleset-required workflow declines" "${ELIGIBLE[@]}"
GH_RUNS=".github/workflows/other.yml${TAB}completed${TAB}success"
verdict "NOT ELIGIBLE" 4 "a different workflow's success does not satisfy the required one" "${ELIGIBLE[@]}"
GH_RUNS=".github/workflows/openai-review.yml${TAB}completed${TAB}success"
verdict "ROUTINE MERGE" 0 "a passing ruleset-required workflow counts" "${ELIGIBLE[@]}"
GH_RUNS=".github/workflows/openai-review.yml${TAB}completed${TAB}success
.github/workflows/openai-review.yml${TAB}completed${TAB}failure"
verdict "NOT ELIGIBLE" 4 "a failing re-run of a required workflow behind a success declines" "${ELIGIBLE[@]}"
GH_RUNS=".github/workflows/openai-review.yml${TAB}completed${TAB}success"
GH_FAIL=runs
verdict "NOT ELIGIBLE" 4 "an unreadable workflow-run list declines while a workflow is required" "${ELIGIBLE[@]}"
GH_FAIL=""
: > "$GH_LOG"
xr_merge_check "${ELIGIBLE[@]}" >/dev/null 2>&1 || true
if grep -q "workflow_runs.*paginate" "$GH_LOG"; then ok
else bad "the workflow-run read must be paginated, or a later page is invisible"; fi
reset_world

# --- an unreadable requirement model is not an empty one -------------------
GH_FAIL=prot
verdict "NOT ELIGIBLE" 4 "an unreadable protection read on a protected branch declines" "${ELIGIBLE[@]}"
GH_PROTECTED=""
verdict "NOT ELIGIBLE" 4 "an unreadable protected flag leaves the requirement model unknown" "${ELIGIBLE[@]}"
# Provably unprotected is a FACT, not a doubt — but then nothing is required,
# and nothing required is nothing proven.
GH_PROTECTED="false"
verdict "NOT ELIGIBLE" 4 "an unprotected branch with no ruleset has no green to stand on" "${ELIGIBLE[@]}"
GH_RULECHECKS="ruleset-gate${TAB}"
GH_CHECKS="$BASE_CHECKS
ruleset-gate${TAB}completed${TAB}success${TAB}"
verdict "ROUTINE MERGE" 0 "a branch governed only by a ruleset is verified from the ruleset" "${ELIGIBLE[@]}"
# The load-bearing form of the two controls above: a ruleset requirement that IS
# satisfied must not stand in for a protection requirement that could not be
# read. Without this they pass for the wrong reason — their fallthrough is
# "nothing is required", which declines anyway — and an unreadable protection
# read on a protected branch would merge on the ruleset alone.
GH_PROTECTED="true"
verdict "NOT ELIGIBLE" 4 "a satisfied ruleset does not stand in for an unreadable protection requirement" "${ELIGIBLE[@]}"
reset_world
# The same rule with protection readable but requiring nothing.
GH_PROT=""
verdict "NOT ELIGIBLE" 4 "a branch that requires no checks anywhere has no green to stand on" "${ELIGIBLE[@]}"
reset_world

# --- BOTH observation surfaces must be readable ----------------------------
# Converting a failed read into an empty one let the other surface's successes
# stand alone, while the surface that could not be read might hold the
# conflicting failure or the pending re-run that decides the question.
GH_PROT="tests${TAB}
doctor${TAB}
gate${TAB}"
GH_CHECKS=""
GH_STATUSES="tests${TAB}completed${TAB}success${TAB}
doctor${TAB}completed${TAB}success${TAB}
gate${TAB}completed${TAB}success${TAB}"
verdict "ROUTINE MERGE" 0 "commit statuses alone satisfy an unbound requirement set" "${ELIGIBLE[@]}"
GH_FAIL=checks
verdict "NOT ELIGIBLE" 4 "an unreadable check-run list declines even when statuses satisfy every requirement" "${ELIGIBLE[@]}"
GH_FAIL=""
reset_world
GH_FAIL=statuses
verdict "NOT ELIGIBLE" 4 "an unreadable commit-status list declines even when check runs satisfy every requirement" "${ELIGIBLE[@]}"
GH_FAIL=""
reset_world

# --- scope depends on the WHOLE changed-file list ---------------------------
# A non-routine path past a page boundary was invisible, and the pull request
# was classified routine on the strength of the first page alone.
PAGE1=""
i=1
while [ "$i" -le 120 ]; do
  PAGE1="${PAGE1}plugins/spark/docs/reference/page-$i.md
"
  i=$((i + 1))
done
GH_FILES="${PAGE1}.github/workflows/ci.yml"
verdict "NOT ELIGIBLE" 4 "a non-routine path after a page boundary is still seen" "${ELIGIBLE[@]}"
GH_FILES="${PAGE1}plugins/spark/settings/permissions.json"
verdict "NOT ELIGIBLE" 4 "an enforcement-settings path after a page boundary is still seen" "${ELIGIBLE[@]}"
GH_FILES="${PAGE1}plugins/spark/lib/execution.sh"
verdict "ROUTINE MERGE" 0 "a long but wholly routine file list still merges" "${ELIGIBLE[@]}"
reset_world

# --- every trusted list read must be paginated ------------------------------
# "Exactly one" concluded from a truncated page is not exactly one, and a
# failing check on page two is invisible.
xr_merge_check "${ELIGIBLE[@]}" >/dev/null 2>&1 || true
for expect in "author_association" "check_runs" "statuses" "filename" \
              "required_status_checks.checks" "integration_id" "parameters.workflows"; do
  if grep -q "$expect.*paginate" "$GH_LOG"; then ok
  else bad "the '$expect' read must be paginated, or a later page is invisible"; fi
done
reset_world

# --- conflicting evidence is not passing evidence ---------------------------
# A later CHANGES REQUIRED for the same commit does not sit quietly beside an
# earlier PASS; one commit cannot be both.
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=CHANGES REQUIRED -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "a PASS beside a CHANGES REQUIRED for the same head declines" "${ELIGIBLE[@]}"
# ...and in the other order, so this is not an artefact of which came first.
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=CHANGES REQUIRED -->
github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "the order of conflicting verdicts does not matter" "${ELIGIBLE[@]}"
# A MET beside a NOT-MET for the same identity and commit proves nothing.
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=NOT-MET -->"
verdict "NOT ELIGIBLE" 4 "a MET beside a NOT-MET for the same commit declines" "${ELIGIBLE[@]}"
# A malformed acceptance record is not something to step over.
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC bogus=1 -->"
verdict "NOT ELIGIBLE" 4 "a malformed acceptance record beside a good one declines" "${ELIGIBLE[@]}"
reset_world

# Two records for one commit, even agreeing, are not one canonical record.
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "two reviewer records for one commit are ambiguous" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict= -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "a reviewer marker with no readable verdict declines" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=NOT ASSESSED -->
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "NOT ASSESSED is never a pass" "${ELIGIBLE[@]}"
reset_world

# --- every marker OCCURRENCE is read, not the first one per comment ---------
# Parsing at most one marker per comment let a second record hide behind the
# first: a contradicting sibling in the same body was never seen at all.
ACCEPT_MET="OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS --> and then <!-- spark-openai-review pr=727 head=$SHA verdict=CHANGES REQUIRED -->
$ACCEPT_MET"
verdict "NOT ELIGIBLE" 4 "two conflicting reviewer markers inside ONE comment decline" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->\\n<!-- spark-openai-review pr=727 head=$SHA verdict=CHANGES REQUIRED -->
$ACCEPT_MET"
verdict "NOT ELIGIBLE" 4 "two conflicting reviewer markers on separate lines of one comment decline" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS --> <!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->
$ACCEPT_MET"
verdict "NOT ELIGIBLE" 4 "two agreeing reviewer markers inside one comment are still two records" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET --> <!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=NOT-MET -->"
verdict "NOT ELIGIBLE" 4 "a MET and a NOT-MET inside ONE comment decline" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->\\n<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "two acceptance proofs inside one comment decline" "${ELIGIBLE[@]}"
reset_world

# --- an uninterpretable reviewer record is not an ignorable one -------------
# A malformed same-HEAD marker beside a PASS leaves the verdict unestablished:
# the closed grammar is positional because the verdict is the only multi-word
# value, so a reordering or an extra field means the record is not readable.
for broken in "pr=727 head=$SHA verdict=LOOKS FINE" \
              "pr=727 head=$SHA" \
              "head=$SHA pr=727 verdict=PASS" \
              "pr=727 head=$SHA verdict=PASS extra=1" \
              "pr=727 head=$SHA verdict="; do
  GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->\\n<!-- spark-openai-review $broken -->
$ACCEPT_MET"
  verdict "NOT ELIGIBLE" 4 "a malformed reviewer marker ('$broken') beside a PASS declines" "${ELIGIBLE[@]}"
done
# An unterminated marker is ambiguity, not absence.
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->\\n<!-- spark-openai-review pr=727 head=$SHA verdict=PASS
$ACCEPT_MET"
verdict "NOT ELIGIBLE" 4 "an unterminated reviewer marker beside a PASS declines" "${ELIGIBLE[@]}"
# NOT ASSESSED is in the vocabulary, so it parses — and never affirms.
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=NOT ASSESSED -->
$ACCEPT_MET"
verdict "NOT ELIGIBLE" 4 "NOT ASSESSED is a readable verdict and still not a pass" "${ELIGIBLE[@]}"
# A malformed record that legibly concerns ANOTHER commit is not this decision's
# business; only ambiguity about THIS commit declines.
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->\\n<!-- spark-openai-review pr=727 head=$SHA2 verdict=WHATEVER -->
$ACCEPT_MET"
verdict "ROUTINE MERGE" 0 "a malformed reviewer marker for a different commit does not decline this one" "${ELIGIBLE[@]}"
reset_world

# --- a repeated identity field is ambiguity, not "about something else" -----
# Keeping only the first pr= or head= let a record carrying both pr=999 and
# pr=727 — or a stale head beside the current one — be waved through as
# concerning another commit on the strength of whichever came first.
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->\\n<!-- spark-openai-review pr=999 pr=727 head=$SHA verdict=PASS -->
$ACCEPT_MET"
verdict "NOT ELIGIBLE" 4 "a malformed reviewer marker naming two pull requests declines" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="github-actions[bot]${TAB}github-actions[bot]${TAB}<!-- spark-openai-review pr=727 head=$SHA verdict=PASS -->\\n<!-- spark-openai-review pr=727 head=$SHA2 head=$SHA verdict=PASS -->
$ACCEPT_MET"
verdict "NOT ELIGIBLE" 4 "a malformed reviewer marker naming two commits declines" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->\\n<!-- spark-acceptance pr=999 pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "a malformed acceptance record naming two pull requests declines" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=#724 head=$SHA contract=$ACC verdict=MET -->\\n<!-- spark-acceptance pr=727 child=#724 head=$SHA2 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "a malformed acceptance record naming two commits declines" "${ELIGIBLE[@]}"
reset_world

# --- the work unit lives in the PULL REQUEST's repository -------------------
# The owning issue may live elsewhere. Borrowing the parent's repository for
# the child's identity would let a bare "#724" written on a parent in another
# repository stand for THIS repository's #724 — a different issue that happens
# to share a number.
GH_PARENT="https://api.github.com/repos/other/org-repo/issues/722"
verdict "NOT ELIGIBLE" 4 "a bare grant under a cross-repository parent is ambiguous" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=other/org-repo#724 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "a grant naming the parent's repository does not authorize the PR's issue" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=jwogrady/spark#724 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "a bare acceptance child under a cross-repository parent is ambiguous" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=jwogrady/spark#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "ROUTINE MERGE" 0 "explicit full identities authorize across a cross-repository parent" "${ELIGIBLE[@]}"
GH_PR_COMMENTS="$REV
OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=727 child=other/org-repo#724 head=$SHA contract=$ACC verdict=MET -->"
verdict "NOT ELIGIBLE" 4 "an acceptance naming the parent's repository does not prove the PR's issue" "${ELIGIBLE[@]}"
# A bare grant for a DIFFERENT number is unambiguous whichever repository it
# means, so it is simply not this work unit.
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#725 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "a bare grant for another number under a cross-repository parent is not this unit" "${ELIGIBLE[@]}"
reset_world

# --- derived: stale-head protection by construction -------------------------
GH_HEAD="$SHA2"
verdict "NOT ELIGIBLE" 4 "HEAD moving between derivation and verdict declines" "${ELIGIBLE[@]}"
GH_HEAD="not-a-sha"
verdict "NOT ELIGIBLE" 4 "an unreadable current head declines" "${ELIGIBLE[@]}"
reset_world

# --- derived: the work unit and the native hierarchy ------------------------
GH_CLOSING=""
verdict "NOT ELIGIBLE" 4 "a PR closing no issue has no bounded work unit" "${ELIGIBLE[@]}"
GH_CLOSING="724
725"
verdict "NOT ELIGIBLE" 4 "a PR closing two issues is ambiguous about its work unit" "${ELIGIBLE[@]}"
# Ambiguity must decline on its own, not merely because the extra issue happens
# to lack a grant: here the LAST closed issue is the fully-authorized one, so a
# "take the last" implementation would merge.
GH_CLOSING="723
724"
verdict "NOT ELIGIBLE" 4 "two closed issues decline even when the last one is authorized" "${ELIGIBLE[@]}"
reset_world
GH_PARENT=""
verdict "NOT ELIGIBLE" 4 "a work unit with no native parent has no owning issue" "${ELIGIBLE[@]}"
GH_PARENT="https://api.github.com/repos/jwogrady/spark/issues/not-a-number"
verdict "NOT ELIGIBLE" 4 "an unreadable native parent declines" "${ELIGIBLE[@]}"
reset_world

# --- the grant, read back from the parent -----------------------------------
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}Thanks, this looks reasonable to me."
verdict "NOT ELIGIBLE" 4 "an unrelated comment on the parent authorizes nothing" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}I authorize bounded unit #724 with acceptance $ACC."
verdict "NOT ELIGIBLE" 4 "prose naming the child and acceptance is not a grant" "${ELIGIBLE[@]}"
# A valid grant beside a MALFORMED same-unit authorization line is ambiguity
# about authority itself. Silently skipping the malformed sibling left one
# valid grant standing and let the good record carry a decision the pair does
# not support.
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC\\nspark-authorizes child=#724 acceptance=$ACC scope=everything"
verdict "NOT ELIGIBLE" 4 "a malformed same-unit grant line beside a valid one declines" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC
OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC extra=1"
verdict "NOT ELIGIBLE" 4 "a malformed same-unit grant in another comment declines too" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC
OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=not a token"
verdict "NOT ELIGIBLE" 4 "a same-unit grant whose acceptance is not canonical declines" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC
OWNER${TAB}jwogrady${TAB}spark-authorizes child=nonsense acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "a grant line naming an unreadable work unit declines" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC
OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 child=#725 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "a grant line naming two work units declines" "${ELIGIBLE[@]}"
# A malformed grant for a DIFFERENT work unit authorizes something else.
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC
OWNER${TAB}jwogrady${TAB}spark-authorizes child=#725 acceptance=$ACC extra=1"
verdict "ROUTINE MERGE" 0 "a malformed grant for a different work unit does not decline this one" "${ELIGIBLE[@]}"
reset_world

# A real comment does not end exactly at the marker. Parsing the flattened tail
# instead of the LINE rejected every grant with prose after it — fail-closed,
# but it made the feature unusable.
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC\\nThanks for the quick turnaround."
verdict "ROUTINE MERGE" 0 "a grant followed by ordinary prose still authorizes" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}Approving this.\\nspark-authorizes child=#724 acceptance=$ACC\\nSee the plan above."
verdict "ROUTINE MERGE" 0 "a grant surrounded by prose still authorizes" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC\\nspark-authorizes child=#724 acceptance=other-v1"
verdict "NOT ELIGIBLE" 4 "two grant lines in one comment are ambiguous" "${ELIGIBLE[@]}"
# IDENTICAL lines too: a "take the last" implementation sails through a control
# whose duplicates merely disagree.
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC\\nspark-authorizes child=#724 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "two identical grant lines in one comment are ambiguous" "${ELIGIBLE[@]}"
# The marker must START the line. Prose that merely mentions it is discussion,
# not a grant — otherwise quoting the syntax in a sentence would authorize.
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}Write spark-authorizes child=#724 acceptance=$ACC to approve."
verdict "NOT ELIGIBLE" 4 "a marker quoted mid-sentence is discussion, not a grant" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}  spark-authorizes child=#724 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "an indented marker is not the canonical line form" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#725 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "a grant for the wrong child does not authorize this one" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#7241 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "#7241 does not satisfy a grant to #724" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=other/repo#724 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "the same number in another repository is a different work unit" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC
OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=other-v1"
verdict "NOT ELIGIBLE" 4 "two grants for the same child are ambiguous and decline" "${ELIGIBLE[@]}"
# Two IDENTICAL grants are still ambiguous: a "take the last" implementation
# would sail through this, so the control must not rely on them differing.
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC
OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "two identical grants are still ambiguous and decline" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#0724 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "a zero-padded child in the grant is refused" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance="
verdict "NOT ELIGIBLE" 4 "a grant binding no acceptance is refused" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC extra=1"
verdict "NOT ELIGIBLE" 4 "a grant with an unknown field is refused" "${ELIGIBLE[@]}"
for assoc in NONE CONTRIBUTOR FIRST_TIME_CONTRIBUTOR MANNEQUIN owner Owner; do
  GH_PARENT_COMMENTS="$assoc${TAB}drive-by${TAB}spark-authorizes child=#724 acceptance=$ACC"
  verdict "NOT ELIGIBLE" 4 "a grant written by '$assoc' is not authority" "${ELIGIBLE[@]}"
done
# A machine report carrying a grant line is still a report.
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}<!-- spark-openai-review pr=1 head=x verdict=PASS -->\\nspark-authorizes child=#724 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "a reviewer surface carrying a grant line is not a grant" "${ELIGIBLE[@]}"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}<!-- spark-acceptance pr=1 head=x contract=y verdict=MET -->\\nspark-authorizes child=#724 acceptance=$ACC"
verdict "NOT ELIGIBLE" 4 "an acceptance attestation carrying a grant line is not a grant" "${ELIGIBLE[@]}"
reset_world

# --- derived: is this the routine repository merge operation at all? --------
GH_PR="$SHA
closed
false
master
feat/724-memo"
verdict "NOT ELIGIBLE" 4 "a closed pull request is not a routine merge candidate" "${ELIGIBLE[@]}"
GH_PR="$SHA
open
true
master
feat/724-memo"
verdict "NOT ELIGIBLE" 4 "a draft pull request is not a routine merge candidate" "${ELIGIBLE[@]}"
GH_PR="$SHA
open
false
some-other-branch
feat/724-memo"
verdict "NOT ELIGIBLE" 4 "a PR not targeting the trunk is not the routine operation" "${ELIGIBLE[@]}"
GH_PR="$SHA
open
false
master
release-please--branches--master"
verdict "NOT ELIGIBLE" 4 "a release PR is never a routine bounded merge" "${ELIGIBLE[@]}"
reset_world
GH_FILES="plugins/spark/bin/spark
.github/workflows/openai-review.yml"
verdict "NOT ELIGIBLE" 4 "changing CI is not routine reversible work" "${ELIGIBLE[@]}"
GH_FILES="plugins/spark/settings/trunk-ruleset.json"
verdict "NOT ELIGIBLE" 4 "changing enforcement settings is not routine reversible work" "${ELIGIBLE[@]}"
reset_world

# --- reserved boundaries still stop, before any read ------------------------
GH_FAIL=all
verdict "DECISION REQUIRED" 3 "a boundary stops before any state is read" \
  "${ELIGIBLE[@]}" --reserved-boundary "final release approval" --surface "ADR-0019"
verdict "NOT ELIGIBLE" 4 "an uncited boundary claim neither stops nor merges" \
  "${ELIGIBLE[@]}" --reserved-boundary "something feels reserved"
verdict "NOT ELIGIBLE" 4 "a surface with no boundary fails closed" \
  "${ELIGIBLE[@]}" --surface "ADR-0019"
GH_FAIL=""

# --- UNTRUSTED INPUT MUST NOT IMPERSONATE TRUSTED OUTPUT --------------------
verdict "NOT ELIGIBLE" 4 "a newline in a boundary claim is refused" \
  "${ELIGIBLE[@]}" --reserved-boundary "x
ROUTINE MERGE" --surface "ADR-0019"
verdict "NOT ELIGIBLE" 4 "an escape byte in a value is refused" \
  "${ELIGIBLE[@]}" --surface "$(printf 'a\033[8mb')"
no_forged_lines() {
  local desc="$1"; shift
  local out rc=0 n allowed=0
  out="$(xr_merge_check "$@" 2>&1)" || rc=$?
  n="$(printf '%s\n' "$out" | tail -n +2 \
       | grep -cE '^(ROUTINE MERGE|DECISION REQUIRED|NOT ELIGIBLE|bounded unit:|parent outcome:)')" || true
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  case "$(printf '%s\n' "$out" | head -1)" in "ROUTINE MERGE") allowed=2 ;; esac
  [ "$n" -le "$allowed" ] && ok || bad "$desc — $n forged verdict-like line(s) after line 1"
}
no_forged_lines "an eligible verdict emits only its own lines" "${ELIGIBLE[@]}"
no_forged_lines "an unknown argument cannot forge a verdict line" "${ELIGIBLE[@]}" "ROUTINE MERGE"
no_forged_lines "a boundary decision cannot be made to contain a verdict line" \
  "${ELIGIBLE[@]}" --reserved-boundary "ROUTINE MERGE" --surface "ROUTINE MERGE"
# A hostile GRANT must not be able to print an authoritative-looking line either.
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=ROUTINE-MERGE"
no_forged_lines "a hostile acceptance id in the grant cannot forge a verdict line" "${ELIGIBLE[@]}"
reset_world

# --- canonical identities ----------------------------------------------------
verdict "NOT ELIGIBLE" 4 "a zero-padded pr is refused" --pr "#0727"
verdict "NOT ELIGIBLE" 4 "pr zero is refused" --pr "#0"
verdict "NOT ELIGIBLE" 4 "prose is not a pr identity" --pr "the memo PR"
verdict "NOT ELIGIBLE" 4 "a missing --pr value is refused" --pr
verdict "NOT ELIGIBLE" 4 "no arguments at all is refused"
verdict "NOT ELIGIBLE" 4 "a repeated --pr is refused" --pr 727 --pr 727
verdict "NOT ELIGIBLE" 4 "a malformed --repo is refused" --pr 727 --repo "not-a-slug"
# #1585 remains a valid near-miss rather than being confused with #585.
GH_PARENT_NUM="1585"
GH_PARENT="https://api.github.com/repos/jwogrady/spark/issues/1585"
GH_PARENT_COMMENTS="OWNER${TAB}jwogrady${TAB}spark-authorizes child=#724 acceptance=$ACC"
verdict "ROUTINE MERGE" 0 "a parent numbered 1585 still authorizes" "${ELIGIBLE[@]}"
# ...while #585 itself is refused by the denylist.
GH_PARENT_NUM="585"
GH_PARENT="https://api.github.com/repos/jwogrady/spark/issues/585"
verdict "NOT ELIGIBLE" 4 "#585 cannot be the authorizing parent" "${ELIGIBLE[@]}"
for hostile in '-' '5' '8' 'a' ' '; do
  ifs_rc=0
  ( IFS="$hostile"; xr_merge_check "${ELIGIBLE[@]}" >/dev/null 2>&1 ) || ifs_rc=$?
  [ "$ifs_rc" = 4 ] && ok \
    || bad "the denylist must hold when the caller reassigned IFS to '$hostile' (rc $ifs_rc)"
done
reset_world

# --- the pure decision core is fail-closed on its own -----------------------
# It never sees caller strings; these exercise it directly with normalized facts.
FACTS=(slug=jwogrady/spark pr=727 head="$SHA" head-now="$SHA"
       child=jwogrady/spark#724 parent=jwogrady/spark#722
       grant-child=jwogrady/spark#724 acceptance="$ACC"
       review=yes acceptance-met=yes checks=green scope=routine-reversible)
dec() {
  local want="$1" desc="$2"; shift 2
  local out rc=0; out="$(xm_decide "$@" 2>&1)" || rc=$?
  case "$(printf '%s\n' "$out" | head -1)" in
    "$want") ok ;;
    *) bad "$desc — want '$want' got '$(printf '%s\n' "$out" | head -1)'" ;;
  esac
}
dec "ROUTINE MERGE" "the core accepts a complete normalized fact set" "${FACTS[@]}"
dec "NOT ELIGIBLE" "the core refuses an unknown fact" "${FACTS[@]}" bogus=1
# The advertised fail-closed core must REQUIRE the grant identity, not skip the
# comparison when it happens to be absent.
dec "NOT ELIGIBLE" "the core refuses a missing grant-child" "${FACTS[@]/grant-child=*/grant-child=}"
dec "NOT ELIGIBLE" "the core refuses a non-canonical grant-child" "${FACTS[@]/grant-child=*/grant-child=nonsense}"
for drop in review acceptance-met checks scope; do
  dec "NOT ELIGIBLE" "the core refuses when '$drop' is not affirmed" \
    "${FACTS[@]/$drop=*/$drop=no}"
done
dec "NOT ELIGIBLE" "the core refuses a moved head" "${FACTS[@]/head-now=*/head-now=$SHA2}"
dec "NOT ELIGIBLE" "the core refuses a cross-repository grant" \
  "${FACTS[@]/grant-child=*/grant-child=other/repo#724}"
dec "DECISION REQUIRED" "the core routes a named+cited boundary" \
  "${FACTS[@]}" reserved-boundary=release surface=ADR-0026

# --- the CLI and the dispatcher agree ---------------------------------------
rc=0; out="$(cmd_merge_authority "${ELIGIBLE[@]}" 2>&1)" || rc=$?
[ "$rc" = 0 ] && ok || bad "cmd_merge_authority must exit 0 on a routine merge (got $rc)"
case "$out" in "ROUTINE MERGE"*) ok ;; *) bad "cmd_merge_authority must echo the verdict" ;; esac
GH_CHECKS="gate${TAB}completed${TAB}failure${TAB}15368"
rc=0; cmd_merge_authority "${ELIGIBLE[@]}" >/dev/null 2>&1 || rc=$?
[ "$rc" = 4 ] && ok || bad "cmd_merge_authority must exit 4 when not eligible (got $rc)"
reset_world
rc=0; cmd_merge_authority "${ELIGIBLE[@]}" --reserved-boundary release --surface ADR-0026 >/dev/null 2>&1 || rc=$?
[ "$rc" = 3 ] && ok || bad "cmd_merge_authority must exit 3 at a reserved boundary (got $rc)"
rc=0; out="$(cmd_merge_authority --help 2>&1)" || rc=$?
[ "$rc" = 0 ] && ok || bad "help must exit 0 (got $rc)"
case "$out" in *"DERIVED, never asserted"*) ok ;; *) bad "help must say which facts are derived" ;; esac
case "$(printf '%s\n' "$out" | head -1)" in
  "ROUTINE MERGE") bad "help must not emit a verdict as its first line" ;;
  *) ok ;;
esac
rc=0; out="$(cmd_merge_authority 2>&1)" || rc=$?
[ "$rc" = 4 ] && ok || bad "a bare invocation must exit 4, never 0 (got $rc)"
case "$(printf '%s\n' "$out" | head -1)" in
  "NOT ELIGIBLE") ok ;; *) bad "a bare invocation must declare NOT ELIGIBLE" ;;
esac

spark_bin="$here/../plugins/spark/bin/spark"
rc=0; out="$("$spark_bin" merge-authority "${ELIGIBLE[@]}" 2>&1)" || rc=$?
[ "$rc" = 0 ] && ok || bad "the verb must route through the dispatcher (rc $rc)"
case "$out" in "ROUTINE MERGE"*) ok ;; *) bad "the verb must emit the verdict" ;; esac
rc=0; "$spark_bin" merge-authority >/dev/null 2>&1 || rc=$?
[ "$rc" = 4 ] && ok || bad "the bare verb must exit 4, never 0 (got $rc)"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
