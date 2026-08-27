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

# --- priority outranks order: P0 wins even when it sits later in the list.
sel 0 "priority outranks explicit order" \
"issue	10	0	1	1	P1	0	first in order but P1
issue	11	1	1	1	P0	0	later in order but P0
" \
  "selected  #11" "priority  P0"

# --- equal priority: the explicit sub-issue order breaks the tie.
sel 0 "explicit order breaks a same-priority tie" \
"issue	21	1	1	1	P1	0	second
issue	20	0	1	1	P1	0	first
" \
  "selected  #20" "the explicit sub-issue order broke the P1 tie"

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

# --- metadata that is not mechanically interpretable NEVER yields a pick.
sel 3 "a missing category is not assessed" \
"issue	50	0	0	1	P1	0	no category
" \
  "carries 0 taxonomy category labels" "not mechanically interpretable"

sel 3 "two categories are not assessed" \
"issue	51	0	2	1	P1	0	two categories
" \
  "carries 2 taxonomy category labels"

sel 3 "a missing priority is not assessed" \
"issue	52	0	1	0	-	0	no priority
" \
  "carries 0 P0-P3 labels"

sel 3 "two priorities are not assessed" \
"issue	53	0	1	2	P1	0	two priorities
" \
  "carries 2 P0-P3 labels"

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
  "selected  #3" "broke the P1 tie"

# Step 4 — C closed: D and E eligible, both P1; order picks D.
sel 0 "dogfood step 4 selects D on order" \
"issue	4	3	1	1	P1	0	D
issue	5	4	1	1	P1	0	E
issue	6	5	1	1	P1	1	F
" \
  "selected  #4" "broke the P1 tie"

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
