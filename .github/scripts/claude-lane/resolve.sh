#!/usr/bin/env bash
# Stage 1 — the trusted event resolver for the Claude coding lane (#583).
#
# Runs from the trusted default-branch checkout, never PR-head code. The job's
# `if:` has already admitted only a trusted commenter who wrote @claude; this
# step turns the admitted event into an immutable identity the later jobs bind
# to. It NEVER infers pull_request fields from the issue_comment payload — those
# fields are not present there — it fetches PR metadata deterministically.
#
# Emits to GITHUB_OUTPUT: publication_authorized, repository, issue_number,
# is_pr, pr_number, head_repo, head_ref, head_sha, default_branch, reason.
# Fails closed: any missing or malformed identity yields publication_authorized
# = false while still letting Claude wake for conversation.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib.sh"

out() { printf '%s=%s\n' "$1" "$2" >> "${GITHUB_OUTPUT:-/dev/stdout}"; }

repo="${REPO:?REPO (github.repository) required}"
issue_number="${EVENT_ISSUE_NUMBER:?issue number required}"
is_pr="${EVENT_IS_PR:-false}"

out repository "$repo"
out issue_number "$issue_number"
out is_pr "$is_pr"

# An ordinary issue has no feature branch. Claude may still wake and converse;
# publication is simply not authorized, and no branch is invented.
if [ "$is_pr" != "true" ]; then
  out pr_number ""
  out head_repo ""
  out head_ref ""
  out head_sha ""
  out default_branch ""
  out publication_authorized false
  out reason "not-a-pr"
  echo "ordinary issue #$issue_number — conversation only, no publication" >&2
  exit 0
fi

# A comment on a PR carries the PR number as the issue number. Fetch the real
# pull_request object; do not trust anything derived from the comment payload.
meta="$(gh api "repos/$repo/pulls/$issue_number" --jq \
  '{pr:.number, head_repo:(.head.repo.full_name // ""), head_ref:(.head.ref // ""), head_sha:(.head.sha // ""), default_branch:(.base.repo.default_branch // "")}')"

pr_number="$(printf '%s' "$meta" | jq -r '.pr')"
head_repo="$(printf '%s' "$meta" | jq -r '.head_repo')"
head_ref="$(printf '%s' "$meta" | jq -r '.head_ref')"
head_sha="$(printf '%s' "$meta" | jq -r '.head_sha')"
default_branch="$(printf '%s' "$meta" | jq -r '.default_branch')"

out pr_number "$pr_number"
out head_repo "$head_repo"
out head_ref "$head_ref"
out head_sha "$head_sha"
out default_branch "$default_branch"

decision="$(cl_resolve_publication "true" "$head_repo" "$repo" "$head_ref" "$default_branch" "$head_sha")" || true

if [ "$decision" = "authorized" ]; then
  out publication_authorized true
  out reason "authorized"
else
  out publication_authorized false
  out reason "$decision"
  echo "publication refused: $decision" >&2
fi
