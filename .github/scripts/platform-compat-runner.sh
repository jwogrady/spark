#!/usr/bin/env bash
# CI glue for the Platform Compatibility Review (#300, ADR-0026). Finds the open
# Release Please PR, resolves the release range (last core tag..PR head), lists
# the capabilities it releases (feat commits), asks platform-compat-check.sh
# whether their DECLARED evaluation evidence is present and valid, then posts an
# advisory `platform-compat` commit status and one summary comment. Mirrors
# gate-runner.sh / release-notes-runner.sh; like them it reads and writes only a
# status + a comment — never merges, tags, or releases.
#
# The pure helpers below are factored out so the exit-code mapping and the
# capability-identity resolution can be tested offline (tests/test-platform-
# compat-check.sh); main runs only when the script is executed, not sourced.

# Map the check's exit code to a commit-status state, honestly. Exit codes match
# the gate convention: 0 ready/neutral, 1 blocked, 3 not-assessed, 2 usage/input
# error. A usage/config error or ANY unexpected code must never be published as a
# successful advisory — it becomes `error`, and main fails the step.
compat_status_for() { # <rc> -> success|failure|error
  case "$1" in
    0) echo success ;;   # ready / neutral — a trustworthy assessment
    1) echo failure ;;   # blocked — a declared-but-invalid required declaration
    3) echo success ;;   # not assessed (range unavailable) — honest, non-error
    *) echo error ;;     # 2 (usage/config/input) or unexpected — never success
  esac
}

# Turn raw "issue_id<TAB>subject" feat records (issue_id may be empty) into the
# deterministic capability list the check consumes: one record per capability.
# A resolved id (issue reference) is deduped to a single record; a feat with no
# issue reference has no stable identity (a commit subject is not one, ADR-0026),
# so it is emitted with an empty id and classified as unresolved by the check —
# never assigned an invented identity. Order of first appearance is preserved.
compat_resolve_capabilities() {
  # Unresolved rows use a "-" sentinel id (a leading empty tab-column would be
  # eaten by `read`, whose IFS treats a tab as whitespace).
  awk -F'\t' '
    { id=$1; label=$2 }
    id != ""    { if (!seen_id[id]++)    print id "\t" label; next }
    label != "" { if (!seen_lbl[label]++) print "-\t" label }
  '
}

main() {
  set -euo pipefail
  local here repo_root repo release_branch index eval_root pr pr_number head_sha
  local caps no_range_flag last_tag range out rc state body status_state

  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$here/../.." && pwd)"
  repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
  release_branch="release-please--branches--master"
  index="$repo_root/evaluations/evidence-index.tsv"
  eval_root="$repo_root/evaluations"

  pr="$(gh pr list --repo "$repo" --head "$release_branch" --state open \
        --json number,headRefOid --jq '.[0] // empty')"
  if [ -z "$pr" ]; then
    echo "no open Release Please PR; nothing to review"
    return 0
  fi
  pr_number="$(printf '%s' "$pr" | jq -r '.number')"
  head_sha="$(printf '%s' "$pr" | jq -r '.headRefOid')"

  caps="$(mktemp)"
  no_range_flag=""

  # Resolve the release range as the release-notes runner does: from the last
  # CORE tag (vX.Y.Z, never a companion tag) to the PR head. If the head can't be
  # resolved, the range is unknown — tell the check to report not-assessed.
  git fetch --quiet --tags origin "$head_sha" 2>/dev/null || true
  if ! git cat-file -e "$head_sha" 2>/dev/null; then
    no_range_flag="--no-range"
  else
    last_tag="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname 2>/dev/null | head -n1)"
    range="${last_tag:+$last_tag..}$head_sha"
    # A release capability is a feat commit, keyed by its first issue reference.
    git log --no-merges --format='%H' "$range" 2>/dev/null | while IFS= read -r sha; do
      subj="$(git log -1 --format='%s' "$sha")"
      case "$subj" in feat:*|feat\(*) ;; *) continue ;; esac
      id="$(git log -1 --format='%s%n%b' "$sha" | grep -oE '#[0-9]+' | head -n1 | tr -d '#')"
      printf '%s\t%s\n' "$id" "${subj#*: }"
    done | compat_resolve_capabilities > "$caps"
  fi

  set +e
  out="$(bash "$here/platform-compat-check.sh" \
    --index "$index" --capabilities "$caps" --evaluations-root "$eval_root" $no_range_flag 2>&1)"
  rc=$?
  set -e
  rm -f "$caps"

  state="$(printf '%s\n' "$out" | sed -n 's/^gate-state: //p' | head -n1)"
  body="$(printf '%s\n' "$out" | tail -n +2)"
  status_state="$(compat_status_for "$rc")"

  gh api -X POST "repos/$repo/statuses/$head_sha" \
    -f state="$status_state" -f context="platform-compat" \
    -f description="$(printf '%s' "$body" | head -c 130)" >/dev/null

  local marker existing comment
  marker="<!-- platform-compat -->"
  existing="$(gh api "repos/$repo/issues/$pr_number/comments" \
    --jq ".[] | select(.body|startswith(\"$marker\")) | .id" 2>/dev/null | head -n1)"
  comment="$(printf '%s\n**Platform Compatibility Review: %s**\n\n```\n%s\n```\n\n(Checks DECLARED capability-evaluation evidence for the Evaluation → Release seam — ADR-0026. Undeclared or unresolved-identity capabilities are advisory during initial adoption and do not block.)\n' "$marker" "${state:-unknown}" "$body")"
  if [ -n "$existing" ]; then
    gh api -X PATCH "repos/$repo/issues/comments/$existing" -f body="$comment" >/dev/null
  else
    gh api -X POST "repos/$repo/issues/$pr_number/comments" -f body="$comment" >/dev/null
  fi

  # Fail the step honestly when the check could not run correctly (status=error);
  # never leave a misleading green advisory behind a broken check.
  if [ "$status_state" = "error" ]; then
    echo "platform-compat: check errored (rc=$rc); status posted as 'error'" >&2
    return 1
  fi
  echo "platform-compat: ${state:-unknown} (rc=$rc)"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
