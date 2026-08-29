#!/usr/bin/env bash
# Behavioral suite for member identity (#592): a governed member name is ONE
# record everywhere, whatever it contains.
#
# A GitHub label may contain spaces. Three consumers of the resolved model
# counted members by joining matched names with a space and splitting the
# result back, so one label named `not planned` counted as two — a cardinality
# violation invented by serialisation. `roadmap-check` was repaired first, which
# left the two validators disagreeing with it about the same governed value:
# valid in one, invalid in the other.
#
# The defect is not specific to `disposition`. Any family with a multi-word
# member had its cardinality and exclusivity computed wrong, so the fixtures
# below use a family of their own rather than the shipped one.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

sandbox_init
. "$SPARK"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}
repo_root_dir="$(cd "$(dirname "$0")/.." && pwd)"

# A model with multi-word members in two families: one cardinality-limited, one
# carrying an exclusive member. Both are ordinary GitHub label names.
model="$(printf '%s\n' \
  'version	1' \
  'family	stage	at-most-one	optional	Delivery stage' \
  'member	stage	not planned	abcdef	Deferred' \
  'member	stage	in progress	123456	Underway' \
  'family	scope	any	optional	Declared scope' \
  'member	scope	no impact	c5def5	Nothing is affected' \
  'member	scope	wide impact	0075ca	A great deal is affected' \
  'exclusive	scope	no impact	"no impact" may not be combined with any other value')"

TAXO="feature bug documentation chore tech-debt research infrastructure"
iss() { GOV_ISS="$1" gov_issue_rows "$model" "$1" "$TAXO"; }
det() { printf '%s\n' "$1" | awk -F'\t' -v i="$2" '$3 == i { print $4 }'; }

# ============ 1. one multi-word member counts as ONE ======================
one="$(printf '900\tnot planned\tv1.0\n')"
out="$(iss "$one")"
assert_eq "one multi-word member is one member" "=" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$3 == "#900" { print $2; exit }')"
case "$(det "$out" '#900')" in
  *"but 2 are set"*) bad "a single multi-word member was counted as two" ;;
  *) ok ;;
esac

# ============ 2. two distinct multi-word members count as TWO =============
# The fix must not simply stop counting: a real cardinality violation built
# from two multi-word names still has to be caught.
two="$(printf '901\tnot planned,in progress\tv1.0\n')"
out="$(iss "$two")"
assert_eq "two multi-word members are two members" "!" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$3 == "#901" { print $2; exit }')"
assert_contains "and the count is right" "at-most-one but 2 are set" "$(det "$out" '#901')"
# Both names are readable in the message, separably. A space-joined list could
# not be read back once a member may contain a space.
assert_contains "naming the first whole" "not planned" "$(det "$out" '#901')"
assert_contains "and the second whole" "in progress" "$(det "$out" '#901')"
assert_contains "separated unambiguously" "not planned, in progress" "$(det "$out" '#901')"

# ============ 3. exclusivity compares whole names =========================
excl="$(printf '902\tno impact,wide impact\tv1.0\n')"
out="$(iss "$excl")"
assert_contains "an exclusive member combined with another is caught" \
  "is exclusive but is combined" "$(det "$out" '#902')"
# The exclusive member alone is fine — and must not trip on the fact that its
# name shares a word with the other member.
solo="$(printf '903\tno impact\tv1.0\n')"
out="$(iss "$solo")"
assert_eq "the exclusive member alone is valid" "=" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$3 == "#903" { print $2; exit }')"
# A member that merely CONTAINS the exclusive name as a word must not satisfy
# the membership test: `wide impact` shares "impact" with `no impact`.
shared="$(printf '904\twide impact\tv1.0\n')"
out="$(iss "$shared")"
assert_eq "a member sharing a word is not the exclusive member" "=" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$3 == "#904" { print $2; exit }')"

# ============ 4. single-word behaviour is retained ========================
shipped="$(resolve_governance)"
sone="$(printf '905\tfeature,docs-impact:none\tv1.0\n')"
out="$(GOV_ISS="$sone" gov_issue_rows "$shipped" "$sone" "$TAXO")"
assert_eq "one category and one docs-impact still validate" "=" \
  "$(printf '%s\n' "$out" | awk -F'\t' '$3 == "#905" { print $2; exit }')"
stwo="$(printf '906\tfeature,bug,docs-impact:none\tv1.0\n')"
out="$(GOV_ISS="$stwo" gov_issue_rows "$shipped" "$stwo" "$TAXO")"
assert_contains "two single-word categories are still caught" \
  "category allows exactly-one but 2 are set" "$(det "$out" '#906')"

# ============ 5. the plan validator agrees with the issue validator =======
# The two were the pair that disagreed, so they are compared on the same value.
art="$WORK/plan.tsv"
printf 'issue\tk1\tA title\tnot planned\tbody\n' > "$art"
pout="$(plan_schema_rows "$model" "$art")"
case "$pout" in
  *"allows at-most-one but the plan sets 2"*) bad "the plan validator counted one member as two" ;;
  *) ok ;;
esac
printf 'issue\tk2\tA title\tnot planned,in progress\tbody\n' > "$art"
pout="$(plan_schema_rows "$model" "$art")"
assert_contains "and still catches a real violation" "the plan sets 2" "$pout"
assert_contains "naming both whole" "not planned, in progress" "$pout"
printf 'issue\tk3\tA title\tno impact,wide impact\tbody\n' > "$art"
pout="$(plan_schema_rows "$model" "$art")"
assert_contains "and compares the exclusive member whole" "is exclusive but the plan combines" "$pout"

# ============ 6. EVERY known consumer agrees on one fixture ===============
# THE CENSUS IS THE CLAIM. This section previously said "all three consumers"
# and tested the three that had already been repaired — so a fourth, cmd_next,
# stayed broken while the suite reported agreement. Enumerating them is the
# point; if a fifth appears, it belongs in this list before it ships.
#
#   1. gov_issue_rows    the per-issue validator
#   2. plan_schema_rows  the plan compiler
#   3. roadmap-check     the release-decision gate
#   4. cmd_next          issue selection
#
# cmd_next is exercised through its RAW GATHERING PATH — the label CSV as it
# arrives from gh — because that is where it split. A normalized helper would
# repeat the exact blind spot this check exists to close.
rc="$WORK/rc"; mkdir -p "$rc/.spark"
git -C "$rc" init -q
printf 'version\t1\nmember\tdisposition\tnot planned\tabcdef\tDeferred\n' \
  > "$rc/.spark/governance.tsv"
cat > "$rc/ROADMAP.md" <<'EOF'
# Roadmap

## v0.9 — Current

**Status:** Shipped (`v0.9.0`)

Tracks #100.

## v0.10 — Next

**Status:** Planned — see #101.
EOF
cat > "$rc/iss.json" <<'EOF'
[
  {"number": 900, "title": "Deferred", "labels": ["feature", "not planned"], "milestone": null, "body": "Deliberately not planned."}
]
EOF
pmodel="$(cd "$rc" && resolve_governance)"
# consumer 1 — the per-issue validator
c1="$(cd "$rc" && GOV_ISS="$(printf '900\tfeature,not planned\t\n')" \
  gov_issue_rows "$pmodel" "$(printf '900\tfeature,not planned\t\n')" "$TAXO" \
  | awk -F'\t' '$3 == "#900" { print $2; exit }')"
# consumer 2 — the plan compiler
printf 'issue\tk1\tA title\tfeature,not planned\tbody\n' > "$rc/plan.tsv"
c2="$(cd "$rc" && plan_schema_rows "$pmodel" "$rc/plan.tsv" \
  | awk -F'\t' '$4 ~ /disposition allows/ { print "!"; exit }')"
[ -n "$c2" ] || c2="="
# consumer 3 — roadmap-check
rcrc=0
( cd "$rc" && bash "$WORK/plugin/skills/plan/scripts/roadmap-check.sh" \
    --roadmap "$rc/ROADMAP.md" --issues "$rc/iss.json" >/dev/null 2>&1 ) || rcrc=$?
c3="$([ "$rcrc" -eq 0 ] && echo "=" || echo "!")"

# consumer 4 — cmd_next, INVOKED FOR REAL.
#
# The previous version of this check reimplemented the loop in the test. That is
# the failure mode the whole suite exists to kill: reverting the real gathering
# path to whitespace splitting left the replica passing. The fixture below runs
# `spark next --milestone` against a stubbed GitHub whose issue row carries a
# multi-word priority label, so the production path is the thing under test.
nextrepo="$WORK/nx"; mkdir -p "$nextrepo/.spark" "$nextrepo/.github/ISSUE_TEMPLATE"
git -C "$nextrepo" init -q
git -C "$nextrepo" config user.email t@e.invalid
git -C "$nextrepo" config user.name T
echo 'n: B' > "$nextrepo/.github/ISSUE_TEMPLATE/b.yml"
echo '## W' > "$nextrepo/.github/pull_request_template.md"
echo '{}' > "$nextrepo/release-please-config.json"
# A project model whose PRIORITY family is multi-word, and whose category set is
# the default. This is the shape a downstream project may legitimately declare.
printf 'version\t1\nfamily\tpriority\texactly-one\toptional\tStage\nmember\tpriority\ttop urgent\tb60205\tUrgent\nmember\tpriority\tlater on\tc2e0c6\tLater\n' \
  > "$nextrepo/.spark/governance.tsv"
git -C "$nextrepo" add -A; git -C "$nextrepo" commit -qm seed

nxbin="$WORK/nxbin"; mkdir -p "$nxbin"
for t in git awk sed grep find sort printf bash env cat wc tr head tail cut date mktemp rm mkdir ls dirname basename jq python3 xargs cksum comm; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$nxbin/$t" 2>/dev/null || true
done
# ISSUEROWS is the TSV `gh issue list` would emit: number, label CSV, title.
cat > "$nxbin/gh" <<'GHEOF'
#!/usr/bin/env bash
case "${1:-}" in
  auth) exit 0 ;;
  issue) printf '%s
' "$ISSUEROWS"; exit 0 ;;
esac
for a in "$@"; do
  case "$a" in
    *sub_issues*)   printf '900
901
'; exit 0 ;;
    *dependencies*) printf '0
'; exit 0 ;;
  esac
done
exit 0
GHEOF
chmod +x "$nxbin/gh"

nx() { ( cd "$nextrepo" && env PATH="$nxbin" ISSUEROWS="$1" \
  "$SPARK" next --milestone "v0.9" 2>&1 ); }

# ONE multi-word priority label must count as ONE. The gate carries sub-issues,
# so 900 is the gate and 901 is the selectable issue.
out4="$(nx "$(printf '900\tfeature\tGate\n901\tfeature,top urgent\tReal work\n')")" || true
case "$out4" in
  *"carries 2"*) c4="!" ;;
  *"selected  #901"*) c4="=" ;;
  *) c4="?" ;;
esac
assert_contains "cmd_next selects an issue carrying a multi-word priority" "selected  #901" "$out4"
case "$out4" in
  *"carries 2"*) bad "cmd_next counted one multi-word priority label as two" ;;
  *) ok ;;
esac

# NEGATIVE CONTROL: two DISTINCT multi-word priority labels must count as two
# and fail cardinality honestly. Without this the fix could be "stop counting".
out4b="$(nx "$(printf '900\tfeature\tGate\n901\tfeature,top urgent,later on\tReal work\n')")" || true
assert_contains "two distinct multi-word priorities are counted as two" "carries 2" "$out4b"
case "$out4b" in
  *"selected  #901"*) bad "an issue carrying two priorities was selected anyway" ;;
  *) ok ;;
esac

# ...and the diagnostic must name the RESOLVED family, not a hard-coded P0-P3.
case "$out4b" in
  *"P0-P3"*) bad "the diagnostic still hard-codes P0-P3 instead of reading the model" ;;
  *) ok ;;
esac
assert_contains "the diagnostic names the resolved family" "priority" "$out4b"
assert_contains "and its declared members" "top urgent, later on" "$out4b"

assert_eq "the per-issue validator accepts it" "=" "$c1"
assert_eq "the plan compiler accepts it" "=" "$c2"
assert_eq "roadmap-check accepts it" "=" "$c3"
assert_eq "cmd_next counts it as one member" "=" "$c4"
if [ "$c1" = "$c2" ] && [ "$c2" = "$c3" ] && [ "$c3" = "$c4" ]; then ok
else bad "the consumers disagree about one governed value: $c1 / $c2 / $c3 / $c4"; fi

# THE BINARY'''S OWN SERIALIZATION, not a replica of it. c4 above exercises the
# loop; this exercises the function that feeds it, because a replica passes
# while the original is wrong — which is how #597 survived a suite that claimed
# the consumers agreed.
mwmodel="$(printf '%s\n' 'version	1' 'family	priority	exactly-one	optional	P' \
  'member	priority	top urgent	b60205	Urgent' 'member	priority	later on	c2e0c6	Later')"
pm="$(priority_members "$mwmodel")"
assert_eq "priority_members emits one multi-word member per line" "2" \
  "$(printf '%s\n' "$pm" | awk 'NF' | wc -l | tr -d ' ')"
assert_eq "and keeps the first whole" "top urgent" "$(printf '%s\n' "$pm" | sed -n 1p)"
assert_eq "and the second whole" "later on" "$(printf '%s\n' "$pm" | sed -n 2p)"
assert_eq "the shipped model still contributes four" "4" \
  "$(priority_members "$(resolve_governance)" | awk 'NF' | wc -l | tr -d ' ')"

finish
