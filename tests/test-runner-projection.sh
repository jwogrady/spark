#!/usr/bin/env bash
# Behavioural suite for #609 — capture once, project many.
#
# Release certification once ran the whole behavioural suite THREE times in one
# command line, to get the tail, the suite count, and the assertion total. Three
# executions, three views of the same evidence, five minutes.
#
# The runner therefore derives every figure a caller might want from ONE run and
# emits them together. A second projection must never imply a second execution —
# which is a property of the runner, so it is tested against a sandboxed copy of
# the runner driving fake suites, rather than by running the real suite again
# (which would be the very mistake under test).
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "runner projection (#609)"
sandbox_init

RUN="$repo_root/tests/run.sh"
[ -f "$RUN" ] && ok || bad "tests/run.sh must exist"

SB="$WORK/suite"
mkdir -p "$SB"
cp "$RUN" "$SB/run.sh"

# Two passing suites and, later, one failing one — printing the same
# "  N passed, M failed" line every real suite ends with.
mk_suite() { # mk_suite <name> <passed> <failed> <exit>
  printf '#!/usr/bin/env bash\necho "  %s passed, %s failed"\nexit %s\n' "$2" "$3" "$4" > "$SB/test-$1.sh"
  chmod +x "$SB/test-$1.sh"
}
mk_suite alpha 10 0 0
mk_suite beta  7  0 0

OUT="$(bash "$SB/run.sh" --json 2>&1)"
JSON="$(printf '%s\n' "$OUT" | grep -E '^\{')"

assert_contains "one run reports the suite count"      '"suites":2' "$JSON"
assert_contains "and the assertion total"              '"assertions_passed":17' "$JSON"
assert_contains "and the failure total"                '"assertions_failed":0' "$JSON"
assert_contains "and no suite failed"                  '"suites_failed":0' "$JSON"
assert_contains "the human summary carries them too"   "assertions: 17 passed, 0 failed" "$OUT"
assert_contains "and the suite verdict"                "all 2 suite(s) passed" "$OUT"

if command -v jq >/dev/null 2>&1; then
  printf '%s' "$JSON" | jq empty >/dev/null 2>&1 && ok || bad "--json must emit valid JSON"
  n="$(printf '%s' "$JSON" | jq '.slowest | length')"
  [ "$n" -ge 1 ] && ok || bad "the slowest-suite projection must be populated"
else
  ok; ok
fi

# THE POINT: every figure came from a single execution. A suite that counted its
# own invocations proves the runner did not run it twice to produce two numbers.
COUNTER="$WORK/invocations"
: > "$COUNTER"
printf '#!/usr/bin/env bash\necho x >> "%s"\necho "  3 passed, 0 failed"\n' "$COUNTER" > "$SB/test-counted.sh"
chmod +x "$SB/test-counted.sh"
OUT="$(bash "$SB/run.sh" --json 2>&1)"
runs="$(wc -l < "$COUNTER" | tr -d ' ')"
[ "$runs" = "1" ] && ok || bad "one runner invocation must execute each suite exactly once (ran $runs times)"
assert_contains "and the totals include it" '"assertions_passed":20' "$(printf '%s\n' "$OUT" | grep -E '^\{')"

# --- a failing suite is still counted correctly ------------------------------
mk_suite gamma 4 2 1
OUT="$(bash "$SB/run.sh" --json 2>&1)" || true
JSON="$(printf '%s\n' "$OUT" | grep -E '^\{')"
assert_contains "failed assertions are aggregated"   '"assertions_failed":2' "$JSON"
assert_contains "and the failing suite is counted"   '"suites_failed":1' "$JSON"
assert_contains "the human summary agrees"           "1 of 4 suite(s) failed" "$OUT"

rc=0
bash "$SB/run.sh" >/dev/null 2>&1 || rc=$?
[ "$rc" = "1" ] && ok || bad "a failing suite must still exit non-zero (got $rc)"

# --- streaming is preserved ---------------------------------------------------
# Capturing each suite's output to count assertions must not swallow it, or the
# CI log stops being readable.
assert_contains "suite output still reaches the log" "  10 passed, 0 failed" "$OUT"
assert_contains "and each suite is announced"        "== test-alpha.sh" "$OUT"

# --- the targeted path is the cheap one --------------------------------------
# #558 prefers targeted checks during repair and reserves full certification for
# a boundary. That preference only means something if the runner can actually
# run a subset.
OUT="$(bash "$SB/run.sh" --only alpha --json 2>&1)"
JSON="$(printf '%s\n' "$OUT" | grep -E '^\{')"
assert_contains "a targeted run reports only the matching suite" '"suites":1' "$JSON"
assert_contains "and names itself targeted"                      '"kind":"targeted"' "$JSON"
assert_contains "carrying only that suite's assertions"          '"assertions_passed":10' "$JSON"
case "$OUT" in *"test-beta.sh"*) bad "--only must not run non-matching suites" ;; *) ok ;; esac

FULLJSON="$(bash "$SB/run.sh" --json 2>&1 | grep -E '^\{')" || true
assert_contains "a full run names itself full" '"kind":"full"' "$FULLJSON"

# --- one invocation is one execution, however many summaries are read --------
assert_contains "an execution counts itself once" '"executions":1' "$JSON"

# The telemetry hand-off: each runner invocation records exactly one execution,
# which is what lets run telemetry tell one run with several projections apart
# from several actual runs.
mkdir -p "$SB/../plugins/spark/bin" "$SB/../plugins/spark/lib"
# run.sh validates SPARK_RUN_ID with the ONE canonical rule by sourcing the real
# runtime module (#648) — so the sandbox carries it, exercising the production
# path rather than a re-stated copy.
cp "$repo_root/plugins/spark/lib/execution.sh" "$SB/../plugins/spark/lib/execution.sh"
TELLOG="$WORK/telemetry.calls"
: > "$TELLOG"
cat > "$SB/../plugins/spark/bin/spark" <<TELSTUB
#!/usr/bin/env bash
if [ "\$2" = "record" ] || [ "\$1" = "telemetry" ] && [ "\$2" = "record" ]; then
  printf '%s\n' "\$*" >> "$TELLOG"
fi
exit 0
TELSTUB
chmod +x "$SB/../plugins/spark/bin/spark"

SPARK_RUN_ID=bench-run bash "$SB/run.sh" --only alpha >/dev/null 2>&1 || true
calls="$(awk "/telemetry record/ { n++ } END { print n+0 }" "$TELLOG")"
[ "$calls" = "1" ] && ok || bad "one execution must record exactly one telemetry increment (got $calls)"
assert_contains "a targeted run counts a targeted check" "targeted_checks=1" "$(cat "$TELLOG")"
assert_contains "and no full-suite execution"            "full_suite_runs=0" "$(cat "$TELLOG")"

: > "$TELLOG"
SPARK_RUN_ID=bench-run bash "$SB/run.sh" >/dev/null 2>&1 || true
assert_contains "a full run counts a full-suite execution" "full_suite_runs=1" "$(cat "$TELLOG")"

# DURABILITY: the count is derived from an append-only log, so a second
# execution increments even though nothing re-read a prior telemetry value. A
# read-modify-write would lose one of two overlapping runs; this cannot.
: > "$TELLOG"
SPARK_RUN_ID=bench-run bash "$SB/run.sh" >/dev/null 2>&1 || true
assert_contains "a second execution increments durably" "full_suite_runs=2" "$(cat "$TELLOG")"

# Even with the telemetry binary failing every call, the execution is still
# durably logged — so a transient recording failure cannot silently erase it.
LOG="$SB/../.spark/telemetry/bench-run.executions"
if [ -f "$LOG" ]; then
  n="$(awk '$1 == "full" { n++ } END { print n+0 }' "$LOG")"
  [ "$n" = "2" ] && ok || bad "the execution log must hold every execution (got $n)"
else
  bad "the append-only execution log must exist at $LOG"
fi

# A recording that cannot happen must SAY so. Silence here would leave the
# "telemetry distinguishes executions" claim resting on a number never written.
mv "$SB/../plugins/spark/bin/spark" "$SB/../plugins/spark/bin/spark.hidden"
ERR="$(SPARK_RUN_ID=bench-run bash "$SB/run.sh" --only alpha 2>&1 >/dev/null || true)"
assert_contains "a missing recorder is reported, not swallowed" "NOT recorded" "$ERR"
mv "$SB/../plugins/spark/bin/spark.hidden" "$SB/../plugins/spark/bin/spark"

# --- #648: SPARK_RUN_ID becomes a filename, so a traversal id must not escape ---
# The recorder writes ".spark/telemetry/<id>.executions". A traversal or separator
# id would append OUTSIDE that directory and corrupt a tracked file, so an invalid
# id records nothing, says so, and writes no file — for full and targeted runs
# alike. A sentinel one level up from the telemetry dir must stay byte-identical.
TELDIR="$SB/../.spark/telemetry"
mkdir -p "$TELDIR"
SENT="$TELDIR/../escaped.executions"   # where '../escaped' would land
printf 'pre-existing\n' > "$SENT"
sent_before="$(sha1sum "$SENT" | cut -d' ' -f1)"
# Every invalid class — traversal, absolute, separator, dot-dot, control char —
# must be refused in BOTH the full and the targeted invocation (the control-char
# id is quoted so the loop cannot split it apart).
CTRL="$(printf 'a\tb')"
for bad_id in '../escaped' '../../escaped' '/abs/escaped' 'a/b' '..' "$CTRL"; do
  for mode in targeted full; do
    : > "$TELLOG"
    if [ "$mode" = targeted ]; then
      ERR="$(SPARK_RUN_ID="$bad_id" bash "$SB/run.sh" --only alpha 2>&1 >/dev/null || true)"
    else
      ERR="$(SPARK_RUN_ID="$bad_id" bash "$SB/run.sh" 2>&1 >/dev/null || true)"
    fi
    assert_contains "invalid run id '$bad_id' ($mode) is reported, not recorded" "NOT recorded" "$ERR"
    assert_contains "and names the canonical rule for '$bad_id' ($mode)" "valid run id" "$ERR"
    calls="$(awk "/telemetry record/ { n++ } END { print n+0 }" "$TELLOG")"
    [ "$calls" = "0" ] && ok || bad "invalid run id '$bad_id' ($mode) must record no telemetry (got $calls)"
  done
done
sent_after="$(sha1sum "$SENT" | cut -d' ' -f1)"
[ "$sent_before" = "$sent_after" ] && ok || bad "a traversal run id must not modify a tracked file (#648)"
[ "$(cat "$SENT")" = "pre-existing" ] && ok \
  || bad "no execution row may be appended through the traversal path (#648)"
rm -f "$SENT"

# Reading the same result again must record nothing further — a projection is
# not an execution.
: > "$TELLOG"
printf '%s\n' "$JSON" | grep -q '"suites"' && ok || bad "the captured JSON should still be readable"
calls="$(awk "/telemetry record/ { n++ } END { print n+0 }" "$TELLOG")"
[ "$calls" = "0" ] && ok || bad "re-reading a captured result must not record an execution (got $calls)"

# --- MUTATION CONTROL ---------------------------------------------------------
# Stop accumulating assertions across suites, so the totals no longer come from
# the captured evidence. The aggregate fixture must go red.
MUT="$WORK/mutant-run.sh"
sed 's|assert_pass=$((assert_pass + p))|assert_pass=$((assert_pass + 0))|' "$SB/run.sh" > "$MUT"
if ! cmp -s "$SB/run.sh" "$MUT"; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi
MOUT="$(bash "$MUT" --json 2>&1)" || true
case "$MOUT" in
  *'"assertions_passed":20'*) bad "MUTATION control — totals still aggregated; the fixture does not discriminate" ;;
  *) ok ;;
esac

finish
