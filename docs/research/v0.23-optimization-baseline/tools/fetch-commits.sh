#!/usr/bin/env bash
# fetch-commits.sh <outdir> — per-commit file stats for every sha in <outdir>/commits.json.
# Each commit is fetched to a temporary file and moved into place only on success (a failed fetch exits non-zero).
set -euo pipefail
out="$1"
mkdir -p "$out/commits"
for sha in $(jq -r '.[].sha' "$out/commits.json"); do
  [ -s "$out/commits/$sha.json" ] && continue
  tmp="$(mktemp "$out/commits/.fetch.XXXXXX")"
  gh api "repos/jwogrady/spark/commits/$sha" > "$tmp"
  [ -s "$tmp" ] || { echo "empty response for $sha" >&2; rm -f "$tmp"; exit 1; }
  mv -f "$tmp" "$out/commits/$sha.json"
done
n_have="$(ls "$out/commits" | grep -c '\.json$')"; n_want="$(jq 'length' "$out/commits.json")"
[ "$n_have" -eq "$n_want" ] || { echo "have $n_have commit files, expected $n_want" >&2; exit 1; }
echo "$n_have"
