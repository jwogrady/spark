#!/usr/bin/env bash
# Behavioral tests for bounded-increment merge authority (#726).
#
# The defect: PR #724 was a bounded, independently reviewed optimization that
# #722 authorized, reached exact-HEAD #584 PASS with green checks, and still
# could not merge — because #677 required the OWNING issue's acceptance to be
# true and the merge to make the OWNING issue true, and #722 ("prove the gate
# with equal-workload benchmarks") is deliberately not true yet. Every routine
# increment beneath a broad outcome hit a human stop. That is ceremony.
#
# The correction must not swing into the opposite defect. xr_stop_check (#690)
# fails toward CONTINUE because ITS defect was a false stop; this classifier
# fails toward NOT ELIGIBLE because its defect would be manufactured merge
# authority. So these fixtures spend most of their weight on what must NOT
# merge, and on proving that a child merge never closes its parent.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/../plugins/spark/lib/execution.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

echo "Bounded-increment merge authority (#726)"

bash -n "$here/../plugins/spark/lib/execution.sh" && ok || bad "bash -n execution.sh"

# verdict <want-verdict> <want-rc> <desc> <args...>
verdict() {
  local want="$1" wrc="$2" desc="$3"; shift 3
  local out rc=0
  out="$(xr_merge_check "$@" 2>&1)" || rc=$?
  local got; got="$(printf '%s\n' "$out" | head -1)"
  if [ "$got" != "$want" ]; then bad "$desc — want verdict '$want' got '$got'"; return 0; fi
  if [ "$rc" != "$wrc" ]; then bad "$desc — want rc $wrc got $rc"; return 0; fi
  ok
}

# The fully-established bounded increment, reused as the base for every negative
# control below. Kept in one place so a control differs from eligibility by
# EXACTLY the field under test — otherwise a control could pass for the wrong
# reason.
ELIGIBLE=(
  parent-authorizes="#722 authorizes bounded optimization increments"
  child-acceptance="memoize git_root and resolve_prefs, transparently, for measured verbs"
  acceptance-true=yes
  review=pass
  checks=green
  stale-head=protected
  scope=routine-reversible
)

# The variants are built into an ARRAY, never echoed through command
# substitution. An unquoted $(...) word-splits on whitespace, so a multi-word
# value like child-acceptance="memoize git_root and resolve_prefs" would arrive
# as five bare words and be refused by the ARGUMENT PARSER. Every negative
# control below would then "pass" without ever reaching the condition it claims
# to test — a fixture that proves nothing while looking green.
A=()

# mk_without <field> — the base set with one field dropped entirely.
mk_without() {
  local drop="$1" a; A=()
  for a in "${ELIGIBLE[@]}"; do
    case "$a" in "$drop"=*) ;; *) A+=("$a") ;; esac
  done
}

# mk_instead <field> <value> — the base set with one field replaced.
mk_instead() {
  local field="$1" value="$2" a; A=()
  for a in "${ELIGIBLE[@]}"; do
    case "$a" in "$field"=*) A+=("$field=$value") ;; *) A+=("$a") ;; esac
  done
}

# vwithout / vinstead <want-verdict> <want-rc> <desc> <field> [value]
vwithout() { local w="$1" r="$2" d="$3" f="$4"; mk_without "$f"; verdict "$w" "$r" "$d" "${A[@]}"; }
vinstead() { local w="$1" r="$2" d="$3" f="$4" v="$5"; mk_instead "$f" "$v"; verdict "$w" "$r" "$d" "${A[@]}"; }

# Guard the guard: the base set must itself be eligible, and each helper must
# return the right number of fields. If ELIGIBLE ever stops being eligible,
# every negative control below would pass for the wrong reason.
verdict "ROUTINE MERGE" 0 "the shared base set is eligible before any control mutates it" "${ELIGIBLE[@]}"
mk_without review
[ "${#A[@]}" = 6 ] && ok || bad "mk_without must drop exactly one field (got ${#A[@]})"
mk_instead review fail
[ "${#A[@]}" = 7 ] && ok || bad "mk_instead must preserve the field count (got ${#A[@]})"
case " ${A[*]} " in *" review=fail "*) ok ;; *) bad "mk_instead must substitute the value" ;; esac
# A multi-word value must survive as ONE argument, or the controls test the parser.
mk_instead child-acceptance "two words here"
[ "${#A[@]}" = 7 ] && ok || bad "a multi-word value must stay one argument (got ${#A[@]})"

# --- the #722 -> #724 case: this is the whole point of the issue ------------
# Broad parent open and incomplete, bounded child fully accepted, exact HEAD
# independently passing, checks green, no reserved boundary.
verdict "ROUTINE MERGE" 0 "a fully established bounded increment merges routinely" "${ELIGIBLE[@]}"

# The load-bearing guarantee: the parent is NOT closed by the child.
# `|| true` so a REGRESSION reports through the assertions below rather than
# aborting the suite under `set -e` with no diagnosis.
out="$(xr_merge_check "${ELIGIBLE[@]}")" || true
case "$out" in
  *"parent outcome: NOT closed and NOT satisfied"*) ok ;;
  *) bad "a routine merge must state that the parent outcome is neither closed nor satisfied" ;;
esac
case "$out" in
  *"release approval remains human-owned"*) ok ;;
  *) bad "a routine merge must restate that release approval stays human-owned" ;;
esac
# It must never claim the parent is advanced INTO completion.
case "$out" in
  *"closes the parent"*|*"parent satisfied"*|*"completes #"*)
    bad "a routine merge verdict must not claim parent completion" ;;
  *) ok ;;
esac

# --- negative control: attaching an arbitrary PR to a broad issue -----------
# #726 requires proof that reference alone creates nothing. The parent is cited
# but the child has no acceptance of its own, so there is nothing to satisfy.
vwithout "NOT ELIGIBLE" 4 "citing a broad parent without bounded acceptance does not merge" child-acceptance
vinstead "NOT ELIGIBLE" 4 "a whitespace-only bounded acceptance is not an acceptance" child-acceptance "   "

# --- negative control: an evidence-only PR ----------------------------------
# Acceptance exists and is cited, but is not TRUE on this HEAD. Moving evidence
# is not satisfying acceptance.
vinstead "NOT ELIGIBLE" 4 "bounded acceptance that is not true on HEAD does not merge" acceptance-true no
vwithout "NOT ELIGIBLE" 4 "an unset acceptance-true does not merge" acceptance-true

# UNKNOWN / NOT ASSESSED are never yes. This is the vocabulary the whole
# governance model rests on, so it is asserted rather than assumed.
vinstead "NOT ELIGIBLE" 4 "UNKNOWN acceptance does not merge" acceptance-true UNKNOWN
vinstead "NOT ELIGIBLE" 4 "NOT-ASSESSED acceptance does not merge" acceptance-true "NOT ASSESSED"
vinstead "NOT ELIGIBLE" 4 "'true' is not the affirming token" acceptance-true true
vinstead "NOT ELIGIBLE" 4 "'y' is not the affirming token" acceptance-true y
vinstead "NOT ELIGIBLE" 4 "'YES' is not the affirming token" acceptance-true YES

# --- negative control: #585 / relay cannot manufacture authority ------------
# #726 names this explicitly. #585 stops at governed close-out; a reviewer PASS
# is evidence, not permission; relay coordination moves work without granting.
vinstead "NOT ELIGIBLE" 4 "#585 cannot authorize a merge" parent-authorizes "#585 selected this writer"
vinstead "NOT ELIGIBLE" 4 "a relay handoff cannot authorize a merge" parent-authorizes "relay handoff 5555178239"
vinstead "NOT ELIGIBLE" 4 "orchestrator coordination cannot authorize a merge" parent-authorizes "external orchestrator coordination"
vinstead "NOT ELIGIBLE" 4 "a reviewer PASS cannot authorize a merge" parent-authorizes "#584 reviewer PASS on this HEAD"
vinstead "NOT ELIGIBLE" 4 "comment consensus cannot authorize a merge" parent-authorizes "consensus in the PR comment thread"

# The denylist must match whole words, not substrings — a real issue reference
# that merely CONTAINS one of those letters is a legitimate authorization.
vinstead "ROUTINE MERGE" 0 "an issue number containing 585 as a substring still authorizes" parent-authorizes "#1585 authorizes this bounded unit"
vinstead "ROUTINE MERGE" 0 "a word containing 'pass' as a substring still authorizes" parent-authorizes "#722 compasses this bounded work unit"

# --- negative control: missing parent authorization -------------------------
vwithout "NOT ELIGIBLE" 4 "no parent authorization does not merge" parent-authorizes
vinstead "NOT ELIGIBLE" 4 "whitespace parent authorization does not merge" parent-authorizes "  "

# --- the evidence conditions each stand alone -------------------------------
# Each must be individually load-bearing: dropping any ONE must decline, or the
# model would let a green-looking overall impression carry a missing gate.
vinstead "NOT ELIGIBLE" 4 "a failing independent review does not merge" review fail
vwithout "NOT ELIGIBLE" 4 "an absent review does not merge" review
vinstead "NOT ELIGIBLE" 4 "CHANGES REQUIRED does not merge" review "CHANGES REQUIRED"
vinstead "NOT ELIGIBLE" 4 "red checks do not merge" checks red
vwithout "NOT ELIGIBLE" 4 "absent checks do not merge" checks
vinstead "NOT ELIGIBLE" 4 "pending checks do not merge" checks pending
vinstead "NOT ELIGIBLE" 4 "an unprotected stale head does not merge" stale-head stale
vwithout "NOT ELIGIBLE" 4 "absent stale-head protection does not merge" stale-head
vinstead "NOT ELIGIBLE" 4 "a release act is not routine scope" scope release
vinstead "NOT ELIGIBLE" 4 "an irreversible action is not routine scope" scope irreversible
vwithout "NOT ELIGIBLE" 4 "absent scope does not merge" scope

# --- reserved boundaries still stop -----------------------------------------
# Green evidence never converts a human-owned decision into a routine merge.
verdict "DECISION REQUIRED" 3 "a named+cited reserved boundary stops even when all else is green" \
  "${ELIGIBLE[@]}" reserved-boundary="final release approval" surface="ADR-0019"
verdict "DECISION REQUIRED" 3 "a new authority grant stops" \
  "${ELIGIBLE[@]}" reserved-boundary="a write-capable deploy key" surface="AGENTS.md guardrails"

# Symmetry with xr_stop_check: an UNCITED boundary claim must not manufacture a
# stop — but here it must not grant eligibility either. It declines instead.
verdict "NOT ELIGIBLE" 4 "an uncited boundary claim neither stops nor merges" \
  "${ELIGIBLE[@]}" reserved-boundary="something feels reserved"
verdict "NOT ELIGIBLE" 4 "a whitespace surface does not cite a boundary" \
  "${ELIGIBLE[@]}" reserved-boundary="release policy" surface="   "
# A whitespace-only boundary is no boundary at all, so eligibility stands.
verdict "ROUTINE MERGE" 0 "a whitespace-only boundary claim does not block an established merge" \
  "${ELIGIBLE[@]}" reserved-boundary="   "

# --- input discipline: unknown fields fail closed ---------------------------
# A typo must never read as an unset field that some later edit defaults true.
verdict "NOT ELIGIBLE" 4 "an underscore typo in a field name is refused" \
  "${ELIGIBLE[@]}" acceptance_true=yes
verdict "NOT ELIGIBLE" 4 "an unknown field is refused" "${ELIGIBLE[@]}" merge=yes
verdict "NOT ELIGIBLE" 4 "a bare positional word is refused" "${ELIGIBLE[@]}" yes
verdict "NOT ELIGIBLE" 4 "no arguments at all is refused"

# --- the reason text must be actionable -------------------------------------
# A declined verdict that does not say WHICH condition is missing sends the
# agent back to re-read the model, which is how ceremony returns.
mk_without child-acceptance
case "$(xr_merge_check "${A[@]}" 2>&1)" in
  *"child-acceptance:"*) ok ;;
  *) bad "a decline must name the missing field" ;;
esac
mk_instead review fail
case "$(xr_merge_check "${A[@]}" 2>&1)" in
  *"review=pass"*) ok ;;
  *) bad "a decline must name the token it expected" ;;
esac
case "$(xr_merge_check "${A[@]}" 2>&1)" in
  *"got 'fail'"*) ok ;;
  *) bad "a decline must report the value it actually got" ;;
esac
mk_without acceptance-true
case "$(xr_merge_check "${A[@]}" 2>&1)" in
  *"<unset>"*) ok ;;
  *) bad "a decline must distinguish an unset field from a wrong value" ;;
esac
# The decline must not merely list the FIRST problem when several are missing.
# `|| true` because a declining verdict returns non-zero BY DESIGN, and under
# `set -e` an unguarded assignment would abort the suite instead of asserting.
multi="$(xr_merge_check parent-authorizes="#722" child-acceptance="x" 2>&1)" || true
for want in acceptance-true review=pass checks=green stale-head=protected scope=routine-reversible; do
  case "$multi" in
    *"$want"*) ok ;;
    *) bad "a decline must report every unestablished condition, missing '$want'" ;;
  esac
done

# --- the CLI wrapper agrees with the function -------------------------------
# The verb is the surface an agent actually calls; a wrapper that swallowed the
# exit code would make every decline look like permission.
rc=0; out="$(cmd_merge_authority "${ELIGIBLE[@]}" 2>&1)" || rc=$?
[ "$rc" = 0 ] && ok || bad "cmd_merge_authority must exit 0 on a routine merge (got $rc)"
case "$out" in "ROUTINE MERGE"*) ok ;; *) bad "cmd_merge_authority must echo the verdict" ;; esac

mk_instead acceptance-true no
rc=0; cmd_merge_authority "${A[@]}" >/dev/null 2>&1 || rc=$?
[ "$rc" = 4 ] && ok || bad "cmd_merge_authority must exit 4 when not eligible (got $rc)"

rc=0; cmd_merge_authority "${ELIGIBLE[@]}" reserved-boundary="release" surface="ADR-0019" >/dev/null 2>&1 || rc=$?
[ "$rc" = 3 ] && ok || bad "cmd_merge_authority must exit 3 at a reserved boundary (got $rc)"

# Help must not be mistaken for a verdict: it exits 0 like a routine merge, so
# it must not print one.
rc=0; out="$(cmd_merge_authority --help 2>&1)" || rc=$?
[ "$rc" = 0 ] && ok || bad "help must exit 0 (got $rc)"
case "$out" in *"ROUTINE MERGE"*"("*) ok ;; *) bad "help must document the verdicts" ;; esac
case "$(printf '%s\n' "$out" | head -1)" in
  "ROUTINE MERGE") bad "help must not emit a verdict as its first line" ;;
  *) ok ;;
esac
# A bare invocation must NOT share its exit code with ROUTINE MERGE. This
# fixture previously asserted rc 0 for the usage text, which enshrined exactly
# the hole it should have caught: a status-only caller would have read "no
# evidence supplied" as merge authority.
rc=0; out="$(cmd_merge_authority 2>&1)" || rc=$?
[ "$rc" = 4 ] && ok || bad "a bare invocation must exit 4, never 0 — 0 means ROUTINE MERGE (got $rc)"
case "$(printf '%s\n' "$out" | head -1)" in
  "NOT ELIGIBLE") ok ;;
  *) bad "a bare invocation must declare NOT ELIGIBLE, not print usage as if nothing were wrong" ;;
esac

# --- the verb is reachable through the dispatcher ---------------------------
# The classifier is worthless if `spark merge-authority` does not route to it.
spark_bin="$here/../plugins/spark/bin/spark"
rc=0; out="$("$spark_bin" merge-authority "${ELIGIBLE[@]}" 2>&1)" || rc=$?
[ "$rc" = 0 ] && ok || bad "the merge-authority verb must route through the dispatcher (rc $rc)"
case "$out" in "ROUTINE MERGE"*) ok ;; *) bad "the verb must emit the verdict; got: $(printf '%s' "$out" | head -1)" ;; esac
mk_instead checks red
rc=0; "$spark_bin" merge-authority "${A[@]}" >/dev/null 2>&1 || rc=$?
[ "$rc" = 4 ] && ok || bad "the verb must propagate the NOT ELIGIBLE exit code (got $rc)"
# The bare verb is the likeliest accidental call; it must never exit 0.
rc=0; "$spark_bin" merge-authority >/dev/null 2>&1 || rc=$?
[ "$rc" = 4 ] && ok || bad "the bare verb must exit 4, never 0 (got $rc)"
# Help is the one deliberate success path, and must not look like a verdict.
rc=0; out="$("$spark_bin" merge-authority --help 2>&1)" || rc=$?
[ "$rc" = 0 ] && ok || bad "the verb's --help must exit 0 (got $rc)"
case "$(printf '%s\n' "$out" | head -1)" in
  usage:*) ok ;;
  *) bad "the verb's --help must lead with usage, not a verdict" ;;
esac

# --- duplicate fields are refused, never last-write-wins --------------------
# Overwriting would let a non-affirming value be talked over by a later one:
# "review=fail review=pass" must not become eligible, and a trailing whitespace
# value must not erase a named reserved boundary.
verdict "NOT ELIGIBLE" 4 "a repeated review field is refused" \
  "${ELIGIBLE[@]}" review=pass
verdict "NOT ELIGIBLE" 4 "a failing value cannot be overwritten by a passing one" \
  "${ELIGIBLE[@]/review=pass/review=fail}" review=pass
verdict "NOT ELIGIBLE" 4 "a repeated acceptance-true is refused" \
  "${ELIGIBLE[@]}" acceptance-true=yes
verdict "NOT ELIGIBLE" 4 "a repeated parent-authorizes is refused" \
  "${ELIGIBLE[@]}" parent-authorizes="#722 again"
# A reserved boundary must not be erasable by a later empty value.
verdict "DECISION REQUIRED" 3 "a cited boundary stands on its own" \
  "${ELIGIBLE[@]}" reserved-boundary="release approval" surface="ADR-0019"
verdict "NOT ELIGIBLE" 4 "a second boundary value cannot erase the first" \
  "${ELIGIBLE[@]}" reserved-boundary="release approval" surface="ADR-0019" reserved-boundary=""
verdict "NOT ELIGIBLE" 4 "a second surface value cannot erase the citation" \
  "${ELIGIBLE[@]}" reserved-boundary="release approval" surface="ADR-0019" surface="   "
# The decline must say which field repeated, not merely that something did.
dupout="$(xr_merge_check "${ELIGIBLE[@]}" review=pass 2>&1)" || true
case "$dupout" in
  *"repeated field"*review*) ok ;;
  *) bad "a duplicate decline must name the repeated field" ;;
esac

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
