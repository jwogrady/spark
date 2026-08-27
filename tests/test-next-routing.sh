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

TAXO="feature bug documentation chore tech-debt research infrastructure"

# route <want-exit> <desc> <issue> <category> <themes> [needle ...]
route() {
  local want="$1" desc="$2" n="$3" cat="$4" themes="$5"; shift 5
  local out rc=0 needle
  out="$(next_route "$n" "$cat" "$themes" "$TAXO" 2>&1)" || rc=$?
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
  out="$(next_route "$n" "$cat" "$themes" "$TAXO" 2>&1 || true)"
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
  "is not one of this project's declared categories" \
  "replace it with exactly one declared category"

refutes "an unroutable issue never names a lane" 400 "" "" "codify"

# --- #437 follow-up 1: `research` must NOT imply a human-decision gate.
# The gate belongs to the `decision` theme. Binding it to a category would
# collapse the two signal kinds this router exists to keep apart — and it
# produced a self-contradicting report: a route ending at "human decision"
# beside "approval  none".
route 0 "research alone routes without a decision gate" \
  500 research "" \
  "category  research" \
  "ideate/knowledge -> validate -> ship" \
  "approval  none"
refutes "research alone never asserts a human decision" 500 research "" "human decision"
refutes "research alone never claims human judgement" 500 research "" "human judgement required"

# --- and the gate still appears the moment the theme is actually present.
route 0 "research plus decision does gate" \
  501 research decision \
  "STOP: human decision" \
  "human judgement required"

# --- #437 follow-up 2: documentation has two possible lanes and no label
# distinguishes them, so the audience is disclosed rather than guessed.
route 0 "documentation discloses the internal/outward fork" \
  502 documentation "" \
  "audience  internal by default" \
  "docit" \
  "confirm the audience before running the lane"

# --- #437 follow-up 3: issue.taxonomy is project-configurable, so Spark's
# lane table must not act as a second taxonomy. A category this project
# declares but Spark maps no lane for is a DIFFERENT answer, with a different
# correction, from one the project never declared.
declared_no_lane() {
  local out rc=0
  out="$(next_route 503 ops "" "feature bug ops" 2>&1)" || rc=$?
  [ "$rc" -eq 3 ] || { bad "a declared-but-unmapped category must be not assessed (got $rc)"; return 0; }
  case "$out" in
    *"is declared here, but Spark maps no lane for it"*) ;;
    *) bad "a declared-but-unmapped category must not be called undeclared ($out)"; return 0 ;;
  esac
  case "$out" in
    *"not one of this project's declared categories"*)
      bad "a declared category must never be reported as undeclared" ;;
    *) ok ;;
  esac
}
declared_no_lane

# --- a project that renames its categories still routes the ones it declares.
custom_taxonomy_routes() {
  local out rc=0
  out="$(next_route 504 feature "" "feature ops" 2>&1)" || rc=$?
  [ "$rc" -eq 0 ] || { bad "a declared, mapped category must route under a custom taxonomy (got $rc)"; return 0; }
  case "$out" in
    *"codify -> validate -> ship"*) ok ;;
    *) bad "custom taxonomy routing lost the lane ($out)" ;;
  esac
}
custom_taxonomy_routes

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
