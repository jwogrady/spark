#!/usr/bin/env bash
# Behavioral suite for the docs-impact disposition (#483): every row of the
# declared grammar, path classification from schema data, core/companion
# distinctness, multi-PR evidence aggregation, and not-assessed.
#
# The grammar and the classifier are factored functions, so they are driven
# from fixtures with no GitHub — the same technique test-remote-enforcement.sh
# uses for the enforcement verdict. The verb's own not-assessed paths are
# driven through the binary.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # load di_grade / di_classify (dispatch is source-guarded)

repo="$WORK/repo"
make_repo "$repo"
cd "$repo"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

NONE="docs-impact:none"
REF="docs-impact:reference"
PUB="docs-impact:public"
OPS="docs-impact:operator"
ARCH="docs-impact:architecture"
ROAD="docs-impact:roadmap"
REL="docs-impact:release"
COMP="docs-impact:companion"

# grade <declared> <governed> — sets GRADE_VERDICT / GRADE_DETAIL / GRADE_RC.
# Called DIRECTLY, never through $( ): a command substitution runs in a
# subshell, so the exit code and detail would be discarded and a broken
# assertion would read as a pass.
GRADE_VERDICT="" GRADE_DETAIL="" GRADE_RC=0
grade() {
  local out rc=0 tab
  tab="$(printf '\t')"
  out="$(di_grade "$1" "$2" "$NONE")" || rc=$?
  GRADE_VERDICT="${out%%${tab}*}"
  GRADE_DETAIL="${out#*${tab}}"
  GRADE_RC="$rc"
}

model="$(resolve_governance)"
# classes <newline-separated paths> — the governed classes those paths change.
classes() {
  printf '%s\n' "$1" | di_classify "$model" \
    | awk -F'\t' 'NF{print $1}' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ *$//'
}

# ======================== the grammar, row by row ========================
# no docs-impact label -> FAIL. Silence is never "none".
grade "" "$REF"
assert_eq "no disposition fails" "FAIL" "$GRADE_VERDICT"
assert_eq "and exits non-zero" 1 "$GRADE_RC"
assert_contains "explaining that silence is not none" "silence is never" "$GRADE_DETAIL"

# ...and it fails even when nothing changed. The omission is what fails, not
# the absence of a documentation change.
grade "" ""
assert_eq "no disposition fails even with no docs change" "FAIL" "$GRADE_VERDICT"

# none + any other value -> INVALID -> FAIL
grade "$NONE $REF" ""
assert_eq "none combined with another value is invalid" "FAIL" "$GRADE_VERDICT"
assert_contains "and says INVALID" "INVALID" "$GRADE_DETAIL"
assert_eq "invalid exits non-zero" 1 "$GRADE_RC"
grade "$REF $NONE" ""
assert_eq "order does not matter for the invalid combination" "FAIL" "$GRADE_VERDICT"

# none + nothing changed -> PASS
grade "$NONE" ""
assert_eq "none with no governed change passes" "PASS" "$GRADE_VERDICT"
assert_eq "and exits zero" 0 "$GRADE_RC"

# none + a governed class changed -> FAIL
grade "$NONE" "$REF"
assert_eq "none contradicted by a governed change fails" "FAIL" "$GRADE_VERDICT"
assert_contains "naming what changed" "$REF" "$GRADE_DETAIL"
assert_eq "the contradiction exits non-zero" 1 "$GRADE_RC"

# every declared class has evidence -> PASS
grade "$REF" "$REF"
assert_eq "a satisfied single declaration passes" "PASS" "$GRADE_VERDICT"
grade "$REF $ARCH" "$ARCH $REF"
assert_eq "multiple satisfied declarations pass" "PASS" "$GRADE_VERDICT"
assert_eq "and exit zero" 0 "$GRADE_RC"

# a declared class with no evidence -> FAIL
grade "$REF $ARCH" "$REF"
assert_eq "an unsatisfied declaration fails" "FAIL" "$GRADE_VERDICT"
assert_contains "naming the unsatisfied class" "$ARCH" "$GRADE_DETAIL"
assert_eq "unsatisfied exits non-zero" 1 "$GRADE_RC"

# an ADDITIONAL governed class beyond an otherwise valid declaration -> WARN
grade "$REF" "$REF $ROAD"
assert_eq "an additional undeclared class warns" "WARN" "$GRADE_VERDICT"
assert_contains "naming the extra class" "$ROAD" "$GRADE_DETAIL"
assert_eq "a warning does not fail the build" 0 "$GRADE_RC"

# WARN is NOT a general "docs changed but nothing declared" escape hatch: that
# case is an undeclared issue, which fails.
grade "" "$REF $ROAD"
assert_eq "undeclared plus changes is a FAIL, never a WARN" "FAIL" "$GRADE_VERDICT"

# Exclusivity is DATA, not a rule baked into the grader: with no exclusive
# member declared, the same declaration is judged by the ordinary rows instead
# of being rejected as invalid.
rc=0; out="$(di_grade "$NONE $REF" "" "")" || rc=$?
assert_eq "with no exclusive member declared, none is not special" 1 "$rc"
case "$out" in
  *INVALID*) bad "exclusivity must come from schema data, not from the grader" ;;
  *) ok ;;
esac
assert_contains "it falls through to the ordinary unsatisfied row" \
  "no qualifying evidence" "$out"

# ======================== classification from schema data ================
assert_eq "a reference doc classifies as reference" "$REF" \
  "$(classes 'plugins/spark/docs/reference/cli.md')"
assert_eq "an ADR classifies as architecture" "$ARCH" "$(classes 'docs/adr/0030-x.md')"
assert_eq "the internals map classifies as architecture" "$ARCH" \
  "$(classes 'docs/architecture/overview.md')"
assert_eq "the roadmap classifies as roadmap" "$ROAD" "$(classes 'ROADMAP.md')"
assert_eq "an explanation doc classifies as public" "$PUB" \
  "$(classes 'plugins/spark/docs/explanation/identity.md')"
assert_eq "a how-to classifies as public" "$PUB" "$(classes 'plugins/spark/docs/how-to/x.md')"
assert_eq "a tutorial classifies as public" "$PUB" "$(classes 'plugins/spark/docs/tutorials/x.md')"
assert_eq "the repo README classifies as public" "$PUB" "$(classes 'README.md')"
# The shipped docs README is a separate mapping from the repo README, and #483
# requires `public` to cover the WHOLE shipped non-reference user-doc set — not
# the four quadrants minus their index page.
assert_eq "the shipped docs README classifies as public" "$PUB" \
  "$(classes 'plugins/spark/docs/README.md')"
assert_eq "a release record classifies as release" "$REL" "$(classes 'docs/releases/v0.21.md')"
assert_eq "an ops runbook classifies as operator" "$OPS" \
  "$(classes 'docs/ops/release-conventions.md')"

# Code is not governed documentation.
assert_eq "a script is not governed" "" "$(classes 'plugins/spark/bin/spark')"
assert_eq "a test is not governed" "" "$(classes 'tests/test-docs-impact.sh')"
# CHANGELOG.md is generated by Release Please and hand-editing it is forbidden,
# so it can never be a declarable documentation impact.
assert_eq "CHANGELOG is deliberately not governed" "" "$(classes 'CHANGELOG.md')"
# An exact-file mapping must not match a path that merely starts with it.
assert_eq "ROADMAP.md.bak is not the roadmap" "" "$(classes 'ROADMAP.md.bak')"
# A directory mapping must not match a sibling with a longer name.
assert_eq "docs/adrenaline/ is not docs/adr/" "" "$(classes 'docs/adrenaline/x.md')"

# ======================== core vs companion distinctness ================
assert_eq "a companion doc classifies as companion, not reference" "$COMP" \
  "$(classes 'plugins/spark-audit/docs/x.md')"
assert_eq "every companion has its surface declared" "$COMP" \
  "$(classes 'plugins/spark-connect/docs/x.md')"
assert_eq "spark-docs too" "$COMP" "$(classes 'plugins/spark-docs/docs/x.md')"
# The surface column is what keeps them apart mechanically, not convention.
assert_eq "core reference carries the core surface" "core" \
  "$(printf 'plugins/spark/docs/reference/cli.md\n' | di_classify "$model" | awk -F'\t' '{print $2}')"
assert_eq "a companion doc carries the companion surface" "companion" \
  "$(printf 'plugins/spark-audit/docs/x.md\n' | di_classify "$model" | awk -F'\t' '{print $2}')"

# A companion change cannot satisfy a core declaration...
grade "$REF" "$(classes 'plugins/spark-audit/docs/x.md')"
assert_eq "a companion change does not satisfy a core reference declaration" "FAIL" "$GRADE_VERDICT"
# ...and a core change cannot satisfy a companion declaration.
grade "$COMP" "$(classes 'plugins/spark/docs/reference/cli.md')"
assert_eq "a core change does not satisfy a companion declaration" "FAIL" "$GRADE_VERDICT"
# Declaring both, with evidence for both, passes.
grade "$REF $COMP" "$(classes 'plugins/spark/docs/reference/cli.md
plugins/spark-audit/docs/x.md')"
assert_eq "declaring both surfaces with evidence for both passes" "PASS" "$GRADE_VERDICT"
# A companion change under a `none` declaration is still a contradiction — it
# must not be invisible just because the core vocabulary cannot describe it.
grade "$NONE" "$(classes 'plugins/spark-audit/docs/x.md')"
assert_eq "a companion change contradicts a none declaration" "FAIL" "$GRADE_VERDICT"

# ======================== aggregate evidence ============================
# The union of the whole evidence set is judged, not one PR at a time — so
# documentation that landed in an EARLIER PR of the same issue must not
# false-fail. Modelled here as the aggregated path set the verb builds.
earlier_pr='plugins/spark/docs/reference/cli.md'
later_pr='plugins/spark/bin/spark
tests/test-docs-impact.sh'
grade "$REF" "$(classes "$earlier_pr
$later_pr")"
assert_eq "docs in an earlier PR still satisfy the declaration" "PASS" "$GRADE_VERDICT"
# Judging the later PR alone would have failed — the defect the aggregate
# exists to prevent.
grade "$REF" "$(classes "$later_pr")"
assert_eq "the later PR alone would have failed" "FAIL" "$GRADE_VERDICT"

# ======================== the schema owns all of it =====================
# Not one of these rules may be a constant in the validator.
assert_contains "the family is schema data" "$(printf 'family\tdocs-impact\tany\trequired')" "$model"
assert_contains "the exclusive member is schema data" \
  "$(printf 'exclusive\tdocs-impact\t%s\t' "$NONE")" "$model"
assert_contains "the path mapping is schema data" \
  "$(printf 'pathclass\tdocs-impact\t%s\tcore\tplugins/spark/docs/reference/' "$REF")" "$model"
for m in "$NONE" "$PUB" "$REF" "$OPS" "$ARCH" "$ROAD" "$REL" "$COMP"; do
  assert_contains "member $m is declared" "$(printf 'member\tdocs-impact\t%s\t' "$m")" "$model"
done

# A project can re-point a class's paths, because pathclass is a replaceable
# SET like member — otherwise an overlay could only ever add a path.
mkdir -p "$repo/.spark"
{ printf 'version\t1\n'
  printf 'pathclass\tdocs-impact\t%s\tcore\thandbook/\n' "$REF"
} > "$repo/.spark/governance.tsv"
model2="$(resolve_governance)"
classes2() {
  printf '%s\n' "$1" | di_classify "$model2" \
    | awk -F'\t' 'NF{print $1}' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ *$//'
}
assert_eq "a project overlay re-points a class" "$REF" "$(classes2 'handbook/x.md')"
assert_eq "and the shipped path stops matching" "" "$(classes2 'plugins/spark/docs/reference/cli.md')"
assert_eq "untouched classes keep their shipped paths" "$ARCH" "$(classes2 'docs/adr/0030-x.md')"
rm -f "$repo/.spark/governance.tsv"

# An absolute or traversing pathclass must fail closed: a governed path that
# escapes the repo can never match a repo-relative changed path anyway.
printf 'version\t1\npathclass\tdocs-impact\t%s\tcore\t/etc/\n' "$REF" > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" governance --tsv 2>&1)" || rc=$?
assert_rc "an absolute pathclass fails closed" 1 "$rc"
assert_contains "and says why" "must be repo-relative" "$out"
rm -f "$repo/.spark/governance.tsv"

# Replacing the member set supersedes the lower tier's rules for the members it
# dropped: they are pruned, not fatal. Narrowing is the whole reason member
# sets replace rather than merge, so it must not brick the model.
printf 'version\t1\nmember\tdocs-impact\tdi-other\t444444\tReplaces the whole set\n' \
  > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" governance --tsv 2>&1)" || rc=$?
assert_rc "a wholesale member replacement resolves" 0 "$rc"
assert_eq "the shipped rules for dropped members are pruned" "" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$1=="pathclass" || $1=="exclusive"')"
assert_contains "and the replacement member is what resolves" \
  "$(printf 'member\tdocs-impact\tdi-other\t444444\t')" "$out"
rm -f "$repo/.spark/governance.tsv"

# A pathclass naming a member no family declares is not closed — and because it
# is declared ABOVE the tier that owns the member set, it is a typo rather than
# something a narrowing superseded.
printf 'version\t1\npathclass\tdocs-impact\tdocs-impact:invented\tcore\tx/\n' \
  > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" governance --tsv 2>&1)" || rc=$?
assert_rc "a pathclass for an undeclared member fails closed" 1 "$rc"
assert_contains "naming the member" "docs-impact:invented" "$out"
rm -f "$repo/.spark/governance.tsv"

# ====== narrowing a family must stay possible (the documented escape) ======
# Member sets replace rather than merge precisely so a tier can REMOVE a
# member. But the shipped tier's pathclass and exclusive rows still name the
# dropped members, and treating those as fatal made narrowing brick the model
# with no way out — declaring a replacement rule for a member that no longer
# exists is itself unclosed.
mkdir -p "$repo/.spark"
{ printf 'version\t1\n'
  printf 'member\tdocs-impact\t%s\tc5def5\tNone\n' "$NONE"
  printf 'member\tdocs-impact\t%s\t1d76db\tReference\n' "$REF"
} > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" governance --tsv 2>&1)" || rc=$?
assert_rc "narrowing a family resolves" 0 "$rc"
narrowed="$(printf '%s\n' "$out" | awk -F'\t' '$1=="member" && $2=="docs-impact"{printf "%s%s", s, $3; s=" "}')"
assert_eq "the narrowed member set is what resolves" "$NONE $REF" "$narrowed"
# The orphaned rules are DROPPED, not fatal, and the surviving ones are kept.
orphans="$(printf '%s\n' "$out" | awk -F'\t' '$1=="pathclass" && $3!="'"$REF"'"{print}')"
assert_eq "pathclass rows for dropped members are gone" "" "$orphans"
assert_contains "the surviving class keeps its paths" \
  "$(printf 'pathclass\tdocs-impact\t%s\tcore\tplugins/spark/docs/reference/' "$REF")" "$out"
assert_contains "the exclusive rule survives with its member" \
  "$(printf 'exclusive\tdocs-impact\t%s\t' "$NONE")" "$out"
# And the verb is usable against the narrowed model rather than stuck.
rc=0; "$SPARK" docs-impact --issue 1 --paths "$WORK/ev" >/dev/null 2>&1 || rc=$?
assert_rc "the verb still runs against a narrowed model" 3 "$rc"
rm -f "$repo/.spark/governance.tsv"

# A SECOND family's pathclass must classify, with no code that knows about
# `docs-impact`. The existing coverage proves a foreign family's BROKEN
# pathclass fails closed; that is the error path. This is the success path — the
# actual extensibility claim, which a fail-closed test cannot make.
{ printf 'version\t1\n'
  printf 'family\tmirror\tany\toptional\tA second family, data only\n'
  printf 'member\tmirror\tmirror:docs\t222222\tDocs\n'
  printf 'pathclass\tmirror\tmirror:docs\tcore\tplugins/spark/docs/\n'
} > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" governance --tsv 2>&1)" || rc=$?
assert_rc "a second family with its own pathclass resolves" 0 "$rc"
gm="$(printf '%s\n' "$out" | awk -F'\t' 'NF { NF--; print }' OFS='\t')"
assert_eq "and its mapping classifies a path under it" "mirror:docs" \
  "$(printf '%s\n' 'plugins/spark/docs/reference/cli.md' | di_classify "$gm" \
     | awk -F'\t' '$1 ~ /^mirror:/ { print $1 }' | head -1)"
assert_eq "while docs-impact still classifies the same path too" "$REF" \
  "$(printf '%s\n' 'plugins/spark/docs/reference/cli.md' | di_classify "$gm" \
     | awk -F'\t' '$1 ~ /^docs-impact:/ { print $1 }' | head -1)"
rm -f "$repo/.spark/governance.tsv"

# A genuine SAME-TIER typo must still fail closed — dropping superseded rules
# must not become a general amnesty for rules that name nothing.
{ printf 'version\t1\n'
  printf 'family\tmine\tany\toptional\tMine\n'
  printf 'member\tmine\tmine:a\t111111\tA\n'
  printf 'pathclass\tmine\tmine:typo\tcore\tx/\n'
} > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" governance --tsv 2>&1)" || rc=$?
assert_rc "a same-tier typo still fails closed" 1 "$rc"
assert_contains "naming the typo" "mine:typo" "$out"
rm -f "$repo/.spark/governance.tsv"

# A family may declare at most one exclusive member: a consumer can act on only
# one, so a second would validate and then be silently ignored, accepting a
# combination the schema appears to forbid.
{ printf 'version\t1\n'
  printf 'family\tmine\tany\toptional\tMine\n'
  printf 'member\tmine\tmine:a\t111111\tA\n'
  printf 'member\tmine\tmine:b\t222222\tB\n'
  printf 'exclusive\tmine\tmine:a\tA is exclusive\n'
  printf 'exclusive\tmine\tmine:b\tB too\n'
} > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" governance --tsv 2>&1)" || rc=$?
assert_rc "a second exclusive member is rejected" 1 "$rc"
assert_contains "and says a family may declare at most one" "at most one" "$out"
rm -f "$repo/.spark/governance.tsv"

# ======================== not assessed, never PASS ======================
di_na() { # <desc> <args...>
  local desc="$1"; shift
  local out rc=0
  out="$("$SPARK" docs-impact "$@" 2>&1)" || rc=$?
  assert_rc "$desc exits 3" 3 "$rc"
  assert_contains "$desc says NOT ASSESSED" "NOT ASSESSED" "$out"
}
printf 'plugins/spark/docs/reference/x.md\n' > "$WORK/ev"
# No issue number anywhere: the sandbox repo is on master, not a feat/N branch.
di_na "an unresolvable issue number" --paths "$WORK/ev"
# A missing evidence file.
di_na "a missing evidence file" --issue 1 --paths "$WORK/nope.txt"
# No gh auth — the declaration lives on the issue, so it cannot be answered.
di_na "no authenticated gh" --issue 1 --paths "$WORK/ev"

# The issue number is taken from the branch name when not given, using the same
# feat/<n>-slug convention codify creates.
git -C "$repo" checkout -q -b feat/4242-something
out="$("$SPARK" docs-impact --paths "$WORK/ev" 2>&1)" || true
assert_contains "the issue number comes from the branch name" "#4242" "$out"
git -C "$repo" checkout -q master

# An unresolvable governance model must not silently grade anything.
mkdir -p "$repo/.spark"
printf 'version\t1\nnonsense\tx\ty\n' > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" docs-impact --issue 1 --paths "$WORK/ev" 2>&1)" || rc=$?
assert_rc "an unresolvable model is not assessed" 3 "$rc"
assert_contains "and names the finding" "unknown record type nonsense" "$out"
rm -f "$repo/.spark/governance.tsv"

# ====== --tsv carries records only ======================================
# stdout is sold as stable records for CI and skills, so a coloured prose line
# in the middle of it is a garbage row to whatever is parsing.
mkdir -p "$repo/.spark"
printf 'version\t1\nnonsense\tx\ty\n' > "$repo/.spark/governance.tsv"
tsv_out="$("$SPARK" docs-impact --issue 1 --paths "$WORK/ev" --tsv 2>/dev/null)" || true
case "$tsv_out" in
  *$'\033'*) bad "--tsv stdout must carry no ANSI escapes" ;;
  *) ok ;;
esac
bad_rows="$(printf '%s\n' "$tsv_out" | awk -F'\t' 'NF && $1 !~ /^(issue|declared|evidence|evidence-note|governed|verdict)$/ { print }')"
assert_eq "--tsv emits only known record types" "" "$bad_rows"
assert_contains "and still reports the verdict" "verdict	NOT ASSESSED" "$tsv_out"
rm -f "$repo/.spark/governance.tsv"

# ======================== read-only by construction =====================
before="$(git -C "$repo" status --porcelain)"
"$SPARK" docs-impact --issue 1 --paths "$WORK/ev" >/dev/null 2>&1 || true
"$SPARK" docs-impact --issue 1 --branch >/dev/null 2>&1 || true
after="$(git -C "$repo" status --porcelain)"
assert_eq "spark docs-impact writes nothing" "$before" "$after"

finish
