#!/usr/bin/env bash
# Regression tests for the commit-msg git hook: conventional-commit rules,
# git-generated subject exemptions, and the AI-attribution ban.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

hook="$WORK/plugin/scripts/hooks/commit-msg"
msg="$WORK/msg.txt"

run_hook() { printf '%s\n' "$1" > "$msg"; local rc=0; bash "$hook" "$msg" >/dev/null 2>&1 || rc=$?; echo "$rc"; }

allow() { assert_rc "$1" 0 "$(run_hook "$2")"; }
deny()  { local rc; rc="$(run_hook "$2")"; if [ "$rc" -ne 0 ]; then ok; else bad "$1 — expected rejection"; fi; }

# --- conventional subjects
allow "feat subject"                "feat: add a thing"
allow "scoped fix"                  "fix(guard): close a bypass"
allow "breaking marker"             "feat!: change the contract"
deny  "no type prefix"              "add a thing"
deny  "unknown type"                "wip: half done"
deny  "trailing period"             "feat: add a thing."
deny  "subject over 72 chars"       "feat: $(printf 'x%.0s' $(seq 1 80))"

# --- git-generated subjects are exempt from style rules
allow "merge branch"                "Merge branch 'feat/x'"
allow "merge pull request"          "Merge pull request #1 from jwogrady/feat-x"
allow "revert"                      'Revert "feat: something"'
allow "autosquash fixup"            "fixup! feat: earlier thing"
allow "autosquash squash"           "squash! feat: earlier thing"
deny  "hand-written merge prose"    "Merged some stuff by hand"

# --- AI attribution is banned everywhere, git-generated or not
deny  "co-author trailer"           "feat: x

Co-authored-by: Claude <noreply@anthropic.com>"
deny  "generated-with line"         "feat: x

Generated with Claude Code"
deny  "attribution on a merge"      "Merge branch 'x'

Co-authored-by: Claude <noreply@anthropic.com>"

finish
