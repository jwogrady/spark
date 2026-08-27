#!/usr/bin/env bash
# Behavioral suite for the governance integration (#473): doctor reading the
# same resolved model as the governance commands, work selection refusing
# mechanically invalid execution metadata, and brief surfacing readiness from
# deterministic state.
#
# The recurring hazard these pin is a green result that means "not looked at".
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

# ======================== a new repo ========================
new="$WORK/new"; make_repo "$new"
( cd "$new" && "$SPARK" setup ) >/dev/null 2>&1
out="$(cd "$new" && "$SPARK" doctor 2>&1)" || true

assert_contains "doctor reports governance readiness" "Governance readiness:" "$out"
assert_contains "and confirms the model resolves" "governance model is valid" "$out"

# ======================== no auth is NOT a pass ========================
# A PATH with no gh is the honest simulation of an unauthenticated operator.
shim="$WORK/shim"; mkdir -p "$shim"
for t in bash sh git grep sed cat cp mv rm mkdir mktemp basename dirname tr find \
         sort head tail date env uname readlink awk cut wc ls chmod touch printf paste comm python3; do
  s="$(command -v "$t" 2>/dev/null || true)"; [ -n "$s" ] && ln -sf "$s" "$shim/$t"
done
out="$(cd "$new" && env PATH="$shim" "$SPARK" doctor 2>&1)" || true
assert_contains "no gh reports remote governance NOT ASSESSED" \
  "remote governance NOT ASSESSED" "$out"
assert_contains "and says explicitly that this is not a pass" "not a pass" "$out"
# The critical property: a green doctor must never mean a remote surface was
# silently skipped. It may be deferred, but it must be NAMED.
assert_contains "the deferred surfaces are named, not skipped" \
  "spark governance validate" "$out"
case "$out" in
  *"every governed label exists"*) bad "doctor claimed the remote matched without reading it" ;;
  *) ok ;;
esac

# ======================== doctor reads the SAME model ========================
# Not a second copy of the rules: overriding the taxonomy must move doctor's
# reported category set with it.
proj="$WORK/proj"; make_repo "$proj"
( cd "$proj" && "$SPARK" setup ) >/dev/null 2>&1
mkdir -p "$proj/.spark"
printf '{"issue.taxonomy":"alpha beta"}\n' > "$proj/.spark/preferences.json"
out="$(cd "$proj" && env PATH="$shim" "$SPARK" doctor 2>&1)" || true
# Anchored to the line that reports the SET. A bare "alpha beta" needle also
# matches the standards-boundary drift message, so it stayed green while the
# category set had not moved at all.
assert_contains "a resolved override moves doctor's category set" \
  "Declared categories: alpha beta" "$out"

# A project governance model that does not resolve makes every check below it
# unassessable, and doctor must say so rather than passing.
printf 'version\t1\nnonsense\tx\ty\n' > "$proj/.spark/governance.tsv"
rc=0; out="$(cd "$proj" && env PATH="$shim" "$SPARK" doctor 2>&1)" || rc=$?
assert_rc "an unresolvable model fails doctor" 1 "$rc"
assert_contains "and says every check below is unassessable" "unassessable" "$out"
rm -f "$proj/.spark/governance.tsv" "$proj/.spark/preferences.json"

# ======================== file surfaces need a decision =====================
model="$(resolve_governance)"
rows="$(gov_file_rows "$model" "$proj")"
assert_contains "a missing human-owned surface is judgment, not a create" \
  "$(printf 'file\t!\t')" "$rows"
# Providing it clears the finding — the same rows doctor reads.
mkdir -p "$proj/.github"
: > "$proj/.github/PULL_REQUEST_TEMPLATE.md"
: > "$proj/release-please-config.json"
mkdir -p "$proj/.github/ISSUE_TEMPLATE"
assert_eq "a satisfied surface set raises nothing" "" \
  "$(gov_file_rows "$model" "$proj" | awk -F'\t' '$2 == "!"')"
out="$(cd "$proj" && env PATH="$shim" "$SPARK" doctor 2>&1)" || true
assert_contains "doctor agrees once they are present" \
  "every declared governance file surface is present" "$out"

# ======================== selection refuses invalid metadata ================
# The rule is schema-driven, so it is drivable without GitHub. Two categories on
# a milestone-assigned issue is mechanically invalid.
bad_row="$(printf '77\tfeature,bug,docs-impact:none\tv1.0\n')"
findings="$(gov_issue_rows "$model" "$bad_row" | awk -F'\t' '$2 == "!"')"
assert_contains "two categories is a finding selection can refuse on" \
  "exactly-one but 2 are set" "$findings"
# ...and Spark must not choose which one was meant.
case "$findings" in
  *"should be"*|*"use feature"*) bad "selection must not pick a category" ;;
  *) ok ;;
esac
# A clean active issue raises nothing, so selection proceeds.
assert_eq "a clean active issue does not block selection" "" \
  "$(gov_issue_rows "$model" "$(printf '78\tfeature,P1,docs-impact:none\tv1.0\n')" \
     | awk -F'\t' '$2 == "!"')"

# The priority set comes from the model, not a hard-coded case: a project that
# renames the family must still have its priorities recognised.
printf 'version\t1\nmember\tpriority\tUrgent\tb60205\tMost urgent\n' \
  > "$proj/.spark/governance.tsv"
( cd "$proj" && . "$SPARK" >/dev/null 2>&1
  m="$(resolve_governance)"
  p="$(printf '%s\n' "$m" | awk -F'\t' '$1 == "member" && $2 == "priority" { printf "%s ", $3 }')"
  case "$p" in *Urgent*) exit 0 ;; *) exit 1 ;; esac ) \
  && ok || bad "a renamed priority family must resolve from the model"
rm -f "$proj/.spark/governance.tsv"

# ======================== brief surfaces readiness ==========================
rc=0; out="$(cd "$proj" && env PATH="$shim" "$SPARK" brief 2>&1)" || rc=$?
# The real exit status, not a literal: `|| true` swallowed it and the assertion
# could never fail.
assert_rc "brief still runs offline" 0 "$rc"
# With every surface satisfied there is nothing to warn about.
case "$out" in
  *"governance surface(s) need a decision"*) bad "brief warned on a satisfied surface set" ;;
  *) ok ;;
esac
# An unresolvable model is a blocker brief must surface from deterministic state.
printf 'version\t1\nnonsense\tx\ty\n' > "$proj/.spark/governance.tsv"
out="$(cd "$proj" && env PATH="$shim" "$SPARK" brief 2>&1)" || true
assert_contains "brief surfaces an unresolvable model" \
  "the model does not resolve" "$out"
rm -f "$proj/.spark/governance.tsv"

# ======================== a missing surface is not "present" ================
# A `+` row is MISSING. Counting only `!` let a provisionable surface fall
# straight through to the green all-clear — the "a green result never means
# not-looked-at" hazard, in the block written to eliminate it.
rm -f "$proj/release-please-config.json"
out="$(cd "$proj" && env PATH="$shim" "$SPARK" doctor 2>&1)" || true
assert_contains "a missing provisionable surface is reported" \
  "missing and provisionable" "$out"
case "$out" in
  *"every declared governance file surface is present"*)
    bad "a missing surface must not read as present" ;;
  *) ok ;;
esac
: > "$proj/release-please-config.json"

# ======================== an extended taxonomy stays workable ==============
# Categories come from the preference that owns them. Resolving them from the
# model's members alone made every issue in a repo with a custom taxonomy read
# as "category is required and none is declared" — and selection then refused
# every issue, unfixably.
assert_eq "a project category satisfies the requirement" "" \
  "$(gov_issue_rows "$model" "$(printf '78\talpha,P1,docs-impact:none\tv1.0\n')" "alpha beta" \
     | awk -F'\t' '$2 == "!"')"
assert_contains "and a category it does NOT declare is reported" \
  "category is required and none is declared" \
  "$(gov_issue_rows "$model" "$(printf '79\tfeature,P1,docs-impact:none\tv1.0\n')" "alpha beta")"
assert_contains "two project categories are still invalid" \
  "exactly-one but 2 are set" \
  "$(gov_issue_rows "$model" "$(printf '80\talpha,beta,docs-impact:none\tv1.0\n')" "alpha beta")"

# ======================== reruns are idempotent =============================
before="$(cd "$proj" && env PATH="$shim" "$SPARK" doctor 2>&1 | grep -c 'Governance readiness')"
after="$(cd "$proj" && env PATH="$shim" "$SPARK" doctor 2>&1 | grep -c 'Governance readiness')"
assert_eq "doctor is idempotent" "$before" "$after"
snapshot="$(cd "$proj" && git status --porcelain)"
( cd "$proj" && env PATH="$shim" "$SPARK" doctor >/dev/null 2>&1 ) || true
( cd "$proj" && env PATH="$shim" "$SPARK" brief >/dev/null 2>&1 ) || true
assert_eq "neither doctor nor brief writes anything" "$snapshot" \
  "$(cd "$proj" && git status --porcelain)"

# ======================== existing-repo behaviour unchanged =================
# This issue deliberately leaves the existing-repo path alone: it still
# classifies as existing and goes discovery-first, never scaffolding.
ex="$WORK/existing"; fixture_mature_repo "$ex"
out="$(cd "$ex" && env PATH="$shim" "$SPARK" orient 2>&1)" || true
assert_contains "a mature repo still classifies as existing" "existing" "$out"
# Both branches were no-ops with no ok/bad, so the block asserted nothing.
# What actually matters is that orient stays inspect-only on an existing repo.
assert_eq "orient wrote nothing" "" "$(cd "$ex" && git status --porcelain | grep '.spark' || true)"
assert_eq "and recorded no classification" "" \
  "$([ -f "$ex/.spark/preferences.json" ] && echo present || echo '')"

finish
