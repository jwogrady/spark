#!/usr/bin/env bash
# Regression contract for #665 — concurrent runners must not let a stale
# telemetry writer move execution counters backward after the append-only log
# has already recorded newer truth.
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
FIRST="$WORK/first-writer-ready"
SECOND="$WORK/newer-writer-published"
: > "$TELLOG"

# Force the stale-writer interleaving deterministically:
#   A appends and counts 1, then blocks before publishing telemetry.
#   B appends and counts 2, publishes 2, then releases A.
#   A finally publishes its stale absolute count of 1.
cat > "$SB/../plugins/spark/bin/spark" <<STUB
#!/usr/bin/env bash
set -eu
case "\$*" in
  *"telemetry record"*)
    case "\$*" in
      *"full_suite_runs=1"*)
        : > "$FIRST"
        i=0
        while [ ! -f "$SECOND" ] && [ "\$i" -lt 500 ]; do
          sleep 0.01
          i=\$((i + 1))
        done
        [ -f "$SECOND" ] || exit 97
        printf '%s\n' "\$*" >> "$TELLOG"
        ;;
      *)
        printf '%s\n' "\$*" >> "$TELLOG"
        : > "$SECOND"
        ;;
    esac
    ;;
esac
exit 0
STUB
chmod +x "$SB/../plugins/spark/bin/spark"

SPARK_RUN_ID=race bash "$SB/run.sh" >/dev/null 2>&1 &
a_pid=$!

i=0
while [ ! -f "$FIRST" ] && [ "$i" -lt 500 ]; do
  sleep 0.01
  i=$((i + 1))
done
[ -f "$FIRST" ] && ok || bad "first runner must reach the stale-writer barrier"

SPARK_RUN_ID=race bash "$SB/run.sh" >/dev/null 2>&1 &
b_pid=$!
wait "$b_pid" || true
wait "$a_pid" || true

LOG="$SB/../.spark/telemetry/race.executions"
if [ -f "$LOG" ]; then
  durable="$(awk '$1 == "full" { n++ } END { print n+0 }' "$LOG")"
else
  durable=0
fi
[ "$durable" = "2" ] && ok || bad "append-only execution truth must preserve both concurrent full runs (got $durable)"

assert_contains "newer runner publishes the durable count" "full_suite_runs=2" "$(cat "$TELLOG")"
assert_contains "forced stale writer publishes afterward" "full_suite_runs=1" "$(tail -n 1 "$TELLOG")"

# Last-write-wins telemetry must never finish below the durable log. This is the
# discriminating assertion: it is red on the #665 reproduction and turns green
# only when the published projection is race-safe (or derived from durable truth).
last_full="$(awk '{ for (i=1; i<=NF; i++) if ($i ~ /^full_suite_runs=/) { split($i,a,"="); v=a[2] } } END { print v+0 }' "$TELLOG")"
[ "$last_full" = "$durable" ] && ok \
  || bad "published full_suite_runs regressed to $last_full while durable execution truth is $durable"

finish
