#!/usr/bin/env bash
# Behavioural suite for #558 — bounded autonomous execution and convergence.
#
# The failure this pins is a run that is deterministic at the repository level
# and unbounded inside it: expensive certification bought again and again,
# findings rediscovered instead of carried as a shrinking failing set, and no
# boundary anywhere except the agent's own sense of having done enough.
#
# So the contract is external and declared up front. The two properties that
# matter most are the ones easiest to get wrong in opposite directions:
#
#   * a run that is NOT converging must stop even with budget left over —
#     unused tokens are not a reason to buy the same answer again;
#   * a run that IS converging must be allowed past a soft signal — punishing
#     productive work would train exactly the behaviour this discourages.
#
# And the boundary is never authority: every stop must still report the failing
# set it is stopping on. A budget that could quietly mark work clean would be a
# worse defect than the unbounded run it replaced.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "bounded runs and convergence (#558)"
sandbox_init
make_repo "$WORK/proj"
cd "$WORK/proj"

# rc <expected> <desc> -- <cmd...>: run a check and pin its exit code, because
# the verdict is the exit code as much as the text; a loop reading only the
# status must still terminate.
rc() {
  local want="$1" desc="$2" got=0; shift 3
  "$@" >/dev/null 2>&1 || got=$?
  if [ "$got" = "$want" ]; then ok; else bad "$desc (wanted rc $want, got $got)"; fi
}

# --- nothing may be spent before convergence is defined ----------------------
rc 1 "an undeclared run cannot authorize spend" -- "$SPARK" budget check --run u1 --kind full
OUT="$("$SPARK" budget check --run u1 --kind full 2>&1 || true)"
assert_contains "the refusal says why" "no declared convergence condition" "$OUT"

rc 1 "a budget without a convergence condition is refused" -- \
  "$SPARK" budget declare --run u1 --max-full-suite 5
assert_contains "and says budgets do not define finishing" "they do not tell it what finishing means" \
  "$("$SPARK" budget declare --run u1 --max-full-suite 5 2>&1 || true)"

# --- the converging run ------------------------------------------------------
"$SPARK" budget declare --run c1 --convergence "full suite green" \
  --max-full-suite 6 --max-no-progress 1 >/dev/null

FIRST="$("$SPARK" budget record --run c1 --failing 4)"
assert_contains "a first failing set has no invented trend" "first record" "$FIRST"
assert_contains "and reports no trend yet" "NOT ASSESSED" "$("$SPARK" budget status --run c1)"

rc 0 "the first full verification proceeds" -- "$SPARK" budget check --run c1 --kind full
"$SPARK" budget record --run c1 --failing 2 >/dev/null
assert_contains "a shrinking failing set is reported as such" "yes (4 -> 2)" \
  "$("$SPARK" budget status --run c1)"
rc 0 "a run making progress continues" -- "$SPARK" budget check --run c1 --kind full

# A successful final verification ends the loop, and says so with its own exit
# code so a caller cannot mistake "finished" for "keep going".
"$SPARK" budget record --run c1 --failing 0 >/dev/null
rc 4 "an empty failing set terminates the loop" -- "$SPARK" budget check --run c1 --kind full
assert_contains "convergence is reported against the declared condition" "CONVERGED — full suite green" \
  "$("$SPARK" budget check --run c1 --kind full 2>&1 || true)"

# --- repeated expensive work with nothing material changed -------------------
"$SPARK" budget declare --run n1 --convergence "green" --max-no-progress 1 >/dev/null
"$SPARK" budget record --run n1 --failing 3 >/dev/null
rc 0 "the first expensive verification is fine" -- "$SPARK" budget check --run n1 --kind full
WARN="$("$SPARK" budget check --run n1 --kind full 2>&1 || true)"
assert_contains "an unchanged repeat is flagged, not silently allowed" "no material change" "$WARN"
rc 3 "a third identical verification escalates" -- "$SPARK" budget check --run n1 --kind full
ESC="$("$SPARK" budget check --run n1 --kind full 2>&1 || true)"
assert_contains "escalation explains the futility" "will buy the same answer" "$ESC"

# The point of the fixture: it stops with the resource budget almost untouched.
# Convergence, not spend, is what ended it.
"$SPARK" budget declare --run n2 --convergence "green" --max-no-progress 1 \
  --max-wall-seconds 99999 --max-tool-calls 99999 >/dev/null
"$SPARK" budget record --run n2 --failing 7 >/dev/null
"$SPARK" budget check --run n2 --kind full >/dev/null 2>&1 || true
"$SPARK" budget check --run n2 --kind full >/dev/null 2>&1 || true
rc 3 "a stalled run stops even with budget to spare" -- "$SPARK" budget check --run n2 --kind full

# --- a hard boundary stops, and never launders the failure -------------------
"$SPARK" budget declare --run h1 --convergence "green" --max-full-suite 1 >/dev/null
"$SPARK" budget record --run h1 --failing 5 >/dev/null
"$SPARK" budget check --run h1 --kind full >/dev/null 2>&1
"$SPARK" budget record --run h1 --failing 3 >/dev/null
rc 2 "a hard bound stops the run" -- "$SPARK" budget check --run h1 --kind full
STOP="$("$SPARK" budget check --run h1 --kind full 2>&1 || true)"
assert_contains "the stop names the bound"            "full-suite verifications (1 of 1)" "$STOP"
assert_contains "the stop still reports what is failing" "remaining failing set: 3" "$STOP"
assert_contains "a budget never clears the work"      "never clears it" "$STOP"
case "$STOP" in *PASS*|*CONVERGED*) bad "a budget stop must never read as success" ;; *) ok ;; esac

# --- targeted checks are the cheap half, so their bound is a soft signal ------
"$SPARK" budget declare --run s1 --convergence "green" --max-targeted 1 >/dev/null
"$SPARK" budget record --run s1 --failing 6 >/dev/null
rc 0 "a targeted check inside the bound proceeds" -- "$SPARK" budget check --run s1 --kind targeted
"$SPARK" budget record --run s1 --failing 2 >/dev/null
SOFT="$("$SPARK" budget check --run s1 --kind targeted 2>&1 || true)"
assert_contains "crossing a soft signal while converging continues" "PROCEED (over soft signal)" "$SOFT"
assert_contains "and shows the movement that justified it" "6 -> 2" "$SOFT"

# Movement is measured since the LAST TARGETED CHECK. Comparing against the
# last recorded set instead lets one improvement authorize an unlimited tail.
rc 2 "coasting on an earlier improvement stops" -- "$SPARK" budget check --run s1 --kind targeted
assert_contains "the soft stop reports its failing set too" "remaining failing set: 2" \
  "$("$SPARK" budget check --run s1 --kind targeted 2>&1 || true)"

# --- the facts come from the run's own telemetry record (#574) ---------------
"$SPARK" budget declare --run t1 --convergence "green" --max-tool-calls 50 >/dev/null
"$SPARK" budget record --run t1 --failing 1 >/dev/null
rc 0 "with no telemetry the tool-call bound cannot bind" -- "$SPARK" budget check --run t1 --kind full
"$SPARK" telemetry record --run t1 tool_calls=120 >/dev/null 2>&1
rc 2 "a bound binds against the recorded facts" -- "$SPARK" budget check --run t1 --kind full
assert_contains "the stop names the measured overrun" "tool calls (120 of 50)" \
  "$("$SPARK" budget check --run t1 --kind full 2>&1 || true)"

# An undeclared bound is not a bound of zero. Treating absence as a limit would
# stop every run that declined to guess a number.
"$SPARK" budget declare --run t2 --convergence "green" >/dev/null
"$SPARK" budget record --run t2 --failing 1 >/dev/null
"$SPARK" telemetry record --run t2 tool_calls=99999 wall_seconds=99999 >/dev/null 2>&1
rc 0 "an undeclared bound does not stop the run" -- "$SPARK" budget check --run t2 --kind full

# --- a per-request provider cap is not the episode budget --------------------
"$SPARK" budget declare --run p1 --convergence "green" --per-request-output-cap 8000 >/dev/null
assert_contains "the cap is reported apart from the envelope" "bounds one request, not this run" \
  "$("$SPARK" budget status --run p1)"
n=5
while [ "$n" -gt 0 ]; do
  "$SPARK" budget record --run p1 --failing "$n" >/dev/null
  "$SPARK" budget check --run p1 --kind full >/dev/null 2>&1 || true
  n=$((n - 1))
done
# Five verifications ran under a declared per-request cap: it never bounded the
# episode, which is exactly the confusion the issue calls out.
assert_contains "a per-request cap does not bound a multi-request episode" "full verifications         5" \
  "$("$SPARK" budget status --run p1)"

# --- new release-critical evidence may deliberately reopen work --------------
rc 1 "reopening without stated evidence is refused" -- "$SPARK" budget reopen --run n1
REO="$("$SPARK" budget reopen --run n1 --reason "release-critical: ledger truth fails on tag" 2>&1)"
assert_contains "a reopen is announced, never silent" "REOPENED (#1)" "$REO"
assert_contains "and does not absolve the existing failures" "does not clear old findings" "$REO"
assert_contains "the reason is recorded for the operator" "ledger truth fails on tag" \
  "$("$SPARK" budget status --run n1)"
rc 0 "a deliberate reopen clears the no-progress escalation" -- "$SPARK" budget check --run n1 --kind full
assert_contains "reopening never resets the failing set" "known failing set          3" \
  "$("$SPARK" budget status --run n1)"

# --- machine shape -----------------------------------------------------------
J="$("$SPARK" budget status --run c1 --json)"
assert_contains "json separates what was declared" '"convergence":"full suite green"' "$J"
assert_contains "json carries the run state"       '"failing":0' "$J"
assert_contains "json nulls an undeclared bound"   '"max_tool_calls":null' "$J"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$J" | jq empty >/dev/null 2>&1 && ok || bad "--json must emit valid JSON"
else ok; fi

# --- the documented model ----------------------------------------------------
DOC="$repo_root/docs/ops/bounded-execution.md"
[ -f "$DOC" ] && ok || bad "the bounded-execution model must be documented at docs/ops/bounded-execution.md"
if [ -f "$DOC" ]; then
  assert_contains "the model names its escalation boundary" "ESCALATE" "$(cat "$DOC")"
fi

# --- MUTATION CONTROL --------------------------------------------------------
# Remove the escalation: let a stalled run keep buying the same verification.
# The no-progress fixture must go red — that boundary is the whole issue.
MUT="$WORK/plugin/bin/spark-mutant"
sed 's|if \[ "${bgv_no_progress_runs}" -gt "${bgv_max_no_progress:-$BUDGET_DEFAULT_NO_PROGRESS}" \]; then|if false; then|' "$SPARK" > "$MUT"
chmod +x "$MUT"
if ! cmp -s "$SPARK" "$MUT"; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

"$SPARK" budget declare --run m1 --convergence "green" --max-no-progress 1 >/dev/null
"$SPARK" budget record --run m1 --failing 3 >/dev/null
"$MUT" budget check --run m1 --kind full >/dev/null 2>&1 || true
"$MUT" budget check --run m1 --kind full >/dev/null 2>&1 || true
mgot=0
"$MUT" budget check --run m1 --kind full >/dev/null 2>&1 || mgot=$?
if [ "$mgot" = "3" ]; then
  bad "MUTATION control — the stalled run still escalated, so the fixture does not discriminate"
else ok; fi

finish
