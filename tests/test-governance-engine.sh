#!/usr/bin/env bash
# Behavioral suite for the governance engine (#471): the row generators behind
# inspect / diff / apply / validate, and the safety boundary that separates
# what Spark may create from what it must only report.
#
# The generators are pure functions, driven from fixtures with no GitHub — the
# same technique test-remote-enforcement.sh uses. The verb's read-only and
# idempotence properties are driven through the binary.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # load gov_label_rows / gov_issue_rows / gov_cycle_rows (source-guarded)

repo="$WORK/repo"
make_repo "$repo"
cd "$repo"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

model="$(resolve_governance)"
TAXO="feature bug documentation chore tech-debt research infrastructure"

# row <rows> <name> -> the status character for that id
row() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '$3 == n { print $2; exit }'; }
det() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '$3 == n { print $4; exit }'; }

# ======================== the label surface ========================
# Live labels as name/colour/description, the shape the remote returns.
live="$(printf 'feature\t0e8a16\tNew capability or user-visible behaviour\n')"
rows="$(gov_label_rows "$model" "$live" "$TAXO")"
assert_eq "a label matching the model is correct" "=" "$(row "$rows" feature)"
assert_eq "a label absent from the remote is missing" "+" "$(row "$rows" bug)"
assert_contains "and says what it would create" "would be created #d73a4a" "$(det "$rows" bug)"

# Colour drift is repairable, not missing and not correct.
live="$(printf 'feature\ta2eeef\tNew capability or user-visible behaviour\n')"
rows="$(gov_label_rows "$model" "$live" "$TAXO")"
assert_eq "colour drift is reported as drift" "~" "$(row "$rows" feature)"
assert_contains "naming both colours" "colour #a2eeef, model declares #0e8a16" "$(det "$rows" feature)"

# Description drift too.
live="$(printf 'feature\t0e8a16\tSomething else entirely\n')"
rows="$(gov_label_rows "$model" "$live" "$TAXO")"
assert_eq "description drift is reported as drift" "~" "$(row "$rows" feature)"
assert_contains "naming the description" "description differs" "$(det "$rows" feature)"

# GitHub echoes colours upper-case while the schema declares them lower-case.
# Treating that as drift would report every correct label as broken.
live="$(printf 'feature\t0E8A16\tNew capability or user-visible behaviour\n')"
rows="$(gov_label_rows "$model" "$live" "$TAXO")"
assert_eq "an upper-case colour is not drift" "=" "$(row "$rows" feature)"

# Every governed family is covered, not just the taxonomy — the omission that
# left docs-impact and the theme labels unprovisioned.
rows="$(gov_label_rows "$model" "$(printf 'x\tffffff\tx\n')" "$TAXO")"
for l in feature P0 P1 P2 P3 decision human-approval backlog \
         docs-impact:none docs-impact:reference docs-impact:companion; do
  assert_eq "the label surface covers $l" "+" "$(row "$rows" "$l")"
done

# Category NAMES come from the taxonomy, so extending it is picked up, and a
# category the model does not declare still resolves rather than breaking.
rows="$(gov_label_rows "$model" "$(printf 'x\tffffff\tx\n')" "$TAXO invented")"
assert_eq "an added category appears on the label surface" "+" "$(row "$rows" invented)"
assert_contains "with the neutral fallback colour" "#ededed" "$(det "$rows" invented)"

# ======================== per-issue metadata ========================
# "<number>\t<labels csv>\t<milestone>"
iss() { gov_issue_rows "$model" "$1"; }

# A clean, fully-declared active issue reports itself CORRECT rather than
# reporting nothing: emitting no row made the summary say "=0", which reads as
# "not one issue is correct" instead of "every issue is".
clean="$(printf '10\tfeature,P1,docs-impact:none\tv0.21 — Governance as schema\n')"
out="$(iss "$clean")"
assert_eq "a fully-declared active issue is reported correct" "=" "$(row "$out" "#10")"
assert_eq "and raises no finding" "" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$2 == "!"')"

# Two categories is invalid whether or not the work is scheduled.
two="$(printf '11\tfeature,bug,docs-impact:none\tv0.21 — Governance as schema\n')"
out="$(iss "$two")"
assert_contains "two categories is reported" "category allows exactly-one but 2 are set" "$out"
assert_contains "naming both" "feature bug" "$out"
# ...and Spark must NOT choose between them.
case "$out" in
  *"should be"*|*"use feature"*|*"correct label is"*) bad "Spark must not choose which category is meant" ;;
  *) ok ;;
esac
two_backlog="$(printf '12\tfeature,bug,backlog\t\n')"
assert_contains "two categories is invalid in the backlog too" \
  "exactly-one but 2 are set" "$(iss "$two_backlog")"

# A required family is demanded of ACTIVE work — work with a release decision.
noimpact_active="$(printf '13\tfeature,P1\tv0.21 — Governance as schema\n')"
assert_contains "an active issue must declare a required family" \
  "docs-impact is required and none is declared" "$(iss "$noimpact_active")"
# ...but not of an idea nobody has scheduled yet.
noimpact_backlog="$(printf '14\tfeature,backlog\t\n')"
out="$(iss "$noimpact_backlog")"
case "$out" in
  *"docs-impact is required"*) bad "a backlog issue must not be failed for an undecided disposition" ;;
  *) ok ;;
esac

# The exclusive member is honoured generically.
excl="$(printf '15\tfeature,docs-impact:none,docs-impact:reference\tv0.21 — Governance as schema\n')"
assert_contains "an exclusive value combined with another is reported" \
  "is exclusive but is combined with another" "$(iss "$excl")"

# Every issue needs a release disposition: a milestone, or an explicit backlog.
nodisp="$(printf '16\tfeature,docs-impact:none\t\n')"
assert_contains "no release decision is reported" \
  "no release disposition" "$(iss "$nodisp")"
assert_eq "a backlog label is a release decision" "" \
  "$(iss "$(printf '17\tfeature,backlog\t\n')" | grep 'release disposition' || true)"
# Membership, not a substring: a label that merely CONTAINS the word must not
# satisfy the decision on an issue carrying no disposition member at all.
assert_contains "a backlog-like label does not satisfy the disposition" \
  "no release disposition" "$(iss "$(printf '19\tfeature,needs-backlog\t\n')")"

# An optional family missing is never a finding.
assert_eq "an optional family may be absent" "" \
  "$(iss "$(printf '18\tfeature,docs-impact:none\tv0.21 — Governance as schema\n')" \
    | awk -F'\t' '$2 == "!"')"

# The fallback description for a member the model does not declare has ONE
# definition. Two writers disagreeing on it meant a label created by
# `spark labels` was immediately reported drifted by the governance surface,
# forever, and `--repair-drift` would then rewrite it.
created_desc="$(taxonomy_label_desc spike "$model")"
rows="$(gov_label_rows "$model" \
  "$(printf 'spike\tededed\t%s\n' "$created_desc")" "feature spike")"
assert_eq "a label created by spark labels is not reported drifted" "=" "$(row "$rows" spike)"

# ======================== dependency cycles ========================
# "<issue>\t<blocker>" — issue is blocked BY blocker.
assert_eq "a chain is not a cycle" "" \
  "$(gov_cycle_rows "$(printf '2\t1\n3\t2\n')")"
assert_eq "a diamond is not a cycle" "" \
  "$(gov_cycle_rows "$(printf '2\t1\n3\t1\n4\t2\n4\t3\n')")"
out="$(gov_cycle_rows "$(printf '1\t2\n2\t1\n')")"
assert_contains "a two-issue cycle is caught" "cannot be started in any order" "$out"
assert_contains "naming both issues" "#1 #2" "$out"
out="$(gov_cycle_rows "$(printf '1\t2\n2\t3\n3\t1\n')")"
assert_contains "a three-issue cycle is caught" "cannot be started in any order" "$out"
assert_contains "naming all three" "#1 #2 #3" "$out"
# Numerically, not lexicographically: "#10" sorts before "#2" as a string, and
# the list then reads as the wrong set of issues.
out="$(gov_cycle_rows "$(printf '1\t2\n2\t10\n10\t1\n')")"
assert_contains "cycle members are ordered numerically" "#1 #2 #10" "$out"
# A self-edge is a cycle of one.
assert_contains "an issue blocked by itself is caught" "cannot be started" \
  "$(gov_cycle_rows "$(printf '5\t5\n')")"
# An issue hanging off a cycle is stuck too, and saying so is the point.
out="$(gov_cycle_rows "$(printf '1\t2\n2\t1\n9\t1\n')")"
assert_contains "work behind a cycle is reported with it" "#9" "$out"

# ======================== governance files ========================
assert_contains "a missing human-owned surface is judgment, not a create" \
  "$(printf 'file\t!\t')" "$(gov_file_rows "$model" "$repo")"
mkdir -p "$repo/.github"
: > "$repo/.github/PULL_REQUEST_TEMPLATE.md"
out="$(gov_file_rows "$model" "$repo")"
assert_eq "any declared spelling satisfies its kind" "=" "$(row "$out" ".github/PULL_REQUEST_TEMPLATE.md")"
# ...and the lower-case spelling works just as well.
rm -f "$repo/.github/PULL_REQUEST_TEMPLATE.md"
: > "$repo/.github/pull_request_template.md"
out="$(gov_file_rows "$model" "$repo")"
assert_eq "the other spelling satisfies it too" "=" "$(row "$out" ".github/pull_request_template.md")"
rm -f "$repo/.github/pull_request_template.md"
# The label surface is not duplicated as a file.
assert_eq "github-labels is not treated as a file" "" \
  "$(gov_file_rows "$model" "$repo" | awk -F'\t' '$3 == "github-labels"')"

# ======================== the verb's own contract ========================
# inspect and diff are read-only: no local write, and without gh they report
# not-assessed rather than a clean pass.
before="$(git -C "$repo" status --porcelain)"
rc=0; out="$("$SPARK" governance inspect 2>&1)" || rc=$?
assert_rc "inspect runs without gh" 0 "$rc"
assert_contains "and reports not assessed rather than healthy" "not assessed" "$out"
rc=0; out="$("$SPARK" governance diff 2>&1)" || rc=$?
assert_rc "diff runs without gh" 0 "$rc"
assert_contains "diff says nothing was written" "Nothing was written" "$out"
assert_contains "and that a judgment row is never applied" "never applied" "$out"
after="$(git -C "$repo" status --porcelain)"
assert_eq "inspect and diff write nothing" "$before" "$after"

# validate must never report PASS from surfaces it could not read. The finding
# here is an ABSENT HUMAN-PROVISIONED file surface, which is an owed decision
# rather than broken state, so the verdict is DECISION REQUIRED (exit 5) — and
# the report still has to admit the picture is partial rather than implying it
# looked everywhere. Before #559 this reported "mechanically invalid", which is
# false by the row alphabet's own legend and made writing the judgment the
# cheapest route to green.
rc=0; out="$("$SPARK" governance validate 2>&1)" || rc=$?
assert_rc "an owed decision is DECISION REQUIRED even with unread surfaces" 5 "$rc"
assert_contains "and says which outcome it is" "DECISION REQUIRED" "$out"
assert_contains "and admits the picture is partial" "could not be read" "$out"
assert_contains "and never claims the state is mechanically invalid" \
  "nothing is mechanically wrong" "$out"
case "$out" in *PASS*) bad "validate must never PASS on unread surfaces" ;; *) ok ;; esac
# The ROW status is unchanged — `!`, not `+`. #535 owns whether that alphabet
# should grow; #559 moved only the verdict. If this flips, the two issues have
# been conflated.
assert_contains "the row stays judgment, not a create" \
  "$(printf 'file\t!\t')" "$("$SPARK" governance inspect --tsv 2>&1)"

# With no findings left but surfaces still unread, the verdict is NOT ASSESSED
# — never PASS by assumption.
mkdir -p "$repo/.github"
: > "$repo/.github/PULL_REQUEST_TEMPLATE.md"
: > "$repo/release-please-config.json"
mkdir -p "$repo/.github/ISSUE_TEMPLATE"
rc=0; out="$("$SPARK" governance validate 2>&1)" || rc=$?
assert_rc "unread surfaces alone are not assessed" 3 "$rc"
assert_contains "and say so" "NOT ASSESSED" "$out"
case "$out" in *PASS*) bad "validate must never PASS on unread surfaces" ;; *) ok ;; esac
rm -rf "$repo/.github" "$repo/release-please-config.json"

# apply must NEVER report a clean surface it did not read. Without this guard
# an unauthenticated gh emptied the create list and apply announced that every
# surface matched a model it had not compared — the one invariant this whole
# capability rests on, inverted.
rc=0; out="$("$SPARK" governance apply --yes 2>&1)" || rc=$?
assert_rc "apply is not assessed when a surface is unread" 3 "$rc"
assert_contains "and says so" "NOT ASSESSED" "$out"
case "$out" in
  *"already matches the model"*) bad "apply must not claim a surface it never read" ;;
  *) ok ;;
esac
after="$(git -C "$repo" status --porcelain)"
assert_eq "apply writes nothing when it cannot assess" "$before" "$after"

# A DELIBERATE deferral is not an unknown. Emitting the trunk policy as `?`
# meant apply — which refuses on an unread surface — could never act again, and
# validate reported NOT ASSESSED forever. `>` says "assessed elsewhere".
rc=0; out="$("$SPARK" governance inspect --tsv 2>&1)" || rc=$?
assert_contains "the deferred surface uses its own status" \
  "$(printf 'ruleset\t>\t')" "$out"
assert_contains "and names the verb that owns it" "spark doctor --requirements" "$out"
# apply must not be disabled by a surface it does not act on.
rc=0; out="$("$SPARK" governance apply --yes 2>&1)" || rc=$?
case "$out" in
  *"nothing can be applied safely"*)
    # Only legitimate when the LABEL surface itself is unread.
    assert_contains "a refusal names the label surface" "label surface" "$out" ;;
  *) ok ;;
esac

# Every surface appears in every report: a reader must be able to tell "no
# cycles" from "never looked", which a missing row cannot express.
rc=0; out="$("$SPARK" governance inspect --tsv 2>&1)" || rc=$?
for s in label metadata dependency ruleset file; do
  assert_contains "the $s surface is always reported" "$s" \
    "$(printf '%s\n' "$out" | awk -F'\t' '{print $1}' | sort -u | tr '\n' ' ')"
done

# diff must not promise something apply does not do.
out="$("$SPARK" governance diff 2>&1)"
assert_contains "diff scopes its advice to labels" "missing LABELS" "$out"
assert_contains "and names where file surfaces come from" "spark setup" "$out"

# The bare verb still renders the model — the compatibility surface #471 builds
# on rather than replaces.
rc=0; out="$("$SPARK" governance --tsv 2>&1)" || rc=$?
assert_rc "the bare render still works" 0 "$rc"
assert_contains "and still emits records" "$(printf 'family\tcategory\t')" "$out"

# The verb's own help must describe its subcommands, or they are undiscoverable.
out="$("$SPARK" governance --help 2>&1)"
for s in inspect diff apply validate; do
  assert_contains "help describes $s" "$s" "$out"
done

# An unknown subcommand is an error, not a silent fallthrough to the render.
rc=0; out="$("$SPARK" governance --nonsense 2>&1)" || rc=$?
assert_rc "an unknown option fails" 1 "$rc"

# ======================== one authority ========================
# `spark labels` is a compatibility wrapper over the same generator. Whatever
# it calls missing, the label surface must also call missing.
rows="$(gov_label_rows "$model" "$(printf 'feature\t0e8a16\tNew capability or user-visible behaviour\n')" "$TAXO")"
assert_eq "the shared generator drives both" "+" "$(row "$rows" chore)"
assert_eq "and agrees on what exists" "=" "$(row "$rows" feature)"

finish
