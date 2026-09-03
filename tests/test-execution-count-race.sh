#!/usr/bin/env bash
# Regression contract for #665 — concurrent runners must never let a stale
# telemetry publish move a REPORTED execution counter backward below the
# append-only log that already recorded newer truth.
#
# The fix is read-time derivation: `.spark/telemetry/<run>.executions` is the
# authority (atomic appends survive arbitrary overlap), and EVERY read that
# reports full_suite_runs/targeted_checks — `telemetry show`, its `--json`,
# `relay`, and `compare` — derives the two counters from that log rather than
# trusting the last-write-wins projection on the record.
#
# The discriminating reproduction is DETERMINISTIC, not timing-based. A recorder
# wrapper is driven by marker-file barriers, so the controller knows exactly when
# the stale publisher is waiting, when the newer publisher has completed, and
# when to release the stale one — the publication ORDER is forced by those
# barriers, never by sleep durations racing the scheduler. Each poll below sleeps
# only as a wait interval on a set-once marker; the OUTCOME does not depend on how
# long it sleeps, and a barrier that never trips HARD-FAILS the suite rather than
# passing on incomplete evidence.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "execution count race (#665)"
sandbox_init

# One git repo hosting both the runner and the read surfaces, so `git_root()`
# (what `telemetry record/show` key their .spark/telemetry paths off) resolves to
# the exact directory `run.sh` uses as `$top`. `.spark/` is gitignored so the
# runners' own writes during a race can never register as a working-tree mutation
# under run.sh's "a suite must leave the checkout untouched" self-check (#274).
make_repo "$WORK/proj"
PROJ="$WORK/proj"
printf '.spark/\n' > "$PROJ/.gitignore"
SB="$PROJ/suite"
mkdir -p "$SB" "$PROJ/plugins/spark/bin" "$PROJ/plugins/spark/lib"
cp "$repo_root/tests/run.sh" "$SB/run.sh"
cp "$repo_root/plugins/spark/lib/execution.sh" "$PROJ/plugins/spark/lib/execution.sh"
printf '#!/usr/bin/env bash\necho "  1 passed, 0 failed"\n' > "$SB/test-alpha.sh"
chmod +x "$SB/test-alpha.sh"

# The recorder wrapper. REAL_SPARK is the sandbox's own real dispatcher, so every
# publish is genuinely handled by the production `telemetry record` path. When
# RACE_BARRIER=1 it additionally coordinates the forced publication order through
# marker files: the runner about to publish full_suite_runs=1 (the staler read)
# parks until released, and the runner publishing 2 is proven to have completed
# first — reproducing #665's exact last-write-wins hazard on every run, with no
# dependence on scheduler timing. Without RACE_BARRIER it is a pass-through.
export REAL_SPARK="$SPARK"
export BAR_A_AT="$WORK/bar_a_at" BAR_RELEASE="$WORK/bar_release"
export BAR_A_DONE="$WORK/bar_a_done" BAR_B_DONE="$WORK/bar_b_done"
# A publisher's DONE marker is written only when its real record SUCCEEDS; a
# failed record writes a distinct FAIL marker instead. run.sh reports a telemetry
# failure without failing the runner, so a PID check alone would not catch it —
# the controller must see B's 2 actually land before it releases A (#665).
export BAR_A_FAIL="$WORK/bar_a_fail" BAR_B_FAIL="$WORK/bar_b_fail"
cat > "$PROJ/plugins/spark/bin/spark" <<'WRAP'
#!/usr/bin/env bash
set -uo pipefail
if [ "${1:-}" = telemetry ] && [ "${2:-}" = record ] && [ "${RACE_BARRIER:-}" = 1 ]; then
  nf=0
  for a in "$@"; do case "$a" in full_suite_runs=*) nf="${a#full_suite_runs=}" ;; esac; done
  if [ "$nf" = 1 ]; then
    # The staler read: announce arrival at the publish point, then park until the
    # controller has PROVEN the newer publish landed. The wait outcome is decided
    # by the release marker, not by how long each poll sleeps.
    : > "$BAR_A_AT"
    w=0
    while [ ! -f "$BAR_RELEASE" ]; do
      w=$((w + 1)); [ "$w" -gt 12000 ] && { echo "barrier: stale publisher never released" >&2; exit 91; }
      sleep 0.01
    done
    # DONE only on a successful record; a failed one raises FAIL, never DONE, so
    # the controller can never mistake a failed stale publish for a completed one.
    if "$REAL_SPARK" "$@"; then : > "$BAR_A_DONE"; exit 0
    else rc=$?; : > "$BAR_A_FAIL"; exit "$rc"; fi
  elif [ "$nf" = 2 ]; then
    # The newer publish must SUCCEED for its completion to count: emit DONE only on
    # success (FAIL otherwise), so releasing A can be gated on B's 2 truly landing.
    if "$REAL_SPARK" "$@"; then : > "$BAR_B_DONE"; exit 0
    else rc=$?; : > "$BAR_B_FAIL"; exit "$rc"; fi
  fi
fi
exec "$REAL_SPARK" "$@"
WRAP
chmod +x "$PROJ/plugins/spark/bin/spark"

# --- 1. the exact two-full-run discriminating reproduction (#665) -------------
# Deterministic sequence, forced by barriers:
#   A appends the first full execution, reads the log as 1, and PARKS at publish;
#   B appends the second, publishes full_suite_runs=2, and is PROVEN complete;
#   A is released and publishes its stale full_suite_runs=1 LAST.
# The stored last-write-wins projection is therefore 1, yet the authoritative
# read must still report 2 from the append-only log.
rm -f "$BAR_A_AT" "$BAR_RELEASE" "$BAR_A_DONE" "$BAR_B_DONE" "$BAR_A_FAIL" "$BAR_B_FAIL"
export RACE_BARRIER=1
PTSV="$PROJ/.spark/telemetry/pair.tsv"
# Robust under `set -e`: a missing record reads as 0, never an awk failure that
# would abort the fixture — so a broken B publish FAILS the assertions explicitly
# rather than exiting the script and leaving the parked runner to time out.
tsv_full() {
  [ -f "$PTSV" ] || { echo 0; return 0; }
  awk -F'\t' '$1 == "full_suite_runs" { v = $2 } END { print v + 0 }' "$PTSV"
}

( cd "$SB" && SPARK_RUN_ID=pair bash run.sh >/dev/null 2>&1 ) & A_PID=$!
w=0; while [ ! -f "$BAR_A_AT" ] && [ ! -f "$BAR_A_FAIL" ]; do w=$((w + 1)); [ "$w" -gt 12000 ] && break; sleep 0.01; done
[ -f "$BAR_A_AT" ] && ok || bad "pair: runner A must reach the publish barrier having read the log as 1"

( cd "$SB" && SPARK_RUN_ID=pair bash run.sh >/dev/null 2>&1 ) & B_PID=$!
# Wait for B to resolve either way — a successful publish (DONE) or a failed one
# (FAIL) — so a broken recorder is caught explicitly, never by silent timeout.
w=0; while [ ! -f "$BAR_B_DONE" ] && [ ! -f "$BAR_B_FAIL" ]; do w=$((w + 1)); [ "$w" -gt 12000 ] && break; sleep 0.01; done
[ -f "$BAR_B_DONE" ] && ok \
  || bad "pair: runner B must SUCCESSFULLY publish full_suite_runs=2 before A is released (fail=$([ -f "$BAR_B_FAIL" ] && echo yes || echo timeout))"
# B's 2 must ACTUALLY be on disk before A is released — the stored projection is
# read here and must be 2, so the stale-writer sequence provably starts from 2.
b_stored="$(tsv_full)"
[ "$b_stored" = 2 ] && ok \
  || bad "pair: B's full_suite_runs=2 must be the stored projection before A is released (got $b_stored)"

: > "$BAR_RELEASE"
w=0; while [ ! -f "$BAR_A_DONE" ] && [ ! -f "$BAR_A_FAIL" ]; do w=$((w + 1)); [ "$w" -gt 12000 ] && break; sleep 0.01; done
[ -f "$BAR_A_DONE" ] && ok \
  || bad "pair: runner A must SUCCESSFULLY publish its stale 1 after release (fail=$([ -f "$BAR_A_FAIL" ] && echo yes || echo timeout))"

pair_fail=0
wait "$A_PID" || pair_fail=$((pair_fail + 1))
wait "$B_PID" || pair_fail=$((pair_fail + 1))
[ "$pair_fail" = 0 ] && ok || bad "pair: a concurrent runner exited non-zero — no swallowed failure"
unset RACE_BARRIER

PLOG="$PROJ/.spark/telemetry/pair.executions"
pfull="$(awk -F'\t' '$1 == "full" { n++ } END { print n+0 }' "$PLOG")"
[ "$pfull" = 2 ] && ok || bad "pair: the append-only log must hold both full executions (got $pfull)"

# The stored projection went 2 (B, proven above) then 1 (A, last): the exact
# 2 -> stale-1 last-write-wins sequence #665 is about.
stored="$(tsv_full)"
[ "$stored" = 1 ] && ok \
  || bad "pair: the stale publish must finish LAST, leaving the stored projection at 1 (got $stored)"

PJSON="$(cd "$PROJ" && "$SPARK" telemetry show --run pair --json 2>&1)"
assert_contains "pair: the public JSON read still reports 2, derived from the authoritative log" \
  '"full_suite_runs":2' "$PJSON"
case "$PJSON" in
  *'"full_suite_runs":1'*) bad "pair: JSON must not surface the stale stored 1 (#665)" ;;
  *) ok ;;
esac

# --- 2. mixed full + targeted overlap: JSON == append-only truth, both counters -
# Real overlapping runners, pass-through recorder. The append-only log must keep
# every execution, and telemetry show --json must report EXACTLY the log's count
# for each counter — proving derivation holds for both under real concurrency.
run_pool() { # <run-id> <full-count> <targeted-count> -> sets pool_fail
  local run="$1" nfull="$2" ntarg="$3" i pids=""
  i=0; while [ "$i" -lt "$nfull" ]; do ( cd "$SB" && SPARK_RUN_ID="$run" bash run.sh >/dev/null 2>&1 ) & pids="$pids $!"; i=$((i + 1)); done
  i=0; while [ "$i" -lt "$ntarg" ]; do ( cd "$SB" && SPARK_RUN_ID="$run" bash run.sh --only alpha >/dev/null 2>&1 ) & pids="$pids $!"; i=$((i + 1)); done
  pool_fail=0
  local p; for p in $pids; do wait "$p" || pool_fail=$((pool_fail + 1)); done
}

run_pool mixed 2 2
[ "$pool_fail" = 0 ] && ok || bad "mixed: $pool_fail concurrent runner(s) exited non-zero"
MLOG="$PROJ/.spark/telemetry/mixed.executions"
mfull="$(awk -F'\t' '$1 == "full" { n++ } END { print n+0 }' "$MLOG")"
mtarg="$(awk -F'\t' '$1 == "targeted" { n++ } END { print n+0 }' "$MLOG")"
[ "$mfull" = 2 ] && ok || bad "mixed: append-only log must preserve both full runs (got $mfull)"
[ "$mtarg" = 2 ] && ok || bad "mixed: append-only log must preserve both targeted runs (got $mtarg)"
MJSON="$(cd "$PROJ" && "$SPARK" telemetry show --run mixed --json 2>&1)"
assert_contains "mixed: JSON full_suite_runs equals the append-only full count" \
  "\"full_suite_runs\":$mfull" "$MJSON"
assert_contains "mixed: JSON targeted_checks equals the append-only targeted count" \
  "\"targeted_checks\":$mtarg" "$MJSON"

# --- 3. full-only overlap: JSON full_suite_runs == append-only full count ------
run_pool fullonly 3 0
[ "$pool_fail" = 0 ] && ok || bad "fullonly: $pool_fail concurrent runner(s) exited non-zero"
FLOG="$PROJ/.spark/telemetry/fullonly.executions"
ffull="$(awk -F'\t' '$1 == "full" { n++ } END { print n+0 }' "$FLOG")"
[ "$ffull" = 3 ] && ok || bad "fullonly: append-only log must preserve all three full runs (got $ffull)"
FJSON="$(cd "$PROJ" && "$SPARK" telemetry show --run fullonly --json 2>&1)"
assert_contains "fullonly: JSON full_suite_runs equals the append-only full count" \
  "\"full_suite_runs\":$ffull" "$FJSON"

# --- 4. the non-human read surfaces derive too (relay + compare) --------------
RSHOW="$(cd "$PROJ" && "$SPARK" telemetry relay --run mixed 2>&1)"
assert_contains "relay reports derived counts, not a stale publish" "$mfull / $mtarg" "$RSHOW"
CMP="$(cd "$PROJ" && "$SPARK" telemetry compare mixed fullonly 2>&1)"
FULLROW="$(printf '%s\n' "$CMP" | awk '$1 == "full_suite_runs"')"
case "$FULLROW" in
  *"$mfull"*"$ffull"*) ok ;;
  *) bad "compare must report derived full_suite_runs ($mfull vs $ffull) — got: $FULLROW" ;;
esac

# --- MUTATION CONTROL --------------------------------------------------------
# Stop deriving from the log: let tm_exec_count report "no log" so every reader
# falls back to the stored projection. The DETERMINISTICALLY stale pair.tsv (1,
# proven above, against a log of 2) must resurface across JSON and relay.
mutant_runtime 's#\[ -f "$elog" \] || return 1#return 1#'
MUT="$MUTANT_PATH"
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi
MJSON2="$(cd "$PROJ" && "$MUT" telemetry show --run pair --json 2>&1)"
case "$MJSON2" in
  *'"full_suite_runs":2'*) bad "MUTATION control — json still derived; the fixture does not discriminate" ;;
  *'"full_suite_runs":1'*) ok ;;
  *) bad "MUTATION control — unexpected json count: $MJSON2" ;;
esac
MREL="$(cd "$PROJ" && "$MUT" telemetry relay --run pair 2>&1)"
case "$MREL" in
  *"1 / 0"*) ok ;;
  *) bad "MUTATION control — relay did not fall back to the stale stored projection (1 / 0)" ;;
esac

# --- 5. a recording failure stays explicit, and the log stays durable ---------
# The recorder is present but its call fails: the execution is still appended to
# the authoritative log and the failure is announced — never a silent drop.
printf '#!/usr/bin/env bash\nexit 1\n' > "$PROJ/plugins/spark/bin/spark"
chmod +x "$PROJ/plugins/spark/bin/spark"
ERR="$(cd "$SB" && SPARK_RUN_ID=failrec bash run.sh 2>&1 >/dev/null || true)"
assert_contains "a failing recorder is announced, not swallowed" "record FAILED" "$ERR"
FRLOG="$PROJ/.spark/telemetry/failrec.executions"
if [ -f "$FRLOG" ] && [ "$(awk -F'\t' '$1 == "full" { n++ } END { print n+0 }' "$FRLOG")" = "1" ]; then ok
else bad "the execution must remain durably logged even when the recorder fails (#665)"; fi

finish
