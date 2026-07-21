#!/usr/bin/env bash
# Behavioral suite for spark doctor's changelog-mode check (#186): where
# Release Please owns the changelog, a hand-curated [Unreleased] section is a
# policy violation; without Release Please the check stays silent.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init

# Scenario A — Release Please-managed, no hand-curated [Unreleased]: passes.
make_repo "$WORK/rp-clean"
: > "$WORK/rp-clean/release-please-config.json"
printf '# Changelog\n\nRelease Please maintains the released sections.\n' \
  > "$WORK/rp-clean/CHANGELOG.md"
if out="$( cd "$WORK/rp-clean" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_contains "RP repo without [Unreleased] reports the clean state" \
  "changelog mode matches Release Please" "$out"

# Scenario B — Release Please-managed WITH a stray [Unreleased]: errors, exit 1.
make_repo "$WORK/rp-stray"
: > "$WORK/rp-stray/release-please-config.json"
printf '# Changelog\n\n## [Unreleased]\n\n- hand entry\n' \
  > "$WORK/rp-stray/CHANGELOG.md"
if out="$( cd "$WORK/rp-stray" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_contains "RP repo with [Unreleased] is flagged" \
  "hand-curated [Unreleased]" "$out"
assert_rc "doctor fails when an RP changelog has [Unreleased]" 1 "$rc"

# Scenario C — no Release Please config: the check does not run at all.
make_repo "$WORK/manual"
printf '# Changelog\n\n## [Unreleased]\n\n- hand entry\n' \
  > "$WORK/manual/CHANGELOG.md"
if out="$( cd "$WORK/manual" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
case "$out" in
  *"changelog mode"*) bad "manual repo must not run the changelog-mode check" ;;
  *) ok ;;
esac

finish
