#!/usr/bin/env bash
# Behavioural suite for #611 — `spark next` must follow the authoritative
# release-gate order.
#
# Two independent defects, proved independently here:
#
#   1. NESTED ORDER LOSS. `suborder_of` listed only the gate's DIRECT children,
#      so a selectable leaf beneath an ordinary container under the gate had no
#      position at all. The gate validator calls that hierarchy valid, so a
#      correctly scoped milestone could be delivered in an order nobody
#      recorded — and the remediation the verb printed asked the operator to
#      reparent the leaf directly onto the gate, flattening a valid shape.
#
#   2. PRIORITY OVERRODE THE ORDER, WITH NO NESTING INVOLVED. The sort key
#      ranked priority ahead of the recorded position, so a P2 sitting second in
#      a flat, complete order record was delivered after every P1. The model
#      declares the gate's sub-issue order the delivery-order authority AND
#      declares that delivery order is never manufactured from priority; ranking
#      priority-first honoured neither, and the operator's only correction was to
#      distort P0-P3 to express sequence — the act the model forbids.
#
# MUTATION CONTROLS ARE EXECUTABLE, not described. Each defect is reintroduced
# by a single surgical edit to a COPY OF THE REAL SCRIPT, which is then sourced
# and re-run. A replica of the code under test would pass while the original was
# wrong, which is how the original defect survived a suite that claimed the
# consumers agreed — so nothing here re-implements what it is checking.
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

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

# --- snapshot fixtures -------------------------------------------------------
#
# `suborder_of` consumes the milestone SNAPSHOT (the TSV projection), so the
# fixtures are written in that shape directly. `sub <title> <parent> <child>`
# rows carry the declared order; `container` rows are emitted for OPEN parents
# only, which is exactly the asymmetry defect 1 hid behind.

MS='v9.9'

# Flat: the gate carries four leaves itself.
FLAT="$(printf 'sub\t%s\t900\t10\nsub\t%s\t900\t11\nsub\t%s\t900\t12\nsub\t%s\t900\t13\n' \
  "$MS" "$MS" "$MS" "$MS")"

# Nested: gate → two ordinary containers → two leaves each. The containers are
# open, so they carry `container` rows too.
NESTED="$(printf 'sub\t%s\t900\t800\nsub\t%s\t900\t801\nsub\t%s\t800\t10\nsub\t%s\t800\t11\nsub\t%s\t801\t12\nsub\t%s\t801\t13\ncontainer\t%s\t800\ncontainer\t%s\t801\n' \
  "$MS" "$MS" "$MS" "$MS" "$MS" "$MS" "$MS" "$MS")"

# Mixed: a leaf, then a container, then another leaf — proves a container takes
# the position it sat in rather than being appended.
MIXED="$(printf 'sub\t%s\t900\t10\nsub\t%s\t900\t800\nsub\t%s\t900\t13\nsub\t%s\t800\t11\nsub\t%s\t800\t12\ncontainer\t%s\t800\n' \
  "$MS" "$MS" "$MS" "$MS" "$MS" "$MS")"

# A CLOSED container: no `container` row is emitted for it, because that row is
# open-only. Parenthood must therefore come from the `sub` rows, or every child
# beneath a closed container is stranded — the same order loss by another door.
CLOSED_PARENT="$(printf 'sub\t%s\t900\t800\nsub\t%s\t900\t13\nsub\t%s\t800\t11\nsub\t%s\t800\t12\n' \
  "$MS" "$MS" "$MS" "$MS")"

# A hierarchy that reaches itself. There is no delivery order in a cycle; the
# projection must stop rather than loop.
CYCLIC="$(printf 'sub\t%s\t900\t800\nsub\t%s\t800\t801\nsub\t%s\t801\t800\nsub\t%s\t801\t14\n' \
  "$MS" "$MS" "$MS" "$MS")"

flat_out="$(suborder_of "$FLAT" "$MS" 900 | tr '\n' ' ' | sed 's/ $//')"
assert_eq "flat: direct children keep their declared order" "10 11 12 13" "$flat_out"

nested_out="$(suborder_of "$NESTED" "$MS" 900 | tr '\n' ' ' | sed 's/ $//')"
assert_eq "nested: leaves project in preorder through containers" "10 11 12 13" "$nested_out"

mixed_out="$(suborder_of "$MIXED" "$MS" 900 | tr '\n' ' ' | sed 's/ $//')"
assert_eq "mixed: a container occupies the position it sat in" "10 11 12 13" "$mixed_out"

closed_out="$(suborder_of "$CLOSED_PARENT" "$MS" 900 | tr '\n' ' ' | sed 's/ $//')"
assert_eq "a CLOSED container still projects its children" "11 12 13" "$closed_out"

# Containers are structure, not work: none of them may appear as a position.
case "$nested_out" in
  *800*|*801*) bad "a container was offered as selectable work" ;;
  *) ok ;;
esac

# Termination, and no invented sequence: the cycle must not hang or duplicate.
cyc_out="$(suborder_of "$CYCLIC" "$MS" 900 | tr '\n' ' ' | sed 's/ $//')"
assert_eq "a cyclic hierarchy terminates without looping" "14" "$cyc_out"

# STABILITY. Wrapping 11 and 12 in a container must not renumber 10 or 13.
assert_eq "wrapping work in a container does not renumber its siblings" \
  "$flat_out" "$mixed_out"

# An unknown gate has no order, and that is a known answer rather than an error.
assert_eq "a gate with no sub-issues yields an empty order" "" \
  "$(suborder_of "$FLAT" "$MS" 555 | tr -d '\n')"

# --- the flat order-over-priority contract, end to end -----------------------
#
# This is the live v0.23 shape reduced to its essentials: a complete, flat,
# valid order record in which a P2 sits EARLIER than a P1. #475/#477 are P2 and
# sit in positions 2 and 4 of gate #480's order, while every later phase is P1.
sel_out() { printf '%s' "$1" | next_select 2>&1; }

FLAT_EV="issue	474	0	1	1	01:P0	0	ownership contract
issue	475	1	1	1	03:P2	0	remove chronology
issue	574	2	1	1	02:P1	0	observability
"
out="$(sel_out "$FLAT_EV")"
case "$out" in *"selected  #474"*) ok ;; *) bad "flat: P0 first in order is selected — got: $out" ;; esac

# With 474 closed, the recorded order says 475 — a P2 — comes before the P1.
FLAT_EV2="issue	475	1	1	1	03:P2	0	remove chronology
issue	574	2	1	1	02:P1	0	observability
"
out2="$(sel_out "$FLAT_EV2")"
case "$out2" in
  *"selected  #475"*) ok ;;
  *) bad "flat: a P2 recorded earlier must precede a P1 recorded later — got: $out2" ;;
esac
case "$out2" in
  *"first eligible issue in the release-gate sub-issue order"*) ok ;;
  *) bad "flat: the reason must name the order as the deciding authority" ;;
esac
case "$out2" in
  *"priority did not override it"*) ok ;;
  *) bad "flat: the reason must state that priority did not override the order" ;;
esac

# Eligibility still comes from native blocked-by, ahead of both authorities: an
# earlier position never promotes blocked work.
BLOCKED_EV="issue	475	1	1	1	03:P2	1	blocked but earlier
issue	574	2	1	1	02:P1	0	later but eligible
"
outb="$(sel_out "$BLOCKED_EV")"
case "$outb" in
  *"selected  #574"*) ok ;;
  *) bad "blocked-by outranks the recorded order — got: $outb" ;;
esac

# --- mutation control 1: nested order loss -----------------------------------
#
# Reintroduce direct-children-only projection by removing the recursion, on a
# copy of the real script. The nested fixture must then fail.
mutant1="$WORK/mutant-nested.sh"
sed 's|if (isparent\[c\]) walk(c); else print c|print c|' "$script" > "$mutant1"
if ! cmp -s "$script" "$mutant1"; then ok; else bad "mutation 1 changed nothing — the control proves nothing"; fi

m1_out="$(bash -c '. "$1" >/dev/null 2>&1; suborder_of "$2" "$3" 900 | tr "\n" " "' \
  _ "$mutant1" "$NESTED" "$MS" 2>/dev/null | sed 's/ $//')"
# The EXACT defective answer, not merely "something different". Asserting
# inequality alone would also pass if the mutant failed to source at all, which
# is a control that proves nothing: the two containers are what direct-child-only
# projection returns, and every real leaf is missing from it.
assert_eq "mutation 1: direct-child-only projection returns the containers, not the leaves" \
  "800 801" "$m1_out"

# --- mutation control 2: priority overrides order ----------------------------
#
# Restore the priority-first sort key, again on a copy of the real script. The
# flat fixture must then select the P1 over the earlier-positioned P2.
mutant2="$WORK/mutant-priority.sh"
# `%` as the delimiter: the key itself is `|`-separated, so `|` cannot be one.
sed 's%cand="${cand}${rorder}|${rprio}|${rnum}|%cand="${cand}${rprio}|${rorder}|${rnum}|%' \
  "$script" > "$mutant2"
if ! cmp -s "$script" "$mutant2"; then ok; else bad "mutation 2 changed nothing — the control proves nothing"; fi

m2_out="$(bash -c '. "$1" >/dev/null 2>&1; printf "%s" "$2" | next_select 2>&1' \
  _ "$mutant2" "$FLAT_EV2" 2>/dev/null)"
case "$m2_out" in
  *"selected  #574"*) ok ;;
  *) bad "mutation 2: priority-first ranking did not select the later P1 — the flat assertion does not discriminate (got: $m2_out)" ;;
esac

finish
