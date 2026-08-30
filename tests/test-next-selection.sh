#!/usr/bin/env bash
# Behavioral tests for `spark next` — deterministic next-work selection (#436).
#
# next_select is a pure function over evidence lines, so the whole selection
# POLICY is exercised offline here: no gh, no network, no fixtures on GitHub.
# The gathering half (which GitHub calls produce those lines) is deliberately
# not mocked — the policy is what has to be deterministic and auditable.
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

# sel <want-exit> <desc> <evidence> [needle ...]
sel() {
  local want="$1" desc="$2" ev="$3"; shift 3
  local out rc=0 needle
  out="$(printf '%s' "$ev" | next_select 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then bad "$desc — want exit $want, got $rc ($out)"; return 0; fi
  for needle in "$@"; do
    case "$out" in *"$needle"*) ;; *) bad "$desc — output lacks '$needle'"; return 0 ;; esac
  done
  ok
}

bash -n "$script" && ok || bad "bash -n spark"

# --- ORDER OUTRANKS PRIORITY (#611). This assertion is the inverse of what it
# was, and the inversion is the point: it used to prove "priority outranks
# explicit order", which is the defect. A recorded gate order is the delivery
# authority, so a P1 sitting first in it is selected ahead of a P0 sitting
# later — and the reason names which fact decided.
#
# The governance model already forbade the old behaviour:
#   separation  order  priority
#   Delivery order is never manufactured from priority
# With priority leading the sort, the only way an operator could correct a
# sequence was to relabel priorities — the exact distortion that rule prohibits.
sel 0 "the recorded gate order outranks priority" \
"issue	10	0	1	1	P1	0	first in order but P1
issue	11	1	1	1	P0	0	later in order but P0
" \
  "selected  #10" "priority  P1" "first in the gate's recorded delivery order"

# --- equal priority: the order still decides, and still says so.
sel 0 "explicit order decides a same-priority slate" \
"issue	21	1	1	1	P1	0	second
issue	20	0	1	1	P1	0	first
" \
  "selected  #20" "first in the gate's recorded delivery order"

# --- THE LIVE v0.23 CASE (#611 defect 2), reproduced exactly.
#
# Gate #480 governs v0.23 with a FLAT hierarchy: every issue is a direct child,
# every one carries a recorded order, so defect 1 cannot apply. The order encodes
# the operator-approved course, whose first phase is truth/ownership.
#
# #475 and #477 sit in that first phase and are P2. Everything in the later
# phases is P1. With priority leading the sort, both were surfaced AFTER the
# entire autonomous-loop and release-automation phases — inverting the approved
# course with a complete, correct order record sitting right there.
#
# The operator could not fix that without committing the offence the model
# forbids: relabelling #475/#477 to P1 to express sequence is precisely
# "distorting P0-P3 to express sequence". The only truthful repair was here.
sel 0 "a P2 earlier in the recorded order is selected ahead of a later P1" \
"ordercount	4
issue	475	1	1	1	P2	0	truth/ownership, second in the course
issue	616	5	1	1	P1	0	a later phase
issue	477	3	1	1	P2	0	truth/ownership, fourth in the course
issue	484	9	1	1	P1	0	a later phase still
" \
  "selected  #475" "priority  P2" \
  "order     2 of 4 in the gate sub-issue order" \
  "first in the gate's recorded delivery order"

# --- MUTATION CONTROL for the sort key.
#
# The assertion above is worthless unless the pre-#611 key would fail it. This
# takes the REAL function body and mutates only the sort-key line back to
# priority-first — not a hand-written replica of the old policy, because this
# codebase has already been bitten by a replica passing while the original was
# wrong (see priority_members). The issue number is field 3 of both key shapes,
# so `selected #N` is read identically either way; only the ranking differs.
mutant_src="$(declare -f next_select \
  | sed "s/printf '%03d|%s|%09d|%s' \"\$order\" \"\$prio\"/printf '%s|%03d|%09d|%s' \"\$prio\" \"\$order\"/")"
case "$mutant_src" in
  *"'%s|%03d|%09d|%s' \"\$prio\" \"\$order\""*) ok ;;
  *) bad "mutation control: could not rewrite the sort key — the control proves nothing" ;;
esac
eval "${mutant_src/next_select /next_select_mutant }"
mut_out="$(printf '%s' \
"ordercount	4
issue	475	1	1	1	P2	0	truth/ownership, second in the course
issue	616	5	1	1	P1	0	a later phase
issue	477	3	1	1	P2	0	truth/ownership, fourth in the course
issue	484	9	1	1	P1	0	a later phase still
" | next_select_mutant 2>&1)" || true
case "$mut_out" in
  *"selected  #475"*) bad "mutation control: priority-first ALSO selects #475 — the fixture proves nothing" ;;
  *"selected  #616"*) ok ;;
  *) bad "mutation control: priority-first selected something unexpected ($mut_out)" ;;
esac

# --- and where NO gate declares an order, priority ranking is unchanged and is
# still reported as the reason. Absence stays a valid answer, not a fallback.
sel 0 "with no gate, priority ranks and the reason says so" \
"ordernone	this milestone declares no release gate, so no explicit order exists
issue	200	-	1	1	P2	0	lower priority
issue	201	-	1	1	P0	0	higher priority
" \
  "selected  #201" "priority  P0" \
  "highest-priority eligible issue; no gate declares an order"

# --- an issue absent from an EXISTING order record sorts last, and the reason
# names that rather than implying the gate chose it.
sel 0 "an unordered issue under a gate is named as unordered" \
"ordercount	2
issue	300	-	1	1	P0	0	absent from the order
" \
  "selected  #300" "place it under the gate hierarchy" \
  "#300 is absent from the gate order"

# --- a higher-priority BLOCKED issue never outranks a lower-priority eligible
# one. This is the whole point of separating the two authorities.
sel 0 "a blocked P0 does not outrank an eligible P2" \
"issue	30	0	1	1	P0	1	blocked P0
issue	31	1	1	1	P2	0	eligible P2
" \
  "selected  #31" "priority  P2" "1 candidate(s) excluded as blocked"

# --- no explicit order anywhere: the documented stable fallback is issue
# number ascending, never an arbitrary pick.
sel 0 "unordered same-priority ties fall back to issue number" \
"issue	41	-	1	1	P1	0	higher number
issue	40	-	1	1	P1	0	lower number
" \
  "selected  #40" "order     not recorded"

# --- the order position counts places in the ORDER RECORD, not candidates
# left on the slate. Found the first time `spark next` ran for real: six of
# seven ordered issues had closed, so one candidate remained and the verb
# reported "order 5 of 1".
sel 0 "order position counts the order record, not the remaining slate" \
"ordercount	7
issue	437	4	1	1	P1	0	the only one left
" \
  "order     5 of 7 in the gate sub-issue order"

sel 0 "without an order count the total falls back to the slate size" \
"issue	10	0	1	1	P1	0	only candidate
" \
  "order     1 of 1 in the gate sub-issue order"

# --- metadata that is not mechanically interpretable NEVER yields a pick.
sel 3 "a missing category is not assessed" \
"issue	50	0	0	1	P1	0	no category
" \
  "carries 0 taxonomy category labels" "not mechanically interpretable"

sel 3 "two categories are not assessed" \
"issue	51	0	2	1	P1	0	two categories
" \
  "carries 2 taxonomy category labels"

# The diagnostic names the family, not a hard-coded set. With no priofamily
# record it falls back to the generic word rather than inventing P0-P3, which
# would be a second copy of a rule the schema owns.
sel 3 "a missing priority is not assessed" \
"issue	52	0	1	0	-	0	no priority
" \
  "carries 0 priority labels"

sel 3 "two priorities are not assessed" \
"issue	53	0	1	2	P1	0	two priorities
" \
  "carries 2 priority labels"

# --- OPTIONAL PRIORITY STAYS OPTIONAL (#611).
#
# The model declares two different facts in two different columns:
#   family  priority  exactly-one  optional
# `exactly-one` is cardinality; `optional` is requirement. The selector read the
# first and ignored the second, so an issue with NO priority was reported as
# uninterpretable — and since one uninterpretable issue correctly poisons the
# whole slate, a single unprioritised issue made an entire milestone NOT
# ASSESSED. Live v0.23 was in exactly that state: #611 and #615 carry no
# priority, so nothing anywhere in the milestone could be selected.
#
# The only way out was to invent a priority to unblock the tool, which is the
# distortion `separation order priority` exists to prevent.
sel 0 "an unprioritised issue is selectable where the model says optional" \
"prioreq	optional
ordercount	2
issue	611	0	1	0	99:-	0	no priority, first in the order
issue	616	1	1	1	01:P1	0	P1, second in the order
" \
  "selected  #611" "none recorded (the model makes it optional)" \
  "first in the gate's recorded delivery order"

# ...and it is still ranked, not merely admitted: with no order to decide, a
# prioritised issue outranks an unprioritised one rather than the reverse.
sel 0 "an unprioritised issue does not outrank a prioritised one" \
"prioreq	optional
ordernone	this milestone declares no release gate, so no explicit order exists
issue	620	-	1	0	99:-	0	no priority
issue	621	-	1	1	01:P1	0	P1
" \
  "selected  #621"

# --- REQUIREMENT IS NOT RELAXED BY SILENCE. Absent `prioreq` evidence, the
# policy still demands a priority: assuming optional would quietly loosen a
# constraint a project may depend on, and the gatherer saying nothing is not
# the model saying optional.
sel 3 "with no requirement evidence, a missing priority is still not assessed" \
"issue	630	0	1	0	-	0	no priority, no prioreq line
" \
  "carries 0 priority labels"

# --- and `optional` never licenses TWO. Cardinality is the other column.
sel 3 "optional does not permit two priorities" \
"prioreq	optional
issue	640	0	1	2	P1	0	two priorities
" \
  "carries 2 priority labels — at most one is allowed"

# --- MUTATION CONTROL for the optional-priority repair. Restoring the strict
# `prios != 1` test must make the live-shaped fixture fail, or the fixture above
# proves nothing. Again the REAL body, mutated, not a replica.
optmut_src="$(declare -f next_select \
  | sed 's/if \[ "\$prios" != "1" \] && \[ "\$priooptional" != "1" \]; then/if [ "$prios" != "1" ]; then/')"
case "$optmut_src" in
  *'if [ "$prios" != "1" ]; then'*) ok ;;
  *) bad "mutation control: could not restore the strict priority test" ;;
esac
eval "${optmut_src/next_select /next_select_optmutant }"
optmut_out="$(printf '%s' \
"prioreq	optional
ordercount	2
issue	611	0	1	0	99:-	0	no priority, first in the order
issue	616	1	1	1	01:P1	0	P1, second in the order
" | next_select_optmutant 2>&1)" || true
case "$optmut_out" in
  *"selected  #611"*) bad "mutation control: the strict test ALSO selects #611 — the fixture proves nothing" ;;
  *"not mechanically interpretable"*) ok ;;
  *) bad "mutation control: strict priority gave an unexpected result ($optmut_out)" ;;
esac

# ...and when the evidence carries the resolved family, the diagnostic uses it.
# A project that renames or extends the family is told what IT declared, not
# what the shipped default happens to be.
sel 3 "the diagnostic names the resolved family and its members" \
"priofamily	stage	top urgent, later on
issue	54	0	1	2	top urgent	0	two priorities
" \
  "carries 2 stage (top urgent, later on) labels"

# --- one uninterpretable issue poisons the whole slate: selecting around it
# would be picking from a set we cannot fully read.
sel 3 "one bad issue blocks selection from the whole slate" \
"issue	60	0	1	1	P0	0	perfectly fine
issue	61	1	0	1	P1	0	broken metadata
" \
  "#61 carries 0 taxonomy category labels"

# --- unreadable blockers are never assumed clear.
sel 3 "unreadable native blockers are not assessed" \
"issue	70	0	1	1	P1	?	blockers unreadable
" \
  "could not be read — never assumed clear"

sel 3 "malformed blocker evidence is not assessed" \
"issue	71	0	1	1	P1	yes	garbage
" \
  "blocker evidence is unreadable"

# --- a dependency cycle never yields a selection.
sel 3 "a dependency cycle is not assessed" \
"cycle	80	80 -> 81 -> 80
issue	80	0	1	1	P1	1	in a cycle
issue	81	1	1	1	P1	1	in a cycle
" \
  "dependency cycle through #80" "break the cycle"

# --- an order record that does not exist is drift, not a silent default.
sel 3 "a missing delivery-order record is not assessed" \
"orderdrift	is missing	no issue in this milestone carries sub-issues, so no explicit order exists
issue	90	-	1	1	P1	0	fine otherwise
" \
  "delivery-order record is missing"

# --- KNOWN NONE is not UNKNOWN. Everything blocked is a determinate answer
# and must not masquerade as "could not tell" (the invariant #488 names).
sel 1 "everything blocked is a known answer, not an unassessed one" \
"issue	100	0	1	1	P0	2	blocked
issue	101	1	1	1	P1	1	blocked
" \
  "no eligible issue: every candidate is blocked" \
  "#100 (P0) — blocked by 2 open prerequisite(s)" \
  "This is a known answer, not an unassessed one"

sel 1 "an empty milestone is a known answer" \
"" \
  "no open leaf issues"

# --- the zd-dns dogfood fixture (#436). Hard graph and preferred order are
# independent: every leaf is P1 except B, and the ORDER is what sequences
# them. The selector must walk A -> B -> C -> D -> E -> F as prerequisites
# close, never inventing an edge and never reading order from prose.
#
#   A []        P1      order 0
#   B [A]       P0      order 1
#   C [A]       P1      order 2
#   D [C]       P1      order 3
#   E [B]       P1      order 4
#   F [C,E]     P1      order 5
# A closed issue LEAVES the open slate; it does not linger as "unblocked".
# Each step below is the real open set at that moment, which is what the
# gatherer would hand the policy.

# Step 1 — nothing done: only A has no open prerequisite.
sel 0 "dogfood step 1 selects A" \
"issue	1	0	1	1	P1	0	A
issue	2	1	1	1	P0	1	B
issue	3	2	1	1	P1	1	C
issue	4	3	1	1	P1	1	D
issue	5	4	1	1	P1	1	E
issue	6	5	1	1	P1	2	F
" \
  "selected  #1" "priority  P1"

# Step 2 — A closed: B and C unblock together. B is next in the recorded order
# AND the higher priority, so both authorities agree; the order is the one that
# decides, and the reason says so. (Before #611 this case was described as
# priority deciding — it read as agreement only because the two never disagreed
# in this fixture. The disagreement case is the flat-gate fixture below.)
sel 0 "dogfood step 2 selects B, next in the order" \
"issue	2	1	1	1	P0	0	B
issue	3	2	1	1	P1	0	C
issue	4	3	1	1	P1	1	D
issue	5	4	1	1	P1	1	E
issue	6	5	1	1	P1	2	F
" \
  "selected  #2" "priority  P0"

# Step 3 — B closed: C and E are both eligible and both P1. Only the explicit
# sub-issue order can decide, and it must pick C.
sel 0 "dogfood step 3 selects C on order" \
"issue	3	2	1	1	P1	0	C
issue	4	3	1	1	P1	1	D
issue	5	4	1	1	P1	0	E
issue	6	5	1	1	P1	1	F
" \
  "selected  #3" "first in the gate's recorded delivery order"

# Step 4 — C closed: D and E eligible, both P1; order picks D.
sel 0 "dogfood step 4 selects D on order" \
"issue	4	3	1	1	P1	0	D
issue	5	4	1	1	P1	0	E
issue	6	5	1	1	P1	1	F
" \
  "selected  #4" "first in the gate's recorded delivery order"

# Step 5 — D closed: E is eligible, F still waits on E.
sel 0 "dogfood step 5 selects E" \
"issue	5	4	1	1	P1	0	E
issue	6	5	1	1	P1	1	F
" \
  "selected  #5"

# Step 6 — E closed: F last.
sel 0 "dogfood step 6 selects F last" \
"issue	6	5	1	1	P1	0	F
" \
  "selected  #6"

# --- the gate itself is never selected: it is excluded before next_select
# ever sees it, so a slate of only-the-gate is "no open leaf issues".
sel 1 "a milestone of only the gate has no leaf to select" "" "no open leaf issues"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
