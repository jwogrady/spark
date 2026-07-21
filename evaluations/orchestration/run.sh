#!/usr/bin/env bash
# Orchestration evaluation harness.
#
# RESEARCH EVIDENCE — this measures lifecycle topologies against fixed fixtures
# so a candidate topology can be compared to the recorded single-agent baseline
# on the SAME inputs. It is not a pass/fail unit suite; it lives outside tests/
# on purpose and is not run by tests/run.sh.
#
# Zero runtime dependencies beyond POSIX bash + awk (used only for float math;
# bash has no floats). No jq, no python, no network.
#
# The four metrics, and exactly how each is derived:
#
#   correctness  fraction of answer-key items caught/met.
#                = (rows with caught=1 in the run's findings.tsv)
#                  / (rows in the fixture's answer-key.tsv).
#                Objective: the answer key is fixed; a run only records 1/0.
#
#   quality      normalised human-graded rubric score.
#                = (sum of scores in the run's scorecard.tsv)
#                  / (sum of max in the fixture's rubric.tsv).
#                Subjective: a human grader fills scorecard.tsv per run.
#
#   latency      wall-clock seconds for the run, READ from the run's run.tsv
#                (latency_seconds), carrying its own latency_method field
#                (measured | estimate). The harness does not time the run
#                itself — a zero-dep bash script cannot observe an LLM run's
#                wall clock — so it reports what the run recorded and labels it.
#
#   cost         USD, DERIVED (not measured) from token counts x published rates:
#                = tokens_in/1e6 * input_rate + tokens_out/1e6 * output_rate,
#                with rates from rates.tsv keyed by the run's model, and
#                tokens_in/out READ from run.tsv (carrying tokens_method).
#                The arithmetic is exact; its inputs may be estimates — the
#                tokens_method field says which.
#
# Usage:
#   run.sh list                 list fixtures and their answer-key/rubric sizes
#   run.sh score [TOPOLOGY]      score a topology (default: single-agent-baseline)
#   run.sh validate [TOPOLOGY]   check fixture/run files are well-formed
#   run.sh help

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FIXTURES="$HERE/fixtures"
RUNS="$HERE/runs"
RATES="$HERE/rates.tsv"
EVAL_GROUPS="shape build assure-deliver"
DEFAULT_TOPOLOGY="single-agent-baseline"

die() { echo "run.sh: $1" >&2; exit 1; }

# Count non-comment, non-blank rows in a TSV.
rows() {
  awk -F'\t' '/^[[:space:]]*#/ {next} /^[[:space:]]*$/ {next} {n++} END {print n+0}' "$1"
}

# Sum column N over non-comment, non-blank rows.
sumcol() {
  awk -F'\t' -v c="$2" '
    /^[[:space:]]*#/ {next} /^[[:space:]]*$/ {next}
    { s += ($c + 0) } END { printf "%d", s+0 }' "$1"
}

# Read a key\tvalue pair from a run.tsv-style file.
kv() {
  awk -F'\t' -v k="$2" '
    /^[[:space:]]*#/ {next}
    $1==k { print $2; found=1; exit }
    END { if (!found) print "" }' "$1"
}

cmd_list() {
  echo "Orchestration evaluation fixtures"
  echo "================================="
  for g in $EVAL_GROUPS; do
    ak="$FIXTURES/$g/answer-key.tsv"
    rb="$FIXTURES/$g/rubric.tsv"
    [ -f "$ak" ] || die "missing $ak"
    [ -f "$rb" ] || die "missing $rb"
    printf '  %-16s  %s answer-key items, %s rubric dimensions\n' \
      "$g" "$(rows "$ak")" "$(rows "$rb")"
  done
  echo
  echo "Topologies with recorded runs:"
  for t in "$RUNS"/*/; do
    [ -d "$t" ] || continue
    printf '  %s\n' "$(basename "$t")"
  done
}

cmd_validate() {
  topology="${1:-$DEFAULT_TOPOLOGY}"
  problems=0
  for g in $EVAL_GROUPS; do
    ak="$FIXTURES/$g/answer-key.tsv"
    fnd="$RUNS/$topology/$g/findings.tsv"
    rb="$FIXTURES/$g/rubric.tsv"
    sc="$RUNS/$topology/$g/scorecard.tsv"
    run="$RUNS/$topology/$g/run.tsv"
    for f in "$ak" "$rb" "$fnd" "$sc" "$run"; do
      [ -f "$f" ] || { echo "  missing: ${f#"$HERE"/}" >&2; problems=$((problems+1)); }
    done
    [ -f "$ak" ] && [ -f "$fnd" ] && {
      [ "$(rows "$ak")" = "$(rows "$fnd")" ] || {
        echo "  row mismatch: $g findings ($(rows "$fnd")) != answer-key ($(rows "$ak"))" >&2
        problems=$((problems+1))
      }
    }
    [ -f "$rb" ] && [ -f "$sc" ] && {
      [ "$(rows "$rb")" = "$(rows "$sc")" ] || {
        echo "  row mismatch: $g scorecard ($(rows "$sc")) != rubric ($(rows "$rb"))" >&2
        problems=$((problems+1))
      }
    }
  done
  if [ "$problems" -eq 0 ]; then
    echo "validate: $topology is well-formed"
  else
    die "$problems problem(s) found for topology '$topology'"
  fi
}

cmd_score() {
  topology="${1:-$DEFAULT_TOPOLOGY}"
  [ -d "$RUNS/$topology" ] || die "no recorded runs for topology '$topology'"
  [ -f "$RATES" ] || die "missing rates table: $RATES"

  echo "Orchestration evaluation — topology: $topology"
  echo "RESEARCH EVIDENCE. Not shipped capability. See BASELINE.md."
  echo
  printf '%-16s  %11s  %8s  %9s  %14s\n' \
    group correctness quality "latency" "cost(USD,est)"
  printf '%-16s  %11s  %8s  %9s  %14s\n' \
    ---------------- ----------- -------- --------- --------------

  for g in $EVAL_GROUPS; do
    ak="$FIXTURES/$g/answer-key.tsv"
    rb="$FIXTURES/$g/rubric.tsv"
    fnd="$RUNS/$topology/$g/findings.tsv"
    sc="$RUNS/$topology/$g/scorecard.tsv"
    run="$RUNS/$topology/$g/run.tsv"
    for f in "$ak" "$rb" "$fnd" "$sc" "$run"; do
      [ -f "$f" ] || die "missing ${f#"$HERE"/} (run validate)"
    done

    caught="$(sumcol "$fnd" 2)"; total="$(rows "$ak")"
    got="$(sumcol "$sc" 2)"; max="$(sumcol "$rb" 2)"
    model="$(kv "$run" model)"
    ti="$(kv "$run" tokens_in)"; to="$(kv "$run" tokens_out)"
    tmethod="$(kv "$run" tokens_method)"
    lat="$(kv "$run" latency_seconds)"; lmethod="$(kv "$run" latency_method)"

    rin="$(awk -F'\t' -v m="$model" '$1==m{print $2; exit}' "$RATES")"
    rout="$(awk -F'\t' -v m="$model" '$1==m{print $3; exit}' "$RATES")"
    [ -n "$rin" ] || die "model '$model' not in rates.tsv"

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

main() {
  case "${1:-help}" in
    list)     shift; cmd_list "$@" ;;
    score)    shift; cmd_score "$@" ;;
    validate) shift; cmd_validate "$@" ;;
    help|-h|--help) sed -n '2,52p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) die "unknown command '${1:-}' (try: list | score | validate | help)" ;;
  esac
}

main "$@"
