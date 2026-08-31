#!/usr/bin/env bash
# Behavioural suite for #623 — fail closed on cross-repository mutation.
#
# THE INCIDENT, reproduced. A session bound to repository A received a prompt
# written for repository B. The issue numbers it named did not exist in A, so
# the agent found them in B and carried on writing there — routing around the
# worktree boundary with `git -C` and absolute paths when the session pulled it
# back.
#
# The hole was not a missing pattern rule:
#
#     repository DISCOVERY was treated as repository AUTHORIZATION.
#
# So the authority is a resolved repository identity, and the fixtures below
# pin the three things that makes true:
#
#   * a write aimed at another repository is refused BEFORE that repository
#     changes, whatever syntax reaches it;
#   * reading another repository stays legitimate — evidence gathering is not
#     mutation, and confusing the two would make the boundary unusable;
#   * discovering the matching issue in B is NOT a handoff. Only a human saying
#     so is.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "repository boundary (#623)"
sandbox_init
. "$SPARK"

GUARD="$WORK/plugin/hooks/guard-bash.sh"

# Two real repositories with distinct origins: the identity under test is
# canonical git fact, not a path string.
mk() { # mk <dir> <origin-url>
  make_repo "$1"
  git -C "$1" remote add origin "$2"
}
mk "$WORK/A" "git@github.com:jwogrady/project-a.git"
mk "$WORK/B" "https://github.com/jwogrady/project-b.git"

run_guard() { # run_guard <cwd> <command> -> exit code
  local rc=0
  ( cd "$1" && printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/')" \
      | bash "$GUARD" >/dev/null 2>&1 ) || rc=$?
  printf '%s' "$rc"
}
guard_msg() {
  ( cd "$1" && printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/')" \
      | bash "$GUARD" 2>&1 >/dev/null ) || true
}

# --- identity is canonical, not textual --------------------------------------
IDA="$(repo_identity "$WORK/A")"
assert_contains "an ssh remote normalises to a canonical locator" \
  "github.com/jwogrady/project-a" "$(repo_fact "$IDA" locator)"
IDB="$(repo_identity "$WORK/B")"
assert_contains "an https remote normalises the same way" \
  "github.com/jwogrady/project-b" "$(repo_fact "$IDB" locator)"

# The same repository spelled two ways is one repository.
assert_contains "ssh and https forms of one repo agree" "github.com/o/n" \
  "$(repo_locator_normalize 'git@github.com:o/n.git')"
assert_contains "and so does the https form" "github.com/o/n" \
  "$(repo_locator_normalize 'https://github.com/o/n.git')"

# An unresolvable identity is NOT ASSESSED, and never silently equal.
assert_contains "a non-repository reports unreadable" "__unreadable__" \
  "$(repo_fact "$(repo_identity "$WORK")" locator)"
assert_contains "an unresolved side is never 'same'" "unassessed" \
  "$(repo_authorize "" "github.com/jwogrady/project-a")"
assert_contains "and neither is an unresolved target" "unassessed" \
  "$(repo_authorize "github.com/jwogrady/project-a" "__unreadable__")"

assert_contains "identical locators authorize"  "same" \
  "$(repo_authorize "github.com/x/y" "github.com/x/y")"
assert_contains "different locators do not"     "boundary" \
  "$(repo_authorize "github.com/x/y" "github.com/x/z")"

# --- THE INCIDENT: a write into the sibling repository is refused ------------
# Bound to A; the prompt's objects live in B; the agent reaches for B.
repo_bind "$WORK/A" "github.com/jwogrady/project-a"

[ "$(run_guard "$WORK/A" "git -C $WORK/B commit -m 'implement #611'")" = "2" ] && ok \
  || bad "a commit into the sibling repository must be refused"
MSG="$(guard_msg "$WORK/A" "git -C $WORK/B commit -m x")"
assert_contains "the refusal names the target"       "project-b" "$MSG"
assert_contains "and what authority is bound to"     "project-a" "$MSG"
assert_contains "and why discovery is not authority" "never permission to write there" "$MSG"

# B must be untouched: refused BEFORE the repository changes.
[ "$(git -C "$WORK/B" rev-list --count HEAD)" = "1" ] && ok \
  || bad "the sibling repository was modified despite the refusal"

# The same crossing by other syntax — the point of resolving identity rather
# than matching one command shape.
[ "$(run_guard "$WORK/A" "git --git-dir=$WORK/B/.git push origin main")" = "2" ] && ok \
  || bad "--git-dir must be covered by the same rule"
[ "$(run_guard "$WORK/A" "gh pr create --repo jwogrady/project-b --title x")" = "2" ] && ok \
  || bad "a gh write against another repo must be covered"
[ "$(run_guard "$WORK/A" "gh api --method POST repos/x/y/issues --repo jwogrady/project-b")" = "2" ] && ok \
  || bad "an API write against another repo must be covered"

# --- reads across repositories stay legitimate -------------------------------
# Evidence gathering is not mutation; a boundary that blocked it would be
# unusable and would train people to disable it.
[ "$(run_guard "$WORK/A" "git -C $WORK/B log --oneline -5")" = "0" ] && ok \
  || bad "reading a sibling repository must remain allowed"
[ "$(run_guard "$WORK/A" "git -C $WORK/B status --porcelain")" = "0" ] && ok \
  || bad "status against a sibling repository must remain allowed"
[ "$(run_guard "$WORK/A" "gh pr view 611 --repo jwogrady/project-b")" = "0" ] && ok \
  || bad "viewing a sibling PR must remain allowed"
[ "$(run_guard "$WORK/A" "gh issue list --repo jwogrady/project-b")" = "0" ] && ok \
  || bad "listing sibling issues must remain allowed"

# --- work in the bound repository is unaffected ------------------------------
[ "$(run_guard "$WORK/A" "git -C $WORK/A commit -m 'own work'")" = "0" ] && ok \
  || bad "a commit in the bound repository must not be blocked"
[ "$(run_guard "$WORK/A" "gh pr create --repo jwogrady/project-a --title x")" = "0" ] && ok \
  || bad "a gh write against the bound repository must not be blocked"

# --- discovery is not handoff ------------------------------------------------
# The negative control the incident demands: knowing B's issue exists changes
# nothing about authority over B.
[ "$(run_guard "$WORK/A" "gh issue view 611 --repo jwogrady/project-b")" = "0" ] && ok \
  || bad "reading the sibling issue must be allowed"
[ "$(run_guard "$WORK/A" "git -C $WORK/B commit -m 'now implement it'")" = "2" ] && ok \
  || bad "having read the sibling issue must NOT authorize writing there"

# A handoff needs a human. The flagless form refuses and says so.
out="$(cd "$WORK/A" && "$SPARK" repo handoff --to github.com/jwogrady/project-b 2>&1)" && rc=0 || rc=$?
[ "$rc" = "4" ] && ok || bad "an unauthorized handoff must fail closed (got $rc)"
assert_contains "and demand explicit authorization" "needs explicit authorization" "$out"
assert_contains "restating that discovery is not handoff" "never a handoff" "$out"
[ "$(cd "$WORK/A" && repo_bound_locator "$WORK/A")" = "github.com/jwogrady/project-a" ] && ok \
  || bad "a refused handoff must not rebind"

# --- an explicit handoff rebinds, and then permits ---------------------------
out="$(cd "$WORK/A" && "$SPARK" repo handoff --to github.com/jwogrady/project-b --yes 2>&1)"
assert_contains "an authorized handoff rebinds" "bound to github.com/jwogrady/project-b" "$out"
# Root, HEAD and branch are re-established against the repository now in force.
assert_contains "and re-resolves the head" "$(git -C "$WORK/A" rev-parse HEAD)" "$out"
[ "$(run_guard "$WORK/A" "git -C $WORK/B commit -m 'now authorized'")" = "0" ] && ok \
  || bad "after an explicit handoff the write must be permitted"

# --- the three results are distinct ------------------------------------------
repo_bind "$WORK/A" "github.com/jwogrady/project-a"
MSG="$(guard_msg "$WORK/A" "git -C $WORK/B commit -m x")"
assert_contains "a boundary refusal names itself" "repository boundary" "$MSG"
case "$MSG" in
  *"DECISION REQUIRED"*) bad "a repository mismatch must not be reported as project judgment" ;;
  *) ok ;;
esac
case "$MSG" in
  *"NOT ASSESSED"*) bad "a repository mismatch must not be reported as missing evidence" ;;
  *) ok ;;
esac

# --- existing protections remain ---------------------------------------------
# This is an additional authority dimension, not a replacement.
[ "$(run_guard "$WORK/A" "git push --force origin feature")" = "2" ] && ok \
  || bad "force-push protection must remain intact"
[ "$(run_guard "$WORK/A" "git push origin master")" = "2" ] && ok \
  || bad "trunk-push protection must remain intact"

# --- the documented contract --------------------------------------------------
DOC="$repo_root/docs/ops/repository-boundary.md"
[ -f "$DOC" ] && ok || bad "the boundary must be documented at docs/ops/repository-boundary.md"
if [ -f "$DOC" ]; then
  assert_contains "and state that discovery is not authorization" \
    "not authorization" "$(cat "$DOC")"
fi

# --- MUTATION CONTROL --------------------------------------------------------
# Treat every cross-repository command as read-only — the deny-list mistake this
# design avoids. The incident fixture must go red.
mutant_runtime 's#^  guard_is_read_only() {#  guard_is_read_only() { return 0; #'
if [ "$MUTANT_CHANGED" = "1" ]; then ok
else bad "MUTATION control changed nothing — it proves nothing"; fi
MGUARD="$WORK/mutant-plugin/hooks/guard-bash.sh"
mrc=0
( cd "$WORK/A" && printf '{"tool_input":{"command":"git -C %s commit -m x"}}' "$WORK/B" \
    | bash "$MGUARD" >/dev/null 2>&1 ) || mrc=$?
if [ "$mrc" = "2" ]; then
  bad "MUTATION control — the cross-repo write was still refused; the fixture does not discriminate"
else ok; fi

finish
