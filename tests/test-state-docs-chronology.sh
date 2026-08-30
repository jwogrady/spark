#!/usr/bin/env bash
# Behavioural suite for #475 — current-state documents must not retell chronology
# that Git, GitHub, or a release record already owns.
#
# The failure this guards is duplication, not leakage. One story — the withdrawal
# of the `v0.17`–`v0.19.1` line — was told in `ROADMAP.md`, `CHANGELOG.md`,
# `docs/problem-statement.md` and the release records at once. Four copies written
# on different days drift, and they had: the changelog's copy still named
# `v0.16.2` as the published baseline two releases after that stopped being true.
#
# THIS IS NOT #476. That issue teaches `audit` to DETECT provenance leakage
# generally, across arbitrary surfaces, as a first-class finding. This suite
# asserts that the specific passages removed here stay removed and the role
# statements that replace them stay present. It is a regression guard on a known
# defect, deliberately narrow, and it does not attempt a general rule.
#
# Nor is it #477: nothing here checks terminology.
#
# Discrimination is proved, not asserted. Every "absent" assertion is re-run
# against a mutant copy of the same file with the removed passage restored, and
# must fail there. An assertion that cannot fail proves nothing.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# absent <file> <pattern> — 0 when the passage is gone, 1 when it is present.
# Split out so the same predicate can be pointed at a mutant and expected to
# disagree.
absent() { ! grep -qF -- "$2" "$1"; }
present() { grep -qF -- "$2" "$1"; }

check_absent() {
  local label="$1" file="$2" pat="$3"
  if absent "$file" "$pat"; then ok; else bad "$label — '$pat' is still in $(basename "$file")"; fi
}

check_present() {
  local label="$1" file="$2" pat="$3"
  if present "$file" "$pat"; then ok; else bad "$label — $(basename "$file") lacks '$pat'"; fi
}

# mutate <file> <text> — a copy of the real file with a removed passage restored.
mutate() {
  local out="$WORK/mutant-$RANDOM.md"
  cat "$1" > "$out"
  printf '\n%s\n' "$2" >> "$out"
  printf '%s' "$out"
}

# control <label> <file> <pattern> — restoring the passage must break the
# assertion that says it is gone.
control() {
  local label="$1" file="$2" pat="$3" m
  m="$(mutate "$file" "$pat")"
  if absent "$m" "$pat"; then
    bad "MUTATION CONTROL $label — the check passed with the passage restored; it does not discriminate"
  else
    ok
  fi
}

ROADMAP="$repo_root/ROADMAP.md"
CHANGELOG="$repo_root/CHANGELOG.md"
README="$repo_root/README.md"
PROBLEM="$repo_root/docs/problem-statement.md"
RELREADME="$repo_root/docs/releases/README.md"
RELV19="$repo_root/docs/releases/v0.19.md"

# --- the retold chronology is gone from every current-state surface -----------
P_TAGS_DELETED="Their GitHub Releases and tags"
P_BASELINE_RETURN="returned the published baseline to"
P_STALE_BASELINE='`v0.16.2` is again the published baseline'
P_PUBLISHED_BETWEEN="were published between"
P_EVERY_CHANGE="records every change"
P_PS_CHRONOLOGY="What happened since:"

check_absent "roadmap does not retell the withdrawal"      "$ROADMAP"   "$P_TAGS_DELETED"
check_absent "roadmap does not restate the baseline move"  "$ROADMAP"   "$P_BASELINE_RETURN"
check_absent "changelog does not name a stale baseline"    "$CHANGELOG" "$P_STALE_BASELINE"
check_absent "changelog does not retell the withdrawal"    "$CHANGELOG" "$P_PUBLISHED_BETWEEN"
check_absent "readme does not overclaim the changelog"     "$README"    "$P_EVERY_CHANGE"
check_absent "problem statement does not retell it"        "$PROBLEM"   "$P_PS_CHRONOLOGY"

# --- the roles that replace it are stated ------------------------------------
check_present "changelog declares itself a projection" "$CHANGELOG" \
  "generated release projection, not an authority on current"
check_present "release records are named as the chronology owner" "$RELREADME" \
  "Release chronology lives here"
check_present "release records are named provenance, not rewritten" "$RELREADME" \
  "Correct a factual error; never tidy the history"
check_present "roadmap keeps the durable conclusion" "$ROADMAP" \
  "No commit was removed and no pull request was unmerged"
check_present "roadmap cites the record instead of retelling" "$ROADMAP" \
  "docs/releases/v0.19.md"

# --- PROVENANCE WAS NOT ERASED. The point of #475 is to remove duplicate
# retellings, never the evidence. The account must still exist where it belongs,
# or this suite would be satisfied by deleting the history outright.
check_present "the withdrawal account survives in its release record" "$RELV19" \
  "withdraw"
if [ -s "$RELV19" ]; then ok; else bad "the v0.19 release record is missing or empty"; fi

# --- mutation controls -------------------------------------------------------
control "roadmap withdrawal"    "$ROADMAP"   "$P_TAGS_DELETED"
control "roadmap baseline move" "$ROADMAP"   "$P_BASELINE_RETURN"
control "changelog baseline"    "$CHANGELOG" "$P_STALE_BASELINE"
control "changelog withdrawal"  "$CHANGELOG" "$P_PUBLISHED_BETWEEN"
control "readme overclaim"      "$README"    "$P_EVERY_CHANGE"
control "problem chronology"    "$PROBLEM"   "$P_PS_CHRONOLOGY"

finish
