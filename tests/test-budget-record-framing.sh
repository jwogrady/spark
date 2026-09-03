#!/usr/bin/env bash
# Regression suite for #642 — budget text may never manufacture TSV records.
#
# The budget file is a machine-enforced envelope. A text value that can inject
# another key turns prose into authority over spend. These fixtures therefore
# attack every text-bearing input and the ambiguous pre-fix on-disk format.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "budget record framing (#642)"
sandbox_init
make_repo "$WORK/proj"
cd "$WORK/proj"

run_rc() {
  local want="$1" desc="$2"; shift 2
  local got=0 out
  out="$("$@" 2>&1)" || got=$?
  if [ "$got" = "$want" ]; then ok; else bad "$desc — wanted rc $want, got $got"; fi
  printf '%s' "$out"
}

# A rejected value must say what the caller has to fix, not merely fail.
assert_one_line_error() {
  local desc="$1" out="$2"
  assert_contains "$desc" "one line" "$out"
}

# --- convergence cannot inject an envelope/state key ------------------------
OUT="$(run_rc 1 "newline convergence is rejected" \
  "$SPARK" budget declare --run inject-nl \
  --convergence $'suite green\nmax_full_suite\t0')"
assert_one_line_error "newline rejection explains the framing rule" "$OUT"
[ ! -e .spark/budgets/inject-nl.tsv ] && ok || bad "rejected convergence must not create a budget file"

OUT="$(run_rc 1 "tab convergence is rejected" \
  "$SPARK" budget declare --run inject-tab --convergence $'suite\tgreen')"
assert_one_line_error "tab rejection explains the framing rule" "$OUT"
[ ! -e .spark/budgets/inject-tab.tsv ] && ok || bad "rejected tab convergence must not create a budget file"

OUT="$(run_rc 1 "CR convergence is rejected" \
  "$SPARK" budget declare --run inject-cr --convergence $'suite\rgreen')"
assert_one_line_error "CR rejection explains the framing rule" "$OUT"
[ ! -e .spark/budgets/inject-cr.tsv ] && ok || bad "rejected CR convergence must not create a budget file"

# A malicious redeclaration must leave an existing valid envelope unchanged.
"$SPARK" budget declare --run stable --convergence "green" >/dev/null
OUT="$(run_rc 1 "rejected convergence cannot rewrite an existing envelope" \
  "$SPARK" budget declare --run stable \
  --convergence $'green\nmax_full_suite\t0')"
assert_one_line_error "existing-envelope rejection is actionable" "$OUT"
J="$("$SPARK" budget status --run stable --json)"
assert_contains "rejected convergence did not manufacture max_full_suite" '"max_full_suite":null' "$J"

# --- every other text-bearing budget input has the same boundary ------------
for spec in \
  "model|--model" \
  "effort|--effort"
do
  name="${spec%%|*}"; flag="${spec#*|}"
  OUT="$(run_rc 1 "$name newline injection is rejected" \
    "$SPARK" budget declare --run "text-$name" --convergence "green" \
    "$flag" $'safe\nmax_full_suite=0')"
  assert_one_line_error "$name rejection explains the framing rule" "$OUT"
  if [ -e ".spark/budgets/text-$name.tsv" ]; then
    J="$("$SPARK" budget status --run "text-$name" --json 2>/dev/null || true)"
    case "$J" in
      *'"max_full_suite":0'*) bad "$name text manufactured max_full_suite" ;;
      *) ok ;;
    esac
  else
    ok
  fi
done

"$SPARK" budget declare --run reopen-safe --convergence "green" --max-full-suite 2 >/dev/null
"$SPARK" budget record --run reopen-safe --failing 1 >/dev/null
BEFORE="$("$SPARK" budget status --run reopen-safe --json)"
OUT="$(run_rc 1 "reopen reason newline injection is rejected" \
  "$SPARK" budget reopen --run reopen-safe \
  --reason $'new evidence\nmax_full_suite\t0')"
assert_one_line_error "reopen reason rejection explains the framing rule" "$OUT"
AFTER="$("$SPARK" budget status --run reopen-safe --json)"
[ "$BEFORE" = "$AFTER" ] && ok || bad "rejected reopen reason must not mutate budget state"

# --- accepted one-line text still round-trips through JSON ------------------
"$SPARK" budget declare --run json-safe \
  --convergence 'green when "quoted" path \\ remains stable' \
  --model 'model "quoted" \\ id' --effort 'medium effort' >/dev/null
J="$("$SPARK" budget status --run json-safe --json)"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$J" | jq empty >/dev/null 2>&1 && ok || bad "accepted one-line budget text must emit valid JSON"
else
  ok
fi
assert_contains "accepted convergence survives JSON projection" 'green when \"quoted\" path \\\\' "$J"

# --- the serialization boundary itself is fail-closed, not just today's flags
# Every text-bearing CLI flag above calls bg_reject_framing before it ever
# stages a value, but that only proves the ENUMERATED flags are safe. A future
# author adds a new bgv_<key> and a new BUDGET_KEYS entry without necessarily
# remembering to guard its call site the same way. bg_write must refuse to
# serialize framing on its own, for a key no CLI flag here has ever heard of —
# proving the guarantee lives at the boundary, not in each caller's memory.
BOUNDARY_SCRIPT="$WORK/boundary-probe.sh"
cat > "$BOUNDARY_SCRIPT" <<'EOF'
set -eu
. "$1" >/dev/null 2>&1
bg_load "/nonexistent-budget-probe.tsv"
BUDGET_KEYS="$BUDGET_KEYS future_field"
bgv_future_field="$(printf 'safe\nmax_full_suite\t0')"
f="$2"
if bg_write "$f"; then echo "WROTE"; else echo "REJECTED"; fi
if [ -f "$f" ]; then cat "$f"; fi
EOF
BOUNDARY_FILE="$WORK/boundary.tsv"
boundary_rc=0
BOUNDARY_OUT="$(bash "$BOUNDARY_SCRIPT" "$SPARK" "$BOUNDARY_FILE" 2>&1)" || boundary_rc=$?
[ "$boundary_rc" -eq 0 ] || bad "boundary probe script itself failed (rc $boundary_rc): $BOUNDARY_OUT"
case "$BOUNDARY_OUT" in
  *REJECTED*) ok ;;
  *) bad "bg_write must reject framing in a key no CLI flag validates, not just the enumerated flags — got: $BOUNDARY_OUT" ;;
esac
case "$BOUNDARY_OUT" in
  *max_full_suite*) bad "an unrecognized future field's framing must not manufacture max_full_suite" ;;
  *) ok ;;
esac
[ ! -e "$BOUNDARY_FILE" ] && ok || bad "bg_write must not create a record when any field fails the framing check"

# --- the generic staging/assignment path is fail-closed, not just bg_write --
# The probe above proves bg_write refuses a framed value handed to it
# directly, but that bypasses cmd_budget's own staging: every option above
# calls bg_stage, which queues a pending declare assignment for
# bg_apply_staged to validate and assign. A future text option could call
# bg_stage without repeating its own bg_reject_framing precheck first — this
# drives a future text key through those same two calls, with no precheck run
# first, and proves the staging/assignment path itself rejects newline, tab
# and CR alike, and that none can manufacture max_full_suite or any other
# second assignment.
STAGE_SCRIPT="$WORK/stage-probe.sh"
cat > "$STAGE_SCRIPT" <<'EOF'
set -eu
. "$1" >/dev/null 2>&1
BUDGET_KEYS="$BUDGET_KEYS future_field"
bg_pairs_n=0
bg_stage future_field "$2"
if bg_apply_staged; then echo "APPLIED"; else echo "REJECTED"; fi
echo "max_full_suite=[${bgv_max_full_suite:-}]"
EOF
for spec in \
  "nl|$(printf 'safe\nmax_full_suite=0')" \
  "tab|$(printf 'safe\tmax_full_suite=0')" \
  "cr|$(printf 'safe\rmax_full_suite=0')"
do
  sep="${spec%%|*}"; val="${spec#*|}"
  stage_rc=0
  STAGE_OUT="$(bash "$STAGE_SCRIPT" "$SPARK" "$val" 2>&1)" || stage_rc=$?
  [ "$stage_rc" -eq 0 ] || bad "stage probe ($sep) script itself failed (rc $stage_rc): $STAGE_OUT"
  case "$STAGE_OUT" in
    *REJECTED*) ok ;;
    *) bad "bg_apply_staged must reject a $sep-framed value staged through bg_stage — got: $STAGE_OUT" ;;
  esac
  case "$STAGE_OUT" in
    *'max_full_suite=[0]'*) bad "a $sep-framed staged value must not manufacture max_full_suite" ;;
    *) ok ;;
  esac
done

# --- ambiguous pre-fix records cannot silently acquire authority ------------
# Before #642 a multiline convergence value could serialize to exactly the same
# bytes as a legitimate bound. There is no honest parser-only way to know which
# producer wrote this file. It may remain readable only if the implementation
# has a mechanically unambiguous migration; otherwise it must fail explicitly
# with repair guidance rather than treating max_full_suite=0 as intentional.
mkdir -p .spark/budgets
printf 'convergence\tsuite green\nmax_full_suite\t0\nmax_no_progress\t1\n' > .spark/budgets/legacy-ambiguous.tsv
legacy_rc=0
LEGACY="$("$SPARK" budget status --run legacy-ambiguous 2>&1)" || legacy_rc=$?
if [ "$legacy_rc" -eq 0 ]; then
  bad "ambiguous legacy budget was silently reinterpreted as an intentional bound"
else
  ok
  assert_contains "legacy refusal gives repair guidance" "repair" "$LEGACY"
fi

finish
