#!/usr/bin/env bash
# Behavioral tests for spark setup: fresh repo, idempotent re-run, existing
# non-Spark hook, unwritable hooks directory, and exit semantics.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# --- outside a git repo: refuse with non-zero
rc=0; out="$(cd "$WORK" && "$SPARK" setup --yes 2>&1)" || rc=$?
assert_rc "refuses outside a git repo" 1 "$rc"

# --- fresh repo: arms everything, decisions (LICENSE) don't fail the run
repo="$WORK/fresh"; make_repo "$repo"
rc=0; out="$(cd "$repo" && "$SPARK" setup --yes 2>&1)" || rc=$?
assert_rc "fresh repo exits 0" 0 "$rc"
assert_contains "prints the aggregate line" "Setup:" "$out"
[ -x "$repo/.git/hooks/commit-msg" ] && ok || bad "commit-msg hook not installed"
[ -x "$repo/.git/hooks/pre-commit" ] && ok || bad "pre-commit hook not installed"
[ -f "$repo/.claude/settings.json" ] && ok || bad "settings.json not created"
assert_contains "LICENSE surfaces as a decision" "LICENSE" "$out"

# --- idempotent re-run: nothing recreated, still exit 0
before="$(cat "$repo/.claude/settings.json")"
rc=0; out="$(cd "$repo" && "$SPARK" setup --yes 2>&1)" || rc=$?
assert_rc "re-run exits 0" 0 "$rc"
assert_contains "re-run keeps the settings"  "0 created" "$out"
[ "$before" = "$(cat "$repo/.claude/settings.json")" ] && ok || bad "re-run modified settings.json"

# --- existing non-Spark hook: warned about, left untouched, exit 0
repo2="$WORK/foreign-hook"; make_repo "$repo2"
printf '#!/bin/sh\nexit 0\n' > "$repo2/.git/hooks/pre-commit"
chmod +x "$repo2/.git/hooks/pre-commit"
rc=0; out="$(cd "$repo2" && "$SPARK" setup --yes 2>&1)" || rc=$?
assert_rc "foreign hook is a decision, not a failure" 0 "$rc"
[ "$(cat "$repo2/.git/hooks/pre-commit")" = "$(printf '#!/bin/sh\nexit 0\n')" ] && ok || bad "foreign pre-commit was overwritten"

# --- unwritable hooks directory: a mechanical failure, non-zero exit
repo3="$WORK/unwritable"; make_repo "$repo3"
chmod 555 "$repo3/.git/hooks"
rc=0; out="$(cd "$repo3" && "$SPARK" setup --yes 2>&1)" || rc=$?
chmod 755 "$repo3/.git/hooks"
if [ "$rc" -ne 0 ]; then ok; else bad "unwritable hooks dir should fail the run"; fi

# --- #401: a repo with no .gitattributes has no opinion about line endings, so
# the first carried-in third-party source buries real output under one CRLF
# warning per file. The standard provisions it, create-only like everything else.
d="$WORK/gitattrs"; make_repo "$d"
( cd "$d" && "$SPARK" setup ) >/dev/null 2>&1
[ -f "$d/.gitattributes" ] && ok || bad "#401: setup did not create .gitattributes"
attrs="$(cat "$d/.gitattributes")"
assert_contains "#401: normalizes text to LF" "* text=auto eol=lf" "$attrs"
assert_contains "#401: marks images binary" "*.png" "$attrs"
assert_contains "#401: keeps shebang scripts LF" "*.sh" "$attrs"
assert_contains "#401: keeps Windows scripts CRLF" "eol=crlf" "$attrs"

# Create-only: a repo that already has one has made a decision.
printf '# mine\n' > "$d/.gitattributes"
out="$(cd "$d" && "$SPARK" setup 2>&1)" || true
assert_contains "#401: an existing .gitattributes is kept" ".gitattributes (exists — kept)" "$out"
[ "$(cat "$d/.gitattributes")" = "# mine" ] && ok \
  || bad "#401: setup overwrote an existing .gitattributes"

finish
