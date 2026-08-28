#!/usr/bin/env bash
# Behavioural suite for #473's narrowed contract: what `setup` provisions, and
# what it deliberately does not.
#
# #473 promised a newly Spark-managed repository "should start with its standard
# labels, templates, and governance machinery" — unqualified. Issue forms and
# pull-request templates are `human-provisions`, `setup` does not author them, and
# `governance validate` therefore reports them, so a correctly onboarded repo
# failed its own validation on day one (#535).
#
# The contract was the thing that was wrong. Templates stay human-provisioned:
# Spark defines and validates their SHAPE and refuses to invent project-specific
# content. So this suite pins the boundary in both directions — and deliberately
# does NOT assert that a fresh repo passes `governance validate`, because that
# assertion is what would pressure the report into lying.
#
# Measured discrimination, not asserted. Of the 13 assertions: dropping the
# provisioner from the ABSENT row turns 5 red — a fresh repo then says nothing
# actionable about what a human owes — and dropping it from the PRESENT row turns
# 1, because the two classes stop being distinguishable to a check even though a
# reader could still guess.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"
set +e

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

fresh="$WORK/fresh"; make_repo "$fresh"
( cd "$fresh" && "$SPARK" setup ) >/dev/null 2>&1
model="$(cd "$fresh" && resolve_governance)"
rows="$(cd "$fresh" && gov_file_rows "$model" "$fresh")"

# ============ Spark provisions what it owns ==============================
# No surface the model marks `spark-provisions` may be left for a human to
# notice: that is the half of the promise that survived narrowing.
sparkjudge="$(printf '%s\n' "$rows" | awk -F'\t' '$2 == "!" && $4 ~ /spark-provisions/ { print }')"
assert_eq "no spark-owned surface is left as a judgment" "" "$sparkjudge"

# ============ and does NOT author what a human owns ======================
for pth in .github/ISSUE_TEMPLATE .github/pull_request_template.md; do
  if [ -e "$fresh/$pth" ]; then
    bad "setup authored $pth; templates are human-provisioned by contract"
  else ok; fi
done

# ============ the prerequisites are REPORTED, not silent =================
# Silence about them would be the real defect. A report naming them is the
# feature, and it is what makes the day-one non-pass honest rather than obscure.
humanrows="$(printf '%s\n' "$rows" | awk -F'\t' '$4 ~ /human-provisions/ { print }')"
n_human="$(printf '%s\n' "$humanrows" | grep -c . || true)"
if [ "$n_human" -gt 0 ]; then ok
else bad "a fresh repo said nothing about its human-provisioned prerequisites"; fi
# Each row must name the path a human has to supply, or the report is not
# actionable.
unnamed="$(printf '%s\n' "$humanrows" | awk -F'\t' '$3 !~ /\// { print }')"
assert_eq "and each names the path it wants" "" "$unnamed"
# ...and it must say a human provisions it, so the reader knows who acts.
for r in issue-form pr-template; do
  assert_contains "the $r row says a human provisions it" "human-provisions" \
    "$(printf '%s\n' "$humanrows" | grep -- "$r" || true)"
done

# ============ the classes are DISTINGUISHABLE from the rows ==============
# The narrowed contract's substance: a reader can tell the two apart
# mechanically, not by knowing which paths happen to be templates.
prov="$(printf '%s\n' "$rows" | awk -F'\t' 'NF { print $4 }' \
  | grep -oE '(spark|human)-provisions' | LC_ALL=C sort -u | paste -sd, -)"
case "$prov" in
  *spark-provisions*) ok ;;
  *) bad "no row names spark-provisions, so the classes cannot be told apart: $prov" ;;
esac
case "$prov" in
  *human-provisions*) ok ;;
  *) bad "no row names human-provisions: $prov" ;;
esac

# ============ a human-supplied template flips its own row =================
# The other direction, and the proof that the report tracks reality rather than a
# constant: create the template a human owes and the row must stop asking.
mkdir -p "$fresh/.github"
printf 'A project-specific template.\n' > "$fresh/.github/pull_request_template.md"
rows2="$(cd "$fresh" && gov_file_rows "$model" "$fresh")"
pr2="$(printf '%s\n' "$rows2" | grep -- 'pr-template' || true)"
assert_contains "a supplied PR template is present" "$(printf 'file\t=')" "$pr2"
# ...while the issue form, still absent, still asks.
if2="$(printf '%s\n' "$rows2" | grep -- 'issue-form' || true)"
assert_contains "and the still-absent issue form still asks" "human-provisions" "$if2"
rm -f "$fresh/.github/pull_request_template.md"

# ============ Spark still refuses to author it ===========================
# `setup` is create-only and offline; re-running must not decide to supply the
# human's content after all.
( cd "$fresh" && "$SPARK" setup ) >/dev/null 2>&1
for pth in .github/ISSUE_TEMPLATE .github/pull_request_template.md; do
  if [ -e "$fresh/$pth" ]; then
    bad "a second setup authored $pth"
  else ok; fi
done

finish
