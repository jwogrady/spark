#!/usr/bin/env bash
# Behavioral tests for spark hub (issue #375): the four truthful resolution
# states (configured / explicit none / not configured / malformed), locator
# validation, create-only recording that never disturbs other committed facts,
# tier provenance (operator vs project), the inspect-only guarantee for the
# bare report, and the graceful skip when no JSON parser is available.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# --- not configured: truthful standalone report, exit 0, nothing written
d="$WORK/uncfg"; make_repo "$d"
rc=0; out="$(cd "$d" && "$SPARK" hub 2>&1)" || rc=$?
assert_rc "unconfigured report exits 0" 0 "$rc"
assert_contains "unconfigured is named truthfully" "not configured" "$out"
[ ! -e "$d/.spark" ] && ok || bad "bare hub report created .spark (must stay read-only)"

# --- --set records the fact, report resolves it and names the source tier
d="$WORK/setrec"; make_repo "$d"
rc=0; ( cd "$d" && "$SPARK" hub --set jwogrady/cosmos ) >/dev/null 2>&1 || rc=$?
assert_rc "hub --set exits 0" 0 "$rc"
[ -f "$d/.spark/preferences.json" ] && ok || bad "--set did not create preferences.json"
jq empty "$d/.spark/preferences.json" 2>/dev/null && ok || bad "recorded preferences.json is not valid JSON"
rc=0; out="$(cd "$d" && "$SPARK" hub 2>&1)" || rc=$?
assert_rc "configured report exits 0" 0 "$rc"
assert_contains "report names the hub" "jwogrady/cosmos" "$out"
assert_contains "report names the source tier" "project" "$out"

# --- URL and scp-style locators are valid (provider-neutral, not GitHub-shaped)
for loc in "https://example.org/team/memory" "git@forge.internal:team/memory.git" "https://example.org:8443/team/memory" "ssh://git@example.org/team/memory.git" "https://example.org/team/memory?ref=main" "https://example.org/team/memory#readme" "https://user@example.org/team/memory" "https://user@example.org:8443/team/memory" "https://[::1]:8443/team/memory" "https://[2001:db8::1]/team/memory" "https://user@[::1]:8443/team/memory" "git@[::1]:team/memory.git"; do
  rc=0; ( cd "$d" && "$SPARK" hub --set "$loc" ) >/dev/null 2>&1 || rc=$?
  assert_rc "locator accepted: $loc" 0 "$rc"
done

# --- #385: a URL/scp-style value with an empty scheme, host, user, or
# repository path names no repository and must be rejected, not accepted as
# "healthy". This list is the accumulated evidence from seven review rounds:
# slash-counting can't tell an empty host from a real one ('?'/'*' match '/'
# too); an all-slash remainder is a real string but names nothing; gating
# extraction with a separate existence check let a repeated delimiter smuggle
# an empty leading segment through (://a://b, @a@host:path) because the gate
# and the extraction anchored to different occurrences of it; a hybrid string
# can straddle two locator forms (owner/repo@host:path); userinfo/port
# punctuation alone (://:8080/repo, ://@/repo) is not a real hostname; a
# SECOND embedded "@" (://a@b@/repo) defeated a first-"@" split the same way
# a repeated "://" defeated a first-occurrence split in round 3; and empty
# IPv6 brackets (://[]:8080/repo) survived naive colon-based port stripping
# by accident (the truncated leftover stayed non-empty). Defined once
# (BAD_HUB_LOCATORS) and reused below so the two loops can't drift apart.
BAD_HUB_LOCATORS=(
  "https:///repo" "https://github.com" "x://y" "https:////repo" "https://///repo"
  "file:///repo" "file:///home/user/repo" "https://host//" "https://host/"
  "git@host:/" "git@host:" "git@host:///" "git@ho/st:path"
  "https://a@b@/repo" "https://user@pass@/repo" "https://@@/repo" "https://a:b@c:d@/repo"
  "https://[]:8080/repo" "https://[]/repo" "https://user@[]:8080/repo"
  "user@[]:path" "user@[::1]:"
  "https://[192.168.1.1/repo" "https://[::1/path" "https://[/repo" "https://[::/repo" "https://[:8080/repo"
  "://a://b" "@a@host:path" "user@@:path"
  "https://github.com?a=1/2" "https://host/?x=y"
  "owner/repo@host:path" "not/a/scheme://host/path" "user@ho#st:path"
  "https://:8080/repo" "https://:/repo" "https://@:8080/repo" "scheme://@/repo" "https://user@/path"
)
for loc in "${BAD_HUB_LOCATORS[@]}"; do
  rc=0; ( cd "$d" && "$SPARK" hub --set "$loc" ) >/dev/null 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then ok; else bad "#385: '$loc' names no repository and should be rejected"; fi
done

# --- explicit none: a declared standalone state, distinct from unconfigured
rc=0; ( cd "$d" && "$SPARK" hub --set none ) >/dev/null 2>&1 || rc=$?
assert_rc "hub --set none exits 0" 0 "$rc"
rc=0; out="$(cd "$d" && "$SPARK" hub 2>&1)" || rc=$?
assert_rc "explicit-none report exits 0" 0 "$rc"
assert_contains "explicit none is a declaration" "declared standalone" "$out"

# --- re-set behaves sanely: same value is a no-op, a different value is named
rc=0; out="$(cd "$d" && "$SPARK" hub --set none 2>&1)" || rc=$?
assert_rc "same-value re-set exits 0" 0 "$rc"
assert_contains "same-value re-set is a no-op" "already recorded" "$out"
rc=0; out="$(cd "$d" && "$SPARK" hub --set jwogrady/cosmos 2>&1)" || rc=$?
assert_rc "changed re-set exits 0" 0 "$rc"
assert_contains "changed re-set is called explicit" "re-set" "$out"

# --- --set merges without clobbering an existing committed fact
d="$WORK/setmerge"; make_repo "$d"
mkdir -p "$d/.spark"
printf '{"permissions.preset":"conservative"}\n' > "$d/.spark/preferences.json"
( cd "$d" && "$SPARK" hub --set team/memory ) >/dev/null 2>&1
merged="$(cat "$d/.spark/preferences.json")"
assert_contains "existing project fact survives" "conservative" "$merged"
assert_contains "hub key is added" "project.memory-hub" "$merged"

# --- malformed locators are rejected, nothing written
d="$WORK/setbad"; make_repo "$d"
for badloc in "" "not a repo" "norepo" "/leading" "trailing/" "a/b/c" 'quo"te/repo' 'back\slash/repo' '://no-scheme' "${BAD_HUB_LOCATORS[@]}"; do
  rc=0; out="$(cd "$d" && "$SPARK" hub --set "$badloc" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ]; then ok; else bad "locator '$badloc' should be rejected"; fi
done
assert_contains "rejection names the bad value" "invalid locator" "$out"
[ ! -e "$d/.spark" ] && ok || bad "rejected --set still wrote state"

# --- a trailing --set with no value is a usage error, not a silent death
rc=0; out="$(cd "$d" && "$SPARK" hub --set 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "bare --set should fail"; fi
assert_contains "bare --set explains itself" "invalid locator" "$out"

# --- an empty configured value is malformed, and the tier is not mistaken for it
d="$WORK/emptyval"; make_repo "$d"
mkdir -p "$d/.spark"
printf '{"project.memory-hub":""}\n' > "$d/.spark/preferences.json"
rc=0; out="$(cd "$d" && "$SPARK" hub 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "empty configured value should exit non-zero"; fi
assert_contains "empty value is malformed, not the tier name" "value '' is malformed" "$out"

# --- a malformed value already on disk fails truthfully, never guessed around
d="$WORK/badrec"; make_repo "$d"
mkdir -p "$d/.spark"
printf '{"project.memory-hub":"bogus"}\n' > "$d/.spark/preferences.json"
rc=0; out="$(cd "$d" && "$SPARK" hub 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "malformed configured value should exit non-zero"; fi
assert_contains "malformed value is named" "malformed" "$out"

# --- #385 reproduction: a host-only URL committed on disk (no repository
# path) must never be reported healthy by hub, brief, or doctor.
d="$WORK/badurl"; make_repo "$d"
mkdir -p "$d/.spark"
printf '{"project.memory-hub":"https://github.com"}\n' > "$d/.spark/preferences.json"
rc=0; out="$(cd "$d" && "$SPARK" hub 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "#385: host-only URL should exit non-zero, not report healthy"; fi
assert_contains "#385: hub names it malformed" "malformed" "$out"
rc=0; out="$(cd "$d" && "$SPARK" doctor 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "#385: doctor should fail on a host-only URL"; fi
assert_contains "#385: doctor flags it, not healthy" "✗ memory hub" "$out"
out="$(cd "$d" && "$SPARK" brief 2>&1)" || true
assert_contains "#385: brief marks it malformed, not healthy" "malformed" "$out"

# --- tier provenance: an operator declaration resolves, and project wins
d="$WORK/tiers"; make_repo "$d"
mkdir -p "$XDG_CONFIG_HOME/spark"
printf '{"project.memory-hub":"acme/hub"}\n' > "$XDG_CONFIG_HOME/spark/preferences.json"
out="$(cd "$d" && "$SPARK" hub 2>&1)"
assert_contains "operator declaration resolves" "acme/hub" "$out"
assert_contains "source is the operator tier" "source  operator" "$out"
( cd "$d" && "$SPARK" hub --set project/hub ) >/dev/null 2>&1
out="$(cd "$d" && "$SPARK" hub 2>&1)"
assert_contains "project tier overrides operator" "project/hub" "$out"
rm -f "$XDG_CONFIG_HOME/spark/preferences.json"

# --- doctor: valid and explicit-none pointers are healthy, malformed is an error
d="$WORK/badrec"  # still carries the malformed value
rc=0; out="$(cd "$d" && "$SPARK" doctor 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "doctor should fail on a malformed hub pointer"; fi
assert_contains "doctor flags the malformed pointer" "✗ memory hub" "$out"
out="$(cd "$d" && "$SPARK" brief 2>&1)" || true
assert_contains "brief marks the malformed value, not healthy" "malformed" "$out"
( cd "$d" && "$SPARK" hub --set jwogrady/cosmos ) >/dev/null 2>&1
out="$(cd "$d" && "$SPARK" doctor 2>&1)" || true
assert_contains "doctor reports a valid pointer healthy" "✓ memory hub: jwogrady/cosmos" "$out"

# --- brief surfaces a recorded declaration in Load
out="$(cd "$d" && "$SPARK" brief 2>&1)" || true
assert_contains "brief names the declared hub" "project.memory-hub jwogrady/cosmos" "$out"

# --- no jq and no python3: --set into an existing file degrades gracefully
shim="$WORK/hshim"; mkdir -p "$shim"
for tool in bash sh git grep sed cat cp mv rm mkdir mktemp basename dirname tr find sort head tail date env uname readlink awk cut wc ls chmod touch; do
  src="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$src" ] && ln -s "$src" "$shim/$tool"
done
d="$WORK/noparser"; make_repo "$d"
mkdir -p "$d/.spark"
printf '{"permissions.preset":"delivery"}\n' > "$d/.spark/preferences.json"
before="$(cat "$d/.spark/preferences.json")"
rc=0; out="$(cd "$d" && env PATH="$shim" "$SPARK" hub --set team/memory 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "no-parser --set should return non-zero"; fi
assert_contains "points at a manual edit" "by hand" "$out"
[ "$before" = "$(cat "$d/.spark/preferences.json")" ] && ok || bad "no-parser --set modified the file"

finish
