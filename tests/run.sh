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
      echo "  Runs suites once, streaming each suite's output live, and reports"
      echo "  suites, assertions and per-suite seconds together."
      echo "  --only runs the matching subset: the cheap targeted path for repair,"
      echo "  as distinct from full certification. A filter matching no suite fails"
      echo "  non-zero — a targeted run that verifies nothing is not a pass."
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
  # The suite's output is STREAMED live and captured in one execution: a long
  # suite shows progress WHILE it runs — not only after it exits — and the
  # assertion counts are read from the very bytes just streamed, never a second
  # run. tee mirrors the suite to the terminal and to a capture file; the suite's
  # own status is PIPESTATUS[0], since tee's success would otherwise mask a fail.
  cap="$(mktemp)"
  set +e
  bash "$suite" 2>&1 | tee "$cap"
  rc="${PIPESTATUS[0]}"
  set -e
  out="$(cat "$cap")"
  rm -f "$cap"
  s1="$(now_s)"
  [ "$rc" -eq 0 ] || fails=$((fails + 1))

  # "  N passed, M failed" is the shared finish() line every suite prints. A
  # suite that exits 0 WITHOUT it ran no assertions the runner can see — an
  # unterminated heredoc, an early `exit`, a sourcing error swallowed by the
  # shell — and must never count as passed: silence is not evidence.
  if ! printf '%s\n' "$out" | grep -qE '^  [0-9]+ passed, [0-9]+ failed$'; then
    echo "  ✖ $name printed no '  N passed, M failed' line — a silent suite is a failed suite"
    [ "$rc" -eq 0 ] && fails=$((fails + 1))
  fi
  p="$(printf '%s\n' "$out" | awk '/[0-9]+ passed, [0-9]+ failed/ { p = $1 } END { print p + 0 }')"
  f="$(printf '%s\n' "$out" | awk '/[0-9]+ passed, [0-9]+ failed/ { f = $3 } END { print f + 0 }')"
  assert_pass=$((assert_pass + p))
  assert_fail=$((assert_fail + f))
  timings="${timings}${name}	$((s1 - s0))
"
done

# A non-empty --only that matched no suite ran nothing — that is a failure, not a
# pass. A typo or a renamed suite must never yield green targeted evidence, so it
# exits non-zero BEFORE any telemetry, JSON, or summary can describe zero selected
# suites as passed (#664).
if [ -n "$only" ] && [ "$suites" -eq 0 ]; then
  echo "run.sh: --only '$only' matched no suite — nothing ran" >&2
  echo "  (a targeted check that runs zero suites is not evidence; fix the filter)" >&2
  exit 1
fi

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
      # $log is the AUTHORITATIVE, append-only execution evidence: a short append
      # is atomic even when runners overlap, so it never loses a concurrent
      # execution. The full_suite_runs/targeted_checks we publish here are a
      # convenience PROJECTION of it. Publishing is last-write-wins, so under
      # concurrency a staler runner's call can finish last and leave the stored
      # projection below $log — which is exactly why every AUTHORITATIVE read
      # (`telemetry show`, its `--json`, and `relay`) DERIVES these two counters
      # from $log at read time (#665). The reported count can therefore never
      # finish below durable truth however the publishes interleave, so this
      # runner simply publishes its own view: no lock to abandon, no stale lock
      # owner to recover, and no last stale publisher can set the reported count.
      count_kind() { awk -F'\t' -v k="$1" '$1 == k { n++ } END { print n+0 }' "$log"; }
      if ! "$spark_bin" telemetry record --run "$SPARK_RUN_ID" \
             "full_suite_runs=$(count_kind full)" "targeted_checks=$(count_kind targeted)" >/dev/null 2>&1; then
        echo "run.sh: execution logged at $log but telemetry record FAILED" >&2
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
