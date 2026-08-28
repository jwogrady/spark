#!/usr/bin/env bash
# Behavioral tests for doctor's tier-boundary check.
#
# Spark keeps four tiers: code, shipped documentation, development prose and
# provenance (the repo-root docs/), and project management. The separation was
# structural only — repo-root docs/ sits outside plugins/, so it cannot ship —
# and nothing held the reverse direction: a dated decision record filed under
# plugins/ would ship silently, handing a downstream reader this repo's
# internal history. These cover both findings the check makes, and prove the
# error and warning carry different weight.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# A minimal marketplace fixture: one plugin with a shipped docs tree and a
# skills tree, so --root-style inspection has something real to walk.
mk_marketplace() {
  local root="$1"
  mkdir -p "$root/.claude-plugin" \
           "$root/plugins/demo/.claude-plugin" \
           "$root/plugins/demo/docs/reference" \
           "$root/plugins/demo/skills/x"
  printf '{"name":"m","plugins":["./plugins/demo"]}\n' > "$root/.claude-plugin/marketplace.json"
  printf '{"name":"demo","version":"0.0.1"}\n' > "$root/plugins/demo/.claude-plugin/plugin.json"
  printf -- '---\nname: x\ndescription: A demo skill for fixtures. Use when testing.\n---\n\n# x\n' \
    > "$root/plugins/demo/skills/x/SKILL.md"
  printf '# Ref\n\nProse with no issue citations.\n' > "$root/plugins/demo/docs/reference/thing.md"
}

# Exercise the helper directly against a fixture marketplace, so the fixture
# does not have to satisfy every other doctor gate. Sourcing the CLI would run
# dispatch, so extract just the functions under test and call them.
#
# issue_refs comes along because the tier check reads issue citations through
# it rather than owning a second copy of the `#N` syntax. Extracting only
# check_tier_boundary silently produced "command not found" on every file and
# a clean-looking report — a check that had stopped checking.
run_tier() {
  bash -c '
    set -uo pipefail
    eval "$(awk "/^issue_refs\\(\\) \\{/,/^\\}$/" "$1")"
    eval "$(awk "/^check_tier_boundary\\(\\) \\{/,/^\\}$/" "$1")"
    # A helper that fails to extract is "command not found" -> a count of zero
    # -> a clean report. That is a check which has stopped checking while
    # looking healthy, so make it loud instead.
    for fn in issue_refs check_tier_boundary; do
      command -v "$fn" >/dev/null 2>&1 || {
        echo "EXTRACTION-FAILED: $fn was not extracted" >&2; exit 99; }
    done
    check_tier_boundary "$2"
  ' _ "$SPARK" "$1"
}

# --- a clean marketplace: no findings, exit 0
d="$WORK/clean"; mk_marketplace "$d"
rc=0; out="$(run_tier "$d")" || rc=$?
assert_rc "clean marketplace: no hard finding" 0 "$rc"
case "$out" in
  *ISSUEREFS*) bad "clean fixture reported issue references" ;;
  *) ok ;;
esac

# --- a development-only kind under plugins/ is an ERROR (non-zero)
for kind in adr releases governance research alpha; do
  d="$WORK/dev-$kind"; mk_marketplace "$d"
  mkdir -p "$d/plugins/demo/docs/$kind"
  printf '# rec\n' > "$d/plugins/demo/docs/$kind/0001-x.md"
  rc=0; out="$(run_tier "$d")" || rc=$?
  if [ "$rc" -ne 0 ]; then ok; else bad "a '$kind' tree under plugins/ should be a hard finding"; fi
  assert_contains "names the offending path ($kind)" "$kind" "$out"
done

# --- nesting depth does not hide it
d="$WORK/deep"; mk_marketplace "$d"
mkdir -p "$d/plugins/demo/skills/x/references/adr"
printf '# rec\n' > "$d/plugins/demo/skills/x/references/adr/0002-y.md"
rc=0; out="$(run_tier "$d")" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "a nested adr/ tree should still be found"; fi

# --- an issue reference in a shipped surface is a WARNING, not an error
d="$WORK/refs"; mk_marketplace "$d"
printf '# Ref\n\nSee #402 for the rationale.\n' > "$d/plugins/demo/docs/reference/thing.md"
rc=0; out="$(run_tier "$d")" || rc=$?
assert_rc "an issue reference alone is not a hard finding" 0 "$rc"
assert_contains "reports the issue-reference section" "ISSUEREFS" "$out"
assert_contains "names the citing file" "thing.md" "$out"

# --- it counts, so a reviewer can see scale
printf '# Ref\n\nSee #402, #393 and #372.\n' > "$d/plugins/demo/docs/reference/thing.md"
out="$(run_tier "$d")" || true
assert_contains "reports the count" "(3)" "$out"

# --- skills are shipped surfaces too
d="$WORK/skillref"; mk_marketplace "$d"
printf -- '---\nname: x\ndescription: A demo skill for fixtures. Use when testing.\n---\n\n# x\n\nPer #372.\n' \
  > "$d/plugins/demo/skills/x/SKILL.md"
out="$(run_tier "$d")" || true
assert_contains "a skill citing an issue is reported" "SKILL.md" "$out"

# --- ADR references are deliberately NOT flagged (shared vocabulary; the
# shipped glossary explains where ADRs live)
d="$WORK/adrref"; mk_marketplace "$d"
printf '# Ref\n\nAdoption stays create-only (ADR-0022).\n' > "$d/plugins/demo/docs/reference/thing.md"
rc=0; out="$(run_tier "$d")" || rc=$?
assert_rc "an ADR reference is not a hard finding" 0 "$rc"
case "$out" in
  *ISSUEREFS*) bad "ADR references must not be reported as unresolvable issue refs" ;;
  *) ok ;;
esac

# --- a two-digit "#42" is not an issue citation pattern (avoids false hits on
# prose like "#1 priority"); the check requires three or more digits
d="$WORK/short"; mk_marketplace "$d"
printf '# Ref\n\nThe #1 rule and issue #42.\n' > "$d/plugins/demo/docs/reference/thing.md"
out="$(run_tier "$d")" || true
case "$out" in
  *ISSUEREFS*) bad "short numeric references should not be flagged" ;;
  *) ok ;;
esac

# --- the repo itself: the real check runs and the layout holds
root="$(cd "$(dirname "$0")/.." && pwd)"
rc=0; out="$(run_tier "$root")" || rc=$?
assert_rc "the Spark repo carries no development-only material under plugins/" 0 "$rc"

finish
