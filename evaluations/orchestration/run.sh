#!/usr/bin/env bash
# Orchestration evaluation suite — a thin consumer of the shared Evaluation
# mechanism (../lib/eval.sh). It supplies only this suite's policy (its groups,
# where its fixtures/runs/rates live, and its research-evidence caveat) and
# delegates all scoring, validation, and listing to the library.
#
# RESEARCH EVIDENCE — this measures lifecycle topologies against fixed fixtures
# so a candidate topology can be compared to the recorded single-agent baseline
# on the SAME inputs. It is not a pass/fail unit suite; it lives outside tests/
# on purpose and is not run by tests/run.sh. See BASELINE.md and, for the reusable
# contract every suite shares, docs/reference/evaluation.md.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/eval.sh"

EVAL_TITLE="Orchestration evaluation"
EVAL_ROOT="$HERE"
EVAL_FIXTURES="$HERE/fixtures"
EVAL_RUNS="$HERE/runs"
EVAL_RATES="$HERE/rates.tsv"
EVAL_GROUPS="shape build assure-deliver"
EVAL_DEFAULT_TOPOLOGY="single-agent-baseline"
EVAL_BANNER="RESEARCH EVIDENCE. Not shipped capability. See BASELINE.md."

eval_main "$@"
