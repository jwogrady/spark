#!/usr/bin/env bash
# Behavioral tests for spark brief / resume: non-repo, no state, malformed
# state, and stale recorded facts.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# --- outside a git repo
rc=0; out="$(cd "$WORK" && "$SPARK" brief --short 2>&1)" || rc=$?
assert_rc "brief outside a repo exits 0" 0 "$rc"
[ -z "$out" ] && ok || bad "brief outside a repo should print nothing, got: $out"

rc=0; ( cd "$WORK" && "$SPARK" resume ) >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "resume outside a repo should exit non-zero"; fi

# --- repo without state: resume explains how to get one, exits 0
repo="$WORK/nostate"; make_repo "$repo"
rc=0; out="$(cd "$repo" && "$SPARK" resume 2>&1)" || rc=$?
assert_rc "resume with no state exits 0" 0 "$rc"
[ -n "$out" ] && ok || bad "resume with no state printed nothing"

# --- malformed state degrades, never invents facts
repo2="$WORK/badstate"; make_repo "$repo2"
mkdir -p "$repo2/.spark"
printf 'this is not json{{{\n' > "$repo2/.spark/state.json"
rc=0; out="$(cd "$repo2" && "$SPARK" resume 2>&1)" || rc=$?
assert_rc "malformed state exits 0" 0 "$rc"
assert_contains "reports unreadable facts" "no facts" "$out"

# --- stale facts are flagged as drift, the repo is the truth
repo3="$WORK/stale"; make_repo "$repo3"
mkdir -p "$repo3/.spark"
cat > "$repo3/.spark/state.json" <<'EOF'
{
  "stage": "codify",
  "problem_statement": "",
  "issue": "",
  "branch": "feat/branch-that-does-not-exist",
  "pr": "",
  "blockers": "",
  "next_action": "keep going",
  "updated": "2026-01-01"
}
EOF
rc=0; out="$(cd "$repo3" && "$SPARK" resume 2>&1)" || rc=$?
assert_rc "stale state still exits 0" 0 "$rc"
assert_contains "drift is flagged" "drift" "$out"

finish
