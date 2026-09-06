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

# sel_absent <desc> <evidence> <needle-that-must-NOT-appear> ...
# The discriminating half of a reason assertion: a message can name the right
# authority and still smuggle a false one alongside it, so the guard that a
# wrong claim is gone is asserted directly, not inferred from a positive match.
sel_absent() {
  local desc="$1" ev="$2"; shift 2
  local out rc=0 needle
  out="$(printf '%s' "$ev" | next_select 2>&1)" || rc=$?
  for needle in "$@"; do
    case "$out" in *"$needle"*) bad "$desc — output wrongly contains '$needle'"; return 0 ;; esac
  done
  ok
}

bash -n "$script" && ok || bad "bash -n spark"

# --- THE AUTHORITATIVE ORDER OUTRANKS PRIORITY (#611).
#
# This assertion is INVERTED from what it asserted before. The model declares
# the release gate's sub-issue order the delivery-order authority and separately
# declares that delivery order is never manufactured from priority. Ranking
# priority-first honoured neither: a P2 recorded second was delivered after every
# P1, so the recorded course was reported as followed while being inverted, and
# the operator's only correction was to distort P0-P3 to express sequence.
#
# A P1 recorded first is now selected ahead of a P0 recorded second.
sel 0 "the recorded order outranks priority" \
"issue	10	0	1	1	P1	0	first in order but P1
issue	11	1	1	1	P0	0	later in order but P0
" \
  "selected  #10" "priority  P1" "first eligible issue in the release-gate sub-issue order" \
  "priority did not override it"

# --- equal priority: the recorded order still decides, and says so.
sel 0 "explicit order decides a same-priority pair" \
"issue	21	1	1	1	P1	0	second
issue	20	0	1	1	P1	0	first
" \
  "selected  #20" "first eligible issue in the release-gate sub-issue order"

# --- priority is the GOVERNED FALLBACK, not a second sequencing authority: it
# ranks only work the order does not position. Both issues are absent from the
# record, so nothing about their sequence is recorded and priority decides.
sel 0 "priority ranks only work the order does not position" \
"issue	22	-	1	1	P1	0	unordered P1
issue	23	-	1	1	P0	0	unordered P0
" \
  "selected  #23" "priority  P0" "no eligible issue carries a recorded position" \
  "ranked by priority among unordered work"

# --- a positioned issue always precedes an unpositioned one, whatever its
# priority: 999 sorts after every real position.
sel 0 "a positioned P2 precedes an unpositioned P0" \
"issue	24	-	1	1	P0	0	unpositioned P0
issue	25	3	1	1	P2	0	positioned P2
" \
  "selected  #25" "in the gate sub-issue order"

# --- with NO gate there is no order to follow, so priority ranks the slate.
# Absence is a known, valid state, not a fallback from a failure.
sel 0 "priority ranks when the milestone declares no gate" \
"ordernone	this milestone declares no release gate, so no explicit order exists
issue	26	-	1	1	P1	0	P1
issue	27	-	1	1	P0	0	P0
" \
  "selected  #27" "highest-priority eligible issue" "ranked by priority"

# --- #622: with NO gate, an equal top-priority tie is broken by the
# deterministic issue-number fallback, NOT by an explicit order the milestone
# declares absent. The reason must name the fallback that actually decided and
# must not credit an authority its own note reports does not exist.
sel 0 "no gate, equal-priority tie names the issue-number fallback" \
"ordernone	this milestone declares no release gate, so no explicit order exists
issue	11	-	1	1	P0	0	second
issue	10	-	1	1	P0	0	first
" \
  "selected  #10" "highest-priority eligible issue" \
  "the lowest issue number broke the P0 tie"
sel_absent "no gate, equal-priority tie never credits an absent order" \
"ordernone	this milestone declares no release gate, so no explicit order exists
issue	11	-	1	1	P0	0	second
issue	10	-	1	1	P0	0	first
" \
  "explicit sub-issue order broke"

# --- #622: with NO gate and UNEQUAL priority, priority alone decides — no tie
# remained, so no tiebreak clause is claimed at all.
sel 0 "no gate, unequal priority names priority as the sole authority" \
"ordernone	this milestone declares no release gate, so no explicit order exists
issue	10	-	1	1	P0	0	winner
issue	11	-	1	1	P1	0	loser
" \
  "selected  #10" "highest-priority eligible issue"
sel_absent "no gate, unequal priority claims no tiebreak" \
"ordernone	this milestone declares no release gate, so no explicit order exists
issue	10	-	1	1	P0	0	winner
issue	11	-	1	1	P1	0	loser
" \
  "broke the"

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
  "selected  #40" "order     not recorded" \
  "no eligible issue carries a recorded position" \
  "the lowest issue number broke the P1 tie"

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

# --- A MISSING OPTIONAL PRIORITY IS NOT A GAP (#611).
#
# Cardinality and requiredness are two facts. `exactly-one` bounds how many
# labels may be carried; `required`/`optional` says whether one must be. Reading
# them as one rule made a single unlabelled issue poison the WHOLE slate — every
# other issue in the milestone became unselectable — so the operator's only
# route to a selection was to invent a priority, manufacturing the very fact the
# model calls optional to satisfy a rule it never stated.
sel 0 "a missing priority is selectable when the family is optional" \
"priofamily	priority	P0, P1, P2, P3	optional
issue	52	0	1	0	-	0	no priority
" \
  "selected  #52" "priority  not recorded (optional)"

# ...and where the model DOES declare the family required, absence is still a
# gap. The rule is the model's, read from the evidence, not a constant here.
sel 3 "a missing priority is not assessed when the family is required" \
"priofamily	priority	P0, P1, P2, P3	required
issue	52	0	1	0	-	0	no priority
" \
  "carries no priority (P0, P1, P2, P3) label" "the model declares this family required"

# With no priofamily record at all, requiredness is unknown and is NOT assumed
# to be required — absence of evidence never becomes a gap. The diagnostic still
# falls back to the generic word rather than inventing P0-P3.
sel 0 "an unknown requiredness does not manufacture a gap" \
"issue	52	0	1	0	-	0	no priority
" \
  "selected  #52"

# Cardinality is still enforced: `exactly-one` means at most one may be carried,
# and two remains mechanically wrong whatever the requiredness says.
sel 3 "two priorities are not assessed" \
"issue	53	0	1	2	P1	0	two priorities
" \
  "carries 2 priority labels" "at most one is allowed"

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

# Step 2 — A closed: B and C unblock together. B is P0, so priority decides,
# NOT the order (B happens to be next in order too, but priority is the reason).
sel 0 "dogfood step 2 selects B on priority" \
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
  "selected  #3" "first eligible issue in the release-gate sub-issue order"

# Step 4 — C closed: D and E eligible, both P1; order picks D.
sel 0 "dogfood step 4 selects D on order" \
"issue	4	3	1	1	P1	0	D
issue	5	4	1	1	P1	0	E
issue	6	5	1	1	P1	1	F
" \
  "selected  #4" "first eligible issue in the release-gate sub-issue order"

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

finish
