#!/usr/bin/env bash
# Behavioural suite for the fact compiler (#733), first consumer of the fact
# model (#731) and the freshness contract (#732).
#
# Those two shipped as DATA that nothing read. This is where every ambiguity in
# them surfaces first, so the suite is written against the shipped schema rather
# than against strings copied out of it: the identifier grammars, the required
# envelope fields and the status vocabulary are READ FROM preferences/fact-model.tsv
# and applied to what the compiler emitted. A fact that satisfies a hand-written
# expectation but not the schema would pass a test and fail the contract.
#
# The three things under test that a happy-path check would miss:
#
#   * an unreadable or unversioned source yields no fact — refused with a
#     stated reason (NOT ASSESSED, exit 3), never a smaller success and never
#     a surviving previous value; a readable, versioned source with another
#     malformed field is a conforming UNKNOWN instead;
#   * one node is read ONCE for every field of its fact — a per-field fan-out
#     could observe the same node in three states and manufacture a conflict;
#   * the source version is the node's updated_at, never its id, because an id
#     is stable across every change and would make a stale fact look current.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

echo "fact compiler (#733)"
sandbox_init

MODEL="$WORK/plugin/preferences/fact-model.tsv"

# model_regex <kind> <name> — a grammar straight out of the shipped schema, so
# the assertions below are the contract rather than a copy of it.
model_regex() {
  awk -F'\t' -v k="$1" -v n="$2" '$1 == k && $2 == n { print $3; exit }' "$MODEL"
}

# assert_versions_canonical <fact json> <label> — every version an emitted fact
# records is a version by the shipped grammar.
#
# This is the assertion whose absence let an UNKNOWN ship with an empty
# source.version and an empty versions entry: the old fixtures checked the
# STATUS of a failed read and never what the envelope said it had observed.
# `versions` answers "as of when", so a blank there is not a weaker answer, it
# is a field that cannot mean anything.
#
# Every value is judged inside jq, as the one JSON value it is — never handed
# back through -r as text and re-checked by the shell. That is what closes the
# per-line hole: `grep -Eq` accepts a value whenever ANY ONE of its lines
# matches an anchored pattern, `read` splits an embedded newline into separate
# tokens, and a bare command substitution drops a TRAILING newline before any
# check sees it — so "NOT-A-VERSION\n<canonical>" read as canonical, and so did
# two canonical lines glued together into one value that is not.
#
# jq's own anchors were measured here rather than assumed: on jq 1.7.1
# `"a\nb" | test("^b$")` is FALSE, so ^/$ bind to the whole string and the
# grammar could be asked directly. A control character is still rejected BEFORE
# the grammar, for two reasons that do not depend on that measurement holding
# in another jq build: the rejection reason stays truthful about what the value
# is, and the report below is a line-oriented transport, so a value must never
# be able to contribute a line to it. Every report line is a status token built
# with `tojson`, never the raw value, for the same reason.
assert_versions_canonical() {
  local f="$1" label="$2" re report
  re="$(model_regex source-version github-api)"

  report="$(
    printf '%s' "$f" | jq -j --arg re "$re" '
      def canonical:
        if type != "string" then "bad:\(. | tojson) is not a string"
        elif test("[[:cntrl:]]") then "bad:\(. | tojson) carries a control character"
        elif . == "" then "bad:\(. | tojson) is empty, so it cannot say as of when"
        elif test($re) then "ok"
        else "bad:\(. | tojson) is not a github-api version" end;
      ([.source.version | canonical]
       + (if (.versions | type) != "object"
          then ["bad-versions-type:\(.versions | type)"]
          elif (.versions | length) == 0 then ["bad-versions-none:"]
          else [.versions | to_entries[] | (.value | canonical)] end))
      | join("\n")'
  )"

  local entry
  while IFS= read -r entry; do
    case "$entry" in
      ok) ok ;;
      bad-versions-type:*)
        bad "$label: .versions is ${entry#bad-versions-type:}, not an object of canonical versions" ;;
      bad-versions-none:*)
        bad "$label: .versions records no observed version, so nothing can invalidate the fact" ;;
      bad:*) bad "$label: an observed version ${entry#bad:}" ;;
      # jq emits one line per value and never fewer than one, so a blank report
      # is jq failing to read the fact — the one case that must not pass by
      # producing no verdict at all. Skipping a blank here is the exact shape
      # this helper exists to repair, so it is classified, never skipped.
      "") bad "$label: no version could be classified — the fact did not parse" ;;
      *) bad "$label: assert_versions_canonical produced an unrecognised report line '$entry'" ;;
    esac
  done <<EOF
$report
EOF
}

# --- negative controls: the helper above must REJECT every fixture here.
#
# The four newline fixtures are the discriminating ones — each was measured
# PASSING at the pre-repair helper, where the value reached `grep` through
# `jq -r`, a command substitution and a heredoc; they are marked
# `(was fail-open)`. The rest were already rejected there and are kept so the
# rewrite is provably a tightening and not a trade: a helper can gain the
# newline case and quietly lose the empty, non-string or absent one.
#
# `refuses` runs the helper in a subshell so its ok/bad calls land there
# instead of on this suite's real totals, proving the rejection without a
# fixture that fakes a pass.
refuses() {
  local counted
  counted="$(
    fail=0
    assert_versions_canonical "$1" "the negative control" >/dev/null 2>&1
    echo "$fail"
  )"
  [ "$counted" -gt 0 ] && ok \
    || bad "assert_versions_canonical accepted $2"
}

CANON='2026-09-07T21:00:00Z'
KEY='repository:github.com/jwogrady/spark'
refuses "{\"source\":{\"version\":\"$CANON\"},\"versions\":{\"$KEY\":\"\"}}" \
  "a canonical source.version alongside an empty invalidator version"
refuses "{\"source\":{\"version\":\"$CANON\"},\"versions\":{\"$KEY\":\"$CANON\\n\"}}" \
  "an invalidator version with a trailing newline (was fail-open)"
refuses "{\"source\":{\"version\":\"$CANON\"},\"versions\":{\"$KEY\":\"$CANON\\n2026-09-08T00:00:00Z\"}}" \
  "an invalidator version whose every line is canonical but whose value is not (was fail-open)"
refuses "{\"source\":{\"version\":\"$CANON\\n\"},\"versions\":{\"$KEY\":\"$CANON\"}}" \
  "a source.version with a trailing newline (was fail-open)"
refuses "{\"source\":{\"version\":\"NOT-A-VERSION\\n$CANON\"},\"versions\":{\"$KEY\":\"$CANON\"}}" \
  "a source.version whose second line alone is canonical (was fail-open)"
refuses "{\"source\":{\"version\":\"$CANON\"},\"versions\":{\"$KEY\":1757278800}}" \
  "a non-string invalidator version"
refuses "{\"source\":{\"version\":\"$CANON\"},\"versions\":{\"$KEY\":null}}" \
  "a null invalidator version"
refuses "{\"source\":{\"version\":null},\"versions\":{\"$KEY\":\"$CANON\"}}" \
  "an absent source.version"
refuses "{\"source\":{\"version\":\"$CANON\"},\"versions\":[]}" \
  "a .versions that is not an object"
refuses "{\"source\":{\"version\":\"$CANON\"},\"versions\":{}}" \
  "a fact recording no invalidator version at all"

# --- positive control: the tightened helper still ACCEPTS a conforming fact,
# so the ten rejections above are discrimination and not a blanket refusal.
assert_versions_canonical \
  "{\"source\":{\"version\":\"$CANON\"},\"versions\":{\"$KEY\":\"$CANON\"}}" \
  "the positive control"

# required_fields — every envelope field the schema marks required.
required_fields() {
  awk -F'\t' '$1 == "field" && $3 == "required" { print $2 }' "$MODEL"
}

make_repo "$WORK/proj"
git -C "$WORK/proj" remote add origin "git@github.com:jwogrady/Spark.git"
cd "$WORK/proj"

mkdir -p "$WORK/bin"
export GH_CALL_LOG="$WORK/gh.calls"
export PATH="$WORK/bin:$PATH"
: > "$GH_CALL_LOG"

# The node as GitHub returns it, id included — the field the compiler must not
# version by. Every stub answers through the caller's own --jq, so the shipped
# jq program is exercised rather than a pre-shaped row agreeing with anything.
NODE='{"id":123456789,"full_name":"jwogrady/spark","default_branch":"master","updated_at":"2026-09-07T21:00:00Z","pushed_at":"2026-09-07T22:00:00Z"}'

stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB

OUT="$("$SPARK" facts)"

# --- the fragment shape ------------------------------------------------------
# A bare list. The complete snapshot is exactly {observer, facts}, and calling a
# one-class result a snapshot would be a lie a consumer is entitled to act on.
[ "$(printf '%s' "$OUT" | jq -r 'type')" = "array" ] && ok \
  || bad "the compiler must emit a fragment (a bare list), not a snapshot object"
[ "$(printf '%s' "$OUT" | jq -r 'length')" = "1" ] && ok \
  || bad "one class compiled means one fact"

F="$(printf '%s' "$OUT" | jq -r '.[0]')"
fget() { printf '%s' "$F" | jq -r "$1"; }

# --- the envelope is the schema's, field by field ---------------------------
for field in $(required_fields); do
  if [ "$(fget "has(\"$field\")")" = "true" ]; then ok
  else bad "the envelope is missing the required field '$field'"; fi
done

assert_contains "the fact declares the schema version it conforms to" "1" \
  "$(fget '.schema_version | tostring')"
assert_contains "and its class's one canonical key" "repository.identity" "$(fget '.key')"
assert_contains "and its class" "repository" "$(fget '.class')"
assert_contains "a readable source establishes the fact" "ESTABLISHED" "$(fget '.status')"

# --- the value is canonical by the schema's own grammar ---------------------
ID="$(fget '.value.id')"
printf '%s' "$ID" | grep -Eq "$(model_regex identifier repository)" && ok \
  || bad "value.id '$ID' is not a canonical <repository> identifier"
assert_contains "the remote's case is not a second identity" "github.com/jwogrady/spark" "$ID"
assert_contains "and the default branch comes from the same read" "master" \
  "$(fget '.value.default_branch')"

# --- provenance and freshness ------------------------------------------------
assert_contains "the source names the node that was read" "github-api" "$(fget '.source.type')"
assert_contains "identified as the repository itself" "github.com/jwogrady/spark" \
  "$(fget '.source.identity')"
printf '%s' "$(fget '.source.identity')" | grep -Eq "$(model_regex source-identity github-api)" && ok \
  || bad "source.identity is outside the github-api identity grammar"

# The trap this rule exists for: a node id never changes when the node does.
V="$(fget '.source.version')"
assert_contains "the source version is the node's updated_at" "2026-09-07T21:00:00Z" "$V"
[ "$V" = "123456789" ] && bad "a node id must never version a mutable node" || ok
printf '%s' "$V" | grep -Eq "$(model_regex source-version github-api)" && ok \
  || bad "source.version is outside the github-api version grammar"

printf '%s' "$(fget '.observed_at')" | grep -Eq "$(model_regex identifier timestamp)" && ok \
  || bad "observed_at is not a canonical timestamp"

assert_contains "one invalidator: the repository node" "repository:github.com/jwogrady/spark" \
  "$(fget '.invalidators[0]')"
[ "$(fget '.invalidators | length')" = "1" ] && ok || bad "exactly one invalidator applies here"
printf '%s' "$(fget '.invalidators[0]')" | grep -Eq "$(model_regex invalidator repository)" && ok \
  || bad "the invalidator is outside its token grammar"

# Freshness is a comparison of versions, never a judgement of age: the token
# says what the fact depends on, versions says as of when.
assert_contains "and that token's observed version is recorded" "2026-09-07T21:00:00Z" \
  "$(fget '.versions["repository:github.com/jwogrady/spark"]')"
[ "$(fget '.versions | length')" = "1" ] && ok \
  || bad "versions carries one entry per invalidator and no other key"

printf '%s' "$(fget '.provenance')" | grep -Eq "$(model_regex identifier provenance)" && ok \
  || bad "provenance is not a canonical pointer"
assert_versions_canonical "$F" "the established fact"

# R6: a value exists only under ESTABLISHED, and detail only under the other two.
[ "$(fget 'has("detail")')" = "false" ] && ok \
  || bad "an established fact carries no detail"

# --- one node, one read ------------------------------------------------------
# Three fields came from one response. A request per field could observe the
# node in three states and produce a conflict the repository does not have.
[ "$(grep -c . "$GH_CALL_LOG")" = "1" ] && ok \
  || bad "the repository node must be read once, not once per field ($(grep -c . "$GH_CALL_LOG") calls)"

# --- nothing is stored (R10) -------------------------------------------------
[ ! -f "$WORK/proj/.spark/state.json" ] && ok \
  || bad "the compiler must not write mutable GitHub truth into state.json"

# --- the read addresses the node the fact names ------------------------------
# `repos/{owner}/{repo}` is expanded by gh from its OWN context, so a compiler
# using it could read one repository and emit a fact about another — wrong in the
# one way this model exists to prevent, and wrong silently, because both halves
# are individually plausible.
assert_contains "the request names the repository the fact names" \
  "repos/jwogrady/spark" "$(cat "$GH_CALL_LOG")"
assert_contains "and the host it belongs to" "--hostname github.com" "$(cat "$GH_CALL_LOG")"
case "$(cat "$GH_CALL_LOG")" in
  *"{owner}"*) bad "the endpoint must not be left for gh to resolve" ;;
  *) ok ;;
esac

# gh reads $GH_REPO before it reads the remote. If the compiler let it, the
# environment could redirect the read while the fact still named the origin.
: > "$GH_CALL_LOG"
GH_REPO="someone/else" "$SPARK" facts > "$WORK/env.json"
assert_contains "the environment cannot redirect the read" "repos/jwogrady/spark" \
  "$(cat "$GH_CALL_LOG")"
case "$(cat "$GH_CALL_LOG")" in
  *"someone/else"*) bad "GH_REPO must not choose the node that is read" ;;
  *) ok ;;
esac
assert_contains "and the fact still names the origin" "github.com/jwogrady/spark" \
  "$(jq -r '.[0].value.id' < "$WORK/env.json")"
assert_versions_canonical "$(jq -r '.[0]' < "$WORK/env.json")" "the fact read under a redirected GH_REPO"

# A second remote is another thing gh may choose among. The identity is origin's.
git -C "$WORK/proj" remote add upstream "https://github.com/someone/else.git"
: > "$GH_CALL_LOG"
"$SPARK" facts >/dev/null
assert_contains "a second remote does not move the identity" "repos/jwogrady/spark" \
  "$(cat "$GH_CALL_LOG")"
git -C "$WORK/proj" remote remove upstream

# --- an Enterprise origin is read from its own host --------------------------
# Reading github.com for a github.example.com origin answers about a different
# repository that happens to share a name.
make_repo "$WORK/ent"
git -C "$WORK/ent" remote add origin "git@github.example.com:acme/widget.git"
stub_gh "$WORK/bin/gh" <<'STUB'
printf '%s\n' "$*" >> "$GH_CALL_LOG"
case "$*" in
  *"--hostname github.example.com repos/acme/widget"*)
    answer_json '{"full_name":"acme/widget","default_branch":"main","updated_at":"2026-09-07T21:00:00Z"}' ;;
  *) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
esac
STUB
: > "$GH_CALL_LOG"
E="$( (cd "$WORK/ent" && "$SPARK" facts) | jq -r '.[0]')"
assert_contains "an enterprise origin is read from its own host" \
  "--hostname github.example.com" "$(cat "$GH_CALL_LOG")"
assert_contains "and establishes the fact" "ESTABLISHED" \
  "$(printf '%s' "$E" | jq -r '.status')"
assert_contains "with the host in the identity" "github.example.com/acme/widget" \
  "$(printf '%s' "$E" | jq -r '.value.id')"
assert_contains "and its own default branch" "main" \
  "$(printf '%s' "$E" | jq -r '.value.default_branch')"
assert_versions_canonical "$E" "the enterprise fact"

# Back to the project fixture for the remaining cases.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB

# --- nothing is carried between runs -----------------------------------------
# The compiler is not a cache and not a database. A second invocation reads the
# source again rather than serving a fact from the first, which is what keeps a
# fact a statement about now instead of about the last time anyone looked.
: > "$GH_CALL_LOG"
"$SPARK" facts >/dev/null
"$SPARK" facts >/dev/null
[ "$(grep -c . "$GH_CALL_LOG")" = "2" ] && ok \
  || bad "each run observes its own source; nothing persists between them"
[ -z "$(ls -A "$WORK/proj/.spark" 2>/dev/null | grep -v '^repository$' || true)" ] && ok \
  || bad "the compiler must leave no fact store behind"

# --- a rename is a CONFLICT, not a choice ------------------------------------
# GitHub redirects an old name, so the read succeeds while naming a different
# repository. Picking either one would be the compiler inventing precedence.
: > "$GH_CALL_LOG"
stub_gh "$WORK/bin/gh" <<'STUB'
printf '%s\n' "$*" >> "$GH_CALL_LOG"
answer_json '{"full_name":"jwogrady/spark-renamed","default_branch":"master","updated_at":"2026-09-07T21:00:00Z"}'
STUB
C="$("$SPARK" facts | jq -r '.[0]')"
assert_contains "a repository that names itself differently is a conflict" "CONFLICT" \
  "$(printf '%s' "$C" | jq -r '.status')"
[ "$(printf '%s' "$C" | jq -r 'has("value")')" = "false" ] && ok \
  || bad "a conflict carries no value"
assert_contains "both candidates are named" "github.com/jwogrady/spark" \
  "$(printf '%s' "$C" | jq -r '.detail.candidates[0]')"
assert_contains "including the one GitHub reports" "github.com/jwogrady/spark-renamed" \
  "$(printf '%s' "$C" | jq -r '.detail.candidates[1]')"
[ "$(printf '%s' "$C" | jq -r '.detail.candidates | length')" = "2" ] && ok \
  || bad "a conflict names exactly the candidates it saw"
# A CONFLICT is an emitted fact, so it is held to the version grammar like every
# other. It can be: the node WAS read, so its version was observed.
assert_versions_canonical "$C" "the conflict fact"

# --- the unreadable ladder ---------------------------------------------------
# Every one of these is UNKNOWN with a reason. None is a permissive default, and
# none carries a value: an unreadable source is not a smaller success.
# An unreadable source yields NO FACT, and the reason why is the point.
#
# An UNKNOWN is a full envelope: it names the node it depends on and records the
# version observed for that node, which is how freshness is decided. For this
# class that version form is the node's own updated_at — exactly what a failed
# read denies. An empty string is not a version, and the observation instant is
# not one either: writing it would fabricate evidence in the one field whose job
# is to say what was seen. So the failure is reported, with its reason, and no
# fact is emitted.
unreadable_case() { # unreadable_case <message> <expected reason> <label>
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
echo "$1" >&2
exit 1
STUB
  local out rc=0
  out="$("$SPARK" facts 2>&1)" || rc=$?
  [ "$rc" = "3" ] && ok || bad "$3: an unreadable source yields no fact (got $rc)"
  assert_contains "$3" "$2" "$out"
  assert_contains "$3: and says nothing was established" "NOT ASSESSED" "$out"
  case "$out" in
    *'"key"'*|*'"versions"'*) bad "$3: no envelope may be emitted without an observed version" ;;
    *) ok ;;
  esac
}

unreadable_case 'gh: Bad credentials (HTTP 401)'      'permission-denied' 'a 401 is a permission answer'
unreadable_case 'gh: Forbidden (HTTP 403)'            'permission-denied' 'and so is a plain 403'
unreadable_case 'gh: API rate limit exceeded (HTTP 403)' 'rate-limited'   'but a 403 carrying a rate limit is rate limiting'
unreadable_case 'gh: Not Found (HTTP 404)'            'not-found'         'a 404 is not-found'
unreadable_case 'gh: Too Many Requests (HTTP 429)'    'rate-limited'      'a 429 is rate limiting'
unreadable_case 'error: context deadline exceeded'    'timeout'           'a timeout says so'
unreadable_case 'gh: something nobody anticipated'    'unreadable'        'and an unrecognised failure is still stated, never guessed at'

# A response that parsed but does not carry the fields is malformed — an empty
# default branch is not a repository with no trunk.
stub_gh "$WORK/bin/gh" <<'STUB'
answer_json '{"full_name":"jwogrady/spark","default_branch":null,"updated_at":"2026-09-07T21:00:00Z"}'
STUB
M="$("$SPARK" facts | jq -r '.[0]')"
assert_contains "a response missing a field is malformed" "malformed" \
  "$(printf '%s' "$M" | jq -r '.detail.reason')"
assert_contains "and malformed is unknown, not established" "UNKNOWN" \
  "$(printf '%s' "$M" | jq -r '.status')"

# A field that is present but outside its grammar is malformed too, and this is
# the sharper half of the rule: an empty field is obviously missing, while
# "not-a-timestamp" looks like an answer. Emitted, it would become this fact's
# source version and its invalidator's observed version, so freshness — which is
# a comparison of versions — would be comparing something that is not one.
# A malformed field is two different situations, and the difference is whether
# the node's own version was observed.
#
# malformed_case: the read succeeded and updated_at was a real instant, so the
# envelope conforms — the fact is emitted as UNKNOWN, carrying the version that
# was actually observed, and only the value is missing.
malformed_case() { # malformed_case <node json> <label>
  stub_gh "$WORK/bin/gh" <<STUB
answer_json '$1'
STUB
  local m; m="$("$SPARK" facts | jq -r '.[0]')"
  assert_contains "$2" "malformed" "$(printf '%s' "$m" | jq -r '.detail.reason')"
  [ "$(printf '%s' "$m" | jq -r '.status')" = "UNKNOWN" ] && ok \
    || bad "$2: an invalid field is UNKNOWN, not ESTABLISHED"
  [ "$(printf '%s' "$m" | jq -r 'has("value")')" = "false" ] && ok \
    || bad "$2: and carries no value"
  # The whole point of the repair: this UNKNOWN is schema-valid, because the
  # node WAS read and its version recorded.
  assert_versions_canonical "$m" "$2"
  [ "$(printf '%s' "$m" | jq -r '.invalidators[0]')" = "repository:github.com/jwogrady/spark" ] && ok \
    || bad "$2: an unknown still names the node it read"
}

# refused_case: the version itself is not a version, so no envelope can be built
# at all and nothing is emitted.
refused_case() { # refused_case <node json> <label>
  stub_gh "$WORK/bin/gh" <<STUB
answer_json '$1'
STUB
  local out rc=0
  out="$("$SPARK" facts 2>&1)" || rc=$?
  [ "$rc" = "3" ] && ok || bad "$2: no observed version means no fact (got $rc)"
  assert_contains "$2" "NOT ASSESSED" "$out"
  case "$out" in
    *'"key"'*|*'"versions"'*) bad "$2: nothing may be emitted without an observed version" ;;
    *) ok ;;
  esac
}

refused_case '{"full_name":"jwogrady/spark","default_branch":"master","updated_at":"not-a-timestamp"}' \
  'a version outside the timestamp grammar yields no fact'
refused_case '{"full_name":"jwogrady/spark","default_branch":"master","updated_at":"2026-02-30T00:00:00Z"}' \
  'and neither does an instant the calendar does not have'
malformed_case '{"full_name":"not a repository name","default_branch":"master","updated_at":"2026-09-07T21:00:00Z"}' \
  'a name outside the repository grammar is malformed'
malformed_case '{"full_name":"jwogrady/spark.git","default_branch":"master","updated_at":"2026-09-07T21:00:00Z"}' \
  'including one carrying the clone URL suffix a constraint forbids'
malformed_case '{"full_name":"jwogrady/spark","default_branch":"refs/heads/master","updated_at":"2026-09-07T21:00:00Z"}' \
  'a ref spelled as its refs/ path is malformed'
malformed_case '{"full_name":"jwogrady/spark","default_branch":"bad..name","updated_at":"2026-09-07T21:00:00Z"}' \
  'and so is a branch name Git would refuse'

# A body that arrived and cannot be decoded is a different fact about the world
# from a body that never arrived, and reporting the first as unreadable would
# send a caller to check credentials and connectivity that are demonstrably fine.
# Every malformed case above is valid JSON, so none of them crosses this line.
: > "$GH_CALL_LOG"
stub_gh "$WORK/bin/gh" <<'STUB'
printf '%s\n' "$*" >> "$GH_CALL_LOG"
printf 'this is not json'
STUB
dout="$("$SPARK" facts 2>&1)" && drc=0 || drc=$?
[ "$drc" = "3" ] && ok || bad "an undecodable body yields no fact (got $drc)"
assert_contains "an undecodable body is malformed, not unreadable" "malformed" "$dout"
assert_contains "and nothing is established" "NOT ASSESSED" "$dout"
[ "$(grep -c . "$GH_CALL_LOG")" = "1" ] && ok \
  || bad "a decode failure must not cost a second read"

# A field of the wrong type is decodable and still not an answer. The projection
# is total, so this lands on the malformed path rather than erroring as if the
# request had failed.
malformed_case '{"full_name":{"nested":"object"},"default_branch":"master","updated_at":"2026-09-07T21:00:00Z"}' \
  'an object where a name belongs is malformed'
malformed_case '{"full_name":"jwogrady/spark","default_branch":["master"],"updated_at":"2026-09-07T21:00:00Z"}' \
  'and so is an array where a branch belongs'
refused_case '{"full_name":"jwogrady/spark","default_branch":"master","updated_at":1757280000}' \
  'nor a number where an instant belongs'
refused_case '[]' 'a body that is not an object at all yields no fact'

# A remote that does not normalize to a canonical repository cannot name a node
# either — the same answer as no remote at all, for the same reason.
make_repo "$WORK/odd"
git -C "$WORK/odd" remote add origin "git@localhost:no-host-here.git"
out="$(cd "$WORK/odd" && "$SPARK" facts 2>&1)" && rc=0 || rc=$?
[ "$rc" = "3" ] && ok || bad "a non-canonical remote cannot name a repository (got $rc)"
assert_contains "and says so rather than inventing an identity" "NOT ASSESSED" "$out"

# --- an unnameable repository is not assessed --------------------------------
# An UNKNOWN still identifies its node. With no remote there is no node to name,
# so nothing is emitted rather than a fact whose identity was invented.
make_repo "$WORK/bare"
out="$(cd "$WORK/bare" && "$SPARK" facts 2>&1)" && rc=0 || rc=$?
[ "$rc" = "3" ] && ok || bad "a repository with no origin cannot be named (got $rc)"
assert_contains "and says so rather than emitting a fact" "NOT ASSESSED" "$out"
case "$out" in *'"key"'*) bad "nothing may be emitted for a repository that cannot be named" ;; *) ok ;; esac

# --- an unusable clock is a reason there is no fact --------------------------
# Every envelope carries the instant its source was read, an UNKNOWN as much as
# an ESTABLISHED one, so an instant outside the grammar cannot be emitted by any
# branch. The combination that matters is a bad clock WITH a failing read: that
# is the branch which reports a failure and would happily have reported it with
# an invalid observed_at.
mkdir -p "$WORK/badclock"
printf '#!/usr/bin/env bash\necho not-a-timestamp\n' > "$WORK/badclock/date"
chmod +x "$WORK/badclock/date"
stub_gh "$WORK/bin/gh" <<'STUB'
echo 'gh: Not Found (HTTP 404)' >&2
exit 1
STUB
out="$(PATH="$WORK/badclock:$PATH" "$SPARK" facts 2>&1)" && rc=0 || rc=$?
[ "$rc" = "3" ] && ok || bad "an unusable clock cannot yield a fact (got $rc)"
assert_contains "and says which input was unusable" "NOT ASSESSED" "$out"
case "$out" in
  *'"observed_at"'*|*'"key"'*) bad "no envelope may be emitted without a usable instant" ;;
  *) ok ;;
esac

# The same with a readable source: the clock alone decides this, before any read.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB
: > "$GH_CALL_LOG"
out="$(PATH="$WORK/badclock:$PATH" "$SPARK" facts 2>&1)" && rc=0 || rc=$?
[ "$rc" = "3" ] && ok || bad "a readable source does not rescue an unusable clock"
[ ! -s "$GH_CALL_LOG" ] && ok \
  || bad "the source must not be read when no envelope could carry the reading"

# --- a run that compiled nothing still reports its metrics -------------------
# Zero emitted and zero reads is a real answer: this verb ran and found nothing
# it could name. Skipping the record would make an observed run indistinguishable
# from a run that never happened.
SPARK_RUN_ID=rzero bash -c 'cd "$1" && SPARK_RUN_ID=rzero "$2" facts >/dev/null 2>&1' _ "$WORK/odd" "$SPARK" || true
TELZ="$(cd "$WORK/odd" && "$SPARK" telemetry show --run rzero --json 2>/dev/null)"
assert_contains "a not-assessed run records zero emitted" '"facts_emitted":0' "$TELZ"
assert_contains "and zero source reads" '"facts_api_calls":0' "$TELZ"
assert_contains "and zero unknown, because nothing was compiled at all" '"facts_unknown":0' "$TELZ"

# --- the compiler's own cost is observable -----------------------------------
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB
SPARK_RUN_ID=rfacts "$SPARK" facts >/dev/null
TEL="$("$SPARK" telemetry show --run rfacts --json)"
assert_contains "the compiler reports what it emitted" '"facts_emitted":1' "$TEL"
assert_contains "and what it read" '"facts_api_calls":1' "$TEL"
assert_contains "and that nothing was unreadable" '"facts_unknown":0' "$TEL"

# An unreadable run emitted nothing, and says so: one read, no fact. The counts
# stay truthful rather than reporting an unknown that was never emitted.
stub_gh "$WORK/bin/gh" <<'STUB'
echo 'gh: Not Found (HTTP 404)' >&2
exit 1
STUB
SPARK_RUN_ID=rfacts2 "$SPARK" facts >/dev/null 2>&1 || true
TEL2="$("$SPARK" telemetry show --run rfacts2 --json)"
assert_contains "an unreadable run emitted no fact" '"facts_emitted":0' "$TEL2"
assert_contains "and counts no unknown it never emitted" '"facts_unknown":0' "$TEL2"
assert_contains "while still reporting the read it made" '"facts_api_calls":1' "$TEL2"

# A malformed field that still let the version be observed DOES emit, and the
# counts distinguish the two situations.
stub_gh "$WORK/bin/gh" <<'STUB'
answer_json '{"full_name":"not a name","default_branch":"master","updated_at":"2026-09-07T21:00:00Z"}'
STUB
SPARK_RUN_ID=rfacts3 "$SPARK" facts >/dev/null 2>&1 || true
TEL3="$("$SPARK" telemetry show --run rfacts3 --json)"
assert_contains "a conforming unknown is emitted and counted" '"facts_emitted":1' "$TEL3"
assert_contains "and counted as unknown" '"facts_unknown":1' "$TEL3"


# =========================================================================
# The graph fact (#733 packet 2)
# =========================================================================
#
# A graph is a graph OF a work unit, and every node it names carries a state and
# an observed version. The three things a happy-path check would miss:
#
#   * GitHub's vocabulary is OPEN/CLOSED and the model's is open|closed. Four
#     readers in this runtime spelled that difference four ways, which is the
#     residual ambiguity this packet's acceptance item names;
#   * a truncated relationship list is an UNKNOWN, not a shorter graph — the
#     node's own version was observed, so the envelope conforms and says what it
#     could not see;
#   * one node carries one state. A repeat with a different state has no
#     representation and must be refused, not resolved by picking one.

# graph_stub <issue json|null> — answer the graph query with this issue node, and
# the repository query as usual, so a --issue run sees both sources.
graph_stub() {
  # `issueOrPullRequest` is what the compiler now asks, and the node carries its
  # own kind. Every fixture below is an issue, so the default is injected here
  # rather than repeated in each one — a fixture that needs another kind sets
  # __typename itself and this leaves it alone.
  local node
  node="$(printf '%s' "$1" | jq -c 'if type == "object"
                                    then . + {__typename: (.__typename // "Issue")}
                                    else . end')"
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) answer_json '{"data":{"repository":{"issueOrPullRequest":$node}}}' ;;
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB
}

# gfact — the graph fact out of a --issue run.
gfact() { printf '%s' "$1" | jq -r '.[] | select(.key=="graph.native")'; }

REL='{"__typename":"Issue","number":%d,"state":"%s","updatedAt":"%s","repository":{"nameWithOwner":"jwogrady/spark"}}'

FULL='{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":728,"state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"CLOSED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
    {"__typename":"PullRequest","number":741,"state":"OPEN","updatedAt":"2026-09-07T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":700,"state":"CLOSED","updatedAt":"2026-09-06T07:00:00Z","repository":{"nameWithOwner":"OTHER/Repo"}}]}}'

: > "$GH_CALL_LOG"
graph_stub "$FULL"
GOUT="$("$SPARK" facts --issue 733)"
G="$(gfact "$GOUT")"

# --- the fragment carries all three classes, and is still a fragment --------
[ "$(printf '%s' "$GOUT" | jq -r 'type')" = "array" ] && ok || bad "a fragment is a bare list"
[ "$(printf '%s' "$GOUT" | jq -r 'length')" = "3" ] && ok \
  || bad "a --issue run compiles the repository, the work unit and the graph"
[ "$(printf '%s' "$GOUT" | jq -r '[.[].key] | sort | join(",")')" = "graph.native,repository.identity,work_unit.identity" ] \
  && ok || bad "and those three classes exactly"

# --- the envelope is the schema's ------------------------------------------
for field in $(required_fields); do
  if [ "$(printf '%s' "$G" | jq -r "has(\"$field\")")" = "true" ]; then ok
  else bad "the graph envelope is missing the required field '$field'"; fi
done
assert_contains "the graph fact carries its class's one key" "graph.native" \
  "$(printf '%s' "$G" | jq -r '.key')"
assert_contains "a whole relationship set establishes the fact" "ESTABLISHED" \
  "$(printf '%s' "$G" | jq -r '.status')"
[ "$(printf '%s' "$G" | jq -r 'has("detail")')" = "false" ] && ok \
  || bad "an established graph carries no detail"

# --- the source is the work-unit node, versioned by its own updatedAt ------
assert_contains "the source names the work unit it was read from" "github.com/jwogrady/spark#733" \
  "$(printf '%s' "$G" | jq -r '.source.identity')"
printf '%s' "$(printf '%s' "$G" | jq -r '.source.identity')" \
  | grep -Eq "$(model_regex identifier work-unit)" && ok \
  || bad "source.identity is not a canonical work-unit locator"
assert_contains "versioned by the node's own updatedAt" "2026-09-08T10:00:00Z" \
  "$(printf '%s' "$G" | jq -r '.source.version')"
assert_versions_canonical "$G" "the graph fact"

# --- GitHub's vocabulary is translated, once -------------------------------
# This is acceptance item 7's residual ambiguity: OPEN/CLOSED in, open|closed out.
assert_contains "the parent's state is the model's vocabulary" "open" \
  "$(printf '%s' "$G" | jq -r '.value.parent.state')"
assert_contains "and a closed child's is too" "closed" \
  "$(printf '%s' "$G" | jq -r '.value.children[] | select(.id|test("#740")) | .state')"
[ -z "$(printf '%s' "$G" | jq -r '[.. | objects | select(has("state")) | .state] | map(select(. != "open" and . != "closed")) | join(",")')" ] \
  && ok || bad "no state outside the model's closed vocabulary may appear"
printf '%s' "$(printf '%s' "$G" | jq -r '.value.parent.state')" \
  | grep -Eq "$(model_regex identifier issue-state)" && ok \
  || bad "a state is outside the issue-state grammar"

# --- kinds are read, not assumed ------------------------------------------
# The invalidator form differs for an issue and a pull request, so a compiler
# that guessed the kind would emit a token naming the wrong sort of node.
assert_contains "a pull-request child is named as one" "pull_request" \
  "$(printf '%s' "$G" | jq -r '.value.children[] | select(.id|test("#741")) | .kind')"
assert_contains "and gets the pull_request invalidator" "pull_request:github.com/jwogrady/spark#741" \
  "$(printf '%s' "$G" | jq -r '.invalidators | join(" ")')"
assert_contains "while an issue child gets the issue one" "issue:github.com/jwogrady/spark#740" \
  "$(printf '%s' "$G" | jq -r '.invalidators | join(" ")')"

# --- a foreign blocker keeps its own identity -----------------------------
assert_contains "a blocker in another repository is named by that repository" \
  "github.com/other/repo#700" "$(printf '%s' "$G" | jq -r '.value.blocked_by[0].id')"

# --- every named node is an invalidator, with its own observed version ----
[ "$(printf '%s' "$G" | jq -r '.invalidators | length')" = "5" ] && ok \
  || bad "the node and its four relations are each an invalidator"
[ "$(printf '%s' "$G" | jq -r '.versions | length')" = "5" ] && ok \
  || bad "versions carries one entry per invalidator"
assert_contains "the work unit's own token is listed" "issue:github.com/jwogrady/spark#733" \
  "$(printf '%s' "$G" | jq -r '.invalidators | join(" ")')"
assert_contains "and each relation's version is that node's" "2026-09-06T07:00:00Z" \
  "$(printf '%s' "$G" | jq -r '.versions["issue:github.com/other/repo#700"]')"

# --- one read for the whole graph -----------------------------------------
[ "$(grep -c graphql "$GH_CALL_LOG")" = "1" ] && ok \
  || bad "the graph is one request, not one per relationship ($(grep -c graphql "$GH_CALL_LOG"))"

# --- a truncated list is an unknown, not a shorter graph ------------------
# The truncated page CARRIES nodes, which is what a real truncation looks like.
# An empty truncated page cannot show the defect this pins: partial nodes must
# not survive in the invalidators of a fact that says it saw no relationships.
TRUNC='{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":728,"state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"Issue","number":740,"state":"CLOSED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
    {"__typename":"Issue","number":742,"state":"CLOSED","updatedAt":"2026-09-07T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
graph_stub "$TRUNC"
GT="$(gfact "$("$SPARK" facts --issue 733)")"
assert_contains "a truncated relationship list is unknown" "UNKNOWN" \
  "$(printf '%s' "$GT" | jq -r '.status')"
assert_contains "and says which list it could not see" "children" \
  "$(printf '%s' "$GT" | jq -r '.detail.reason')"
[ "$(printf '%s' "$GT" | jq -r 'has("value")')" = "false" ] && ok \
  || bad "a truncated graph carries no value — a bounded read is not a smaller set"
# It conforms, because the node's own version WAS observed.
assert_versions_canonical "$GT" "the truncated graph"
[ "$(printf '%s' "$GT" | jq -r '.invalidators | length')" = "1" ] && ok \
  || bad "an unknown graph names the node it read and no relationship it cannot describe"
# The sharp edge: the partial page's nodes must not survive here. A fact that
# denies knowing the relationship set cannot also claim a freshness contract
# over part of it.
[ "$(printf '%s' "$GT" | jq -r '.invalidators | join(" ")')" = "issue:github.com/jwogrady/spark#733" ] \
  && ok || bad "a partial page's nodes must not remain in an unknown graph's invalidators"
[ "$(printf '%s' "$GT" | jq -r '.versions | length')" = "1" ] && ok \
  || bad "nor in its versions"

# Both lists truncated is the same answer, and names one of them.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"Issue","number":740,"state":"CLOSED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"Issue","number":700,"state":"OPEN","updatedAt":"2026-09-06T07:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]}}'
GT2="$(gfact "$("$SPARK" facts --issue 733)")"
assert_contains "two truncated lists are still one unknown" "UNKNOWN" \
  "$(printf '%s' "$GT2" | jq -r '.status')"
# And it must name BOTH. A fact that says what it could not see, and names only
# half of it, is telling a caller the other half was read.
assert_contains "and names the first incomplete list" "blockers" \
  "$(printf '%s' "$GT2" | jq -r '.detail.reason')"
assert_contains "and the second" "children" \
  "$(printf '%s' "$GT2" | jq -r '.detail.reason')"
[ "$(printf '%s' "$GT2" | jq -r '.invalidators | length')" = "1" ] && ok \
  || bad "and it still names only the work unit"
assert_versions_canonical "$GT2" "the doubly truncated graph"

# --- no parent is 'none', not a missing key ------------------------------
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GN="$(gfact "$("$SPARK" facts --issue 733)")"
assert_contains "a work unit with no parent says none" "none" \
  "$(printf '%s' "$GN" | jq -r '.value.parent')"
[ "$(printf '%s' "$GN" | jq -r '.value.children | length')" = "0" ] && ok \
  || bad "and carries an empty child list"

# --- one node, one state -------------------------------------------------
DUP_SAME='{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"CLOSED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
    {"__typename":"Issue","number":740,"state":"CLOSED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
graph_stub "$DUP_SAME"
GD="$(gfact "$("$SPARK" facts --issue 733)")"
[ "$(printf '%s' "$GD" | jq -r '.value.children | length')" = "1" ] && ok \
  || bad "a node listed twice with one state appears once"

DUP_DIFF='{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"CLOSED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
graph_stub "$DUP_DIFF"
gout="$("$SPARK" facts --issue 733 2>/dev/null)" && grc=0 || grc=$?
case "$(printf '%s' "$gout" | jq -r '[.[].key] | join(",")' 2>/dev/null)" in
  *graph.native*) bad "one node cannot carry two states — that has no representation" ;;
  *) ok ;;
esac

# --- what cannot be named or canonicalized is refused --------------------
graph_refused() { # graph_refused <issue json> <label>
  graph_stub "$1"
  local out; out="$("$SPARK" facts --issue 733 2>&1)"
  case "$(printf '%s' "$out" | jq -r '[.[].key] | join(",")' 2>/dev/null)" in
    *graph.native*) bad "$2" ;;
    *) ok ;;
  esac
}
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"MERGED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a relation state outside the vocabulary must not be emitted"

# The work unit's OWN state is not part of this class: the value carries the
# state of each relation, and the work unit's belongs to another fact. So a
# state this class does not represent cannot make its graph unreadable —
# asserting otherwise would be inventing strictness rather than implementing the
# contract.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"SOMETHING_ELSE","updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":728,"state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GS="$(gfact "$("$SPARK" facts --issue 733)")"
assert_contains "the work unit's own state is not this class's business" "ESTABLISHED" \
  "$(printf '%s' "$GS" | jq -r '.status')"
[ -z "$(printf '%s' "$GS" | jq -r '[.. | objects | select(has("state")) | .state] | map(select(. != "open" and . != "closed")) | join(",")')" ] \
  && ok || bad "and no state it does not represent leaks into the value"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"not-an-instant","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a node version that is not a version leaves nothing to record"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Discussion","number":9,"state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a node kind with no invalidator form must not be guessed at"
graph_refused 'null' "a work unit that does not exist yields no graph"

# --- a partial or errored reply is not a reading of the graph ------------
# GraphQL can answer with errors beside partial data, and a null list is not an
# empty one. Compiling either would state that the work unit has no
# relationships, which is a different fact from not having been able to see them.
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":null,
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a null relationship list is not an empty one"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false}},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a list with no nodes key was not returned, not returned empty"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":null,"parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a node with no version leaves nothing to record"

# A reply carrying errors is refused even when it also carries data.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) answer_json '{"errors":[{"message":"Something went wrong"}],"data":{"repository":{"issueOrPullRequest":{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},"blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}}}}' ;;
  *) answer_json '$NODE' ;;
esac
STUB
eout="$("$SPARK" facts --issue 733 2>&1)"
case "$(printf '%s' "$eout" | jq -r '[.[].key] | join(",")' 2>/dev/null)" in
  *graph.native*) bad "a reply carrying errors must not compile as a graph" ;;
  *) ok ;;
esac
assert_contains "and the reason says the reply was malformed" "malformed" "$eout"

# --- an unreadable graph source is refused, like the repository's --------
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) echo 'gh: Not Found (HTTP 404)' >&2; exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
gout="$("$SPARK" facts --issue 733 2>&1)"
assert_contains "an unreadable graph names its reason" "not-found" "$gout"
case "$(printf '%s' "$gout" | jq -r '[.[].key] | join(",")' 2>/dev/null)" in
  *graph.native*) bad "an unreadable graph must emit no fact" ;;
  *) ok ;;
esac
# The repository fact still comes back: one class failing does not silence another.
assert_contains "while the class that could be read is still emitted" "repository.identity" "$gout"

# --- the flag is validated before it reaches a query --------------------
graph_stub "$FULL"
for bad_arg in 0 abc 12x -3; do
  out="$("$SPARK" facts --issue "$bad_arg" 2>&1)" && rc=0 || rc=$?
  [ "$rc" = "1" ] && ok || bad "--issue $bad_arg must be refused (got $rc)"
done

# A flag that was SUPPLIED and left empty is a caller error, not the flag's
# absence. Treating it as absence would quietly compile a different set of facts
# than the caller asked for.
out="$("$SPARK" facts --issue 2>&1)" && rc=0 || rc=$?
[ "$rc" = "1" ] && ok || bad "--issue with no value must be refused (got $rc)"
case "$out" in *'"key"'*) bad "--issue with no value must not compile anything" ;; *) ok ;; esac
out="$("$SPARK" facts --issue= 2>&1)" && rc=0 || rc=$?
[ "$rc" = "1" ] && ok || bad "--issue= must be refused (got $rc)"
case "$out" in *'"key"'*) bad "--issue= must not compile anything" ;; *) ok ;; esac

# And the flag's absence still compiles exactly the repository class.
out="$("$SPARK" facts)"
[ "$(printf '%s' "$out" | jq -r 'length')" = "1" ] && ok \
  || bad "without the flag only the repository class is compiled"

# --- the compiler's cost, with three classes ----------------------------
: > "$GH_CALL_LOG"
graph_stub "$FULL"
SPARK_RUN_ID=rgraph "$SPARK" facts --issue 733 >/dev/null
TELG="$("$SPARK" telemetry show --run rgraph --json)"
assert_contains "three classes compiled means three facts" '"facts_emitted":3' "$TELG"
# Still TWO reads for three facts: the repository node, and one work-unit node
# that work_unit and graph share. A third read here would mean the two classes
# had described the same node from two separate observations.
assert_contains "from two source reads, not three" '"facts_api_calls":2' "$TELG"
assert_contains "and the shared observation is reused once" '"facts_cache_hits":1' "$TELG"
assert_contains "and nothing unknown" '"facts_unknown":0' "$TELG"

# --- a pageInfo that does not say whether more pages exist ------------------
# Absence of a completeness signal is not a completeness signal. A list whose
# hasNextPage is missing, null or the wrong type has not told us it is whole, so
# it cannot compile as a graph that saw everything.
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a pageInfo with no hasNextPage has not said the list is complete"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":null},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "nor has a null hasNextPage"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":"false"},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "and a string is not a boolean, whatever it spells"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{},"nodes":[]}}' \
  "the blocker list is held to the same rule"

# --- a node can be both a child and a blocker -----------------------------
# Membership is per list; identity is global. Tracking uniqueness across the
# lists would silently drop one of two real edges.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]}}'
GB="$(gfact "$("$SPARK" facts --issue 733)")"
assert_contains "a node that is both a child and a blocker is established" "ESTABLISHED" \
  "$(printf '%s' "$GB" | jq -r '.status')"
[ "$(printf '%s' "$GB" | jq -r '.value.children | length')" = "1" ] && ok \
  || bad "it appears as a child"
[ "$(printf '%s' "$GB" | jq -r '.value.blocked_by | length')" = "1" ] && ok \
  || bad "and as a blocker — one edge is not a duplicate of the other"
# One node, one invalidator and one version, however many relationships it has.
[ "$(printf '%s' "$GB" | jq -r '.invalidators | length')" = "2" ] && ok \
  || bad "the node and the work unit are two invalidators, not three"
[ "$(printf '%s' "$GB" | jq -r '.versions | length')" = "2" ] && ok \
  || bad "and two observed versions"
assert_versions_canonical "$GB" "the shared-node graph"

# The same node reported with two different states has no representation.
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"CLOSED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]}}' \
  "one node cannot be open in one list and closed in another"

# Nor with two different observed versions: one node has one version.
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]}}' \
  "and cannot carry two observed versions"

# A node listed twice within ONE list is still one member of it.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GW="$(gfact "$("$SPARK" facts --issue 733)")"
[ "$(printf '%s' "$GW" | jq -r '.value.children | length')" = "1" ] && ok \
  || bad "a node listed twice in one list appears once in it"
[ "$(printf '%s' "$GW" | jq -r '.invalidators | length')" = "2" ] && ok \
  || bad "and contributes one invalidator"

# --- a list that is not a list ---------------------------------------------
# Same rule as the null list and the missing hasNextPage: a shape that cannot
# answer "which nodes" is not an answer of "none".
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":{}},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "an object where the node list belongs is not an empty list"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":"none"}}' \
  "and neither is a string"

# --- the root is an issue, and the reason says which case applies -----------
# GitHub gives parent, subIssues and blockedBy to Issue and to nothing else, so
# a pull request has no native graph to report. "That is a pull request" and
# "there is no such work unit" send a caller to different places, so they are
# told apart by the SAME read: `issueOrPullRequest` returns either kind as data.
# A GraphQL resolve failure therefore means neither exists, and absence is the
# only thing it can mean — there is no second request left to disagree with it.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) echo 'gh: Could not resolve to an Issue with the number of 733.' >&2; exit 1 ;;
  *"pulls/"*) echo 'a second request was made for a kind the first read already named' >&2; exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
: > "$GH_CALL_LOG"
nout="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
assert_contains "a number that names neither is absent" "no work unit by that number" "$nout"
assert_eq "and nothing was probed to establish that" "0" \
  "$(grep -c 'pulls/' "$GH_CALL_LOG" || true)"

# A work unit that does not exist is not an unreadable source: reporting it that
# way would send a caller to check access it already has.
case "$nout" in
  *unreadable*) bad "an absent work unit is not an unreadable source" ;;
  *) ok ;;
esac

# --- stdout stays a machine surface ----------------------------------------
# A fragment followed by a human note is not parseable JSON, which is exactly
# what a caller piping this would discover at the worst moment.
gout="$("$SPARK" facts --issue 733 2>/dev/null)"
[ "$(printf '%s' "$gout" | jq -r 'type')" = "array" ] && ok \
  || bad "stdout must stay parseable when a class could not be established"
[ "$(printf '%s' "$gout" | jq -r 'length')" = "1" ] && ok \
  || bad "and carry only the class that was established"
[ -n "$nout" ] && ok || bad "while the reason is reported on stderr, not dropped"

# --- failing to look is not absence ----------------------------------------
# Every non-zero result used to be read as not-found somewhere in this path, so
# a 401 or a rate limit asserted that the work unit does not exist — sending a
# caller to create something that may already be there. Only GitHub explicitly
# resolving nothing is absence; every other failure keeps its own reason.
read_case() { # read_case <gh stderr> <expected reason> <label>
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) echo "$1" >&2; exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
  local out; out="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
  assert_contains "$3" "$2" "$out"
  case "$out" in
    *"no work unit by that number"*) bad "$3: a failed read was reported as absence" ;;
    *) ok ;;
  esac
}
read_case 'gh: Bad credentials (HTTP 401)'         'permission-denied' 'a 401 is a permission answer, not absence'
read_case 'gh: API rate limit exceeded (HTTP 403)' 'rate-limited'      'and a rate limit is not absence either'
read_case 'error: context deadline exceeded'       'timeout'           'nor is a timeout'
read_case 'gh: Internal Server Error (HTTP 500)'   'unreadable'        'and an unclassified failure is still not absence'

# --- the node returned must be the node asked for --------------------------
# A response naming a different issue would compile that issue's version and
# relationships under this work unit's identity: one node wearing another's name.
graph_refused '{"number":734,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a graph for another issue must not be compiled under this work unit"
graph_refused '{"number":null,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a root with no number names nothing"
graph_refused '{"number":"733","repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "and a string is not an issue number, whatever it spells"

# The control: the matching number still establishes, so the check discriminates.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GM="$(gfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_contains "the requested work unit's own graph is established" "ESTABLISHED" \
  "$(printf '%s' "$GM" | jq -r '.status')"
assert_contains "and named as itself" "github.com/jwogrady/spark#733" \
  "$(printf '%s' "$GM" | jq -r '.source.identity')"

# --- a reply that did not answer is not a reply of "no" --------------------
# Only an explicitly present, null `issue` is GitHub saying there is no such
# issue. Everything else here is a reply that failed to answer the question, and
# calling that absence produces a confident wrong reason two steps later.
raw_graph_stub() { # raw_graph_stub <whole graphql response>
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) answer_json '$1' ;;
  *"pulls/"*) echo 'a second request was made for a kind the first read already named' >&2; exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
}

malformed_root() { # malformed_root <response> <label>
  raw_graph_stub "$1"
  local out; out="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
  assert_contains "$2" "malformed" "$out"
  case "$out" in
    *"pull request has no native graph"*) bad "$2: a reply that did not answer is not a pull request" ;;
    *not-found*) bad "$2: a reply that did not answer is not absence" ;;
    *) ok ;;
  esac
}

malformed_root '{}' "a reply with no data did not answer"
malformed_root '{"data":null}' "and neither did a null data"
malformed_root '{"data":{}}' "nor one with no repository"
malformed_root '{"data":{"repository":null}}' "nor a null repository"
malformed_root '{"data":{"repository":{}}}' "nor a repository with no work-unit key"

# --- the kind is read once, never probed for --------------------------------
# This replaces a REST probe ladder. `issueOrPullRequest` returns a pull request
# as DATA carrying its own __typename, so "there is no such work unit" and "that
# is a pull request" are two readings of ONE observation. The old second request
# had to classify its own failures — a 401, a rate limit and a timeout each had
# to be kept apart from absence — and none of that can be got wrong now, because
# none of it happens.

# An explicitly null work unit IS absence, and absence is all it is.
raw_graph_stub '{"data":{"repository":{"issueOrPullRequest":null}}}'
aout="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
assert_contains "an explicitly null work unit is absence, and nothing else" \
  "no work unit by that number" "$aout"
case "$aout" in
  *"pull request"*) bad "absence was reported as a pull request" ;;
  *) ok ;;
esac

# A pull request is named by the same read that found it.
: > "$GH_CALL_LOG"
graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
pout="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
assert_contains "a pull request has no native graph, decided from the one read" \
  "a pull request has no native graph" "$pout"
assert_eq "and no second request was made to find that out" "1" \
  "$(grep -c graphql "$GH_CALL_LOG")"
assert_eq "with no REST probe at all" "0" \
  "$(grep -c 'pulls/' "$GH_CALL_LOG" || true)"


# --- parent gets the same rule as every other relationship field -----------
# A reply that omits `parent` has not said the work unit has no parent. Reading
# it as "none" would state a fact about a field the reply never mentioned.
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z",
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a reply with no parent field has not said there is no parent"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":"none",
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "and a string is not a parent"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":[],
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "nor is an array"

# The control: an explicitly null parent IS "no parent", and establishes.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GP="$(gfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_contains "an explicitly null parent establishes the fact" "ESTABLISHED" \
  "$(printf '%s' "$GP" | jq -r '.status')"
assert_contains "and says there is no parent" "none" \
  "$(printf '%s' "$GP" | jq -r '.value.parent')"

# --- the root's own state is genuinely outside this class ------------------
# The reference says so; this proves it rather than trusting the sentence. The
# field is not read at all, so a reply that omits it entirely still establishes.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"CLOSED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GR="$(gfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_contains "a reply with no root state still establishes the graph" "ESTABLISHED" \
  "$(printf '%s' "$GR" | jq -r '.status')"
assert_contains "and the relation's state is still canonical" "closed" \
  "$(printf '%s' "$GR" | jq -r '.value.children[0].state')"
[ -z "$(printf '%s' "$GR" | jq -r '[.. | objects | select(has("state")) | .state] | map(select(. != "open" and . != "closed")) | join(",")')" ] \
  && ok || bad "no state outside the vocabulary may appear"

# --- the root repository is observed, not assumed --------------------------
# Checking the issue number alone left the repository half of the identity
# synthesized from the locator that was asked about. A reply from another
# repository would then have had its issue's version and whole relationship set
# bound to this repository's name — the third unchecked identity on this branch,
# after the endpoint resolving from gh's context and the root number.
graph_refused '{"number":733,"repository":{"nameWithOwner":"someone/else"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "another repository's issue must not be bound to this one"
graph_refused '{"number":733,"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a reply that never named its repository has not identified the node"
graph_refused '{"number":733,"repository":null,"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "and neither has a null repository"
graph_refused '{"number":733,"repository":{"nameWithOwner":42},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "nor one whose name is not a name"

# Case is not a mismatch: GitHub compares owner and name case-insensitively, and
# the locator is canonical lower-case, so the observed identity is folded the
# same way before it is compared.
graph_stub '{"number":733,"repository":{"nameWithOwner":"JWOgrady/Spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GC="$(gfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_contains "the same repository in another case is the same repository" "ESTABLISHED" \
  "$(printf '%s' "$GC" | jq -r '.status')"
assert_contains "and the fact names it canonically" "github.com/jwogrady/spark#733" \
  "$(printf '%s' "$GC" | jq -r '.source.identity')"

# --- one work unit is one node, whatever kind it is called -----------------
# Keying identity by "<kind>:<locator>" made the same work unit returned once as
# an Issue and once as a PullRequest look like two nodes: it could appear twice
# in one list, and both contradictory kinds survived. The kind is an attribute
# of a node; the locator is the node.
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
    {"__typename":"PullRequest","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "one work unit cannot be both an issue and a pull request in one list"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"PullRequest","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]}}' \
  "nor across two lists"

# --- the root is inside the identity accounting ----------------------------
# A relation naming the root used to append the root's invalidator again and
# write the same key into `versions` twice: an object with one key twice, which
# is not a conforming fact at all. A work unit is also not its own relation.
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":733,"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a work unit is not its own parent"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":733,"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "nor its own child"

# --- the invariant itself, on a graph that does establish ------------------
# Every invalidator unique, every version key unique, and one version per node.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":728,"state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]}}'
GU="$(gfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_contains "a shared node still establishes" "ESTABLISHED" \
  "$(printf '%s' "$GU" | jq -r '.status')"
[ "$(printf '%s' "$GU" | jq -r '.invalidators | length')" \
  = "$(printf '%s' "$GU" | jq -r '.invalidators | unique | length')" ] && ok \
  || bad "every invalidator appears once"
[ "$(printf '%s' "$GU" | jq -r '.invalidators | length')" \
  = "$(printf '%s' "$GU" | jq -r '.versions | length')" ] && ok \
  || bad "and each has exactly one observed version"
[ "$(printf '%s' "$GU" | jq -r '.invalidators | length')" = "3" ] && ok \
  || bad "the root, its parent and the shared node are three nodes, not four"

# --- a root that is not an object -----------------------------------------
# Reaching into a scalar or an array raises a jq error, so the failure arrived as
# a generic read failure rather than the malformed refusal this path documents.
# The outcome looked right and the mechanism was wrong, which is the shape of
# the sentinel bug earlier on this branch — so these assert the REASON, not just
# that something refused.
malformed_root '{"data":{"repository":{"issueOrPullRequest":[]}}}'      "an array is not a work unit"
malformed_root '{"data":{"repository":{"issueOrPullRequest":"733"}}}'   "nor is a string"
malformed_root '{"data":{"repository":{"issueOrPullRequest":733}}}'     "nor a number"
malformed_root '{"data":{"repository":{"issueOrPullRequest":true}}}'    "nor a boolean"

# The control: an object still reaches the field checks and can establish.
raw_graph_stub '{"data":{"repository":{"issueOrPullRequest":{"__typename":"Issue","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},"blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}}}}'
GO="$(gfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_contains "an object root still establishes" "ESTABLISHED" \
  "$(printf '%s' "$GO" | jq -r '.status')"

# --- truncation does not excuse a malformed node ---------------------------
# A node the reply DID return is a node it claimed. Skipping the walk when a
# list was truncated also skipped validating those claims, so a truncated child
# list beside a bad parent still emitted UNKNOWN. Validation and representation
# are different concerns: everything returned is checked, only a complete
# reading is represented.
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":728,"state":"MERGED","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":true},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a truncated list does not excuse a parent state outside the vocabulary"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Discussion","number":728,"state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":true},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "nor a kind with no invalidator form"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"not-an-instant","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "nor a returned node whose version is not a version"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"Issue","number":733,"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "nor the work unit naming itself on a truncated page"

# The control: a truncated reading whose returned nodes are all sound is still
# the UNKNOWN, and still represents none of them.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":728,"state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"Issue","number":740,"state":"CLOSED","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GV="$(gfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_contains "sound nodes on a truncated page still yield the unknown" "UNKNOWN" \
  "$(printf '%s' "$GV" | jq -r '.status')"
[ "$(printf '%s' "$GV" | jq -r '.invalidators | length')" = "1" ] && ok \
  || bad "and it still represents none of them"
[ "$(printf '%s' "$GV" | jq -r 'has("value")')" = "false" ] && ok \
  || bad "and carries no value"
assert_versions_canonical "$GV" "the validated truncated graph"

# --- a relation's shape is the root's standard -----------------------------
# Related numbers were coerced with tostring before anything looked at them, so
# "740" was indistinguishable from 740. The root and the pull-request probe
# already required real integers; a rule applied to two of three identity
# sources is a rule with a hole in it.
rel_refused() { # rel_refused <child node json> <label>
  graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
    "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":['"$1"']},
    "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' "$2"
}
rel_refused '{"__typename":"Issue","number":"740","state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}' \
  "a relation number that is a string is not an issue number"
rel_refused '{"__typename":"Issue","number":740.5,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}' \
  "nor is a fraction"
rel_refused '{"__typename":"Issue","number":null,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}' \
  "nor a null"
rel_refused '{"__typename":"Issue","state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}' \
  "nor a relation with no number at all"
rel_refused '740' "and a bare scalar is not a relation"
rel_refused '{"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z"}' \
  "a relation that names no repository has not identified itself"

# The parent is held to it too, not only the lists.
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":"728","state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a parent number that is a string is refused like any other"

# The control: real integers still establish, and the identity is canonical.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":740,"state":"OPEN","updatedAt":"2026-09-07T08:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}}]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GI="$(gfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_contains "an integer relation number still establishes" "ESTABLISHED" \
  "$(printf '%s' "$GI" | jq -r '.status')"
assert_contains "and is named canonically" "github.com/jwogrady/spark#740" \
  "$(printf '%s' "$GI" | jq -r '.value.children[0].id')"

# --- nothing is indexed before it is known to be indexable -----------------
# jq raises on reaching into a scalar, and that error used to arrive as a
# source-read failure rather than the malformed refusal this path documents.
# These are the containers the old checks reached through without a guard, and
# each asserts the REASON, because a refusal by accident and one by design are
# indistinguishable otherwise.
graph_refused '{"number":733,"repository":"jwogrady/spark","updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a scalar where the root repository object belongs"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":"none",
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a scalar where a relationship list belongs"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":"complete","nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a scalar where pageInfo belongs"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":42}' \
  "and a number where the blocker list belongs"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":["2026-09-08T10:00:00Z"],"parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "an array where the root version belongs is not a version"
graph_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":728,"state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":"jwogrady/spark"},
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "and a relation whose repository is a scalar is held to the same guard"

# The control: the same reply with every container an object still establishes,
# so the guards discriminate rather than refusing whatever they are shown.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z",
  "parent":{"__typename":"Issue","number":728,"state":"OPEN","updatedAt":"2026-09-08T09:00:00Z","repository":{"nameWithOwner":"jwogrady/spark"}},
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
GG="$(gfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_contains "well-formed containers still establish" "ESTABLISHED" \
  "$(printf '%s' "$GG" | jq -r '.status')"
assert_contains "with the parent named canonically" "github.com/jwogrady/spark#728" \
  "$(printf '%s' "$GG" | jq -r '.value.parent.id')"

# --- the response root is guarded before it is indexed ---------------------
# `has("errors")` on a scalar raises in jq, so a body that is not an object
# arrived as a source-read failure rather than the malformed refusal.
malformed_root '42'    "a numeric response body is not a reply"
malformed_root 'null'  "nor is a null body"
malformed_root '[]'    "nor an array body"
malformed_root '"ok"'  "nor a bare string"

# --- one observation, two classes ------------------------------------------
# work_unit and graph are two facts about the SAME node. Reading it twice would
# let them describe it in two different states, which is the defect this
# compiler exists to prevent, reintroduced one level up. So the node is read
# once and both classes consume it — and the cache counters say so, which they
# could not before, when nothing ever asked twice.
: > "$GH_CALL_LOG"
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
sout="$("$SPARK" facts --issue 733 2>/dev/null)"
assert_eq "the work unit and its graph come from ONE graphql request" "1" \
  "$(grep -c graphql "$GH_CALL_LOG")"
assert_contains "and both classes are established from it" "work_unit.identity" "$sout"
assert_contains "the graph among them" "graph.native" "$sout"


# =========================================================================
# The work unit fact (#733 packet 3)
# =========================================================================
#
# `work_unit.identity` answers WHICH task is being executed, and the field that
# earns the class is `implements`: the issue a pull request closes. Everything
# downstream binds an issue's acceptance, placement and graph to a pull
# request's work unit through that one declared relationship, so the three
# things a happy-path check would miss are:
#
#   * the relationship is GitHub's closing reference, never prose. A pull
#     request that mentions an issue does not implement it;
#   * `implements` names ONE issue, so two closing references are a conflict
#     with both named — not a first-write or a plausibility pick;
#   * a bounded reference list is an unknown, not a shorter answer.

# wfact — the work unit fact out of a --issue run.
wfact() { printf '%s' "$1" | jq -r '.[] | select(.key=="work_unit.identity")'; }

# unit_stub <node json> — one work-unit node, whatever its kind.
unit_stub() { graph_stub "$1"; }

ISSUE_NODE='{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'

# --- an issue implements nothing -------------------------------------------
unit_stub "$ISSUE_NODE"
W="$(wfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_eq "an issue is established" "ESTABLISHED" "$(printf '%s' "$W" | jq -r '.status')"
assert_eq "and its kind is the model's, not GraphQL's" "issue" "$(printf '%s' "$W" | jq -r '.value.kind')"
assert_eq "and it is named canonically" "github.com/jwogrady/spark#733" "$(printf '%s' "$W" | jq -r '.value.id')"
# An issue implements nothing, and `none` is the model's literal — written as a
# JSON string, because a bare token would not parse at all.
assert_eq "and an issue implements nothing" "none" "$(printf '%s' "$W" | jq -r '.value.implements')"
assert_eq "the source is the node the value describes" "github.com/jwogrady/spark#733" \
  "$(printf '%s' "$W" | jq -r '.source.identity')"
# R17: one canonical form per kind, never both.
assert_eq "an issue is invalidated as an issue, once" '["issue:github.com/jwogrady/spark#733"]' \
  "$(printf '%s' "$W" | jq -c '.invalidators')"
assert_eq "and the version recorded is the node's updated_at" "2026-09-08T10:00:00Z" \
  "$(printf '%s' "$W" | jq -r '.versions["issue:github.com/jwogrady/spark#733"]')"
assert_versions_canonical "$W" "the work unit fact"
for field in $(required_fields); do
  [ "$(printf '%s' "$W" | jq -r --arg f "$field" 'has($f)')" = "true" ] && ok \
    || bad "the work unit envelope is missing the required field $field"
done

# --- a pull request implements the issue it closes -------------------------
PR_ONE='{"__typename":"PullRequest","number":774,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-09T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":733,"repository":{"nameWithOwner":"jwogrady/spark"}}]}}'
unit_stub "$PR_ONE"
W="$(wfact "$("$SPARK" facts --issue 774 2>/dev/null)")"
assert_eq "a pull request is established" "ESTABLISHED" "$(printf '%s' "$W" | jq -r '.status')"
assert_eq "and its kind is a pull request" "pull_request" "$(printf '%s' "$W" | jq -r '.value.kind')"
assert_eq "and it implements the issue it closes" "github.com/jwogrady/spark#733" \
  "$(printf '%s' "$W" | jq -r '.value.implements')"
assert_eq "a pull request is invalidated as a pull request" '["pull_request:github.com/jwogrady/spark#774"]' \
  "$(printf '%s' "$W" | jq -c '.invalidators')"
# The issue it implements is NOT an invalidator: `implements` is a relationship
# this node declares, and the declaration changes when THIS node changes.
assert_eq "and the issue it implements is not an invalidator of it" "1" \
  "$(printf '%s' "$W" | jq -r '.invalidators | length')"
assert_versions_canonical "$W" "the pull request fact"

# A pull request that closes nothing implements nothing — a real answer, not a
# missing one.
unit_stub '{"__typename":"PullRequest","number":774,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-09T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
W="$(wfact "$("$SPARK" facts --issue 774 2>/dev/null)")"
assert_eq "a pull request closing nothing is still established" "ESTABLISHED" \
  "$(printf '%s' "$W" | jq -r '.status')"
assert_eq "and implements nothing" "none" "$(printf '%s' "$W" | jq -r '.value.implements')"

# --- a closing reference in another repository is named canonically --------
# Cross-repository identity: the reference carries its own repository, and the
# work unit it names must be spelled with THAT repository, not the one asked.
unit_stub '{"__typename":"PullRequest","number":774,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-09T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":12,"repository":{"nameWithOwner":"OTHER/Repo"}}]}}'
W="$(wfact "$("$SPARK" facts --issue 774 2>/dev/null)")"
assert_eq "a closing reference elsewhere is named with its own repository" \
  "github.com/other/repo#12" "$(printf '%s' "$W" | jq -r '.value.implements')"

# --- two closing references are a conflict --------------------------------
# The model gives `implements` one work unit. Two authoritative references
# disagree about which issue this unit implements, and no rule picks one (R8).
unit_stub '{"__typename":"PullRequest","number":774,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-09T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"Issue","number":733,"repository":{"nameWithOwner":"jwogrady/spark"}},
    {"__typename":"Issue","number":728,"repository":{"nameWithOwner":"jwogrady/spark"}}]}}'
W="$(wfact "$("$SPARK" facts --issue 774 2>/dev/null)")"
assert_eq "two closing issues are a conflict" "CONFLICT" "$(printf '%s' "$W" | jq -r '.status')"
assert_eq "and both are named as candidates" \
  "github.com/jwogrady/spark#728,github.com/jwogrady/spark#733" \
  "$(printf '%s' "$W" | jq -r '[.detail.candidates[]] | sort | join(",")')"
assert_eq "and a conflict carries no value" "false" "$(printf '%s' "$W" | jq -r 'has("value")')"
assert_versions_canonical "$W" "the conflicted work unit fact"

# --- a bounded reference list is an unknown, not a shorter answer ----------
unit_stub '{"__typename":"PullRequest","number":774,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-09T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"Issue","number":733,"repository":{"nameWithOwner":"jwogrady/spark"}}]}}'
W="$(wfact "$("$SPARK" facts --issue 774 2>/dev/null)")"
assert_eq "a truncated reference list is unknown" "UNKNOWN" "$(printf '%s' "$W" | jq -r '.status')"
assert_eq "and carries no value" "false" "$(printf '%s' "$W" | jq -r 'has("value")')"
assert_eq "and says why" "bounded" "$(printf '%s' "$W" | jq -r '.detail.reason')"
# The envelope still conforms: the node's own version WAS observed, which is
# what separates an unknown value from no fact at all (R6).
assert_versions_canonical "$W" "the bounded work unit fact"

# --- what is refused rather than emitted ----------------------------------
unit_refused() { # unit_refused <node json> <label>
  unit_stub "$1"
  local out; out="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
  case "$out" in
    *"work_unit: "*) ok ;;
    *) bad "$2 — the work unit fact was not refused" ;;
  esac
}
# A closing reference is an issue. A pull request cannot close a pull request,
# so anything else is a reply this class cannot read.
unit_refused '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[
    {"__typename":"PullRequest","number":700,"repository":{"nameWithOwner":"jwogrady/spark"}}]}}' \
  "a pull request cannot be a closing reference"
# A kind outside the model's vocabulary cannot have its invalidator spelled, so
# it is not a fact with a reason — it is no fact.
DISCUSSION='{"__typename":"Discussion","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z"}'
unit_refused "$DISCUSSION" "a kind outside the vocabulary is refused"
# And NEITHER class may be emitted for it. A self row with no relationship rows
# is indistinguishable from an issue that has no relationships, so a permissive
# projection let the graph class establish an EMPTY graph for a node that has
# none because it is not a work unit at all.
unit_stub "$DISCUSSION"
DOUT="$("$SPARK" facts --issue 733 2>/dev/null)"
assert_eq "an unrecognised kind establishes no graph either" "false" \
  "$(printf '%s' "$DOUT" | jq -r 'any(.[]; .key == "graph.native")')"
assert_eq "and no work unit" "false" \
  "$(printf '%s' "$DOUT" | jq -r 'any(.[]; .key == "work_unit.identity")')"
assert_eq "so only the repository class survives" "1" \
  "$(printf '%s' "$DOUT" | jq -r 'length')"

# --- a repository that could not be resolved is not an absent work unit -----
# GitHub phrases a REPOSITORY failure the same way as a node failure — "Could
# not resolve to a Repository with the name ..." — so a prefix match turned an
# inaccessible or nonexistent repository into "no work unit by that number": a
# confident claim about a node in a repository that was never read.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) echo "gh: Could not resolve to a Repository with the name 'jwogrady/spark'." >&2; exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
rout="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
case "$rout" in
  *"no work unit by that number"*)
    bad "an unresolvable repository was reported as an absent work unit" ;;
  *) ok ;;
esac
# It keeps the unclassified reason rather than gaining a confident one: GitHub
# says "Could not resolve to a Repository" both for one that does not exist and
# for one this token cannot see, so `unreadable` is the whole of what was
# learned. Fail-closed, and it does not send a caller to create a repository
# that may already be there.
assert_contains "an unresolvable repository keeps its own reason" "unreadable" "$rout"

# A node-scoped failure for ANOTHER number is not an answer about this one.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) echo 'gh: Could not resolve to an Issue with the number of 999.' >&2; exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
oout="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
case "$oout" in
  *"no work unit by that number"*)
    bad "a failure naming another number was read as this work unit's absence" ;;
  *) ok ;;
esac

# A node-scoped failure naming a LONGER number is not an answer about a
# SHORTER one either: "73" is a prefix of "733", and a prefix match on the
# number would let an error about 733 stand in for the absence of 73 — a
# confident claim about a different work unit than the one asked for.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) echo 'gh: Could not resolve to an Issue with the number of 733.' >&2; exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
pout="$("$SPARK" facts --issue 73 2>&1 >/dev/null)"
case "$pout" in
  *"no work unit by that number"*)
    bad "an error naming 733 was read as the absence of the requested 73" ;;
  *) ok ;;
esac
# It keeps the unclassified reason rather than gaining a confident one, the
# same as any other node-scoped failure naming a number it was not asked
# about.
assert_contains "a prefix-only number match keeps its own reason" "unreadable" "$pout"

# A reply that names THIS number alongside another node still establishes this
# one's absence: GitHub said this node could not be resolved, and what it also
# said about a different node does not weaken that. Pinned because the
# alternative — refusing whenever more than one node is named — is a defensible
# reading that would report `unreadable` for a node GitHub explicitly could not
# resolve, and the choice between them should be deliberate rather than
# whatever the matching happens to do.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*)
    echo 'gh: Could not resolve to an Issue with the number of 733.' >&2
    echo 'gh: Could not resolve to an Issue with the number of 999.' >&2
    exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
mout="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
assert_contains "a reply naming this node and another still establishes this absence" \
  "no work unit by that number" "$mout"

# ...and in EITHER ORDER, with the other number a prefix of ours or ours a
# prefix of it. Reading only the first occurrence of the phrase made the answer
# depend on which error GitHub happened to list first: errors for 733 then 73,
# with 73 requested, rejected an absence the reply did state.
order_case() { # order_case <first number> <second number> <requested> <label>
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*)
    echo 'gh: Could not resolve to an Issue with the number of $1.' >&2
    echo 'gh: Could not resolve to an Issue with the number of $2.' >&2
    exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
  local out; out="$("$SPARK" facts --issue "$3" 2>&1 >/dev/null)"
  assert_contains "$4" "no work unit by that number" "$out"
}
order_case 733 73  73  "an error naming 733 first does not hide the requested 73"
order_case 73  733 73  "and naming 73 first still establishes it"
order_case 999 733 733 "an unrelated number first does not hide the requested 733"
order_case 733 7   733 "nor does a shorter number after it"

# The discrimination that keeps all of that honest: a reply naming ONLY numbers
# this work unit is a prefix of, or unrelated to, is still not its absence.
order_refuses() { # order_refuses <first> <second> <requested> <label>
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*)
    echo 'gh: Could not resolve to an Issue with the number of $1.' >&2
    echo 'gh: Could not resolve to an Issue with the number of $2.' >&2
    exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
  local out; out="$("$SPARK" facts --issue "$3" 2>&1 >/dev/null)"
  case "$out" in
    *"no work unit by that number"*) bad "$4" ;;
    *) ok ;;
  esac
}
order_refuses 733 7331 73  "an error naming 733 and 7331 was read as the absence of 73"
order_refuses 999 1000 733 "unrelated numbers were read as the absence of 733"

# No observed version, no envelope.
unit_refused '{"__typename":"Issue","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"not-a-timestamp","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a noncanonical version is refused"
# The node returned must be the node asked for, in both halves of its identity.
unit_refused '{"__typename":"Issue","number":999,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "another number is not this work unit"
unit_refused '{"__typename":"Issue","number":733,"repository":{"nameWithOwner":"someone/else"},
  "updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "and another repository's issue is not this work unit"

# Case is folded, as everywhere else: the same repository spelled differently is
# the same repository, so the identity check discriminates rather than refusing
# spellings.
unit_stub '{"__typename":"Issue","number":733,"repository":{"nameWithOwner":"JWOgrady/Spark"},
  "updatedAt":"2026-09-08T10:00:00Z","parent":null,
  "subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
W="$(wfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
assert_eq "the same repository in another case is the same work unit" "ESTABLISHED" \
  "$(printf '%s' "$W" | jq -r '.status')"
assert_eq "and it is named in the canonical case" "github.com/jwogrady/spark#733" \
  "$(printf '%s' "$W" | jq -r '.value.id')"

finish
