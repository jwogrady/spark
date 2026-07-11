#!/usr/bin/env bash
# Spark behavioral test runner: executes every tests/test-*.sh, reports a
# summary, exits non-zero on any failure. Zero dependencies beyond bash and
# the tools the scripts under test already require.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
fails=0 suites=0

for suite in "$here"/test-*.sh; do
  [ -e "$suite" ] || { echo "no test suites found"; exit 1; }
  suites=$((suites + 1))
  echo "== $(basename "$suite")"
  if ! bash "$suite"; then
    fails=$((fails + 1))
  fi
done

echo
if [ "$fails" -gt 0 ]; then
  echo "✖ $fails of $suites suite(s) failed"
  exit 1
fi
echo "✓ all $suites suite(s) passed"
