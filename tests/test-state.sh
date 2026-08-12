#!/usr/bin/env bash
# Behavioral suite for `spark state` (#210, schema shrunk by #347): the
# mechanical writer for the two judgment values no repo can answer —
# next_action and blockers. It must produce schema-valid one-level JSON, merge
# into existing state, stamp `updated`, keep the key set stable, reject
# derivable (legacy) keys with a teaching message, and be readable by the same
# reader `brief`/`resume` use. Runs in throwaway git repos.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
repo="$WORK/proj"; make_repo "$repo"
state="$repo/.spark/state.json"
val() { # val <key> — read one key back through the shipped reader path
  ( cd "$repo" && "$SPARK" state ) | awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,"");print}'
}

# --- write: a close-out produces schema-valid JSON with every key present.
( cd "$repo" && "$SPARK" state --set next_action="Run /spark:validate on feat/x" >/dev/null )
if command -v jq >/dev/null 2>&1; then
  ( cd "$repo" && jq empty "$state" ) && ok || bad "written state is valid JSON"
fi
assert_contains "next_action is written" '"next_action"' "$(cat "$state")"
assert_contains "blockers key is present even when unset" '"blockers"' "$(cat "$state")"
[ "$(val next_action)" = "Run /spark:validate on feat/x" ] && ok || bad "next_action recorded"
[ -n "$(val updated)" ] && ok || bad "updated is stamped, not empty"

# --- merge: a later write keeps prior keys it did not set.
( cd "$repo" && "$SPARK" state --set blockers="waiting on review" >/dev/null )
[ "$(val blockers)" = "waiting on review" ] && ok || bad "blockers recorded on merge"
[ "$(val next_action)" = "Run /spark:validate on feat/x" ] && ok \
  || bad "prior next_action survives a merge (got '$(val next_action)')"

# --- values with JSON metacharacters survive round-trip.
( cd "$repo" && "$SPARK" state --set next_action='Merge the "release" PR' >/dev/null )
if command -v jq >/dev/null 2>&1; then
  ( cd "$repo" && jq empty "$state" ) && ok || bad "quotes in a value keep the JSON valid"
  [ "$( cd "$repo" && jq -r '.next_action' "$state" )" = 'Merge the "release" PR' ] \
    && ok || bad "quoted value round-trips through jq"
fi

# --- validation: unknown keys are rejected non-zero, no write.
rc=0; ( cd "$repo" && "$SPARK" state --set bogus=1 >/dev/null 2>&1 ) || rc=$?
[ "$rc" -ne 0 ] && ok || bad "unknown key rejected"

# --- legacy (pre-v0.16) keys are rejected with a teaching message: those
# facts are derived from git/GitHub now, never stored.
rc=0; out="$( cd "$repo" && "$SPARK" state --set stage=codify 2>&1 )" || rc=$?
[ "$rc" -ne 0 ] && ok || bad "legacy key 'stage' rejected"
assert_contains "the rejection teaches derivation" "derived" "$out"
rc=0; ( cd "$repo" && "$SPARK" state --set branch=feat/x >/dev/null 2>&1 ) || rc=$?
[ "$rc" -ne 0 ] && ok || bad "legacy key 'branch' rejected"
[ "$(val next_action)" = 'Merge the "release" PR' ] \
  && ok || bad "a rejected write leaves state unchanged"

# --- reading an old-schema file: legacy keys are ignored, judgment keys read;
# the next write migrates the file to the three-key schema.
old="$WORK/oldschema"; make_repo "$old"
mkdir -p "$old/.spark"
cat > "$old/.spark/state.json" <<'EOF'
{
  "stage": "codify",
  "issue": "32",
  "branch": "feat/old",
  "pr": "",
  "blockers": "",
  "next_action": "carried forward",
  "updated": "2026-01-01"
}
EOF
got="$( cd "$old" && "$SPARK" state | awk -F= '$1=="next_action"{sub(/^[^=]*=/,"");print}' )"
[ "$got" = "carried forward" ] && ok || bad "old-schema next_action still readable (got '$got')"
( cd "$old" && "$SPARK" state --set blockers="none" >/dev/null )
case "$(cat "$old/.spark/state.json")" in
  *'"stage"'*) bad "a write should migrate the file off the legacy schema" ;;
  *) ok ;;
esac

# --- brief shows the recorded intent with its date, never a recorded stage.
out="$( cd "$old" && "$SPARK" brief 2>&1 )"
assert_contains "brief shows the recorded next action" "carried forward" "$out"
case "$out" in
  *"Codify — working branch"*|*"Ideate"*|*"Plan"*) ok ;;
  *) bad "brief's locate line should be derived from the repo" ;;
esac

# --- outside a git repo: refuse, non-zero.
rc=0; ( cd "$WORK" && "$SPARK" state --set next_action=x >/dev/null 2>&1 ) || rc=$?
[ "$rc" -ne 0 ] && ok || bad "state outside a git repo refuses"

# --- #264: a quoted value round-trips even with neither jq nor python3 on PATH
# (the awk fallback must not truncate at the first embedded quote).
bare="$WORK/barebin"; mkdir -p "$bare"
for t in bash sh dirname basename cat cp mkdir grep sed awk sort tr head wc find env git date; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] && ln -s "$real" "$bare/$t"
done
nojq="$WORK/nojq"; make_repo "$nojq"
( cd "$nojq" && env PATH="$bare" "$SPARK" state --set \
    next_action='Merge the "big" PR' blockers='path a\b' >/dev/null 2>&1 )
got="$( cd "$nojq" && env PATH="$bare" "$SPARK" state | awk -F= '$1=="next_action"{sub(/^[^=]*=/,"");print}' )"
[ "$got" = 'Merge the "big" PR' ] && ok || bad "no-jq: quoted next_action round-trips (got '$got')"
gotb="$( cd "$nojq" && env PATH="$bare" "$SPARK" state | awk -F= '$1=="blockers"{sub(/^[^=]*=/,"");print}' )"
[ "$gotb" = 'path a\b' ] && ok || bad "no-jq: backslash in blockers round-trips (got '$gotb')"

finish
