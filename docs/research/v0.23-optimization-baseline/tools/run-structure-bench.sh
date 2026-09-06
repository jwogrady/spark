#!/usr/bin/env bash
set -uo pipefail
# usage: run-structure-bench.sh [frozen-worktree] [output-dir]
cd "${1:-/home/john/code/spark/.claude/worktrees/baseline-921c982}" || exit 1
out="${2:-/home/john/.claude/jobs/046f256e/tmp/raw}"; mkdir -p "$out"
bash tests/structure.sh --json > "$out/structure.json" 2> "$out/structure.err"; echo "structure rc=$?"
bash tests/structure.sh > "$out/structure.txt" 2>&1; echo "structure text rc=$?"
bash tests/bench.sh --json > "$out/bench.json" 2> "$out/bench.err"; echo "bench rc=$?"
bash tests/bench.sh > "$out/bench.txt" 2>&1; echo "bench text rc=$?"
head -c 3000 "$out/structure.txt"; echo; echo ----; cat "$out/bench.txt"
