#!/usr/bin/env bash
# Spark behavioral test runner: executes every tests/test-*.sh, reports a
# summary, exits non-zero on any failure. Zero dependencies beyond bash and
# the tools the scripts under test already require.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
fails=0 suites=0

# Every suite must work in its own sandbox and leave the real checkout
# untouched (#274). Snapshot the tree before and after the run; a change means
# a suite escaped its sandbox — a test-hygiene failure, reported as one.
snapshot() { git -C "$here/.." status --porcelain 2>/dev/null || true; }
tree_before="$(snapshot)"

for suite in "$here"/test-*.sh; do
  [ -e "$suite" ] || { echo "no test suites found"; exit 1; }
  suites=$((suites + 1))
  echo "== $(basename "$suite")"
  if ! bash "$suite"; then
    fails=$((fails + 1))
  fi
done

tree_after="$(snapshot)"
if [ "$tree_before" != "$tree_after" ]; then
  echo
  echo "✖ a suite mutated the working tree (suites must sandbox — #274):"
  diff <(printf '%s\n' "$tree_before") <(printf '%s\n' "$tree_after") || true
  fails=$((fails + 1))
fi

echo
if [ "$fails" -gt 0 ]; then
  echo "✖ $fails of $suites suite(s) failed"
  exit 1
fi
echo "✓ all $suites suite(s) passed"
