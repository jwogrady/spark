# Canonical security decisions for the Claude coding lane (#583).
#
# One producer per security fact. The workflow's resolve/publish steps and the
# behavioural suite all source THIS file — so a rule proven by a test is the
# same rule the runner enforces, and neither can drift from the other.
#
# Every function here is pure: its decision is a function of its arguments and
# stdin only, with no network, no git, and no ambient state.
#
# Source, don't execute.

cl_resolve_publication() {
  local is_pr="$1" head_repo="$2" base_repo="$3" head_ref="$4" default_branch="$5" head_sha="$6"
  [ "$is_pr" = "true" ]  || { echo "refused:not-a-pr"; return 1; }
  [ -n "$head_repo" ] && [ -n "$head_ref" ] && [ -n "$head_sha" ] && [ -n "$base_repo" ] && [ -n "$default_branch" ] \
    || { echo "refused:incomplete-identity"; return 1; }
  case "$head_sha" in *[!0-9a-f]*) echo "refused:malformed-head-sha"; return 1 ;; esac
  case "${#head_sha}" in 40|64) : ;; *) echo "refused:malformed-head-sha"; return 1 ;; esac
  case "$head_ref" in
    -*|*..*|*' '*|*:*|*'~'*|*'^'*|*'?'*|*'*'*|*'['*|*'\'*) echo "refused:malformed-head-ref"; return 1 ;;
  esac
  [ "$head_repo" = "$base_repo" ]      || { echo "refused:fork-head"; return 1; }
  [ "$head_ref" != "$default_branch" ] || { echo "refused:head-is-default-branch"; return 1; }
  echo "authorized"
  return 0
}

cl_check_identity() {
  local repo="$1" xrepo="$2" pr="$3" xpr="$4" head_repo="$5" head_ref="$6" default_branch="$7"
  [ -n "$repo" ] && [ "$repo" = "$xrepo" ]         || { echo "identity:repo-mismatch"; return 1; }
  [ -n "$pr" ] && [ "$pr" = "$xpr" ]               || { echo "identity:pr-mismatch"; return 1; }
  [ "$head_repo" = "$repo" ]                        || { echo "identity:fork-head"; return 1; }
  [ -n "$head_ref" ]                                 || { echo "identity:no-head-ref"; return 1; }
  [ -n "$default_branch" ]                           || { echo "identity:no-default-branch"; return 1; }
  [ "$head_ref" != "$default_branch" ]              || { echo "identity:head-is-default"; return 1; }
  return 0
}

cl_check_stale_head() {
  [ -n "$1" ] && [ "$1" = "$2" ] && return 0
  return 1
}

cl_index_changes() {
  git -C "$1" diff --cached --raw --no-renames | while IFS="$(printf '\t')" read -r meta path _; do
    # shellcheck disable=SC2086
    set -- $meta
    printf '%s\t%s\n' "$2" "$path"
  done
}

# Publication rejects workflow/self-governance surfaces and both sides of the
# autonomous review boundary. Claude cannot rewrite its own publisher OR the
# independent reviewer that judges Claude.
cl_validate_paths() {
  local mode path
  while IFS=$'\t' read -r mode path; do
    [ -n "$path" ] || { echo "reject:empty-path:"; return 1; }
    case "$path" in
      /*) echo "reject:absolute-path:$path"; return 1 ;;
      .github/workflows/*|*/.github/workflows/*) echo "reject:workflow-path:$path"; return 1 ;;
      .github/scripts/claude-lane/*|*/.github/scripts/claude-lane/*) echo "reject:publisher-path:$path"; return 1 ;;
      .github/scripts/openai-review/*|*/.github/scripts/openai-review/*) echo "reject:reviewer-path:$path"; return 1 ;;
    esac
    case "/$path/" in */../*) echo "reject:path-traversal:$path"; return 1 ;; esac
    case "$mode" in
      120000) echo "reject:symlink:$path"; return 1 ;;
      160000) echo "reject:gitlink:$path"; return 1 ;;
    esac
  done
  return 0
}
