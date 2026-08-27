#!/usr/bin/env bash
# #470's acceptance contract, executable.
#
# #470 was closed once and the closure was falsified: three-tier resolution was
# not deterministic, because two `exclusive` rows for one family survived
# layering and consumers then read different ones. The re-audit that reopened it
# was a one-off script; this file is that audit made permanent, so the contract
# can be re-checked rather than re-argued.
#
# The standard it is written to: a grep for a function name, a comment string, a
# command name or a documentation phrase is NOT evidence that a property holds.
# Every assertion below is either behaviour that MOVES when the schema data
# moves, or an observed fail-closed. Where a check could pass trivially, a
# negative control sits beside it.
#
# Measured discrimination, not asserted: restoring the per-member `exclusive`
# key turns 5 of the 21 red, and putting a category colour back into a hard-coded
# case statement beside the schema turns 1 red.
#
# Criteria already covered end-to-end elsewhere are not restated here:
# test-governance-schema.sh owns record grammar and closure,
# test-governance-exclusive.sh owns exclusivity resolution,
# test-next-selection.sh owns selection, and doctor is its own gate.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

repo="$WORK/r"; make_repo "$repo"; cd "$repo"; mkdir -p .spark
OPCONF="$XDG_CONFIG_HOME/spark"; mkdir -p "$OPCONF"
clean() { rm -f .spark/governance.tsv "$OPCONF/governance.tsv" .spark/preferences.json; }
CATS="feature bug documentation chore tech-debt research infrastructure"

# ============ the schema is the authority, not a second description ==========
# The falsifying test for "the hard-coded colours are still duplicated beside
# the schema": override one in the model and require the reconciliation surface
# to follow. A second home would keep reporting the label as correct.
clean
{ printf 'version\t1\n'
  printf 'member\tcategory\tfeature\t0e8a16\tNew capability or user-visible behaviour\n'
  printf 'member\tcategory\tbug\tc0ffee\tOverridden by the project tier\n'
  printf 'member\tcategory\tdocumentation\t0075ca\tDocs, references, and explanatory prose\n'
  printf 'member\tcategory\tchore\tfef2c0\tMaintenance with no behaviour change\n'
  printf 'member\tcategory\ttech-debt\td4c5f9\tDeliberate cleanup of a known compromise\n'
  printf 'member\tcategory\tresearch\t1d76db\tInvestigation whose output is a decision\n'
  printf 'member\tcategory\tinfrastructure\tc2e0c6\tCI, tooling, and delivery plumbing\n'
} > .spark/governance.tsv
model="$(resolve_governance)"
assert_eq "the colour lookup reads the model" c0ffee "$(taxonomy_label_color bug)"
assert_eq "and so does the description" "Overridden by the project tier" \
  "$(taxonomy_label_desc bug)"

live="$(printf 'bug\td73a4a\tSomething behaves other than as documented\n')"
rows="$(gov_label_rows "$model" "$live" "$CATS")"
assert_contains "reconciliation reports drift against the model's colour" c0ffee "$rows"
assert_contains "and names the live colour it found" d73a4a "$rows"
# The negative control: with the model's own colour live, this must NOT be
# drift, or the assertion above would fire on everything and prove nothing.
case "$(gov_label_rows "$model" "$(printf 'bug\tc0ffee\tOverridden by the project tier\n')" bug)" in
  *"$(printf 'label\t~')"*) bad "a label matching the model was reported as drifted" ;;
  *) ok ;;
esac
clean

# ============ nested data never reaches the flat scalar resolver ============
# #470 settled that the model is a structured artifact SELECTED by scalar
# preferences, because `read_flat_json` drops non-scalars. A nested governance
# object in preferences must therefore be inert — neither taking effect nor
# corrupting the model.
printf '{"governance":{"category":{"feature":"ffffff"}}}\n' > .spark/preferences.json
model="$(resolve_governance)"
assert_eq "a nested governance object in preferences is inert" 0e8a16 \
  "$(governance_member_from "$model" category feature 4)"
# ...while the scalar that IS the selector is honoured, and an unknown artifact
# fails closed rather than silently falling back to the shipped one.
printf '{"governance.model":"no-such-model"}\n' > .spark/preferences.json
rc=0; out="$(resolve_governance 2>&1 >/dev/null)" || rc=$?
assert_rc "an unknown governance.model fails closed" 1 "$rc"
assert_contains "naming what it could not find" "no-such-model" "$out"
clean

# ============ the schema holds no project-specific judgment ==================
# Absence in the shipped artifact is necessary but weak; the schema must REFUSE
# a per-issue record, not merely omit one.
printf 'version\t1\nissue\t12\tP0\tan encoded judgment\n' > .spark/governance.tsv
rc=0; out="$(resolve_governance 2>&1 >/dev/null)" || rc=$?
assert_rc "a per-issue record is refused" 1 "$rc"
art="$repo_root/plugins/spark/preferences/governance-models/spark-default.tsv"
if [ -f "$art" ]; then
  n="$(grep -v '^#' "$art" | grep -cP '#[0-9]+' || true)"
  assert_eq "and no shipped RECORD names an issue number" 0 "$n"
else
  bad "the shipped governance artifact was not found at $art"
fi
clean

# ============ pre-schema preference behaviour still governs ==================
# The compatibility promise: `issue.taxonomy` owned the category name set before
# the schema existed and must still own it, including when the schema declares a
# longer list.
printf '{"issue.taxonomy":"feature,bug"}\n' > .spark/preferences.json
assert_eq "issue.taxonomy still resolves the category set" "feature,bug" \
  "$(resolve_issue_taxonomy "$repo")"
clean

# ============ a data-only family is a first-class family ====================
# The extensibility requirement, proven with a family that is neither shipped
# nor `docs-impact`: it exists only as project data, and every governed
# behaviour must apply to it with no schema-code change.
{ printf 'version\t1\n'
  printf 'family\tsurface-risk\texactly-one\trequired\tData-only family\n'
  printf 'member\tsurface-risk\trisk:low\t111111\tLow\n'
  printf 'member\tsurface-risk\trisk:high\t222222\tHigh\n'
  printf 'member\tsurface-risk\trisk:none\t333333\tNone\n'
  printf 'exclusive\tsurface-risk\trisk:none\tnone is exclusive\n'
} > .spark/governance.tsv
model="$(resolve_governance)"
assert_contains "required is enforced for a data-only family" \
  "surface-risk is required" \
  "$(gov_issue_rows "$model" "$(printf '9\tfeature,docs-impact:none\tv1\n')" "$CATS")"
assert_contains "so is its cardinality" "surface-risk allows exactly-one" \
  "$(gov_issue_rows "$model" "$(printf '9\tfeature,risk:low,risk:high,docs-impact:none\tv1\n')" "$CATS")"
assert_contains "and so is its exclusivity" "risk:none is exclusive" \
  "$(gov_issue_rows "$model" "$(printf '9\tfeature,risk:none,risk:low,docs-impact:none\tv1\n')" "$CATS")"
clean

# ============ the falsification does not reproduce ==========================
# Verbatim from #470's reopening: "Two `exclusive` rows for one family survive
# across tiers — the at-most-one check is per-tier — and consumers then
# disagree: cmd_docs_impact reads the first, gov_issue_rows and plan_schema_rows
# read the last." Reproduced exactly, and required to agree.
printf 'version\t1\nexclusive\tdocs-impact\tdocs-impact:companion\tproject override\n' \
  > .spark/governance.tsv
model="$(resolve_governance)"
assert_eq "two tiers yield ONE exclusive row, not two" 1 \
  "$(printf '%s\n' "$model" | awk -F'\t' '$1=="exclusive" && $2=="docs-impact"' | grep -c . || true)"
first="$(printf '%s\n' "$model" | awk -F'\t' '$1=="exclusive" && $2=="docs-impact" {print $3; exit}')"
last="$(printf '%s\n' "$model" | awk -F'\t' '$1=="exclusive" && $2=="docs-impact" {v=$3} END{print v}')"
assert_eq "the first-read and last-read consumers agree" "$first" "$last"
assert_eq "and the override is what is in force" docs-impact:companion "$first"

combo="docs-impact:companion,docs-impact:reference"
assert_contains "gov_issue_rows judges the resolved rule" \
  "docs-impact:companion is exclusive" \
  "$(gov_issue_rows "$model" "$(printf '9\tfeature,%s\tv1\n' "$combo")" "$CATS")"
mkdir -p "$WORK/pb"; echo body > "$WORK/pb/a.md"
printf 'issue\tA\tOne\tfeature,%s\t\t%s\n' "$combo" "$WORK/pb/a.md" > "$WORK/pl.tsv"
assert_contains "plan_schema_rows judges the same one" \
  "docs-impact:companion is exclusive" "$(plan_schema_rows "$model" "$WORK/pl.tsv")"
di_exclusive_violated "docs-impact:companion docs-impact:reference" "$first" \
  && ok || bad "the docs-impact grammar disagreed with the other two consumers"
# An override that still enforces the old value has overridden nothing.
di_exclusive_violated "docs-impact:none docs-impact:reference" "$first" \
  && bad "the superseded shipped member is still enforced" || ok
clean

finish
