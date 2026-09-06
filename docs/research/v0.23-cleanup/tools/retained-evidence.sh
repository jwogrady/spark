#!/usr/bin/env bash
# Reproducible evidence for the RETAINED candidates (#738 audit): call sites, git history, runtime execution, tests.
set -uo pipefail
cd "${1:-.}" || exit 1
SPARK="$PWD/plugins/spark/bin/spark"
echo "=== legacy state keys: call sites (non-comment lines) ==="
grep -nwE 'STATE_LEGACY_KEYS|is_legacy_key' plugins/spark/bin/spark | grep -vE ':[0-9]+:\s*#' | cut -c1-140
echo "=== legacy state keys: git history ==="
git log --format='  %h %cs %s' -S'STATE_LEGACY_KEYS' -- plugins/spark/bin/spark | tail -3
echo "=== legacy state keys: test references ==="
grep -rlwE 'STATE_LEGACY_KEYS|is_legacy_key|legacy keys' tests | sed 's/^/  /' || echo "  none"
echo "=== legacy state keys: runtime execution against a fixture with pre-v0.16 keys ==="
W="$(mktemp -d)"; export HOME="$W/home" XDG_CONFIG_HOME="$W/home/.config"; mkdir -p "$XDG_CONFIG_HOME"; export GIT_CONFIG_NOSYSTEM=1
git config --global user.email t@example.invalid; git config --global user.name t; git config --global init.defaultBranch master
mkdir -p "$W/repo/.spark"; ( cd "$W/repo" && git init -q && echo seed > seed.txt && git add . && git commit -qm "chore: seed" )
printf '{\n  "stage": "codify",\n  "issue": "42",\n  "branch": "feat/x",\n  "pr": "",\n  "next_action": "keep going",\n  "blockers": "",\n  "updated": "2026-01-01"\n}\n' > "$W/repo/.spark/state.json"
( cd "$W/repo" && "$SPARK" state 2>&1 | grep -iE 'legacy|stage|next_action' | cut -c1-160 | sed 's/^/  read: /' )
( cd "$W/repo" && "$SPARK" state --set blockers="none" >/dev/null 2>&1; echo "  after write:"; sed 's/^/    /' .spark/state.json )
rm -rf "$W"
echo "=== enhancement alias / --prune-deprecated: call sites ==="
grep -nE 'prune-deprecated|"enhancement"' plugins/spark/bin/spark | grep -vE ':[0-9]+:\s*#' | cut -c1-140
echo "=== enhancement alias: git history ==="
git log --format='  %h %cs %s' -S'prune-deprecated' -- plugins/spark/bin/spark | tail -3
echo "=== enhancement alias: test and doc references ==="
grep -rlE 'prune-deprecated|enhancement' tests plugins/spark/docs | sed 's/^/  /'
echo "=== single-reference functions: dispatch table and by-name passing ==="
awk '/^VERBS=/{f=1;next} f&&/^"$/{f=0} f' plugins/spark/bin/spark | grep -cE '\|cmd_[a-z_]+\|' | sed 's/^/  verbs dispatched via VERBS: /'
grep -nE 'fp_median3_ms fp_hot_' plugins/spark/bin/spark | cut -c1-120 | sed 's/^/  /'
