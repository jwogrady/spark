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
