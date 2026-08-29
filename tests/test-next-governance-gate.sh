#!/usr/bin/env bash
# Behavioural suite for #520: an unresolvable governance model stops `spark next`
# rather than being warned about and routed past.
#
# The verb printed:
#
#   selected  #11 ... eligible yes ... blocked no
#   readiness NOT ASSESSED: the governance model does not resolve ...
#   issue #11 / category feature / route codify -> validate -> ship
#
# and exited **0**. A reader or an automation received an explicit statement that
# readiness could not be assessed together with a successful, actionable route,
# at the exit code that means "here is your next issue" — defeating "selection is
# not a licence to start" at exactly the moment the governing authority was
# invalid.
#
# Selection also fell back to a hard-coded `P0 P1 P2 P3` when the model did not
# resolve: a second copy of a rule the schema owns, taking over precisely when
# the schema was unusable.
#
# Measured discrimination, not asserted: restoring the warn-and-continue turns 10
# of the 18 assertions red, reproducing the report exactly — exit 0, "selected
# #11", and "codify -> validate -> ship" printed after the readiness warning.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init

repo="$WORK/r"; make_repo "$repo"; mkdir -p "$repo/.spark"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

# ---------------------------------------------------------------- the stub
# Deterministic live metadata: gate #10 carrying child #11, #11 labelled
# feature,P1,docs-impact:none, no open blockers. Exactly the issue's fixture.
stub="$WORK/stub"; mkdir -p "$stub"
for t in bash sh git grep sed awk cat cut tr sort head tail wc env printf mktemp \
         rm mkdir basename dirname date ls chmod touch find readlink uname paste comm; do
  src="$(command -v "$t" 2>/dev/null || true)"; [ -n "$src" ] && ln -sf "$src" "$stub/$t"
done
cat > "$stub/gh" <<'STUB'
#!/usr/bin/env bash
args="$*"
case "$1 $2" in "auth status") exit 0 ;; esac
case "$args" in
  *"issue list"*)
    printf 'issue\t%s\t%s\n' 10 "Release readiness gate"
    printf 'label\t%s\t%s\n' 10 "chore"
    printf 'label\t%s\t%s\n' 10 "P1"
    printf 'label\t%s\t%s\n' 10 "docs-impact:none"
    printf 'issue\t%s\t%s\n' 11 "The work"
    printf 'label\t%s\t%s\n' 11 "feature"
    printf 'label\t%s\t%s\n' 11 "P1"
    printf 'label\t%s\t%s\n' 11 "docs-impact:none"
    exit 0 ;;
  *"/issues/10/sub_issues"*) printf '%s\n' 11; exit 0 ;;
  *"/issues/11/sub_issues"*) exit 0 ;;
  *"dependencies/blocked_by"*) exit 0 ;;
  *"milestones?state=open"*) printf '%s\n' "v1.0"; exit 0 ;;
  *graphql*) exit 0 ;;
esac
exit 0
STUB
chmod +x "$stub/gh"

N() { # -> N_RC / N_OUT
  N_RC=0
  N_OUT="$(cd "$repo" && env PATH="$stub" "$SPARK" next --milestone "v1.0" 2>&1)" || N_RC=$?
}

# ============ a VALID model still selects and routes =======================
# First, because every assertion below is about the difference from this.
rm -f "$repo/.spark/governance.tsv"
N
assert_eq "with a valid model, next selects" 0 "$N_RC"
assert_contains "naming the issue" "selected  #11" "$N_OUT"
assert_contains "and routes it" "route" "$N_OUT"
assert_contains "with the lane named" "codify" "$N_OUT"

# ============ an unresolvable model stops the verb =========================
# The overlay from the issue, verbatim.
printf 'version\t1\nnonsense\tx\ty\n' > "$repo/.spark/governance.tsv"
N
assert_eq "#520: an unresolvable model exits non-zero" 3 "$N_RC"
assert_contains "as NOT ASSESSED" "NOT ASSESSED" "$N_OUT"
assert_contains "naming the finding, not just the state" "nonsense" "$N_OUT"
assert_contains "and pointing at the inspection verb" "spark governance inspect" "$N_OUT"

# The criterion that names the defect: no route, lane, or approval conclusion.
# Matched against the RENDERED row prefixes rather than the bare words, because
# the NOT ASSESSED message itself says "not the route" — a check that trips on
# the fix's own prose measures nothing.
for forbidden in "route     " "codify -> validate -> ship" "approval  " "selected  #"; do
  case "$N_OUT" in
    *"$forbidden"*) bad "#520: '$forbidden' was printed after readiness could not be assessed" ;;
    *) ok ;;
  esac
done
# Nor may it claim eligibility it did not establish.
for forbidden in "eligible" "blocked   no"; do
  case "$N_OUT" in
    *"$forbidden"*) bad "'$forbidden' was printed for an unassessable model" ;;
    *) ok ;;
  esac
done

# ============ the exit code is DISTINCT ====================================
# 0 selection, 1 no eligible issue, 3 not assessed, 4 selected but not ready.
# Collapsing this into 1 would tell a caller "everything is blocked", which is a
# known answer rather than an absent one.
assert_eq "and it is 3, not 1 and not 4" 3 "$N_RC"

# ============ no silent priority fallback =================================
# The fallback is gone rather than guarded. There is deliberately no assertion
# for "a model that resolves but declares no priority family": that state cannot
# be constructed, because no record removes a family and the shipped tier always
# contributes priority members to any model that resolves. The guard in the code
# is an invariant, and claiming a passing test for an unreachable branch is the
# hollow-certification move this milestone exists to stop.
#
# What IS testable is the substance of the criterion — that the model, not a
# hard-coded set, is the authority. A renamed family proves it: a fallback of
# `P0 P1 P2 P3` cannot select an issue labelled `sev1`.

# ============ a RENAMED priority family still works =======================
# The other half of "no second copy": selection must follow the model's own
# member names, not a hard-coded set that happens to match the shipped ones.
{ printf 'version\t1\n'
  printf 'family\tcategory\texactly-one\trequired\tCategory\n'
  printf 'member\tcategory\tfeature\t0e8a16\tFeature\n'
  printf 'member\tcategory\tchore\tfef2c0\tChore\n'
  printf 'family\tpriority\texactly-one\toptional\tPriority\n'
  printf 'member\tpriority\tsev1\tb60205\tHighest\n'
  printf 'member\tpriority\tsev2\td93f0b\tNext\n'
  printf 'family\tdocs-impact\tany\trequired\tDocs impact\n'
  printf 'member\tdocs-impact\tdocs-impact:none\tc5def5\tNone\n'
} > "$repo/.spark/governance.tsv"
cat > "$stub/gh" <<'STUB2'
#!/usr/bin/env bash
args="$*"
case "$1 $2" in "auth status") exit 0 ;; esac
case "$args" in
  *"issue list"*)
    printf 'issue\t%s\t%s\n' 10 "Release readiness gate"
    printf 'label\t%s\t%s\n' 10 "chore"
    printf 'label\t%s\t%s\n' 10 "sev1"
    printf 'label\t%s\t%s\n' 10 "docs-impact:none"
    printf 'issue\t%s\t%s\n' 11 "The work"
    printf 'label\t%s\t%s\n' 11 "feature"
    printf 'label\t%s\t%s\n' 11 "sev1"
    printf 'label\t%s\t%s\n' 11 "docs-impact:none"
    exit 0 ;;
  *"/issues/10/sub_issues"*) printf '%s\n' 11; exit 0 ;;
  *"/issues/11/sub_issues"*) exit 0 ;;
  *"dependencies/blocked_by"*) exit 0 ;;
  *"milestones?state=open"*) printf '%s\n' "v1.0"; exit 0 ;;
  *graphql*) exit 0 ;;
esac
exit 0
STUB2
chmod +x "$stub/gh"
N
assert_eq "a renamed priority family selects normally" 0 "$N_RC"
assert_contains "and the renamed member is read as the priority" "sev1" "$N_OUT"
assert_contains "with a route" "route" "$N_OUT"

finish
