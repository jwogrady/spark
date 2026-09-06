#!/usr/bin/env bash
# Behavioural suite for #521: release-readiness coverage detects a headline
# baseline that lags the newest ROADMAP entry marked Shipped.
#
# The v0.20 section correctly said `Shipped (v0.20.0)` while the top-level
# current-phase summary in the SAME file still said "v0.19.0 is the published
# baseline". The document contradicted itself, and the first summary a reader
# sees is where release state gets established — so an operator or an agent could
# plan from a withdrawn baseline. The release-readiness pass that fixed the
# section had no check that could see the headline.
#
# The other half of the contract is that planning-wave names and published tags
# stay distinct: `## v0.21` is a wave, `v0.20.0` is a tag, and a wave that has
# not shipped must never be read as a release.
#
# Measured discrimination, not asserted. Of the 34 assertions: removing the whole
# headline check turns 13 red, and restoring only the unsound extraction — no
# region boundary, no ambiguity check, a silent maximum — turns 8, including
# #541's own reproduction.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
CHECK="$WORK/plugin/skills/plan/scripts/roadmap-check.sh"
w="$WORK/w"; mkdir -p "$w"

# run_check <line...> — build a roadmap and run the check.
#
# Every fixture carries one unshipped section so the "names a next release" check
# is satisfied and the baseline finding is the only variable.
#
# `--issues` is passed an empty inventory deliberately. Without it the sandbox
# has no usable `gh`, the run is INCOMPLETE, and the script exits 3 for that
# reason alone — so an assertion on a non-zero exit would pass whether or not the
# baseline check existed. That is an assertion that cannot fail, and it was
# written that way here before being measured.
empty_issues="$w/issues.json"; printf '[]\n' > "$empty_issues"
run_check() {
  local f="$w/ROADMAP.md"
  printf '%s\n' "$@" > "$f"
  RC_RC=0
  RC_OUT="$(bash "$CHECK" --roadmap "$f" --issues "$empty_issues" 2>&1)" || RC_RC=$?
}
gapline() { printf '%s\n' "$RC_OUT" | grep '^GAP: ' | grep -i baseline || true; }

BASE_OK='**Current phase: Alpha (v0.x).** `v0.20.0` is the published baseline.'
BASE_STALE='**Current phase: Alpha (v0.x).** `v0.19.0` is the published baseline.'
BASE_AHEAD='**Current phase: Alpha (v0.x).** `v0.21.0` is the published baseline.'

# ============ the reported state is DETECTED ==============================
run_check "# Roadmap" "$BASE_STALE" \
  '## v0.19 — Earlier' '**Status:** Shipped (`v0.19.0`) — released 2026-08-26.' \
  '## v0.20 — Latest'  '**Status:** Shipped — `v0.20.0` was published 2026-08-27.' \
  '## v0.21 — Next'    '**Status:** Planned — see #478.'
if [ -n "$(gapline)" ]; then ok; else bad "#521: a stale headline baseline was not reported"; fi
assert_contains "naming what the headline says" "v0.19.0" "$RC_OUT"
assert_contains "and what the roadmap records" "v0.20.0" "$RC_OUT"
assert_contains "and which way it diverges" "lags the roadmap" "$RC_OUT"
if [ "$RC_RC" -ne 0 ]; then ok; else bad "a stale baseline did not fail the check"; fi
assert_contains "and the gap is counted" "1 gap(s)" "$RC_OUT"

# ============ the corrected state passes ==================================
run_check "# Roadmap" "$BASE_OK" \
  '## v0.19 — Earlier' '**Status:** Shipped (`v0.19.0`) — released 2026-08-26.' \
  '## v0.20 — Latest'  '**Status:** Shipped — `v0.20.0` was published 2026-08-27.' \
  '## v0.21 — Next'    '**Status:** Planned — see #478.'
assert_eq "a correct headline reports no baseline gap" "" "$(gapline)"
assert_contains "and says which tag it matched" 'newest Shipped tag' "$RC_OUT"
assert_eq "and the run is a clean pass" 0 "$RC_RC"

# ============ a headline AHEAD of the roadmap is also a contradiction ======
# The other direction matters: claiming a release the roadmap does not record is
# as untruthful as lagging one it does.
run_check "# Roadmap" "$BASE_AHEAD" \
  '## v0.20 — Latest' '**Status:** Shipped — `v0.20.0` was published 2026-08-27.' \
  '## v0.21 — Next'   '**Status:** Planned — see #478.'
if [ -n "$(gapline)" ]; then ok; else bad "a headline ahead of the roadmap was not reported"; fi
assert_contains "and says the headline overclaims" "does not record" "$RC_OUT"

# ============ planning waves are NOT published tags =======================
# `## v0.21` is a wave. It must never be mistaken for a release, or the check
# would demand the headline name an unshipped version.
run_check "# Roadmap" "$BASE_OK" \
  '## v0.20 — Latest' '**Status:** Shipped — `v0.20.0` was published 2026-08-27.' \
  '## v0.21 — Next'   '**Status:** Planned — see #478.' \
  '## v0.22 — Later'  '**Status:** In progress — see #479.'
assert_eq "an unshipped wave does not become the expected baseline" "" "$(gapline)"
# ...and a version mentioned in an UNSHIPPED section's status is not a tag either.
run_check "# Roadmap" "$BASE_OK" \
  '## v0.20 — Latest' '**Status:** Shipped — `v0.20.0` was published 2026-08-27.' \
  '## v0.21 — Next'   '**Status:** Planned — will be cut as `v0.21.0`, see #478.'
assert_eq "a planned tag in a Planned status is not a published tag" "" "$(gapline)"

# ============ the claim is bounded to the HEADLINE REGION =================
# The guard first scanned the whole file and took the greatest version it found,
# so a later migration note mentioning the current tag masked a stale summary —
# it could positively certify the exact contradiction it exists to prevent
# (#541). This is that reproduction, verbatim.
run_check "# Roadmap" \
  'Published baseline: `v1.0.0`.' \
  '## v1.1 — shipped' '**Status:** Shipped (`v1.1.0`)' \
  '## v1.2 — next'    '**Status:** Planned' 'Tracks #1.' \
  'Migration note: the published baseline for this comparison is `v1.1.0`.'
if [ -n "$(gapline)" ]; then ok; else bad "#541: a later prose mention masked a stale headline"; fi
assert_contains "naming the stale headline" "v1.0.0" "$RC_OUT"
assert_contains "and the tag it should have named" "v1.1.0" "$RC_OUT"
assert_contains "and which way it diverges" "lags the roadmap" "$RC_OUT"

# A mention inside a SECTION cannot supply the claim either, in the other
# direction: with no headline claim at all, later prose must not manufacture one.
run_check "# Roadmap" \
  '**Current phase.** The pipeline is proven.' \
  '## v1.1 — shipped' '**Status:** Shipped (`v1.1.0`)' \
  '## v1.2 — next'    '**Status:** Planned — see #1.' \
  'Historical: the published baseline was once `v1.1.0`.'
assert_eq "section prose does not manufacture a headline claim" "" "$(gapline)"
assert_contains "and the limit is still stated" "makes no published-baseline claim" "$RC_OUT"

# ============ blockquoted history is not the headline =====================
# A roadmap keeps historical asides in blockquotes, and history legitimately
# names superseded baselines. Counting them made this repository's own summary
# ambiguous: a reconciliation note recording that withdrawn releases "returned
# the published baseline to `v0.16.2`" sits above the first heading.
run_check "# Roadmap" \
  '**Current phase.** `v1.1.0` is the published baseline.' \
  '> **Reconciliation.** Withdrawn releases returned the published baseline to' \
  '> `v0.9.0` until the catch-up tag was cut.' \
  '## v1.1 — shipped' '**Status:** Shipped (`v1.1.0`)' \
  '## v1.2 — next'    '**Status:** Planned — see #1.'
assert_eq "a blockquoted historical baseline is not a second claim" "" "$(gapline)"
assert_eq "and the run is clean" 0 "$RC_RC"

# ============ two claims in the summary is AMBIGUITY, not a maximum =======
# Reducing them to the greatest version is precisely how the unsound version hid
# a stale headline, so the check refuses to choose.
run_check "# Roadmap" \
  '**Current phase.** `v1.0.0` is the published baseline.' \
  'Note: for tooling, `v1.1.0` is the published baseline.' \
  '## v1.1 — shipped' '**Status:** Shipped (`v1.1.0`)' \
  '## v1.2 — next'    '**Status:** Planned — see #1.'
if [ -n "$(gapline)" ]; then ok; else bad "two summary claims were silently reduced to one"; fi
assert_contains "and it says the summary is ambiguous" "more than one published baseline" "$RC_OUT"
assert_contains "naming both" "v1.0.0" "$RC_OUT"
# ...and it must not ALSO report a match or a limit for the same file.
case "$RC_OUT" in
  *"newest Shipped tag"*) bad "an ambiguous summary also reported a match" ;;
  *) ok ;;
esac
case "$RC_OUT" in
  *"makes no published-baseline claim"*) bad "an ambiguous summary also reported no claim" ;;
  *) ok ;;
esac
# The same version named twice is not ambiguous — one claim, stated twice.
run_check "# Roadmap" \
  '**Current phase.** `v1.1.0` is the published baseline.' \
  'Restated: `v1.1.0` is the published baseline.' \
  '## v1.1 — shipped' '**Status:** Shipped (`v1.1.0`)' \
  '## v1.2 — next'    '**Status:** Planned — see #1.'
assert_eq "one version named twice is not ambiguity" "" "$(gapline)"

# ============ the phrase is matched case-insensitively ===================
run_check "# Roadmap" \
  'Published Baseline: `v1.0.0`.' \
  '## v1.1 — shipped' '**Status:** Shipped (`v1.1.0`)' \
  '## v1.2 — next'    '**Status:** Planned — see #1.'
if [ -n "$(gapline)" ]; then ok; else bad "a capitalised claim was not read"; fi

# ============ several tags in one wave: the newest wins ===================
run_check "# Roadmap" '**Current phase.** `v0.16.2` is the published baseline.' \
  '## v0.16 — Wave' '**Status:** Shipped (`v0.16.0`–`v0.16.2`) — released 2026-08-12' \
  '## v0.17 — Next' '**Status:** Planned — see #478.'
assert_eq "the highest tag in a multi-tag wave is the baseline" "" "$(gapline)"
run_check "# Roadmap" '**Current phase.** `v0.16.0` is the published baseline.' \
  '## v0.16 — Wave' '**Status:** Shipped (`v0.16.0`–`v0.16.2`) — released 2026-08-12' \
  '## v0.17 — Next' '**Status:** Planned — see #478.'
if [ -n "$(gapline)" ]; then ok; else bad "naming the first tag of a wave rather than the newest was not reported"; fi

# ============ absent and contradictory claims ============================
# No claim at all: the check states its own limit rather than implying it
# verified something.
run_check "# Roadmap" "**Current phase: Alpha.** The pipeline is proven." \
  '## v0.20 — Latest' '**Status:** Shipped — `v0.20.0` was published 2026-08-27.' \
  '## v0.21 — Next'   '**Status:** Planned — see #478.'
assert_eq "no baseline claim is not reported as a gap" "" "$(gapline)"
assert_contains "and the limit is stated explicitly" "makes no published-baseline claim" "$RC_OUT"

# A claim with nothing Shipped to support it is a contradiction, not a pass.
run_check "# Roadmap" "$BASE_OK" \
  '## v0.20 — Latest' '**Status:** In progress — see #478.' \
  '## v0.21 — Next'   '**Status:** Planned — see #479.'
if [ -n "$(gapline)" ]; then ok; else bad "a baseline claim with no Shipped tag was not reported"; fi
assert_contains "and says no Shipped section records a tag" "no roadmap section marked Shipped" "$RC_OUT"

finish
