#!/usr/bin/env bash
# Spark PreToolUse guard for the Bash tool.
#
# Blocks three classes of dangerous commands before Claude runs them:
#   1. force-pushing  (git push --force / -f)
#   2. pushing directly to master/main
#   3. cutting releases by hand where Release Please owns them
#      (git tag <name> / gh release create, only when
#      release-please-config.json exists — see ADR-0009 and the ship skill)
#
# Protocol: Claude Code passes the tool call as JSON on stdin. Exit code 2
# blocks the call and feeds stderr back to Claude as the reason. Any other
# exit code allows the call.

set -euo pipefail

payload="$(cat)"

# Extract the command string from the JSON payload. Prefer jq, fall back to
# python3, fall back to matching the raw payload (still safe — we only ever
# *block*, never auto-approve, on a match).
extract_command() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null && return 0
  fi
  printf '%s' "$payload"
}

cmd="$(extract_command)"

block() {
  msg="Spark guard: $1"
  # When a shell was invoked, quoted text and heredoc bodies are treated as
  # commands, so a refusal may be about a pattern rather than an invocation.
  # Saying which is the difference between an actionable message and a puzzle.
  if [ "${guard_shell_invoked:-0}" -eq 1 ]; then
    msg="$msg (this command invokes a shell, so quoted text and heredoc bodies are read as commands)"
  fi
  echo "$msg" >&2
  # Log to audit trail if configured (non-blocking). The variable must be
  # expanded with a default everywhere: under set -u an unbound reference
  # kills the script with exit 1 — which the hook protocol reads as ALLOW.
  if [ -n "${SPARK_AUDIT_LOG:-}" ] && [ -w "${SPARK_AUDIT_LOG:-}" ]; then
    printf '[%s] blocked: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$msg" >> "${SPARK_AUDIT_LOG:-}"
  fi
  exit 2
}

# Only inspect commands that can touch git or gh.
case "$cmd" in
  *git*|*gh*) ;;
  *) exit 0 ;;
esac

# Release ownership is conditional: with a release-please-config.json (or a
# release-please workflow — the ship skill names either as the marker) at the
# repo root, tags and GitHub Releases belong to the Release Please workflow
# (the human merging its release PR is the approval act). Without the marker,
# the ship skill's documented manual fallback stays available.
release_please_configured() {
  local root f
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root="."
  [ -f "$root/release-please-config.json" ] && return 0
  # Unmatched globs stay literal, so -f is simply false when nothing matches.
  for f in "$root"/.github/workflows/*release-please*.yml \
           "$root"/.github/workflows/*release-please*.yaml; do
    [ -f "$f" ] && return 0
  done
  return 1
}

# QUOTED TEXT AND HEREDOC BODIES ARE DATA, not commands.
#
# The tokenizer used to replace quotes with spaces and walk everything, on the
# reasoning that an over-block is harmless. It is not: `echo "do not git push
# origin master"`, `grep -r "git push origin master" docs/` and a heredoc whose
# body mentions a push were all refused, and `hooks.md` claims the guard
# "tokenizes the command rather than substring-matching" — a guarantee a release
# would otherwise ship as false (#526).
#
# The rule keeps the bypass-free direction. When the command invokes a SHELL,
# quoted text and heredoc bodies may themselves be commands (`sh -c 'git push
# origin master'`, `sh <<EOF … EOF`), so nothing is stripped and behaviour is
# exactly as before — conservative, possibly over-blocking, never bypassable.
# Only when no shell is invoked is quoted text treated as the data it is.
#
# An unquoted `git push origin master` anywhere still blocks, whatever command
# precedes it: `xargs git push origin master` and `find … -exec git push …` are
# real invocations and stay refused.
guard_shell_invoked=0
case " $(printf '%s' "$cmd" | tr -s '[:space:]' ' ') " in
  *" sh "*|*" bash "*|*" zsh "*|*" dash "*|*" ksh "*|*"/sh "*|*"/bash "*|*"/zsh "*|*"/dash "*|*"/ksh "*)
    guard_shell_invoked=1 ;;
esac

if [ "$guard_shell_invoked" -eq 1 ]; then
  scan="$cmd"
else
  # Drop heredoc bodies, then quoted spans. awk rather than sed: the quote state
  # has to be tracked character by character, and a line-oriented substitution
  # cannot see a span that opens on one line and closes on another.
  scan="$(printf '%s' "$cmd" | awk '
    BEGIN { hd = "" }
    {
      line = $0
      if (hd != "") {                      # inside a heredoc body: data
        stripped = line
        sub(/^[ \t]+/, "", stripped)
        if (stripped == hd) hd = ""
        next
      }
      # Does this line open a heredoc? Capture the delimiter, quoted or not.
      probe = line
      if (match(probe, /<<-?[ \t]*["'\'']?[A-Za-z_][A-Za-z0-9_]*["'\'']?/)) {
        d = substr(probe, RSTART, RLENGTH)
        gsub(/^<<-?[ \t]*/, "", d); gsub(/["'\'']/, "", d)
        hd = d
        sub(/<<-?[ \t]*["'\'']?[A-Za-z_][A-Za-z0-9_]*["'\'']?.*$/, "", line)
      }
      # Remove quoted spans, leaving a space so tokens do not fuse.
      out = ""; i = 1; L = length(line); q = ""
      while (i <= L) {
        c = substr(line, i, 1)
        if (q == "") {
          if (c == "\"" || c == "'\''") { q = c; out = out " " }
          else out = out c
        } else if (c == q) { q = "" }
        i++
      }
      print out
    }')"
fi

normalized="$(printf '%s' "$scan" | tr ';|&()"'\''' '       ')"
# shellcheck disable=SC2206 # word splitting is the tokenizer
tokens=( $normalized )
n=${#tokens[@]}

# The destination side of a refspec (after ':', else the token itself),
# stripped of a fully-qualified refs/heads/ prefix and the force marker '+'.
is_protected_dst() {
  local dst="${1#+}"
  case "$dst" in *:*) dst="${dst#*:}" ;; esac
  dst="${dst#refs/heads/}"
  case "$dst" in
    master|main) return 0 ;;
    *) return 1 ;;
  esac
}

# A refspec whose destination is under refs/tags/ writes a tag on the remote
# directly — `git push origin HEAD:refs/tags/v1` cuts a release tag without
# ever running `git tag`. Deletes (`:refs/tags/v1`) mutate a published tag,
# so the whole namespace is treated as Release Please's.
is_tag_dst() {
  local dst="${1#+}"
  case "$dst" in *:*) dst="${dst#*:}" ;; esac
  case "$dst" in
    refs/tags/*) return 0 ;;
    *) return 1 ;;
  esac
}

# A GitHub wiki repository (<owner>/<repo>.wiki.git) renders only from
# `master`, has exactly one branch, and has no pull request mechanism at all
# (#397). The trunk block's remedy — "open a feature branch and a PR" — can
# therefore never be performed there, so the rule could only ever be
# bypassed. Recognise the destination instead: a wiki URL given literally,
# or a named remote that resolves to one.
is_wiki_url() {
  case "$1" in
    *.wiki.git|*.wiki.git/|*.wiki|*.wiki/) return 0 ;;
    *) return 1 ;;
  esac
}

is_wiki_remote() {
  local r="$1" url=""
  # Judge a value on its own text ONLY when it actually looks like a URL or a
  # path. A bare remote *name* is never trusted to describe its destination:
  # testing the name first let `git push evil.wiki master` through, because
  # the name matched "*.wiki" and the URL was never resolved — a remote named
  # after a wiki but pointing at the trunk repo relaxed the trunk block. That
  # is an under-block, which this hook's tokenizer contract forbids ("can only
  # cause an over-block, never a bypass"), so the name always gets resolved.
  case "$r" in
    */*|*:*) is_wiki_url "$r" && return 0
             return 1 ;;
  esac
  if [ -n "$gitc" ]; then
    url="$(git -C "$gitc" remote get-url -- "$r" 2>/dev/null)" || return 1
  else
    url="$(git remote get-url -- "$r" 2>/dev/null)" || return 1
  fi
  is_wiki_url "$url"
}

i=0
while [ "$i" -lt "$n" ]; do
  t="${tokens[$i]}"

  if [ "${t##*/}" = "gh" ]; then
    # Find gh's first two subcommand words, skipping global options that take
    # a value. `gh release create` cuts a GitHub Release directly — with
    # Release Please configured, that is the release workflow's job.
    g=$((i + 1)) sub1="" sub2=""
    while [ "$g" -lt "$n" ]; do
      a="${tokens[$g]}"
      case "${a##*/}" in git|gh) break ;; esac
      case "$a" in
        -R|--repo|--hostname) g=$((g + 2)); continue ;;
        -*) g=$((g + 1)); continue ;;
      esac
      if [ -z "$sub1" ]; then sub1="$a"
      elif [ -z "$sub2" ]; then sub2="$a"; break
      fi
      g=$((g + 1))
    done
    if [ "$sub1" = "release" ] && [ "$sub2" = "create" ] && release_please_configured; then
      block "creating a GitHub Release by hand is blocked: this repo uses Release Please, so Releases are cut by the release workflow after a human merges its release PR (see the ship skill)."
    fi
    # g is at least i+1 here, so the walk always advances.
    i=$g
    continue
  fi

  if [ "${t##*/}" != "git" ]; then i=$((i + 1)); continue; fi

  # Skip git's global options to find the subcommand. Options that take a
  # separate argument consume two tokens.
  j=$((i + 1))
  gitc=""
  while [ "$j" -lt "$n" ]; do
    case "${tokens[$j]}" in
      # -C names the repository the rest of the invocation acts on, so it is
      # captured (not merely skipped) to resolve a named remote below.
      -C) gitc="${tokens[$((j + 1))]:-}"; j=$((j + 2)) ;;
      -c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix)
        j=$((j + 2)) ;;
      -*) j=$((j + 1)) ;;
      *) break ;;
    esac
  done
  if [ "$j" -ge "$n" ]; then i=$((i + 1)); continue; fi

  if [ "${tokens[$j]}" = "tag" ]; then
    # Classify the tag invocation. Listing, inspecting, and deleting stay
    # allowed everywhere; *creating* a tag is blocked when Release Please
    # owns tags. Non-creating markers win over a stray non-option token so
    # that e.g. `git tag -l v*` never over-blocks (git itself treats a name
    # next to -l as a pattern, so this cannot be abused to create).
    noncreate=0 create=0
    k=$((j + 1))
    while [ "$k" -lt "$n" ]; do
      a="${tokens[$k]}"
      case "${a##*/}" in git|gh) break ;; esac
      case "$a" in
        -l|--list|-d|--delete|-v|--verify|-n|-n[0-9]*|--contains|--no-contains|--points-at|--merged|--no-merged|--sort|--sort=*|--format|--format=*|--column|--column=*|-i|--ignore-case)
          noncreate=1 ;;
        -a|--annotate|-s|--sign|-m|--message|--message=*|-F|--file|--file=*|-u|--local-user|--local-user=*|-f|--force|-e|--edit)
          create=1 ;;
        -*) : ;;
        *) create=1 ;;
      esac
      k=$((k + 1))
    done
    if [ "$create" -eq 1 ] && [ "$noncreate" -eq 0 ] && release_please_configured; then
      block "tagging by hand is blocked: this repo uses Release Please, so tags are cut by the release workflow after a human merges its release PR (see the ship skill)."
    fi
    i=$k
    continue
  fi

  if [ "${tokens[$j]}" = "update-ref" ]; then
    # Plumbing can write refs/tags/* without ever running `git tag`; with
    # Release Please configured that namespace is the release workflow's.
    k=$((j + 1))
    while [ "$k" -lt "$n" ]; do
      a="${tokens[$k]}"
      case "${a##*/}" in git|gh) break ;; esac
      case "$a" in
        refs/tags/*)
          if release_please_configured; then
            block "writing refs/tags/ via update-ref is blocked: this repo uses Release Please, so tags are cut by the release workflow after a human merges its release PR (see the ship skill)."
          fi ;;
      esac
      k=$((k + 1))
    done
    i=$k
    continue
  fi

  if [ "${tokens[$j]}" != "push" ]; then i=$((i + 1)); continue; fi

  # Decide up front whether this push is aimed at a wiki, classifying by the
  # push's *remote* — git's first positional after `push` — and nothing else.
  # Consulting only that one token is what keeps the relaxation un-smuggleable:
  # a wiki-looking string anywhere else in the command line is never consulted,
  # so it cannot turn a trunk push into an allowed one.
  wiki=0
  p=$((j + 1))
  while [ "$p" -lt "$n" ] && [ "${tokens[$p]##*/}" != "git" ]; do
    case "${tokens[$p]}" in
      -o|--push-option|--repo|--receive-pack|--exec) p=$((p + 2)); continue ;;
      -*|+*) p=$((p + 1)); continue ;;
    esac
    is_wiki_remote "${tokens[$p]}" && wiki=1
    break
  done

  # Walk this push invocation's arguments (up to the next `git` token).
  force=0 lease=0
  k=$((j + 1))
  while [ "$k" -lt "$n" ] && [ "${tokens[$k]##*/}" != "git" ]; do
    a="${tokens[$k]}"
    case "$a" in
      --force-with-lease|--force-with-lease=*) lease=1 ;;
      --force) force=1 ;;
      --tags|--follow-tags)
        # Publishing tags wholesale is a release act where Release Please
        # owns tags (creation is blocked, so only fetched tags could ride
        # along — still not a push Spark should make).
        if release_please_configured; then
          block "pushing tags is blocked: this repo uses Release Please, so tags are cut and pushed by the release workflow after a human merges its release PR (see the ship skill)."
        fi ;;
      -o|--push-option|--repo|--receive-pack|--exec) k=$((k + 1)) ;;
      --*) : ;;
      -*)
        # A short-option cluster containing f is a force push (-f, -fu, ...).
        case "$a" in -[A-Za-z]*) case "$a" in *f*) force=1 ;; esac ;; esac ;;
      +*)
        # A leading + on a refspec is a per-refspec force push (a
        # --force-with-lease elsewhere in the command still tempers it).
        force=1
        if [ "$wiki" -eq 0 ] && is_protected_dst "$a"; then
          block "pushing to master/main is blocked. Open a feature branch and a PR instead (see the ship skill)."
        fi
        if is_tag_dst "$a" && release_please_configured; then
          block "pushing a refs/tags/ refspec is blocked: this repo uses Release Please, so tags are cut and pushed by the release workflow after a human merges its release PR (see the ship skill)."
        fi ;;
      *)
        # Remote or refspec: block if the destination is a protected branch.
        # (A remote literally named master/main over-blocks — acceptable.)
        if [ "$wiki" -eq 0 ] && is_protected_dst "$a"; then
          block "pushing to master/main is blocked. Open a feature branch and a PR instead (see the ship skill)."
        fi
        if is_tag_dst "$a" && release_please_configured; then
          block "pushing a refs/tags/ refspec is blocked: this repo uses Release Please, so tags are cut and pushed by the release workflow after a human merges its release PR (see the ship skill)."
        fi ;;
    esac
    k=$((k + 1))
  done

  if [ "$force" -eq 1 ] && [ "$lease" -eq 0 ]; then
    block "force-push is blocked. Use --force-with-lease if you truly must rewrite a shared branch, and confirm with the author first."
  fi
  i=$k
done

# --- Repository boundary (#623) ----------------------------------------------
#
# Discovery is not authorization. A session bound to one project once found a
# prompt's issue numbers in a sibling repository and carried on writing there,
# routing around the worktree boundary with `git -C` and absolute paths.
#
# The authority here is the RESOLVED REPOSITORY IDENTITY, not the spelling of a
# command: `git -C`, `--git-dir` and a `gh --repo` write all reach a different
# repository by different syntax, and comparing canonical locators covers them
# together instead of chasing each form.
#
# It FAILS CLOSED by allow-listing reads rather than deny-listing writes. A
# deny-list is only as complete as its author's imagination, and the one write
# verb nobody thought of is exactly the one that crosses the boundary. Reading
# another repository stays legitimate — evidence gathering is not mutation — so
# recognised read-only commands pass untouched.
guard_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd || true)"
if [ -n "${guard_lib:-}" ] && [ -f "$guard_lib/repository.sh" ]; then
  # shellcheck source=/dev/null
  . "$guard_lib/repository.sh"

  guard_bound_locator() {
    local top b
    top="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
    b="$(repo_bound_locator "$top")"
    if [ -n "$b" ]; then printf '%s' "$b"; return 0; fi
    repo_locator_normalize "$(git -C "$top" remote get-url origin 2>/dev/null || true)"
  }

  # Recognised read-only shapes. Anything not listed is treated as capable of
  # mutation, because that is the safe direction to be wrong in.
  guard_is_read_only() {
    case "$1" in
      *" -X POST"*|*" -X PATCH"*|*" -X PUT"*|*" -X DELETE"*|\
      *" --method POST"*|*" --method PATCH"*|*" --method PUT"*|*" --method DELETE"*)
        return 1 ;;
    esac
    case "$1" in
      *" log"*|*" status"*|*" show "*|*" diff"*|*" rev-parse"*|*" ls-files"*|\
      *" cat-file"*|*" describe"*|*" remote -v"*|*" config --get"*|*" rev-list"*|\
      *" for-each-ref"*|*" ls-remote"*|*" blame"*|*" shortlog"*)
        return 0 ;;
      *"pr list"*|*"pr view"*|*"pr checks"*|*"pr diff"*|*"issue list"*|*"issue view"*|\
      *"repo view"*|*"release list"*|*"release view"*|*"label list"*|*"run list"*|\
      *"run view"*|*"search "*|*"gh api "*)
        return 0 ;;
    esac
    return 1
  }

  guard_target_locator=""
  guard_path_target="$(repo_target_of_command "$cmd" 2>/dev/null || true)"
  if [ -n "${guard_path_target:-}" ]; then
    guard_target_locator="$(repo_locator_normalize "$(git -C "$guard_path_target" remote get-url origin 2>/dev/null || true)")"
  fi
  if [ -z "$guard_target_locator" ]; then
    guard_gh_target="$(repo_gh_repo_of_command "$cmd" 2>/dev/null || true)"
    case "${guard_gh_target:-}" in
      "") ;;
      */*/*) guard_target_locator="$guard_gh_target" ;;
      */*)   guard_target_locator="github.com/$guard_gh_target" ;;
    esac
  fi

  if [ -n "$guard_target_locator" ] && ! guard_is_read_only "$cmd"; then
    guard_bound="$(guard_bound_locator)"
    if [ -n "$guard_bound" ] && [ "$guard_bound" != "$guard_target_locator" ]; then
      block "repository boundary: this would change $guard_target_locator, but mutation authority is bound to $guard_bound. Finding a prompt's objects in another repository is evidence about what the prompt means, never permission to write there. Reads across repositories are allowed; if a write is genuinely intended, hand off explicitly with 'spark repo handoff --to <owner/name> --yes'."
    fi
  fi
fi

exit 0
