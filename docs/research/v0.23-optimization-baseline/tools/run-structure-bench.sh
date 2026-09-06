#!/usr/bin/env bash
# usage: run-structure-bench.sh [frozen-worktree] [output-dir]
# Runs tests/structure.sh and tests/bench.sh (JSON and text projections) in the frozen worktree.
# Exits non-zero if ANY measurement failed, so a failed run cannot pass as evidence.
set -uo pipefail
cd "${1:-/home/john/code/spark/.claude/worktrees/baseline-921c982}" || exit 1
out="${2:-/home/john/.claude/jobs/046f256e/tmp/raw}"; mkdir -p "$out"
fail=0
run() { # <label> <outfile> <errfile> <cmd...>
  local label="$1" o="$2" e="$3"; shift 3
  "$@" > "$o" 2> "$e"; local rc=$?
  echo "$label rc=$rc"; [ "$rc" -eq 0 ] || fail=1
}
run "structure --json" "$out/structure.json" "$out/structure.err" bash tests/structure.sh --json
run "structure text"   "$out/structure.txt"  /dev/null            bash tests/structure.sh
run "bench --json"     "$out/bench.json"     "$out/bench.err"     bash tests/bench.sh --json
run "bench text"       "$out/bench.txt"      /dev/null            bash tests/bench.sh
head -c 3000 "$out/structure.txt"; echo; echo ----; cat "$out/bench.txt"
exit "$fail"
