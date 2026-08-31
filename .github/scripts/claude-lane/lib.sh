# Canonical security decisions for the Claude coding lane (#583).
#
# One producer per security fact. The workflow's resolve/publish steps and the
# behavioural suite all source THIS file — so a rule proven by a test is the
# same rule the runner enforces, and neither can drift from the other.
#
# Every function here is pure: its decision is a function of its arguments and
# stdin only, with no network, no git, and no ambient state. That is what lets
# a synthetic-input fixture prove the real control rather than a proxy for it.
#
# Source, don't execute.

# cl_resolve_publication — is code publication authorized for this event?
#
# Args (all explicit): is_pr head_repo base_repo head_ref default_branch head_sha
# Echoes "authorized" or "refused:<reason>". Returns 0 authorized, 1 refused.
#
# Fails closed: any missing or malformed identity refuses. An ordinary issue
# (is_pr != true) refuses publication — Claude may still converse, but there is
# no branch to publish to.
cl_resolve_publication() {
  local is_pr="$1" head_repo="$2" base_repo="$3" head_ref="$4" default_branch="$5" head_sha="$6"

  [ "$is_pr" = "true" ]  || { echo "refused:not-a-pr"; return 1; }
  [ -n "$head_repo" ] && [ -n "$head_ref" ] && [ -n "$head_sha" ] && [ -n "$base_repo" ] \
    || { echo "refused:incomplete-identity"; return 1; }

  # A head SHA is 40 (sha1) or 64 (sha256) lowercase hex. Anything else is a
  # malformed payload, not a commit — refuse rather than trust it.
  case "$head_sha" in
    *[!0-9a-f]*) echo "refused:malformed-head-sha"; return 1 ;;
  esac
  case "${#head_sha}" in
    40|64) : ;;
    *) echo "refused:malformed-head-sha"; return 1 ;;
  esac

  # A head ref that carries refspec or path tricks is never a plain branch.
  case "$head_ref" in
    -*|*..*|*' '*|*:*|*'~'*|*'^'*|*'?'*|*'*'*|*'['*|*'\'*) echo "refused:malformed-head-ref"; return 1 ;;
  esac

  [ "$head_repo" = "$base_repo" ]     || { echo "refused:fork-head"; return 1; }
  [ "$head_ref" != "$default_branch" ] || { echo "refused:head-is-default-branch"; return 1; }

  echo "authorized"
  return 0
}

# cl_check_identity — re-verify the resolved identity at publish time, against
# what the resolver recorded. A second, independent gate so a corrupted or
# swapped output between jobs cannot smuggle a different target through.
#
# Args: repo expected_repo pr expected_pr head_repo head_ref default_branch
cl_check_identity() {
  local repo="$1" xrepo="$2" pr="$3" xpr="$4" head_repo="$5" head_ref="$6" default_branch="$7"
  [ -n "$repo" ] && [ "$repo" = "$xrepo" ]       || { echo "identity:repo-mismatch";   return 1; }
  [ -n "$pr" ]   && [ "$pr" = "$xpr" ]           || { echo "identity:pr-mismatch";     return 1; }
  [ "$head_repo" = "$repo" ]                      || { echo "identity:fork-head";       return 1; }
  [ -n "$head_ref" ]                             || { echo "identity:no-head-ref";     return 1; }
  [ "$head_ref" != "$default_branch" ]           || { echo "identity:head-is-default"; return 1; }
  return 0
}

# cl_check_stale_head — the TOCTOU gate. The branch tip the publisher is about
# to build on must be the exact SHA the resolver captured before Claude ran. A
# moved head refuses; it never silently rebases onto new work.
#
# Args: expected_sha actual_sha  ->  0 fresh, 1 stale.
cl_check_stale_head() {
  [ -n "$1" ] && [ "$1" = "$2" ] && return 0
  return 1
}

# cl_index_changes — the canonical path/mode producer.
#
# Echoes "<dst_mode><TAB><path>" for every staged change in the git repo at $1,
# with renames decomposed (--no-renames) so both the old and new path are seen
# as their own change. Reads git's own index rather than parsing diff text, so
# the mode (symlink 120000, gitlink 160000, deletion 000000) is git's, not a
# guess. The publisher and the suite both feed this into cl_validate_paths, so
# the path set that is tested is the path set that is enforced.
cl_index_changes() {
  git -C "$1" diff --cached --raw --no-renames | while IFS="$(printf '\t')" read -r meta path _; do
    # meta is ":<srcmode> <dstmode> <srcsha> <dstsha> <status>"; dstmode is $2.
    # shellcheck disable=SC2086 # deliberate word split of the fixed-shape meta
    set -- $meta
    printf '%s\t%s\n' "$2" "$path"
  done
}

# cl_validate_paths — the load-bearing publication control.
#
# Reads the resulting change as lines of "<dst_mode><TAB><path>" on stdin, where
# dst_mode is git's six-digit destination mode (000000 for a deletion) and every
# touched path — adds, modifications, deletions, and both sides of a rename —
# appears as its own line. The caller derives these from git's own index (the
# canonical producer of paths and modes), never from parsing diff text.
#
# Echoes "reject:<reason>:<path>" and returns 1 on the first violation; prints
# nothing and returns 0 when every path is allowed. Refuses:
#   * the workflow tree            (.github/workflows/**) — self-governance
#   * the lane's own helpers        (.github/scripts/claude-lane/**) — self-protection
#   * absolute paths and traversal  (/x, ../x) — escaping the repo
#   * symlinks (120000) and gitlinks/submodules (160000) — indirection tricks
cl_validate_paths() {
  local mode path
  while IFS=$'\t' read -r mode path; do
    [ -n "$path" ] || { echo "reject:empty-path:"; return 1; }
    case "$path" in
      /*)                                            echo "reject:absolute-path:$path";  return 1 ;;
      .github/workflows/*|*/.github/workflows/*)     echo "reject:workflow-path:$path";  return 1 ;;
      .github/scripts/claude-lane/*|*/.github/scripts/claude-lane/*)
                                                     echo "reject:publisher-path:$path"; return 1 ;;
    esac
    case "/$path/" in
      */../*)                                        echo "reject:path-traversal:$path"; return 1 ;;
    esac
    case "$mode" in
      120000)                                        echo "reject:symlink:$path";        return 1 ;;
      160000)                                        echo "reject:gitlink:$path";        return 1 ;;
    esac
  done
  return 0
}
