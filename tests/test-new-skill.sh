#!/usr/bin/env bash
# Regression tests for spark new-skill name validation: traversal and
# separator inputs must not escape skills/, and rejections must leave the
# filesystem untouched. Runs against a temporary copy of the plugin so the
# checkout is never mutated.

set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cp -r "$repo/plugins/spark" "$work/spark"
spark="$work/spark/bin/spark"
skills="$work/spark/skills"

pass=0 fail=0

snapshot() { find "$work" | sort; }

reject() {
  local desc="$1" name="$2" before after rc=0
  before="$(snapshot)"
  "$spark" new-skill "$name" >/dev/null 2>&1 || rc=$?
  after="$(snapshot)"
  if [ "$rc" -ne 0 ] && [ "$before" = "$after" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "  ✖ $desc — rc=$rc, fs-changed=$([ "$before" != "$after" ] && echo yes || echo no): '$name'"
  fi
}

# --- rejected: traversal, separators, and malformed slugs
reject "parent traversal"        "../escape"
reject "deep traversal"          "../../outside"
reject "slash separator"         "a/b"
reject "backslash separator"     'a\b'
reject "dot"                     "."
reject "dot-dot"                 ".."
reject "leading dash"            "-rf"
reject "embedded whitespace"     "a b"
reject "uppercase"               "MySkill"
reject "underscore"              "my_skill"
reject "empty name"              ""

# --- accepted: a documented slug creates exactly skills/<name>/SKILL.md
rc=0
"$spark" new-skill test-skill-9 >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && [ -f "$skills/test-skill-9/SKILL.md" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "  ✖ valid slug accepted — rc=$rc, SKILL.md present: $([ -f "$skills/test-skill-9/SKILL.md" ] && echo yes || echo no)"
fi

# --- compat: every skill name the plugin already ships passes the same rule
for existing in "$repo"/plugins/spark/skills/*/; do
  name="$(basename "$existing")"
  case "$name" in
    *[!a-z0-9-]*|-*)
      fail=$((fail + 1))
      echo "  ✖ shipped skill name '$name' would be rejected by the slug rule" ;;
    *) pass=$((pass + 1)) ;;
  esac
done

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
