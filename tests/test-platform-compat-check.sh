#!/usr/bin/env bash
# Offline suite for the Platform Compatibility Review decision logic (#300,
# ADR-0026). It exercises platform-compat-check.sh against a throwaway evidence
# index, capability lists, and a real evaluation suite that sources the shipped
# eval.sh — so the `required` path genuinely runs the suite's `validate`, not a
# stand-in. No network, no gh, no git.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/.github/scripts/platform-compat-check.sh"
lib="$root/evaluations/lib/eval.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

bash -n "$script" && ok || bad "bash -n platform-compat-check.sh"

# --- Build a throwaway evaluation suite 's1' that consumes the real library,
# with a VALID topology (ids match) and a MALFORMED one (a renamed id).
suite="$work/evals/s1"
mkdir -p "$suite/fixtures/g1" "$suite/runs/valid/g1" "$suite/runs/malformed/g1"
printf '# id\tdescription\nA1\tfirst\nA2\tsecond\n' > "$suite/fixtures/g1/answer-key.tsv"
printf '# id\tmax\nc1\t2\nc2\t2\n'                  > "$suite/fixtures/g1/rubric.tsv"
printf 'm1\t3\t6\n'                                 > "$suite/rates.tsv"
run_tsv() { printf 'model\tm1\ntokens_in\t1000\ntokens_out\t100\ntokens_method\testimate\nlatency_seconds\t10\nlatency_method\testimate\n' > "$1"; }
# valid: findings ids match the answer key; scorecard ids match the rubric.
printf 'A1\t1\nA2\t0\n' > "$suite/runs/valid/g1/findings.tsv"
printf 'c1\t1\nc2\t2\n' > "$suite/runs/valid/g1/scorecard.tsv"; run_tsv "$suite/runs/valid/g1/run.tsv"
# malformed: A9 is not in the answer key, A2 is missing -> eval validate fails.
printf 'A1\t1\nA9\t0\n' > "$suite/runs/malformed/g1/findings.tsv"
printf 'c1\t1\nc2\t2\n' > "$suite/runs/malformed/g1/scorecard.tsv"; run_tsv "$suite/runs/malformed/g1/run.tsv"
cat > "$suite/run.sh" <<RUNSH
#!/usr/bin/env bash
set -euo pipefail
HERE="\$(cd "\$(dirname "\$0")" && pwd)"
. "$lib"
EVAL_TITLE="Test"; EVAL_ROOT="\$HERE"; EVAL_FIXTURES="\$HERE/fixtures"
EVAL_RUNS="\$HERE/runs"; EVAL_RATES="\$HERE/rates.tsv"
EVAL_GROUPS="g1"; EVAL_DEFAULT_TOPOLOGY="valid"; EVAL_BANNER=""
eval_main "\$@"
RUNSH
EVROOT="$work/evals"

# check <want-exit> <want-state> <desc> <index-content> <caps-content> [needle ...]
check() {
  local want="$1" wstate="$2" desc="$3" idx="$4" caps="$5"; shift 5
  local out rc=0 needle state
  printf '%s' "$idx"  > "$work/index.tsv"
  printf '%s' "$caps" > "$work/caps.tsv"
  out="$(bash "$script" --index "$work/index.tsv" --capabilities "$work/caps.tsv" --evaluations-root "$EVROOT" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then bad "$desc — want exit $want, got $rc ($out)"; return 0; fi
  state="$(printf '%s\n' "$out" | sed -n 's/^gate-state: //p' | head -n1)"
  if [ "$state" != "$wstate" ]; then bad "$desc — want state '$wstate', got '$state' ($out)"; return 0; fi
  for needle in "$@"; do
    case "$out" in *"$needle"*) ;; *) bad "$desc — output lacks '$needle'"; return 0 ;; esac
  done
  ok
}

HDR="# capability_id	requirement	suite	topology"

# 1. required + present + valid -> ready.
check 0 ready "required+valid -> ready" \
"$HDR
206	required	s1	valid" \
"206" \
  "declared and valid (required):   1" "capability 206"

# 2. required + missing suite -> blocked.
check 1 blocked "required+missing-suite -> blocked" \
"$HDR
207	required	nosuch	valid" \
"207" \
  "required suite 'nosuch' is missing"

# 3. required + missing topology -> blocked.
check 1 blocked "required+missing-topology -> blocked" \
"$HDR
208	required	s1	nope" \
"208" \
  "required topology 'nope' is missing"

# 4. required + malformed evidence -> blocked through the suite's validate.
check 1 blocked "required+malformed -> blocked via validate" \
"$HDR
209	required	s1	malformed" \
"209" \
  "failed the suite's validate"

# 5. incomplete required declaration -> blocked.
check 1 blocked "required+incomplete -> blocked" \
"$HDR
210	required		" \
"210" \
  "incomplete required declaration"

# 6. not-required -> non-blocking and reported (neutral: nothing required verified).
check 0 neutral "not-required -> reported, non-blocking" \
"$HDR
211	not-required		" \
"211" \
  "explicitly not required:         1" "declared not-required"

# 7. undeclared released capability -> advisory and named.
check 0 neutral "undeclared -> advisory + named" \
"$HDR" \
"212" \
  "undeclared (advisory):           1" "capability 212" "no evidence-index entry"

# 8. empty index -> neutral/advisory, never 'all evaluated'.
check 0 neutral "empty index -> neutral advisory" \
"$HDR" \
"206" \
  "does not claim all capabilities were evaluated" "undeclared (advisory):           1"

# 9. duplicate declaration -> blocked as ambiguous.
check 1 blocked "duplicate declaration -> ambiguous" \
"$HDR
213	required	s1	valid
213	not-required		" \
"213" \
  "ambiguous"

# 10. unknown requirement value -> blocked.
check 1 blocked "unknown requirement -> blocked" \
"$HDR
214	maybe	s1	valid" \
"214" \
  "unknown requirement value 'maybe'"

# 11. no reliable release range -> not assessed (exit 3), mirroring the gate convention.
rc=0; out="$(bash "$script" --index "$work/index.tsv" --capabilities "$work/caps.tsv" --evaluations-root "$EVROOT" --no-range 2>&1)" || rc=$?
{ [ "$rc" -eq 3 ] && case "$out" in *"not assessed: release range unavailable"*) true ;; *) false ;; esac; } \
  && ok || bad "no-range -> not assessed exit 3 ($rc: $out)"

# 12. language: says 'declared evaluation evidence', never 'all capabilities evaluated'.
printf '%s\n206\trequired\ts1\tvalid\n' "$HDR" > "$work/index.tsv"
printf '206\n' > "$work/caps.tsv"
out="$(bash "$script" --index "$work/index.tsv" --capabilities "$work/caps.tsv" --evaluations-root "$EVROOT" 2>&1)" || true
case "$out" in *"declared evaluation evidence"*) ok ;; *) bad "language — missing 'declared evaluation evidence' ($out)" ;; esac
case "$out" in *"all capabilities evaluated"*) bad "language — must never claim 'all capabilities evaluated' ($out)" ;; *) ok ;; esac

# usage errors exit 2.
rc=0; bash "$script" --index "$work/nope.tsv" --capabilities "$work/caps.tsv" --evaluations-root "$EVROOT" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok || bad "missing index file -> exit 2 (got $rc)"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
