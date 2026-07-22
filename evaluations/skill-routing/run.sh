#!/usr/bin/env bash
# Skill-routing evaluation suite — a thin consumer of the shared Evaluation
# mechanism (../lib/eval.sh). It supplies only this suite's policy (its group,
# where its fixtures/runs/rates live, and its measurement caveat) and delegates
# all scoring, validation, and listing to the library.
#
# Measures how the core skill descriptions route representative prompts, so a
# description trim carries before/after routing evidence (#293/#313). n = 1,
# model-judged — see fixtures/routing/task.md for the method and its limits,
# and docs/reference/evaluation.md for the contract every suite shares.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/eval.sh"

EVAL_TITLE="Skill-routing evaluation"
EVAL_ROOT="$HERE"
EVAL_FIXTURES="$HERE/fixtures"
EVAL_RUNS="$HERE/runs"
EVAL_RATES="$HERE/rates.tsv"
EVAL_GROUPS="routing"
EVAL_DEFAULT_TOPOLOGY="current-descriptions"
EVAL_BANNER="n=1, MODEL-JUDGED routing (no live selector trace). See fixtures/routing/task.md."

eval_main "$@"
