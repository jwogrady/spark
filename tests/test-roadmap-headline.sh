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
# Measured discrimination, not asserted: removing the headline check turns 13 of
# the 19 assertions red, including the reported state itself.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
CHECK="$WORK/plugin/skills/plan/scripts/roadmap-check.sh"
w="$WORK/w"; mkdir -p "$w"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

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
