#!/usr/bin/env bash
# Behavioral tests for spark apply-permissions: create, keep, merge, decline,
# invalid JSON, the no-parser degradation, and the trust-tier presets
# (delivery vs conservative — selection, subset invariant, never-narrows).

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

settings=".claude/settings.json"

# --- no settings file: baseline copied in, exit 0, valid JSON
repo="$WORK/create"; make_repo "$repo"
rc=0; ( cd "$repo" && "$SPARK" apply-permissions ) >/dev/null 2>&1 || rc=$?
assert_rc "creates settings from baseline" 0 "$rc"
jq empty "$repo/$settings" 2>/dev/null && ok || bad "created settings is not valid JSON"

# --- re-run: every rule present, kept, exit 0
rc=0; out="$(cd "$repo" && "$SPARK" apply-permissions 2>&1)" || rc=$?
assert_rc "re-run keeps existing settings" 0 "$rc"
assert_contains "reports already applied" "already applied" "$out"

# --- existing partial settings: --yes merges, own rules survive
repo2="$WORK/merge"; make_repo "$repo2"
mkdir -p "$repo2/.claude"
printf '{"permissions":{"allow":["Bash(project-tool:*)"]}}\n' > "$repo2/$settings"
rc=0; ( cd "$repo2" && "$SPARK" apply-permissions --yes ) >/dev/null 2>&1 || rc=$?
assert_rc "merge with --yes exits 0" 0 "$rc"
merged="$(cat "$repo2/$settings")"
assert_contains "project rule survives the merge" "project-tool" "$merged"
baseline_rule="$(jq -r '.permissions.allow[0]' "$WORK/plugin/settings/permission-baseline.json")"
assert_contains "baseline rule arrives" "$baseline_rule" "$merged"

# --- decline path: file untouched, non-zero, nothing written
repo3="$WORK/decline"; make_repo "$repo3"
mkdir -p "$repo3/.claude"
printf '{"permissions":{"allow":["Bash(project-tool:*)"]}}\n' > "$repo3/$settings"
before="$(cat "$repo3/$settings")"
rc=0; out="$(cd "$repo3" && printf 'n\n' | "$SPARK" apply-permissions 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "decline should return non-zero"; fi
assert_contains "decline reports abort" "aborted" "$out"
[ "$before" = "$(cat "$repo3/$settings")" ] && ok || bad "decline modified the settings file"

# --- invalid JSON: refused before any merge
repo4="$WORK/invalid"; make_repo "$repo4"
mkdir -p "$repo4/.claude"
printf '{"permissions": nope}\n' > "$repo4/$settings"
rc=0; out="$(cd "$repo4" && "$SPARK" apply-permissions --yes 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "invalid JSON should fail"; fi
assert_contains "names the JSON problem" "not valid JSON" "$out"

# --- no jq and no python3: degrade to manual-merge guidance
shim="$WORK/shim"; mkdir -p "$shim"
for tool in bash sh git grep sed cat cp mv rm mkdir mktemp basename dirname tr find sort head tail date env uname readlink awk cut wc ls chmod touch; do
  src="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$src" ] && ln -s "$src" "$shim/$tool"
done
repo5="$WORK/noparser"; make_repo "$repo5"
mkdir -p "$repo5/.claude"
printf '{"permissions":{"allow":["Bash(project-tool:*)"]}}\n' > "$repo5/$settings"
rc=0; out="$(cd "$repo5" && env PATH="$shim" "$SPARK" apply-permissions --yes 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "no-parser path should return non-zero"; fi
assert_contains "points at a manual merge" "by hand" "$out"
[ "$(cat "$repo5/$settings")" = "$(printf '{"permissions":{"allow":["Bash(project-tool:*)"]}}\n' )" ] && ok || bad "no-parser path modified settings"

# --- presets: the shipped default is delivery, and it says so
repo6="$WORK/preset-default"; make_repo "$repo6"
rc=0; out="$(cd "$repo6" && "$SPARK" apply-permissions 2>&1)" || rc=$?
assert_rc "default preset applies" 0 "$rc"
assert_contains "names the delivery preset" "Permission preset: delivery" "$out"
assert_contains "delivery grants push" "git push" "$(cat "$repo6/$settings")"

# --- conservative: read-only, nothing push- or write-capable lands
repo7="$WORK/preset-cons"; make_repo "$repo7"
rc=0; out="$(cd "$repo7" && "$SPARK" apply-permissions --preset conservative 2>&1)" || rc=$?
assert_rc "conservative preset applies" 0 "$rc"
assert_contains "names the conservative preset" "Permission preset: conservative" "$out"
cons="$(cat "$repo7/$settings")"
assert_contains "conservative keeps read access" "git status" "$cons"
case "$cons" in
  *"git push"*|*"git commit"*|*"gh pr create"*|*"spark setup"*)
    bad "conservative preset granted a mutating command" ;;
  *) ok ;;
esac

# --- subset invariant: every conservative rule exists in delivery, so
# switching a repo from conservative to delivery only ever adds
missing="$(jq -r '.permissions.allow[]' "$WORK/plugin/settings/permission-baseline-conservative.json" \
  | while IFS= read -r rule; do
      jq -e --arg r "$rule" '.permissions.allow | index($r)' \
        "$WORK/plugin/settings/permission-baseline.json" >/dev/null || printf '%s\n' "$rule"
    done)"
[ -z "$missing" ] && ok || bad "conservative rules missing from delivery: $missing"

# --- never narrows: conservative onto a delivery-armed repo adds nothing
rc=0; out="$(cd "$repo6" && "$SPARK" apply-permissions --preset conservative --yes 2>&1)" || rc=$?
assert_rc "conservative over delivery exits 0" 0 "$rc"
assert_contains "reports nothing to add" "already applied" "$out"
assert_contains "warns that presets never remove" "never remove" "$out"
assert_contains "delivery rules survive" "git push" "$(cat "$repo6/$settings")"

# --- the posture is a preference: committed project fact drives selection
repo8="$WORK/preset-pref"; make_repo "$repo8"
mkdir -p "$repo8/.spark"
printf '{"permissions.preset":"conservative"}\n' > "$repo8/.spark/preferences.json"
rc=0; out="$(cd "$repo8" && "$SPARK" apply-permissions 2>&1)" || rc=$?
assert_rc "preference-driven preset applies" 0 "$rc"
assert_contains "project fact selects conservative" "Permission preset: conservative" "$out"

# --- unknown preset: rejected, nothing written
repo9="$WORK/preset-bogus"; make_repo "$repo9"
rc=0; out="$(cd "$repo9" && "$SPARK" apply-permissions --preset yolo 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "unknown preset should fail"; fi
assert_contains "names the bad preset" "unknown permission preset" "$out"
[ ! -e "$repo9/$settings" ] && ok || bad "unknown preset still wrote settings"

finish
