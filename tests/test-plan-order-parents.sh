#!/usr/bin/env bash
# Behavioural suite for #518: preferred order is scoped to a parent.
#
# Placement used one global `prev`, so with two independent hierarchies the
# second parent's first child was handed an `after_id` belonging to a child of
# the FIRST parent. GitHub cannot place a sub-issue after a child outside that
# parent, so a valid multi-parent plan created and wired its remote state,
# ordered the first group, and then failed part-way through the second.
#
# Positions were also unique globally, so two independent gates could not each
# declare a first child — an artifact format that supports multiple milestones
# and hierarchies could not express their order.
#
# Measured discrimination, not asserted. Of the 20 assertions: restoring the
# global `prev` turns 2 red — reporting the leak verbatim, "B under P2 has
# after_id A2, which is not its sibling" — and restoring the global position
# check turns 5, starting with the valid two-gate artifact being refused.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
SCRIPT="$WORK/plugin/skills/plan/scripts/issue-manifest.sh"
. "$SCRIPT" 2>/dev/null || true
set +e

T="$(printf '\t')"
work="$WORK/w"; mkdir -p "$work"
B="$work/b.md"; echo body > "$B"

man() { local f="$work/m.tsv"; printf '%s\n' "$@" > "$f"; printf '%s' "$f"; }

# Two gates, two children each. This is the shape the issue reports, widened to
# multiple children per parent so the WITHIN-parent chain is also exercised.
ART=(
  "issue${T}P1${T}First gate${T}feature${T}${T}$B"
  "issue${T}A${T}First child${T}feature${T}${T}$B"
  "issue${T}A2${T}First gate second child${T}feature${T}${T}$B"
  "issue${T}P2${T}Second gate${T}feature${T}${T}$B"
  "issue${T}B${T}Second child${T}feature${T}${T}$B"
  "issue${T}B2${T}Second gate second child${T}feature${T}${T}$B"
  "subissue${T}P1${T}A"
  "subissue${T}P1${T}A2"
  "subissue${T}P2${T}B"
  "subissue${T}P2${T}B2"
  "order${T}A${T}1"
  "order${T}A2${T}2"
  "order${T}B${T}1"
  "order${T}B2${T}2"
)

# ============ two gates may each declare a first child =====================
# Globally unique positions made this artifact invalid, so the format could not
# represent what it was designed to represent.
rc=0; out="$(im_validate "$(man "${ART[@]}")" 2>&1)" || rc=$?
assert_rc "two parents may each have a child at position 1" 0 "$rc"
assert_eq "with no findings at all" "" "$out"

# ...while a duplicate WITHIN one parent is still refused, or the relaxation
# above would have removed the check rather than scoped it.
rc=0; out="$(im_validate "$(man \
  "issue${T}P1${T}Gate${T}feature${T}${T}$B" \
  "issue${T}A${T}One${T}feature${T}${T}$B" \
  "issue${T}A2${T}Two${T}feature${T}${T}$B" \
  "subissue${T}P1${T}A" \
  "subissue${T}P1${T}A2" \
  "order${T}A${T}1" \
  "order${T}A2${T}1")" 2>&1)" || rc=$?
assert_rc "a duplicate position under ONE parent is refused" 1 "$rc"
assert_contains "naming the position" "duplicate order position 1" "$out"
assert_contains "and the parent it is under" "under parent P1" "$out"

# An unattached pair is its own scope, not an exemption: unplaceable records are
# reported at plan time, but two of them claiming one position is still wrong.
rc=0; out="$(im_validate "$(man \
  "issue${T}A${T}One${T}feature${T}${T}$B" \
  "issue${T}B${T}Two${T}feature${T}${T}$B" \
  "order${T}A${T}1" \
  "order${T}B${T}1")" 2>&1)" || rc=$?
assert_rc "two unattached refs cannot share a position either" 1 "$rc"
assert_contains "and it says neither is attached" "neither is a sub-issue" "$out"

# ============ an undecidable order parent is refused =======================
rc=0; out="$(im_validate "$(man \
  "issue${T}P1${T}Gate one${T}feature${T}${T}$B" \
  "issue${T}P2${T}Gate two${T}feature${T}${T}$B" \
  "issue${T}A${T}Shared child${T}feature${T}${T}$B" \
  "subissue${T}P1${T}A" \
  "subissue${T}P2${T}A" \
  "order${T}A${T}1")" 2>&1)" || rc=$?
assert_rc "a child under two parents cannot be ordered" 1 "$rc"
assert_contains "and says why" "order parent cannot be determined" "$out"
assert_contains "naming both parents" "P1" "$out"
# Two parents, but NO order record: still a legal artifact. The ambiguity is
# about ordering, not about hierarchy.
rc=0; out="$(im_validate "$(man \
  "issue${T}P1${T}Gate one${T}feature${T}${T}$B" \
  "issue${T}P2${T}Gate two${T}feature${T}${T}$B" \
  "issue${T}A${T}Shared child${T}feature${T}${T}$B" \
  "subissue${T}P1${T}A" \
  "subissue${T}P2${T}A")" 2>&1)" || rc=$?
assert_rc "a child under two parents is fine when nothing orders it" 0 "$rc"

# ============ every after_id stays inside its parent =======================
# The criterion that names the defect. Each emitted order action is
# order<US>parent<US>child<US>position<US>after.
pending="$(im_pending "$(man "${ART[@]}")" "")"
US="$(printf '\037')"
rows="$(printf '%s\n' "$pending" | awk -F"$US" '$1 == "order" { print }')"
assert_eq "one order action per ordered child" 4 \
  "$(printf '%s\n' "$rows" | grep -c . || true)"

# Build parent -> children from the artifact, then require every after to be a
# child of the SAME parent as the row it appears on.
leak="$(printf '%s\n' "$rows" | awk -F"$US" '
    BEGIN {
      kid["P1"] = " A A2 "; kid["P2"] = " B B2 "
    }
    {
      p = $2; c = $3; after = $5
      if (after == "") next
      if (index(kid[p], " " after " ") == 0)
        printf "%s under %s has after_id %s, which is not its sibling\n", c, p, after
    }')"
assert_eq "no after_id crosses a parent boundary" "" "$leak"

# The chain must RESET, not merely avoid crossing: each parent's first child has
# an empty after, and its later children follow the previous sibling.
firsts="$(printf '%s\n' "$rows" | awk -F"$US" '$4 == 1 { print $2 ":" ($5 == "" ? "empty" : $5) }' | LC_ALL=C sort | paste -sd, -)"
assert_eq "each parent's first child is placed first" "P1:empty,P2:empty" "$firsts"
seconds="$(printf '%s\n' "$rows" | awk -F"$US" '$4 == 2 { print $2 ":" $5 }' | LC_ALL=C sort | paste -sd, -)"
assert_eq "and each second child follows its own sibling" "P1:A,P2:B" "$seconds"

# Grouped emission: a parent's rows must be contiguous and ascending, because
# each placement references the sibling placed immediately before it.
seq="$(printf '%s\n' "$rows" | awk -F"$US" '{ printf "%s%s/%s", s, $2, $4; s = " " }')"
case "$seq" in
  "P1/1 P1/2 P2/1 P2/2"|"P2/1 P2/2 P1/1 P1/2") ok ;;
  *) bad "order actions are not grouped by parent in ascending position: $seq" ;;
esac

# ============ an unattached order record is still reported =================
pending="$(im_pending "$(man \
  "issue${T}A${T}One${T}feature${T}${T}$B" \
  "order${T}A${T}1")" "")"
assert_contains "an unattached ordered ref is unplaceable, not silently dropped" \
  "order-unplaceable" "$pending"
# ...and it must not be emitted as a placement as well.
assert_eq "and produces no order action" 0 \
  "$(printf '%s\n' "$pending" | awk -F"$US" '$1 == "order"' | grep -c . || true)"

# ============ the dry-run plan an operator reads =========================
plan="$(bash "$SCRIPT" --dry-run "$(man "${ART[@]}")" 2>&1)"
assert_contains "the plan shows the second gate's own ordering" "under P2" "$plan"
# The falsifying check: no planned placement may name a child of the other gate.
bad_line="$(printf '%s\n' "$plan" | awk '/^order: / && /under P2/ && (/ A / || / A2 /) { print }')"
assert_eq "and no P2 placement references a P1 child" "" "$bad_line"

finish
