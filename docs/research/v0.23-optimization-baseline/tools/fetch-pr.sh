#!/usr/bin/env bash
# fetch-pr.sh <pr-number> <linked-issue-number> <outdir>  — raw GitHub evidence, no interpretation.
# Every fetch goes to a temporary file and is moved into place only on success, so a failed `gh api` can never
# leave a missing or empty evidence file behind a zero exit status.
set -euo pipefail
pr="$1"; issue="$2"; out="$3"
mkdir -p "$out"
R=repos/jwogrady/spark
fetch() { # <outfile> <gh api args...>
  local dest="$1"; shift
  local tmp; tmp="$(mktemp "$out/.fetch.XXXXXX")"
  gh api "$@" > "$tmp"
  [ -s "$tmp" ] || { echo "empty response for $dest" >&2; rm -f "$tmp"; exit 1; }
  mv -f "$tmp" "$dest"
}
fetch "$out/pr.json"              "$R/pulls/$pr"
fetch "$out/commits.json"         --paginate "$R/pulls/$pr/commits?per_page=100"
fetch "$out/reviews.json"         --paginate "$R/pulls/$pr/reviews?per_page=100"
fetch "$out/review-comments.json" --paginate "$R/pulls/$pr/comments?per_page=100"
fetch "$out/issue-comments.json"  --paginate "$R/issues/$pr/comments?per_page=100"
fetch "$out/events.json"          --paginate "$R/issues/$pr/events?per_page=100"
fetch "$out/timeline.json"        --paginate "$R/issues/$pr/timeline?per_page=100"
fetch "$out/files.json"           --paginate "$R/pulls/$pr/files?per_page=100"
fetch "$out/issue$issue.json"     "$R/issues/$issue"
fetch "$out/issue$issue-comments.json" --paginate "$R/issues/$issue/comments?per_page=100"
head_sha="$(gh api "$R/pulls/$pr" --jq '.head.sha')"
head_ref="$(gh api "$R/pulls/$pr" --jq '.head.ref')"
# filter=all: the endpoint defaults to the LATEST run per check suite, so a later rerun would replace the
# historical run in the response; with all runs present, analyze-pr.py can pin to those started at or before the cutoff.
fetch "$out/check-runs-head.json" --paginate "$R/commits/$head_sha/check-runs?filter=all&per_page=100"
fetch "$out/workflow-runs.json"   --paginate "$R/actions/runs?branch=$head_ref&per_page=100"
wc -c "$out"/*.json
