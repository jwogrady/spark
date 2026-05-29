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
  echo "Spark guard: $1" >&2
  exit 2
}

# Only inspect git commands.
case "$cmd" in
  *git*) ;;
  *) exit 0 ;;
esac

# 1. Force push (allow the safer --force-with-lease).
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+push' \
   && printf '%s' "$cmd" | grep -Eq -- '(--force([^-]|$)|[[:space:]]-f([[:space:]]|$))' \
   && ! printf '%s' "$cmd" | grep -Eq -- '--force-with-lease'; then
  block "force-push is blocked. Use --force-with-lease if you truly must rewrite a shared branch, and confirm with the author first."
fi

# 2. Push to master/main.
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+push' \
   && printf '%s' "$cmd" | grep -Eq '([[:space:]:]|^)(master|main)([[:space:]]|$)'; then
  block "pushing to master/main is blocked. Open a feature branch and a PR instead (see the ship skill)."
fi

exit 0
