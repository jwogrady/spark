#!/usr/bin/env bash
# Behavioral suite for the shared Evaluation mechanism (evaluations/lib/eval.sh).
# The grading harness itself is graded measurement and lives outside tests/, but
# its reusable LOGIC — row counting, column sums, metric math, and shape
# validation — is deterministic and belongs under the behavioral gate (ADR-0018).
# It runs against a throwaway fixture; no network, no git, no real suite.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
lib="$root/evaluations/lib/eval.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

bash -n "$lib" && ok || bad "bash -n eval.sh"

# --- Build a minimal one-group, one-topology suite. Cost is chosen to land on a
# known value: 1e6 in @ 3 + 5e5 out @ 6 = 3.0 + 3.0 = 6.0000.
mkdir -p "$work/fixtures/g1" "$work/runs/t1/g1"
printf '# id\tdescription\nA1\titem one\nA2\titem two\n' > "$work/fixtures/g1/answer-key.tsv"
printf '# id\tmax\nclarity\t2\ndepth\t2\n'            > "$work/fixtures/g1/rubric.tsv"
printf 'A1\t1\nA2\t0\n'                               > "$work/runs/t1/g1/findings.tsv"
printf 'clarity\t1\ndepth\t2\n'                       > "$work/runs/t1/g1/scorecard.tsv"

# Restore the good run files (id-matched to the fixtures) — the id-integrity
# tests below corrupt one file at a time, so reset between them.
good_findings()  { printf 'A1\t1\nA2\t0\n'      > "$work/runs/t1/g1/findings.tsv"; }
good_scorecard() { printf 'clarity\t1\ndepth\t2\n' > "$work/runs/t1/g1/scorecard.tsv"; }
printf 'model\tm1\ntokens_in\t1000000\ntokens_out\t500000\ntokens_method\testimate\nlatency_seconds\t120\nlatency_method\tmeasured\n' > "$work/runs/t1/g1/run.tsv"
printf 'm1\t3\t6\n'                                    > "$work/rates.tsv"

# Load the mechanism and point it at the throwaway suite.
. "$lib"
EVAL_TITLE="Test suite"
EVAL_ROOT="$work"
EVAL_FIXTURES="$work/fixtures"
EVAL_RUNS="$work/runs"
EVAL_RATES="$work/rates.tsv"
EVAL_GROUPS="g1"
EVAL_DEFAULT_TOPOLOGY="t1"
EVAL_BANNER=""

# --- Pure helpers: counting, summing, key lookup (comments/blanks ignored).
[ "$(eval_rows "$work/fixtures/g1/answer-key.tsv")" = "2" ] && ok || bad "eval_rows ignores the comment row"
[ "$(eval_sumcol "$work/runs/t1/g1/findings.tsv" 2)" = "1" ] && ok || bad "eval_sumcol sums caught column"
[ "$(eval_kv "$work/runs/t1/g1/run.tsv" model)" = "m1" ] && ok || bad "eval_kv reads a key/value"
[ -z "$(eval_kv "$work/runs/t1/g1/run.tsv" nonesuch)" ] && ok || bad "eval_kv returns empty for a missing key"

# --- validate: a well-formed suite passes (exit 0).
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -eq 0 ] && case "$out" in *"t1 is well-formed"*) true ;; *) false ;; esac; } \
  && ok || bad "validate accepts a well-formed suite ($rc: $out)"

# --- score: correctness 1/2=0.50, quality 3/4=0.75, cost 6.0000, measured latency.
rc=0; out="$(eval_main score t1 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then bad "score exited $rc ($out)"; else
  for needle in "1/2 " "0.50" "0.75" "6.0000" "120s"; do
    case "$out" in *"$needle"*) ok ;; *) bad "score output lacks '$needle' ($out)" ;; esac
  done
fi

# --- IDENTITY, not cardinality: equal row count with a renamed id must fail,
# reporting both the missing expected id and the unexpected unknown id.
good_scorecard; printf 'A1\t1\nA9\t0\n' > "$work/runs/t1/g1/findings.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
if [ "$rc" -eq 0 ]; then bad "renamed id (equal count) must fail but passed ($out)"; else
  case "$out" in *"missing: g1 findings lacks expected id \"A2\""*) ok ;; *) bad "renamed id — no missing-A2 diagnostic ($out)" ;; esac
  case "$out" in *"unexpected: g1 findings has unknown id \"A9\""*) ok ;; *) bad "renamed id — no unexpected-A9 diagnostic ($out)" ;; esac
fi

# --- a duplicate id (equal row count, one item repeated, one missing) fails.
good_scorecard; printf 'A1\t1\nA1\t0\n' > "$work/runs/t1/g1/findings.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"duplicate: g1 findings id \"A1\""*) true ;; *) false ;; esac; } \
  && ok || bad "duplicate id must fail with a duplicate diagnostic ($rc: $out)"

# --- the same rule governs scorecard vs rubric dimensions.
good_findings; printf 'clarity\t1\nspeed\t2\n' > "$work/runs/t1/g1/scorecard.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
if [ "$rc" -eq 0 ]; then bad "renamed rubric dimension must fail but passed ($out)"; else
  case "$out" in *"missing: g1 scorecard lacks expected id \"depth\""*) ok ;; *) bad "scorecard — no missing-depth diagnostic ($out)" ;; esac
  case "$out" in *"unexpected: g1 scorecard has unknown id \"speed\""*) ok ;; *) bad "scorecard — no unexpected-speed diagnostic ($out)" ;; esac
fi
good_findings; good_scorecard  # leave the suite well-formed

# --- an unknown command exits non-zero with guidance.
rc=0; out="$(eval_main bogus 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"unknown command"*) true ;; *) false ;; esac; } \
  && ok || bad "unknown command is rejected ($rc: $out)"

# ============================================================================
# Metric-range validation (#306): identity is not enough — values must be sane.
# ============================================================================
good_run() { printf 'model\tm1\ntokens_in\t1000000\ntokens_out\t500000\ntokens_method\testimate\nlatency_seconds\t120\nlatency_method\tmeasured\n' > "$work/runs/t1/g1/run.tsv"; }
good_rubric() { printf '# id\tmax\nclarity\t2\ndepth\t2\n' > "$work/fixtures/g1/rubric.tsv"; }

# caught value outside {0,1} is rejected, naming the id.
good_findings; good_scorecard; printf 'A1\t2\nA2\t0\n' > "$work/runs/t1/g1/findings.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *'findings id "A1" caught="2"'*) true ;; *) false ;; esac; } \
  && ok || bad "caught=2 must be rejected ($rc: $out)"

# non-numeric caught is rejected.
printf 'A1\tx\nA2\t0\n' > "$work/runs/t1/g1/findings.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *'caught="x"'*) true ;; *) false ;; esac; } \
  && ok || bad "non-numeric caught must be rejected ($rc: $out)"

# a score exceeding its rubric max is rejected.
good_findings; printf 'clarity\t9\ndepth\t2\n' > "$work/runs/t1/g1/scorecard.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *'score 9 exceeds rubric max 2'*) true ;; *) false ;; esac; } \
  && ok || bad "score above rubric max must be rejected ($rc: $out)"

# a negative score is rejected.
printf 'clarity\t-1\ndepth\t2\n' > "$work/runs/t1/g1/scorecard.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *'scorecard id "clarity" score="-1"'*) true ;; *) false ;; esac; } \
  && ok || bad "negative score must be rejected ($rc: $out)"

# a non-positive rubric max (a scoring denominator) is rejected.
good_scorecard; printf '# id\tmax\nclarity\t0\ndepth\t2\n' > "$work/fixtures/g1/rubric.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *'rubric id "clarity" max="0"'*) true ;; *) false ;; esac; } \
  && ok || bad "non-positive rubric max must be rejected ($rc: $out)"
good_rubric

# valid evidence still validates (no false positives from the range checks).
good_findings; good_scorecard; good_run
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -eq 0 ] && case "$out" in *"well-formed"*) true ;; *) false ;; esac; } \
  && ok || bad "valid evidence still validates ($rc: $out)"

# ============================================================================
# Run-facts + required-config validation (#304).
# ============================================================================
# run.tsv missing a required key is caught by validate, naming the key.
printf 'model\tm1\ntokens_out\t500000\ntokens_method\testimate\nlatency_seconds\t120\nlatency_method\tmeasured\n' > "$work/runs/t1/g1/run.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"run.tsv missing key 'tokens_in'"*) true ;; *) false ;; esac; } \
  && ok || bad "missing run.tsv key must be caught ($rc: $out)"

# a model absent from the rates table is caught at validate, not silently at score.
printf 'model\tnope\ntokens_in\t1\ntokens_out\t1\ntokens_method\testimate\nlatency_seconds\t1\nlatency_method\tmeasured\n' > "$work/runs/t1/g1/run.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"model 'nope' not in rates table"*) true ;; *) false ;; esac; } \
  && ok || bad "unknown model must be caught by validate ($rc: $out)"
good_run

# a suite that forgot a required variable gets a named error, not a set -u crash.
rc=0; out="$(EVAL_RATES="" eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"missing required config: EVAL_RATES"*) true ;; *) false ;; esac; } \
  && ok || bad "missing required config is named ($rc: $out)"

# non-numeric run facts are caught — they would otherwise coerce to 0 in scoring
# and publish a silently wrong cost/latency as valid evidence.
good_run; printf 'model\tm1\ntokens_in\tlots\ntokens_out\t1\ntokens_method\testimate\nlatency_seconds\t1\nlatency_method\tmeasured\n' > "$work/runs/t1/g1/run.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *'tokens_in="lots"'*) true ;; *) false ;; esac; } \
  && ok || bad "non-numeric tokens_in must be caught ($rc: $out)"

printf 'model\tm1\ntokens_in\t1\ntokens_out\t1\ntokens_method\testimate\nlatency_seconds\tsoon\nlatency_method\tmeasured\n' > "$work/runs/t1/g1/run.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *'latency_seconds="soon"'*) true ;; *) false ;; esac; } \
  && ok || bad "non-numeric latency_seconds must be caught ($rc: $out)"

# a non-numeric rate for the run's model is caught (cost would coerce to 0).
good_run; printf 'm1\tcheap\t6\n' > "$work/rates.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *'in-rate'*'non-numeric'*) true ;; *) false ;; esac; } \
  && ok || bad "non-numeric rate must be caught ($rc: $out)"
printf 'm1\t3\t6\n' > "$work/rates.tsv"

# a missing rates table is caught by validate, not only at score time.
good_run; rm -f "$work/rates.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *'missing rates table'*) true ;; *) false ;; esac; } \
  && ok || bad "missing rates table must be caught ($rc: $out)"
printf 'm1\t3\t6\n' > "$work/rates.tsv"

# ============================================================================
# CONTRACT (not message) guarantees.
# ============================================================================
# score consumes the SAME authority as validate: it must refuse to emit any
# metric from evidence validate would reject (no bypass / coercion path). This
# is the guarantee, independent of wording.
good_findings; good_scorecard; good_run
printf 'A1\t2\nA2\t0\n' > "$work/runs/t1/g1/findings.tsv"   # caught=2 is invalid
rc=0; out="$(eval_main score t1 2>&1)" || rc=$?
if [ "$rc" -eq 0 ]; then bad "score must refuse invalid evidence, exited 0 ($out)"; else ok; fi
case "$out" in *"Test suite — topology"*) bad "score emitted its metric table on invalid evidence ($out)" ;; *) ok ;; esac
good_findings

# duplicate key in run.tsv is rejected rather than silently first-match-resolved.
printf 'model\tm1\nmodel\tm2\ntokens_in\t1\ntokens_out\t1\ntokens_method\testimate\nlatency_seconds\t1\nlatency_method\tmeasured\n' > "$work/runs/t1/g1/run.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"duplicate key 'model'"*) true ;; *) false ;; esac; } \
  && ok || bad "duplicate run.tsv key must be rejected ($rc: $out)"
good_run

# a duplicate model row in the rates table is rejected (ambiguous).
printf 'm1\t3\t6\nm1\t9\t9\n' > "$work/rates.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"rows for model 'm1' (ambiguous)"*) true ;; *) false ;; esac; } \
  && ok || bad "duplicate rate row must be rejected ($rc: $out)"
printf 'm1\t3\t6\n' > "$work/rates.tsv"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
