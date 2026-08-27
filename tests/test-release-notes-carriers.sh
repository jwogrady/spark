#!/usr/bin/env bash
# Behavioral tests for carrier relationships in the release-notes guard (#447).
#
# A carrier commit repeats an earlier commit's subject so one logical change
# reaches the generated notes when the generator cannot reach the original.
# The pair is ONE release-note change and consumes ONE bullet.
#
# The relationship is always DECLARED. Most of these tests exist to prove the
# negatives: chronology proves nothing, two same-subject commits without a
# declaration still need two bullets, and every unprovable declaration is NOT
# ASSESSED rather than a quiet pass.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib.sh"

runner="$here/../.github/scripts/release-notes-runner.sh"
# shellcheck source=/dev/null
. "$runner"

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "  ✖ $1"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

bash -n "$runner" && ok || bad "bash -n release-notes-runner.sh"

hex() { printf "$1%.0s" $(seq 40); }
A="$(hex a)"; B="$(hex b)"; C="$(hex c)"; MISSING="$(hex f)"

# --- pure ledger parsing -----------------------------------------------------
printf '%s\t%s\n' "$A" "$B" > "$WORK/led.tsv"
[ "$(notes_carrier_ledger_rows "$WORK/led.tsv")" = "$(printf '%s\t%s' "$A" "$B")" ] \
  && ok || bad "a well-formed row parses"

printf '# comment\n\n%s\t%s\n' "$A" "$B" > "$WORK/led.tsv"
[ "$(notes_carrier_ledger_rows "$WORK/led.tsv" | wc -l)" = "1" ] \
  && ok || bad "comments and blank lines are skipped"

[ -z "$(notes_carrier_ledger_rows "$WORK/absent.tsv")" ] \
  && ok || bad "an absent ledger is simply no relationships"

# Malformed rows are rc 2, never silently skipped: a ledger that cannot be read
# is a relationship that cannot be proven.
mal() { # <desc> <content>
  printf '%s\n' "$2" > "$WORK/led.tsv"
  local rc=0
  notes_carrier_ledger_rows "$WORK/led.tsv" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ] && ok || bad "$1 — want rc 2, got $rc"
}
mal "a one-column row is malformed"   "$A"
mal "a three-column row is malformed" "$(printf '%s\t%s\t%s' "$A" "$B" "$C")"
mal "a short sha is malformed"        "$(printf 'deadbeef\t%s' "$B")"
mal "an uppercase sha is malformed"   "$(printf '%s\t%s' "$(hex A)" "$B")"
mal "a non-hex sha is malformed"      "$(printf '%s\t%s' "$(hex z)" "$B")"
mal "a self-carry is malformed"       "$(printf '%s\t%s' "$A" "$A")"

# --- ambiguity is rejected ---------------------------------------------------
uniq_rc() { printf '%s\n' "$1" | notes_carrier_check_unique >/dev/null 2>&1 && echo 0 || echo $?; }
[ "$(uniq_rc "$(printf '%s\t%s\n%s\t%s' "$A" "$B" "$A" "$C")")" = "2" ] \
  && ok || bad "one carrier claiming two originals is rejected"
[ "$(uniq_rc "$(printf '%s\t%s\n%s\t%s' "$A" "$C" "$B" "$C")")" = "2" ] \
  && ok || bad "two carriers claiming one original is rejected"
[ "$(uniq_rc "$(printf '%s\t%s\n%s\t%s' "$A" "$B" "$C" "$A")")" = "0" ] \
  && ok || bad "two independent pairs are accepted"

# --- the real v0.20 topology, end to end ------------------------------------
# The ORIGINAL sits on a branch opened before the release tag and merged after
# it: genuinely unreleased (not an ancestor of the tag), yet dated before the
# tag, which is exactly why the generator's newest-first walk never reaches it.
fix="$WORK/repo"
mkdir -p "$fix"
git -c init.defaultBranch=trunk init -q "$fix"
gitc() { git -C "$fix" -c user.name=t -c user.email=t@e.invalid "$@"; }
seed() { # <path> <subject> <date>
  mkdir -p "$fix/$(dirname "$1")"; date +%s%N > "$fix/$1"; gitc add -A
  GIT_AUTHOR_DATE="$3" GIT_COMMITTER_DATE="$3" gitc commit -q -m "$2"
}

seed core.txt 'chore: scaffold'            '2026-01-01T00:00:00'
gitc checkout -q -b side
seed side.txt 'docs: reserve blocked-by'   '2026-01-02T10:00:00'
orig="$(gitc rev-parse HEAD)"
gitc checkout -q trunk
seed core.txt 'chore: unrelated work'      '2026-01-02T12:00:00'
gitc tag v1.0.0
GIT_AUTHOR_DATE='2026-01-03T08:00:00' GIT_COMMITTER_DATE='2026-01-03T08:00:00' \
  gitc merge -q --no-ff side -m 'Merge side'
seed core.txt 'feat: something new'        '2026-01-03T09:00:00'
other="$(gitc rev-parse HEAD)"
seed carrier.txt 'docs: reserve blocked-by' '2026-01-03T10:00:00'
carrier="$(gitc rev-parse HEAD)"
head_sha="$(gitc rev-parse HEAD)"
root="$(gitc rev-list --max-parents=0 HEAD)"

# No gh in these tests.
notes_pr_labels() { echo ""; }

count_blocked() { printf '%s\n' "$1" | grep -c 'reserve blocked-by' || true; }

# HOSTILE: identical subjects with NO declared relationship stay two changes.
# This is the guarantee the whole feature must not weaken — chronology alone
# never collapses anything.
: > "$fix/.carriers.tsv"
out="$( ( cd "$fix" && NOTES_CARRIER_LEDGER=".carriers.tsv" \
    notes_component_commits_tsv "o/r" "core" "v1.0.0..$head_sha" ) 2>/dev/null )"
[ "$(count_blocked "$out")" = "2" ] \
  && ok || bad "without a declaration two same-subject commits must stay two entries (got $(count_blocked "$out"))"

# DECLARED via the ledger: the pair collapses to exactly one entry.
printf '%s\t%s\n' "$carrier" "$orig" > "$fix/.carriers.tsv"
out="$( ( cd "$fix" && NOTES_CARRIER_LEDGER=".carriers.tsv" \
    notes_component_commits_tsv "o/r" "core" "v1.0.0..$head_sha" ) 2>/dev/null )"
[ "$(count_blocked "$out")" = "1" ] \
  && ok || bad "a declared carrier pair must yield exactly one entry (got $(count_blocked "$out"))"
# and the unrelated commits are untouched
[ "$(printf '%s\n' "$out" | grep -c 'something new')" = "1" ] \
  && ok || bad "collapsing a pair must not disturb other commits"

# DECLARED via the trailer — the forward mechanism, same result, no ledger.
# The commit touches a file: an empty one is outside every path scope, so it
# would never reach the commit list and the trailer would never be read.
: > "$fix/.carriers.tsv"
date +%s%N > "$fix/trailer.txt"; gitc add -A
GIT_AUTHOR_DATE='2026-01-03T11:00:00' GIT_COMMITTER_DATE='2026-01-03T11:00:00' \
  gitc commit -q -m "docs: reserve blocked-by

Changelog-Carrier-For: $orig"
head2="$(gitc rev-parse HEAD)"
out="$( ( cd "$fix" && NOTES_CARRIER_LEDGER=".carriers.tsv" \
    notes_component_commits_tsv "o/r" "core" "v1.0.0..$head2" ) 2>/dev/null )"
# orig collapses into the trailer carrier; the earlier ledger-less carrier
# remains its own change, so two entries survive, not three.
[ "$(count_blocked "$out")" = "2" ] \
  && ok || bad "the trailer must collapse its own pair (got $(count_blocked "$out"))"

# --- unprovable declarations are NOT ASSESSED, never a pass ------------------
notassessed() { # <desc> <ledger-content> [range-head]
  printf '%s\n' "$2" > "$fix/.carriers.tsv"
  local rc=0
  ( cd "$fix" && NOTES_CARRIER_LEDGER=".carriers.tsv" \
      notes_component_commits_tsv "o/r" "core" "v1.0.0..${3:-$head_sha}" ) >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ] && ok || bad "$1 — want rc 2, got $rc"
}

notassessed "a carrier naming a nonexistent original" "$(printf '%s\t%s' "$carrier" "$MISSING")"
notassessed "a nonexistent carrier"                   "$(printf '%s\t%s' "$MISSING" "$orig")"
notassessed "a malformed ledger row"                  "$carrier"
notassessed "an original outside the release range"   "$(printf '%s\t%s' "$carrier" "$root")"
notassessed "a pair whose subjects do not match"      "$(printf '%s\t%s' "$carrier" "$other")"

# HOSTILE: two carrier trailers on ONE commit. The uniqueness tests above cover
# the ledger's input path; this covers the trailer's, which they cannot reach.
# Taking the first and dropping the second would silently pick a winner — the
# exact ambiguity the contract says must be NOT ASSESSED.
: > "$fix/.carriers.tsv"
date +%s%N > "$fix/two.txt"; gitc add -A
GIT_AUTHOR_DATE='2026-01-03T13:00:00' GIT_COMMITTER_DATE='2026-01-03T13:00:00' \
  gitc commit -q -m "docs: two trailers

Changelog-Carrier-For: $orig
Changelog-Carrier-For: $other"
head4="$(gitc rev-parse HEAD)"
rc=0
( cd "$fix" && NOTES_CARRIER_LEDGER=".carriers.tsv" \
    notes_component_commits_tsv "o/r" "core" "v1.0.0..$head4" ) >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok || bad "two carrier trailers on one commit must not be assessed (got $rc)"

# ...and the message must name the multiplicity, not some downstream symptom.
err="$( ( cd "$fix" && NOTES_CARRIER_LEDGER=".carriers.tsv" \
    notes_component_commits_tsv "o/r" "core" "v1.0.0..$head4" ) 2>&1 >/dev/null || true )"
case "$err" in
  *"appears 2 times"*) ok ;;
  *) bad "the two-trailer failure must say so ($err)" ;;
esac

# Two IDENTICAL trailers are still two declarations, not one — a commit that
# says the same thing twice is still malformed metadata.
: > "$fix/.carriers.tsv"
date +%s%N > "$fix/dup.txt"; gitc add -A
GIT_AUTHOR_DATE='2026-01-03T14:00:00' GIT_COMMITTER_DATE='2026-01-03T14:00:00' \
  gitc commit -q -m "docs: duplicate trailers

Changelog-Carrier-For: $orig
Changelog-Carrier-For: $orig"
head5="$(gitc rev-parse HEAD)"
rc=0
( cd "$fix" && NOTES_CARRIER_LEDGER=".carriers.tsv" \
    notes_component_commits_tsv "o/r" "core" "v1.0.0..$head5" ) >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok || bad "repeated identical trailers must not be assessed (got $rc)"

# A key with no value is a declaration that cannot be honoured, not an absence.
: > "$fix/.carriers.tsv"
date +%s%N > "$fix/empty.txt"; gitc add -A
GIT_AUTHOR_DATE='2026-01-03T15:00:00' GIT_COMMITTER_DATE='2026-01-03T15:00:00' \
  gitc commit -q -m "docs: empty trailer

Changelog-Carrier-For:"
head6="$(gitc rev-parse HEAD)"
rc=0
( cd "$fix" && NOTES_CARRIER_LEDGER=".carriers.tsv" \
    notes_component_commits_tsv "o/r" "core" "v1.0.0..$head6" ) >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok || bad "an empty carrier trailer must not be assessed (got $rc)"

# A malformed trailer is unprovable too — and must fail rather than be ignored.
: > "$fix/.carriers.tsv"
date +%s%N > "$fix/bad.txt"; gitc add -A
GIT_AUTHOR_DATE='2026-01-03T12:00:00' GIT_COMMITTER_DATE='2026-01-03T12:00:00' \
  gitc commit -q -m "docs: bad trailer

Changelog-Carrier-For: not-a-sha"
head3="$(gitc rev-parse HEAD)"
rc=0
( cd "$fix" && NOTES_CARRIER_LEDGER=".carriers.tsv" \
    notes_component_commits_tsv "o/r" "core" "v1.0.0..$head3" ) >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok || bad "a malformed trailer must not be assessed (got $rc)"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
