#!/usr/bin/env bash
# CI glue for the Platform Compatibility Review (#300, ADR-0026). Finds the open
# Release Please PR, resolves the release range (last core tag..PR head), lists
# the capabilities it releases (feat commits), asks platform-compat-check.sh
# whether their DECLARED evaluation evidence is present and valid, then posts an
# advisory `platform-compat` commit status and one summary comment. Mirrors
# gate-runner.sh / release-notes-runner.sh; like them it reads and writes only a
# status + a comment — never merges, tags, or releases.
#
# The check is the decision-maker; this only assembles inputs and reports. The
# release-range and Release Please discovery mirror release-notes-runner.sh
# rather than sharing a helper, to avoid modifying the other runners here.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
release_branch="release-please--branches--master"
index="$repo_root/evaluations/evidence-index.tsv"
eval_root="$repo_root/evaluations"

pr="$(gh pr list --repo "$repo" --head "$release_branch" --state open \
      --json number,headRefOid --jq '.[0] // empty')"
if [ -z "$pr" ]; then
  echo "no open Release Please PR; nothing to review"
  exit 0
fi
pr_number="$(printf '%s' "$pr" | jq -r '.number')"
head_sha="$(printf '%s' "$pr" | jq -r '.headRefOid')"

caps="$(mktemp)"
no_range_flag=""

# Resolve the release range exactly as the release-notes runner does: from the
# last CORE tag (vX.Y.Z, never a companion tag) to the PR head. If the head can't
# be resolved, the range is unknown — tell the check to report not-assessed
# rather than guess.
git fetch --quiet --tags origin "$head_sha" 2>/dev/null || true
if ! git cat-file -e "$head_sha" 2>/dev/null; then
  no_range_flag="--no-range"
else
  last_tag="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -n1)"
  range="${last_tag:+$last_tag..}$head_sha"
  # A release capability is a feat commit. Key it by the first issue it
  # references (its capability_id); fall back to the subject when none is cited.
  git log --no-merges --format='%H' "$range" 2>/dev/null | while IFS= read -r sha; do
    subj="$(git log -1 --format='%s' "$sha")"
    case "$subj" in
      feat:*|feat\(*) ;;
      *) continue ;;
    esac
    id="$(git log -1 --format='%s%n%b' "$sha" | grep -oE '#[0-9]+' | head -n1 | tr -d '#')"
    label="${subj#*: }"
    printf '%s\t%s\n' "${id:-$subj}" "$label" >> "$caps"
  done
fi

set +e
out="$(bash "$here/platform-compat-check.sh" \
  --index "$index" --capabilities "$caps" --evaluations-root "$eval_root" $no_range_flag 2>&1)"
rc=$?
set -e
rm -f "$caps"

state="$(printf '%s\n' "$out" | sed -n 's/^gate-state: //p' | head -n1)"
body="$(printf '%s\n' "$out" | tail -n +2)"

# Advisory: block visibility on a declared-but-invalid required declaration
# (rc 1), success otherwise (ready/neutral/not-assessed). Never a required check.
status_state="success"; [ "$rc" -eq 1 ] && status_state="failure"

gh api -X POST "repos/$repo/statuses/$head_sha" \
  -f state="$status_state" -f context="platform-compat" \
  -f description="$(printf '%s' "$body" | head -c 130)" >/dev/null

marker="<!-- platform-compat -->"
existing="$(gh api "repos/$repo/issues/$pr_number/comments" \
  --jq ".[] | select(.body|startswith(\"$marker\")) | .id" 2>/dev/null | head -n1)"
comment="$(printf '%s\n**Platform Compatibility Review: %s**\n\n```\n%s\n```\n\n(Checks DECLARED capability-evaluation evidence for the Evaluation → Release seam — ADR-0026. Undeclared capabilities are advisory during initial adoption and do not block.)\n' "$marker" "${state:-unknown}" "$body")"
if [ -n "$existing" ]; then
  gh api -X PATCH "repos/$repo/issues/comments/$existing" -f body="$comment" >/dev/null
else
  gh api -X POST "repos/$repo/issues/$pr_number/comments" -f body="$comment" >/dev/null
fi

echo "platform-compat: ${state:-unknown} (rc=$rc)"
