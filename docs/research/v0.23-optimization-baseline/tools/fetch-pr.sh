#!/usr/bin/env bash
# fetch-pr.sh <pr-number> <linked-issue-number> <outdir>  — raw GitHub evidence, no interpretation
set -uo pipefail
pr="$1"; issue="$2"; out="$3"
mkdir -p "$out"
R=repos/jwogrady/spark
gh api "$R/pulls/$pr" > "$out/pr.json"
gh api --paginate "$R/pulls/$pr/commits?per_page=100" > "$out/commits.json"
gh api --paginate "$R/pulls/$pr/reviews?per_page=100" > "$out/reviews.json"
gh api --paginate "$R/pulls/$pr/comments?per_page=100" > "$out/review-comments.json"
gh api --paginate "$R/issues/$pr/comments?per_page=100" > "$out/issue-comments.json"
gh api --paginate "$R/issues/$pr/events?per_page=100" > "$out/events.json"
gh api --paginate "$R/issues/$pr/timeline?per_page=100" > "$out/timeline.json"
gh api --paginate "$R/pulls/$pr/files?per_page=100" > "$out/files.json"
gh api "$R/issues/$issue" > "$out/issue$issue.json"
gh api --paginate "$R/issues/$issue/comments?per_page=100" > "$out/issue$issue-comments.json"
head_sha="$(gh api "$R/pulls/$pr" --jq '.head.sha')"
# filter=all: the endpoint defaults to the LATEST run per check suite, so a later rerun would replace the
# historical run in the response; with all runs present, analyze-pr.py can pin to those started at or before the cutoff.
gh api --paginate "$R/commits/$head_sha/check-runs?filter=all&per_page=100" > "$out/check-runs-head.json"
gh api --paginate "$R/actions/runs?branch=$(gh api "$R/pulls/$pr" --jq '.head.ref')&per_page=100" > "$out/workflow-runs.json"
wc -c "$out"/*.json
