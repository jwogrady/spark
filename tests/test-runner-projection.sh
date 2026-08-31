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
