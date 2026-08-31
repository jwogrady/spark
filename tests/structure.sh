#!/usr/bin/env bash
# Spark structural baseline (#614).
#
# Decomposition has to be argued from the call/data/authority graph, not from
# line counts. A 900-line function that nothing else touches is a smaller
# problem than a 40-line one that eleven verbs depend on, and only the graph
# tells you which is which.
#
# WHAT THE REFERENCE COUNTS ACTUALLY ARE. This finds, for each function body,
# occurrences of other known function names as whole words. That is a TEXTUAL
# REFERENCE COUNT, not a call graph: a name inside a comment or a string counts,
# and a name reached through a variable does not. It is named `references`
# throughout for that reason. It is strong enough to separate shared primitives
# from verb-local helpers — which is the question decomposition actually asks —
# and too weak to be quoted as a call count.
#
# Reported:
#   size       bytes, lines, function count, function size distribution
#   shared     functions referenced by several verbs — these are the primitives
#              a thin dispatcher must keep canonical, never copy
#   local      functions referenced by exactly one verb — these can move with it
#   globals    top-level variable assignments, the coupling that survives any
#              file split and quietly defeats it
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
F="$root/plugins/spark/bin/spark"
as_json=""
as_raw=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) as_json=1 ;;
    # The scanner's own rows, so its correctness can be asserted against a
    # fixture whose answer is known by construction rather than inferred from a
    # summary of the real executable.
    --raw)  as_raw=1 ;;
    -h|--help)
      echo "usage: structure.sh [--json]"
      echo "  Reports the structural baseline of the core executable: size,"
      echo "  function distribution, shared vs verb-local functions (by textual"
      echo "  reference, not call graph), and top-level global state."
      exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    # An explicit target, so the scanner can be exercised against a fixture
    # whose correct answer is known by construction.
    *) F="$1" ;;
  esac
  if [ "$#" -gt 0 ]; then shift; fi
done

[ -f "$F" ] || { echo "core executable not found at $F" >&2; exit 2; }

ANALYSIS="$(awk '
  # ---- record function ranges and bodies -----------------------------------
  # A function ENDS at a closing brace in column zero, or on its own line for a
  # one-liner. Without that, `cur` never clears: every line after the first
  # function is charged to it, and the top-level-assignment rule never fires
  # again — which silently reports almost no globals and inflates both sizes and
  # references with text that belongs to no function at all.
  /^[a-z_][a-z0-9_]*\(\)[[:space:]]*\{/ {
    name = $0; sub(/\(\).*/, "", name)
    order[++nf] = name; start[name] = NR
    len[name] = 1; body[name] = $0
    # `red() { ...; }` opens and closes on one line.
    cur = ($0 ~ /\}[[:space:]]*$/) ? "" : name
    next
  }
  cur != "" {
    len[cur]++; body[cur] = body[cur] "\n" $0
    if ($0 ~ /^\}[[:space:]]*$/) { end[cur] = NR; cur = "" }
    next
  }
  # Reached only OUTSIDE a function body, which is what makes this a top-level
  # assignment rather than any assignment that happens to start a line.
  /^[A-Za-z_][A-Za-z0-9_]*=/ { g = $0; sub(/=.*/, "", g); globals[g] = 1 }
  END {
    # ---- which functions each function references --------------------------
    for (i = 1; i <= nf; i++) {
      f = order[i]
      for (j = 1; j <= nf; j++) {
        t = order[j]
        if (t == f) continue
        if (body[f] ~ ("(^|[^A-Za-z0-9_])" t "([^A-Za-z0-9_]|$)")) {
          refs[f, t] = 1
          refsof[f] = refsof[f] " " t
        }
      }
    }
    # ---- verbs are the cmd_* entry points ----------------------------------
    nv = 0
    for (i = 1; i <= nf; i++) if (order[i] ~ /^cmd_/) verbs[++nv] = order[i]

    # Transitive closure per verb, so a helper reached two levels down still
    # counts as belonging to that verb.
    for (v = 1; v <= nv; v++) {
      delete seen
      stack[1] = verbs[v]; sp = 1
      while (sp > 0) {
        f = stack[sp--]
        for (j = 1; j <= nf; j++) {
          t = order[j]
          if ((f SUBSEP t) in refs && !(t in seen) && t !~ /^cmd_/) {
            seen[t] = 1; stack[++sp] = t
          }
        }
      }
      for (t in seen) usedby[t] = usedby[t] " " verbs[v]
      for (t in seen) nusers[t]++
    }

    printf "SIZE\t%d\t%d\n", nf, 0
    for (i = 1; i <= nf; i++) printf "FUNC\t%s\t%d\n", order[i], len[order[i]]
    for (i = 1; i <= nf; i++)
      printf "RANGE\t%s\t%d\t%d\n", order[i], start[order[i]], (order[i] in end ? end[order[i]] : start[order[i]])
    for (i = 1; i <= nf; i++) printf "REFS\t%s\t%s\n", order[i], refsof[order[i]]
    for (t in nusers) printf "USED\t%s\t%d\t%s\n", t, nusers[t], usedby[t]
    for (g in globals) printf "GLOBAL\t%s\n", g
  }
' "$F")"

if [ -n "$as_raw" ]; then printf '%s\n' "$ANALYSIS"; exit 0; fi

fn_count="$(printf '%s\n' "$ANALYSIS" | awk -F'\t' '$1=="SIZE"{print $2}')"
bytes="$(wc -c < "$F" | tr -d ' ')"
lines="$(wc -l < "$F" | tr -d ' ')"
globals="$(printf '%s\n' "$ANALYSIS" | awk -F'\t' '$1=="GLOBAL"{n++} END{print n+0}')"

# Shared primitives: referenced by several verbs. These must stay canonical —
# a thin dispatcher may source them, never restate them.
shared="$(printf '%s\n' "$ANALYSIS" | awk -F'\t' '$1=="USED" && $3 >= 3 {print $3 "\t" $2}' | LC_ALL=C sort -rn)"
shared_n="$(printf '%s' "$shared" | awk 'NF' | wc -l | tr -d ' ')"
single="$(printf '%s\n' "$ANALYSIS" | awk -F'\t' '$1=="USED" && $3 == 1 {print $2}' | LC_ALL=C sort)"
single_n="$(printf '%s' "$single" | awk 'NF' | wc -l | tr -d ' ')"

if [ -n "$as_json" ]; then
  printf '{"bytes":%s,"lines":%s,"functions":%s,"globals":%s,' "$bytes" "$lines" "$fn_count" "$globals"
  printf '"references_are":"textual whole-word references between function bodies, not a call graph",'
  printf '"shared_by_3_or_more_verbs":%s,"referenced_by_one_verb":%s}\n' "$shared_n" "$single_n"
  exit 0
fi

echo "Spark structural baseline — plugins/spark/bin/spark"
echo "  bytes $bytes   lines $lines   functions $fn_count   top-level globals $globals"
echo
echo "Largest functions (lines):"
printf '%s\n' "$ANALYSIS" | awk -F'\t' '$1=="FUNC"{printf "  %6d  %s\n", $3, $2}' | LC_ALL=C sort -rn | head -12
echo
echo "Shared primitives — referenced by 3+ verbs ($shared_n).  These stay canonical;"
echo "a module may own one, but nothing may restate it:"
printf '%s\n' "$shared" | head -12 | awk -F'\t' 'NF{printf "  %3d verbs  %s\n", $1, $2}'
echo
echo "Verb-local clusters — functions referenced by exactly one verb ($single_n total),"
echo "grouped by owner. A large cluster is a coherent module the graph itself names:"
printf '%s\n' "$ANALYSIS" \
  | awk -F'\t' '$1=="USED" && $3==1 { v=$4; gsub(/^ +/,"",v); n[v]++ } END { for (v in n) printf "%d\t%s\n", n[v], v }' \
  | LC_ALL=C sort -rn | head -10 | awk -F'\t' '{ printf "  %3d functions  %s\n", $1, $2 }'
echo
echo "references = textual whole-word references between function bodies. NOT a"
echo "call graph: a name in a comment counts, a name reached via a variable does"
echo "not. Strong enough to separate shared from verb-local, too weak to quote as"
echo "a call count."
