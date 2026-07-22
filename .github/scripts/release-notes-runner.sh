#!/usr/bin/env bash
# CI glue for the release-notes completeness guard (#261, #232). Finds the open
# Release Please PR, builds the commit list for the range it releases and the
# notes from its body, asks release-notes-check.sh whether any changelog-visible
# commit is missing, then posts an ADVISORY `release-notes` commit status and one
# summary comment. Mirrors gate-runner.sh; like it, this reads and writes only a
# status + a comment — never merges, tags, or releases.
#
# Advisory by design: a subject-substring heuristic should never hard-block a
# release, so the status is always `success` and the detail carries the finding.
# The mislabel half of the check (a feature merged as chore) needs per-commit PR
# labels and stays the manual release-docs-checklist step; this automates the
# omission half, which needs only commit subjects and the notes.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
release_branch="release-please--branches--master"

pr="$(gh pr list --repo "$repo" --head "$release_branch" --state open \
      --json number,headRefOid,body --jq '.[0] // empty')"
if [ -z "$pr" ]; then
  echo "no open Release Please PR; nothing to check"
  exit 0
fi
pr_number="$(printf '%s' "$pr" | jq -r '.number')"
head_sha="$(printf '%s' "$pr" | jq -r '.headRefOid')"
printf '%s' "$pr" | jq -r '.body' > notes.md

# Commit range: since the last release tag on this history. Needs full history
# (the workflow checks out with fetch-depth: 0). Each subject becomes a
# type<TAB>subject line; labels are left empty (the omission half needs none).
last_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
range="${last_tag:+$last_tag..}HEAD"
: > commits.tsv
git log --no-merges --format='%s' "$range" 2>/dev/null | while IFS= read -r subj; do
  case "$subj" in
    *:\ *) type="${subj%%:*}"; type="${type%%(*}"; rest="${subj#*: }"
           printf '%s\t%s\t\n' "$type" "$rest" >> commits.tsv ;;
  esac
done

set +e
out="$(bash "$here/release-notes-check.sh" --commits commits.tsv --notes notes.md 2>&1)"
set -e

# Commit status — always success (advisory); the detail names any finding.
gh api -X POST "repos/$repo/statuses/$head_sha" \
  -f state="success" -f context="release-notes" \
  -f description="$(printf '%s' "$out" | tail -n1 | head -c 130)" >/dev/null

marker="<!-- release-notes-check -->"
existing="$(gh api "repos/$repo/issues/$pr_number/comments" \
  --jq ".[] | select(.body|startswith(\"$marker\")) | .id" 2>/dev/null | head -n1)"
comment="$(printf '%s\n**Release-notes completeness (advisory)**\n\n```\n%s\n```\n\n(Omission check only — a feature merged under a hidden type still needs the manual release-docs-checklist review.)\n' "$marker" "$out")"
if [ -n "$existing" ]; then
  gh api -X PATCH "repos/$repo/issues/comments/$existing" -f body="$comment" >/dev/null
else
  gh api -X POST "repos/$repo/issues/$pr_number/comments" -f body="$comment" >/dev/null
fi

echo "release-notes advisory posted for PR #$pr_number"
