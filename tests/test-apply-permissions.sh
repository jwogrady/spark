#!/usr/bin/env bash
# Behavioral tests for spark apply-permissions: create, keep, merge, decline,
# invalid JSON, and the no-parser degradation.

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

finish
