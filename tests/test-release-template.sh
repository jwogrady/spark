#!/usr/bin/env bash
# Deterministic coverage for the seeded Release Please policy (#357): a fresh
# project armed with Spark's templates must not be able to (a) default its
# first release to 1.0.0 — release-please's initialReleaseVersion() is
# hardcoded to 1.0.0 when no release exists and no initial-version is set — or
# (b) let an ordinary feat: commit silently consume a milestone version, which
# is what default bump semantics do on a 0.x line. The template is the
# contract; this suite pins it.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
tpl="$WORK/plugin/preferences/templates/release-please-config.json"
man="$WORK/plugin/preferences/templates/release-please-manifest.json"

[ -f "$tpl" ] && ok || bad "seeded release-please config template exists"
[ -f "$man" ] && ok || bad "seeded release-please manifest template exists"

if command -v jq >/dev/null 2>&1; then
  jq empty "$tpl" && ok || bad "config template is valid JSON"
  jq empty "$man" && ok || bad "manifest template is valid JSON"

  # (a) the first-release guard: without initial-version, a repo with no
  # release resolves to 1.0.0.
  iv="$(jq -r '."initial-version" // empty' "$tpl")"
  [ -n "$iv" ] && ok || bad "config template carries initial-version (else first release defaults to 1.0.0)"
  case "$iv" in
    0.*) ok ;;
    *) bad "initial-version must start pre-1.0 (got '$iv')" ;;
  esac

  # (b) milestone version authority: day-to-day merges bump only the patch
  # line; milestone boundaries are minted with Release-As, never computed.
  vs="$(jq -r '.versioning // empty' "$tpl")"
  [ "$vs" = "always-bump-patch" ] && ok \
    || bad "config template must set versioning=always-bump-patch (got '$vs')"

  # (c) the manifest baseline claims nothing was released — a manifest that
  # names a version with no matching tag is a fabricated baseline.
  base="$(jq -r '."."' "$man")"
  [ "$base" = "0.0.0" ] && ok || bad "manifest baseline must be 0.0.0 (got '$base')"
else
  echo "  (jq absent — template value checks skipped)"
fi

finish
