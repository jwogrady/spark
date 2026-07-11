#!/usr/bin/env bash
# Regression tests for the pre-commit git hook: commits on trunk are blocked,
# feature branches pass.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

hook="$WORK/plugin/scripts/hooks/pre-commit"

on_branch() {
  local branch="$1"
  local repo="$WORK/repo-${branch//\//-}"
  make_repo "$repo"
  git -C "$repo" checkout -q -B "$branch"
  local rc=0
  ( cd "$repo" && bash "$hook" ) >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

assert_rc "blocks commit on master"        1 "$(on_branch master)"
assert_rc "blocks commit on main"          1 "$(on_branch main)"
assert_rc "allows commit on feat branch"   0 "$(on_branch feat/x)"
assert_rc "allows commit on fix branch"    0 "$(on_branch fix/y)"

finish
