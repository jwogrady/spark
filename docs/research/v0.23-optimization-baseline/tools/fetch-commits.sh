#!/usr/bin/env bash
# fetch-commits.sh <outdir> — per-commit file stats for every sha in <outdir>/commits.json
set -uo pipefail
out="$1"
mkdir -p "$out/commits"
for sha in $(jq -r '.[].sha' "$out/commits.json"); do
  [ -s "$out/commits/$sha.json" ] || gh api "repos/jwogrady/spark/commits/$sha" > "$out/commits/$sha.json"
done
ls "$out/commits" | wc -l
