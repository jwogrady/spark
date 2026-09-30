#!/usr/bin/env bash
# Behavioural suite for the bounded task snapshot (#734): the complete
# {observer, facts} object `spark facts --issue` emits when every required
# class compiled, and the fragment it stays when anything is missing.
#
# The things a happy-path check would miss:
#
#   * the shape is decided by completeness, never by the request — a missing
#     class or an unreadable observer leaves a bare list, not a smaller object
#     a consumer is entitled to act on (R11, R22);
#   * the observer read is spent only when a snapshot is possible, so an
#     incomplete run costs no call it cannot use;
#   * the snapshot is bounded by the work unit's governing graph: prose,
#     titles and comment history that grow without changing a governed fact do
#     not change a byte of it;
#   * the size #736 compares is the size a consumer actually read.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "fact snapshot (#734)"
sandbox_init

MODEL="$WORK/plugin/preferences/fact-model.tsv"

make_repo "$WORK/proj"
git -C "$WORK/proj" remote add origin "git@github.com:jwogrady/Spark.git"
cd "$WORK/proj"

mkdir -p "$WORK/bin"
export GH_CALL_LOG="$WORK/gh.calls"
export PATH="$WORK/bin:$PATH"

# One observation instant for every run, so two outputs can be compared byte
# for byte and a difference is a difference in what was compiled.
cat > "$WORK/bin/date" <<'SH'
#!/usr/bin/env bash
echo "2026-09-29T12:00:00Z"
SH
chmod +x "$WORK/bin/date"

mkdir -p .spark
cat > .spark/preferences.json <<'JSON'
{
  "authority.decision_record": "github.com/jwogrady/spark#677/comment/5622552139"
}
JSON

NODE='{"id":123456789,"full_name":"jwogrady/spark","default_branch":"master","updated_at":"2026-09-07T21:00:00Z"}'
AUTH_BODY='spark-authority-v1
target github.com/jwogrady/spark
grant merge:routine
boundary release:approve'
AUTH_COMMENT="$(jq -nc --arg body "$AUTH_BODY" '{id:5622552139,updated_at:"2026-09-10T20:00:00Z",user:{login:"jwogrady",type:"User"},author_association:"OWNER",issue_url:"https://api.github.com/repos/jwogrady/spark/issues/677",body:$body}')"
AUTH_ISSUE='{"number":677,"updated_at":"2026-09-10T20:05:00Z"}'

# An issue as the work-unit query returns it: every key the query asks for is
# present, so the only thing varied below is what a test is about.
issue_node() { # issue_node [extra jq merge]
  jq -nc "{__typename:\"Issue\", number:734, updatedAt:\"2026-09-20T10:00:00Z\",
           repository:{nameWithOwner:\"jwogrady/spark\"}, milestone:null, parent:null,
           subIssues:{pageInfo:{hasNextPage:false}, nodes:[]},
           blockedBy:{pageInfo:{hasNextPage:false}, nodes:[]}} ${1:+| . + $1}"
}

VIEWER='{"data":{"viewer":{"login":"JWogrady"},"repository":{"viewerPermission":"ADMIN"}}}'

# snapshot_stub <unit node json> [viewer response|FAIL] — the unit query, the
# observer query and the repository reads, each told apart by what it asks.
snapshot_stub() {
  local unit="$1" viewer="${2:-$VIEWER}"
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *viewerPermission*) [ '$viewer' = FAIL ] && { echo 'gh: Bad credentials (HTTP 401)' >&2; exit 1; }
                      answer_json '$viewer' ;;
  *issueOrPullRequest*) answer_json '{"data":{"repository":{"issueOrPullRequest":$unit}}}' ;;
  *"--hostname github.com repos/jwogrady/spark/issues/comments/5622552139"*) answer_json '$AUTH_COMMENT' ;;
  *"--hostname github.com repos/jwogrady/spark/issues/677"*) answer_json '$AUTH_ISSUE' ;;
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB
}

observer_calls() { command grep -c 'viewer{ login }' "$GH_CALL_LOG" || true; }
required_classes() { awk -F'\t' '$1 == "class" && $3 == "required" { print $2 }' "$MODEL" | sort | tr '\n' ' '; }

# --- a complete set is the {observer, facts} object ---------------------------
snapshot_stub "$(issue_node)"
: > "$GH_CALL_LOG"
S="$("$SPARK" facts --issue 734 2>"$WORK/err")"

assert_eq "a complete set is an object" "object" "$(printf '%s' "$S" | jq -r type)"
assert_eq "whose keys are exactly observer and facts (R22)" "facts,observer" \
  "$(printf '%s' "$S" | jq -r 'keys | join(",")')"
assert_eq "carrying every required class exactly once (R11)" "$(required_classes)" \
  "$(printf '%s' "$S" | jq -r '[.facts[] | select(.class != "next_action") | .class] | sort | join(" ") + " "')"
assert_eq "and no class twice" "0" \
  "$(printf '%s' "$S" | jq '[.facts[].class] | group_by(.) | map(select(length > 1)) | length')"
assert_eq "plus the derived next action" "1" \
  "$(printf '%s' "$S" | jq '[.facts[] | select(.class == "next_action")] | length')"
assert_eq "the observer login is canonical — lower-cased, prefixed" "login:jwogrady" \
  "$(printf '%s' "$S" | jq -r '.observer.login')"
assert_eq "its permission is GitHub's closed vocabulary" "admin" \
  "$(printf '%s' "$S" | jq -r '.observer.permission')"
assert_eq "checked in the same run that read the facts" "2026-09-29T12:00:00Z" \
  "$(printf '%s' "$S" | jq -r '.observer.checked_at')"
assert_eq "which is every fact's observation instant" "2026-09-29T12:00:00Z" \
  "$(printf '%s' "$S" | jq -r '[.facts[].observed_at] | unique | join(",")')"
assert_eq "the observer has exactly its three fields" "checked_at,login,permission" \
  "$(printf '%s' "$S" | jq -r '.observer | keys | join(",")')"
assert_eq "the observer is read once" "1" "$(observer_calls)"
assert_eq "and a complete snapshot reports nothing missing" "" "$(cat "$WORK/err")"

# Explicit non-ESTABLISHED statuses survive into the snapshot as themselves.
assert_eq "an issue's HEAD-bound classes stay NOT_APPLICABLE" "NOT_APPLICABLE NOT_APPLICABLE NOT_APPLICABLE NOT_APPLICABLE" \
  "$(printf '%s' "$S" | jq -r '[.facts[] | select(.class == "head" or .class == "review" or .class == "checks" or .class == "acceptance") | .status] | join(" ")')"
assert_eq "and an underivable action stays UNKNOWN with its reason" "UNKNOWN" \
  "$(printf '%s' "$S" | jq -r '.facts[] | select(.class == "next_action") | .status')"

# Every fact is pointable: provenance and freshness, never the history itself.
assert_eq "every fact carries provenance, invalidators and versions" "true" \
  "$(printf '%s' "$S" | jq '[.facts[] | (.provenance | type) == "string" and (.invalidators | length) > 0 and (.versions | type) == "object"] | all')"

# --- the observer is a condition of the shape, never repaired -----------------
observer_refused() { # observer_refused <viewer response|FAIL> <label>
  snapshot_stub "$(issue_node)" "$1"
  local out err
  out="$("$SPARK" facts --issue 734 2>"$WORK/err")"
  err="$(cat "$WORK/err")"
  assert_eq "$2: the output stays a fragment" "array" "$(printf '%s' "$out" | jq -r type)"
  assert_eq "$2: with every fact still compiled" "10" "$(printf '%s' "$out" | jq length)"
  assert_contains "$2: and the reason is reported" "observer:" "$err"
}
observer_refused FAIL "an unreadable observer"
observer_refused '{"data":{"viewer":{"login":"jwogrady"},"repository":{"viewerPermission":null}}}' "a null permission"
observer_refused '{"data":{"viewer":{"login":"jwogrady"},"repository":{"viewerPermission":"OWNER"}}}' "a permission outside the vocabulary"
observer_refused '{"data":{"viewer":{"login":"not a login"},"repository":{"viewerPermission":"WRITE"}}}' "a login outside the grammar"
observer_refused '{"data":{"viewer":null,"repository":{"viewerPermission":"WRITE"}}}' "a missing viewer"
observer_refused '{"data":"nonsense"}' "a reply of the wrong shape"

# --- an incomplete set costs no observer read ---------------------------------
snapshot_stub "$(issue_node)"
: > "$GH_CALL_LOG"
F="$("$SPARK" facts 2>/dev/null)"
assert_eq "without a work unit the output is a fragment" "array" "$(printf '%s' "$F" | jq -r type)"
assert_eq "and the observer is never asked" "0" "$(observer_calls)"

mv .spark/preferences.json "$WORK/prefs.saved"
: > "$GH_CALL_LOG"
F="$("$SPARK" facts --issue 734 2>/dev/null)"
assert_eq "a work unit missing a required class is a fragment" "array" "$(printf '%s' "$F" | jq -r type)"
assert_eq "whatever else it carries" "9" "$(printf '%s' "$F" | jq length)"
assert_eq "and no observer read is spent on it" "0" "$(observer_calls)"
mv "$WORK/prefs.saved" .spark/preferences.json

# --- bounded: growth that changes no governed fact changes no byte -----------
# The snapshot carries facts, never the prose they were read from. Growth that
# is not a change to this work unit's governing graph must leave the output
# byte-identical; growth that IS (a new child) changes it, and only by that
# child's entry and its freshness.
snapshot_stub "$(issue_node)"
BASE="$("$SPARK" facts --issue 734 2>/dev/null)"

snapshot_stub "$(issue_node '{title: ("long title " * 500), body: ("prose that grows " * 5000)}')"
assert_eq "a larger title and body change no byte of the snapshot" "$BASE" \
  "$("$SPARK" facts --issue 734 2>/dev/null)"

ONE_CHILD='{subIssues:{pageInfo:{hasNextPage:false}, nodes:[{__typename:"Issue", number:900, state:"OPEN", updatedAt:"2026-09-21T10:00:00Z", repository:{nameWithOwner:"jwogrady/spark"}}]}}'
snapshot_stub "$(issue_node "$ONE_CHILD")"
CHILD="$("$SPARK" facts --issue 734 2>/dev/null)"
assert_eq "a child in the governing graph does appear" "github.com/jwogrady/spark#900" \
  "$(printf '%s' "$CHILD" | jq -r '.facts[] | select(.class == "graph") | .value.children[0].id')"
assert_eq "and outside the graph fact the snapshot is unchanged" \
  "$(printf '%s' "$BASE" | jq -c '.facts | map(select(.class != "graph" and .class != "next_action"))')" \
  "$(printf '%s' "$CHILD" | jq -c '.facts | map(select(.class != "graph" and .class != "next_action"))')"

# --- a pull request's graph is the graph of the issue it implements ----------
# GitHub gives a pull request no parent, children or blockers. R17 and the
# model's first example read them from the issue the pull request closes, name
# that issue as the source, and let it invalidate the fact — so a pull request
# has a complete snapshot, and the issue is read once, as itself.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"tests"}]}}]'
HEADOID="a1b2c3d4e5f60718293a4b5c6d7e8f9012345678"
BASEOID="b1c2d3e4f5061728394a5b6c7d8e9f0123456789"
PARENTED='{parent:{__typename:"Issue", number:728, state:"OPEN", updatedAt:"2026-09-01T10:00:00Z", repository:{nameWithOwner:"jwogrady/spark"}}}'

pr_node() { # pr_node <closing reference nodes json>
  jq -nc --argjson refs "$1" --arg h "$HEADOID" --arg b "$BASEOID" '
    {__typename:"PullRequest", number:801, updatedAt:"2026-09-22T10:00:00Z",
     repository:{nameWithOwner:"jwogrady/spark"}, milestone:null,
     headRefOid:$h, baseRefName:"master", baseRefOid:$b, baseRef:{target:{oid:$b}},
     commits:{nodes:[{commit:{oid:$h, statusCheckRollup:null}}]},
     comments:{pageInfo:{hasPreviousPage:false}, nodes:[]},
     closingIssuesReferences:{pageInfo:{hasNextPage:false}, nodes:$refs}}'
}
ref_node() { # ref_node <number> [owner/name] [updatedAt]
  jq -nc --argjson n "$1" --arg r "${2:-jwogrady/spark}" --arg u "${3:-2026-09-20T10:00:00Z}" \
    '{__typename:"Issue", number:$n, updatedAt:$u, repository:{nameWithOwner:$r},
      body:"## Acceptance\n\n- [ ] the one criterion\n"}'
}

# pr_stub <pr node> <node answered for 734> — the pull request and its issue
# are two reads, told apart by the number each one asks for.
pr_stub() {
  local pr="$1" issue="$2"
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *viewerPermission*) answer_json '$VIEWER' ;;
  *"number=801"*) answer_json '{"data":{"repository":{"issueOrPullRequest":$pr}}}' ;;
  *"number=734"*) answer_json '{"data":{"repository":{"issueOrPullRequest":$issue}}}' ;;
  *"repos/jwogrady/spark/rules/branches/"*) answer_json '$RULES' ;;
  *"--hostname github.com repos/jwogrady/spark/issues/comments/5622552139"*) answer_json '$AUTH_COMMENT' ;;
  *"--hostname github.com repos/jwogrady/spark/issues/677"*) answer_json '$AUTH_ISSUE' ;;
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB
}
reads_of() { command grep -c "number=$1 " "$GH_CALL_LOG" || true; }
gfact() { printf '%s' "$1" | jq -c '(.facts? // .)[] | select(.class == "graph")'; }

pr_stub "$(pr_node "[$(ref_node 734)]")" "$(issue_node "$PARENTED")"
: > "$GH_CALL_LOG"
P="$("$SPARK" facts --issue 801 2>"$WORK/err")"
G="$(gfact "$P")"
assert_eq "a pull request implementing one issue has a complete snapshot" "object" \
  "$(printf '%s' "$P" | jq -r type)"
assert_eq "whose graph is established" "ESTABLISHED" "$(printf '%s' "$G" | jq -r .status)"
assert_eq "sourced from the implemented issue, not the pull request" "github.com/jwogrady/spark#734" \
  "$(printf '%s' "$G" | jq -r .source.identity)"
assert_eq "carrying that issue's parent" "github.com/jwogrady/spark#728" \
  "$(printf '%s' "$G" | jq -r .value.parent.id)"
assert_eq "invalidated by the issue and its relatives, never the pull request" \
  "issue:github.com/jwogrady/spark#728,issue:github.com/jwogrady/spark#734" \
  "$(printf '%s' "$G" | jq -r '.invalidators | sort | join(",")')"
assert_eq "the pull request is read once, whatever reads the issue" "1" "$(reads_of 801)"
assert_eq "and the issue is read once" "1" "$(reads_of 734)"
assert_eq "so the head is still the pull request's own" "$HEADOID" \
  "$(printf '%s' "$P" | jq -r '.facts[] | select(.class == "head") | .value.head')"
assert_eq "and the issue has one version across the set (R20)" "1" \
  "$(printf '%s' "$P" | jq '[.facts[] | .versions["issue:github.com/jwogrady/spark#734"] // empty] | unique | length')"
assert_eq "and nothing is reported missing" "" "$(cat "$WORK/err")"

# The issue edited between the two reads has two versions, and one set cannot
# carry both: the graph is withdrawn rather than published beside the other.
pr_stub "$(pr_node "[$(ref_node 734 jwogrady/spark 2026-09-19T09:00:00Z)]")" "$(issue_node)"
P="$("$SPARK" facts --issue 801 2>"$WORK/err")"
assert_eq "an issue seen in two versions leaves no graph" "" "$(gfact "$P")"
assert_eq "so the output is a fragment" "array" "$(printf '%s' "$P" | jq -r type)"
assert_contains "and says the issue changed between reads" "the implemented issue changed between reads" "$(cat "$WORK/err")"

pr_unknown() { # pr_unknown <closing refs json> <reason> <label>
  pr_stub "$(pr_node "$1")" "$(issue_node)"
  : > "$GH_CALL_LOG"
  local out g
  out="$("$SPARK" facts --issue 801 2>/dev/null)"
  g="$(gfact "$out")"
  assert_eq "$3: the graph is unknown with its reason" "UNKNOWN|$2" \
    "$(printf '%s' "$g" | jq -r '"\(.status)|\(.detail.reason)"')"
  assert_eq "$3: named and invalidated by the pull request it was read from" \
    "github.com/jwogrady/spark#801|pull_request:github.com/jwogrady/spark#801" \
    "$(printf '%s' "$g" | jq -r '"\(.source.identity)|\(.invalidators | join(","))"')"
  assert_eq "$3: and no issue is read to find that out" "0" "$(reads_of 734)"
}
pr_unknown '[]' "a pull request that implements no issue has no native graph" "closing nothing"
pr_unknown "[$(ref_node 734 other/repo)]" "the implemented issue is in another repository" "closing another repository's issue"
pr_unknown "[$(ref_node 734),$(ref_node 735)]" "the pull request declares more than one closing issue" "closing two issues"

pr_stub "$(pr_node '[]')" "$(issue_node)"
P="$("$SPARK" facts --issue 801 2>/dev/null)"
assert_eq "an unknown graph is still a complete snapshot" "object" "$(printf '%s' "$P" | jq -r type)"

# A closing reference that turns out to be a pull request is a reply that
# contradicts itself; it is refused, never followed again.
pr_stub "$(pr_node "[$(ref_node 734)]")" "$(pr_node "[$(ref_node 734)]" | jq -c '.number = 734')"
: > "$GH_CALL_LOG"
P="$("$SPARK" facts --issue 801 2>"$WORK/err")"
assert_eq "an implemented node that is a pull request leaves no graph" "" "$(gfact "$P")"
assert_contains "with the reason" "the implemented work unit is not an issue" "$(cat "$WORK/err")"
assert_eq "and it is not chased a second time" "1" "$(reads_of 734)"

# --- --delta: the same compilation, presented against the last observation ---
# Every fact is re-read from its source on every run; the stored record is
# compared, never consulted. What a repair round gets back is the facts whose
# status, value or versions moved, and the keys of those that did not.
rm -rf .spark/facts
assert_eq "--delta without a work unit is refused" "1" \
  "$("$SPARK" facts --delta >/dev/null 2>&1; echo $?)"

pr_stub "$(pr_node "[$(ref_node 734)]")" "$(issue_node "$PARENTED")"
FIRST="$("$SPARK" facts --issue 801 --delta 2>"$WORK/err")"
assert_eq "the first delta run is the full output" "facts,observer" "$(printf '%s' "$FIRST" | jq -r 'keys | join(",")')"
assert_contains "and says why" "no previous record" "$(cat "$WORK/err")"
[ -f .spark/facts/801.json ] && ok || bad "the first run stores the observation record"
assert_eq "the record names its unit and holds the full output" "github.com/jwogrady/spark#801|snapshot|10" \
  "$(jq -r '"\(.unit)|\(.shape)|\(.output.facts | length)"' .spark/facts/801.json)"

SPARK_RUN_ID=rdelta "$SPARK" facts --issue 801 --delta > "$WORK/delta.out" 2>/dev/null
D="$(cat "$WORK/delta.out")"
assert_eq "an unchanged unit yields a delta object, never a snapshot shape (R22)" "delta" \
  "$(printf '%s' "$D" | jq -r 'keys | join(",")')"
assert_eq "nothing changed" "0" "$(printf '%s' "$D" | jq '.delta.changed | length')"
assert_eq "and every fact is reported unchanged by key and version" "10" "$(printf '%s' "$D" | jq '.delta.unchanged | length')"
assert_eq "an unchanged entry carries key, status, source and versions only" "key,source,status,versions" \
  "$(printf '%s' "$D" | jq -r '.delta.unchanged[0] | keys | join(",")')"
assert_eq "the delta names the record it compared against" ".spark/facts/801.json|snapshot" \
  "$(printf '%s' "$D" | jq -r '"\(.delta.record)|\(.delta.shape)"')"
TELD="$("$SPARK" telemetry show --run rdelta --json)"
assert_contains "the run records what moved" '"facts_changed":0' "$TELD"
assert_contains "and what was reused by key" '"facts_unchanged":10' "$TELD"
assert_contains "and that a delta was printed" '"facts_output_shape":"delta"' "$TELD"
assert_contains "with the delta's own size" "\"facts_output_bytes\":$(wc -c < "$WORK/delta.out" | tr -d ' ')" "$TELD"

# A push: only the HEAD-bound facts and what derives from them move.
NEWHEAD="c1d2e3f4a5b60718293a4b5c6d7e8f9012345678"
pr_stub "$(pr_node "[$(ref_node 734)]" | jq -c --arg h "$NEWHEAD" '.headRefOid = $h | .commits.nodes[0].commit.oid = $h')" "$(issue_node "$PARENTED")"
D="$("$SPARK" facts --issue 801 --delta 2>/dev/null)"
assert_eq "a new HEAD changes exactly the HEAD-bound facts and the derived action" \
  "acceptance.contract,checks.required,head.exact,next_action.governed,review.independent" \
  "$(printf '%s' "$D" | jq -r '[.delta.changed[].key] | sort | join(",")')"
assert_eq "and leaves the non-HEAD facts unchanged" \
  "authority.standing,graph.native,placement.current,repository.identity,work_unit.identity" \
  "$(printf '%s' "$D" | jq -r '[.delta.unchanged[].key] | sort | join(",")')"
assert_eq "a changed fact is carried in full" "$NEWHEAD" \
  "$(printf '%s' "$D" | jq -r '.delta.changed[] | select(.key == "head.exact") | .value.head')"

# An edit to the implemented issue moves what is read from it, and nothing else.
pr_stub "$(pr_node "[$(ref_node 734 jwogrady/spark 2026-09-21T11:00:00Z)]" | jq -c --arg h "$NEWHEAD" '.headRefOid = $h | .commits.nodes[0].commit.oid = $h')" "$(issue_node "$PARENTED" | jq -c '.updatedAt = "2026-09-21T11:00:00Z"')"
D="$("$SPARK" facts --issue 801 --delta 2>/dev/null)"
assert_eq "an edited contract issue moves the facts read from it" \
  "acceptance.contract,graph.native" \
  "$(printf '%s' "$D" | jq -r '[.delta.changed[].key] | sort | join(",")')"
# The derived action did not move because it did not consult them: its inputs
# are exactly the facts the derivation read (R15), and a wait-review verdict is
# decided before acceptance or the graph is looked at.
assert_eq "and a derived fact moves only when an input it consulted moved" "unchanged|false" \
  "$(printf '%s' "$D" | jq -r '(.delta.unchanged[] | select(.key == "next_action.governed") | "unchanged") + "|" + ((.delta.unchanged[] | select(.key == "next_action.governed") | .source.version | test("acceptance.contract|graph.native")) | tostring)')"

# The record is compared, never believed: a tampered record cannot make a
# fact "unchanged", because the fact was re-read from its source.
jq -c '.output.facts |= map(if .key == "placement.current" then .status = "ESTABLISHED" | .value = {milestone: "none", release: "v9.9.9", gate: "none"} else . end)' \
  .spark/facts/801.json > "$WORK/tampered.json" && mv "$WORK/tampered.json" .spark/facts/801.json
D="$("$SPARK" facts --issue 801 --delta 2>/dev/null)"
assert_eq "a tampered record is reported as a change, with the source's truth" "placement.current|UNKNOWN" \
  "$(printf '%s' "$D" | jq -r '.delta.changed[] | select(.key == "placement.current") | "\(.key)|\(.status)"')"

# A record for another unit is not a record for this one.
jq -c '.unit = "github.com/jwogrady/spark#999"' .spark/facts/801.json > "$WORK/other.json" && mv "$WORK/other.json" .spark/facts/801.json
D="$("$SPARK" facts --issue 801 --delta 2>"$WORK/err")"
assert_eq "a record naming another unit is ignored" "facts,observer" "$(printf '%s' "$D" | jq -r 'keys | join(",")')"
assert_contains "and the run says so" "no previous record" "$(cat "$WORK/err")"

# Without --delta nothing is stored or compared; the output is the full one.
rm -rf .spark/facts
F="$("$SPARK" facts --issue 801 2>/dev/null)"
assert_eq "a plain run is the full output" "facts,observer" "$(printf '%s' "$F" | jq -r 'keys | join(",")')"
[ ! -e .spark/facts ] && ok || bad "a plain run must not write a record"

# --- the size #736 compares is the size that was read -------------------------
snapshot_stub "$(issue_node)"
SPARK_RUN_ID=rsnap "$SPARK" facts --issue 734 > "$WORK/snap.out" 2>/dev/null
TEL="$("$SPARK" telemetry show --run rsnap --json)"
assert_contains "the output shape is recorded" '"facts_output_shape":"snapshot"' "$TEL"
assert_contains "and its bytes are the bytes printed" "\"facts_output_bytes\":$(wc -c < "$WORK/snap.out" | tr -d ' ')" "$TEL"
assert_contains "and its facts are the facts emitted" "\"facts_emitted\":$(jq '.facts | length' "$WORK/snap.out")" "$TEL"
assert_contains "the observer read is counted as a read" '"facts_api_calls":' "$TEL"

snapshot_stub "$(issue_node)" FAIL
SPARK_RUN_ID=rfrag "$SPARK" facts --issue 734 > "$WORK/frag.out" 2>/dev/null
TEL2="$("$SPARK" telemetry show --run rfrag --json)"
assert_contains "a fragment is recorded as a fragment" '"facts_output_shape":"fragment"' "$TEL2"
assert_contains "with its own size" "\"facts_output_bytes\":$(wc -c < "$WORK/frag.out" | tr -d ' ')" "$TEL2"

finish
