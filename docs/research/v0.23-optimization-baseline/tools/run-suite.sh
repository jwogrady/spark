#!/usr/bin/env bash
# usage: run-suite.sh [frozen-worktree] [output-dir]
# One full-suite run in the frozen worktree; the runner's own --json is the single projection (never re-run for a
# second summary). Fail-closed: setup and metadata collection run under errexit and abort on any failure; the
# suite itself is run with its status captured, and that status is the wrapper's exit status.
set -euo pipefail
cd "${1:-/home/john/code/spark/.claude/worktrees/baseline-921c982}"
out="${2:-/home/john/.claude/jobs/046f256e/tmp/raw}"
mkdir -p "$out"
sha="$(git rev-parse HEAD)"
start="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'sha=%s\nstart_utc=%s\n' "$sha" "$start" > "$out/run-full.meta"
s0=$(date +%s)
rc=0
bash tests/run.sh --json > "$out/run-full.out" 2> "$out/run-full.err" || rc=$?
s1=$(date +%s)
end="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'rc=%s\nwall_seconds=%s\nend_utc=%s\n' "$rc" "$((s1 - s0))" "$end" >> "$out/run-full.meta"
cat "$out/run-full.meta"
tail -c 2500 "$out/run-full.out"
# The wrapper's own status is the suite's status: a failed run must not look like a successful measurement.
exit "$rc"
