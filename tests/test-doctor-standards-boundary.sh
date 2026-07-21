#!/usr/bin/env bash
# Behavioral suite for spark doctor's standards-boundary check (#200): the
# prose standards docs from #182 mark machine-backed facts with a
# `<!-- spark:pref key=value -->` comment. Doctor is the mechanical guardian of
# that seam — a freshly seeded project is green, an edited fact that no longer
# matches the resolved preference is drift, a marker naming a nonexistent key is
# a dangling reference, and a project without the docs is reported (not failed).
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init

conv_tmpl="$repo_root/plugins/spark/preferences/templates/standards/conventions.md"

# --- green: a freshly seeded project passes with matching markers.
repo="$WORK/seeded"; make_repo "$repo"
( cd "$repo" && "$SPARK" setup --yes >/dev/null 2>&1 )
if out="$( cd "$repo" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_contains "seeded project reports CONVENTIONS.md matching" \
  "✓ CONVENTIONS.md — " "$out"
assert_contains "seeded project reports ENGINEERING-STANDARDS.md matching" \
  "✓ ENGINEERING-STANDARDS.md — " "$out"
assert_contains "seeded standards facts resolve and match" \
  "resolve and match .spark/preferences.json" "$out"
assert_rc "doctor is green on a freshly seeded project" 0 "$rc"

# --- drift: edit a machine-backed fact in the prose without changing the
# preference. Doctor names the exact key and the document location, and fails.
repo="$WORK/drift"; make_repo "$repo"
cp "$conv_tmpl" "$repo/CONVENTIONS.md"
# branch.model resolves to github-flow (shipped default); assert a stale value.
sed -i 's/branch.model=github-flow/branch.model=trunk-based/' "$repo/CONVENTIONS.md"
if out="$( cd "$repo" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_contains "drift names the exact key" "'branch.model' drifted" "$out"
assert_contains "drift reports the asserted value" "prose asserts 'trunk-based'" "$out"
assert_contains "drift reports the resolved value" "resolve to 'github-flow'" "$out"
assert_contains "drift names the document location" "CONVENTIONS.md:" "$out"
assert_rc "doctor fails on prose/preference drift" 1 "$rc"

# --- dangling: a marker referencing a key that does not resolve fails with
# actionable output that names the key and the location.
repo="$WORK/dangling"; make_repo "$repo"
cp "$conv_tmpl" "$repo/CONVENTIONS.md"
printf '\n- bogus fact. <!-- spark:pref nonexistent.key=whatever -->\n' \
  >> "$repo/CONVENTIONS.md"
if out="$( cd "$repo" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_contains "dangling names the unknown key" \
  "unknown preference key 'nonexistent.key'" "$out"
assert_contains "dangling is actionable" "dangling reference" "$out"
assert_contains "dangling names the document location" "CONVENTIONS.md:" "$out"
assert_rc "doctor fails on a dangling reference" 1 "$rc"

# --- absent: a repo with no standards docs is reported as such, not failed.
repo="$WORK/absent"; make_repo "$repo"
if out="$( cd "$repo" && "$SPARK" doctor 2>&1 )"; then rc=0; else rc=$?; fi
assert_contains "absent docs are reported as nothing to verify" \
  "no standards documents present" "$out"
case "$out" in
  *"drifted"*|*"dangling reference"*) bad "absent repo must not report a boundary error" ;;
  *) ok ;;
esac

finish
