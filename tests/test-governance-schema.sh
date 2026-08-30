#!/usr/bin/env bash
# Behavioral suite for the canonical governance schema (#470, ADR-0030):
# default resolution, operator override, project override, whole-set member
# replacement, fail-closed validation, and the separation of dependency from
# delivery order. Drives the shipped binary in a sandbox, and sources it for
# the factored resolver functions.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"   # load resolve_governance and the taxonomy seams (dispatch is source-guarded)

repo="$WORK/repo"
make_repo "$repo"
cd "$repo"

gov() { "$SPARK" governance "$@"; }

# Exact-match assertion. Local to this suite: the shared lib carries exit-code
# and substring asserts, and several checks here are about a value being
# EXACTLY something (an empty member set after replacement, a declaration
# order), where a substring match would pass on a superset.
assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

# Every case runs a fresh binary, so no fixture's model leaks into the next.

# ======================== default resolution ========================
rc=0; out="$(gov --tsv)" || rc=$?
assert_rc "default model resolves" 0 "$rc"
assert_contains "declares its schema version" "$(printf 'version\t1\tdefault')" "$out"
assert_contains "declares the shipped model id" "model	spark-default" "$out"

# The category family carries the shipped colours that used to be hard-coded
# in bin/spark — the schema owns them now, so they must come from here.
assert_contains "category family is exactly-one and required" \
  "$(printf 'family\tcategory\texactly-one\trequired')" "$out"
assert_contains "feature carries its shipped colour" \
  "$(printf 'member\tcategory\tfeature\t0e8a16')" "$out"
assert_contains "tech-debt carries its shipped colour" \
  "$(printf 'member\tcategory\ttech-debt\td4c5f9')" "$out"

# Every shipped category is present, and every record names its tier.
for cat in feature bug documentation chore tech-debt research infrastructure; do
  assert_contains "category $cat resolves from the default tier" \
    "$(printf 'member\tcategory\t%s\t' "$cat")" "$out"
done
missing_source="$(printf '%s\n' "$out" | awk -F'\t' '$NF != "default" { print }')"
assert_eq "every default-tier record names its source" "" "$missing_source"

# ======================== the required model ========================
assert_contains "priority family exists" "$(printf 'family\tpriority\t')" "$out"
for p in P0 P1 P2 P3; do
  assert_contains "priority $p is declared" "$(printf 'member\tpriority\t%s\t' "$p")" "$out"
done
assert_contains "theme family is orthogonal (any)" \
  "$(printf 'family\ttheme\tany\toptional')" "$out"
assert_contains "decision is a theme, not a category" \
  "$(printf 'member\ttheme\tdecision\t')" "$out"
assert_contains "human-approval is a theme" \
  "$(printf 'member\ttheme\thuman-approval\t')" "$out"
assert_contains "milestone is release scope" \
  "$(printf 'structure\tscope\tmilestone\tauthoritative')" "$out"
assert_contains "hierarchy is parent/sub-issue" \
  "$(printf 'structure\thierarchy\tparent-sub-issue\tauthoritative')" "$out"
assert_contains "native blocked-by is the dependency authority" \
  "$(printf 'structure\tdependency\tnative-blocked-by\tauthoritative')" "$out"
assert_contains "issue-body prose is derived, never authoritative" \
  "$(printf 'structure\tdependency\tissue-body-prose\tderived')" "$out"
assert_contains "governance surfaces are declared" \
  "$(printf 'surface\tissue-form\t')" "$out"
assert_contains "enforcement requirements are declared" \
  "$(printf 'enforce\ttrunk-protection\tremote\tmechanical')" "$out"

# ============ dependency and order are separate authorities ============
# The whole point of the separation records: order has its own authority and
# is never manufactured from either blocked-by or priority.
assert_contains "delivery order has its own authority" \
  "$(printf 'structure\torder\tgate-sub-issue-order\tauthoritative')" "$out"
assert_contains "order is never derived from blocked-by" \
  "$(printf 'separation\torder\tnative-blocked-by\t')" "$out"
assert_contains "order is never derived from priority" \
  "$(printf 'separation\torder\tpriority\t')" "$out"
assert_contains "a theme never satisfies the category requirement" \
  "$(printf 'separation\tcategory\ttheme\t')" "$out"

# The dependency structure record must not claim to carry order, and the order
# record must not claim to be a dependency — one fact, one surface.
dep_surfaces="$(printf '%s\n' "$out" | awk -F'\t' '$1=="structure" && $2=="dependency" { print $3 }')"
ord_surfaces="$(printf '%s\n' "$out" | awk -F'\t' '$1=="structure" && $2=="order" { print $3 }')"
overlap=0
for d in $dep_surfaces; do
  for o in $ord_surfaces; do [ "$d" = "$o" ] && overlap=1; done
done
assert_eq "no surface is both the dependency and the order authority" 0 "$overlap"

# ======================== priority ordering is data ========================
# Ordering semantics are the member declaration order, not inferred from the
# label spelling. Reversing the shipped order must be observable.
pri_order="$(printf '%s\n' "$out" | awk -F'\t' '$1=="member" && $2=="priority" { printf "%s ", $3 }')"
assert_eq "priority order is the declaration order" "P0 P1 P2 P3 " "$pri_order"

# ======================== operator override ========================
opgov="$XDG_CONFIG_HOME/spark/governance.tsv"
mkdir -p "$(dirname "$opgov")"
{
  printf 'version\t1\n'
  printf 'family\tcategory\texactly-one\trequired\tOperator category set\n'
  printf 'member\tcategory\tfeature\t111111\tOperator feature\n'
  printf 'member\tcategory\tbug\t222222\tOperator bug\n'
} > "$opgov"
rc=0; out_op="$(gov --tsv)" || rc=$?
assert_rc "operator tier resolves" 0 "$rc"
assert_contains "operator recolours feature" \
  "$(printf 'member\tcategory\tfeature\t111111\tOperator feature\toperator')" "$out_op"
# Whole-set replacement: a tier that declares any member of a family replaces
# that family's entire member set, so removal is expressible.
dropped="$(printf '%s\n' "$out_op" | awk -F'\t' '$1=="member" && $2=="category" && $3=="chore"')"
assert_eq "an operator member set replaces the whole family" "" "$dropped"
assert_contains "the operator family header wins" \
  "$(printf 'family\tcategory\texactly-one\trequired\tOperator category set\toperator')" "$out_op"
# Families the operator did not touch still resolve from the default tier.
assert_contains "untouched families keep the default tier" \
  "$(printf 'member\tpriority\tP0\tb60205')" "$out_op"

# ======================== project override ========================
mkdir -p "$repo/.spark"
{
  printf 'version\t1\n'
  printf 'member\tcategory\tfeature\t333333\tProject feature\n'
  printf 'family\tproving-family\texactly-one\trequired\tA data-defined family\n'
  printf 'member\tproving-family\tproving-member\t444444\tAdded as data, with no schema code\n'
} > "$repo/.spark/governance.tsv"
rc=0; out_pr="$(gov --tsv)" || rc=$?
assert_rc "project tier resolves over operator" 0 "$rc"
assert_contains "project beats operator" \
  "$(printf 'member\tcategory\tfeature\t333333\tProject feature\tproject')" "$out_pr"
gone="$(printf '%s\n' "$out_pr" | awk -F'\t' '$1=="member" && $2=="category" && $3=="bug"')"
assert_eq "the project member set replaces the operator one too" "" "$gone"

# A new governed label family is DATA: declared in a tier, no schema code.
assert_contains "a new family needs no schema code" \
  "$(printf 'family\tproving-family\texactly-one\trequired\tA data-defined family\tproject')" "$out_pr"
assert_contains "the new family's member resolves generically" \
  "$(printf 'member\tproving-family\tproving-member\t444444\t')" "$out_pr"

# ============ structure aspects: whole-set replacement, multi-fact ==========
#
# The generic layering contract, not the release-gate consumer that exposed it.
# Structure records key per (aspect, fact) — one aspect may state several facts
# — but a tier declaring ANY fact about an aspect replaces that aspect's WHOLE
# lower-tier set, the same way a member set replaces a family's.
#
# `dependency` is the multi-fact aspect the shipped model already carries: an
# authoritative native-blocked-by form and a derived issue-body-prose one.
mkdir -p "$repo/.spark"
{
  printf 'version\t1\n'
  printf 'structure\tdependency\tnative-blocked-by\tauthoritative\tProject dependency rule\n'
} > "$repo/.spark/governance.tsv"
rc=0; out_st="$(gov --tsv)" || rc=$?
assert_rc "a tier may restate a structure aspect" 0 "$rc"
assert_contains "and its own fact is what is in force" \
  "$(printf 'structure\tdependency\tnative-blocked-by\tauthoritative\tProject dependency rule\tproject')" "$out_st"

# A. WHOLE-ASPECT REPLACEMENT. The sibling fact the project did not restate is
# gone — replaced away with the rest of the aspect, exactly as an unrestated
# member of a family is. Keying alone would have left it beside the new fact,
# and the aspect would then mean two things at once.
sibling="$(printf '%s\n' "$out_st" | awk -F'\t' '$1=="structure" && $2=="dependency" && $3=="issue-body-prose"')"
assert_eq "an unrestated fact of the same aspect is replaced away" "" "$sibling"
kept="$(printf '%s\n' "$out_st" | awk -F'\t' '$1=="structure" && $2=="dependency"' | wc -l | tr -d ' ')"
assert_eq "so the aspect holds only the winning tier's declaration" "1" "$kept"
# Aspects the project never mentioned are untouched: replacement is per aspect,
# not per record type.
assert_contains "another aspect keeps the default tier" \
  "$(printf 'structure\thierarchy\tparent-sub-issue\tauthoritative')" "$out_st"

# B. A WINNING ASPECT MAY STILL BE MULTI-FACT. The guard against "fixing"
# whole-aspect replacement by collapsing an aspect to a single row: an aspect
# states as many facts as its owning tier declares, and both must survive.
{
  printf 'version\t1\n'
  printf 'structure\tdependency\tnative-blocked-by\tauthoritative\tProject dependency rule\n'
  printf 'structure\tdependency\tproject-body-prose\tderived\tA second fact about the same aspect\n'
} > "$repo/.spark/governance.tsv"
rc=0; out_st2="$(gov --tsv)" || rc=$?
assert_rc "a winning tier may declare several facts for one aspect" 0 "$rc"
both="$(printf '%s\n' "$out_st2" | awk -F'\t' '$1=="structure" && $2=="dependency"' | wc -l | tr -d ' ')"
assert_eq "both of the winning tier's facts survive together" "2" "$both"
assert_contains "the authoritative one" \
  "$(printf 'structure\tdependency\tnative-blocked-by\tauthoritative\tProject dependency rule\tproject')" "$out_st2"
assert_contains "and the derived one beside it" \
  "$(printf 'structure\tdependency\tproject-body-prose\tderived\tA second fact about the same aspect\tproject')" "$out_st2"

rm -f "$repo/.spark/governance.tsv" "$opgov"

# ======================== fail closed ========================
fail_case() { # <name> <artifact-body> <expected-substring>
  printf '%s' "$2" > "$repo/.spark/governance.tsv"
  local rc=0 out
  out="$(gov --tsv 2>&1)" || rc=$?
  assert_rc "invalid: $1 fails closed" 1 "$rc"
  assert_contains "invalid: $1 explains precisely" "$3" "$out"
  rm -f "$repo/.spark/governance.tsv"
}
mkdir -p "$repo/.spark"

fail_case "duplicate category" \
  "$(printf 'version\t1\nfamily\tcategory\texactly-one\trequired\tD\nmember\tcategory\tfeature\taaaaaa\tX\nmember\tcategory\tfeature\tbbbbbb\tY\n')" \
  "duplicate member feature in family category"

fail_case "duplicate priority family" \
  "$(printf 'version\t1\nfamily\tpriority\texactly-one\toptional\tA\nfamily\tpriority\tany\toptional\tB\n')" \
  "duplicate family priority"

fail_case "unknown record type" \
  "$(printf 'version\t1\nnonsense\tfoo\tbar\n')" \
  "unknown record type nonsense"

fail_case "wrong field count" \
  "$(printf 'version\t1\nfamily\tcategory\texactly-one\n')" \
  "family record needs 5 tab-separated fields, found 3"

fail_case "bad cardinality" \
  "$(printf 'version\t1\nfamily\tcategory\tsometimes\trequired\tD\n')" \
  "cardinality sometimes is not exactly-one|at-most-one|any"

fail_case "bad requirement" \
  "$(printf 'version\t1\nfamily\tcategory\texactly-one\tmaybe\tD\n')" \
  "requirement maybe is not required|optional"

fail_case "bad colour" \
  "$(printf 'version\t1\nfamily\tcategory\texactly-one\trequired\tD\nmember\tcategory\tfeature\tZZZ\tX\n')" \
  "is not six lowercase hex digits"

fail_case "no version record" \
  "$(printf 'family\tcategory\texactly-one\trequired\tD\n')" \
  "no version record"

fail_case "unsupported version" \
  "$(printf 'version\t99\n')" \
  "version 99 is not supported by this Spark (expects 1)"

fail_case "member of an undeclared family" \
  "$(printf 'version\t1\nmember\tmystery\tthing\taaaaaa\tX\n')" \
  "belongs to undeclared family mystery"

fail_case "separation naming nothing declared" \
  "$(printf 'version\t1\nseparation\tphantom\tother\tWhy\n')" \
  "which is neither a declared family nor a structure aspect"

fail_case "bad structure authority" \
  "$(printf 'version\t1\nstructure\torder\tsomewhere\tmaybe\tRule\n')" \
  "authority maybe is not authoritative|derived"

# BOTH sides of a separation are checked. The one thing the record asserts is
# that X is never derived from Y; an unvalidated Y let a typo render as a rule
# about something that does not exist.
fail_case "typo in a separation's second field" \
  "$(printf 'version\t1\nseparation\tcategory\tprioriy\tRule text\n')" \
  "is declared against prioriy, which is not a declared family"

# One problem, one finding: counting the version record as seen before judging
# its value keeps a malformed version from also tripping the END check.
printf 'version\tX\n' > "$repo/.spark/governance.tsv"
rc=0; out="$(gov --tsv 2>&1)" || rc=$?
assert_rc "a non-integer version fails closed" 1 "$rc"
assert_eq "and yields exactly one finding" 1 \
  "$(printf '%s\n' "$out" | grep -c 'governance:')"
assert_contains "naming the real problem" "version must be an integer" "$out"
rm -f "$repo/.spark/governance.tsv"

# A traversal in governance.model must never read an arbitrary file as the
# governance authority.
printf '{ "governance.model": "../../../etc/passwd" }' > "$repo/.spark/preferences.json"
rc=0; out="$(gov --tsv 2>&1)" || rc=$?
assert_rc "a path in governance.model fails closed" 1 "$rc"
assert_contains "and says why" "is not a bare model id" "$out"
rm -f "$repo/.spark/preferences.json"

# ======================== the taxonomy seams read the schema ========================
# taxonomy_label_color / taxonomy_label_desc must be lookups into the resolved
# model, not a second copy of the values.
assert_eq "taxonomy colour comes from the schema" "0e8a16" "$(taxonomy_label_color feature)"
assert_eq "taxonomy description comes from the schema" \
  "Docs, references, and explanatory prose" "$(taxonomy_label_desc documentation)"
# Extending issue.taxonomy stays safe: an undeclared category still resolves.
assert_eq "an undeclared category gets neutral grey" "ededed" "$(taxonomy_label_color invented)"
assert_eq "an undeclared category gets the generic description" \
  "Work category declared by issue.taxonomy" "$(taxonomy_label_desc invented)"

# And an operator override of the schema moves the colour with it.
mkdir -p "$(dirname "$(governance_operator_model)")"
{ printf 'version\t1\n'
  printf 'family\tcategory\texactly-one\trequired\tOps\n'
  printf 'member\tcategory\tfeature\tabcdef\tOps feature\n'
} > "$(governance_operator_model)"
assert_eq "an operator schema override moves the colour" "abcdef" "$(taxonomy_label_color feature)"

# The lookups also accept a pre-resolved model, which is how cmd_labels pays for
# resolution once instead of once per category. Same answer either way.
m="$(resolve_governance)"
assert_eq "a pre-resolved model gives the same colour" "abcdef" \
  "$(taxonomy_label_color feature "$m")"
assert_eq "a pre-resolved model gives the same description" "Ops feature" \
  "$(taxonomy_label_desc feature "$m")"
assert_eq "an undeclared category still falls back with a pre-resolved model" \
  "ededed" "$(taxonomy_label_color invented "$m")"
rm -f "$(governance_operator_model)"

# ======================== shipped parity is enforced ========================
# doctor holds the shipped model and the shipped issue.taxonomy in parity, so
# the name set cannot have two answers.
rc=0; out="$("$SPARK" doctor 2>&1)" || rc=$?
assert_contains "doctor reports shipped model parity" \
  "the shipped governance model is valid and in parity with issue.taxonomy" "$out"

# Parity is a SET comparison: member declaration order is meaningful elsewhere
# in the artifact, so reordering one file is a natural edit and must not fail
# with two lines holding the same seven names.
defaults_file="$WORK/plugin/preferences/defaults.json"
python3 - "$defaults_file" <<'PY'
import collections, json, sys
p = sys.argv[1]
d = json.load(open(p), object_pairs_hook=collections.OrderedDict)
t = d["issue.taxonomy"].split()
d["issue.taxonomy"] = " ".join([t[1], t[0]] + t[2:])
json.dump(d, open(p, "w"), indent=2)
PY
rc=0; out="$("$SPARK" doctor 2>&1)" || rc=$?
assert_rc "reordering the taxonomy keeps parity" 0 "$rc"
assert_contains "and still reports parity" "in parity with issue.taxonomy" "$out"
# A genuinely different set must still fail.
python3 - "$defaults_file" <<'PY'
import collections, json, sys
p = sys.argv[1]
d = json.load(open(p), object_pairs_hook=collections.OrderedDict)
d["issue.taxonomy"] = d["issue.taxonomy"] + " invented"
json.dump(d, open(p, "w"), indent=2)
PY
rc=0; out="$("$SPARK" doctor 2>&1)" || rc=$?
assert_rc "a different set still fails parity" 1 "$rc"
assert_contains "naming the disagreement" "disagree" "$out"
python3 - "$defaults_file" <<'PY'
import collections, json, sys
p = sys.argv[1]
d = json.load(open(p), object_pairs_hook=collections.OrderedDict)
d["issue.taxonomy"] = "feature bug documentation chore tech-debt research infrastructure"
json.dump(d, open(p, "w"), indent=2)
PY

model_file="$WORK/plugin/preferences/governance-models/spark-default.tsv"
cp "$model_file" "$WORK/model.pristine"
printf 'member\tcategory\tinvented\tededed\tDrifted in\n' >> "$model_file"
rc=0; out="$("$SPARK" doctor 2>&1)" || rc=$?
assert_rc "doctor fails on shipped drift" 1 "$rc"
assert_contains "doctor names the drift" \
  "category family and the shipped issue.taxonomy disagree" "$out"
# Restore it: leaving the shipped model drifted made every later case run
# against a model that declares `invented`, which silently changed what those
# cases were testing.
cp "$WORK/model.pristine" "$model_file"
rc=0; "$SPARK" doctor >/dev/null 2>&1 || rc=$?
assert_rc "the shipped model is restored for the cases that follow" 0 "$rc"

# ============ an unresolvable model must not be written to a remote ============
# The colours and descriptions spark labels --apply writes come from the model.
# If the model cannot be resolved, creating labels from the fallback would push
# a guess to the remote, so the verb refuses instead.
printf 'version\t1\nnonsense\tx\ty\n' > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" labels --apply 2>&1)" || rc=$?
assert_contains "labels reports the unresolvable model" \
  "the governance model could not be resolved" "$out"
assert_contains "labels names the precise finding" "unknown record type nonsense" "$out"
assert_contains "labels refuses to create from a guess" "Refusing to create labels" "$out"
# The refusal is reported BEFORE the gh gate: the model is local truth, so an
# unresolvable one is knowable with no network — which is what makes this
# testable offline at all.
assert_contains "the refusal precedes the not-assessed gh gate" "needs an authenticated gh" "$out"
gov_pos="$(printf '%s\n' "$out" | grep -n 'could not be resolved' | cut -d: -f1)"
gh_pos="$(printf '%s\n' "$out" | grep -n 'needs an authenticated gh' | cut -d: -f1)"
if [ -n "$gov_pos" ] && [ -n "$gh_pos" ] && [ "$gov_pos" -lt "$gh_pos" ]; then ok; else
  bad "the governance finding is reported before the gh gate"
fi
# Report-only says the same thing without the refusal language.
rc=0; out="$("$SPARK" labels 2>&1)" || rc=$?
assert_contains "report-only warns the colours are fallbacks" \
  "are the fallbacks, not the declared ones" "$out"
rm -f "$repo/.spark/governance.tsv"

# ====== a valid model can still contradict the taxonomy (resolved tiers) ======
# Whole-set replacement is deliberate and issue.taxonomy owns the name set
# independently, so an overlay declaring only `feature` leaves six categories
# with no declared colour while resolution still SUCCEEDS. Creating them from
# the fallback would write a guess that create-only never corrects.
mkdir -p "$XDG_CONFIG_HOME/spark"
{ printf 'version\t1\n'
  printf 'family\tcategory\texactly-one\trequired\tNarrowed\n'
  printf 'member\tcategory\tfeature\t111111\tOps feature\n'
} > "$XDG_CONFIG_HOME/spark/governance.tsv"
rc=0; out="$("$SPARK" labels --apply 2>&1)" || rc=$?
assert_contains "a narrowed overlay is reported as a disagreement" \
  "disagree about which categories exist" "$out"
assert_contains "naming the tier that replaced the family" \
  "the operator tier replaced the whole category family" "$out"
assert_contains "and listing the undeclared categories" \
  "bug documentation chore tech-debt research infrastructure" "$out"
assert_contains "refusing to write a guess" "Refusing to create labels" "$out"
# The model itself is VALID — this is a cross-tier contradiction, not a parse
# error, which is exactly why the fail-closed path alone could not catch it.
rc=0; "$SPARK" governance --tsv >/dev/null 2>&1 || rc=$?
assert_rc "the narrowed model is itself valid" 0 "$rc"
rm -f "$XDG_CONFIG_HOME/spark/governance.tsv"

# Extending issue.taxonomy stays the supported act: when the SHIPPED member set
# is the winner, a category it does not name was added, and neutral grey is the
# intended answer rather than a contradiction.
mkdir -p "$repo/.spark"
printf '{ "issue.taxonomy": "feature bug documentation chore tech-debt research infrastructure invented" }' \
  > "$repo/.spark/preferences.json"
rc=0; out="$("$SPARK" labels 2>&1)" || rc=$?
assert_contains "an added category is the supported extension path" \
  "not declared by the governance model, so neutral grey: invented" "$out"
assert_contains "and it is not reported as a disagreement" "extending issue.taxonomy is supported" "$out"
case "$out" in
  *"disagree about which categories exist"*) bad "an added category must not read as a disagreement" ;;
  *) ok ;;
esac
rm -f "$repo/.spark/preferences.json"

# --prune-deprecated reads no colour and no description, so an unusable model
# must not disable it — and the fallthrough must not tell the operator to
# re-run the command they just ran.
printf 'version\t1\nnonsense\tx\ty\n' > "$repo/.spark/governance.tsv"
rc=0; out="$("$SPARK" labels --apply --prune-deprecated 2>&1)" || rc=$?
assert_eq "the misdirecting re-run message is gone" 0 \
  "$(printf '%s\n' "$out" | grep -c 'Remove it deliberately with: spark labels --apply --prune-deprecated')"
rm -f "$repo/.spark/governance.tsv"

# ============ the human view renders every record type it resolves ============
# Omitting a record type made `spark governance` claim to render "the resolved
# model" while silently dropping rules that decide real verdicts.
rc=0; out="$("$SPARK" governance 2>&1)" || rc=$?
assert_rc "the human view renders" 0 "$rc"
assert_contains "it shows label families" "Label families:" "$out"
assert_contains "it shows execution structure" "Execution structure:" "$out"
assert_contains "it shows the separations" "Separations that must not be collapsed:" "$out"
assert_contains "it shows the surfaces" "Governance surfaces:" "$out"
assert_contains "it shows enforcement" "Enforcement requirements:" "$out"
# Every record type present in --tsv must be visible in the human view too.
for t in exclusive pathclass; do
  if printf '%s\n' "$("$SPARK" governance --tsv)" | awk -F'\t' -v t="$t" '$1==t{f=1} END{exit !f}'; then
    case "$t" in
      exclusive) assert_contains "the exclusivity rule is rendered" \
        "may not be combined with any other value" "$out" ;;
      pathclass) assert_contains "the governed paths are rendered" "governs" "$out" ;;
    esac
  fi
done

# ======================== read-only by construction ========================
# The verb must not write anything: no network, no remote, no local mutation.
git -C "$repo" checkout -q -- . 2>/dev/null || true
before="$(git -C "$repo" status --porcelain)"
"$SPARK" governance >/dev/null 2>&1 || true
"$SPARK" governance --tsv >/dev/null 2>&1 || true
after="$(git -C "$repo" status --porcelain)"
assert_eq "spark governance writes nothing" "$before" "$after"

finish
