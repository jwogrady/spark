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

# --- unresolved identity at the check level: an empty id (no issue reference)
# is advisory and non-blocking, and the feat is named — never invented as an id.
printf '%s' "$HDR" > "$work/index.tsv"
printf -- '-\tadd the thing\n' > "$work/caps.tsv"
rc=0; out="$(bash "$script" --index "$work/index.tsv" --capabilities "$work/caps.tsv" --evaluations-root "$EVROOT" 2>&1)" || rc=$?
state="$(printf '%s\n' "$out" | sed -n 's/^gate-state: //p' | head -n1)"
if [ "$rc" -eq 0 ] && [ "$state" = "neutral" ]; then ok; else bad "unresolved -> neutral/exit0 (rc=$rc state=$state: $out)"; fi
case "$out" in *'feat "add the thing" — no issue reference'*) ok ;; *) bad "unresolved names the feat, does not invent an id ($out)" ;; esac

# ============================================================================
# Runner pure helpers (Findings 1 & 2). Source the runner: main is guarded, so
# only the functions load — no CI side effects.
# ============================================================================
. "$root/.github/scripts/platform-compat-runner.sh"

# Finding 1 — exit-code mapping. A usage/config error or any unexpected code must
# NEVER become a successful advisory.
[ "$(compat_status_for 0)" = "success" ] && ok || bad "rc 0 -> success"
[ "$(compat_status_for 1)" = "failure" ] && ok || bad "rc 1 -> failure"
[ "$(compat_status_for 3)" = "success" ] && ok || bad "rc 3 (not-assessed) -> success (honest, non-error)"
[ "$(compat_status_for 2)" = "error" ]   && ok || bad "rc 2 (usage/config) -> error, never success"
[ "$(compat_status_for 42)" = "error" ]  && ok || bad "unexpected rc -> error, never success"

# Finding 2 — deterministic one-record-per-capability; unresolved never invented.
res="$(printf '206\tadd A\n206\tadd A again\n207\tadd B\n\tadd C\n\tadd C\n' | compat_resolve_capabilities)"
[ "$(printf '%s\n' "$res" | awk -F'\t' '$1=="206"{c++} END{print c+0}')" = "1" ] && ok || bad "duplicate id 206 collapses to one record ($res)"
[ "$(printf '%s\n' "$res" | awk -F'\t' '$1=="207"{c++} END{print c+0}')" = "1" ] && ok || bad "207 present exactly once ($res)"
[ "$(printf '%s\n' "$res" | awk -F'\t' '$1=="206"{print $2; exit}')" = "add A" ] && ok || bad "206 keeps the first (deterministic) label ($res)"
[ "$(printf '%s\n' "$res" | awk -F'\t' '$1=="-"{c++} END{print c+0}')" = "1" ] && ok || bad "unresolved (sentinel id) deduped by subject to one record ($res)"

# --- #310: capability-id extraction must tolerate a feat with no issue reference
# and never abort the runner under `set -euo pipefail` (grep exits 1 on no match).
# Case 1 — feat with an issue reference: id extracted.
[ "$(compat_issue_id 'feat: add thing (#123)')" = "123" ] && ok || bad "case1: '(#123)' -> 123 (got '$(compat_issue_id 'feat: add thing (#123)')')"
# Case 2 — feat with NO reference: empty id, and the call does not abort. This
# whole test file runs under `set -e`; reaching the next line proves no abort.
id2="$(compat_issue_id 'feat: add thing')"
[ -z "$id2" ] && ok || bad "case2: no reference -> empty id (got '$id2')"
ok  # reached here without the set -e abort the bug caused
# Case 3 — existing behavior unchanged: first reference wins, deterministically.
[ "$(compat_issue_id 'feat: close #7 and #8')" = "7" ] && ok || bad "case3: first reference wins (got '$(compat_issue_id 'feat: close #7 and #8')')"

# --- integration: the discovery step over a mix (with a no-ref feat) completes
# and yields a deterministic caps list — a resolved id plus a "-" sentinel — with
# no abort, so the checker is reached (the failure mode was aborting beforehand).
caps_out="$(printf 'feat: add exporter (#42)\nfeat: tidy things\n' | while IFS= read -r subj; do
  printf '%s\t%s\n' "$(compat_issue_id "$subj")" "${subj#*: }"
done | compat_resolve_capabilities)"
[ "$(printf '%s\n' "$caps_out" | awk -F'\t' '$1=="42"{c++} END{print c+0}')" = "1" ] && ok || bad "integration: referenced feat -> id 42 ($caps_out)"
[ "$(printf '%s\n' "$caps_out" | awk -F'\t' '$1=="-"{c++} END{print c+0}')" = "1" ] && ok || bad "integration: no-ref feat -> unresolved sentinel, no abort ($caps_out)"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
