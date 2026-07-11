#!/usr/bin/env bash
# Behavioral tests for spark doctor --requirements: capability grouping,
# missing/unauthenticated dependency reporting, JSON output, and the
# core-only exit contract (optional tools must never fail the run).

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# A PATH farm holds symlinks to exactly the tools a scenario allows, so
# "missing dependency" means missing, not merely deprioritized. Tools the
# CLI itself needs (dirname, awk, ...) are always present.
FARM_TOOLS="bash sh dirname readlink basename cat cp mkdir grep sed awk sort tr head env git jq python3"
make_farm() { # make_farm <name> <exclude...>
  local dir="$WORK/farm-$1"; shift
  mkdir -p "$dir"
  local t real skip
  for t in $FARM_TOOLS; do
    skip=0
    for x in "$@"; do [ "$t" = "$x" ] && skip=1; done
    [ "$skip" -eq 1 ] && continue
    real="$(command -v "$t" 2>/dev/null || true)"
    [ -n "$real" ] && ln -s "$real" "$dir/$t"
  done
  printf '%s' "$dir"
}

# gh stubs: auth state must be deterministic, so the real gh (and any
# GH_TOKEN in the environment) never runs in these tests.
make_gh() { # make_gh <farm-dir> <auth-exit>
  cat > "$1/gh" <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  --version) echo "gh version 0.0.0-stub" ;;
  auth) exit $2 ;;
esac
exit 0
EOF
  chmod +x "$1/gh"
}

run_req() { # run_req <farm> [--json] — from inside $REPO
  ( cd "$REPO" && env PATH="$1" bash "$SPARK" doctor --requirements "${2:-}" )
}

REPO="$WORK/repo"; make_repo "$REPO"

# --- fully provisioned environment, release-please wired
full="$(make_farm full)"
make_gh "$full" 0
printf '{}\n' > "$REPO/release-please-config.json"
mkdir -p "$REPO/.github/workflows"
: > "$REPO/.github/workflows/release-please.yml"

rc=0; out="$(run_req "$full" 2>&1)" || rc=$?
assert_rc "fully provisioned env exits 0" 0 "$rc"
assert_contains "reports gh authenticated"   "authenticated" "$out"
assert_contains "reports full readiness"     "every Spark capability" "$out"

rc=0; out="$(run_req "$full" --json 2>&1)" || rc=$?
assert_rc "--json exits 0" 0 "$rc"
printf '%s' "$out" | jq empty 2>/dev/null && ok || bad "--json output is not valid JSON"
[ "$(printf '%s' "$out" | jq -r '.core.ready and .github.ready and .json.ready and .release.ready')" = "true" ] \
  && ok || bad "--json readiness flags not all true in a full environment"

# --- gh missing: optional, named, never fatal
nogh="$(make_farm nogh)"
rc=0; out="$(run_req "$nogh" 2>&1)" || rc=$?
assert_rc "missing gh stays exit 0" 0 "$rc"
assert_contains "names the missing CLI"    "gh not found" "$out"
assert_contains "points at the install"    "cli.github.com" "$out"
assert_contains "still ready for local"    "Ready for basic local use" "$out"
rc=0; out="$(run_req "$nogh" --json 2>&1)" || rc=$?
[ "$(printf '%s' "$out" | jq -r '.github.ready')" = "false" ] \
  && ok || bad "--json github.ready should be false without gh"

# --- gh present but unauthenticated
unauth="$(make_farm unauth)"
make_gh "$unauth" 1
rc=0; out="$(run_req "$unauth" 2>&1)" || rc=$?
assert_rc "unauthenticated gh stays exit 0" 0 "$rc"
assert_contains "remediation is gh auth login" "gh auth login" "$out"
rc=0; out="$(run_req "$unauth" --json 2>&1)" || rc=$?
[ "$(printf '%s' "$out" | jq -r '.github.authenticated')" = "false" ] \
  && ok || bad "--json should report authenticated: false"

# --- no JSON parser at all: degraded, named, never fatal
nojson="$(make_farm nojson jq python3)"
make_gh "$nojson" 0
rc=0; out="$(run_req "$nojson" 2>&1)" || rc=$?
assert_rc "missing jq+python3 stays exit 0" 0 "$rc"
assert_contains "names the settings-merge capability" ".claude/settings.json" "$out"

# --- git missing: core, fatal
nogit="$(make_farm nogit git)"
rc=0; out="$(cd "$WORK" && env PATH="$nogit" bash "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "missing git exits 1" 1 "$rc"
assert_contains "names the core failure" "git not found" "$out"

# --- outside a git repo: release wiring not assessed, still exit 0
rc=0; out="$(cd "$WORK" && env PATH="$full" bash "$SPARK" doctor --requirements 2>&1)" || rc=$?
assert_rc "outside a repo exits 0" 0 "$rc"
assert_contains "release wiring skipped" "not assessed" "$out"
rc=0; out="$(cd "$WORK" && env PATH="$full" bash "$SPARK" doctor --requirements --json 2>&1)" || rc=$?
[ "$(printf '%s' "$out" | jq -r '.release.assessed')" = "false" ] \
  && ok || bad "--json release.assessed should be false outside a repo"

# --- unknown option is rejected
rc=0; ( cd "$REPO" && bash "$SPARK" doctor --bogus ) >/dev/null 2>&1 || rc=$?
assert_rc "unknown doctor option is rejected" 1 "$rc"

finish
