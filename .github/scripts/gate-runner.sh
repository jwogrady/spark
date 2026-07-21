#!/usr/bin/env bash
# CI glue for the milestone gate (#194). Finds the open Release Please PR,
# gathers its milestone issues and validate status, asks milestone-gate.sh for
# the verdict, then posts a `milestone-gate` commit status and upserts one
# summary comment on the PR.
#
# It has NO path that merges, tags, or publishes a release — it only reads and
# writes a status + a comment. The workflow grants it no `contents: write`,
# which is what a tag/push/merge would require.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
release_branch="release-please--branches--master"

pr="$(gh pr list --repo "$repo" --head "$release_branch" --state open \
      --json number,headRefOid --jq '.[0] // empty')"
if [ -z "$pr" ]; then
  echo "no open Release Please PR; nothing to gate"
  exit 0
fi
pr_number="$(printf '%s' "$pr" | jq -r '.number')"
head_sha="$(printf '%s' "$pr" | jq -r '.headRefOid')"

# Proposed version comes from the manifest at the PR head, not master.
gh api "repos/$repo/contents/.release-please-manifest.json?ref=$head_sha" \
  --jq '.content' | base64 -d > manifest.json
gh issue list --repo "$repo" --state all --limit 500 \
  --json number,state,milestone > issues.json

# Validate is green only if every doctor/tests run on the PR head succeeded.
checks="unknown"
concl="$(gh api "repos/$repo/commits/$head_sha/check-runs" \
  --jq '[.check_runs[] | select(.name=="doctor" or .name=="tests") | .conclusion]' 2>/dev/null || echo '[]')"
if printf '%s' "$concl" | jq -e 'length>0 and all(.=="success")' >/dev/null 2>&1; then
  checks="green"
elif printf '%s' "$concl" | jq -e 'length>0' >/dev/null 2>&1; then
  checks="red"
fi

set +e
summary="$(bash "$here/milestone-gate.sh" --manifest manifest.json --issues issues.json --checks "$checks")"
set -e
state="$(printf '%s\n' "$summary" | sed -n 's/^gate-state: //p' | head -n1)"
body="$(printf '%s\n' "$summary" | tail -n +2)"

case "$state" in
  ready)   status_state="success" ;;
  blocked) status_state="failure" ;;
  *)       status_state="success" ;;   # neutral: never block the PR
esac

# Commit status — the only "write" is the status itself.
gh api -X POST "repos/$repo/statuses/$head_sha" \
  -f state="$status_state" -f context="milestone-gate" \
  -f description="$(printf '%s' "$body" | head -c 130)" >/dev/null

# Upsert exactly one summary comment, keyed by a hidden marker.
marker="<!-- milestone-gate -->"
existing="$(gh api "repos/$repo/issues/$pr_number/comments" \
  --jq ".[] | select(.body|startswith(\"$marker\")) | .id" 2>/dev/null | head -n1)"
comment="$(printf '%s\n**Milestone gate: %s**\n\n%s\n' "$marker" "$state" "$body")"
if [ -n "$existing" ]; then
  gh api -X PATCH "repos/$repo/issues/comments/$existing" -f body="$comment" >/dev/null
else
  gh api -X POST "repos/$repo/issues/$pr_number/comments" -f body="$comment" >/dev/null
fi

echo "milestone-gate: $state (checks=$checks)"
