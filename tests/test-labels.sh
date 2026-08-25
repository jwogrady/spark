#!/usr/bin/env bash
# Behavioral tests for spark labels (issue #396): Spark declared a seven-category
# issue taxonomy, wrote it into every onboarded repo, and built governance
# doctrine on it — but nothing ever created a label, so a fresh repo declared a
# taxonomy that did not exist. These cover the parts that are testable without a
# GitHub remote: taxonomy resolution through the tiers and through the
# CONVENTIONS.md marker, the report-by-default contract, the truthful
# not-assessed state when gh is unavailable, and the downstream doctor check
# that used to read its own silence as health.

set -euo pipefail
. "$(dirname "$0")/lib.sh"
sandbox_init

# --- outside a git repo there is nothing to reconcile, and it says so
d="$WORK/nogit"; mkdir -p "$d"
rc=0; out="$(cd "$d" && "$SPARK" labels 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "labels outside a git repo should fail"; fi
assert_contains "names the reason" "not inside a git repo" "$out"

# --- the verb is registered and self-documenting
out="$("$SPARK" help 2>&1)"
assert_contains "labels appears in the verb table" "spark labels" "$out"
out="$("$SPARK" labels --help 2>&1)"
assert_contains "labels documents its own usage" "usage: spark labels" "$out"
rc=0; out="$(cd "$WORK" && "$SPARK" labels --nonsense 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then ok; else bad "an unknown option should fail"; fi

# --- without gh the answer is "not assessed", never "healthy", and exit 0.
# A PATH holding no gh is the honest simulation of an unauthenticated operator.
shim="$WORK/lshim"; mkdir -p "$shim"
for tool in bash sh git grep sed cat cp mv rm mkdir mktemp basename dirname tr find sort head tail date env uname readlink awk cut wc ls chmod touch printf; do
  src="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$shim/$tool"
done
d="$WORK/nogh"; make_repo "$d"
rc=0; out="$(cd "$d" && env PATH="$shim" "$SPARK" labels 2>&1)" || rc=$?
assert_rc "labels without gh exits 0 (degrades, never fails)" 0 "$rc"
assert_contains "labels without gh is not assessed" "not assessed" "$out"
assert_contains "labels without gh names the taxonomy" "Declared taxonomy" "$out"
case "$out" in
  *"exists — kept"*) bad "#396: labels claimed a category exists without reaching GitHub" ;;
  *) ok ;;
esac
# Reporting is inspect-only: nothing is written, with or without gh.
[ ! -e "$d/.spark" ] && ok || bad "#396: labels wrote project state"

# --- the taxonomy resolves from a committed project fact (the tiers work)
d="$WORK/projtaxo"; make_repo "$d"
mkdir -p "$d/.spark"
printf '{"issue.taxonomy":"alpha beta"}\n' > "$d/.spark/preferences.json"
out="$(cd "$d" && env PATH="$shim" "$SPARK" labels 2>&1)" || true
assert_contains "a project fact overrides the shipped taxonomy" "alpha beta" "$out"

# --- and falls back to the CONVENTIONS.md marker, so a collaborator without
# Spark's preference store still reads the categories the project declares
d="$WORK/marker"; make_repo "$d"
mkdir -p "$d/.spark"
printf '{"issue.taxonomy":""}\n' > "$d/.spark/preferences.json"
cat > "$d/CONVENTIONS.md" <<'MD'
# Conventions

- Track work across these categories: `gamma delta`. <!-- spark:pref issue.taxonomy=gamma delta -->
MD
out="$(cd "$d" && env PATH="$shim" "$SPARK" labels 2>&1)" || true
assert_contains "the CONVENTIONS.md marker is the fallback" "gamma delta" "$out"

# --- #396 downstream: doctor's taxonomy check was gated on a directory setup
# never creates, and scoped to the marketplace root, so it silently no-opped in
# exactly the repos it was written for. Its silence read as a clean pass.
d="$WORK/armed"; make_repo "$d"
( cd "$d" && "$SPARK" setup ) >/dev/null 2>&1
out="$(cd "$d" && "$SPARK" doctor 2>&1)" || true
assert_contains "doctor reports issue metadata governance in a user repo" \
  "Issue metadata governance" "$out"
assert_contains "doctor names the missing issue forms rather than skipping" \
  "no .github/ISSUE_TEMPLATE/" "$out"
assert_contains "doctor points at the verb that provisions labels" "spark labels" "$out"

# --- setup names the GitHub-side half of the standard instead of declaring a
# taxonomy it never provisions and never mentions
d="$WORK/setupmsg"; make_repo "$d"
out="$(cd "$d" && "$SPARK" setup 2>&1)" || true
assert_contains "setup names the label gap" "issue labels" "$out"
assert_contains "setup names the verb that closes it" "spark labels --apply" "$out"

finish
