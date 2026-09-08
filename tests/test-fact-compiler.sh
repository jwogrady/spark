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
#   * an unreadable source is an UNKNOWN with a stated reason, never a smaller
#     success and never a surviving previous value;
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

# --- the unreadable ladder ---------------------------------------------------
# Every one of these is UNKNOWN with a reason. None is a permissive default, and
# none carries a value: an unreadable source is not a smaller success.
unreadable_case() { # unreadable_case <message> <expected reason> <label>
  stub_gh "$WORK/bin/gh" <<STUB
printf '%s\n' "\$*" >> "\$GH_CALL_LOG"
echo "$1" >&2
exit 1
STUB
  local u; u="$("$SPARK" facts | jq -r '.[0]')"
  assert_contains "$3" "$2" "$(printf '%s' "$u" | jq -r '.detail.reason')"
  [ "$(printf '%s' "$u" | jq -r '.status')" = "UNKNOWN" ] && ok \
    || bad "$3: an unreadable source is UNKNOWN"
  [ "$(printf '%s' "$u" | jq -r 'has("value")')" = "false" ] && ok \
    || bad "$3: an unknown fact carries no value"
  # It still names the node it failed to read, so the failure goes stale when
  # that node changes.
  [ "$(printf '%s' "$u" | jq -r '.invalidators[0]')" = "repository:github.com/jwogrady/spark" ] && ok \
    || bad "$3: an unknown still names the node it could not read"
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
}

malformed_case '{"full_name":"jwogrady/spark","default_branch":"master","updated_at":"not-a-timestamp"}' \
  'a version outside the timestamp grammar is malformed'
malformed_case '{"full_name":"jwogrady/spark","default_branch":"master","updated_at":"2026-02-30T00:00:00Z"}' \
  'and so is an instant the calendar does not have'
malformed_case '{"full_name":"not a repository name","default_branch":"master","updated_at":"2026-09-07T21:00:00Z"}' \
  'a name outside the repository grammar is malformed'
malformed_case '{"full_name":"jwogrady/spark.git","default_branch":"master","updated_at":"2026-09-07T21:00:00Z"}' \
  'including one carrying the clone URL suffix a constraint forbids'
malformed_case '{"full_name":"jwogrady/spark","default_branch":"refs/heads/master","updated_at":"2026-09-07T21:00:00Z"}' \
  'a ref spelled as its refs/ path is malformed'
malformed_case '{"full_name":"jwogrady/spark","default_branch":"bad..name","updated_at":"2026-09-07T21:00:00Z"}' \
  'and so is a branch name Git would refuse'

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

# An unreadable run reports the unknown rather than a smaller emitted count.
stub_gh "$WORK/bin/gh" <<'STUB'
echo 'gh: Not Found (HTTP 404)' >&2
exit 1
STUB
SPARK_RUN_ID=rfacts2 "$SPARK" facts >/dev/null
TEL2="$("$SPARK" telemetry show --run rfacts2 --json)"
assert_contains "an unreadable run still emitted its fact" '"facts_emitted":1' "$TEL2"
assert_contains "and counts it as unknown" '"facts_unknown":1' "$TEL2"

finish
