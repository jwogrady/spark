#!/usr/bin/env bash
# One full-suite run in the frozen worktree; the runner's own --json is the single projection (never re-run for a second summary).
set -uo pipefail
cd /home/john/code/spark/.claude/worktrees/baseline-921c982 || exit 1
out=/home/john/.claude/jobs/046f256e/tmp/raw
echo "sha=$(git rev-parse HEAD)" > "$out/run-full.meta"
echo "start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$out/run-full.meta"
s0=$(date +%s)
bash tests/run.sh --json > "$out/run-full.out" 2> "$out/run-full.err"
rc=$?
s1=$(date +%s)
echo "rc=$rc" >> "$out/run-full.meta"
echo "wall_seconds=$((s1-s0))" >> "$out/run-full.meta"
echo "end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$out/run-full.meta"
cat "$out/run-full.meta"
tail -c 2500 "$out/run-full.out"
