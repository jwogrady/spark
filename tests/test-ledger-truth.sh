#!/usr/bin/env bash
# Behavioural suite for #546: the dogfood ledger and the release record must not
# contradict themselves about how much work they describe.
#
# PR #545 appended repair cycles 13 and 14, updated the certification heading to
# 74 checks and the tally to 14 repair issues — and left "5 of the 75" in the
# discrimination sentence and "the twelve repair cycles" in the summary heading.
# Two numbers were updated and two were not, in one commit, in one file.
#
# THE POINT OF THIS SUITE is that a grep for today's literals would be
# certification theatre: it passes because someone typed the right figure today
# and says nothing about tomorrow. Every fixture below therefore APPENDS A CYCLE
# or changes a count and requires a failure — the property #546 asks for, checked
# in the direction that matters.
#
# Measured against the ACTUAL defect, not only fixtures: run over the real
# documents as they stood at merged commit 67f78d9, the check reports both
# contradictions #546 names — the twelve-versus-14 summary heading and the
# 74-versus-75 denominator — and exits 1. Over the fixed documents it exits 0.
# Of the 33 assertions, 20 require a failure.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
CHECK="$repo_root/.github/scripts/ledger-truth-check.sh"
w="$WORK/w"; mkdir -p "$w"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

# A minimal but structurally complete pair of documents. Kept small so each
# fixture changes exactly one thing.
# The suite rows need a tests/ directory of the FIXTURE's own, and a baseline the
# checker cannot resolve — so the fixtures exercise the current-total half, which
# is the half that catches an added suite, and the checker's shallow-clone limit
# is exercised at the same time.
FIXTURE_BASE="0000000000000000000000000000000000000000"
mk() { # <cycles> <word> <tally> <rows> <cert-h> <cert-p> <cert-of> [new] [base] [total]
  local cycles="$1" word="$2" tally="$3" rows="$4" ch="$5" cp="$6" co="$7" i
  { echo "# Ledger"
    echo
    for i in $(seq 1 "$cycles"); do
      printf '### Repair cycle %s — #%s, a thing\n\nprose\n\n' "$i" "$((500 + i))"
    done
    echo "### Current result"
    echo
    echo "All $tally repair issues are closed, and so on."
    echo
    echo "### Certification — $ch checks, 0 failures, 1 honest gap"
    echo
    echo "Re-run against master: **$cp passed, 0 failed, 1 reported NOT ASSESSED.**"
    echo
    echo "Reverting the key turns **5 of the $co** red — the assertions by name."
    echo
    echo "### What the $word repair cycles cost, and what they bought"
    echo
    echo "| | |"
    echo "| --- | --- |"
    echo "| repair issues closed | $tally (${tally} code defects) |"
    echo "| new behavioural suites | ${8:-0} |"
    echo "| suites total | ${9:-0} → ${10:-0} (baseline \`$FIXTURE_BASE\`) |"
  } > "$w/ledger.md"
  { echo "# Release record"
    echo
    echo "## Scope"
    echo
    echo "| Issue | Outcome | Merge |"
    echo "| --- | --- | --- |"
    echo "| #470 | the original scope | \`aaa\` |"
    echo
    echo "**The repairs**, each with measured discrimination:"
    echo
    echo "| Issue | Defect | Merge |"
    echo "| --- | --- | --- |"
    for i in $(seq 1 "$rows"); do
      printf '| #%s | a defect | `abc%s` |\n' "$((500 + i))" "$i"
    done
    echo
    echo "## What the milestone implemented"
    echo
    echo "prose"
  } > "$w/record.md"
}
# The checker counts suites under its repository root. Pointed at the fixture
# directory, `find "$root/tests"` sees the fixture's own tests/ — which is what
# makes the suite-count assertions below about the fixture rather than about this
# repository.
mkdir -p "$w/tests"
run() {
  RC=0
  OUT="$(cd "$w" && bash "$CHECK" --ledger "$w/ledger.md" --record "$w/record.md" 2>&1)" || RC=$?
}

# ============ a consistent pair passes ====================================
# First, because every fixture below is a difference from this one.
mk 14 fourteen 14 14 74 74 74
run
assert_eq "a consistent record passes" 0 "$RC"
assert_contains "and says how many cycles it counted" "14 repair cycle(s)" "$OUT"

# ============ APPEND A CYCLE without updating the summary =================
# The property #546 asks for, stated as a fixture: the derived count moves and
# the claim does not.
mk 15 fourteen 14 14 74 74 74
run
assert_eq "appending a cycle without updating the summary fails" 1 "$RC"
assert_contains "naming what the heading claims" "claims 14 repair cycles" "$OUT"
assert_contains "and what the ledger records" "records 15" "$OUT"

# ...and a tally that disagrees with the distinct issues the record names still
# fails. Cycles and issues are NOT the same number — an issue reopened twice gets
# two cycles — so each is compared against the claim that names it.
mk 15 fifteen 14 15 74 74 74
run
assert_eq "a tally disagreeing with the record's distinct issues fails" 1 "$RC"
assert_contains "naming both counts" "names 15 distinct" "$OUT"

# ...and updating both but not the release record still fails.
mk 15 fifteen 15 14 74 74 74
run
assert_eq "a stale release record fails even with a fresh ledger" 1 "$RC"
assert_contains "naming the record's row count" "lists 14 repairs" "$OUT"

# Only when all three move together does it pass. This is the assertion that
# makes the three previous ones mean something.
mk 15 fifteen 15 15 74 74 74
run
assert_eq "all three moving together passes" 0 "$RC"
assert_contains "at the new count" "15 repair cycle(s)" "$OUT"
assert_contains "and reports the issue count too" "over 15 repair issue(s)" "$OUT"

# ============ the suite counts are derived from the tree =================
# The ledger said "6 new" and "47 → 56" while the tree held 57, and this check
# reported "record agrees" — because it derived cycles, the repairs table and the
# denominator, and did not look at these rows. A guard that emits a success beside
# a stale figure teaches its reader to trust a signal that does not cover the
# claim (#549).
rm -f "$w/tests"/test-*.sh
: > "$w/tests/test-alpha.sh"; : > "$w/tests/test-beta.sh"
mk 14 fourteen 14 14 74 74 74 0 0 2
run
assert_eq "a suite total matching the tree passes" 0 "$RC"
assert_contains "and the summary reports it" "2 suite(s)" "$OUT"

# ADD A SUITE without updating the row: the derived count moves, the claim does
# not. This is #549's own fixture.
: > "$w/tests/test-gamma.sh"
run
assert_eq "adding a suite without updating the row fails" 1 "$RC"
assert_contains "naming what the tally claims" "claims 2 suites" "$OUT"
assert_contains "and what the tree holds" "tree holds 3" "$OUT"

# Updating it passes again.
mk 14 fourteen 14 14 74 74 74 0 0 3
run
assert_eq "updating the row passes" 0 "$RC"

# A row that is not "A → B (baseline REF)" is refused rather than skipped.
mk 14 fourteen 14 14 74 74 74 0 0 3
sed -i 's/^| suites total |.*/| suites total | lots |/' "$w/ledger.md"
run
assert_eq "an unparseable suites row fails" 1 "$RC"
assert_contains "and says what shape it wants" "A → B (baseline" "$OUT"

# A missing baseline commit is a GAP: without it the starting figure cannot be
# reproduced, which is the whole complaint about the original hand-counted rows.
mk 14 fourteen 14 14 74 74 74 0 0 3
sed -i 's/ (baseline `[^`]*`)//' "$w/ledger.md"
run
assert_eq "a suites row with no baseline commit fails" 1 "$RC"
assert_contains "and says why" "cannot be reproduced" "$OUT"

# An unresolvable baseline is a stated LIMIT, not a silent pass — and the
# current total is still checked, so an added suite still fails.
mk 14 fourteen 14 14 74 74 74 0 0 3
run
assert_eq "an unresolvable baseline still passes on the checkable half" 0 "$RC"
assert_contains "and says which half it could not verify" "not in this clone" "$OUT"
: > "$w/tests/test-delta.sh"
run
assert_eq "while an added suite still fails with an unresolvable baseline" 1 "$RC"
rm -f "$w/tests/test-delta.sh"

# A missing 'new behavioural suites' row is only reachable when the baseline
# resolves; with an unresolvable one the checker says so instead of inventing a
# verdict. Asserted so the degradation is deliberate rather than accidental.
mk 14 fourteen 14 14 74 74 74 0 0 3
sed -i '/^| new behavioural suites |/d' "$w/ledger.md"
run
assert_eq "a missing new-suites row is not invented around" 0 "$RC"
assert_contains "because the baseline could not be resolved" "not in this clone" "$OUT"

# Leave the fixture tree empty again: every other fixture calls mk with seven
# arguments, so its suite rows default to 0 → 0 and must match an empty tests/.
rm -f "$w/tests"/test-*.sh

# ============ the certification denominator, everywhere ===================
# #546's literal reproduction: the heading and the passed-count updated, the
# discrimination sentence left behind.
mk 14 fourteen 14 14 74 74 75
run
assert_eq "a stale discrimination denominator fails" 1 "$RC"
assert_contains "naming both numbers" "more than one denominator" "$OUT"
assert_contains "and showing them" "74 75" "$OUT"
# The other direction: the heading left behind instead.
mk 14 fourteen 14 14 75 74 74
run
assert_eq "a stale certification heading fails too" 1 "$RC"
# And a consistent denominator of any value passes — the check is about
# agreement, not about a particular number, so re-certifying is not a fight.
mk 14 fourteen 14 14 91 91 91
run
assert_eq "a different but consistent denominator passes" 0 "$RC"

# ============ the tally breakdown must add up =============================
# A category set that stops covering the population is the same drift in
# miniature.
mk 14 fourteen 14 14 74 74 74
sed -i 's/| repair issues closed | 14 (14 code defects) |/| repair issues closed | 14 (9 code defects, 4 owner re-audits) |/' "$w/ledger.md"
run
assert_eq "a breakdown that does not sum to the total fails" 1 "$RC"
assert_contains "naming the sum" "sums to 13" "$OUT"

# ============ non-contiguous cycle numbers ===============================
# Without this, a renumbering or a dropped section lets the maximum overstate
# the count — the derived figure would be wrong and the check would still pass.
mk 14 fourteen 14 14 74 74 74
sed -i 's/^### Repair cycle 7 — .*/### Repair cycle 99 — #507, renumbered by accident/' "$w/ledger.md"
run
assert_eq "a gap in the cycle numbering fails" 1 "$RC"
assert_contains "naming where it broke" "not contiguous" "$OUT"

# ============ two cycles under one heading ================================
# Cycles sometimes arrive together and share a heading. The count must not
# depend on how the run was paragraphed, or the check would dictate prose.
# Built with 13 individual headings and a record already holding 15 rows, then
# the 14th and 15th cycles are added as ONE heading. Appending the record row
# instead would land it after the repairs table's scope boundary — a fixture
# fault that reads exactly like a checker fault, and did on the first run.
mk 13 fifteen 15 15 74 74 74
printf '\n### Repair cycles 14 and 15 — #514 and #515, together\n\nprose\n' >> "$w/ledger.md"
run
if [ "$RC" -eq 0 ]; then ok
else bad "a combined heading was miscounted: $OUT"; fi
assert_contains "and both numbers were read from it" "15 repair cycle(s)" "$OUT"

# ============ an issue may repeat; an extra ROW may not ==================
# A second reopening is a second cycle, so the same issue legitimately appears
# twice in the repairs table. What must still fail is a row with no cycle behind
# it, and a tally that no longer matches the distinct issues.
mk 14 fourteen 13 14 74 74 74
sed -i '0,/^| #514 | a defect |/s//| #501 | a defect |/' "$w/record.md"
run
assert_eq "an issue repeated with a matching tally is accepted" 0 "$RC"
assert_contains "and the summary line reports both counts" "over 13 repair issue(s)" "$OUT"
# Now the same duplication with the tally left at the row count: the distinct
# issues no longer match what the tally claims.
mk 14 fourteen 14 14 74 74 74
sed -i '0,/^| #514 | a defect |/s//| #501 | a defect |/' "$w/record.md"
run
assert_eq "a duplicate that contradicts the tally fails" 1 "$RC"
assert_contains "naming the distinct count" "distinct one" "$OUT"
# And an EXTRA row with no cycle behind it fails on the row count.
mk 14 fourteen 14 15 74 74 74
run
assert_eq "a row with no cycle behind it fails" 1 "$RC"
assert_contains "naming one row per cycle" "one row per cycle" "$OUT"

# ============ missing structure is a GAP, never a silent pass =============
mk 14 fourteen 14 14 74 74 74
sed -i '/^### What the fourteen repair cycles/d' "$w/ledger.md"
run
assert_eq "a missing summary heading fails rather than passing vacuously" 1 "$RC"
assert_contains "and says what it could not find" "no '### What the" "$OUT"

mk 14 fourteen 14 14 74 74 74
sed -i '/^### Certification —/d' "$w/ledger.md"
run
assert_eq "a missing certification section fails rather than passing vacuously" 1 "$RC"

mk 14 fourteen 14 14 74 74 74
sed -i '/^### Repair cycle /d' "$w/ledger.md"
run
assert_eq "no cycle headings at all fails rather than passing vacuously" 1 "$RC"
assert_contains "saying nothing could be cross-checked" "nothing can be cross-checked" "$OUT"

# ============ number words and numerals both read ========================
# The summary heading reads better as prose, and a check that forced numerals
# would be a check dictating style.
mk 14 14 14 14 74 74 74
run
assert_eq "a numeral in the summary heading is accepted" 0 "$RC"
# A hyphenated compound resolves: the tens and units are added, so prose does not
# have to stop at twenty. "twenty-one" was rejected by the first version of this
# check, which is how the gap was found.
mk 21 "twenty-one" 21 21 74 74 74
run
assert_eq "a hyphenated number word is accepted" 0 "$RC"
mk 14 "twenty-flurb" 14 14 74 74 74
run
assert_eq "an unparseable count fails rather than being ignored" 1 "$RC"
mk 14 "flurbteen" 14 14 74 74 74
run
assert_eq "and a single unparseable word fails too" 1 "$RC"

# ============ the REAL documents ==========================================
# Last, and separately: the fixtures prove the check works, this proves the
# repository is consistent right now.
RC=0; OUT="$(bash "$CHECK" 2>&1)" || RC=$?
assert_eq "this repository's own ledger and record agree" 0 "$RC"
assert_contains "and the check says so with a count" "repair cycle(s)" "$OUT"

finish
