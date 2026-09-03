#!/usr/bin/env bash
# Spark behavioral test runner: executes every tests/test-*.sh, reports a
# summary, exits non-zero on any failure. Zero dependencies beyond bash and
# the tools the scripts under test already require.
#
# CAPTURE ONCE, PROJECT MANY (#609). Release certification once ran this three
# times in a single command line — for the tail, the suite count, and the
# assertion total — spending three full executions on three views of the same
# evidence. Every number a caller might want is therefore derived here from one
# run and emitted together, with --json for anything that wants to slice it
# further. A second projection must never imply a second execution.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
fails=0 suites=0
assert_pass=0 assert_fail=0
as_json=""
timings=""
only=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json)   as_json=1 ;;
    --only)   shift; only="${1:-}" ;;
    --only=*) only="${1#--only=}" ;;
    -h|--help)
      echo "usage: run.sh [--json] [--only <substring>]"
      echo "  Runs suites once and reports suites, assertions and per-suite seconds."
      echo "  --only runs the matching subset: the cheap targeted path for repair,"
      echo "  as distinct from full certification."
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  if [ "$#" -gt 0 ]; then shift; fi
done

# Every suite must work in its own sandbox and leave the real checkout
# untouched (#274). Snapshot the tree before and after the run; a change means
# a suite escaped its sandbox — a test-hygiene failure, reported as one.
snapshot() { git -C "$here/.." status --porcelain 2>/dev/null || true; }
tree_before="$(snapshot)"

now_s() { date +%s; }
run_start="$(now_s)"

for suite in "$here"/test-*.sh; do
  [ -e "$suite" ] || { echo "no test suites found"; exit 1; }
  name="$(basename "$suite")"
  # A targeted run is the repair path: cheap enough to use between changes,
  # which is what keeps full certification for the boundary it belongs to.
  if [ -n "$only" ]; then
    case "$name" in *"$only"*) ;; *) continue ;; esac
  fi
  suites=$((suites + 1))
  echo "== $name"
  s0="$(now_s)"
  # The suite's output is streamed AND captured: the log stays readable while
  # the assertion counts come from the same execution that produced it.
  out="$(bash "$suite" 2>&1)" && rc=0 || rc=$?
  printf '%s\n' "$out"
  s1="$(now_s)"
  [ "$rc" -eq 0 ] || fails=$((fails + 1))

  # "  N passed, M failed" is the shared finish() line every suite prints.
  p="$(printf '%s\n' "$out" | awk '/[0-9]+ passed, [0-9]+ failed/ { p = $1 } END { print p + 0 }')"
  f="$(printf '%s\n' "$out" | awk '/[0-9]+ passed, [0-9]+ failed/ { f = $3 } END { print f + 0 }')"
  assert_pass=$((assert_pass + p))
  assert_fail=$((assert_fail + f))
  timings="${timings}${name}	$((s1 - s0))
"
done

tree_after="$(snapshot)"
if [ "$tree_before" != "$tree_after" ]; then
  echo
  echo "✖ a suite mutated the working tree (suites must sandbox — #274):"
  diff <(printf '%s\n' "$tree_before") <(printf '%s\n' "$tree_after") || true
  fails=$((fails + 1))
fi

elapsed=$(( $(now_s) - run_start ))

# One invocation is one execution, however many summaries are read from it. That
# is what lets run telemetry tell a single run with several projections apart
# from several actual runs — the number below counts executions, never views.
kind="full"; [ -n "$only" ] && kind="targeted"
if [ -n "${SPARK_RUN_ID:-}" ]; then
  # One execution must produce exactly one DURABLE increment, so the count is
  # derived from an append-only log rather than read-modify-written. A short
  # append is atomic on POSIX; a read-then-write pair silently loses an
  # execution whenever two runners overlap, which would quietly falsify the
  # claim that telemetry can tell executions from projections.
  #
  # And a recording that fails says so. Swallowing the error would leave the
  # same claim resting on a number that was never written.
  # The runner's own parent IS the repository root by construction, so asking
  # git for it only adds a way to fail.
  top="$(cd "$here/.." && pwd)"
  spark_bin="$top/plugins/spark/bin/spark"
  # The run id becomes a repository-local filename below, so validate it with the
  # ONE canonical rule (tm_valid_run) BEFORE the append — a traversal or separator
  # would append outside .spark/telemetry and corrupt a tracked file (#648). Source
  # the runtime module rather than restating the rule, so the two cannot drift.
  # A missing module fails closed on RECORDING (the suites already ran); it never
  # crashes the run, so the summary below is always reached.
  lib="$top/plugins/spark/lib/execution.sh"
  # shellcheck source=/dev/null
  [ -f "$lib" ] && . "$lib"
  if ! command -v tm_valid_run >/dev/null 2>&1; then
    echo "run.sh: SPARK_RUN_ID is set but this execution was NOT recorded" >&2
    echo "  (the runtime module that validates the id is missing: $lib)" >&2
  elif ! tm_valid_run "$SPARK_RUN_ID"; then
    echo "run.sh: SPARK_RUN_ID '$SPARK_RUN_ID' is not a valid run id — this execution was NOT recorded" >&2
    echo "  (letters, digits, dot, dash and underscore only — it becomes a filename)" >&2
  elif [ ! -x "$spark_bin" ]; then
    echo "run.sh: SPARK_RUN_ID is set but this execution was NOT recorded" >&2
    echo "  (plugins/spark/bin/spark is missing or not executable)" >&2
  else
    log_dir="$top/.spark/telemetry"
    log="$log_dir/$SPARK_RUN_ID.executions"
    if ! mkdir -p "$log_dir" 2>/dev/null ||
       ! printf '%s\t%s\n' "$kind" "$(date -u +%FT%TZ 2>/dev/null)" >> "$log" 2>/dev/null; then
      echo "run.sh: this execution was NOT recorded — could not append to $log" >&2
    else
      # $log is the AUTHORITATIVE surface for execution counts: an append-only
      # log where a short append is atomic even when two runners overlap.
      # full_suite_runs/targeted_checks on the telemetry record are a
      # last-write-wins PROJECTION of it, published below — read them for
      # convenience, never in place of $log when the two could disagree.
      count_kind() { awk -F'\t' -v k="$1" '$1 == k { n++ } END { print n+0 }' "$log"; }
      n_full="$(count_kind full)"
      n_targ="$(count_kind targeted)"
      if ! "$spark_bin" telemetry record --run "$SPARK_RUN_ID" \
             "full_suite_runs=$n_full" "targeted_checks=$n_targ" >/dev/null 2>&1; then
        echo "run.sh: execution logged at $log but telemetry record FAILED" >&2
      fi
      # The call above can be published by the underlying store AFTER a
      # concurrent runner's fresher call, because it was dispatched against
      # whatever $log held at THIS runner's read — and last-write-wins storage
      # lets the STALER of two overlapping publishes finish last and erase the
      # newer one (#665). $log only grows, so re-deriving it now already
      # reflects every append any concurrent runner made by the time this
      # runner's own call returned; republish whatever moved so the projection
      # can never finish below the append-only evidence above.
      n_full2="$(count_kind full)"
      n_targ2="$(count_kind targeted)"
      reconcile_pairs=()
      [ "$n_full2" = "$n_full" ] || reconcile_pairs+=("full_suite_runs=$n_full" "full_suite_runs=$n_full2")
      [ "$n_targ2" = "$n_targ" ] || reconcile_pairs+=("targeted_checks=$n_targ" "targeted_checks=$n_targ2")
      if [ "${#reconcile_pairs[@]}" -gt 0 ]; then
        if ! "$spark_bin" telemetry record --run "$SPARK_RUN_ID" "${reconcile_pairs[@]}" >/dev/null 2>&1; then
          echo "run.sh: durable count advanced after publishing but the corrected telemetry record FAILED" >&2
        fi
      fi
    fi
  fi
fi

if [ -n "$as_json" ]; then
  echo
  printf '{"kind":"%s","executions":1,"suites":%s,"suites_failed":%s,"assertions_passed":%s,"assertions_failed":%s,"seconds":%s,"slowest":[' \
    "$kind" "$suites" "$fails" "$assert_pass" "$assert_fail" "$elapsed"
  printf '%s' "$timings" | LC_ALL=C sort -t'	' -k2,2nr | head -n 5 | awk -F'\t' '
    NF { printf "%s{\"suite\":\"%s\",\"seconds\":%s}", (n++ ? "," : ""), $1, $2 }'
  printf ']}\n'
fi

echo
# Every figure a caller might want, from this one execution.
echo "suites: $suites   assertions: $assert_pass passed, $assert_fail failed   ${elapsed}s"
if [ "$fails" -gt 0 ]; then
  echo "✖ $fails of $suites suite(s) failed"
  exit 1
fi
echo "✓ all $suites suite(s) passed"
