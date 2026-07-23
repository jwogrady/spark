#!/usr/bin/env bash
# Capability-traceability enforcement for pull requests (#301). A capability-
# proposing PR (conventional title type `feat`) must carry the "Capability
# traceability" section the PR template seeds — the CEF answer is REQUIRED,
# not merely invited (Constitution Article VI; the issue-form side is enforced
# by GitHub via required: true on the capability_traceability field).
#
# Pure decision logic lives in trace_pr_verdict so tests can drive it offline;
# main (source-guarded) fetches the PR body via gh and exits non-zero on FAIL,
# which fails the validate workflow's traceability job — that is the
# enforcement. Non-feat PRs are skipped with an honest line: the CEF governs
# capability admission, not docs/fixes/chores.

# trace_pr_verdict <pr-title> <body-file> -> prints SKIP|PASS|FAIL + reason
trace_pr_verdict() {
  local title="$1" body_file="$2"
  case "$title" in
    feat:*|feat\(*\):*|feat!:*|feat\(*\)!:*) ;;   # capability-proposing
    *) printf 'SKIP: not a capability-proposing PR (title type is not feat)\n'; return 0 ;;
  esac
  if [ ! -f "$body_file" ]; then
    printf 'FAIL: PR body unavailable\n'; return 1
  fi
  if grep -qiE '^##+[[:space:]]+Capability traceability' "$body_file"; then
    printf 'PASS: capability traceability section present\n'; return 0
  fi
  printf 'FAIL: feat PR is missing the "## Capability traceability" section (the CEF answer is required — see docs/governance/capability-evaluation.md)\n'
  return 1
}

main() {
  set -euo pipefail
  local repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
  local pr="${PR_NUMBER:?PR_NUMBER is required}"
  local title body_file verdict rc=0
  title="$(gh pr view "$pr" --repo "$repo" --json title --jq .title)"
  body_file="$(mktemp)"
  TRACE_BODY_FILE="$body_file"
  trap 'rm -f "${TRACE_BODY_FILE:-}"' EXIT
  gh pr view "$pr" --repo "$repo" --json body --jq .body > "$body_file"
  verdict="$(trace_pr_verdict "$title" "$body_file")" || rc=$?
  printf '%s\n' "$verdict"
  return "$rc"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
