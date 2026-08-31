# Spark runtime module: repository identity and mutation authority (#623)
#
# THE INCIDENT. A session bound to one project received a prompt written for
# another. The issue numbers it named did not exist locally, so the agent found
# them in the sibling repository, switched to that checkout, and carried on —
# routing around the worktree boundary with `git -C` and absolute paths when the
# session kept pulling it back.
#
# The hole was not a missing pattern rule. It was this:
#
#     repository DISCOVERY was treated as repository AUTHORIZATION.
#
# Finding a prompt's issue numbers in another repository is evidence about what
# the prompt refers to. It is not permission to write there.
#
# So authority attaches to a RESOLVED REPOSITORY IDENTITY — canonical facts from
# git, not the spelling of a command. `git -C`, `--git-dir`, an absolute path, a
# sibling worktree and a `gh --repo` call all cross the same boundary, and a
# substring rule would have to enumerate every one of them and would still miss
# the next. Resolving the target and comparing identities covers them together.
#
# Three outcomes, kept distinct because collapsing them destroys the signal:
#
#   same          proceed, subject to whatever authority the motion already needs
#   boundary      the target is a DIFFERENT repository — fail closed. This is not
#                 a judgment call and not missing evidence; it is a refusal
#   NOT ASSESSED  identity could not be resolved. Never treated as "same"
#
# Reads across repositories stay legitimate: evidence gathering is not mutation,
# and this module never restricts it.

# repo_locator_normalize <url> — a canonical host/owner/name locator, so the same
# repository compares equal however its remote is spelled. SSH, HTTPS, with or
# without a trailing .git, are one repository and must not read as three.
repo_locator_normalize() {
  local u="${1:-}"
  [ -n "$u" ] || return 0
  u="${u%.git}"
  case "$u" in
    git@*:*)      u="${u#git@}"; u="${u/://}" ;;
    ssh://git@*)  u="${u#ssh://git@}" ;;
    https://*)    u="${u#https://}" ;;
    http://*)     u="${u#http://}" ;;
  esac
  # Strip any userinfo left in an https form.
  u="${u#*@}"
  printf '%s' "$u"
}

# repo_identity <dir> — the canonical facts a mutation boundary is built from.
# Emits TSV rows; a fact that cannot be read is emitted as __unreadable__ rather
# than omitted, so a caller cannot mistake absence for agreement.
repo_identity() {
  local dir="${1:-.}" root locator head branch
  root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || root="__unreadable__"
  if [ "$root" = "__unreadable__" ]; then
    printf 'root\t__unreadable__\n'
    printf 'locator\t__unreadable__\n'
    printf 'head\t__unreadable__\n'
    printf 'branch\t__unreadable__\n'
    return 0
  fi
  locator="$(repo_locator_normalize "$(git -C "$dir" remote get-url origin 2>/dev/null || true)")"
  [ -n "$locator" ] || locator="__unreadable__"
  head="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || head="__unreadable__"
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch="__unreadable__"
  printf 'root\t%s\n'    "$root"
  printf 'locator\t%s\n' "$locator"
  printf 'head\t%s\n'    "$head"
  printf 'branch\t%s\n'  "$branch"
}

repo_fact() { printf '%s\n' "$1" | awk -F'\t' -v k="$2" '$1 == k { print $2; exit }'; }

# The binding is a create-only project fact: which repository this project's
# mutations belong to. Recorded rather than inferred per command, so a prompt
# that wanders cannot quietly move it.
repo_binding_path() { printf '%s/.spark/repository' "$1"; }

repo_bound_locator() {
  local f; f="$(repo_binding_path "$1")"
  [ -f "$f" ] || return 0
  awk -F'\t' '$1 == "locator" { print $2; exit }' "$f"
}

repo_bind() { # repo_bind <root> <locator>
  local root="$1" locator="$2" f
  f="$(repo_binding_path "$root")"
  mkdir -p "$(dirname "$f")" || return 1
  {
    printf 'locator\t%s\n' "$locator"
    printf 'bound_at\t%s\n' "$(date -u +%FT%TZ 2>/dev/null)"
  } > "$f"
}

# repo_authorize <bound-locator> <target-locator> — the decision, and only the
# decision. Prints one verdict token.
repo_authorize() {
  local bound="${1:-}" target="${2:-}"
  if [ -z "$bound" ] || [ "$bound" = "__unreadable__" ] ||
     [ -z "$target" ] || [ "$target" = "__unreadable__" ]; then
    printf 'unassessed'
    return 0
  fi
  if [ "$bound" = "$target" ]; then printf 'same'; else printf 'boundary'; fi
}

# repo_target_of_command <command> — the repository a shell command would act on,
# when it names one explicitly. This reads the command to find its TARGET; the
# authority decision is then made on the RESOLVED identity of that target, never
# on the text. A command naming no other repository resolves to the caller's own.
repo_target_of_command() {
  local cmd="$1" p=""
  case "$cmd" in
    *" -C "*)        p="$(printf '%s' "$cmd" | sed -n 's/.* -C  *\([^ ][^ ]*\).*/\1/p')" ;;
    *--git-dir=*)    p="$(printf '%s' "$cmd" | sed -n 's/.*--git-dir=\([^ ][^ ]*\).*/\1/p')"; p="${p%/.git}" ;;
    *--git-dir\ *)   p="$(printf '%s' "$cmd" | sed -n 's/.*--git-dir  *\([^ ][^ ]*\).*/\1/p')"; p="${p%/.git}" ;;
  esac
  printf '%s' "$p"
}

# repo_gh_repo_of_command <command> — an explicit `--repo owner/name` on a gh
# invocation. A connector or API write can cross the boundary without touching a
# path at all, so the locator form is resolved too.
repo_gh_repo_of_command() {
  local cmd="$1" r=""
  case "$cmd" in
    *gh\ *)
      case "$cmd" in
        *--repo=*)   r="$(printf '%s' "$cmd" | sed -n 's/.*--repo=\([^ ][^ ]*\).*/\1/p')" ;;
        *"--repo "*) r="$(printf '%s' "$cmd" | sed -n 's/.*--repo  *\([^ ][^ ]*\).*/\1/p')" ;;
      esac ;;
  esac
  printf '%s' "$r"
}

cmd_repo() {
  local usage_line="usage: spark repo [status|bind|handoff] [--to <owner/name>] [--yes] [--json]"
  local action="status"
  case "${1:-}" in
    status|bind|handoff) action="$1"; shift ;;
  esac
  local to="" yes="" json=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --to)   shift; to="${1:-}" ;;
      --to=*) to="${1#--to=}" ;;
      --yes)  yes=1 ;;
      --json) json=1 ;;
      -h|--help) echo "$usage_line"; return 0 ;;
      *) red "unknown option: $1"; echo "$usage_line"; return 1 ;;
    esac
    if [ "$#" -gt 0 ]; then shift; fi
  done

  local top; top="$(git_root)"
  if [ -z "$top" ]; then
    red "spark repo needs a git repo — run it from inside the project."
    return 1
  fi

  local ident locator bound
  ident="$(repo_identity "$top")"
  locator="$(repo_fact "$ident" locator)"
  bound="$(repo_bound_locator "$top")"

  case "$action" in
    bind|handoff)
      local target="${to:-$locator}"
      if [ "$target" = "__unreadable__" ] || [ -z "$target" ]; then
        red "the repository locator could not be resolved, so nothing can be bound"
        return 3
      fi
      # A handoff is a HUMAN act. Requiring the flag is the whole point: the
      # incident happened because a rebind occurred without one.
      if [ "$action" = "handoff" ] && [ -z "$yes" ]; then
        red "STOP — a repository handoff needs explicit authorization (--yes)"
        echo "  bound:  ${bound:-<unbound>}"
        echo "  target: $target"
        echo "  Discovering objects in another repository is evidence, never a handoff."
        return 4
      fi
      repo_bind "$top" "$target" || { red "could not record the binding"; return 1; }
      # Re-resolve after rebinding, so root, locator, HEAD and branch are
      # established against the repository now in force.
      ident="$(repo_identity "$top")"
      green "bound to $target"
      printf '  %-8s %s\n' root   "$(repo_fact "$ident" root)"
      printf '  %-8s %s\n' head   "$(repo_fact "$ident" head)"
      printf '  %-8s %s\n' branch "$(repo_fact "$ident" branch)"
      ;;
    status)
      local verdict
      verdict="$(repo_authorize "${bound:-$locator}" "$locator")"
      if [ -n "$json" ]; then
        printf '{"root":"%s","locator":"%s","head":"%s","branch":"%s","bound":"%s","verdict":"%s"}\n' \
          "$(repo_fact "$ident" root)" "$locator" "$(repo_fact "$ident" head)" \
          "$(repo_fact "$ident" branch)" "${bound:-}" "$verdict"
        return 0
      fi
      echo "Repository identity"
      printf '  %-10s %s\n' root    "$(repo_fact "$ident" root)"
      printf '  %-10s %s\n' locator "$locator"
      printf '  %-10s %s\n' head    "$(repo_fact "$ident" head)"
      printf '  %-10s %s\n' branch  "$(repo_fact "$ident" branch)"
      echo
      if [ -z "$bound" ]; then
        yellow "  unbound — mutation authority defaults to this repository"
        echo "  Record it with: spark repo bind"
      elif [ "$verdict" = "same" ]; then
        green "  bound to $bound — this repository"
      else
        red "  BOUNDARY — bound to $bound, but this is $locator"
        echo "  Mutation authority does not transfer. Hand off explicitly, or stop."
        return 4
      fi
      ;;
    *)
      red "unknown repo action: $action"; echo "$usage_line"; return 1 ;;
  esac
}
