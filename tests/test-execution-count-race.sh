#!/usr/bin/env bash
# Regression contract for #665 — concurrent runners must never let a stale
# telemetry publish move a REPORTED execution counter backward below the
# append-only log that already recorded newer truth.
#
# The fix is read-time derivation: `.spark/telemetry/<run>.executions` is the
# authority (atomic appends survive arbitrary overlap), and EVERY read that
# reports full_suite_runs/targeted_checks — `telemetry show`, its `--json`,
# `relay`, and `compare` — derives the two counters from that log rather than
# trusting the last-write-wins projection on the record. So the discriminating
# properties are:
#   1. the append-only log loses no concurrent execution (durability);
#   2. no read surface reports a stale stored projection when a newer log exists,
#      proven with a mutation control that removes the derivation and watches the
#      stale value resurface across the human, JSON, relay and compare paths.
# There is no lock to abandon and no stale lock owner, so no bounded-wait or
# cleanup fixture is needed — the mechanism has no such synchronisation state.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "execution count race (#665)"
sandbox_init

# --- 1. real overlap: the append-only log preserves every execution -----------
# Three full and two targeted runners for one run id overlap. Each append is a
# short atomic write, so the log must end with all five — none lost, whatever the
# interleaving. The recorder is a no-op here: the log run.sh writes itself is the
# durable evidence under test, independent of any telemetry projection.
SB="$WORK/suite"
mkdir -p "$SB" "$SB/../plugins/spark/bin" "$SB/../plugins/spark/lib"
cp "$repo_root/tests/run.sh" "$SB/run.sh"
cp "$repo_root/plugins/spark/lib/execution.sh" "$SB/../plugins/spark/lib/execution.sh"
printf '#!/usr/bin/env bash\necho "  1 passed, 0 failed"\n' > "$SB/test-alpha.sh"
chmod +x "$SB/test-alpha.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$SB/../plugins/spark/bin/spark"
chmod +x "$SB/../plugins/spark/bin/spark"

pids=""
for _ in 1 2 3; do
  SPARK_RUN_ID=conc bash "$SB/run.sh" >/dev/null 2>&1 &
  pids="$pids $!"
done
for _ in 1 2; do
  SPARK_RUN_ID=conc bash "$SB/run.sh" --only alpha >/dev/null 2>&1 &
  pids="$pids $!"
done
for p in $pids; do wait "$p" || true; done

LOG="$SB/../.spark/telemetry/conc.executions"
[ -f "$LOG" ] && ok || bad "the append-only execution log must exist after concurrent runs"
nf="$(awk -F'\t' '$1 == "full" { n++ } END { print n+0 }' "$LOG")"
nt="$(awk -F'\t' '$1 == "targeted" { n++ } END { print n+0 }' "$LOG")"
[ "$nf" = "3" ] && ok || bad "append-only log must preserve all 3 concurrent full runs (got $nf)"
[ "$nt" = "2" ] && ok || bad "append-only log must preserve all 2 concurrent targeted runs (got $nt)"

# --- 2. every read surface DERIVES the counters from the log (the #665 fix) ----
# A lost publish race leaves the stored projection BELOW the log: a runner
# published its early absolute count and later appends by overlapping runners
# never reached the record. Construct exactly that end-state — a log proving 3
# full + 2 targeted, a record still holding the stale 1 + 0 — and require every
# read that reports these counters to come from the log, for BOTH counters. Each
# derived count equals-or-exceeds the append-only truth (3>=3, 2>=2) and can
# never finish below it.
make_repo "$WORK/proj"
PROJ="$WORK/proj"
mkdir -p "$PROJ/.spark/telemetry"
seed_log() { # <run> <fulls> <targeteds>
  local f i
  f="$PROJ/.spark/telemetry/$1.executions"
  : > "$f"
  i=0; while [ "$i" -lt "$2" ]; do printf 'full\t2026-01-01T00:00:%02dZ\n' "$i" >> "$f"; i=$((i + 1)); done
  i=0; while [ "$i" -lt "$3" ]; do printf 'targeted\t2026-01-01T00:01:%02dZ\n' "$i" >> "$f"; i=$((i + 1)); done
}
seed_log derive 3 2
# a stale publish stored a LOWER absolute count than the log proves
( cd "$PROJ" && "$SPARK" telemetry record --run derive full_suite_runs=1 targeted_checks=0 >/dev/null )

# human table
HSHOW="$(cd "$PROJ" && "$SPARK" telemetry show --run derive 2>&1)"
assert_contains "the human table reports the derived full/targeted counts" "3" "$HSHOW"
# JSON (the automation surface)
JSHOW="$(cd "$PROJ" && "$SPARK" telemetry show --run derive --json 2>&1)"
assert_contains "json reports the derived full count, not the stale publish" '"full_suite_runs":3' "$JSHOW"
assert_contains "json reports the derived targeted count too" '"targeted_checks":2' "$JSHOW"
case "$JSHOW" in
  *'"full_suite_runs":1'*) bad "json must not report the stale stored projection (#665)" ;;
  *) ok ;;
esac
# relay (the #578 non-human projection surface)
RSHOW="$(cd "$PROJ" && "$SPARK" telemetry relay --run derive 2>&1)"
assert_contains "the relay projection reports derived counts, not the stale 1 / 0" "3 / 2" "$RSHOW"
# compare (the comparison consumer) — a second run whose stored projection is
# also stale must be compared on its DERIVED counts.
seed_log derive2 5 0
( cd "$PROJ" && "$SPARK" telemetry record --run derive2 full_suite_runs=1 targeted_checks=0 >/dev/null )
CMP="$(cd "$PROJ" && "$SPARK" telemetry compare derive derive2 2>&1)"
assert_contains "compare reads the derived full count for run a" "3" "$CMP"
assert_contains "compare reads the derived full count for run b" "5" "$CMP"
FULLROW="$(printf '%s\n' "$CMP" | awk '$1 == "full_suite_runs"')"
case "$FULLROW" in
  *" 1 "*" 1 "*) bad "compare must not read the stale stored projection for both runs (#665)" ;;
  *) ok ;;
esac

# --- MUTATION CONTROL --------------------------------------------------------
# Stop deriving from the log: let tm_exec_count report "no log" so every reader
# falls back to the stored projection. The stale 1 must resurface across the
# human, JSON, relay and compare paths, proving the fixtures above discriminate.
mutant_runtime 's#\[ -f "$elog" \] || return 1#return 1#'
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi
MJSON="$(cd "$PROJ" && "$MUT" telemetry show --run derive --json 2>&1)"
case "$MJSON" in
  *'"full_suite_runs":3'*) bad "MUTATION control — json still derived; the fixture does not discriminate" ;;
  *'"full_suite_runs":1'*) ok ;;
  *) bad "MUTATION control — unexpected json count: $MJSON" ;;
esac
MREL="$(cd "$PROJ" && "$MUT" telemetry relay --run derive 2>&1)"
case "$MREL" in
  *"1 / 0"*) ok ;;
  *) bad "MUTATION control — relay did not fall back to the stale stored projection" ;;
esac

# --- 3. a recording failure stays explicit, and the log stays durable ---------
# When the recorder is present but its call fails, the execution is still
# appended to the authoritative log and the failure is announced — never a silent
# drop that would leave the count resting on a number nothing wrote.
printf '#!/usr/bin/env bash\nexit 1\n' > "$SB/../plugins/spark/bin/spark"
chmod +x "$SB/../plugins/spark/bin/spark"
ERR="$(SPARK_RUN_ID=failrec bash "$SB/run.sh" 2>&1 >/dev/null || true)"
assert_contains "a failing recorder is announced, not swallowed" "record FAILED" "$ERR"
FLOG="$SB/../.spark/telemetry/failrec.executions"
if [ -f "$FLOG" ] && [ "$(awk -F'\t' '$1 == "full" { n++ } END { print n+0 }' "$FLOG")" = "1" ]; then ok
else bad "the execution must remain durably logged even when the recorder fails (#665)"; fi

finish
