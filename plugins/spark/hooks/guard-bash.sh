#!/usr/bin/env bash
# Spark PreToolUse guard for the Bash tool.
#
# Blocks two classes of dangerous git commands before Claude runs them:
#   1. force-pushing  (git push --force / -f)
#   2. pushing directly to master/main
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
  echo "$msg" >&2
  # Log to audit trail if configured (non-blocking). The variable must be
  # expanded with a default everywhere: under set -u an unbound reference
  # kills the script with exit 1 — which the hook protocol reads as ALLOW.
  if [ -n "${SPARK_AUDIT_LOG:-}" ] && [ -w "${SPARK_AUDIT_LOG:-}" ]; then
    printf '[%s] blocked: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$msg" >> "${SPARK_AUDIT_LOG:-}"
  fi
  exit 2
}

# Only inspect git commands.
case "$cmd" in
  *git*) ;;
  *) exit 0 ;;
esac

# Substring matching is bypassable (`git -C /path push`, `HEAD:refs/heads/main`),
# so normalize and walk the tokens instead: find each `git` invocation, skip
# git's global options to reach the real subcommand, and for `push` classify
# every refspec by its *destination* side. Tokenization is whitespace-naive by
# design — a quoted argument containing spaces can only split into more tokens,
# which can only cause an over-block, never a bypass.
normalized="$(printf '%s' "$cmd" | tr ';|&()"'\''' '       ')"
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

i=0
while [ "$i" -lt "$n" ]; do
  t="${tokens[$i]}"
  if [ "${t##*/}" != "git" ]; then i=$((i + 1)); continue; fi

  # Skip git's global options to find the subcommand. Options that take a
  # separate argument consume two tokens.
  j=$((i + 1))
  while [ "$j" -lt "$n" ]; do
    case "${tokens[$j]}" in
      -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix)
        j=$((j + 2)) ;;
      -*) j=$((j + 1)) ;;
      *) break ;;
    esac
  done
  if [ "$j" -ge "$n" ] || [ "${tokens[$j]}" != "push" ]; then i=$((i + 1)); continue; fi

  # Walk this push invocation's arguments (up to the next `git` token).
  force=0 lease=0
  k=$((j + 1))
  while [ "$k" -lt "$n" ] && [ "${tokens[$k]##*/}" != "git" ]; do
    a="${tokens[$k]}"
    case "$a" in
      --force-with-lease|--force-with-lease=*) lease=1 ;;
      --force) force=1 ;;
      -o|--push-option|--repo|--receive-pack|--exec) k=$((k + 1)) ;;
      --*) : ;;
      -*)
        # A short-option cluster containing f is a force push (-f, -fu, ...).
        case "$a" in -[A-Za-z]*) case "$a" in *f*) force=1 ;; esac ;; esac ;;
      +*)
        # A leading + on a refspec is a per-refspec force push (a
        # --force-with-lease elsewhere in the command still tempers it).
        force=1
        if is_protected_dst "$a"; then
          block "pushing to master/main is blocked. Open a feature branch and a PR instead (see the ship skill)."
        fi ;;
      *)
        # Remote or refspec: block if the destination is a protected branch.
        # (A remote literally named master/main over-blocks — acceptable.)
        if is_protected_dst "$a"; then
          block "pushing to master/main is blocked. Open a feature branch and a PR instead (see the ship skill)."
        fi ;;
    esac
    k=$((k + 1))
  done

  if [ "$force" -eq 1 ] && [ "$lease" -eq 0 ]; then
    block "force-push is blocked. Use --force-with-lease if you truly must rewrite a shared branch, and confirm with the author first."
  fi
  i=$k
done

exit 0
