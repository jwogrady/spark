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
# Every defect these describe was reverted and the reds counted, because a test
# that cannot fail against the bug it names is not evidence, and this milestone's
# recurring defect has been assertions that cannot fail. Of the 39 assertions:
#   * restoring the per-member key turns 9 red;
#   * restoring the readers' prefix match (`index(v, " " excl)`) turns 2 red;
#   * restoring cmd_docs_impact's private copy of the rule turns 1 red — the
#     verbatim-verdict assertion, which is why it compares the whole sentence
#     instead of grepping for INVALID.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

repo="$WORK/r"; make_repo "$repo"; cd "$repo"; mkdir -p .spark
OPCONF="$XDG_CONFIG_HOME/spark"; mkdir -p "$OPCONF"

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

# ======================== keying by family did not over-collapse ===========
# Two DIFFERENT families must keep two independent rules: the fix narrows the
# key to the family, not to the record type.
clean
{ printf 'version\t1\n'
  printf 'family\tmine\tany\toptional\tMine\n'
  printf 'member\tmine\tmine:solo\t111111\tSolo\n'
  printf 'exclusive\tmine\tmine:solo\tSolo is exclusive\n'
} > .spark/governance.tsv
model="$(resolve_governance)"
assert_eq "two families keep two independent exclusive rules" 2 \
  "$(printf '%s\n' "$model" | awk -F'\t' '$1 == "exclusive"' | grep -c . || true)"
assert_contains "the shipped family keeps its own" \
  "$(printf 'exclusive\tdocs-impact\tdocs-impact:none\t')" "$model"
assert_contains "and the added family keeps its own" \
  "$(printf 'exclusive\tmine\tmine:solo\t')" "$model"

# An exclusive naming a family nobody declared is not closed.
clean
printf 'version\t1\nexclusive\tphantom\tphantom:x\tNope\n' > .spark/governance.tsv
rc=0; out="$(resolve_governance 2>&1 >/dev/null)" || rc=$?
assert_rc "an exclusive for an undeclared family fails closed" 1 "$rc"
assert_contains "naming the family" "undeclared family phantom" "$out"

# Pruning must not become an amnesty: a tier naming a member IT does not
# declare is incoherent within itself, and still fails closed.
clean
{ printf 'version\t1\n'
  printf 'member\tdocs-impact\tdocs-impact:reference\t1d76db\tOnly reference\n'
  printf 'exclusive\tdocs-impact\tdocs-impact:none\tBut none is exclusive\n'
} > .spark/governance.tsv
rc=0; out="$(resolve_governance 2>&1 >/dev/null)" || rc=$?
assert_rc "a tier naming its own nonexistent member fails closed" 1 "$rc"
assert_contains "rather than being pruned" "not a member of that family" "$out"

# ======================== membership, never a prefix =======================
# The readers tested `index(v, " " excl)`, which matches any label merely
# STARTING WITH the exclusive member's name. A family with `mine:none` exclusive
# and `mine:noneish` declared therefore reported a violation for an issue that
# never carried `mine:none` — blocking valid work in `governance validate`, in
# `spark next` selection, and in the plan compiler.
#
# The fixture below is deliberately prefix-colliding: the original suite could
# not catch this, because `docs-impact:companion` and `docs-impact:reference`
# share no prefix.
clean
{ printf 'version\t1\n'
  printf 'family\tmine\tany\toptional\tMine\n'
  printf 'member\tmine\tmine:none\t111111\tNone\n'
  printf 'member\tmine\tmine:noneish\t222222\tShares the prefix\n'
  printf 'member\tmine\tmine:other\t333333\tOther\n'
  printf 'exclusive\tmine\tmine:none\tnone is exclusive\n'
} > .spark/governance.tsv
pmodel="$(resolve_governance)"

prefix_rows="$(gov_issue_rows "$pmodel" "$(gov_iss 9 "v1.0" "mine:noneish" "mine:other")" "")"
case "$prefix_rows" in
  *"is exclusive but is combined"*) bad "a prefix of the exclusive member is not the member" ;;
  *) ok ;;
esac
assert_contains "and a genuine violation is still caught" \
  "mine:none is exclusive but is combined" \
  "$(gov_issue_rows "$pmodel" "$(gov_iss 10 "v1.0" "mine:none" "mine:other")" "")"

mkdir -p "$WORK/pb"; echo body > "$WORK/pb/a.md"
printf 'issue\tA\tOne\tmine:noneish,mine:other\t\t%s\n' "$WORK/pb/a.md" > "$WORK/pp.tsv"
case "$(plan_schema_rows "$pmodel" "$WORK/pp.tsv")" in
  *"is exclusive but the plan combines"*) bad "the plan reader must not prefix-match either" ;;
  *) ok ;;
esac
printf 'issue\tA\tOne\tmine:none,mine:other\t\t%s\n' "$WORK/pb/a.md" > "$WORK/pp2.tsv"
assert_contains "and the plan reader still catches a genuine one" \
  "mine:none is exclusive but the plan combines" \
  "$(plan_schema_rows "$pmodel" "$WORK/pp2.tsv")"

# ======================== one predicate, not four readers =================
# `cmd_docs_impact` carried its own exclusivity test and returned before
# di_grade could run, so the grammar's INVALID branch was unreachable from the
# CLI: two implementations of one rule, with the tested one not being the one
# users reach. Both now call di_exclusive_violated.
di_exclusive_violated "mine:none mine:other" "mine:none" \
  && ok || bad "the predicate must catch a genuine violation"
di_exclusive_violated "mine:noneish mine:other" "mine:none" \
  && bad "the predicate must not prefix-match" || ok
di_exclusive_violated "mine:none" "mine:none" \
  && bad "the exclusive value alone is legal" || ok
di_exclusive_violated "mine:other" "" \
  && bad "no exclusive member declared means no violation" || ok

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
  "$(gov_issue_rows "$model" "$(gov_iss 9 v1.0 feature docs-impact:companion docs-impact:reference)" "feature")"

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

# ======================== the CLI reaches the same verdict =================
# Every assertion above calls the readers directly. `spark docs-impact` is what
# a human and a CI job actually run, and it used to answer exclusivity with its
# own copy of the rule — so the graded verdict was tested and the reached
# verdict was not. These drive the real verb.
clean
shim="$WORK/dishim"; mkdir -p "$shim"
for t in bash sh git grep sed awk cat cut tr sort head tail wc env printf mktemp \
         rm mkdir basename dirname date ls chmod touch find readlink uname; do
  src="$(command -v "$t" 2>/dev/null || true)"; [ -n "$src" ] && ln -sf "$src" "$shim/$t"
done
# A gh whose issue labels are whatever the caller put in DI_LABELS. `gh auth
# status` must succeed or the verb short-circuits to NOT ASSESSED and would
# never reach the rule under test.
stub_gh "$shim/gh" <<'GH'
case "$1 $2" in
  "auth status") exit 0 ;;
  "issue view")  printf '%s\n' ${DI_LABELS:-} ; exit 0 ;;
esac
exit 1
GH
echo "plugins/spark/docs/reference/x.md" > "$WORK/di-paths"

di_cli() {
  ( cd "$repo" && env PATH="$shim" DI_LABELS="$1" \
      "$SPARK" docs-impact --issue 9 --paths "$WORK/di-paths" --tsv 2>&1 )
}

rc=0; out="$(di_cli 'docs-impact:none docs-impact:reference')" || rc=$?
assert_rc "the verb itself refuses the exclusive member plus another" 1 "$rc"

# Not merely "the verb also says INVALID" — the verb says the GRAMMAR'S
# sentence, character for character. Two implementations that agree today
# diverge the moment one is edited, and the CLI's copy was the one no test
# reached; comparing the rendered verdict to di_grade's is the assertion that
# goes red if the copy comes back.
graded="$(di_grade 'docs-impact:none docs-impact:reference' '' \
  "$(printf '%s\n' "$(resolve_governance)" \
     | awk -F'\t' '$1 == "exclusive" && $2 == "docs-impact" { print $3; exit }')" || true)"
assert_eq "the verb reports the grammar's verdict verbatim" \
  "$(printf 'verdict\t%s\n' "$graded")" \
  "$(printf '%s\n' "$out" | grep '^verdict')"

# The prefix case, through the verb: a member merely starting with the
# exclusive member's name is a different label.
{ printf 'version\t1\n'
  printf 'member\tdocs-impact\tdocs-impact:none\tc5def5\tNone\n'
  printf 'member\tdocs-impact\tdocs-impact:noneish\t222222\tShares the prefix\n'
  printf 'member\tdocs-impact\tdocs-impact:reference\t1d76db\tReference\n'
} > "$repo/.spark/governance.tsv"
rc=0; out="$(di_cli 'docs-impact:noneish docs-impact:reference')" || rc=$?
case "$out" in
  *INVALID*) bad "the verb must not read a prefix as the exclusive member" ;;
  *) ok ;;
esac
# ...and the exclusive member is still enforced under the same narrowed set.
rc=0; out="$(di_cli 'docs-impact:none docs-impact:noneish')" || rc=$?
assert_rc "while the real combination still fails through the verb" 1 "$rc"
assert_contains "as INVALID" "INVALID" "$out"
clean

# ======================== the rendered model agrees ========================
# Re-declared rather than inherited from the section above: a suite whose later
# assertions depend on an earlier section's leftover files silently changes
# meaning the moment anything is inserted between them.
clean
printf 'version\t1\nexclusive\tdocs-impact\tdocs-impact:companion\tOperator says companion\n' \
  > "$OPCONF/governance.tsv"
tsv="$("$SPARK" governance --tsv 2>/dev/null)"
assert_eq "--tsv carries exactly one exclusive for the family" 1 "$(excount "$tsv")"
assert_contains "and it is the winner" \
  "$(printf 'exclusive\tdocs-impact\tdocs-impact:companion\t')" "$tsv"
clean

finish
