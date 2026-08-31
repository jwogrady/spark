#!/usr/bin/env bash
# Behavioural suite for #574 — run telemetry as a by-product of execution.
#
# The contract under test is not "we print some numbers". It is that the record
# is CHEAP TO PRODUCE, HONEST ABOUT WHAT IT DOES NOT KNOW, and INCAPABLE of
# swallowing the evidence it is supposed to link:
#
#   * no model call and no remote read is needed to record a fact the executing
#     process already knows — asserted by a `gh` stub that logs every call;
#   * an unrecorded metric reports NOT ASSESSED, never a guess and never a zero;
#   * a raw prompt, transcript, diff or log has no key to live under and no room
#     to fit, so the "link deep evidence" rule is enforced, not requested;
#   * a run bound to a superseded commit says so, because telemetry about code
#     that is no longer under review is worse than none.
#
# The mutation control at the end removes the schema allowlist and requires the
# leak fixture to go red — the guarantee has to come from the guard, not from
# callers happening to behave.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "run telemetry (#574)"
sandbox_init
make_repo "$WORK/proj"
cd "$WORK/proj"

# A `gh` stub that records every invocation. Telemetry must never need it to
# write a fact the caller already handed it.
mkdir -p "$WORK/bin"
export GH_CALL_LOG="$WORK/gh.calls"
export GH_HEAD_FILE="$WORK/gh.head"
: > "$GH_CALL_LOG"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
printf '%s\n' "$*" >> "$GH_CALL_LOG"
if [ -s "$GH_HEAD_FILE" ]; then cat "$GH_HEAD_FILE"; exit 0; fi
exit 1
STUB
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"

FULL="pr=638 head_sha=0acd721 attempt=1 trigger=pull_request
      provider=anthropic model=claude-opus-5 effort=high
      routing_reason=cross-cutting-judgment
      preflight_tokens=12000 input_tokens=11840 output_tokens=2100
      cache_write_tokens=9000 cache_read_tokens=27000 tool_schema_tokens=4200
      cost_usd=0.42 wall_seconds=186
      tool_calls=34 api_requests=12 full_suite_runs=1 targeted_checks=8
      iterations=2 batch_usage=none compaction_events=1
      context_before=180000 context_after=96000
      failing_before=3 failing_after=0 verdict=PASS
      actions_run=https://github.com/jwogrady/spark/actions/runs/33331136498"

# --- a complete record -------------------------------------------------------
if "$SPARK" telemetry record --run r1 $FULL >/dev/null 2>&1; then ok
else bad "recording a complete run must succeed"; fi

[ -f "$WORK/proj/.spark/telemetry/r1.tsv" ] && ok || bad "the record must land under .spark/telemetry"

# No remote read is needed to write a fact the caller already knows. This is the
# whole "observability must not cost what it measures" claim, made checkable.
if [ ! -s "$GH_CALL_LOG" ]; then ok
else bad "recording telemetry called gh: $(cat "$GH_CALL_LOG")"; fi

SHOW="$("$SPARK" telemetry show --run r1 --head 0acd721)"
assert_contains "the summary is bound to the exact head sha" "0acd721" "$SHOW"
assert_contains "a matching live head reads as current"      "current" "$SHOW"
assert_contains "effort sits beside the outcome"             "high"    "$SHOW"
assert_contains "the model is named"                         "claude-opus-5" "$SHOW"
assert_contains "the escalation reason is visible"           "cross-cutting-judgment" "$SHOW"
assert_contains "cost is reported"                           "0.42"    "$SHOW"
assert_contains "wall time is reported"                      "186"     "$SHOW"
assert_contains "the preflight estimate is comparable with actual input" "12000" "$SHOW"
assert_contains "tool-schema tokens are measurable"          "4200"    "$SHOW"
assert_contains "the derived cache hit ratio is shown"       "75.0%"   "$SHOW"
assert_contains "context change is derived, not restated"    "-84000"  "$SHOW"
assert_contains "the failing set change is derived"          "-3"      "$SHOW"
assert_contains "the verdict is reported"                    "PASS"    "$SHOW"
assert_contains "deep evidence is linked, not copied"        "never copies it" "$SHOW"

# --- machine shape -----------------------------------------------------------
J="$("$SPARK" telemetry show --run r1 --json --head 0acd721)"
assert_contains "json carries the derived block"   '"cache_hit_ratio":"75.0%"' "$J"
assert_contains "json emits counters as numbers"   '"input_tokens":11840' "$J"
assert_contains "json emits unrecorded fields as null" '"cache_reason":null' "$J"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$J" | jq empty >/dev/null 2>&1 && ok || bad "--json must emit valid JSON"
else
  ok
fi

# --- what is unknown stays unknown -------------------------------------------
"$SPARK" telemetry record --run r2 pr=1 head_sha=abc123 >/dev/null 2>&1
SPARSE="$("$SPARK" telemetry show --run r2 --head abc123)"
assert_contains "an unrecorded cost is NOT ASSESSED, never zero" "estimated cost USD       NOT ASSESSED" "$SPARSE"
assert_contains "a ratio with no cache evidence is NOT ASSESSED" "cache hit ratio          NOT ASSESSED" "$SPARSE"

# Half the evidence is still not a ratio: a cache figure derived from one side
# would read as a measurement.
"$SPARK" telemetry record --run r3 cache_read_tokens=100 >/dev/null 2>&1
assert_contains "a one-sided cache figure yields no ratio" "cache hit ratio          NOT ASSESSED" \
  "$("$SPARK" telemetry show --run r3)"

# A cold run is a real 0.0%, not an unknown — miss and rebuild must be tellable
# apart from "the provider did not say".
"$SPARK" telemetry record --run r4 cache_read_tokens=0 cache_write_tokens=8000 \
  cache_reason=first-turn-of-a-new-prefix >/dev/null 2>&1
COLD="$("$SPARK" telemetry show --run r4)"
assert_contains "a cache miss reports 0.0%, distinct from unknown" "0.0%" "$COLD"
assert_contains "the rebuild cause is carried" "first-turn-of-a-new-prefix" "$COLD"

# --- staleness ---------------------------------------------------------------
assert_contains "a moved head marks the record superseded" "superseded — the live head is deadbee" \
  "$("$SPARK" telemetry show --run r1 --head deadbee)"

# An unreadable live head is an unknown. It must never resolve to "current" —
# that would silently promote stale telemetry to current evidence.
: > "$GH_HEAD_FILE"
BLIND="$("$SPARK" telemetry show --run r1)"
assert_contains "an unreadable live head is NOT ASSESSED, not current" \
  "NOT ASSESSED — the live head could not be read" "$BLIND"

printf '0acd721\n' > "$GH_HEAD_FILE"
assert_contains "a readable live head resolves the binding" "current" \
  "$("$SPARK" telemetry show --run r1)"
: > "$GH_HEAD_FILE"

"$SPARK" telemetry record --run r5 pr=9 >/dev/null 2>&1
assert_contains "a record with no head sha cannot claim to be current" \
  "NOT ASSESSED — no head_sha recorded" "$("$SPARK" telemetry show --run r5)"

# --- repeated expensive work with no progress (the #558 signal) --------------
"$SPARK" telemetry record --run r6 full_suite_runs=3 failing_before=2 failing_after=2 >/dev/null 2>&1
assert_contains "repeated full suites over a static failing set are visible" \
  "yes — 3 full-suite runs left the failing set at 2" "$("$SPARK" telemetry show --run r6)"

"$SPARK" telemetry record --run r7 full_suite_runs=3 failing_before=5 failing_after=1 >/dev/null 2>&1
assert_contains "repeated suites that shrink the failing set are progress" \
  "repeated, no progress    no" "$("$SPARK" telemetry show --run r7)"

"$SPARK" telemetry record --run r8 full_suite_runs=3 >/dev/null 2>&1
assert_contains "no-progress cannot be asserted without the failing set" \
  "repeated, no progress    NOT ASSESSED" "$("$SPARK" telemetry show --run r8)"

# --- the verdict vocabulary is closed ----------------------------------------
"$SPARK" telemetry record --run r9 verdict="DECISION REQUIRED" >/dev/null 2>&1
assert_contains "a run may stop at DECISION REQUIRED" "DECISION REQUIRED" \
  "$("$SPARK" telemetry show --run r9)"

if "$SPARK" telemetry record --run r9 verdict=MAYBE >/dev/null 2>&1; then
  bad "an unknown verdict must be refused"
else ok; fi

# --- the observability cost contract, enforced -------------------------------
# Each of these is a way a transcript, diff or log could have entered the stream.
if "$SPARK" telemetry record --run r1 transcript=hello >/dev/null 2>&1; then
  bad "a key outside the schema must be refused"
else ok; fi

BIG="$(head -c 400 /dev/zero | tr '\0' 'x')"
if "$SPARK" telemetry record --run r1 "routing_reason=$BIG" >/dev/null 2>&1; then
  bad "an oversize value must be refused — deep evidence is linked, not pasted"
else ok; fi

if "$SPARK" telemetry record --run r1 "cache_reason=line one
line two" >/dev/null 2>&1; then
  bad "a multi-line value must be refused"
else ok; fi

if "$SPARK" telemetry record --run r1 tool_calls=lots >/dev/null 2>&1; then
  bad "a counter that is not a number must be refused"
else ok; fi

# --- secrets never reach a published surface ---------------------------------
if "$SPARK" telemetry record --run r1 routing_reason=ghp_0123456789abcdefghijklmnopqrstuvwxyz >/dev/null 2>&1; then
  bad "a GitHub-token-shaped value must be refused"
else ok; fi

if "$SPARK" telemetry record --run r1 trigger=AKIAIOSFODNN7EXAMPLE >/dev/null 2>&1; then
  bad "an AWS-key-shaped value must be refused"
else ok; fi

if "$SPARK" telemetry record --run r1 cache_reason="sk-ant-abc123" >/dev/null 2>&1; then
  bad "an API-key-shaped value must be refused"
else ok; fi

# A refused record leaves the previous one intact — failing closed must not also
# destroy the evidence already gathered.
assert_contains "a refused write does not corrupt the existing record" "PASS" \
  "$("$SPARK" telemetry show --run r1 --head 0acd721)"

# --- unchanged facts are referenced, not restated ----------------------------
"$SPARK" telemetry record --run r1 tool_calls=40 >/dev/null 2>&1
DUP="$(awk -F'\t' '$1 == "tool_calls"' "$WORK/proj/.spark/telemetry/r1.tsv" | wc -l | tr -d ' ')"
[ "$DUP" = "1" ] && ok || bad "re-recording a field must supersede it, not append a second truth (got $DUP lines)"
assert_contains "the superseding value is the one reported" "40" \
  "$("$SPARK" telemetry show --run r1 --head 0acd721)"

# --- the relay projection ----------------------------------------------------
RELAY="$("$SPARK" telemetry relay --run r1 --head 0acd721)"
assert_contains "the projection names the PR"          "PR #638" "$RELAY"
assert_contains "the projection links the Actions run" "actions/runs/33331136498" "$RELAY"
assert_contains "the projection carries the outcome"   "PASS" "$RELAY"
assert_contains "the projection disclaims authority"   "not itself authority" "$RELAY"
assert_contains "the projection reports staleness too" "superseded" \
  "$("$SPARK" telemetry relay --run r1 --head deadbee)"

# --- comparing two runs without reading a log --------------------------------
CMP="$("$SPARK" telemetry compare r1 r6)"
assert_contains "comparison names both runs"        "r1 vs r6" "$CMP"
assert_contains "comparison derives a signed delta" "+2" "$CMP"
if "$SPARK" telemetry compare r1 nosuchrun >/dev/null 2>&1; then
  bad "comparing against a run with no record must fail"
else ok; fi

assert_contains "list reports each run's verdict" "r6" "$("$SPARK" telemetry list)"

# --- the run id becomes a filename -------------------------------------------
if "$SPARK" telemetry record --run ../escape tool_calls=1 >/dev/null 2>&1; then
  bad "a run id that escapes the telemetry directory must be refused"
else ok; fi

# --- the baseline this issue requires ----------------------------------------
# "Record these metrics before optimization so later claims are comparative
# rather than anecdotal" — the baseline is a committed provenance record, so its
# absence is a test failure, not a missing nicety.
BASELINE="$repo_root/docs/ops/telemetry-baseline.md"
[ -f "$BASELINE" ] && ok || bad "the pre-optimization baseline record must exist at docs/ops/telemetry-baseline.md"
if [ -f "$BASELINE" ]; then
  assert_contains "the baseline names the run it measured" "spark telemetry" "$(cat "$BASELINE")"
fi

# --- MUTATION CONTROL --------------------------------------------------------
# Remove the schema allowlist — the one guard standing between the telemetry
# stream and a pasted transcript. The leak fixture must go red.
mutant_runtime 's|if ! tm_is_key "$key"; then|if false; then|'
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi

if "$MUT" telemetry record --run mut transcript=hello >/dev/null 2>&1; then ok
else bad "MUTATION control — the leak fixture stayed green without the allowlist, so it does not discriminate"; fi

finish
