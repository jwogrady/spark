#!/usr/bin/env bash
# Behavioral suite for the context budgets doctor enforces (#209): a SKILL.md
# within budget passes, one over the line budget or the description budget fails
# with the measured size and the budget named, and a skill directory with no
# SKILL.md is reported. Runs against a throwaway copy of the plugin so the
# checkout is never mutated.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
skills="$WORK/plugin/skills"

assert_absent() { # assert_absent <desc> <needle> <haystack>
  case "$3" in *"$2"*) bad "$1 — output unexpectedly contains '$2'" ;; *) ok ;; esac
}

# --- control: the shipped skills are all within budget, so a clean copy names
# no budget violation. This is the within-budget case.
clean="$( cd "$WORK/plugin" && "$SPARK" doctor 2>&1 )" || true
assert_absent "shipped skills report no line-budget violation" "(budget 100)" "$clean"
assert_absent "shipped skills report no description-budget violation" "(budget 1024)" "$clean"

# --- over the line budget: a 130-line SKILL.md fails, naming size and budget.
mkdir -p "$skills/fixture-over-lines"
{
  echo "---"; echo "name: fixture-over-lines"
  echo "description: A fixture skill. Use when testing the line budget; not for real work."
  echo "---"
  i=0; while [ "$i" -lt 130 ]; do echo "body line $i"; i=$((i + 1)); done
} > "$skills/fixture-over-lines/SKILL.md"

# --- over the description budget: a >1024-char description fails.
mkdir -p "$skills/fixture-over-desc"
longdesc="$(printf 'x%.0s' $(seq 1 1100))"
{
  echo "---"; echo "name: fixture-over-desc"
  echo "description: $longdesc"
  echo "---"; echo "# body"
} > "$skills/fixture-over-desc/SKILL.md"

# --- missing SKILL.md entirely: reported, not silently skipped.
mkdir -p "$skills/fixture-no-file"

out="$( cd "$WORK/plugin" && "$SPARK" doctor 2>&1 )" || true

assert_contains "over-line skill fails with its measured size" \
  "fixture-over-lines: SKILL.md is 134 lines (budget 100)" "$out"
assert_contains "over-description skill fails naming the budget" \
  "fixture-over-desc: description is 1100 chars (budget 1024)" "$out"
assert_contains "a skill dir with no SKILL.md is reported" \
  "fixture-no-file: missing SKILL.md" "$out"

# --- exit code: budget violations fail doctor, not merely warn.
rc=0; ( cd "$WORK/plugin" && "$SPARK" doctor >/dev/null 2>&1 ) || rc=$?
[ "$rc" -ne 0 ] && ok || bad "doctor must exit non-zero on a budget violation (got $rc)"

finish
