#!/usr/bin/env bash
# Behavioral tests for the project-local prose standards (issue #182): setup
# seeds CONVENTIONS.md and ENGINEERING-STANDARDS.md at the repo root,
# create-only; a pre-existing doc is kept byte-for-byte; and a rerun is
# idempotent (nothing recreated).

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# --- fresh repo: both docs are created at the root and carry spark:pref markers
repo="$WORK/fresh"; make_repo "$repo"
rc=0; out="$(cd "$repo" && "$SPARK" setup --yes 2>&1)" || rc=$?
assert_rc "fresh setup exits 0" 0 "$rc"
[ -f "$repo/CONVENTIONS.md" ] && ok || bad "CONVENTIONS.md not created"
[ -f "$repo/ENGINEERING-STANDARDS.md" ] && ok || bad "ENGINEERING-STANDARDS.md not created"
assert_contains "reports CONVENTIONS.md created" "+ CONVENTIONS.md" "$out"
assert_contains "reports ENGINEERING-STANDARDS.md created" "+ ENGINEERING-STANDARDS.md" "$out"

# The marker is the seam a drift check parses; assert its exact shape lands.
assert_contains "conventions marks branch.model" \
  "<!-- spark:pref branch.model=github-flow -->" "$(cat "$repo/CONVENTIONS.md")"
assert_contains "standards marks release.mechanism" \
  "<!-- spark:pref release.mechanism=release-please -->" "$(cat "$repo/ENGINEERING-STANDARDS.md")"

# --- pre-existing doc: kept and byte-for-byte unchanged, never overwritten
repo2="$WORK/existing"; make_repo "$repo2"
printf 'my own conventions\n' > "$repo2/CONVENTIONS.md"
before="$(cat "$repo2/CONVENTIONS.md")"
rc=0; out="$(cd "$repo2" && "$SPARK" setup --yes 2>&1)" || rc=$?
assert_rc "setup over an existing doc exits 0" 0 "$rc"
assert_contains "existing doc reported kept" "= CONVENTIONS.md (exists — kept)" "$out"
[ "$before" = "$(cat "$repo2/CONVENTIONS.md")" ] && ok || bad "existing CONVENTIONS.md was overwritten"
# The other doc did not exist, so it is still seeded.
[ -f "$repo2/ENGINEERING-STANDARDS.md" ] && ok || bad "ENGINEERING-STANDARDS.md not seeded alongside a kept doc"

# --- idempotent rerun: nothing recreated, both docs reported kept
conv_before="$(cat "$repo/CONVENTIONS.md")"
eng_before="$(cat "$repo/ENGINEERING-STANDARDS.md")"
rc=0; out="$(cd "$repo" && "$SPARK" setup --yes 2>&1)" || rc=$?
assert_rc "rerun exits 0" 0 "$rc"
assert_contains "rerun reports zero created" "Standard: 0 created" "$out"
assert_contains "rerun keeps CONVENTIONS.md" "= CONVENTIONS.md (exists — kept)" "$out"
assert_contains "rerun keeps ENGINEERING-STANDARDS.md" \
  "= ENGINEERING-STANDARDS.md (exists — kept)" "$out"
[ "$conv_before" = "$(cat "$repo/CONVENTIONS.md")" ] && ok || bad "rerun changed CONVENTIONS.md"
[ "$eng_before" = "$(cat "$repo/ENGINEERING-STANDARDS.md")" ] && ok || bad "rerun changed ENGINEERING-STANDARDS.md"

# --- #241 regression: EVERY shipped profile must seed standards whose prose and
# spark:pref markers reflect the *resolved* preferences, so a freshly onboarded
# repo passes doctor's boundary check — not just the default python-uv profile,
# whose value happened to match the old static template.
for prof in "$WORK"/plugin/preferences/profiles/*.json; do
  [ -e "$prof" ] || continue
  name="$(basename "$prof" .json)"
  pr="$WORK/profile-$name"; make_repo "$pr"
  rc=0; (cd "$pr" && "$SPARK" setup --profile "$name" --yes) >/dev/null 2>&1 || rc=$?
  assert_rc "setup --profile $name exits 0" 0 "$rc"
  # No unrendered placeholder may survive in either seeded doc.
  case "$(cat "$pr/CONVENTIONS.md" "$pr/ENGINEERING-STANDARDS.md" 2>/dev/null)" in
    *'{{'*) bad "profile $name left an unrendered {{placeholder}}" ;;
    *) ok ;;
  esac
  # doctor's standards-boundary check green == every marker matches the resolved
  # preference (the #241 failure was doctor going red here for typescript-bun).
  rc=0; (cd "$pr" && "$SPARK" doctor) >/dev/null 2>&1 || rc=$?
  assert_rc "doctor green after --profile $name (no prose/marker drift)" 0 "$rc"
done

# The typescript-bun profile is the exact #241 case: prose AND marker both
# render the resolved stack, not the hard-coded python-uv default.
tsb="$WORK/profile-typescript-bun/ENGINEERING-STANDARDS.md"
if [ -f "$tsb" ]; then
  body="$(cat "$tsb")"
  assert_contains "#241 prose renders the resolved stack" "Default stack: \`typescript-bun\`" "$body"
  assert_contains "#241 marker renders the resolved stack" "spark:pref stack.default=typescript-bun" "$body"
  case "$body" in *"python-uv"*) bad "#241 typescript-bun doc still contains the python-uv default" ;; *) ok ;; esac
fi

finish
