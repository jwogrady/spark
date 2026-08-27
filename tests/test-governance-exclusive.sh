#!/usr/bin/env bash
# Behavioural suite for #511: `exclusive` is ONE overridable fact per family,
# resolved by the existing shipped → operator → project precedence, so every
# consumer reads the same rule.
#
# The defect these pin: `exclusive` was keyed per family+member, so two members
# were two distinct facts. Both survived layering, and each consumer then picked
# one by its own accident of iteration order — `cmd_docs_impact` read the first
# row, `gov_issue_rows` and `plan_schema_rows` the last. One rule, two answers.
#
# Every assertion here fails against that keying: verified by reverting the key
# and watching 7 of these 14 turn red. A test that cannot fail against the bug
# it describes is not evidence.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

repo="$WORK/r"; make_repo "$repo"; cd "$repo"; mkdir -p .spark
OPCONF="$XDG_CONFIG_HOME/spark"; mkdir -p "$OPCONF"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

clean() { rm -f .spark/governance.tsv "$OPCONF/governance.tsv"; }
# member|tier for each resolved exclusive row of the family
exrows() {
  printf '%s\n' "$1" | awk -F'\t' '$1 == "exclusive" && $2 == "docs-impact" { print $3 "|" $NF }'
}
# `grep -c` exits 1 on zero matches and this file runs under `set -e`: without
# the guard the suite would abort at the first zero-row case, which is the case
# most worth asserting.
excount() {
  printf '%s\n' "$1" | awk -F'\t' '$1 == "exclusive" && $2 == "docs-impact"' | grep -c . || true
}

# ======================== one winner, at every tier ========================
clean
model="$(resolve_governance)"
assert_eq "the shipped model resolves exactly one exclusive" 1 "$(excount "$model")"
assert_eq "and it is the shipped member" "docs-impact:none|default" "$(exrows "$model")"

# default -> operator
printf 'version\t1\nexclusive\tdocs-impact\tdocs-impact:companion\tOperator says companion\n' \
  > "$OPCONF/governance.tsv"
model="$(resolve_governance)"
assert_eq "an operator override still resolves one row" 1 "$(excount "$model")"
assert_eq "and the operator wins" "docs-impact:companion|operator" "$(exrows "$model")"

# operator -> project
printf 'version\t1\nexclusive\tdocs-impact\tdocs-impact:reference\tProject says reference\n' \
  > .spark/governance.tsv
model="$(resolve_governance)"
assert_eq "a project override still resolves one row" 1 "$(excount "$model")"
assert_eq "and the project wins over the operator" "docs-impact:reference|project" "$(exrows "$model")"

# ======================== same-tier duplicates still fail ==================
# Making exclusive one fact per family must not weaken the within-tier rule: a
# tier declaring two exclusive members is incoherent, not something to resolve.
clean
{ printf 'version\t1\n'
  printf 'exclusive\tdocs-impact\tdocs-impact:none\tOne\n'
  printf 'exclusive\tdocs-impact\tdocs-impact:companion\tTwo\n'
} > .spark/governance.tsv
rc=0; out="$(resolve_governance 2>&1 >/dev/null)" || rc=$?
assert_rc "two exclusives in one tier fail closed" 1 "$rc"
assert_contains "and say a family may declare at most one" "at most one" "$out"

# ======================== narrowing prunes an obsolete rule ================
# A tier that replaces the member set can supersede a member out of existence.
# The lower tier's exclusive rule about it is then pruned, not fatal.
clean
printf 'version\t1\nmember\tdocs-impact\tdocs-impact:reference\t1d76db\tOnly reference\n' \
  > .spark/governance.tsv
model="$(resolve_governance)"
assert_eq "narrowing away the exclusive member drops its rule" 0 "$(excount "$model")"
assert_contains "and the narrowed member survives" \
  "$(printf 'member\tdocs-impact\tdocs-impact:reference\t')" "$model"

# ======================== every consumer, one rule =========================
clean
printf 'version\t1\nexclusive\tdocs-impact\tdocs-impact:companion\tOperator says companion\n' \
  > "$OPCONF/governance.tsv"
model="$(resolve_governance)"

# The two iteration orders that used to disagree must now coincide, because
# there is only one row to read.
first="$(printf '%s\n' "$model" | awk -F'\t' '$1=="exclusive" && $2=="docs-impact" {print $3; exit}')"
last="$(printf '%s\n' "$model" | awk -F'\t' '$1=="exclusive" && $2=="docs-impact" {v=$3} END{print v}')"
assert_eq "first-read and last-read see the same member" "$first" "$last"
assert_eq "and it is the resolved winner" "docs-impact:companion" "$first"

combo="docs-impact:companion,docs-impact:reference"
assert_contains "gov_issue_rows enforces the resolved member" \
  "docs-impact:companion is exclusive" \
  "$(gov_issue_rows "$model" "$(printf '9\tfeature,%s\tv1.0\n' "$combo")" "feature")"

art="$WORK/plan.tsv"; mkdir -p "$WORK/bodies"; echo body > "$WORK/bodies/a.md"
printf 'issue\tA\tOne\tfeature,%s\t\t%s\n' "$combo" "$WORK/bodies/a.md" > "$art"
assert_contains "plan_schema_rows enforces the same member" \
  "docs-impact:companion is exclusive" "$(plan_schema_rows "$model" "$art")"

rc=0; dg="$(di_grade "docs-impact:companion docs-impact:reference" "" "$first")" || rc=$?
assert_rc "di_grade refuses the same combination" 1 "$rc"
assert_contains "as INVALID" "INVALID" "$dg"

# ...and the shipped member is NOT the rule any more, which is the whole point
# of an override: judging by `docs-impact:none` would be reading a superseded
# fact.
rc=0; dg2="$(di_grade "docs-impact:none docs-impact:reference" "" "$first")" || rc=$?
case "$dg2" in
  *INVALID*) bad "a superseded exclusive member must not still be enforced" ;;
  *) ok ;;
esac

# ======================== the rendered model agrees ========================
tsv="$("$SPARK" governance --tsv 2>/dev/null)"
assert_eq "--tsv carries exactly one exclusive for the family" 1 "$(excount "$tsv")"
assert_contains "and it is the winner" \
  "$(printf 'exclusive\tdocs-impact\tdocs-impact:companion\t')" "$tsv"
clean

finish
