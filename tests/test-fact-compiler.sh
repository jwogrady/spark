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
  #
  # The milestone key is defaulted the same way and for the same reason: the
  # query always asks for it, so a real reply always carries it, and a fixture
  # that omits it models a reply GitHub does not send. A fixture proving what
  # happens when the key is genuinely ABSENT must bypass this helper —
  # `raw_graph_stub` exists for exactly that.
  #
  # A pull request also carries its HEAD, and the same reasoning applies: the
  # query always asks, so a real reply always answers. The default makes the
  # base branch target equal the base the pull request sits on, which is the
  # CURRENT case; a fixture proving staleness sets baseRef itself.
  local node
  node="$(printf '%s' "$1" | jq -c 'if type == "object"
                                    then . + {__typename: (.__typename // "Issue")}
                                         + (if has("milestone") then {} else {milestone: null} end)
                                         + (if (.__typename // "Issue") != "PullRequest" then {}
                                            else {headRefOid: (.headRefOid // "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678"),
                                                  baseRefName: (.baseRefName // "master"),
                                                  baseRefOid: (.baseRefOid // "b1c2d3e4f5061728394a5b6c7d8e9f0123456789")}
                                                 + (if has("baseRef") then {}
                                                    else {baseRef: {target: {oid: (.baseRefOid // "b1c2d3e4f5061728394a5b6c7d8e9f0123456789")}}} end)
                                            end)
                                    else . end
                                  | if (type == "object") and (.__typename == "PullRequest")
                                       and (has("commits") | not)
                                    then . + {commits: {nodes: [{commit: {oid: .headRefOid,
                                                                 statusCheckRollup: null}}]}}
                                    else . end
                                  | if (type == "object") and (.__typename == "PullRequest")
                                       and (((.commits.nodes // []) | length) > 0)
                                    then .commits.nodes |= map(
                                           if (.commit.statusCheckRollup // null) == null then .
                                           else .commit.statusCheckRollup.contexts.nodes |= map(
                                                  if (.__typename == "CheckRun")
                                                  then (if has("conclusion") then . else . + {conclusion: null} end)
                                                       | (if has("checkSuite") then . else . + {checkSuite: null} end)
                                                  else . end)
                                           end)
                                    else . end
                                  | if (type == "object") and (.__typename == "PullRequest")
                                       and (has("comments") | not)
                                    then . + {comments: {pageInfo: {hasPreviousPage: false}, nodes: []}}
                                    else . end')"
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) answer_json '{"data":{"repository":{"issueOrPullRequest":$node}}}' ;;
  *"repos/jwogrady/spark/rules/branches/"*) answer_json '$RULES' ;;
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB
}

# gfact — the graph fact out of a --issue run.
gfact() { printf '%s' "$1" | jq -r '.[] | select(.key=="graph.native")'; }

# The branch rules answer: what the base branch REQUIRES, which is not what
# runs. Two required here, as this repository actually has, so a fixture can
# show a check that runs and is not required.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor"},{"context":"tests"}]}}]'

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

# --- the fragment carries all seven classes, and is still a fragment -------
[ "$(printf '%s' "$GOUT" | jq -r 'type')" = "array" ] && ok || bad "a fragment is a bare list"
[ "$(printf '%s' "$GOUT" | jq -r 'length')" = "7" ] && ok \
  || bad "a --issue run compiles repository, work unit, graph, placement, head, review and checks"
[ "$(printf '%s' "$GOUT" | jq -r '[.[].key] | sort | join(",")')" = "checks.required,graph.native,head.exact,placement.current,repository.identity,review.independent,work_unit.identity" ] \
  && ok || bad "and those seven classes exactly"

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

# --- the compiler's cost, with seven classes ----------------------------
: > "$GH_CALL_LOG"
graph_stub "$FULL"
SPARK_RUN_ID=rgraph "$SPARK" facts --issue 733 >/dev/null
TELG="$("$SPARK" telemetry show --run rgraph --json)"
assert_contains "seven classes compiled means seven facts" '"facts_emitted":7' "$TELG"
# Still TWO reads for seven facts: the repository node, and one work-unit node
# that work_unit, graph, placement, head, review and checks all share. Another
# read here would mean two classes had described the same node from two
# separate observations -- the defect this compiler exists to prevent.
#
# This fixture is an ISSUE, so head, review and checks are all NOT_APPLICABLE
# and checks answers before it needs the repository or the branch rules. The
# pull-request path costs more, and is measured where it is exercised.
assert_contains "from two source reads, not three" '"facts_api_calls":2' "$TELG"
assert_contains "and the shared observation is reused five times" '"facts_cache_hits":5' "$TELG"
assert_contains "and the placement is the one unknown" '"facts_unknown":1' "$TELG"

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
# A GraphQL resolve failure therefore means neither exists, and it is decided
# from the error's PATH rather than its message — the detailed cases are with
# the work unit class below, where the classification lives.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*)
    echo 'gh: the reply carried errors' >&2
    printf '%s' '{"data":{"repository":{"issueOrPullRequest":null}},"errors":[{"type":"NOT_FOUND","path":["repository","issueOrPullRequest"],"message":"gone"}]}'
    exit 1 ;;
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
# Only a typed NOT_FOUND at the node's path is absence; every other failure
# keeps its own reason instead of asserting that the work unit does not exist.
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
raw_graph_stub '{"data":{"repository":{"issueOrPullRequest":{"__typename":"Issue","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","milestone":null,"parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},"blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}}}}'
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

# ...but truncation is not a way to avoid being checked. Every reference the
# reply DID return is validated first, so a truncated list carrying a malformed
# reference is REFUSED rather than emitted as a bounded UNKNOWN from an
# observation the schema does not admit.
unit_stub '{"__typename":"PullRequest","number":774,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-09T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"PullRequest","number":700,"repository":{"nameWithOwner":"jwogrady/spark"}}]}}'
TOUT="$("$SPARK" facts --issue 774 2>&1 >/dev/null)"
case "$TOUT" in
  *"work_unit: "*) ok ;;
  *) bad "a truncated list with a non-Issue reference was not refused" ;;
esac
TJSON="$(wfact "$("$SPARK" facts --issue 774 2>/dev/null)")"
assert_eq "and no bounded UNKNOWN was emitted from it" "" "$TJSON"

# The same for a reference that cannot be named canonically: truncation does not
# excuse it either.
unit_stub '{"__typename":"PullRequest","number":774,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-09T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"Issue","number":733,"repository":{"nameWithOwner":"not a name"}}]}}'
NOUT="$("$SPARK" facts --issue 774 2>&1 >/dev/null)"
case "$NOUT" in
  *"work_unit: "*) ok ;;
  *) bad "a truncated list with an unnameable reference was not refused" ;;
esac

# The control: a truncated list whose returned references are all sound is
# still the bounded UNKNOWN — the repair discriminates rather than refusing
# every truncation.
unit_stub '{"__typename":"PullRequest","number":774,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-09T10:00:00Z",
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":true},"nodes":[
    {"__typename":"Issue","number":733,"repository":{"nameWithOwner":"jwogrady/spark"}}]}}'
W="$(wfact "$("$SPARK" facts --issue 774 2>/dev/null)")"
assert_eq "a truncated list of sound references is still the bounded unknown" "UNKNOWN" \
  "$(printf '%s' "$W" | jq -r '.status')"

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

# --- absence is decided by the error PATH, not by its message ---------------
# When the node does not exist GitHub answers with a typed error, and `gh`
# ignores `--jq` for a reply carrying errors and writes the RAW body to stdout.
# The query asks for exactly ONE node, at `repository.issueOrPullRequest`, so a
# NOT_FOUND at that path is GitHub saying the node this request asked for does
# not exist. Nothing is read out of the sentence — which is what four rounds of
# matching on it kept getting wrong: a glob had no digit boundary, stripping to
# the first occurrence was order-dependent, requiring an exact set of numbers
# rejected a reply that also named another node, and every number-based rule
# accepted the wrong ENTITY.

# resolve_stub <errors json array> [target node json] — the shape gh actually
# produces: raw body on stdout, a message on stderr, non-zero exit. The target
# node defaults to null, which is what a genuine absence looks like; a caller
# proving the contradictory-evidence case passes a non-null node instead.
resolve_stub() {
  local target="${2:-null}"
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*)
    echo 'gh: the reply carried errors' >&2
    printf '%s' '{"data":{"repository":{"issueOrPullRequest":$target}},"errors":$1}'
    exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
}

establishes_absence() { # establishes_absence <errors json> <requested> <label>
  resolve_stub "$1"
  local out; out="$("$SPARK" facts --issue "$2" 2>&1 >/dev/null)"
  assert_contains "$3" "no work unit by that number" "$out"
}
refuses_absence() { # refuses_absence <errors json> <requested> <label>
  resolve_stub "$1"
  local out; out="$("$SPARK" facts --issue "$2" 2>&1 >/dev/null)"
  case "$out" in
    *"no work unit by that number"*) bad "$3" ;;
    *) ok ;;
  esac
}

establishes_absence '[{"type":"NOT_FOUND","path":["repository","issueOrPullRequest"],"message":"Could not resolve to an issue or pull request with the number of 733."}]' \
  733 "NOT_FOUND at the work unit's own path is absence"
# The path is the fact, so neither the number in the sentence nor the position
# of the error in the array can change the answer.
establishes_absence '[{"type":"NOT_FOUND","path":["repository","issueOrPullRequest"],"message":"Could not resolve to an issue or pull request with the number of 999999."}]' \
  73 "the message's number is irrelevant when the path is the fact"
establishes_absence '[{"type":"NOT_FOUND","path":["repository","milestone"],"message":"m"},{"type":"NOT_FOUND","path":["repository","issueOrPullRequest"],"message":"i"}]' \
  733 "and a NOT_FOUND at our path is absence even when listed second"
establishes_absence '[ { "type" : "NOT_FOUND" , "path" : [ "repository" , "issueOrPullRequest" ] , "message" : "spaced" } ]' \
  733 "JSON whitespace is not part of the comparison"

# A DIFFERENT ENTITY whose message names the requested number. Every
# number-based rule accepted this: the digits are in the sentence, but a
# milestone is not a work unit.
refuses_absence '[{"type":"NOT_FOUND","path":["repository","milestone"],"message":"Could not resolve to a Milestone with the number of 733."}]' \
  733 "a milestone resolution failure was read as a work unit's absence"
# The repository itself, which an earlier prefix match also accepted.
refuses_absence '[{"type":"NOT_FOUND","path":["repository"],"message":"Could not resolve to a Repository."}]' \
  733 "a repository resolution failure was read as a work unit's absence"
# Our path, but not a NOT_FOUND: being forbidden to see a node says nothing
# about whether it exists.
refuses_absence '[{"type":"FORBIDDEN","path":["repository","issueOrPullRequest"],"message":"Resource not accessible."}]' \
  733 "a forbidden node was reported as absent"
# Tokens that would pair ACROSS error objects: the NOT_FOUND belongs to another
# path, and our path carries a different type. Matching both tokens anywhere in
# the body would call this absence.
refuses_absence '[{"type":"NOT_FOUND","path":["repository","milestone"],"message":"m"},{"type":"FORBIDDEN","path":["repository","issueOrPullRequest"],"message":"f"}]' \
  733 "tokens from two different errors were paired into an absence"

# A single VALID error carrying both tokens in the wrong places: the error is
# about a milestone, and the node's path appears only nested under
# `extensions`. Text matching cannot tell a top-level `path` from a nested one,
# and splitting on object boundaries splits nested objects too — so this read
# as the work unit's absence until the body was actually parsed.
refuses_absence '[{"type":"NOT_FOUND","path":["repository","milestone"],"extensions":{"path":["repository","issueOrPullRequest"]}}]' \
  733 "a nested extensions.path was read as the error's own path"
# The same shape the other way round: our path is top-level but the NOT_FOUND
# belongs to a nested object rather than to this error.
refuses_absence '[{"type":"FORBIDDEN","path":["repository","issueOrPullRequest"],"extensions":{"type":"NOT_FOUND"}}]' \
  733 "a nested type was read as the error's own type"
# A path that merely STARTS at the node is not the node: a deeper field failing
# to resolve is a different fact from the node not existing.
refuses_absence '[{"type":"NOT_FOUND","path":["repository","issueOrPullRequest","closingIssuesReferences"]}]' \
  733 "a deeper path was read as the node's own absence"
# And a body that is not an errors array at all establishes nothing.
refuses_absence '{"type":"NOT_FOUND","path":["repository","issueOrPullRequest"]}' \
  733 "an errors field that is not an array was read as absence"

# A NON-NULL target node returned ALONGSIDE the target's own NOT_FOUND. The two
# halves of the same reply disagree about whether the node exists — data says
# here it is, errors says it could not be resolved — which is contradictory,
# malformed evidence, not a reading of the world. Reporting this as absence
# would send a caller to create a work unit the same reply just described.
resolve_stub \
  '[{"type":"NOT_FOUND","path":["repository","issueOrPullRequest"],"message":"Could not resolve to an issue or pull request with the number of 733."}]' \
  '{"__typename":"Issue","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","milestone":null,"parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},"blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
cout="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
case "$cout" in
  *"no work unit by that number"*)
    bad "a non-null target node alongside its own NOT_FOUND was read as absence" ;;
  *) ok ;;
esac
assert_contains "the contradiction keeps its own reason instead" "unreadable" "$cout"

# A reply carrying the message but NO structured body establishes nothing.
# Absence is a claim about the world, so with nothing structured to read it
# fails closed and keeps its own reason.
stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) echo 'gh: Could not resolve to an Issue with the number of 733.' >&2; exit 1 ;;
  *) answer_json '$NODE' ;;
esac
STUB
bout="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
case "$bout" in
  *"no work unit by that number"*)
    bad "a bare message with no structured error was read as absence" ;;
  *) ok ;;
esac
assert_contains "an unstructured failure keeps its own reason" "unreadable" "$bout"


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

# --- placement.current: the ruling, made mechanical -------------------------
# `placement.release` is ESTABLISHED only from an explicit authoritative
# declaration mapping the work unit to an exact SemVer vX.Y.Z (#733, decision
# 5608275480). Nothing in this repository declares that, so the fact is UNKNOWN
# — and the point of these assertions is that UNKNOWN is not `release: none`.
# The difference is a reserved human boundary: fact-model.tsv:241 fires
# `placement:release` when release is not-none, so answering `none` from an
# absence of evidence would suppress the boundary by asserting what nobody saw.

pfact() { printf '%s' "$1" | jq -r '.[] | select(.key=="placement.current")'; }

MS='{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z",
  "milestone":{"number":20,"updatedAt":"2026-09-05T12:00:00Z"},
  "parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},
  "blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'

graph_stub "$MS"
POUT="$("$SPARK" facts --issue 733)"
P="$(pfact "$POUT")"

[ -n "$P" ] && ok || bad "a --issue run compiles placement.current"
assert_contains "the placement fact carries its class's one key" "placement.current" \
  "$(printf '%s' "$P" | jq -r '.key')"
assert_contains "placement is UNKNOWN without an authoritative release declaration" "UNKNOWN" \
  "$(printf '%s' "$P" | jq -r '.status')"
for field in $(required_fields); do
  if [ "$(printf '%s' "$P" | jq -r "has(\"$field\")")" = "true" ]; then ok
  else bad "the placement envelope is missing the required field '$field'"; fi
done

# THE ruling, as a control: an UNKNOWN carries no value at all, so it can never
# be read as `release: none`. A future change that answers `none` from silence
# fails here.
[ "$(printf '%s' "$P" | jq -r 'has("value")')" = "false" ] && ok \
  || bad "an unknown placement carries a value, which could be read as release:none"
[ "$(printf '%s' "$P" | jq -r '.value.release // "absent"')" = "absent" ] && ok \
  || bad "the placement fact names a release it never observed"
assert_contains "and says why it is unknown" "no authoritative declaration" \
  "$(printf '%s' "$P" | jq -r '.detail.reason')"

# The milestone is an invalidator, never the answer: it makes the fact go stale
# when the work unit moves, and it is spelled in the model's own grammar.
assert_contains "the observed milestone is an invalidator" "milestone:github.com/jwogrady/spark/milestone/20" \
  "$(printf '%s' "$P" | jq -r '.invalidators | join(",")')"
printf '%s' "$(printf '%s' "$P" | jq -r '.invalidators[] | select(startswith("milestone:"))')" \
  | grep -Eq "$(model_regex invalidator milestone)" && ok \
  || bad "the milestone invalidator is not in the model's grammar"
assert_eq "and is versioned by the milestone's own updatedAt" "2026-09-05T12:00:00Z" \
  "$(printf '%s' "$P" | jq -r '.versions["milestone:github.com/jwogrady/spark/milestone/20"]')"
assert_contains "the source is still the work unit the placement was read from" "github.com/jwogrady/spark#733" \
  "$(printf '%s' "$P" | jq -r '.source.identity')"
assert_versions_canonical "$P" "placement"

# No milestone is a real answer from GitHub, and it means one fewer invalidator
# — not a missing one. The fact is still UNKNOWN, for the release reason.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},"blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
PNONE="$(pfact "$("$SPARK" facts --issue 733)")"
assert_contains "a work unit in no milestone still compiles a placement" "UNKNOWN" \
  "$(printf '%s' "$PNONE" | jq -r '.status')"
[ "$(printf '%s' "$PNONE" | jq -r '[.invalidators[] | select(startswith("milestone:"))] | length')" = "0" ] \
  && ok || bad "a work unit with no milestone carries a milestone invalidator"

# One observation, four classes: placement must not add a read.
: > "$GH_CALL_LOG"
graph_stub "$MS"
"$SPARK" facts --issue 733 >/dev/null 2>&1
assert_eq "placement reuses the shared observation rather than reading again" "1" \
  "$(grep -c 'graphql' "$GH_CALL_LOG")"

# --- placement fails closed on a milestone it cannot spell ------------------
# An invalidator outside its grammar is a freshness contract that cannot be
# written, so the fact is refused rather than emitted without it.
placement_refused() { # placement_refused <issue json> <label>
  graph_stub "$1"
  local out; out="$("$SPARK" facts --issue 733 2>&1 >/dev/null)"
  local got; got="$(pfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
  [ -z "$got" ] && ok || bad "$2"
}
placement_refused '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z",
  "milestone":{"number":20,"updatedAt":"not-an-instant"},
  "parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},"blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a milestone whose version is not an instant still produced a placement"

# A reply that OMITS the milestone key has not said the work unit has no
# milestone. This bypasses graph_stub deliberately: the helper defaults the key
# precisely because a real reply always carries it, and this fixture is the one
# proving what happens when it does not.
raw_graph_stub '{"data":{"repository":{"issueOrPullRequest":{"__typename":"Issue","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"updatedAt":"2026-09-08T10:00:00Z","parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},"blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}}}}'
[ -z "$(pfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a reply that never answered the milestone question compiled a placement"

# --- head.exact: the base is the BRANCH TARGET, and that is the whole class ---
# R20 makes value.base the version of this fact's own `ref:` invalidator, so
# base must be the commit the branch points at — not the commit the pull
# request happens to sit on. Measured against the live API the two genuinely
# differ (PR #775 sat on c340b093 while master pointed at 35489172), so a
# implementation that returned the wrong one would look right until a branch
# moved. `current` is exactly that comparison.

hfact() { printf '%s' "$1" | jq -r '.[] | select(.key=="head.exact")'; }

PR_CUR='{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z",
  "headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "baseRefName":"master",
  "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'

graph_stub "$PR_CUR"
H="$(hfact "$("$SPARK" facts --issue 733)")"
assert_contains "a pull request establishes its exact head" "ESTABLISHED" \
  "$(printf '%s' "$H" | jq -r '.status')"
assert_eq "the head is the pull request head commit" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
  "$(printf '%s' "$H" | jq -r '.value.head')"
assert_eq "the base ref is named" "master" "$(printf '%s' "$H" | jq -r '.value.base_ref')"
assert_eq "the base is the branch target commit" "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
  "$(printf '%s' "$H" | jq -r '.value.base')"
assert_eq "and a change sitting on that target is current" "true" \
  "$(printf '%s' "$H" | jq -r '.value.current')"
for field in $(required_fields); do
  if [ "$(printf '%s' "$H" | jq -r "has(\"$field\")")" = "true" ]; then ok
  else bad "the head envelope is missing the required field '$field'"; fi
done
assert_contains "the base ref is carried as an invalidator" "ref:github.com/jwogrady/spark/master" \
  "$(printf '%s' "$H" | jq -r '.invalidators | join(",")')"
assert_eq "versioned by the branch target commit, per R20" "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
  "$(printf '%s' "$H" | jq -r '.versions["ref:github.com/jwogrady/spark/master"]')"
assert_versions_canonical "$H" "head"

# THE control for this class: the branch has moved on. base must follow the
# BRANCH, and current must say the change no longer sits on it. An
# implementation returning the pull requests own base passes every assertion
# above and fails both of these.
PR_STALE='{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z",
  "headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "baseRefName":"master",
  "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"cccccccccccccccccccccccccccccccccccccccc"}},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
graph_stub "$PR_STALE"
HS="$(hfact "$("$SPARK" facts --issue 733)")"
assert_eq "base follows the branch, not the commit the change sits on" "cccccccccccccccccccccccccccccccccccccccc" \
  "$(printf '%s' "$HS" | jq -r '.value.base')"
assert_eq "and a change left behind by the branch is not current" "false" \
  "$(printf '%s' "$HS" | jq -r '.value.current')"
assert_eq "the ref version follows the branch too" "cccccccccccccccccccccccccccccccccccccccc" \
  "$(printf '%s' "$HS" | jq -r '.versions["ref:github.com/jwogrady/spark/master"]')"

# An issue has no HEAD. That is an answer, and it carries no value, no detail
# and no ref: there is no base to be stale against (R17, R18).
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},"blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
HI="$(hfact "$("$SPARK" facts --issue 733)")"
assert_contains "an issue has no head, and says so" "NOT_APPLICABLE" \
  "$(printf '%s' "$HI" | jq -r '.status')"
[ "$(printf '%s' "$HI" | jq -r 'has("value")')" = "false" ] && ok \
  || bad "a not-applicable head carries a value"
[ "$(printf '%s' "$HI" | jq -r 'has("detail")')" = "false" ] && ok \
  || bad "a not-applicable head carries a detail, which belongs to unknown and conflict alone"
[ "$(printf '%s' "$HI" | jq -r '[.invalidators[] | select(startswith("ref:"))] | length')" = "0" ] \
  && ok || bad "a not-applicable head lists a ref it has no base for"
assert_contains "and is invalidated by its own work unit" "issue:github.com/jwogrady/spark#733" \
  "$(printf '%s' "$HI" | jq -r '.invalidators | join(",")')"

# A deleted base branch names no target, so the ref token could not be
# versioned. Refused rather than emitted with an unversionable invalidator.
graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "baseRefName":"master","baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","baseRef":null,
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
[ -z "$(hfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a deleted base branch still produced a head fact"

# A head that is not a commit cannot be a value, but the node WAS read and
# versioned, so this is an unknown rather than a refusal.
graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"HEAD","baseRefName":"master",
  "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
HM="$(hfact "$("$SPARK" facts --issue 733)")"
assert_contains "a head outside the commit grammar is unknown, not established" "UNKNOWN" \
  "$(printf '%s' "$HM" | jq -r '.status')"
[ "$(printf '%s' "$HM" | jq -r 'has("value")')" = "false" ] && ok \
  || bad "an unknown head carries a value"

# --- an envelope cannot carry a token it could not spell --------------------
# The `ref:` invalidator and its version belong to EVERY status this class
# emits, so validating them after building the envelope let a malformed ref or
# target reach a caller inside an UNKNOWN — a fact naming a dependency nothing
# can resolve and a version nothing can compare. It also contradicted the
# refusal one branch above: an ABSENT target is refused, so a malformed one
# cannot be merely reported. Both are refusals now.
#
# These two fixtures were not covered by the malformed-head case, which
# exercises a value-only field and must still produce an UNKNOWN.

head_refused() { # head_refused <pull request json> <label>
  graph_stub "$1"
  local out; out="$(hfact "$("$SPARK" facts --issue 733 2>/dev/null)")"
  [ -z "$out" ] && ok || bad "$2"
}

# A base ref outside the ref grammar: the token `ref:<repository>/<name>` could
# not be canonically named.
head_refused '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "baseRefName":"refs//bad name","baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a base ref outside the grammar still produced a fact carrying that token"

# A branch target that is not a commit: the token is spellable but its version
# is not, which is the same freshness hole the absent target has.
head_refused '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "baseRefName":"master","baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"not-a-commit"}},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}' \
  "a branch target that is not a commit still produced a fact versioned by it"

# The discrimination in the other direction: a value-only field is still an
# UNKNOWN, and its envelope is sound — the ref token and its version are both
# canonical, so freshness remains decidable.
graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "baseRefName":"master","baseRefOid":"not-a-commit",
  "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
HV="$(hfact "$("$SPARK" facts --issue 733)")"
assert_contains "a value-only malformed field is still an unknown" "UNKNOWN" \
  "$(printf '%s' "$HV" | jq -r '.status')"
assert_contains "and its envelope still names the base ref" "ref:github.com/jwogrady/spark/master" \
  "$(printf '%s' "$HV" | jq -r '.invalidators | join(",")')"
assert_eq "and still versions it canonically" "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
  "$(printf '%s' "$HV" | jq -r '.versions["ref:github.com/jwogrady/spark/master"]')"
assert_versions_canonical "$HV" "head unknown"

# --- checks.required: required is not the same question as present ----------
# This repository runs five checks and requires two. The value is therefore
# keyed by the REQUIRED set read from the branch rules, and a required name
# with no run observed is `missing` — required and unanswered is a state, not
# an absence. R17 also gives this class a source the others do not have: it
# names the REPOSITORY and lists ruleset:<repository>.

cfact() { printf '%s' "$1" | jq -r '.[] | select(.key=="checks.required")'; }

HEADOID="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
pr_with_checks() { # pr_with_checks <contexts json array>
  graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
    "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"'"$HEADOID"'","baseRefName":"master",
    "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
    "commits":{"nodes":[{"commit":{"oid":"'"$HEADOID"'","statusCheckRollup":{"contexts":{"pageInfo":{"hasNextPage":false},"nodes":'"$1"'}}}}]},
    "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
}

# Both required checks green, plus one that ran and is NOT required.
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"gate","conclusion":"FAILURE","status":"COMPLETED"}]'
C="$(cfact "$("$SPARK" facts --issue 733)")"
assert_contains "a pull request establishes its required checks" "ESTABLISHED" \
  "$(printf '%s' "$C" | jq -r '.status')"
assert_eq "the required set is the branch rules, not what ran" "doctor,tests" \
  "$(printf '%s' "$C" | jq -r '.value.required | join(",")')"
assert_eq "one result per required name, and only those" "doctor=success,tests=success" \
  "$(printf '%s' "$C" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"
assert_eq "the value is bound to the exact head" "$HEADOID" \
  "$(printf '%s' "$C" | jq -r '.value.head')"
for field in $(required_fields); do
  if [ "$(printf '%s' "$C" | jq -r "has(\"$field\")")" = "true" ]; then ok
  else bad "the checks envelope is missing the required field '$field'"; fi
done

# R17: this class names the REPOSITORY, not the work unit. Every sibling names
# the work unit, so an implementation copying one of them passes everything
# above and fails here.
assert_eq "the source is the repository, per R17" "github.com/jwogrady/spark" \
  "$(printf '%s' "$C" | jq -r '.source.identity')"
assert_contains "the exact head is an invalidator" "head:$HEADOID" \
  "$(printf '%s' "$C" | jq -r '.invalidators | join(",")')"
assert_contains "and the rulesets that require them" "ruleset:github.com/jwogrady/spark" \
  "$(printf '%s' "$C" | jq -r '.invalidators | join(",")')"
assert_eq "the head token is versioned by the commit itself, per R20" "$HEADOID" \
  "$(printf '%s' "$C" | jq -r '.versions["head:'"$HEADOID"'"]')"
printf '%s' "$(printf '%s' "$C" | jq -r '.versions["ruleset:github.com/jwogrady/spark"]')" \
  | grep -Eq '^[0-9a-f]{40}$' && ok \
  || bad "the ruleset token is not versioned by a collection digest"
assert_versions_canonical "$C" "checks"

# A required check that never ran is `missing`, not absent from the answer.
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
CM="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "a required check with no run observed is missing" "doctor=success,tests=missing" \
  "$(printf '%s' "$CM" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

# A run that has not completed is pending, whatever it currently reports.
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":null,"status":"IN_PROGRESS"},
                 {"__typename":"CheckRun","name":"tests","conclusion":"FAILURE","status":"COMPLETED"}]'
CP="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "an incomplete run is pending, and a completed failure is failure" "doctor=pending,tests=failure" \
  "$(printf '%s' "$CP" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

# SKIPPED is deliberately NOT success. The vocabulary has no fifth state, and
# R12 merges only when every required check is success, so a required check
# that never ran its assertions must not read as one that passed.
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SKIPPED","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"tests","conclusion":"NEUTRAL","status":"COMPLETED"}]'
CS="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "a skipped or neutral required check is not a passing one" "doctor=failure,tests=failure" \
  "$(printf '%s' "$CS" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

# A rollup belonging to another commit is not the state of THIS head.
graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"'"$HEADOID"'","baseRefName":"master",
  "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  "commits":{"nodes":[{"commit":{"oid":"dddddddddddddddddddddddddddddddddddddddd","statusCheckRollup":{"contexts":{"pageInfo":{"hasNextPage":false},"nodes":[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},{"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED"}]}}}}]},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
CW="$(cfact "$("$SPARK" facts --issue 733)")"
assert_contains "a rollup for another commit is not this head's state" "UNKNOWN" \
  "$(printf '%s' "$CW" | jq -r '.status')"
[ "$(printf '%s' "$CW" | jq -r 'has("value")')" = "false" ] && ok \
  || bad "a mismatched rollup still produced a value"

# A bounded rollup has not told us every state, so it is an unknown rather than
# a shorter answer.
graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"'"$HEADOID"'","baseRefName":"master",
  "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  "commits":{"nodes":[{"commit":{"oid":"'"$HEADOID"'","statusCheckRollup":{"contexts":{"pageInfo":{"hasNextPage":true},"nodes":[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]}}}}]},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
CB="$(cfact "$("$SPARK" facts --issue 733)")"
assert_contains "a bounded rollup is an unknown, not a shorter answer" "bounded" \
  "$(printf '%s' "$CB" | jq -r '.detail.reason')"

# An issue has no head, so no required check can be in a state against it. R17
# says such a fact names the WORK UNIT rather than the repository.
graph_stub '{"number":733,"repository":{"nameWithOwner":"jwogrady/spark"},"state":"OPEN","updatedAt":"2026-09-08T10:00:00Z","parent":null,"subIssues":{"pageInfo":{"hasNextPage":false},"nodes":[]},"blockedBy":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
CI="$(cfact "$("$SPARK" facts --issue 733)")"
assert_contains "an issue has no required checks to be in a state" "NOT_APPLICABLE" \
  "$(printf '%s' "$CI" | jq -r '.status')"
assert_eq "and names the work unit rather than the repository" "github.com/jwogrady/spark#733" \
  "$(printf '%s' "$CI" | jq -r '.source.identity')"
[ "$(printf '%s' "$CI" | jq -r '[.invalidators[] | select(startswith("ruleset:"))] | length')" = "0" ] \
  && ok || bad "a not-applicable checks fact lists a ruleset it never consulted"
[ "$(printf '%s' "$CI" | jq -r 'has("detail")')" = "false" ] && ok \
  || bad "a not-applicable checks fact carries a detail"

# --- a legacy status context is not a completed check run ------------------
# StatusContext carries no separate status: its state is both what it is doing
# and how it ended. Synthesizing COMPLETED for it turned PENDING and EXPECTED
# into completed non-successes — a check still running reported as one that
# failed, which is the opposite of what a caller waiting on it needs.

pr_with_contexts() { # pr_with_contexts <contexts json array>
  graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
    "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"'"$HEADOID"'","baseRefName":"master",
    "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
    "commits":{"nodes":[{"commit":{"oid":"'"$HEADOID"'","statusCheckRollup":{"contexts":{"pageInfo":{"hasNextPage":false},"nodes":'"$1"'}}}}]},
    "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
}

pr_with_contexts '[{"__typename":"StatusContext","context":"doctor","state":"PENDING"},
                   {"__typename":"StatusContext","context":"tests","state":"EXPECTED"}]'
CSC="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "a status context still running is pending, not failed" "doctor=pending,tests=pending" \
  "$(printf '%s' "$CSC" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

pr_with_contexts '[{"__typename":"StatusContext","context":"doctor","state":"SUCCESS"},
                   {"__typename":"StatusContext","context":"tests","state":"FAILURE"}]'
CSD="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "and a settled status context keeps its own verdict" "doctor=success,tests=failure" \
  "$(printf '%s' "$CSD" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

# --- "requires nothing" is a claim; a malformed reply is not that claim -----
# Both would otherwise be an empty required set. One is a valid answer, the
# other is no answer at all, and hashing the second would ESTABLISH a fact
# saying the branch requires nothing.
RULES_SAVED="$RULES"
RULES='{"message":"Not Found"}'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
[ -z "$(cfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a branch-rules reply that was not the promised array established a checks fact"
RULES="$RULES_SAVED"

# An empty array IS a valid answer: this branch requires nothing, versioned.
RULES='[]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
CE="$(cfact "$("$SPARK" facts --issue 733)")"
assert_contains "a branch that requires nothing still establishes" "ESTABLISHED" \
  "$(printf '%s' "$CE" | jq -r '.status')"
assert_eq "with an empty required set" "0" \
  "$(printf '%s' "$CE" | jq -r '.value.required | length')"
printf '%s' "$(printf '%s' "$CE" | jq -r '.versions["ruleset:github.com/jwogrady/spark"]')" \
  | grep -Eq '^[0-9a-f]{40}$' && ok \
  || bad "requiring nothing produced no digest, so the answer could not go stale"
RULES="$RULES_SAVED"

# --- a branch name is ONE path segment -------------------------------------
# `feat/x` interpolated raw becomes two segments and the lookup fails for a
# base branch that is perfectly valid.
: > "$GH_CALL_LOG"
graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"'"$HEADOID"'","baseRefName":"release/v1.0",
  "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  "commits":{"nodes":[{"commit":{"oid":"'"$HEADOID"'","statusCheckRollup":{"contexts":{"pageInfo":{"hasNextPage":false},"nodes":[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},{"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED"}]}}}}]},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
"$SPARK" facts --issue 733 >/dev/null 2>&1
grep -q 'rules/branches/release%2Fv1.0' "$GH_CALL_LOG" && ok \
  || bad "a base branch containing a slash was not asked for as one path segment"

# --- two rulesets requiring the same check is still one check --------------
# R12 admits exactly one result per required check name. Overlapping rulesets
# are ordinary in a repository that layers an org ruleset over a repo one, and
# emitting `doctor` twice would produce two results for one name and let the
# same check be counted twice toward merge.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor"},{"context":"tests"}]}},
        {"type":"required_status_checks","ruleset_id":2,"parameters":{"required_status_checks":[{"context":"doctor"}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED"}]'
CD="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "a check required by two rulesets is named once" "doctor,tests" \
  "$(printf '%s' "$CD" | jq -r '.value.required | join(",")')"
assert_eq "and carries exactly one result" "doctor=success,tests=success" \
  "$(printf '%s' "$CD" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"
# The digest still distinguishes the two-ruleset configuration from the one-
# ruleset one: R20 versions the collection as read, not the deduplicated view.
DIG_TWO="$(printf '%s' "$CD" | jq -r '.versions["ruleset:github.com/jwogrady/spark"]')"
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor"},{"context":"tests"}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED"}]'
CD1="$(cfact "$("$SPARK" facts --issue 733)")"
DIG_ONE="$(printf '%s' "$CD1" | jq -r '.versions["ruleset:github.com/jwogrady/spark"]')"
[ "$DIG_TWO" != "$DIG_ONE" ] && ok \
  || bad "dropping a duplicate name also dropped the ruleset it came from, so the digest could not tell the two configurations apart"
RULES="$RULES_SAVED"

# --- a malformed required-check rule is not "nothing is required" ----------
# The dangerous failure here is silent: a rule of the right TYPE whose shape
# cannot be read, discarded quietly, establishes an empty required set, and an
# empty required set means every check is satisfied and everything merges.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":"doctor"}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
CM="$("$SPARK" facts --issue 733 2>/dev/null)"
[ -z "$(cfact "$CM")" ] && ok \
  || bad "a required-status-checks rule that was not readable still produced a checks fact"

# The same holds one level down: a well-formed rule whose entries are not
# contexts is unreadable, not empty.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor"},{"ctx":"tests"}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
CM2="$("$SPARK" facts --issue 733 2>/dev/null)"
[ -z "$(cfact "$CM2")" ] && ok \
  || bad "an unreadable required-check entry was discarded and the rest established as the whole truth"

# Rules of OTHER types are still ignored: their shape is not this reader to
# police, and refusing on them would make an unrelated ruleset break checks.
RULES='[{"type":"deletion","parameters":"whatever"},
        {"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor"}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
CM3="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "an unrelated rule type does not refuse the read" "doctor" \
  "$(printf '%s' "$CM3" | jq -r '.value.required | join(",")')"
RULES="$RULES_SAVED"

# --- a pull request that carried no commit observed nothing ---------------
# `commits(last:1)` always answers with the head commit, so an empty array is
# a reply that did not carry the observation. Admitted, it binds nothing to
# the head, every required check reads `missing`, and the fact establishes
# that from no evidence.
graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"'"$HEADOID"'","baseRefName":"master",
  "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  "commits":{"nodes":[]},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
CN="$("$SPARK" facts --issue 733 2>/dev/null)"
[ -z "$(cfact "$CN")" ] && ok \
  || bad "a reply that carried no commit still established the state of every required check"

# --- one name observed in two states is a CONFLICT, not the first row -----
# A rollup can carry a re-run beside the run it replaces. R8: two authoritative
# inputs that disagree are a CONFLICT, and no first-write rule resolves them.
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"doctor","conclusion":"FAILURE","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED"}]'
CC="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "a required check observed in two states conflicts" "CONFLICT" \
  "$(printf '%s' "$CC" | jq -r '.status')"
assert_contains "and the conflict names the check" "doctor" \
  "$(printf '%s' "$CC" | jq -r '.detail.reason')"
printf '%s' "$CC" | jq -e 'has("value") | not' >/dev/null && ok \
  || bad "a CONFLICT carried a value, which R6 forbids"

# The order of the two rows must not decide the answer: reversing them is the
# same contradiction, and a first-write rule would flip the result.
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"FAILURE","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED"}]'
assert_eq "and conflicts whichever row came first" "CONFLICT" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '.status')"

# Repetition is not contradiction: two runs that AGREE answer normally.
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED"}]'
CA="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "two runs that agree are one result" "doctor=success,tests=success" \
  "$(printf '%s' "$CA" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

# A duplicate on a name nobody requires says nothing about this fact.
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"lint","conclusion":"SUCCESS","status":"COMPLETED"},
                 {"__typename":"CheckRun","name":"lint","conclusion":"FAILURE","status":"COMPLETED"}]'
assert_eq "a contradiction on an unrequired check does not conflict" "ESTABLISHED" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '.status')"

# --- a requiring ruleset must say which ruleset it is ---------------------
# The digest is declared to cover every requiring ruleset id. Defaulting an
# absent id to 0 makes "some ruleset nobody identified" hash like a real
# ruleset 0, and freshness then rests on provenance nobody observed.
RULES='[{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"doctor"}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
CR="$("$SPARK" facts --issue 733 2>/dev/null)"
[ -z "$(cfact "$CR")" ] && ok \
  || bad "a requiring ruleset with no id was accepted and its provenance invented"
RULES="$RULES_SAVED"

# --- a requirement can bind the app that must answer it -------------------
# GitHub lets a rule require `doctor` FROM a named app. A check of that name
# from anyone else does not satisfy it, and reading only the name would let a
# look-alike pass the gate.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor","integration_id":15368}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":15368}}}]'
assert_eq "the required app answering satisfies the requirement" "doctor=success" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":99999}}}]'
assert_eq "the same name from another app does not" "doctor=missing" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

# A status context carries no app, so it cannot answer an app-bound
# requirement however green it is.
pr_with_checks '[{"__typename":"StatusContext","context":"doctor","state":"SUCCESS"}]'
assert_eq "and neither does a status context with no producer" "doctor=missing" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

# Swapping the required app is a change in what is required, so freshness must
# see it: the digest cannot be blind to the binding.
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":15368}}}]'
DIG_A="$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '.versions["ruleset:github.com/jwogrady/spark"]')"
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor","integration_id":424242}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":15368}}}]'
DIG_B="$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '.versions["ruleset:github.com/jwogrady/spark"]')"
[ -n "$DIG_A" ] && [ "$DIG_A" != "$DIG_B" ] && ok \
  || bad "changing the app a check is required from left the ruleset digest unchanged"

# An unbound requirement is still satisfied by the name alone: binding is
# optional, and this repository's own rules do not use it.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor"}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":15368}}}]'
assert_eq "an unbound requirement takes the name from any producer" "doctor=success" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

# --- two requirements wearing one name are aggregated conservatively ------
# R12 admits one result per name, so a name required from two apps reports
# `success` only when both answered.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor","integration_id":1},{"context":"doctor","integration_id":2}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":1}}},
                 {"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":2}}}]'
CG="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "one name required twice is one result" "1" \
  "$(printf '%s' "$CG" | jq -r '.value.results | length')"
assert_eq "and both answering is success" "doctor=success" \
  "$(printf '%s' "$CG" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":1}}}]'
assert_eq "one of the two silent is not success" "doctor=missing" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":1}}},
                 {"__typename":"CheckRun","name":"doctor","conclusion":"FAILURE","status":"COMPLETED","checkSuite":{"app":{"databaseId":2}}}]'
assert_eq "and one of the two failing is failure" "doctor=failure" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"
RULES="$RULES_SAVED"

# --- a context bearing a delimiter is refused, not transported ------------
# These rows are TSV and the required names travel newline-delimited. A tab or
# newline inside a context splits a row, mismatches an observed name, and lets
# two different collections serialize to one digest.
RULES="$(printf '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doc\\ttor"}]}}]')"
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
[ -z "$(cfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a required context containing a tab was carried into the rows anyway"

RULES="$(printf '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doc\\ntor"}]}}]')"
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
[ -z "$(cfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a required context containing a newline was carried into the rows anyway"
RULES="$RULES_SAVED"

# --- an app id that is not a number is malformed --------------------------
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor","integration_id":"15368"}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
[ -z "$(cfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a requirement whose app id was not a number was accepted"
RULES="$RULES_SAVED"

# --- a required name of no characters is not "nothing is required" -------
# An empty context survives every string check and is then skipped when the
# results are built, so the rule establishes an empty required set — and an
# empty required set means every check is satisfied and everything merges.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":""}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
[ -z "$(cfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a required context of no characters established a required set anyway"

# The same emptiness beside a real requirement must not be silently dropped
# either: the reply is unreadable, not partially readable.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doctor"},{"context":""}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
[ -z "$(cfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "an empty context beside a real one was quietly discarded"
RULES="$RULES_SAVED"

# --- a name @tsv would rewrite is refused, so what is carried round-trips -
# `@tsv` escapes backslash, tab, newline and carriage return, and nothing
# decodes them, so a real context of `foo\bar` would be carried and reported
# as `foo\\bar` — a different check name than the one required. Refusing the
# characters the encoding rewrites makes it an identity for what is admitted.
RULES="$(printf '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"foo\\\\bar"}]}}]')"
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
[ -z "$(cfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a required context containing a backslash was carried and silently rewritten"

# A control character that TSV would survive but rendering would not.
RULES="$(printf '[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"doc\\u0001tor"}]}}]')"
pr_with_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
[ -z "$(cfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a required context containing a control character was carried anyway"

# What IS admitted round-trips exactly, including the punctuation real check
# names use.
RULES='[{"type":"required_status_checks","ruleset_id":1,"parameters":{"required_status_checks":[{"context":"build (ubuntu-latest, 3.11) / test"}]}}]'
pr_with_checks '[{"__typename":"CheckRun","name":"build (ubuntu-latest, 3.11) / test","conclusion":"SUCCESS","status":"COMPLETED"}]'
CRT="$(cfact "$("$SPARK" facts --issue 733)")"
assert_eq "an ordinary check name round-trips exactly" "build (ubuntu-latest, 3.11) / test" \
  "$(printf '%s' "$CRT" | jq -r '.value.required[0]')"
assert_eq "and is matched against the run of that name" "success" \
  "$(printf '%s' "$CRT" | jq -r '.value.results[0].state')"
RULES="$RULES_SAVED"

# --- a malformed run is no observation of a run --------------------------
# jq resolves a MISSING field to null, so `.checkSuite == null` alone cannot
# tell a run that genuinely has no suite from a reply that omitted the field —
# and they mean opposite things: evidence that no installation produced the
# run, versus no evidence at all. The query always asks, so absence is
# malformed. Each of these must refuse the fact rather than normalize into it.
# The shared stub fills in a missing conclusion and checkSuite, because almost
# every fixture is about something else. These assertions are about ABSENCE
# itself, so they build the reply without that help.
raw_pr_checks() { # raw_pr_checks <contexts json array> — no stub defaults
  local node='{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
    "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"'"$HEADOID"'","baseRefName":"master",
    "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","milestone":null,
    "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
    "commits":{"nodes":[{"commit":{"oid":"'"$HEADOID"'","statusCheckRollup":{"contexts":{"pageInfo":{"hasNextPage":false},"nodes":'"$1"'}}}}]},
    "comments":{"pageInfo":{"hasPreviousPage":false},"nodes":[]},
    "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
case "\$*" in
  *graphql*) answer_json '{"data":{"repository":{"issueOrPullRequest":$node}}}' ;;
  *"repos/jwogrady/spark/rules/branches/"*) answer_json '$RULES' ;;
  *"--hostname github.com repos/jwogrady/spark"*) answer_json '$NODE' ;;
  *) exit 1 ;;
esac
STUB
}
refuses_checks() { # refuses_checks <label> <contexts json array>
  raw_pr_checks "$2"
  [ -z "$(cfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok || bad "$1"
}

refuses_checks "a conclusion that is not null or a string was normalized anyway" \
  '[{"__typename":"CheckRun","name":"doctor","conclusion":7,"status":"COMPLETED","checkSuite":null}]'
refuses_checks "a run with no conclusion field at all was read as inconclusive" \
  '[{"__typename":"CheckRun","name":"doctor","status":"COMPLETED","checkSuite":null}]'
refuses_checks "an omitted checkSuite was read as a run produced by nobody" \
  '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED"}]'
refuses_checks "a suite with no app field was read as a suite with no app" \
  '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{}}]'
refuses_checks "an app with no id was read as an app" \
  '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{}}}]'
refuses_checks "an app id that is not a number was accepted" \
  '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":{"databaseId":"15368"}}}]'
refuses_checks "a suite that is not an object was accepted" \
  '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":7}]'

# The legitimately absent shapes are still admitted, explicitly stated: a run
# with no suite, and a suite with no app, are evidence rather than gaps.
raw_pr_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":null},
                {"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":{"app":null}}]'
assert_eq "a run with no suite and a suite with no app are both evidence" "doctor=success,tests=success" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"

# A run still in flight has a null conclusion, which is the ordinary case the
# strictness must not break.
raw_pr_checks '[{"__typename":"CheckRun","name":"doctor","conclusion":null,"status":"IN_PROGRESS","checkSuite":null},
                {"__typename":"CheckRun","name":"tests","conclusion":"SUCCESS","status":"COMPLETED","checkSuite":null}]'
assert_eq "a run in flight carries a null conclusion and stays pending" "doctor=pending,tests=success" \
  "$(printf '%s' "$(cfact "$("$SPARK" facts --issue 733)")" | jq -r '[.value.results[] | "\(.name)=\(.state)"] | join(",")')"
# --- review.independent ----------------------------------------------------
RULES="$RULES_SAVED"
MARK='<!-- spark-openai-review pr=733 head='"$HEADOID"' verdict=PASS -->'
pr_with_comments() { # pr_with_comments <comments json array> [hasPreviousPage]
  graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
    "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"'"$HEADOID"'","baseRefName":"master",
    "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
    "commits":{"nodes":[{"commit":{"oid":"'"$HEADOID"'","statusCheckRollup":null}}]},
    "comments":{"pageInfo":{"hasPreviousPage":'"${2:-false}"'},"nodes":'"$1"'},
    "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
}
rfact() { printf '%s' "$1" | jq -r '.[] | select(.key=="review.independent")'; }

# An issue has no change, so there is no verdict bound to a head: an answer,
# not a gap.
graph_stub "$FULL"
RI="$(rfact "$("$SPARK" facts --issue 733)")"
assert_eq "an issue has no review to be independent of" "NOT_APPLICABLE" \
  "$(printf '%s' "$RI" | jq -r '.status')"
printf '%s' "$RI" | jq -e '(has("value") | not) and (has("detail") | not)' >/dev/null && ok \
  || bad "a NOT_APPLICABLE review carried a value or a detail"

# A pull request nobody has reviewed at this head is UNKNOWN, never a PASS.
pr_with_comments '[]'
RU="$(rfact "$("$SPARK" facts --issue 733)")"
assert_eq "an unreviewed head is unknown" "UNKNOWN" "$(printf '%s' "$RU" | jq -r '.status')"
assert_contains "and says so" "no independent verdict names this head" \
  "$(printf '%s' "$RU" | jq -r '.detail.reason')"

# The verdict, bound to the exact head, naming its record and its author.
pr_with_comments '[{"databaseId":5619324861,"updatedAt":"2026-09-10T12:00:00Z",
                    "author":{"login":"github-actions"},"body":"'"$MARK"'\n\n## Reviewer verdict: PASS"}]'
RE="$(rfact "$("$SPARK" facts --issue 733)")"
assert_eq "a verdict at this head establishes" "ESTABLISHED" "$(printf '%s' "$RE" | jq -r '.status')"
assert_eq "carrying the verdict" "PASS" "$(printf '%s' "$RE" | jq -r '.value.verdict')"
assert_eq "the head it judged" "$HEADOID" "$(printf '%s' "$RE" | jq -r '.value.head')"
assert_eq "who judged it" "login:github-actions" "$(printf '%s' "$RE" | jq -r '.value.reviewer')"
assert_eq "and the record it is written in" "github.com/jwogrady/spark#733/comment/5619324861" \
  "$(printf '%s' "$RE" | jq -r '.value.record')"
# R17: the record is the source and a comment: invalidator; R20 versions it by
# the comment updated_at, so an edited verdict goes stale rather than standing.
assert_eq "the record is the source" "github.com/jwogrady/spark#733/comment/5619324861" \
  "$(printf '%s' "$RE" | jq -r '.source.identity')"
assert_eq "versioned by when the record was last written" "2026-09-10T12:00:00Z" \
  "$(printf '%s' "$RE" | jq -r '.source.version')"
assert_eq "and the record can go stale" "2026-09-10T12:00:00Z" \
  "$(printf '%s' "$RE" | jq -r '.versions["comment:github.com/jwogrady/spark#733/comment/5619324861"]')"
# R17: the pull request whose comments hold the verdicts is listed too, so a
# record posted after this read fires a token the fact already carries.
printf '%s' "$RE" | jq -e '[.invalidators[]] | index("pull_request:github.com/jwogrady/spark#733")' >/dev/null && ok \
  || bad "the review did not list the pull request whose comments hold the verdicts"

# A verdict for a DIFFERENT head is not this head's verdict.
pr_with_comments '[{"databaseId":1,"updatedAt":"2026-09-10T12:00:00Z","author":{"login":"github-actions"},
                    "body":"<!-- spark-openai-review pr=733 head=cccccccccccccccccccccccccccccccccccccccc verdict=PASS -->"}]'
assert_eq "a verdict on another head does not answer this one" "UNKNOWN" \
  "$(printf '%s' "$(rfact "$("$SPARK" facts --issue 733)")" | jq -r '.status')"

# A marker naming a different pull request is not this pull request's verdict.
pr_with_comments '[{"databaseId":1,"updatedAt":"2026-09-10T12:00:00Z","author":{"login":"github-actions"},
                    "body":"<!-- spark-openai-review pr=999 head='"$HEADOID"' verdict=PASS -->"}]'
assert_eq "nor does a marker naming another pull request" "UNKNOWN" \
  "$(printf '%s' "$(rfact "$("$SPARK" facts --issue 733)")" | jq -r '.status')"

# A marker QUOTED inside a comment is a quotation of a verdict, never one.
# Evidence comments on these very pull requests quote reviewer output verbatim.
pr_with_comments '[{"databaseId":1,"updatedAt":"2026-09-10T12:00:00Z","author":{"login":"jwogrady"},
                    "body":"The reviewer said:\n\n'"$MARK"'\n\nand I have repaired it."}]'
assert_eq "a quoted marker is not a verdict" "UNKNOWN" \
  "$(printf '%s' "$(rfact "$("$SPARK" facts --issue 733)")" | jq -r '.status')"

# R8: two records naming one head are a CONFLICT with both named, even when
# they agree — the value must name ONE record, and choosing by position is the
# first-write rule R8 forbids.
pr_with_comments '[{"databaseId":1,"updatedAt":"2026-09-10T12:00:00Z","author":{"login":"github-actions"},
                    "body":"'"$MARK"'"},
                   {"databaseId":2,"updatedAt":"2026-09-10T12:30:00Z","author":{"login":"someone-else"},
                    "body":"<!-- spark-openai-review pr=733 head='"$HEADOID"' verdict=CHANGES REQUIRED -->"}]'
RC2="$(rfact "$("$SPARK" facts --issue 733)")"
assert_eq "two records for one head conflict" "CONFLICT" "$(printf '%s' "$RC2" | jq -r '.status')"
assert_eq "naming both as candidates" "2" \
  "$(printf '%s' "$RC2" | jq -r '.detail.candidates | length')"
printf '%s' "$RC2" | jq -e 'has("value") | not' >/dev/null && ok \
  || bad "a CONFLICT review carried a value, which R6 forbids"
# Every named record is also an invalidator, so editing either stales the fact.
printf '%s' "$RC2" | jq -e '[.invalidators[]] | index("comment:github.com/jwogrady/spark#733/comment/2")' >/dev/null && ok \
  || bad "a record named as a candidate was not listed as an invalidator"

# Agreement does not rescue it: the fact still cannot say which record it is.
pr_with_comments '[{"databaseId":1,"updatedAt":"2026-09-10T12:00:00Z","author":{"login":"github-actions"},"body":"'"$MARK"'"},
                   {"databaseId":2,"updatedAt":"2026-09-10T12:30:00Z","author":{"login":"github-actions"},"body":"'"$MARK"'"}]'
assert_eq "and two agreeing records still cannot name one record" "CONFLICT" \
  "$(printf '%s' "$(rfact "$("$SPARK" facts --issue 733)")" | jq -r '.status')"

# A window that never reached the start of the conversation cannot say that no
# verdict names this head.
pr_with_comments '[]' true
RB="$(rfact "$("$SPARK" facts --issue 733)")"
assert_eq "a bounded comment window is unknown" "UNKNOWN" "$(printf '%s' "$RB" | jq -r '.status')"
assert_eq "and says it was bounded" "bounded" "$(printf '%s' "$RB" | jq -r '.detail.reason')"

# A comment by a deleted account names no reviewer, and reviewer is part of the
# value, so the fact is unknown rather than carrying a blank author.
pr_with_comments '[{"databaseId":1,"updatedAt":"2026-09-10T12:00:00Z","author":null,"body":"'"$MARK"'"}]'
assert_eq "a verdict by nobody names no reviewer" "UNKNOWN" \
  "$(printf '%s' "$(rfact "$("$SPARK" facts --issue 733)")" | jq -r '.status')"

# Logins are compared case-insensitively by GitHub, so one representation per
# actor (R1).
pr_with_comments '[{"databaseId":1,"updatedAt":"2026-09-10T12:00:00Z","author":{"login":"GitHub-Actions"},"body":"'"$MARK"'"}]'
assert_eq "a login is carried in one canonical case" "login:github-actions" \
  "$(printf '%s' "$(rfact "$("$SPARK" facts --issue 733)")" | jq -r '.value.reviewer')"

# The verdict vocabulary is closed: anything outside it is not a verdict marker
# at all, so the head reads as unreviewed rather than carrying a made-up state.
pr_with_comments '[{"databaseId":1,"updatedAt":"2026-09-10T12:00:00Z","author":{"login":"github-actions"},
                    "body":"<!-- spark-openai-review pr=733 head='"$HEADOID"' verdict=LGTM -->"}]'
assert_eq "a verdict outside the vocabulary is no verdict" "UNKNOWN" \
  "$(printf '%s' "$(rfact "$("$SPARK" facts --issue 733)")" | jq -r '.status')"

# A malformed comment record is a malformed OBSERVATION, not a fact with a
# reason: an id that is not a number names nothing.
graph_stub '{"__typename":"PullRequest","number":733,"repository":{"nameWithOwner":"jwogrady/spark"},
  "updatedAt":"2026-09-08T10:00:00Z","headRefOid":"'"$HEADOID"'","baseRefName":"master",
  "baseRefOid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "baseRef":{"target":{"oid":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  "commits":{"nodes":[{"commit":{"oid":"'"$HEADOID"'","statusCheckRollup":null}}]},
  "comments":{"pageInfo":{"hasPreviousPage":false},"nodes":[{"databaseId":"1","updatedAt":"2026-09-10T12:00:00Z","author":{"login":"github-actions"},"body":"x"}]},
  "closingIssuesReferences":{"pageInfo":{"hasNextPage":false},"nodes":[]}}'
[ -z "$(rfact "$("$SPARK" facts --issue 733 2>/dev/null)")" ] && ok \
  || bad "a comment whose id was not a number was read as an observation anyway"

RULES="$RULES_SAVED"

finish
