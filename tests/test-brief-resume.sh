#!/usr/bin/env bash
# Behavioral tests for spark brief / resume under the derive-first model
# (#347): reality is read from git/GitHub at run time; .spark/state.json
# contributes only dated judgment (next_action/blockers). Covers: non-repo,
# no state, malformed state, legacy-schema state, the derived loop-close, and
# the classification/standards reporting the brief carries.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# --- outside a git repo
rc=0; out="$(cd "$WORK" && "$SPARK" brief --short 2>&1)" || rc=$?
assert_rc "brief outside a repo exits 0" 0 "$rc"
[ -z "$out" ] && ok || bad "brief outside a repo should print nothing, got: $out"

rc=0; ( cd "$WORK" && "$SPARK" resume ) >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "resume outside a repo should exit non-zero"; fi

# --- repo without state: resume still derives current reality, exits 0
repo="$WORK/nostate"; make_repo "$repo"
rc=0; out="$(cd "$repo" && "$SPARK" resume 2>&1)" || rc=$?
assert_rc "resume with no state exits 0" 0 "$rc"
assert_contains "derives the current branch anyway" "Current reality" "$out"
assert_contains "says nothing is recorded" "Recorded intent: none" "$out"

# --- malformed state degrades, never invents facts
repo2="$WORK/badstate"; make_repo "$repo2"
mkdir -p "$repo2/.spark"
printf 'this is not json{{{\n' > "$repo2/.spark/state.json"
rc=0; out="$(cd "$repo2" && "$SPARK" resume 2>&1)" || rc=$?
assert_rc "malformed state exits 0" 0 "$rc"
assert_contains "reports unreadable facts" "no facts" "$out"
assert_contains "reality is still derived" "Current reality" "$out"

# --- legacy-schema state: derivable facts in the file are ignored and flagged;
# the recorded judgment is still surfaced. The stale-brief failure is
# structurally unreproducible: no recorded stage/branch is ever presented as
# current.
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
assert_rc "legacy state still exits 0" 0 "$rc"
assert_contains "legacy keys are flagged as ignored" "legacy keys" "$out"
assert_contains "recorded judgment survives" "keep going" "$out"
case "$out" in
  *"feat/branch-that-does-not-exist"*) bad "a recorded branch must never be presented" ;;
  *) ok ;;
esac
out="$(cd "$repo3" && "$SPARK" brief --short 2>&1)"
case "$out" in
  *"codify"*|*"Codify — issue"*) bad "brief must not echo a recorded stage" ;;
  *) ok ;;
esac
assert_contains "brief dates the recorded intent" "recorded 2026-01-01" "$out"

# --- derived loop-close: when the current branch's PR reports MERGED, resume
# says the loop is closed and refuses to replay the recorded next_action.
# gh is faked so the suite stays offline-deterministic.
repo7="$WORK/loopclose"; make_repo "$repo7"
mkdir -p "$repo7/.spark"
cat > "$repo7/.spark/state.json" <<'EOF'
{ "next_action": "push and open the PR", "blockers": "", "updated": "2026-02-02" }
EOF
fakebin="$WORK/fakegh"; mkdir -p "$fakebin"
cat > "$fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"pr view"*) printf '7|MERGED\n'; exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$fakebin/gh"
rc=0; out="$(cd "$repo7" && env PATH="$fakebin:$PATH" "$SPARK" resume 2>&1)" || rc=$?
assert_rc "loop-close resume exits 0" 0 "$rc"
assert_contains "the merged PR is derived" "#7 (MERGED)" "$out"
assert_contains "the loop is declared closed" "loop is closed" "$out"
case "$out" in
  *"What's next:"*"push and open the PR"*) bad "a pre-merge next_action must not be replayed" ;;
  *) ok ;;
esac

# --- classified repo (issue #201): brief names the recorded classification,
# the date it was established, and the project-local standards docs present.
repo4="$WORK/classified"; fixture_mature_repo "$repo4"
mkdir -p "$repo4/.spark"
cat > "$repo4/.spark/preferences.json" <<'EOF'
{
  "project.classification": "existing",
  "project.classified": "2026-02-15"
}
EOF
: > "$repo4/CONVENTIONS.md"
: > "$repo4/ENGINEERING-STANDARDS.md"
rc=0; out="$(cd "$repo4" && "$SPARK" brief 2>&1)" || rc=$?
assert_rc "brief in a classified repo exits 0" 0 "$rc"
assert_contains "names the recorded classification" "existing" "$out"
assert_contains "names the date it was established" "2026-02-15" "$out"
assert_contains "lists CONVENTIONS.md" "CONVENTIONS.md" "$out"
assert_contains "lists ENGINEERING-STANDARDS.md" "ENGINEERING-STANDARDS.md" "$out"

# --- unclassified repo: brief recommends the first-run flow, never a guess.
repo5="$WORK/unclassified"; make_repo "$repo5"
rc=0; out="$(cd "$repo5" && "$SPARK" brief 2>&1)" || rc=$?
assert_rc "brief in an unclassified repo exits 0" 0 "$rc"
assert_contains "reports the repo as unclassified" "unclassified" "$out"
assert_contains "recommends the first-run flow" "spark orient" "$out"
assert_contains "reports no standards docs yet" "none yet" "$out"

# --- stale classification: a repo recorded "new" that now carries real sources
# is flagged for re-orientation, and the recorded fact is left untouched.
repo6="$WORK/staleclass"; fixture_mature_repo "$repo6"
mkdir -p "$repo6/.spark"
cat > "$repo6/.spark/preferences.json" <<'EOF'
{
  "project.classification": "new",
  "project.classified": "2026-01-01"
}
EOF
rc=0; out="$(cd "$repo6" && "$SPARK" brief 2>&1)" || rc=$?
assert_rc "brief with a stale classification exits 0" 0 "$rc"
assert_contains "full brief flags the stale classification" "stale" "$out"
# flag only: the recorded fact is never silently rewritten on disk
assert_contains "recorded classification is preserved" '"project.classification": "new"' \
  "$(cat "$repo6/.spark/preferences.json")"
rc=0; out="$(cd "$repo6" && "$SPARK" brief --short 2>&1)" || rc=$?
assert_rc "short brief with a stale classification exits 0" 0 "$rc"
assert_contains "short brief warns about stale orientation" "stale" "$out"

finish
