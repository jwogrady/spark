#!/usr/bin/env bash
# Behavioral tests for `spark next` routing — category and approval boundary
# before Codify (#437).
#
# next_route is a pure function over one issue's canonical metadata, so the
# whole routing POLICY runs offline. The four fixtures below are the concrete
# zd-dns M3 shapes: a documentation baseline, a decision issue, ordinary
# infrastructure implementation, and a human-approved live operation.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib.sh"

script="$here/../plugins/spark/bin/spark"
# shellcheck source=/dev/null
. "$script"

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

# route <want-exit> <desc> <issue> <category> <themes> [needle ...]
route() {
  local want="$1" desc="$2" n="$3" cat="$4" themes="$5"; shift 5
  local out rc=0 needle
  out="$(next_route "$n" "$cat" "$themes" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then bad "$desc — want exit $want, got $rc ($out)"; return 0; fi
  for needle in "$@"; do
    case "$out" in *"$needle"*) ;; *) bad "$desc — output lacks '$needle'"; return 0 ;; esac
  done
  ok
}

# refutes <desc> <issue> <category> <themes> <forbidden>
refutes() {
  local desc="$1" n="$2" cat="$3" themes="$4" forbidden="$5"
  local out
  out="$(next_route "$n" "$cat" "$themes" 2>&1 || true)"
  case "$out" in
    *"$forbidden"*) bad "$desc — output must not contain '$forbidden'" ;;
    *) ok ;;
  esac
}

bash -n "$script" && ok || bad "bash -n spark"

# --- zd-dns shape 1: the documentation baseline (#152) starts the milestone.
# Codify's own contract says it does not write documentation, so routing a
# documentation issue there would hand work to a skill that refuses it.
route 0 "a documentation issue routes to the docs lane" \
  152 documentation "" \
  "category  documentation" \
  "knowledge/audit -> validate -> ship" \
  "codify is code-only by contract"
refutes "a documentation issue is never sent to codify" 152 documentation "" "codify ->"

# --- zd-dns shape 2: the decision-themed research issue (#133). Spark may
# gather evidence and prepare the record; it may not decide.
route 0 "a decision theme stops at a human decision" \
  133 research decision \
  "themes    decision" \
  "STOP: human decision" \
  "the decision is not Spark's to make"

# --- a decision theme is orthogonal: it does NOT replace the category, and it
# stops a code lane just as firmly as a research one.
route 0 "decision stops a code lane without replacing its category" \
  200 feature decision \
  "category  feature" \
  "STOP: human decision"

# --- zd-dns shape 3: ordinary infrastructure implementation (#134/#145).
route 0 "infrastructure routes through the code lane" \
  134 infrastructure "" \
  "category  infrastructure" \
  "codify -> validate -> ship" \
  "approval  none"

# --- zd-dns shape 4: a live production operation carrying human-approval
# (#118/#74). Safe preparation proceeds; the live action does not.
route 0 "human-approval stops before the live action" \
  118 infrastructure human-approval \
  "themes    human-approval" \
  "live action gated" \
  "human authorization required before the live/destructive action" \
  "and no further"
refutes "human-approval never reports no approval needed" 118 infrastructure human-approval "approval  none"

# --- both themes at once: each gate is stated, neither swallows the other.
route 0 "decision and human-approval both surface" \
  201 infrastructure "decision,human-approval" \
  "STOP: human decision" \
  "human judgement required" \
  "human authorization required"

# --- every declared code category reaches the code lane.
for c in bug feature infrastructure tech-debt chore; do
  route 0 "$c routes to the code lane" 300 "$c" "" "codify -> validate -> ship"
done

# --- metadata that cannot be routed fails honestly and names the smallest
# correction; it never guesses a lane.
route 3 "a missing category is not assessed" \
  400 "" "" \
  "carries no issue.taxonomy category" \
  "add exactly one category label"

route 3 "an undeclared category is not assessed" \
  401 "marketing" "" \
  "not in the declared taxonomy" \
  "replace it with exactly one declared category"

refutes "an unroutable issue never names a lane" 400 "" "" "codify"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
