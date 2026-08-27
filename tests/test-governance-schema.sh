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
  printf 'family\tdocs-impact\texactly-one\trequired\tA data-defined family\n'
  printf 'member\tdocs-impact\tdocs-none\t444444\tNo documentation impact\n'
} > "$repo/.spark/governance.tsv"
rc=0; out_pr="$(gov --tsv)" || rc=$?
assert_rc "project tier resolves over operator" 0 "$rc"
assert_contains "project beats operator" \
  "$(printf 'member\tcategory\tfeature\t333333\tProject feature\tproject')" "$out_pr"
gone="$(printf '%s\n' "$out_pr" | awk -F'\t' '$1=="member" && $2=="category" && $3=="bug"')"
assert_eq "the project member set replaces the operator one too" "" "$gone"

# A new governed label family is DATA: declared in a tier, no schema code.
assert_contains "a new family needs no schema code" \
  "$(printf 'family\tdocs-impact\texactly-one\trequired\tA data-defined family\tproject')" "$out_pr"
assert_contains "the new family's member resolves generically" \
  "$(printf 'member\tdocs-impact\tdocs-none\t444444\t')" "$out_pr"

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

model_file="$WORK/plugin/preferences/governance-models/spark-default.tsv"
printf 'member\tcategory\tinvented\tededed\tDrifted in\n' >> "$model_file"
rc=0; out="$("$SPARK" doctor 2>&1)" || rc=$?
assert_rc "doctor fails on shipped drift" 1 "$rc"
assert_contains "doctor names the drift" \
  "category family and the shipped issue.taxonomy disagree" "$out"

# ======================== read-only by construction ========================
# The verb must not write anything: no network, no remote, no local mutation.
git -C "$repo" checkout -q -- . 2>/dev/null || true
before="$(git -C "$repo" status --porcelain)"
"$SPARK" governance >/dev/null 2>&1 || true
"$SPARK" governance --tsv >/dev/null 2>&1 || true
after="$(git -C "$repo" status --porcelain)"
assert_eq "spark governance writes nothing" "$before" "$after"

finish
