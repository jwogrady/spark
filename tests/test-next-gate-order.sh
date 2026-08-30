#!/usr/bin/env bash
# Behavioral suite for the release gate's DELIVERY ORDER as `spark next` reads
# it (#611). Two independent defects lived here, and either alone was enough to
# make a derived course untrue:
#
#   1. A selectable leaf beneath an ordinary container under the gate could not
#      receive an order at all. `suborder_of` emitted only rows whose immediate
#      parent was the gate, so every nested leaf fell to the fallback rank and
#      was handed remediation telling the operator to reparent it directly onto
#      the gate — advice that would collapse a hierarchy the gate validator
#      explicitly permits, to record an order the hierarchy already implied.
#
#   2. Priority outranked the recorded order, so a later course phase jumped an
#      earlier one whenever priorities differed across phases.
#
# Defect 2 is exercised in test-next-selection.sh, where the policy is a pure
# function. THIS file owns defect 1, because the order projection is the thing
# under test and it can only be read from a real snapshot.
#
# Every assertion here is about one question: does the gate's own hierarchy
# decide the sequence, or does the shape of the API response decide it?
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

tools="git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 xargs cksum comm"

# gh_stub <dir> <response-json> — a PATH whose gh answers the hierarchy query,
# applying the --jq the BINARY passes. Same construction the gate-role suite
# uses; the capture shape is shared so the two cannot drift apart.
gh_stub() {
  local d="$1" json="$2" t src
  mkdir -p "$d"
  for t in $tools; do
    src="$(command -v "$t" 2>/dev/null || true)"
    [ -n "$src" ] && ln -sf "$src" "$d/$t" 2>/dev/null || true
  done
  printf '%s' "$json" > "$d/cap.json"
  cat > "$d/gh" <<'GHEOF'
#!/usr/bin/env bash
case "${1:-}" in
  auth) exit 0 ;;
  repo) printf 'o/r\n'; exit 0 ;;
esac
isq=0; jqexpr=""; prev=""
for a in "$@"; do
  [ "$a" = "graphql" ] && isq=1
  [ "$prev" = "--jq" ] && jqexpr="$a"
  prev="$a"
done
if [ "$isq" = 1 ]; then
  if [ -n "$jqexpr" ]; then jq -r "$jqexpr" "$(dirname "$0")/cap.json"
  else cat "$(dirname "$0")/cap.json"; fi
  exit 0
fi
exit 0
GHEOF
  chmod +x "$d/gh"
}

# snap <response-json> — a real snapshot through the real capture.
snap() {
  local d="$WORK/n$RANDOM"
  gh_stub "$d" "$1"
  PATH="$d:$PATH" milestone_snapshot
}

# order <snapshot> <milestone> <gate> — the projection under test, one line.
order() { suborder_of "$1" "$2" "$3" | tr '\n' ' ' | sed 's/ $//'; }

# ===================== 1. the nested hierarchy fixture ======================
#
# The gate carries TWO ordinary parents, and each parent carries two
# equal-priority leaves:
#
#   #900 release gate
#   ├─ #800 ordinary container   ├─ #812 leaf
#   │                            └─ #811 leaf
#   └─ #801 ordinary container   ├─ #802 leaf
#                                └─ #803 leaf
#
# The numbers are deliberately adversarial. Under the first container the leaves
# descend (812 before 811), and the LOWER-numbered leaves (802, 803) sit under
# the SECOND container. So any implementation that falls back to issue number —
# which is exactly what the fallback rank did — selects #802, and any that reads
# the API's enumeration order rather than the declared child order gets a
# different answer again. Only the hierarchy's own order yields 812.
NEST_G="$(gate_iss 900 'v1.0 — nested' - OPEN 800,801 chore P1 release-gate)"
NEST_P1="$(gate_iss 800 'v1.0 — nested' 900 OPEN 812,811 chore P1)"
NEST_P2="$(gate_iss 801 'v1.0 — nested' 900 OPEN 802,803 chore P1)"
NEST_L1="$(gate_iss 812 'v1.0 — nested' 800 OPEN - feature P1)"
NEST_L2="$(gate_iss 811 'v1.0 — nested' 800 OPEN - feature P1)"
NEST_L3="$(gate_iss 802 'v1.0 — nested' 801 OPEN - feature P1)"
NEST_L4="$(gate_iss 803 'v1.0 — nested' 801 OPEN - feature P1)"
NEST_CAP="$(gate_cap "$(gate_mil 'v1.0 — nested' \
  "$NEST_G,$NEST_P1,$NEST_P2,$NEST_L1,$NEST_L2,$NEST_L3,$NEST_L4")" "$NEST_G")"

NEST_SNAP="$(snap "$NEST_CAP")"

assert_eq "the order projects through nested containers, in hierarchy order" \
  "812 811 802 803" "$(order "$NEST_SNAP" 'v1.0 — nested' 900)"

# CONTAINERS ARE NOT EMITTED. A position spent on one would make "N of M" count
# work nobody can be given, and the containers are not selectable anyway.
case " $(order "$NEST_SNAP" 'v1.0 — nested' 900) " in
  *" 800 "*|*" 801 "*) bad "a container appears in the delivery order" ;;
  *) ok ;;
esac

# ================= 2. direct children still behave exactly as before ========
#
# The regression risk of a preorder walk is that it changes the flat case too.
# It must not: a gate whose children are all leaves has always produced them in
# declared order, and that is still the whole answer.
FLAT_G="$(gate_iss 900 'v1.0 — flat' - OPEN 903,901,902 chore P1 release-gate)"
FLAT_A="$(gate_iss 903 'v1.0 — flat' 900 OPEN - feature P1)"
FLAT_B="$(gate_iss 901 'v1.0 — flat' 900 OPEN - feature P1)"
FLAT_C="$(gate_iss 902 'v1.0 — flat' 900 OPEN - feature P1)"
FLAT_CAP="$(gate_cap "$(gate_mil 'v1.0 — flat' \
  "$FLAT_G,$FLAT_A,$FLAT_B,$FLAT_C")" "$FLAT_G")"
FLAT_SNAP="$(snap "$FLAT_CAP")"

assert_eq "direct children keep their declared order, not their numeric order" \
  "903 901 902" "$(order "$FLAT_SNAP" 'v1.0 — flat' 900)"

# ===================== 3. a gate with no children at all ====================
#
# Absence is a known answer, not an error and not a crash in the walk.
BARE_G="$(gate_iss 900 'v1.0 — bare' - OPEN - chore P1 release-gate)"
BARE_SNAP="$(snap "$(gate_cap "$(gate_mil 'v1.0 — bare' "$BARE_G")" "$BARE_G")")"
assert_eq "a gate carrying nothing yields an empty order" \
  "" "$(order "$BARE_SNAP" 'v1.0 — bare' 900)"

# ===================== 4. a cycle terminates, it does not hang ==============
#
# A hierarchy containing a loop is not a shape whose order can be read. The walk
# must stop at the repeat rather than recurse forever — the caller's own cycle
# evidence is what names the state; this projection only has to survive it.
CYC_G="$(gate_iss 900 'v1.0 — cyc' - OPEN 800 chore P1 release-gate)"
CYC_A="$(gate_iss 800 'v1.0 — cyc' 900 OPEN 801 chore P1)"
CYC_B="$(gate_iss 801 'v1.0 — cyc' 800 OPEN 800 chore P1)"
CYC_SNAP="$(snap "$(gate_cap "$(gate_mil 'v1.0 — cyc' "$CYC_G,$CYC_A,$CYC_B")" "$CYC_G")")"
CYC_OUT="$(order "$CYC_SNAP" 'v1.0 — cyc' 900)"
assert_eq "a cyclic hierarchy terminates instead of recursing forever" \
  "" "$CYC_OUT"

# ===================== 5. truncated hierarchy fails closed ==================
#
# `next` refuses to select on a snapshot carrying any unread row, so a truncated
# sub-issue page can never be read as "carries none". Proven here at the
# snapshot, because that is where the evidence is either whole or not.
SUBS_TRUNCATED=true
TRUNC_G="$(gate_iss 900 'v1.0 — trunc' - OPEN 901 chore P1 release-gate)"
TRUNC_L="$(gate_iss 901 'v1.0 — trunc' 900 OPEN - feature P1)"
SUBS_TRUNCATED=false
TRUNC_SNAP="$(snap "$(gate_cap "$(gate_mil 'v1.0 — trunc' "$TRUNC_G,$TRUNC_L")" "$TRUNC_G")")"
case "$(snapshot_unread "$TRUNC_SNAP")" in
  *"sub-issues of #900"*) ok ;;
  *) bad "a truncated sub-issue page did not register as unread evidence" ;;
esac

# ===================== 6. MUTATION CONTROL ==================================
#
# Every fix above is worthless if the suite would pass without it. This restores
# the ORIGINAL direct-children-only projection and asserts the nested fixture
# then fails — so the assertion in section 1 is proven to be load-bearing rather
# than incidentally true.
suborder_of_mutant() {
  [ -n "${3:-}" ] || return 0
  printf '%s\n' "$1" | awk -F'\t' -v t="$2" -v g="$3" \
    '$1 == "sub" && $2 == t && $3 == g { print $4 }'
}
MUT="$(suborder_of_mutant "$NEST_SNAP" 'v1.0 — nested' 900 | tr '\n' ' ' | sed 's/ $//')"
if [ "$MUT" = "812 811 802 803" ]; then
  bad "mutation control: the pre-#611 projection also passes — the nested fixture proves nothing"
else
  ok
fi
# ...and it fails in the SPECIFIC way the issue described: it emits the two
# containers and none of the leaves, which is why every leaf scored 999.
assert_eq "mutation control: the old projection emitted containers, not leaves" \
  "800 801" "$MUT"

finish
