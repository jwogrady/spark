#!/usr/bin/env bash
# deadscan.sh — read-only evidence for #738 against the frozen tree (runtime identical to current master).
# For every function defined in the runtime, count whole-word references anywhere in the repository other
# than its own definition line. Zero → candidate. Also list obsolete-compatibility markers in runtime code.
set -uo pipefail
cd "${1:-.}" || exit 1
OUT="${2:-$(mktemp -d)}"
RUNTIME="plugins/spark/bin/spark plugins/spark/lib/execution.sh plugins/spark/lib/planning.sh plugins/spark/lib/repository.sh plugins/spark/hooks/guard-bash.sh plugins/spark/scripts/hooks/commit-msg plugins/spark/scripts/hooks/pre-commit"
cnt() { { "$@" 2>/dev/null || true; } | wc -l | tr -d ' '; }
{
printf 'function\tdefined_in\trefs_runtime\trefs_tests\trefs_other\n'
for f in $RUNTIME; do
  grep -nE '^[A-Za-z_][A-Za-z0-9_]*\(\)\s*\{' "$f" | sed -E 's/^([0-9]+):([A-Za-z_][A-Za-z0-9_]*)\(\).*/\1\t\2/' | while IFS=$'\t' read -r ln name; do
    rr=$({ grep -wn -- "$name" $RUNTIME 2>/dev/null || true; } | { grep -vE ":[0-9]+:$name\(\)[[:space:]]*\{" || true; } | wc -l | tr -d ' ')
    rt=$(cnt grep -rlw -- "$name" tests)
    ro=$(cnt grep -rlw -- "$name" plugins/spark/skills plugins/spark/docs .github plugins/spark-audit plugins/spark-connect plugins/spark-docs docs)
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$f:$ln" "$rr" "$rt" "$ro"
  done
done
} > "$OUT/functions.tsv"
echo "functions scanned: $(($(wc -l < "$OUT/functions.tsv") - 1))"
echo "== zero runtime references (candidates; tests/other counts shown) =="
awk -F'\t' 'NR>1 && $3==0' "$OUT/functions.tsv"
echo "== runtime refs == 1 and no test refs (informational) =="
awk -F'\t' 'NR>1 && $3==1 && $4==0' "$OUT/functions.tsv" | head -20
echo "== obsolete-compatibility markers in runtime =="
{ grep -nEi 'legacy|deprecated|backward|compat(ibility)? (path|shim|fallback)|for compatibility|no longer (used|needed|read|written)|kept for|retained for|old (format|schema|name)|removed in v|since v0\.[0-9]+' $RUNTIME || true; } | cut -c1-200
echo "== scripts under plugins referenced nowhere =="
for s in $(git ls-files 'plugins/spark/skills/*/scripts/*' plugins/spark/scripts); do
  b="$(basename "$s")"
  n=$({ grep -rlF -- "$b" plugins docs tests .github AGENTS.md README.md 2>/dev/null || true; } | { grep -vF -- "$s" || true; } | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] && echo "  unreferenced: $s"
done
echo "(scan done)"
