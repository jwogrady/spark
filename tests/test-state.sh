#!/usr/bin/env bash
# Behavioral suite for `spark state` (#210): the mechanical work-state writer.
# It must produce schema-valid one-level JSON, merge into existing state, stamp
# `updated`, keep the key set stable, validate keys and the stage enum, and be
# readable by the same reader `brief`/`resume` use. Runs in throwaway git repos.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
repo="$WORK/proj"; make_repo "$repo"
state="$repo/.spark/state.json"
val() { # val <key> — read one key back through the shipped reader path
  ( cd "$repo" && "$SPARK" state ) | awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,"");print}'
}

# --- write: a close-out produces schema-valid JSON with every key present.
( cd "$repo" && "$SPARK" state --set stage=codify issue=66 branch=feat/x \
    next_action="Run /spark:validate on feat/x" >/dev/null )
if command -v jq >/dev/null 2>&1; then
  ( cd "$repo" && jq empty "$state" ) && ok || bad "written state is valid JSON"
fi
assert_contains "all eight schema keys are written" \
  '"next_action"' "$(cat "$state")"
[ "$(val stage)" = "codify" ] && ok || bad "stage recorded (got '$(val stage)')"
[ "$(val issue)" = "66" ] && ok || bad "issue recorded (got '$(val issue)')"
[ -n "$(val updated)" ] && ok || bad "updated is stamped, not empty"

# --- merge: a later stage keeps prior keys it did not set.
( cd "$repo" && "$SPARK" state --set stage=ship pr=185 blockers="" >/dev/null )
[ "$(val stage)" = "ship" ] && ok || bad "stage updated on merge"
[ "$(val pr)" = "185" ] && ok || bad "pr recorded on merge"
[ "$(val issue)" = "66" ] && ok || bad "prior issue survives a merge (got '$(val issue)')"
[ "$(val branch)" = "feat/x" ] && ok || bad "prior branch survives a merge"

# --- values with JSON metacharacters survive round-trip.
( cd "$repo" && "$SPARK" state --set next_action='Merge the "release" PR' >/dev/null )
if command -v jq >/dev/null 2>&1; then
  ( cd "$repo" && jq empty "$state" ) && ok || bad "quotes in a value keep the JSON valid"
  [ "$( cd "$repo" && jq -r '.next_action' "$state" )" = 'Merge the "release" PR' ] \
    && ok || bad "quoted value round-trips through jq"
fi

# --- validation: unknown key and bad stage are rejected non-zero, no write.
rc=0; ( cd "$repo" && "$SPARK" state --set bogus=1 >/dev/null 2>&1 ) || rc=$?
[ "$rc" -ne 0 ] && ok || bad "unknown key rejected"
rc=0; ( cd "$repo" && "$SPARK" state --set stage=nope >/dev/null 2>&1 ) || rc=$?
[ "$rc" -ne 0 ] && ok || bad "invalid stage rejected"
[ "$(val stage)" = "ship" ] && ok || bad "a rejected write leaves state unchanged"

# --- brief reads what state wrote (the writer and reader agree).
assert_contains "brief's locate line reflects the written stage" \
  "Ship" "$( cd "$repo" && "$SPARK" brief 2>&1 )"

# --- outside a git repo: refuse, non-zero.
rc=0; ( cd "$WORK" && "$SPARK" state --set stage=idle >/dev/null 2>&1 ) || rc=$?
[ "$rc" -ne 0 ] && ok || bad "state outside a git repo refuses"

# --- #264: a quoted value round-trips even with neither jq nor python3 on PATH
# (the awk fallback must not truncate at the first embedded quote).
bare="$WORK/barebin"; mkdir -p "$bare"
for t in bash sh dirname basename cat cp mkdir grep sed awk sort tr head wc find env git date; do
  real="$(command -v "$t" 2>/dev/null || true)"; [ -n "$real" ] && ln -s "$real" "$bare/$t"
done
nojq="$WORK/nojq"; make_repo "$nojq"
( cd "$nojq" && env PATH="$bare" "$SPARK" state --set stage=ship \
    next_action='Merge the "big" PR' blockers='path a\b' >/dev/null 2>&1 )
got="$( cd "$nojq" && env PATH="$bare" "$SPARK" state | awk -F= '$1=="next_action"{sub(/^[^=]*=/,"");print}' )"
[ "$got" = 'Merge the "big" PR' ] && ok || bad "no-jq: quoted next_action round-trips (got '$got')"
gotb="$( cd "$nojq" && env PATH="$bare" "$SPARK" state | awk -F= '$1=="blockers"{sub(/^[^=]*=/,"");print}' )"
[ "$gotb" = 'path a\b' ] && ok || bad "no-jq: backslash in blockers round-trips (got '$gotb')"

finish
