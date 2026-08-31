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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) as_json=1 ;;
    -h|--help)
      echo "usage: run.sh [--json]"
      echo "  Runs every suite once and reports suites, assertions and per-suite seconds."
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
  suites=$((suites + 1))
  name="$(basename "$suite")"
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

if [ -n "$as_json" ]; then
  echo
  printf '{"suites":%s,"suites_failed":%s,"assertions_passed":%s,"assertions_failed":%s,"seconds":%s,"slowest":[' \
    "$suites" "$fails" "$assert_pass" "$assert_fail" "$elapsed"
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
