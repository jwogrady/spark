#!/usr/bin/env bash
# Behavioral tests for the guided first-run flow (issue #199, ADR-0021). The
# onboard SKILL.md is prose Claude follows, not executable — so what is tested
# here is the composed CLI sequence it drives end to end: orient → (profile) →
# setup → orient --set → brief, plus the routing hint that names the flow and
# the existing-repo discovery path that creates nothing. Reuses the fixture_*
# builders in lib.sh so the shapes never drift from the classifier suite.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# verdict <dir> — the one-word classification for a fixture, as the flow reads it.
verdict() { ( cd "$1" && "$SPARK" orient 2>/dev/null ) | awk '$1=="classification"{print $2}'; }

# === New project: the guided sequence arms, seeds, records, and briefs green ===
repo="$WORK/newproj"; fixture_empty_git "$repo"

# ORIENT: a fresh repo classifies new, and the bare preflight writes nothing.
v="$(verdict "$repo")"; [ "$v" = "new" ] && ok || bad "new repo: want new, got '$v'"
[ ! -e "$repo/.spark" ] && ok || bad "bare orient wrote .spark on a new repo"

# SEED with a chosen profile: setup arms the repo and seeds the standards docs.
rc=0; out="$(cd "$repo" && "$SPARK" setup --profile python-uv --yes 2>&1)" || rc=$?
assert_rc "guided setup exits 0" 0 "$rc"
assert_contains "setup prints the aggregate line" "Setup:" "$out"
[ -x "$repo/.git/hooks/commit-msg" ] && ok || bad "commit-msg hook not installed"
[ -x "$repo/.git/hooks/pre-commit" ] && ok || bad "pre-commit hook not installed"
[ -f "$repo/.claude/settings.json" ] && ok || bad "settings.json not created"
[ -f "$repo/CONVENTIONS.md" ] && ok || bad "CONVENTIONS.md not seeded"
[ -f "$repo/ENGINEERING-STANDARDS.md" ] && ok || bad "ENGINEERING-STANDARDS.md not seeded"
[ -f "$repo/.spark/preferences.json" ] && ok || bad "profile facts not committed"

# ORIENT --set: record the confirmed verdict; it merges into the profile facts
# rather than clobbering them (create-only, ADR-0022).
rc=0; ( cd "$repo" && "$SPARK" orient --set new ) >/dev/null 2>&1 || rc=$?
assert_rc "orient --set new exits 0" 0 "$rc"
prefs="$(cat "$repo/.spark/preferences.json")"
assert_contains "classification recorded" "project.classification" "$prefs"
assert_contains "profile facts survive the merge" "stack.default" "$prefs"

# BRIEF: the closing summary names the recorded class and the standards docs.
brief="$(cd "$repo" && "$SPARK" brief 2>&1)"
assert_contains "brief reports the classification" "new" "$brief"
assert_contains "brief reports the standards docs" "CONVENTIONS.md" "$brief"

# doctor is green on the armed repo — every fixture scenario must pass it.
rc=0; ( cd "$repo" && "$SPARK" doctor ) >/dev/null 2>&1 || rc=$?
assert_rc "doctor is green after the flow" 0 "$rc"

# === Rerun in an armed repo is a no-op that creates nothing ===
before="$(cat "$repo/.claude/settings.json")"
rc=0; out="$(cd "$repo" && "$SPARK" setup --yes 2>&1)" || rc=$?
assert_rc "rerun exits 0" 0 "$rc"
assert_contains "rerun creates nothing" "0 created" "$out"
[ "$before" = "$(cat "$repo/.claude/settings.json")" ] && ok || bad "rerun modified settings.json"

# a same-value re-set of the classification is a truthful no-op
rc=0; out="$(cd "$repo" && "$SPARK" orient --set new 2>&1)" || rc=$?
assert_rc "same-value re-set exits 0" 0 "$rc"
assert_contains "re-set reports already recorded" "already recorded" "$out"

# === Routing hint: an unoriented, unprofiled setup names the guided flow ===
hint="$WORK/hint"; fixture_empty_git "$hint"
out="$(cd "$hint" && "$SPARK" setup --yes 2>&1)"
assert_contains "unoriented setup names /spark:onboard" "/spark:onboard" "$out"

# an already-classified repo no longer shows the hint (it has been oriented)
out="$(cd "$repo" && "$SPARK" setup --yes 2>&1)"
case "$out" in *"/spark:onboard"*) bad "hint shown after the repo was oriented" ;; *) ok ;; esac

# === Existing project: classifies existing; the discovery path creates nothing ===
mature="$WORK/mature"; fixture_mature_repo "$mature"
v="$(verdict "$mature")"; [ "$v" = "existing" ] && ok || bad "mature repo: want existing, got '$v'"
before="$(git -C "$mature" status --porcelain)"
( cd "$mature" && "$SPARK" orient ) >/dev/null 2>&1
[ "$before" = "$(git -C "$mature" status --porcelain)" ] && ok || bad "discovery dirtied a mature repo"
[ ! -e "$mature/.spark" ] && ok || bad "discovery created .spark on an existing repo"

finish
