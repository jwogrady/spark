#!/usr/bin/env bash
# Regression guard for the v0.22 docs-truth miss.
#
# v0.22.0 shipped `spark triage`, `spark reconcile` and `spark course` — three
# public product surfaces — with correct reference and operator documentation and
# every declared `docs-impact` satisfied. `README.md` still described the
# five-stage lifecycle as the whole product, so the public positioning of the
# release described v0.21.
#
# Issue-level `docs-impact` (#483) proves the documentation classes an issue
# DECLARED were satisfied. It cannot prove the declaration was semantically
# complete: no v0.22 issue named the README, so nothing failed. The release-level
# semantic check that closes this is `docs-truth` (#484).
#
# THIS SUITE IS NOT `docs-truth`. It is a narrow regression guard on the specific
# surfaces that regressed, holding the line until #484 builds the general one. It
# deliberately does not try to derive "which prose is semantically complete" —
# that judgment is #484's, and a half-built version of it here would be a second
# spelling of one fact.
#
# Discrimination: every assertion below fails against `f364d42`, the commit the
# `v0.22.0` tag names.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

README="$repo_root/README.md"
ROADMAP="$repo_root/ROADMAP.md"
RECORD="$repo_root/docs/releases/v0.22.md"

# names <label> <needle> <file> — current-state documentation must mention a
# surface the product actually ships. Case-insensitive: the README may introduce
# a verb in prose or in a code fence.
names() {
  if grep -qi -- "$2" "$3"; then ok; else bad "$1 — '$2' appears nowhere in $(basename "$3")"; fi
}

# --- the three v0.22 verbs are public product, so the public README names them.
names "README names the truth pass"       "triage"    "$README"
names "README names the reconcile slate"  "reconcile" "$README"
names "README names course derivation"    "course"    "$README"

# --- the properties that make them worth shipping, not just the words. A README
# that name-drops the verbs but omits the read-only contract and the authority
# boundary still misdescribes the product.
names "README states the read-only contract"  "read-only"         "$README"
names "README states the authority boundary"  "DECISION REQUIRED" "$README"
names "README keeps authority with the human" "not authority"     "$README"

# --- ROADMAP current-state truth. The headline is where a reader establishes the
# published baseline, and #521 already proved a lagging headline is how planning
# starts from a version that is not current.
# The ROADMAP writes the tag backticked — Shipped (`v0.21.0`) — and one entry
# spans a range, so the tolerant form is "a v-number anywhere inside the
# parentheses", taking the highest. The `Shipped (vX.Y.Z)` placeholder in the
# status vocabulary is excluded by requiring a digit after `v`. Matching only the
# unbackticked spelling would have found exactly one entry — the newest — which
# makes the comparison below tautological rather than discriminating.
newest_shipped="$(grep -o 'Shipped ([^)]*)' "$ROADMAP" \
  | grep -o 'v[0-9][0-9.]*' | sed 's/^v//; s/\.$//' | sort -V | tail -n1)"
if [ -n "$newest_shipped" ]; then ok; else bad "ROADMAP declares no Shipped release"; fi

if grep -q "\`v${newest_shipped}\` is the published baseline" "$ROADMAP"; then
  ok
else
  bad "ROADMAP headline does not name v${newest_shipped}, its newest Shipped release, as the baseline"
fi

# --- a released version must not still be described as awaiting authorization.
# This is the exact false sentence the v0.22.0 tree carried.
if grep -q 'no version has been cut' "$ROADMAP"; then
  bad "ROADMAP still says a version has not been cut while it declares v${newest_shipped} Shipped"
else
  ok
fi

if grep -qi 'awaiting release authorization' "$ROADMAP"; then
  bad "ROADMAP still describes a released milestone as awaiting authorization"
else
  ok
fi

# --- the regression itself is preserved as evidence, in the release it belongs
# to. If this record is ever tidied away, the lesson goes with it.
if grep -q 'docs-truth = FAIL' "$RECORD"; then
  ok
else
  bad "v0.22 record no longer carries the docs-truth fixture"
fi

if grep -q 'Disposition: `Released`' "$RECORD"; then
  ok
else
  bad "v0.22 record does not record the release as Released"
fi

finish
