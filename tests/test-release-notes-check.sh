#!/usr/bin/env bash
# Offline suite for the release-notes completeness check (#232, #291). It
# exercises the pure decision logic against fixtures — no network, no gh, no
# git. The failure modes it must catch: a visible commit missing from the
# notes, a feature merged under an excluded type (the two v0.10.1 actually
# hit), and a breaking change hidden behind an excluded type (#291).
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
  "core subject-omission check passed"

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
  "core subject-omission check passed"

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
  "core subject-omission check passed"

# --- combined: an omission and a mislabel in the same range are both reported.
check 1 "omission and mislabel both reported" \
"feat	add the exporter	feature
refactor	extract the shared helper	tech-debt
chore	assign the feature to its milestone	feature" \
"## Bug Fixes
* an unrelated fix (#9)" \
  "omission: feat: add the exporter" "mislabel: assign the feature to its milestone"

# --- #291: a breaking change whose TYPE is hidden (chore!) is changelog-
# visible regardless of type; missing from the notes it must be flagged.
check 1 "breaking-typed chore missing from the notes flagged" \
"chore!	drop the legacy config knob	chore" \
"## Bug Fixes
* an unrelated fix (#9)" \
  "omission: chore!: drop the legacy config knob" "breaking change"

# --- #291: same property spelled as the BREAKING CHANGE footer, which the
# caller represents as the fourth TSV column.
check 1 "body-marker breaking change missing from the notes flagged" \
"refactor	rework the hook loader	tech-debt	breaking" \
"## Chores
* nothing related here" \
  "omission: refactor!: rework the hook loader"

# --- #291: a breaking change present in the notes passes, and the success
# message may claim breaking visibility because a breaking commit was present.
check 0 "breaking change present in the notes passes with the breaking claim" \
"chore!	drop the legacy config knob	chore" \
"## ⚠ BREAKING CHANGES
* drop the legacy config knob (#77)" \
  "every breaking change appears in the notes"

# --- #291: a breaking, feature-labeled, hidden-type commit that IS in the
# notes is not a mislabel — the breaking marker already made it visible.
check 0 "breaking feature-labeled chore in the notes is not a mislabel" \
"chore!	swap the storage backend	feature" \
"## ⚠ BREAKING CHANGES
* swap the storage backend (#88)" \
  "every breaking change appears in the notes"

# --- #291 regression: an EMPTY labels column before the breaking flag must
# not be collapsed away (tab is IFS whitespace — a naive `read` would swallow
# the empty field and misread `breaking` as the labels). The breaking half
# must run and the labels half must not be claimed.
printf 'chore\tdrop the legacy knob\t\tbreaking\n' > "$work/commits.tsv"
printf '## Chores\n* nothing related\n' > "$work/notes.md"
rc=0; out="$(bash "$script" --commits "$work/commits.tsv" --notes "$work/notes.md" 2>&1)" || rc=$?
if [ "$rc" -ne 1 ]; then bad "empty-labels breaking column — want exit 1, got $rc ($out)"; else
  case "$out" in *"omission: chore!: drop the legacy knob"*) ok ;; *) bad "empty-labels breaking column — breaking omission not flagged ($out)" ;; esac
fi

# --- #291 honesty: with no breaking commit in the range the success message
# must NOT claim the breaking property (nothing exercised it).
printf 'feat\tadd the widget\t\t\n' > "$work/commits.tsv"
printf '## Features\n* add the widget (#10)\n' > "$work/notes.md"
rc=0; out="$(bash "$script" --commits "$work/commits.tsv" --notes "$work/notes.md" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then bad "no-breaking path — want exit 0, got $rc ($out)"; else
  case "$out" in *"breaking change appears in the notes"*) bad "no-breaking path — must NOT claim the breaking property ($out)" ;; *) ok ;; esac
fi

# --- #291: the component name flows into every claim, so a companion's pass
# can never read as core's (per-component honesty for the advisory table).
printf 'feat\tadd the audit exporter\t\t\n' > "$work/commits.tsv"
printf '## Features\n* add the audit exporter (#12)\n' > "$work/notes.md"
rc=0; out="$(bash "$script" --component spark-audit --commits "$work/commits.tsv" --notes "$work/notes.md" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then bad "component path — want exit 0, got $rc ($out)"; else
  case "$out" in *"spark-audit subject-omission check passed"*) ok ;; *) bad "component path — claim must name the component ($out)" ;; esac
fi
printf 'feat\tadd the audit exporter\t\t\n' > "$work/commits.tsv"
printf '## Features\n* something else entirely\n' > "$work/notes.md"
rc=0; out="$(bash "$script" --component spark-audit --commits "$work/commits.tsv" --notes "$work/notes.md" 2>&1)" || rc=$?
if [ "$rc" -ne 1 ]; then bad "component failure path — want exit 1, got $rc ($out)"; else
  case "$out" in *"finding(s) in spark-audit"*) ok ;; *) bad "component failure path — summary must name the component ($out)" ;; esac
fi

# --- #297: the production runner supplies NO labels, so the hidden-feature
# (mislabel) half is vacuous. The success message must make ONLY the
# subject-omission claim, and must NOT claim the hidden-feature property it
# could not check. This is the honesty fix's core assertion.
printf 'feat\tadd the widget\t\nfix\tpatch the bug\t\n' > "$work/commits.tsv"
printf '## Features\n* add the widget (#10)\n## Bug Fixes\n* patch the bug (#11)\n' > "$work/notes.md"
rc=0; out="$(bash "$script" --commits "$work/commits.tsv" --notes "$work/notes.md" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then bad "no-labels path — want exit 0, got $rc ($out)"; else
  case "$out" in *"core subject-omission check passed"*) ok ;; *) bad "no-labels path — missing the omission claim ($out)" ;; esac
  case "$out" in *"hidden behind an excluded type"*) bad "no-labels path — must NOT claim the hidden-feature property ($out)" ;; *) ok ;; esac
fi

# --- #297: when labels ARE supplied and clean, the success message may add the
# hidden-feature clause, because that half actually ran.
printf 'feat\tadd the widget\tfeature\nchore\tbump the container\tchore\n' > "$work/commits.tsv"
printf '## Features\n* add the widget (#10)\n' > "$work/notes.md"
rc=0; out="$(bash "$script" --commits "$work/commits.tsv" --notes "$work/notes.md" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then bad "labels-present path — want exit 0, got $rc ($out)"; else
  case "$out" in *"no labeled commit is hidden behind an excluded type"*) ok ;; *) bad "labels-present path — missing the hidden-feature clause ($out)" ;; esac
fi

# --- usage errors exit 2.
rc=0; bash "$script" --commits "$work/nope.tsv" --notes "$work/notes.md" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok || bad "missing commits file — want exit 2, got $rc"
rc=0; bash "$script" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok || bad "no args — want exit 2, got $rc"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
