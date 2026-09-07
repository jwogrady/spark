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
# this fixture has no usable remote, so if gh is present its empty answer is
# ambiguous — the pr line must hedge, never assert a verified absence.
if command -v gh >/dev/null 2>&1; then
  assert_contains "an unanswerable pr lookup is hedged" "unverified" "$out"
fi
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
stub_gh "$fakebin/gh" <<'EOF'
case "$*" in
  *"pr view"*) printf '7|MERGED\n'; exit 0 ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo7" && env PATH="$fakebin:$PATH" "$SPARK" resume 2>&1)" || rc=$?
assert_rc "loop-close resume exits 0" 0 "$rc"
assert_contains "the merged PR is derived" "#7 (MERGED)" "$out"
assert_contains "the loop is declared closed" "loop is closed" "$out"
case "$out" in
  *"What's next:"*"push and open the PR"*) bad "a pre-merge next_action must not be replayed" ;;
  *) ok ;;
esac

# --- trunk-ancestry drift (#344): commits on the remote trunk missing from
# the current branch are surfaced with the count and the trunk name — a
# merged prerequisite may be among them. Uses a local file remote so the
# suite stays offline.
repo8="$WORK/behind"; make_repo "$repo8"
bare8="$WORK/behind-origin.git"
git clone -q --bare "$repo8" "$bare8"
( cd "$repo8" && git remote add origin "$bare8" && git fetch -q origin )
# advance the remote trunk by two commits the local branch does not have
adv8="$WORK/behind-adv"; git clone -q "$bare8" "$adv8"
( cd "$adv8" && git commit --allow-empty -qm "feat: landed prerequisite one" \
    && git commit --allow-empty -qm "feat: landed prerequisite two" && git push -q origin master )
( cd "$repo8" && git fetch -q origin && git checkout -qb feat/dependent )
rc=0; out="$(cd "$repo8" && "$SPARK" resume 2>&1)" || rc=$?
assert_rc "behind-trunk resume exits 0" 0 "$rc"
assert_contains "names the missing-commit count" "2 commit(s) on origin/master are not in this branch" "$out"
assert_contains "warns a prerequisite may be missing" "prerequisite may be missing" "$out"

# --- locate inference order (#369): positional evidence outranks a missing
# problem statement. An open PR on the current branch reads Validate/Ship —
# never Ideate — even when docs/problem-statement.md does not exist.
repo9="$WORK/midpr"; make_repo "$repo9"
( cd "$repo9" && git checkout -qb feat/9-thing )
fakepr="$WORK/fakeghpr"; mkdir -p "$fakepr"
stub_gh "$fakepr/gh" <<'EOF'
case "$*" in
  *"pr view"*) printf 'PR #9 — the thing
' ;;
  *) exit 1 ;;
esac
EOF
rc=0; out="$(cd "$repo9" && env PATH="$fakepr:$PATH" "$SPARK" brief 2>&1)" || rc=$?
assert_rc "mid-PR brief exits 0" 0 "$rc"
assert_contains "an open PR outranks the missing statement" "Validate/Ship" "$out"
case "$out" in *"Ideate"*) bad "a repo mid-PR must not locate as Ideate" ;; *) ok ;; esac

# a working branch without a PR (and without a statement) reads Codify —
# --short does no network, so this is also the short mode's inference.
rc=0; out="$(cd "$repo9" && "$SPARK" brief --short 2>&1)" || rc=$?
assert_rc "working-branch short brief exits 0" 0 "$rc"
assert_contains "a working branch outranks the missing statement" "Codify — working branch feat/9-thing" "$out"

# on trunk with no statement, Ideate remains the honest read.
rc=0; out="$(cd "$repo9" && git checkout -q master && "$SPARK" brief --short 2>&1)" || rc=$?
assert_contains "trunk without a statement is Ideate" "Ideate" "$out"

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

# --- #399: arming a repo is not drift. Onboarding a new project necessarily
# makes it look like an existing one — the standards docs, the two workflows,
# the release config and the .spark/ store are precisely the signals the
# classifier reads as "existing" — so comparing the live verdict against the
# recorded fact fired on every healthy repo, seconds after setup wrote the
# files that triggered it. A warning that is always wrong trains operators to
# ignore it, which is the expensive failure.
#
# The fixture holds nothing but Spark's own output: a repo on a feature branch
# (setup installs the pre-commit hook that blocks trunk commits) carrying only
# a README, then armed.
arm_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" symbolic-ref HEAD refs/heads/work
  printf '# app\n' > "$dir/README.md"
  ( cd "$dir" && "$SPARK" setup ) >/dev/null 2>&1
  ( cd "$dir" && "$SPARK" orient --set new ) >/dev/null 2>&1
  ( cd "$dir" && git add -A && git commit -qm "chore: arm the repo with spark setup" ) >/dev/null 2>&1
}

repo7="$WORK/armed-new"; arm_repo "$repo7"
rc=0; out="$(cd "$repo7" && "$SPARK" brief 2>&1)" || rc=$?
assert_rc "brief on a freshly armed repo exits 0" 0 "$rc"
case "$out" in
  *stale*) bad "#399: brief warns stale immediately after setup armed the repo" ;;
  *) ok ;;
esac
rc=0; out="$(cd "$repo7" && "$SPARK" brief --short 2>&1)" || rc=$?
case "$out" in
  *stale*) bad "#399: short brief warns stale immediately after setup armed the repo" ;;
  *) ok ;;
esac
# flag-only still holds: nothing was rewritten to make the warning go away
assert_contains "#399: the recorded fact is untouched" '"project.classification": "new"' \
  "$(cat "$repo7/.spark/preferences.json")"

# The warning must still fire the day the fact genuinely is stale: a codebase
# Spark did not create appearing under a "new" classification.
printf '{"name":"app"}\n' > "$repo7/package.json"
mkdir -p "$repo7/src"; printf 'console.log(1)\n' > "$repo7/src/index.js"
( cd "$repo7" && git add -A && git commit -qm "feat: add the application" ) >/dev/null 2>&1
out="$(cd "$repo7" && "$SPARK" brief 2>&1)" || true
assert_contains "#399: real source growth is still flagged stale" "stale" "$out"
out="$(cd "$repo7" && "$SPARK" brief --short 2>&1)" || true
assert_contains "#399: short brief still flags real source growth" "stale" "$out"

# A CI workflow the operator wrote is drift; the two the standard seeds are not.
repo8="$WORK/armed-wf"; arm_repo "$repo8"
out="$(cd "$repo8" && "$SPARK" brief 2>&1)" || true
case "$out" in *stale*) bad "#399: seeded workflows read as drift" ;; *) ok ;; esac
printf 'name: deploy\non: [push]\n' > "$repo8/.github/workflows/deploy.yml"
out="$(cd "$repo8" && "$SPARK" brief 2>&1)" || true
assert_contains "#399: an operator-authored workflow is drift" "stale" "$out"

# A docs/ tree the operator wrote is drift too.
repo9="$WORK/armed-docs"; arm_repo "$repo9"
out="$(cd "$repo9" && "$SPARK" brief 2>&1)" || true
case "$out" in *stale*) bad "#399: a freshly armed repo reads as drift" ;; *) ok ;; esac
mkdir -p "$repo9/docs"; printf '# guide\n' > "$repo9/docs/guide.md"
out="$(cd "$repo9" && "$SPARK" brief 2>&1)" || true
assert_contains "#399: an operator-authored docs tree is drift" "stale" "$out"

finish
