#!/usr/bin/env bash
# Behavioral tests for setup profiles: inspection via spark profiles,
# selection writing committed project facts, all-or-nothing rejection of
# unknown/unsupported/conflicting selections, unchanged default behavior,
# and idempotent re-runs.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# --- inspection: both shipped profiles listed, default marked, exit 0
rc=0; out="$("$SPARK" profiles 2>&1)" || rc=$?
assert_rc "spark profiles exits 0" 0 "$rc"
assert_contains "lists python-uv"        "python-uv" "$out"
assert_contains "lists typescript-bun"   "typescript-bun" "$out"
assert_contains "marks the shipped default" "(the shipped default)" "$out"
assert_contains "marks the override"     "overrides default" "$out"

# --- selection: profile facts committed, CI follows the profile's stack
repo="$WORK/select"; make_repo "$repo"
rc=0; out="$(cd "$repo" && "$SPARK" setup --yes --profile typescript-bun 2>&1)" || rc=$?
assert_rc "setup --profile applies" 0 "$rc"
assert_contains "reports the committed facts" ".spark/preferences.json" "$out"
grep -q '"stack.default": "typescript-bun"' "$repo/.spark/preferences.json" \
  && ok || bad "profile facts not committed to .spark/preferences.json"
grep -qi 'bun' "$repo/.github/workflows/validate.yml" \
  && ok || bad "CI template does not follow the profile's stack"

# --- idempotent re-run: same profile, facts kept, exit 0
rc=0; out="$(cd "$repo" && "$SPARK" setup --yes --profile typescript-bun 2>&1)" || rc=$?
assert_rc "re-run with the same profile exits 0" 0 "$rc"
assert_contains "reports the profile as kept" "kept" "$out"

# --- no profile: shipped defaults unchanged, no project facts invented
repo2="$WORK/default"; make_repo "$repo2"
rc=0; ( cd "$repo2" && "$SPARK" setup --yes ) >/dev/null 2>&1 || rc=$?
assert_rc "profile-less setup still works" 0 "$rc"
[ ! -e "$repo2/.spark/preferences.json" ] \
  && ok || bad "profile-less setup invented project facts"
grep -qi 'uv' "$repo2/.github/workflows/validate.yml" \
  && ok || bad "profile-less setup lost the default stack CI"

# --- unknown profile: whole run refused, nothing materialized
repo3="$WORK/unknown"; make_repo "$repo3"
rc=0; out="$(cd "$repo3" && "$SPARK" setup --yes --profile fortran-punchcards 2>&1)" || rc=$?
assert_rc "unknown profile is refused" 1 "$rc"
assert_contains "points at the profile list" "spark profiles" "$out"
{ [ ! -e "$repo3/.spark" ] && [ ! -e "$repo3/.claude" ] && [ ! -e "$repo3/CHANGELOG.md" ]; } \
  && ok || bad "unknown profile still materialized files"

# --- unsupported combination: named stack has no CI template — refused whole
printf '{"stack.default":"cobol-punchcards"}\n' > "$WORK/plugin/preferences/profiles/legacy.json"
repo4="$WORK/unsupported"; make_repo "$repo4"
rc=0; out="$(cd "$repo4" && "$SPARK" setup --yes --profile legacy 2>&1)" || rc=$?
assert_rc "unsupported combination is refused" 1 "$rc"
assert_contains "names the missing template" "no CI template" "$out"
{ [ ! -e "$repo4/.spark" ] && [ ! -e "$repo4/CHANGELOG.md" ]; } \
  && ok || bad "unsupported profile partially materialized"
rc=0; out="$("$SPARK" profiles 2>&1)" || rc=$?
assert_contains "profiles marks it unsupported" "unsupported" "$out"

# --- conflicting project facts: refused, file untouched, nothing else written
repo5="$WORK/conflict"; make_repo "$repo5"
mkdir -p "$repo5/.spark"
printf '{"stack.default":"python-uv"}\n' > "$repo5/.spark/preferences.json"
before="$(cat "$repo5/.spark/preferences.json")"
rc=0; out="$(cd "$repo5" && "$SPARK" setup --yes --profile typescript-bun 2>&1)" || rc=$?
assert_rc "conflicting facts are refused" 1 "$rc"
assert_contains "explains the refusal" "never overwrites project decisions" "$out"
[ "$before" = "$(cat "$repo5/.spark/preferences.json")" ] \
  && ok || bad "conflict path modified the project facts"
[ ! -e "$repo5/CHANGELOG.md" ] && ok || bad "conflict path still materialized files"

finish
