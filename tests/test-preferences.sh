#!/usr/bin/env bash
# Behavioral tests for preference resolution and --apply: tier precedence,
# create-only application, idempotence, and unknown-stack handling. Also
# validates the rendered release/CI templates (valid JSON/YAML, real paths).

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# --- tier precedence: operator overrides default, project overrides both
mkdir -p "$XDG_CONFIG_HOME/spark"
printf '{"release.mechanism":"manual"}\n' > "$XDG_CONFIG_HOME/spark/preferences.json"
repo="$WORK/tiers"; make_repo "$repo"
mkdir -p "$repo/.spark"
printf '{"branch.model":"trunk-based"}\n' > "$repo/.spark/preferences.json"

out="$(cd "$repo" && "$SPARK" preferences 2>&1)" || { bad "preferences failed"; finish; }
assert_contains "operator tier wins its key"  "[operator]" "$(printf '%s' "$out" | grep 'release.mechanism')"
assert_contains "operator value resolved"     "manual"     "$(printf '%s' "$out" | grep 'release.mechanism')"
assert_contains "project tier wins its key"   "[project]"  "$(printf '%s' "$out" | grep 'branch.model')"
assert_contains "untouched key stays default" "[default]"  "$(printf '%s' "$out" | grep 'stack.default')"

# --- works outside a git repo: project tier absent, still resolves
rc=0; out="$(cd "$WORK" && "$SPARK" preferences 2>&1)" || rc=$?
assert_rc "resolves outside a repo" 0 "$rc"
assert_contains "operator override still applies" "manual" "$(printf '%s' "$out" | grep 'release.mechanism')"

# --- --apply is create-only and idempotent (default prefs: release-please + python-uv)
rm "$XDG_CONFIG_HOME/spark/preferences.json"
repo2="$WORK/apply"; make_repo "$repo2"
rc=0; out="$(cd "$repo2" && "$SPARK" preferences --apply 2>&1)" || rc=$?
assert_rc "first apply exits 0" 0 "$rc"
[ -f "$repo2/release-please-config.json" ] && ok || bad "release-please-config.json not created"
[ -f "$repo2/.release-please-manifest.json" ] && ok || bad ".release-please-manifest.json not created"
[ -f "$repo2/.github/workflows/release-please.yml" ] && ok || bad "release-please.yml not created"
[ -f "$repo2/.github/workflows/validate.yml" ] && ok || bad "validate.yml (stack CI) not created"

# rendered templates are valid JSON / YAML
jq empty "$repo2/release-please-config.json" 2>/dev/null && ok || bad "rendered release-please-config.json invalid JSON"
jq empty "$repo2/.release-please-manifest.json" 2>/dev/null && ok || bad "rendered manifest invalid JSON"
if python3 -c "import yaml" 2>/dev/null; then
  for y in "$repo2/.github/workflows/"*.yml; do
    python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$y" 2>/dev/null \
      && ok || bad "rendered $(basename "$y") invalid YAML"
  done
fi

marker="$repo2/CHANGELOG.md"
[ -f "$marker" ] && ok || bad "doc set not created"
echo "project content" > "$marker"
rc=0; out="$(cd "$repo2" && "$SPARK" preferences --apply 2>&1)" || rc=$?
assert_rc "second apply exits 0" 0 "$rc"
assert_contains "second apply keeps files" "exists — kept" "$out"
[ "$(cat "$marker")" = "project content" ] && ok || bad "apply overwrote an existing project file"

# --- unknown stack: no CI template — an advisory attention item, exit 0
repo3="$WORK/badstack"; make_repo "$repo3"
mkdir -p "$repo3/.spark"
printf '{"stack.default":"fortran-punchcards"}\n' > "$repo3/.spark/preferences.json"
rc=0; out="$(cd "$repo3" && "$SPARK" preferences --apply 2>&1)" || rc=$?
assert_rc "unknown stack stays advisory" 0 "$rc"
assert_contains "names the missing stack template" "no CI template for stack" "$out"
[ ! -e "$repo3/.github/workflows/validate.yml" ] && ok || bad "unknown stack still wrote a CI workflow"

finish
