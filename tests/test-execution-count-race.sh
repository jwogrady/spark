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
#   2. no read surface reports a stale stored projection when a newer log
#      exists, proven with a mutation control that removes the derivation and
#      watches the stale value resurface across the human, JSON, relay and
#      compare paths.
# There is no lock to abandon and no stale lock owner, so no bounded-wait or
# cleanup fixture is needed — the mechanism has no such synchronisation state.
#
# The fixture below is ONE integrated real concurrent race, not two disjoint
# scenarios: real runners append to the log AND publish through the real
# `telemetry record` path, full and targeted overlapping in the same run, so
# the durability check and the derivation check share the very same evidence
# instead of the second being hand-authored after the fact.
#
# A "controlled delayed recorder" stands in for `plugins/spark/bin/spark`
# during the race: it reads the counts a runner is about to publish and
# sleeps LONGER the SMALLER they are, so whichever runner saw the stalest
# snapshot of the log is also, deterministically, the LAST to actually
# publish — reproducing #665's exact last-write-wins hazard on every run of
# this suite instead of leaving it to scheduler luck.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "execution count race (#665)"
sandbox_init

# --- build the integrated project: one git repo hosting both the runner and
# the read surfaces, so `git_root()` (what `telemetry record/show` key their
# .spark/telemetry paths off) resolves to the exact directory `run.sh` itself
# uses as `$top` — the two must agree or the recorder and the reader would
# talk past each other. `.spark/` is gitignored so the runners' own writes
# during the race can never register as a working-tree mutation under
# run.sh's "a suite must leave the checkout untouched" self-check (#274) —
# without it, one runner's telemetry write landing inside another's
# before/after snapshot window would be a source of pure scheduling flake.
make_repo "$WORK/proj"
PROJ="$WORK/proj"
printf '.spark/\n' > "$PROJ/.gitignore"
SB="$PROJ/suite"
mkdir -p "$SB" "$PROJ/plugins/spark/bin" "$PROJ/plugins/spark/lib"
cp "$repo_root/tests/run.sh" "$SB/run.sh"
cp "$repo_root/plugins/spark/lib/execution.sh" "$PROJ/plugins/spark/lib/execution.sh"
printf '#!/usr/bin/env bash\necho "  1 passed, 0 failed"\n' > "$SB/test-alpha.sh"
chmod +x "$SB/test-alpha.sh"

# The delayed recorder. REAL_SPARK is the sandbox's own real, full dispatcher
# (from sandbox_init) — every publish is genuinely handled by the production
# `telemetry record` path; only the delay ahead of it is a test control.
export REAL_SPARK="$SPARK"
cat > "$PROJ/plugins/spark/bin/spark" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = telemetry ] && [ "${2:-}" = record ]; then
  nf=0 nt=0
  for a in "$@"; do
    case "$a" in
      full_suite_runs=*) nf="${a#full_suite_runs=}" ;;
      targeted_checks=*) nt="${a#targeted_checks=}" ;;
    esac
  done
  d="$(awk -v nf="$nf" -v nt="$nt" 'BEGIN { d = (4 - (nf + nt)) * 0.5; if (d < 0) d = 0; printf "%.2f", d }')"
  sleep "$d"
fi
exec "$REAL_SPARK" "$@"
WRAP
chmod +x "$PROJ/plugins/spark/bin/spark"

# --- 1. real overlap: two full and two targeted runners for one run id race,
# each running the REAL run.sh against the REAL recorder. The append-only log
# must keep all four; a failing runner must never be swallowed into a false
# pass (#665 finding 2); and the delayed recorder must have forced a genuinely
# stale publish, not a hand-seeded one, so the derivation check below proves
# something about the actual race rather than a scripted end-state.
pids="" fail_runners=0
for _ in 1 2; do
  ( cd "$SB" && SPARK_RUN_ID=race bash run.sh >/dev/null 2>&1 ) &
  pids="$pids $!"
done
for _ in 1 2; do
  ( cd "$SB" && SPARK_RUN_ID=race bash run.sh --only alpha >/dev/null 2>&1 ) &
  pids="$pids $!"
done
for p in $pids; do
  wait "$p" || fail_runners=$((fail_runners + 1))
done
[ "$fail_runners" = 0 ] && ok || bad "$fail_runners concurrent runner(s) exited non-zero — a swallowed runner failure must never let this race fixture pass on incomplete evidence"

LOG="$PROJ/.spark/telemetry/race.executions"
[ -f "$LOG" ] && ok || bad "the append-only execution log must exist after concurrent runs"
nf="$(awk -F'\t' '$1 == "full" { n++ } END { print n+0 }' "$LOG")"
nt="$(awk -F'\t' '$1 == "targeted" { n++ } END { print n+0 }' "$LOG")"
[ "$nf" = "2" ] && ok || bad "append-only log must preserve both concurrent full runs (got $nf)"
[ "$nt" = "2" ] && ok || bad "append-only log must preserve both concurrent targeted runs (got $nt)"

# --- 2. the delayed recorder's own publish must be the discriminating,
# genuinely stale end-state — below the log truth on at least one counter —
# or the checks that follow would prove nothing about #665.
TSV="$PROJ/.spark/telemetry/race.tsv"
[ -f "$TSV" ] && ok || bad "the delayed recorder must have published a stored projection to race the derivation against"
RAW="$(awk -F'\t' '$1 == "full_suite_runs" { v = $2 } END { print v + 0 }' "$TSV")"
RAWT="$(awk -F'\t' '$1 == "targeted_checks" { v = $2 } END { print v + 0 }' "$TSV")"
if [ "$RAW" -lt "$nf" ] || [ "$RAWT" -lt "$nt" ]; then ok
else bad "the controlled delay did not force a stale publish to finish last (stored $RAW/$RAWT, log $nf/$nt) — the fixture proves nothing"
fi

# --- 3. every read surface DERIVES the counters from the log (the #665 fix),
# never the raw stale publish captured above.
HSHOW="$(cd "$PROJ" && "$SPARK" telemetry show --run race 2>&1)"
assert_contains "the human table reports the derived full/targeted counts" "2" "$HSHOW"
JSHOW="$(cd "$PROJ" && "$SPARK" telemetry show --run race --json 2>&1)"
assert_contains "json reports the derived full count" '"full_suite_runs":2' "$JSHOW"
assert_contains "json reports the derived targeted count" '"targeted_checks":2' "$JSHOW"
if [ "$RAW" != "2" ]; then
  case "$JSHOW" in
    *"\"full_suite_runs\":$RAW"*) bad "json must not report the stale stored full_suite_runs ($RAW, #665)" ;;
    *) ok ;;
  esac
fi
if [ "$RAWT" != "2" ]; then
  case "$JSHOW" in
    *"\"targeted_checks\":$RAWT"*) bad "json must not report the stale stored targeted_checks ($RAWT, #665)" ;;
    *) ok ;;
  esac
fi
RSHOW="$(cd "$PROJ" && "$SPARK" telemetry relay --run race 2>&1)"
assert_contains "the relay projection reports derived counts, not the stale publish" "2 / 2" "$RSHOW"

# --- 4. compare reads truthful derived counts for a second, independently
# raced run — mixed full/targeted overlap on one run id above, full-only
# concurrency on a second, so compare is exercised against two real,
# differently-shaped append-only logs rather than a synthetic pair.
pids2=""
for _ in 1 2 3; do
  ( cd "$SB" && SPARK_RUN_ID=race2 bash run.sh >/dev/null 2>&1 ) &
  pids2="$pids2 $!"
done
fail_runners=0
for p in $pids2; do
  wait "$p" || fail_runners=$((fail_runners + 1))
done
[ "$fail_runners" = 0 ] && ok || bad "$fail_runners concurrent race2 runner(s) exited non-zero"
CMP="$(cd "$PROJ" && "$SPARK" telemetry compare race race2 2>&1)"
assert_contains "compare reads the derived full count for run race" "2" "$CMP"
assert_contains "compare reads the derived full count for run race2" "3" "$CMP"
FULLROW="$(printf '%s\n' "$CMP" | awk '$1 == "full_suite_runs"')"
case "$FULLROW" in
  *"2"*"3"*) ok ;;
  *) bad "compare must report derived full_suite_runs (2 vs 3) — got: $FULLROW" ;;
esac

# --- MUTATION CONTROL --------------------------------------------------------
# Stop deriving from the log: let tm_exec_count report "no log" so every reader
# falls back to the stored projection. The genuinely stale RAW/RAWT captured
# above must resurface across the JSON and relay paths, proving the fixture
# above discriminates rather than passing by coincidence.
mutant_runtime 's#\[ -f "$elog" \] || return 1#return 1#'
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi
MJSON="$(cd "$PROJ" && "$MUT" telemetry show --run race --json 2>&1)"
# Discriminate on whichever dimension the delayed recorder actually left
# stale (section 2 already proved at least one of them is) — the other may
# coincidentally match its true count and so cannot tell derived from raw.
if [ "$RAW" != "$nf" ]; then
  case "$MJSON" in
    *"\"full_suite_runs\":$RAW"*) ok ;;
    *) bad "MUTATION control — json did not fall back to the stale full_suite_runs ($RAW): $MJSON" ;;
  esac
elif [ "$RAWT" != "$nt" ]; then
  case "$MJSON" in
    *"\"targeted_checks\":$RAWT"*) ok ;;
    *) bad "MUTATION control — json did not fall back to the stale targeted_checks ($RAWT): $MJSON" ;;
  esac
else
  bad "MUTATION control — no stale dimension found to discriminate on (unexpected)"
fi
MREL="$(cd "$PROJ" && "$MUT" telemetry relay --run race 2>&1)"
case "$MREL" in
  *"$RAW / $RAWT"*) ok ;;
  *) bad "MUTATION control — relay did not fall back to the stale stored projection ($RAW / $RAWT)" ;;
esac

# --- 5. a recording failure stays explicit, and the log stays durable --------
# When the recorder is present but its call fails, the execution is still
# appended to the authoritative log and the failure is announced — never a
# silent drop that would leave the count resting on a number nothing wrote.
printf '#!/usr/bin/env bash\nexit 1\n' > "$PROJ/plugins/spark/bin/spark"
chmod +x "$PROJ/plugins/spark/bin/spark"
ERR="$(cd "$SB" && SPARK_RUN_ID=failrec bash run.sh 2>&1 >/dev/null || true)"
assert_contains "a failing recorder is announced, not swallowed" "record FAILED" "$ERR"
FLOG="$PROJ/.spark/telemetry/failrec.executions"
if [ -f "$FLOG" ] && [ "$(awk -F'\t' '$1 == "full" { n++ } END { print n+0 }' "$FLOG")" = "1" ]; then ok
else bad "the execution must remain durably logged even when the recorder fails (#665)"; fi

finish
