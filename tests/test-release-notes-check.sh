#!/usr/bin/env bash
# Offline suite for the release-notes completeness check (#232). It exercises
# the pure decision logic against fixtures — no network, no gh, no git. The two
# failure modes it must catch are the ones v0.10.1 actually hit: a visible
# commit missing from the notes, and a feature merged under an excluded type.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/.github/scripts/release-notes-check.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

# check <want-exit> <desc> <commits-content> <notes-content> [needle ...]
check() {
  local want="$1" desc="$2" commits="$3" notes="$4"; shift 4
  local out rc=0 needle
  printf '%s' "$commits" > "$work/commits.tsv"
  printf '%s' "$notes"   > "$work/notes.md"
  out="$(bash "$script" --commits "$work/commits.tsv" --notes "$work/notes.md" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then bad "$desc — want exit $want, got $rc ($out)"; return 0; fi
  for needle in "$@"; do
    case "$out" in *"$needle"*) ;; *) bad "$desc — output lacks '$needle'"; return 0 ;; esac
  done
  ok
}

bash -n "$script" && ok || bad "bash -n release-notes-check.sh"

# --- green: every visible commit is in the notes; excluded types with no
# feature label are correctly ignored (the docs/governance commits that are
# legitimately hidden must NOT be flagged).
check 0 "complete notes pass" \
"feat	add the widget	feature
fix	stop the crash on empty input	bug
docs	document the backlog label	documentation
chore	bump the dev container	chore
refactor	extract the resolver	tech-debt" \
"## Features
* add the widget (#10)
## Bug Fixes
* stop the crash on empty input (#11)
## Documentation
* document the backlog label (#12)" \
  "release-notes: complete"

# --- docs is a visible type: a docs change absent from the notes is flagged
# just like a feat, since documentation is part of the product.
check 1 "missing docs change flagged" \
"docs	rewrite the release-ownership explanation	documentation
fix	stop the crash	bug" \
"## Bug Fixes
* stop the crash (#11)" \
  "omission: docs: rewrite the release-ownership explanation"

# --- a squash-merge subject ending in " (#NNN)" is NOT a false omission: the
# notes linkify the number, so match must tolerate the decoration.
check 0 "trailing PR-number subject matches the linkified notes" \
"fix	stop the crash on empty input (#256)	bug" \
"## Bug Fixes
* stop the crash on empty input ([#256](https://x/256)) ([abc](https://x/abc)), closes [#224]" \
  "release-notes: complete"

# --- omission: a visible feat is missing from the notes.
check 1 "missing feature flagged" \
"feat	surface milestone-gated readiness	feature
fix	stop the crash on empty input	bug" \
"## Bug Fixes
* stop the crash on empty input (#11)" \
  "omission: feat: surface milestone-gated readiness"

# --- mislabel: the #226 shape — a feature merged under chore:, so Release
# Please never put it in the notes. Must be caught even though a chore is
# normally invisible.
check 1 "feature-as-chore flagged" \
"chore	add the milestone-gate readiness signal	feature
fix	stop the crash	bug" \
"## Bug Fixes
* stop the crash (#11)" \
  "mislabel: add the milestone-gate readiness signal" "labeled 'feature'"

# --- multiple build-process commits under hidden types with no user-facing
# label are NOT flagged (they are legitimately hidden). This is the regression
# guard that the check does not become noisy about honest chores.
check 0 "hidden build-process commits stay silent" \
"chore	add metadata governance parity	chore
test	add orchestration fixtures	test
build	bump the dev container image	chore
ci	pin the runner version	chore
refactor	extract the resolver	tech-debt" \
"## Features
* nothing user-facing this release" \
  "release-notes: complete"

# --- combined: an omission and a mislabel in the same range are both reported.
check 1 "omission and mislabel both reported" \
"feat	add the exporter	feature
refactor	extract the shared helper	tech-debt
chore	assign the feature to its milestone	feature" \
"## Bug Fixes
* an unrelated fix (#9)" \
  "omission: feat: add the exporter" "mislabel: assign the feature to its milestone"

# --- usage errors exit 2.
rc=0; bash "$script" --commits "$work/nope.tsv" --notes "$work/notes.md" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok || bad "missing commits file — want exit 2, got $rc"
rc=0; bash "$script" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok || bad "no args — want exit 2, got $rc"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
