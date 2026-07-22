#!/usr/bin/env bash
# Shared evaluation mechanics for Spark's Evaluation surface.
#
# This is the reusable MECHANISM behind every evaluation suite. It knows how to
# read the TSV contract, score the four metrics, and validate a run's shape — but
# nothing about any particular suite. A suite (e.g. evaluations/orchestration/)
# supplies its POLICY as config, then calls eval_main. Policy stays in the suite
# and the contract doc; mechanism stays here. The canonical contract is
# docs/reference/evaluation.md.
#
# Zero runtime dependencies beyond Bash + awk (awk only for float math; bash has
# no floats). No jq, no python, no network. Grading is graded
# measurement, not a pass/fail unit suite — this library lives outside tests/
# and is not run by tests/run.sh (its own logic is covered by tests/test-eval-lib.sh).
#
# A consumer sources this file and sets, before calling eval_main "$@":
#   EVAL_TITLE            human title, e.g. "Orchestration evaluation"
#   EVAL_FIXTURES         dir holding <group>/{answer-key,rubric}.tsv (+ task/seed)
#   EVAL_RUNS             dir holding <topology>/<group>/{findings,scorecard,run}.tsv
#   EVAL_RATES            model→$/Mtok table for the cost metric
#   EVAL_GROUPS           space-separated group names to iterate
#   EVAL_DEFAULT_TOPOLOGY topology used when none is named
#   EVAL_BANNER           optional caveat line printed under score/list titles

# Prefix diagnostics with the invoking script's basename ("run.sh: ...").
eval_die() { echo "${0##*/}: $1" >&2; exit 1; }

# Count non-comment, non-blank rows in a TSV.
eval_rows() {
  awk -F'\t' '/^[[:space:]]*#/ {next} /^[[:space:]]*$/ {next} {n++} END {print n+0}' "$1"
}

# Sum column N over non-comment, non-blank rows.
eval_sumcol() {
  awk -F'\t' -v c="$2" '
    /^[[:space:]]*#/ {next} /^[[:space:]]*$/ {next}
    { s += ($c + 0) } END { printf "%d", s+0 }' "$1"
}

# Read a key<TAB>value pair from a run.tsv-style file.
eval_kv() {
  awk -F'\t' -v k="$2" '
    /^[[:space:]]*#/ {next}
    $1==k { print $2; found=1; exit }
    END { if (!found) print "" }' "$1"
}

eval_list() {
  local title="$EVAL_TITLE fixtures" g ak rb t
  printf '%s\n' "$title"
  printf '%*s\n' "${#title}" '' | tr ' ' '='
  for g in $EVAL_GROUPS; do
    ak="$EVAL_FIXTURES/$g/answer-key.tsv"
    rb="$EVAL_FIXTURES/$g/rubric.tsv"
    [ -f "$ak" ] || eval_die "missing $ak"
    [ -f "$rb" ] || eval_die "missing $rb"
    printf '  %-16s  %s answer-key items, %s rubric dimensions\n' \
      "$g" "$(eval_rows "$ak")" "$(eval_rows "$rb")"
  done
  echo
  echo "Topologies with recorded runs:"
  for t in "$EVAL_RUNS"/*/; do
    [ -d "$t" ] || continue
    printf '  %s\n' "$(basename "$t")"
  done
}

# Compare the column-1 identifiers of two TSV files (comments/blanks skipped).
# The "actual" file must cover exactly the "expected" file's ids — no missing,
# no unexpected, no duplicates on either side. Row-count equality does not prove
# this: a file with the right number of unrelated ids would pass a count check.
# Diagnostics go to stderr; the problem count is printed to stdout.
eval_check_ids() { # <expected-file> <actual-file> <group> <expected-name> <actual-name>
  awk -F'\t' -v g="$3" -v en="$4" -v an="$5" '
    function is_data() { return ($0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/) }
    FNR==NR {
      if (is_data()) {
        c = ++e[$1]
        if (c == 1) eord[++ne] = $1
        else if (c == 2) { printf "  duplicate: %s %s id \"%s\"\n", g, en, $1 > "/dev/stderr"; p++ }
      }
      next
    }
    {
      if (is_data()) {
        c = ++a[$1]
        if (c == 1) aord[++na] = $1
        else if (c == 2) { printf "  duplicate: %s %s id \"%s\"\n", g, an, $1 > "/dev/stderr"; p++ }
      }
    }
    END {
      for (i = 1; i <= ne; i++) { k = eord[i]; if (!(k in a)) { printf "  missing: %s %s lacks expected id \"%s\"\n", g, an, k > "/dev/stderr"; p++ } }
      for (i = 1; i <= na; i++) { k = aord[i]; if (!(k in e)) { printf "  unexpected: %s %s has unknown id \"%s\"\n", g, an, k > "/dev/stderr"; p++ } }
      print p + 0
    }' "$1" "$2"
}

eval_validate() {
  local topology="${1:-$EVAL_DEFAULT_TOPOLOGY}" problems=0 g ak fnd rb sc run f n
  for g in $EVAL_GROUPS; do
    ak="$EVAL_FIXTURES/$g/answer-key.tsv"
    fnd="$EVAL_RUNS/$topology/$g/findings.tsv"
    rb="$EVAL_FIXTURES/$g/rubric.tsv"
    sc="$EVAL_RUNS/$topology/$g/scorecard.tsv"
    run="$EVAL_RUNS/$topology/$g/run.tsv"
    for f in "$ak" "$rb" "$fnd" "$sc" "$run"; do
      [ -f "$f" ] || { echo "  missing: ${f#"$EVAL_ROOT"/}" >&2; problems=$((problems+1)); }
    done
    # Identity, not just cardinality: findings must cover exactly the answer-key
    # items and scorecard exactly the rubric dimensions — same column-1 ids.
    if [ -f "$ak" ] && [ -f "$fnd" ]; then
      n="$(eval_check_ids "$ak" "$fnd" "$g" "answer-key" "findings")"; problems=$((problems + n))
    fi
    if [ -f "$rb" ] && [ -f "$sc" ]; then
      n="$(eval_check_ids "$rb" "$sc" "$g" "rubric" "scorecard")"; problems=$((problems + n))
    fi
  done
  if [ "$problems" -eq 0 ]; then
    echo "validate: $topology is well-formed"
  else
    eval_die "$problems problem(s) found for topology '$topology'"
  fi
}

eval_score() {
  local topology="${1:-$EVAL_DEFAULT_TOPOLOGY}" g ak rb fnd sc run f
  local caught total got max model ti to lat lmethod rin rout line
  [ -d "$EVAL_RUNS/$topology" ] || eval_die "no recorded runs for topology '$topology'"
  [ -f "$EVAL_RATES" ] || eval_die "missing rates table: $EVAL_RATES"

  echo "$EVAL_TITLE — topology: $topology"
  [ -n "${EVAL_BANNER:-}" ] && echo "$EVAL_BANNER"
  echo
  printf '%-16s  %11s  %8s  %9s  %14s\n' \
    group correctness quality "latency" "cost(USD,est)"
  printf '%-16s  %11s  %8s  %9s  %14s\n' \
    ---------------- ----------- -------- --------- --------------

  for g in $EVAL_GROUPS; do
    ak="$EVAL_FIXTURES/$g/answer-key.tsv"
    rb="$EVAL_FIXTURES/$g/rubric.tsv"
    fnd="$EVAL_RUNS/$topology/$g/findings.tsv"
    sc="$EVAL_RUNS/$topology/$g/scorecard.tsv"
    run="$EVAL_RUNS/$topology/$g/run.tsv"
    for f in "$ak" "$rb" "$fnd" "$sc" "$run"; do
      [ -f "$f" ] || eval_die "missing ${f#"$EVAL_ROOT"/} (run validate)"
    done

    caught="$(eval_sumcol "$fnd" 2)"; total="$(eval_rows "$ak")"
    got="$(eval_sumcol "$sc" 2)"; max="$(eval_sumcol "$rb" 2)"
    model="$(eval_kv "$run" model)"
    ti="$(eval_kv "$run" tokens_in)"; to="$(eval_kv "$run" tokens_out)"
    lat="$(eval_kv "$run" latency_seconds)"; lmethod="$(eval_kv "$run" latency_method)"

    rin="$(awk -F'\t' -v m="$model" '$1==m{print $2; exit}' "$EVAL_RATES")"
    rout="$(awk -F'\t' -v m="$model" '$1==m{print $3; exit}' "$EVAL_RATES")"
    [ -n "$rin" ] || eval_die "model '$model' not in rates table"

    line="$(awk -v caught="$caught" -v total="$total" -v got="$got" -v max="$max" \
      -v ti="$ti" -v to="$to" -v rin="$rin" -v rout="$rout" \
      -v lat="$lat" -v lm="$lmethod" -v g="$g" 'BEGIN {
        corr = (total>0)? caught/total : 0
        qual = (max>0)?   got/max     : 0
        cost = ti/1000000*rin + to/1000000*rout
        printf "%-16s  %4d/%-2d %4.2f  %8.2f  %6s%-2s  %14.4f",
          g, caught, total, corr, qual, lat, lm=="measured"?"s":"~", cost
      }')"
    echo "$line"
  done

  echo
  echo "Method:"
  echo "  correctness = answer-key items caught / total (objective, from findings.tsv)"
  echo "  quality     = rubric score / rubric max (human-graded, from scorecard.tsv)"
  echo "  latency     = run.tsv latency_seconds; 's'=measured, '~'=estimate"
  echo "  cost        = tokens_in/1e6*in_rate + tokens_out/1e6*out_rate (DERIVED,"
  echo "                rates from rates.tsv; token counts + method in run.tsv)"
}

# Clean usage. (The previous per-suite help sed-printed the script header and
# leaked code past the comment block; this prints only the contract + usage.)
eval_help() {
  local self="${0##*/}"
  echo "$EVAL_TITLE harness."
  [ -n "${EVAL_BANNER:-}" ] && { echo; echo "$EVAL_BANNER"; }
  cat <<EOF

Graded measurement over fixed fixtures — not a pass/fail suite. See the contract:
docs/reference/evaluation.md. Zero deps beyond Bash + awk.

The four metrics:
  correctness  answer-key items caught / total          (objective, findings.tsv)
  quality      rubric score / rubric max                (human-graded, scorecard.tsv)
  latency      run.tsv latency_seconds ('s'=measured, '~'=estimate; never timed here)
  cost         tokens_in/1e6*in_rate + tokens_out/1e6*out_rate (derived; rates table)

Usage:
  $self list                 list fixtures and their answer-key/rubric sizes
  $self score [TOPOLOGY]      score a topology (default: $EVAL_DEFAULT_TOPOLOGY)
  $self validate [TOPOLOGY]   check fixture/run files are well-formed
  $self help
EOF
}

# Dispatch. EVAL_ROOT (for tidy relative paths in diagnostics) defaults to the
# fixtures' parent when a suite does not set it.
eval_main() {
  : "${EVAL_ROOT:=$(dirname "$EVAL_FIXTURES")}"
  case "${1:-help}" in
    list)     shift; eval_list "$@" ;;
    score)    shift; eval_score "$@" ;;
    validate) shift; eval_validate "$@" ;;
    help|-h|--help) eval_help ;;
    *) eval_die "unknown command '${1:-}' (try: list | score | validate | help)" ;;
  esac
}
