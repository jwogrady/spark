#!/usr/bin/env bash
# deadscan.sh [worktree] [outdir] — read-only dead-code evidence for the v0.23 cleanup.
#
# Surfaces scanned (functions defined with `name() {`):
#   runtime  plugins/spark/bin/spark, plugins/spark/lib/*.sh, plugins/spark/hooks/*.sh, plugins/spark/scripts/hooks/*
#   ci       .github/scripts/**/*.sh (support code the workflows execute)
#   skills   plugins/spark/skills/*/scripts/*, plugins/spark-*/skills/*/scripts/* (shipped support scripts the skills run)
#   tests    tests/lib.sh (the shared test harness; suite-local functions are the suite's own business)
# For every function: whole-word reference counts outside its own definition line, in (a) its own surface,
# (b) tests/, (c) everything else tracked. Zero references in (a)+(b)+(c) → candidate.
# For every candidate the scan then records, per candidate:
#   - an INDIRECT search: the name reached through prefix construction ("${x}_get", "bg_$…", "$name") or as
#     a bare word inside a string anywhere in the tree;
#   - GIT HISTORY: the commits that added/removed the string (git log -S) and every commit whose diff mentions
#     it (git log -G) — a candidate that only ever appears in the commit that introduced it never had a caller.
# Also: obsolete-compatibility markers in the scanned surfaces, and shipped scripts referenced nowhere.
# Output: <outdir>/functions.tsv (all functions), <outdir>/candidates.txt (per-candidate evidence), stdout summary.
set -uo pipefail
cd "${1:-.}" || exit 1
OUT="${2:-$(mktemp -d)}"; mkdir -p "$OUT"
RUNTIME="$(git ls-files plugins/spark/bin/spark 'plugins/spark/lib/*.sh' 'plugins/spark/hooks/*.sh' 'plugins/spark/scripts/hooks/*' | tr '\n' ' ')"
CI="$(git ls-files '.github/scripts/*.sh' '.github/scripts/*/*.sh' | tr '\n' ' ')"
SKILLS="$(git ls-files 'plugins/spark/skills/*/scripts/*' 'plugins/spark-*/skills/*/scripts/*' | tr '\n' ' ')"
TESTLIB="tests/lib.sh"
ALL_TRACKED="$(git ls-files | grep -vE '\.(png|svg)$' | tr '\n' ' ')"
cnt() { { "$@" 2>/dev/null || true; } | wc -l | tr -d ' '; }
defs() { # <file> -> "line<TAB>name"
  grep -nE '^[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{' "$1" | sed -E 's/^([0-9]+):([A-Za-z_][A-Za-z0-9_]*)\(\).*/\1\t\2/'
}
refs_in() { # <name> <files...> -> count of whole-word hits that are not a definition line
  local name="$1"; shift
  { grep -wn -- "$name" "$@" 2>/dev/null || true; } | { grep -vE ":[0-9]+:$name\(\)[[:space:]]*\{" || true; } | wc -l | tr -d ' '
}
{
printf 'surface\tfunction\tdefined_in\trefs_same_surface\trefs_tests\trefs_elsewhere\n'
for f in $RUNTIME; do defs "$f" | while IFS=$'\t' read -r ln name; do
  printf 'runtime\t%s\t%s:%s\t%s\t%s\t%s\n' "$name" "$f" "$ln" "$(refs_in "$name" $RUNTIME)" "$(cnt grep -rlw -- "$name" tests)" "$(cnt grep -rlw -- "$name" plugins/spark/skills plugins/spark/docs .github plugins/spark-audit plugins/spark-connect plugins/spark-docs docs)"
done; done
for f in $CI; do defs "$f" | while IFS=$'\t' read -r ln name; do
  printf 'ci\t%s\t%s:%s\t%s\t%s\t%s\n' "$name" "$f" "$ln" "$(refs_in "$name" $CI .github/workflows/*.yml)" "$(cnt grep -rlw -- "$name" tests)" "$(cnt grep -rlw -- "$name" plugins docs)"
done; done
for f in $SKILLS; do defs "$f" | while IFS=$'\t' read -r ln name; do
  printf 'skills\t%s\t%s:%s\t%s\t%s\t%s\n' "$name" "$f" "$ln" "$(refs_in "$name" $SKILLS)" "$(cnt grep -rlw -- "$name" tests)" "$(cnt grep -rlw -- "$name" plugins/spark/skills/*/SKILL.md plugins/spark/skills/*/references plugins/spark-*/skills plugins/spark/docs docs .github plugins/spark/bin plugins/spark/lib)"
done; done
defs "$TESTLIB" | while IFS=$'\t' read -r ln name; do
  printf 'tests\t%s\t%s:%s\t%s\t%s\t%s\n' "$name" "$TESTLIB" "$ln" "$(refs_in "$name" $TESTLIB)" "$(cnt grep -rlw -- "$name" tests/test-*.sh tests/run.sh tests/bench.sh tests/bench-memo.sh tests/structure.sh)" "$(cnt grep -rlw -- "$name" plugins docs .github)"
done
} > "$OUT/functions.tsv"
total=$(($(wc -l < "$OUT/functions.tsv") - 1))
echo "functions scanned: $total (runtime $(awk -F'\t' 'NR>1&&$1=="runtime"' "$OUT/functions.tsv" | wc -l | tr -d ' '), ci $(awk -F'\t' 'NR>1&&$1=="ci"' "$OUT/functions.tsv" | wc -l | tr -d ' '), skills $(awk -F'\t' 'NR>1&&$1=="skills"' "$OUT/functions.tsv" | wc -l | tr -d ' '), tests/lib.sh $(awk -F'\t' 'NR>1&&$1=="tests"' "$OUT/functions.tsv" | wc -l | tr -d ' '))"
echo "== zero-reference candidates (surface, function, defined_in) =="
awk -F'\t' 'NR>1 && $4==0 && $5==0 && $6==0 {print $1"\t"$2"\t"$3}' "$OUT/functions.tsv" | tee "$OUT/zero.tsv"
echo "== per-candidate evidence → $OUT/candidates.txt =="
: > "$OUT/candidates.txt"
while IFS=$'\t' read -r surface name where; do
  [ -n "$name" ] || continue
  {
    echo "### $surface $name ($where)"
    echo "indirect (prefix construction / string mention anywhere tracked):"
    { grep -nE "\\\$\\{?[A-Za-z_]+\\}?_${name#*_}\\b|${name%%_*}_\\\$|['\"]${name}['\"]|\\b${name}\\b" $ALL_TRACKED 2>/dev/null || true; } | { grep -vE ":[0-9]+:${name}\\(\\)[[:space:]]*\\{" || true; } | cut -c1-160 | sed 's/^/  /'
    echo "git log -S (commits that added/removed the string):"
    git log --format='  %h %cs %s' -S"$name" -- . | head -8
    echo "git log -G (commits whose diff mentions the name):"
    git log --format='  %h %cs %s' -G"\\b$name\\b" -- . | head -8
    echo
  } >> "$OUT/candidates.txt"
done < "$OUT/zero.tsv"
cat "$OUT/candidates.txt"
echo "== obsolete-compatibility markers (runtime + ci) =="
{ grep -nEi 'legacy|deprecated|backward|compat(ibility)? (path|shim|fallback)|for compatibility|no longer (used|needed|read|written)|kept for|retained for|old (format|schema|name)|removed in v|since v0\.[0-9]+' $RUNTIME $CI $SKILLS || true; } | cut -c1-200
echo "== shipped and ci scripts referenced nowhere =="
for s in $(git ls-files 'plugins/spark/skills/*/scripts/*' plugins/spark/scripts '.github/scripts/*.sh' '.github/scripts/*/*.sh'); do
  b="$(basename "$s")"
  n=$({ grep -rlF -- "$b" plugins docs tests .github AGENTS.md README.md 2>/dev/null || true; } | { grep -vF -- "$s" || true; } | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] && echo "  unreferenced: $s"
done
echo "(scan done; outputs in $OUT)"
