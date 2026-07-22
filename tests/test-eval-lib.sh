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
printf '# item\nitem one\nitem two\n'                 > "$work/fixtures/g1/answer-key.tsv"
printf '# dimension\tmax\nclarity\t2\ndepth\t2\n'     > "$work/fixtures/g1/rubric.tsv"
printf 'caught one\t1\ncaught two\t0\n'               > "$work/runs/t1/g1/findings.tsv"
printf 'clarity\t1\ndepth\t2\n'                       > "$work/runs/t1/g1/scorecard.tsv"
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

# --- validate: a findings/answer-key row mismatch is caught (non-zero).
printf 'caught one\t1\ncaught two\t0\ncaught three\t1\n' > "$work/runs/t1/g1/findings.tsv"
rc=0; out="$(eval_main validate t1 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"row mismatch: g1 findings"*) true ;; *) false ;; esac; } \
  && ok || bad "validate rejects a row mismatch ($rc: $out)"

# --- an unknown command exits non-zero with guidance.
rc=0; out="$(eval_main bogus 2>&1)" || rc=$?
{ [ "$rc" -ne 0 ] && case "$out" in *"unknown command"*) true ;; *) false ;; esac; } \
  && ok || bad "unknown command is rejected ($rc: $out)"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
