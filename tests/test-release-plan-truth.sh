#!/usr/bin/env bash
# Release-plan truth guard (issue #380). The v0.16.2 release shipped
# docs/releases/v0.17-plan.md still claiming the v0.17 milestone could not be
# created — after GitHub milestone #14 existed and the release gate (#373) had
# recorded it. The durable release record must describe the release, not the
# capabilities of whatever session drafted it: a transient tooling constraint
# is a session fact, and carrying one forward turns the canonical plan into
# misdirection once the constraint lifts.
#
# The guard is deliberately mechanical and offline: it cannot ask GitHub
# whether a milestone exists, so it forbids the class of claim instead of
# checking the instance — a release plan may never carry an
# environment-capability limitation section or a milestone-unavailability
# claim. State what is (the milestone record), never what a tool could not do.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pass=0 fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

plans=("$root"/docs/releases/*-plan.md)
[ -e "${plans[0]}" ] || { echo "0 passed, 0 failed (no release plans present)"; exit 0; }

for plan in "${plans[@]}"; do
  name="$(basename "$plan")"
  flat="$(tr -s '[:space:]' ' ' < "$plan")"

  # No transient-constraint sections in the durable record.
  if grep -qiE '^##+ +Planning limitation' "$plan"; then
    bad "$name: carries a 'Planning limitation' section — session constraints are not release truth"
  else
    ok
  fi

  # No milestone-unavailability claims — the observed #380 failure class.
  if printf '%s' "$flat" | grep -qiE 'until the milestone( object)? is created|does not expose milestone creation|cannot create (a |the )?milestone'; then
    bad "$name: claims the milestone is unavailable/uncreated — name the milestone record instead"
  else
    ok
  fi

  # A plan must positively name its milestone authority.
  if printf '%s' "$flat" | grep -qiE '\*\*Milestone:?\*\*|milestone #[0-9]+'; then
    ok
  else
    bad "$name: names no GitHub milestone — the milestone is the version authority (ADR-0027/#357)"
  fi
done

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
