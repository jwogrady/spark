#!/usr/bin/env bash
# Release-plan truth checker for the plan skill (#380).
#
# The v0.16.2 release shipped a plan still claiming its milestone could not be
# created after the milestone existed. The durable release record must state
# what is — never what some drafting session's tooling could not do. This
# checker forbids that claim class in every release doc and requires each
# plan to positively name its milestone authority:
#   A. no release doc carries a "planning limitation" marker (any heading
#      level, bold lead-in, or inline mention — the term itself is the marker
#      of the banned class)
#   B. no release doc claims a milestone is unavailable/uncreated/pending
#   C. every *-plan.md names a concrete GitHub milestone (`milestone #N`)
#
# Offline by design: it cannot ask GitHub whether a milestone exists, so it
# bans the claim class instead of verifying the instance. The residual —
# a creatively reworded capability complaint that avoids both the term and
# every unavailability verb — stays a human reconciliation item on the
# release gate; that residual is documented here deliberately (#380 allows
# "document why this state must remain manually reconciled").
#
# Read-only. One `GAP: …` line per finding.
# Exit codes: 0 clean, 1 gaps, 2 usage error or nothing to assess — an empty
# scan must not read as "clean".

set -euo pipefail

usage="usage: release-plan-check.sh [--dir RELEASES_DIR]"

dir="docs/releases"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      [ $# -ge 2 ] || { echo "--dir needs a directory argument" >&2; echo "$usage" >&2; exit 2; }
      dir="$2"; shift 2 ;;
    -h|--help) echo "$usage"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; echo "$usage" >&2; exit 2 ;;
  esac
done

[ -d "$dir" ] || { echo "not assessed: no such directory: $dir" >&2; exit 2; }

gaps=0 scanned=0
gap() { echo "GAP: $1"; gaps=$((gaps + 1)); }

for doc in "$dir"/*.md; do
  [ -f "$doc" ] || continue
  scanned=$((scanned + 1))
  name="$(basename "$doc")"
  # Whitespace-collapsed view: hard wrapping must not split a claim phrase.
  flat="$(tr -s '[:space:]' ' ' < "$doc")"

  # A. The banned section, by its name, in any dress — heading, bold, inline.
  if printf '%s' "$flat" | grep -qiE 'planning limitation'; then
    gap "$name: carries a 'planning limitation' marker — session constraints are not release truth"
  fi

  # B. Milestone-unavailability claims. Broad on the verbs, bounded on the
  # gaps, so "the pattern was not continued" near an unrelated "milestone"
  # doesn't trip it while every phrasing of "couldn't create / isn't created /
  # is unavailable" does.
  if printf '%s' "$flat" | grep -qiE \
    'until the milestone[^.]{0,40}(created|exists)|(cannot|can.t|could not|unable to|not able to|no way to|does not (expose|support|allow)|fail(s|ed)? to)[^.]{0,40}milestone|milestone[^.]{0,40}\bnot\b[^.]{0,20}\b(been |be |yet )?(created|available|possible)|milestone creation[^.]{0,30}(unavailable|impossible|blocked)|milestone[^.]{0,20}(uncreated|unavailable)'; then
    gap "$name: claims a milestone is unavailable/uncreated — record the milestone that is, not what a tool could not do"
  fi

  # C. A plan names its version authority concretely.
  case "$name" in
    *-plan.md)
      if ! printf '%s' "$flat" | grep -qiE 'milestone #[0-9]+'; then
        gap "$name: names no concrete GitHub milestone (milestone #N) — the milestone is the version authority"
      fi ;;
  esac
done

if [ "$scanned" -eq 0 ]; then
  echo "not assessed: no release docs found under $dir" >&2
  exit 2
fi

if [ "$gaps" -eq 0 ]; then
  echo "release-plan-check: $scanned doc(s) scanned, 0 gaps"
  exit 0
fi
echo "release-plan-check: $gaps gap(s)"
exit 1
