#!/usr/bin/env bash
# Regression contract for #665 — concurrent runners must not let a stale
# telemetry writer move execution counters backward after the append-only log
# has already recorded newer truth.
#
# The fix makes "read the log, publish it" one indivisible step per run id (an
# mkdir-based mutual-exclusion boundary in tests/run.sh), so publishes for a
# run id are totally ordered and none can land after a fresher one and regress
# it. Each scenario below forces one runner to read the log, then get
# deliberately delayed while STILL HOLDING the publish lock, and only then
# write — proving the delayed write can never be the LAST one on the wire once
# fresher runners have gone through the same boundary, however many of them
# overlap or whichever mix of full/targeted kinds they are.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "execution count race (#665)"
sandbox_init

RUN="$repo_root/tests/run.sh"
SB="$WORK/suite"
mkdir -p "$SB" "$SB/../plugins/spark/bin" "$SB/../plugins/spark/lib"
cp "$RUN" "$SB/run.sh"
cp "$repo_root/plugins/spark/lib/execution.sh" "$SB/../plugins/spark/lib/execution.sh"

cat > "$SB/test-alpha.sh" <<'SUITE'
#!/usr/bin/env bash
echo "  1 passed, 0 failed"
SUITE
chmod +x "$SB/test-alpha.sh"

TELLOG="$WORK/telemetry.calls"
READY="$WORK/delayed-ready"
GO="$WORK/delayed-go"

# A stub `spark` whose ONLY special behaviour is: the invocation carrying
# RACE_ROLE=delay signals it has been dispatched (proving it already holds
# run.sh's publish lock and has read the log), then blocks until the test
# releases it — simulating a slow backend write that lands long after it was
# read. Every call, delayed or not, is logged in the order it actually wrote.
cat > "$SB/../plugins/spark/bin/spark" <<STUB
#!/usr/bin/env bash
set -eu
case "\$*" in
  *"telemetry record"*)
    if [ "\${RACE_ROLE:-}" = "delay" ]; then
      : > "$READY"
      i=0
      while [ ! -f "$GO" ] && [ "\$i" -lt 500 ]; do
        sleep 0.01
        i=\$((i + 1))
      done
      [ -f "$GO" ] || exit 97
    fi
    printf '%s\n' "\$*" >> "$TELLOG"
    ;;
esac
exit 0
STUB
chmod +x "$SB/../plugins/spark/bin/spark"

# log_count <log> <kind> — durable append-only truth for one kind. A log that
# does not exist yet (nothing has appended) durably counts as zero.
log_count() {
  [ -f "$1" ] || { echo 0; return; }
  awk -F'\t' -v k="$2" '$1 == k { n++ } END { print n+0 }' "$1"
}

# last_value <key> — the value <key>= carried on the LAST telemetry record
# call in $TELLOG. This is the published projection a caller would actually
# read; the discriminating claim is that it can never sit below durable truth.
last_value() {
  awk -v k="$1=" '{ for (i = 1; i <= NF; i++) if (index($i, k) == 1) v = substr($i, length(k) + 1) } END { print v + 0 }' "$TELLOG"
}

# launch_runner <run-id> <kind> [role] — backgrounds one run.sh invocation of
# the given kind (targeted via --only, full otherwise) and records its PID.
# Must run in the CURRENT shell (never inside a command substitution) or `$!`
# would name a subshell's child instead of one this script can wait() on.
launch_runner() {
  local run_id="$1" kind="$2" role="${3:-}"
  if [ "$kind" = targeted ]; then
    RACE_ROLE="$role" SPARK_RUN_ID="$run_id" bash "$SB/run.sh" --only alpha >/dev/null 2>&1 &
  else
    RACE_ROLE="$role" SPARK_RUN_ID="$run_id" bash "$SB/run.sh" >/dev/null 2>&1 &
  fi
  pids+=("$!")
}

# race_scenario <run-id> <delayed-kind> <other-kind>... — the delayed runner
# is launched and confirmed blocked (holding the publish lock) BEFORE any
# other runner starts, so every other runner's own publish attempt is
# provably queued on that same lock, not merely slower to reach it. Appends
# are independent of the lock, so durable truth still reaches its final size
# while the delayed runner sits blocked — proving the others were genuinely
# waiting to publish, not waiting to even run.
race_scenario() {
  local run_id="$1" delayed="$2"; shift 2
  local others=("$@")
  local log="$SB/../.spark/telemetry/$run_id.executions"
  : > "$TELLOG"
  rm -f "$READY" "$GO" "$log"
  pids=()

  launch_runner "$run_id" "$delayed" delay
  local i=0
  while [ ! -f "$READY" ] && [ "$i" -lt 500 ]; do
    sleep 0.01
    i=$((i + 1))
  done
  [ -f "$READY" ] && ok || bad "$run_id: the delayed runner must reach the publish barrier"

  local kind
  for kind in "${others[@]}"; do
    launch_runner "$run_id" "$kind"
  done

  local want=$(( ${#others[@]} + 1 )) total
  i=0
  while [ "$i" -lt 500 ]; do
    total=$(( $(log_count "$log" full) + $(log_count "$log" targeted) ))
    [ "$total" -ge "$want" ] && break
    sleep 0.01
    i=$((i + 1))
  done
  total=$(( $(log_count "$log" full) + $(log_count "$log" targeted) ))
  [ "$total" -ge "$want" ] && ok \
    || bad "$run_id: every append must land while the delayed runner still holds the publish lock (got $total of $want)"

  : > "$GO"
  local pid
  for pid in "${pids[@]}"; do wait "$pid" || true; done

  durable_full="$(log_count "$log" full)"
  durable_targ="$(log_count "$log" targeted)"
}

# --- two concurrent full-suite runners ---------------------------------------
race_scenario race-two full full
[ "$durable_full" = "2" ] && ok \
  || bad "race-two: append-only execution truth must preserve both concurrent full runs (got $durable_full)"
assert_contains "race-two: the delayed runner's early, now-stale read is still published when it finally writes" \
  "full_suite_runs=1" "$(head -n 1 "$TELLOG")"
[ "$(last_value full_suite_runs)" = "$durable_full" ] && ok \
  || bad "race-two: published full_suite_runs regressed to $(last_value full_suite_runs) while durable truth is $durable_full"

# --- a third overlapping runner while a stale reconciliation is in flight ---
# This is the exact hole a single post-publication recheck leaves open (#665):
# a third runner can append and publish between that recheck's read and its
# own write landing, so the retry's stale write finishes last. Here the
# delayed runner's write is forced to land only AFTER two fresher full runs
# are already durable — a mechanically safe publish boundary must still let a
# LATER lock holder correct it to the true total.
race_scenario race-three full full full
[ "$durable_full" = "3" ] && ok \
  || bad "race-three: append-only execution truth must preserve all three concurrent full runs (got $durable_full)"
assert_contains "race-three: the delayed runner's stale read of 1 is still published when it finally writes" \
  "full_suite_runs=1" "$(head -n 1 "$TELLOG")"
[ "$(last_value full_suite_runs)" = "$durable_full" ] && ok \
  || bad "race-three: published full_suite_runs regressed to $(last_value full_suite_runs) while durable truth is $durable_full (3-way overlap)"

# --- the mixed concurrent full/targeted case ---------------------------------
# full_suite_runs and targeted_checks are independent counters on the SAME
# published record; a fix that only serializes one of them (or serializes
# publishing without keeping the two kinds apart) would still let one regress
# while the other looks fine.
race_scenario race-mixed full full targeted
[ "$durable_full" = "2" ] && ok \
  || bad "race-mixed: durable full-suite truth must count both full runs (got $durable_full)"
[ "$durable_targ" = "1" ] && ok \
  || bad "race-mixed: durable targeted truth must count the targeted run (got $durable_targ)"
assert_contains "race-mixed: the delayed runner's stale read (1 full, 0 targeted) is still published when it finally writes" \
  "full_suite_runs=1" "$(head -n 1 "$TELLOG")"
assert_contains "race-mixed: and it is honest about not yet seeing the targeted run" \
  "targeted_checks=0" "$(head -n 1 "$TELLOG")"
[ "$(last_value full_suite_runs)" = "$durable_full" ] && ok \
  || bad "race-mixed: published full_suite_runs regressed to $(last_value full_suite_runs) while durable truth is $durable_full"
[ "$(last_value targeted_checks)" = "$durable_targ" ] && ok \
  || bad "race-mixed: published targeted_checks regressed to $(last_value targeted_checks) while durable truth is $durable_targ"

finish
