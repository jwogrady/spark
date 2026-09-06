#!/usr/bin/env bash
# deadscan.sh [worktree] [outdir] — read-only dead-code evidence for the v0.23 cleanup.
#
# Surfaces scanned (functions defined with `name() {`):
#   runtime  plugins/spark/bin/spark, plugins/spark/lib/*.sh, plugins/spark/hooks/*.sh, plugins/spark/scripts/hooks/*
#   ci       .github/scripts/**/*.sh (support code the workflows execute)
#   skills   plugins/spark/skills/*/scripts/*, plugins/spark-*/skills/*/scripts/* (shipped support scripts the skills run)
#   tests    tests/lib.sh (the shared test harness; suite-local functions are the suite's own business)
#
# WHAT A "REFERENCE" IS HERE. A reference is a LINE, outside the function's own definition line and not a
# comment line (first non-blank character `#`), that contains the function name as a whole word. Counted in
# three places: (a) the function's own surface, (b) tests/, (c) every other tracked text file EXCEPT this
# audit's own artifacts under docs/research/v0.23-cleanup/ (they list every function name and would give
# everything an artificial reference). A name inside a string or a heredoc still counts — the count is an
# UPPER BOUND on real call sites, which errs toward keeping code. A function is a candidate only when all
# three counts are zero: nothing anywhere mentions it outside its definition and comments.
#
# PER-CANDIDATE EVIDENCE, recorded mechanically:
#   - INDIRECT: the name reached through prefix construction ("${x}_get", "bg_$…") or as a quoted string,
#     anywhere tracked (same exclusion);
#   - HISTORY: `git log -S` (commits that added/removed the string), `git log -G` (commits whose diff mentions
#     it), and for EVERY such commit a `git grep -w` of the whole tree at that revision with definition and
#     comment lines removed — so "no revision ever called it" is a checked count per revision, not an inference.
# Also: obsolete-compatibility markers in the scanned surfaces, and shipped or ci scripts referenced nowhere.
# Output: <outdir>/functions.tsv (all functions), <outdir>/candidates.txt (per-candidate evidence), stdout summary.
set -uo pipefail
cd "${1:-.}" || exit 1
OUT="${2:-$(mktemp -d)}"; mkdir -p "$OUT"
EXCL="docs/research/v0.23-cleanup"
RUNTIME="$(git ls-files plugins/spark/bin/spark 'plugins/spark/lib/*.sh' 'plugins/spark/hooks/*.sh' 'plugins/spark/scripts/hooks/*' | tr '\n' ' ')"
CI="$(git ls-files '.github/scripts/*.sh' '.github/scripts/*/*.sh' | tr '\n' ' ')"
SKILLS="$(git ls-files 'plugins/spark/skills/*/scripts/*' 'plugins/spark-*/skills/*/scripts/*' | tr '\n' ' ')"
TESTLIB="tests/lib.sh"
TEXT="$(git ls-files | grep -vE '\.(png|svg)$' | grep -v "^$EXCL/" | tr '\n' ' ')"
TESTS="$(git ls-files 'tests/*' | tr '\n' ' ')"
defs() { grep -nE '^[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{' "$1" | sed -E 's/^([0-9]+):([A-Za-z_][A-Za-z0-9_]*)\(\).*/\1\t\2/'; }
# refs <name> <files...> — non-comment, non-definition lines containing the whole word
refs() {
  local name="$1"; shift
  [ "$#" -gt 0 ] || { echo 0; return; }
  { grep -Hnw -- "$name" "$@" 2>/dev/null || true; } \
    | { grep -vE ":[0-9]+:[[:space:]]*#" || true; } \
    | { grep -vE ":[0-9]+:$name\(\)[[:space:]]*\{" || true; } | wc -l | tr -d ' '
}
others() { # <files-in-own-surface...> → the "elsewhere" set: TEXT minus own surface minus tests
  local own=" $* " f out=""
  for f in $TEXT; do case "$own" in *" $f "*) ;; *) case "$f" in tests/*) ;; *) out="$out $f" ;; esac ;; esac; done
  printf '%s' "$out"
}
ELSE_RUNTIME="$(others $RUNTIME)"; ELSE_CI="$(others $CI .github/workflows/*.yml)"; ELSE_SKILLS="$(others $SKILLS)"; ELSE_TESTLIB="$(others $TESTLIB)"
{
printf 'surface\tfunction\tdefined_in\trefs_same_surface\trefs_tests\trefs_elsewhere\n'
for f in $RUNTIME; do defs "$f" | while IFS=$'\t' read -r ln name; do
  printf 'runtime\t%s\t%s:%s\t%s\t%s\t%s\n' "$name" "$f" "$ln" "$(refs "$name" $RUNTIME)" "$(refs "$name" $TESTS)" "$(refs "$name" $ELSE_RUNTIME)"
done; done
for f in $CI; do defs "$f" | while IFS=$'\t' read -r ln name; do
  printf 'ci\t%s\t%s:%s\t%s\t%s\t%s\n' "$name" "$f" "$ln" "$(refs "$name" $CI .github/workflows/*.yml)" "$(refs "$name" $TESTS)" "$(refs "$name" $ELSE_CI)"
done; done
for f in $SKILLS; do defs "$f" | while IFS=$'\t' read -r ln name; do
  printf 'skills\t%s\t%s:%s\t%s\t%s\t%s\n' "$name" "$f" "$ln" "$(refs "$name" $SKILLS)" "$(refs "$name" $TESTS)" "$(refs "$name" $ELSE_SKILLS)"
done; done
defs "$TESTLIB" | while IFS=$'\t' read -r ln name; do
  printf 'tests\t%s\t%s:%s\t%s\t%s\t%s\n' "$name" "$TESTLIB" "$ln" "$(refs "$name" $TESTLIB)" "$(refs "$name" $(git ls-files 'tests/*' | grep -v '^tests/lib.sh$' | tr '\n' ' '))" "$(refs "$name" $ELSE_TESTLIB)"
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
    echo "indirect (prefix construction / quoted string, anywhere tracked except $EXCL):"
    { grep -HnE "\\\$\\{?[A-Za-z_]+\\}?_${name#*_}\\b|${name%%_*}_\\\$|['\"]${name}['\"]" $TEXT 2>/dev/null || true; } | cut -c1-160 | sed 's/^/  /'
    echo "git log -S (commits that added/removed the string):"
    git log --format='  %h %cs %s' -S"$name" -- . | head -8
    echo "git log -G (commits whose diff mentions the name):"
    git log --format='  %h %cs %s' -G"\\b$name\\b" -- . | head -8
    echo "per-revision whole-tree references (non-comment, non-definition lines) at each of those commits:"
    for c in $( { git log --format='%h' -S"$name" -- .; git log --format='%h' -G"\\b$name\\b" -- .; } | sort -u); do
      n=$({ git grep -nw -- "$name" "$c" -- . 2>/dev/null || true; } | { grep -vE ":[0-9]+:[[:space:]]*#" || true; } | { grep -vE ":[0-9]+:$name\(\)[[:space:]]*\{" || true; } | { grep -v "$EXCL/" || true; } | wc -l | tr -d ' ')
      echo "  $c: $n reference line(s) outside definition and comments"
    done
    echo
  } >> "$OUT/candidates.txt"
done < "$OUT/zero.tsv"
cat "$OUT/candidates.txt"
echo "== obsolete-compatibility markers (runtime + ci + skills) =="
{ grep -nEi 'legacy|deprecated|backward|compat(ibility)? (path|shim|fallback)|for compatibility|no longer (used|needed|read|written)|kept for|retained for|old (format|schema|name)|removed in v|since v0\.[0-9]+' $RUNTIME $CI $SKILLS || true; } | cut -c1-200
echo "== shipped and ci scripts referenced nowhere (excluding $EXCL) =="
for s in $(git ls-files 'plugins/spark/skills/*/scripts/*' plugins/spark/scripts '.github/scripts/*.sh' '.github/scripts/*/*.sh'); do
  b="$(basename "$s")"
  n=$({ grep -rlF --exclude-dir=v0.23-cleanup -- "$b" plugins docs tests .github AGENTS.md README.md 2>/dev/null || true; } | { grep -vF -- "$s" || true; } | wc -l | tr -d ' ')
  [ "$n" -eq 0 ] && echo "  unreferenced: $s"
done
echo "(scan done; outputs in $OUT)"
