# shellcheck shell=bash
# ---------------------------------------------------------------------------
# spark facts — the fact compiler (#733)
#
# Authoritative sources are read once, normalized through the canonical
# semantics the repository already owns, and emitted as facts in the shape
# ADR-0033 fixed (preferences/fact-model.tsv). The point is not to add a layer:
# it is to stop every verb re-deriving the same truth in its own vocabulary,
# each with its own idea of what "unreadable" means.
#
# What this module will not do, because the model forbids it:
#
#   * invent authority semantics — the compiler reads and normalizes, and a
#     precedence the model does not define is a CONFLICT, not a decision here;
#   * write anything to .spark/state.json (R10) — a fact is read from its
#     source and carried, never stored as state;
#   * let an unreadable source read as a small success. The old value never
#     survives as authority (F5), and the failure is reported with its reason;
#   * emit a fact whose observed version is not a version. An UNKNOWN is a full
#     envelope — it records the version of the node it depends on, which is how
#     freshness is decided — so when that version cannot be observed the fact is
#     refused rather than shipped with an empty one. Which case applies is
#     decided by what was actually read, not by a uniform rule: a read that
#     succeeded and returned a malformed field still observed the node's version,
#     so that UNKNOWN conforms and is emitted.
#
# EVERY IDENTITY A FACT CARRIES IS ONE THIS COMPILER OBSERVED. Never one it
# assumed because it asked nicely. Three defects in this module were the same
# mistake wearing different clothes — an endpoint resolved from gh's own context
# rather than from the locator, a root issue number requested and never checked,
# a root repository synthesized from the request — and each one could have bound
# another node's version and relationships to this work unit's name. So a reply
# must say which node it is about, and that must match what was asked, before
# anything it contains becomes a fact.
#
# The output is a FRAGMENT, not a snapshot: a bare list of facts (R11, R22). A
# snapshot is exactly {observer, facts} with every required class present, and
# this module compiles two of them — `repository` and `graph` — so calling its
# output a snapshot would be a lie a consumer is entitled to act on.
#
# The functions here SET a variable rather than printing their result, the same
# discipline __spark_memo_key follows and for a sharper reason: a command
# substitution runs in a subshell, so a compiler that printed its facts would
# lose every count it made while producing them. The metrics would then report
# zero reads for a run that made one, which is worse than not measuring at all.
# ---------------------------------------------------------------------------

# The repository class's canonical locator is repository.sh's, and a shared
# primitive is never restated to let a module stand alone.
spark_load_module repository || return 1

# The schema version every emitted fact conforms to. A consumer that does not
# know this version must treat the fact as UNKNOWN rather than reinterpret it
# (R9), which is only possible because the fact carries the number.
FACTS_SCHEMA_VERSION=1

# Per-invocation counters, reported as telemetry when a run is being observed.
# Zero is a real answer here: this compiler ran and made no API call.
FACTS_EMITTED=0
FACTS_UNKNOWN=0
FACTS_API_CALLS=0
# Reported as zero honestly: no reuse was attempted, which is not the same claim
# as reuse that failed. The keys exist so the packet that adds a second call
# site can show hits rising while the read count stays flat.
FACTS_CACHE_HITS=0
FACTS_CACHE_MISSES=0

# The result variables the functions below set.
FACTS_NODE=""
FACTS_JSON=""
# Why no fact could be emitted, when none could. A fact is refused rather than
# emitted invalid, and the caller reports this instead of a status.
FACTS_REFUSED=""

# The shipped model is the authority for what a canonical value looks like, so
# the compiler is held to the schema rather than to a copy of it. Read ONCE per
# process into these, in a single pass: a validator that re-read the file per
# field would make conformance cost more than the read it is checking.
FACTS_MODEL="$SPARK_ROOT/preferences/fact-model.tsv"
FACTS_RE_REPOSITORY=""
FACTS_RE_REF=""
FACTS_RE_TIMESTAMP=""
FACTS_RE_WORK_UNIT=""
FACTS_RE_ISSUE_STATE=""
FACTS_RE_VERDICT=""
FACTS_RE_LOGIN=""
FACTS_RE_COMMENT=""
FACTS_CON_REPOSITORY=""
FACTS_CON_REF=""
FACTS_CON_WORK_UNIT=""
FACTS_GRAMMARS_LOADED=""

facts_load_grammars() {
  [ -z "$FACTS_GRAMMARS_LOADED" ] || return 0
  local line kind name rest
  while IFS=$'\t' read -r kind name rest; do
    case "$kind/$name" in
      identifier/repository) FACTS_RE_REPOSITORY="$rest" ;;
      identifier/work-unit)  FACTS_RE_WORK_UNIT="$rest" ;;
      identifier/milestone)  FACTS_RE_MILESTONE="$rest" ;;
      identifier/commit)     FACTS_RE_COMMIT="$rest" ;;
      identifier/issue-state) FACTS_RE_ISSUE_STATE="$rest" ;;
      identifier/verdict)    FACTS_RE_VERDICT="$rest" ;;
      identifier/login)      FACTS_RE_LOGIN="$rest" ;;
      identifier/comment)    FACTS_RE_COMMENT="$rest" ;;
      constraint/work-unit)  FACTS_CON_WORK_UNIT="$FACTS_CON_WORK_UNIT$rest"$'\n' ;;
      identifier/ref)        FACTS_RE_REF="$rest" ;;
      identifier/timestamp)  FACTS_RE_TIMESTAMP="$rest" ;;
      constraint/repository) FACTS_CON_REPOSITORY="$FACTS_CON_REPOSITORY$rest"$'\n' ;;
      constraint/ref)        FACTS_CON_REF="$FACTS_CON_REF$rest"$'\n' ;;
    esac
  done < <(awk -F'\t' '
    $1 == "identifier" && ($2 == "repository" || $2 == "ref" || $2 == "timestamp" || $2 == "work-unit" || $2 == "issue-state" || $2 == "milestone" || $2 == "commit" || $2 == "verdict" || $2 == "login" || $2 == "comment") { print $1 "\t" $2 "\t" $3 }
    $1 == "constraint" && ($2 == "repository" || $2 == "ref" || $2 == "work-unit") { print $1 "\t" $2 "\t" $3 }' "$FACTS_MODEL")
  FACTS_GRAMMARS_LOADED=1
}

# facts_canonical <regex> <constraints> <value> — the model's own definition of
# canonical: the value matches its grammar AND matches none of its constraints
# (R1). A grammar that could not be read is a refusal, not a pass: a validator
# that waves a value through when it cannot check it is not a validator.
facts_canonical() {
  local re="$1" cons="$2" value="$3" c
  [ -n "$re" ] || return 1
  [[ "$value" =~ $re ]] || return 1
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    if [[ "$value" =~ $c ]]; then return 1; fi
  done <<EOF
$cons
EOF
  return 0
}

# facts_now — the instant a source was read, in the model's one timestamp form.
facts_now() { date -u +%FT%TZ 2>/dev/null; }

# facts_unreadable_reason <combined-output> — the closed vocabulary for why a
# source could not be read.
#
# gh reports the status in its message rather than in its exit code, so the
# message is what can be classified. Every branch lands on a token; an
# unrecognised failure is `unreadable`, which still refuses the fact — no
# envelope, a stated reason, never a guess at which failure it was.
#
# Order matters: a 403 carrying a rate-limit message is rate limiting, not a
# permission answer, and reading it as permission-denied would send a caller to
# fix an access problem it does not have.
facts_unreadable_reason() {
  case "$1" in
    *"rate limit"*|*"secondary rate"*|*"HTTP 429"*) printf 'rate-limited' ;;
    *"HTTP 401"*)                                   printf 'permission-denied' ;;
    *"HTTP 403"*)                                   printf 'permission-denied' ;;
    *"HTTP 404"*|*"Not Found"*)                     printf 'not-found' ;;
    *"timeout"*|*"timed out"*|*"deadline exceeded"*|*"i/o timeout"*) printf 'timeout' ;;
    # A body that arrived and could not be decoded is a different fact about the
    # world from a body that never arrived. Reporting it as unreadable would send
    # a caller to check credentials and connectivity that are demonstrably fine.
    *"decoding JSON"*|*"invalid character"*|*"unexpected end of JSON"*|*"jq: error"*|\
    *"parse error"*|*"cannot unmarshal"*)           printf 'malformed' ;;
    *) printf 'unreadable' ;;
  esac
}

# facts_repo_node <locator> — ONE read of the repository node the LOCATOR names.
# Sets FACTS_NODE to "<full_name>\t<default_branch>\t<updated_at>" and returns 0,
# or sets it to the failure output and returns non-zero.
#
# The endpoint and the host are built from the locator, never left to gh to
# resolve. `repos/{owner}/{repo}` is expanded from gh's OWN context — $GH_REPO,
# and its choice among several remotes — which is not necessarily the origin the
# fact names. A compiler that read one repository and emitted a fact about
# another would be wrong in the one way this whole model exists to prevent, and
# it would be wrong silently, because both halves are individually plausible.
# The host matters for the same reason: an Enterprise origin read from
# github.com is an answer about a different repository that happens to share a
# name.
#
# Transport and decoding are different failures and are reported as different
# facts: a body that never arrived is unreadable with its transport reason, and
# a body that arrived and could not be decoded is malformed. They reach that
# separation from both ends — the projection cannot fail on a value's type, and
# the reason vocabulary recognises a decode error — because the one call is
# deliberate. A separate decode step would need a JSON decoder in shipped code,
# which the zero-dependency rule forbids, and a text scan for the key is not a
# substitute: a fork's response carries `parent.full_name`, so a scanner would
# read the parent's identity as this repository's.
#
# One request for three fields is the collection rule (#733): a fan-out of one
# request per field would read the same node three times and could observe it
# in three different states — a conflict manufactured by the reader.
#
# updated_at is the source version. A node id is stable across every change to
# the node, so versioning by it would make a stale fact look current forever;
# the model rules it out explicitly.
#
# There is deliberately no cache here yet. The per-process memo is enabled per
# verb from measurement, and `facts` is not on that list — a verb making one
# read would pay for a scratch directory and save nothing. Reuse arrives with
# the second call site that needs the same observation, measured then; a cache
# with one caller is an optimization that cannot be shown to work.
# The repository node is read ONCE and shared, for the same reason the
# work-unit node is: `repository` and `checks` are two facts about the same
# node, and reading it twice would let them describe it in two different
# states. Before this the counters could not even show the duplication,
# because nothing asked twice.
FACTS_REPO_KEY=""
FACTS_REPO_ROWS=""
FACTS_REPO_RC=0
facts_repo_node() {
  local locator="$1" host="${1%%/*}" nwo="${1#*/}" out rc=0
  if [ -n "$FACTS_REPO_KEY" ] && [ "$FACTS_REPO_KEY" = "$locator" ]; then
    FACTS_CACHE_HITS=$(( FACTS_CACHE_HITS + 1 ))
    FACTS_NODE="$FACTS_REPO_ROWS"
    return "$FACTS_REPO_RC"
  fi
  FACTS_CACHE_MISSES=$(( FACTS_CACHE_MISSES + 1 ))
  FACTS_API_CALLS=$(( FACTS_API_CALLS + 1 ))
  # The projection is TOTAL: any valid JSON produces three fields, and anything
  # that is not a string — an object, an array, a number, a null, or a body that
  # is not an object at all — produces an empty one. A field of the wrong type is
  # then malformed by the check that already exists, instead of erroring here and
  # being reported as a failure to reach GitHub.
  out="$(gh api --hostname "$host" "repos/$nwo" \
    --jq '[.full_name?, .default_branch?, .updated_at?] | map(if type == "string" then . else "" end) | @tsv' 2>&1)" || rc=$?
  FACTS_NODE="$out"
  FACTS_REPO_KEY="$locator"
  FACTS_REPO_ROWS="$out"
  FACTS_REPO_RC="$rc"
  return "$rc"
}

# facts_envelope_tail <locator> <observed_at> <version> — the fields every fact
# of this class carries whatever its status: the node it names as its source,
# when it was read, the one invalidator that makes it stale, and that token's
# observed version. Spelled once so a status cannot quietly carry a different
# freshness contract from its siblings (R17, R20).
facts_envelope_tail() {
  local locator="$1" observed="$2" version="$3" inv esc ver
  inv="repository:$locator"
  esc="$(json_escape "$inv")"
  ver="$(json_escape "$version")"
  printf ',"source":{"type":"github-api","identity":"%s","version":"%s"}' \
    "$(json_escape "$locator")" "$ver"
  printf ',"observed_at":"%s","invalidators":["%s"],"versions":{"%s":"%s"}' \
    "$observed" "$esc" "$esc" "$ver"
  printf ',"provenance":"%s"' "$(json_escape "https://$locator")"
}

# facts_repository_fact <locator> <observed_at> — sets FACTS_JSON to the
# repository.identity fact, whatever the outcome. There is always exactly one
# fact for the class; what varies is its status, never whether it was emitted.
#
# The instant is passed in, already validated. Every status carries observed_at,
# so checking it here would mean checking it on each branch — and the branch that
# reports a failed read is exactly the one that would be forgotten.
#
# The identity is the repository the local remote names, canonicalized by
# repository.sh. The node read then says what GitHub currently calls it. When
# those disagree the fact is a CONFLICT naming both candidates (R8): a rename or
# a redirect is exactly the case where picking one would be the compiler
# inventing precedence the model does not define.
facts_repository_fact() {
  local locator="$1" observed="$2" rc=0 head tail
  facts_repo_node "$locator" || rc=$?
  head='{"schema_version":'"$FACTS_SCHEMA_VERSION"',"key":"repository.identity","class":"repository","status":'
  FACTS_JSON=""
  FACTS_REFUSED=""

  # No read, no observed version, and therefore no fact this schema can carry.
  #
  # An UNKNOWN is still a full envelope: it names the node it depends on as an
  # invalidator and records the version observed for that node, which is how
  # freshness is decided. For this class that version form is the node's own
  # updated_at — precisely what a failed read denies. An empty string is not a
  # version, and the observation instant is not one either: writing it would
  # fabricate evidence in the field whose only job is to say what was seen.
  #
  # So the fact is refused rather than emitted invalid. The failure is still
  # reported, with its reason, by the caller; what is not done is dress it as a
  # conforming fact.
  if [ "$rc" -ne 0 ]; then
    FACTS_REFUSED="$(facts_unreadable_reason "$FACTS_NODE")"
    return 3
  fi

  local full branch updated
  full="$(printf '%s' "$FACTS_NODE" | awk -F'\t' 'NR == 1 { print $1 }')"
  branch="$(printf '%s' "$FACTS_NODE" | awk -F'\t' 'NR == 1 { print $2 }')"
  updated="$(printf '%s' "$FACTS_NODE" | awk -F'\t' 'NR == 1 { print $3 }')"

  facts_load_grammars

  # The version is checked first and on its own, because it decides whether any
  # envelope can be built at all. Every other field's failure is reportable
  # inside a conforming fact; this one is not.
  if [ -z "$updated" ] || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$updated"; then
    FACTS_REFUSED="malformed"
    return 3
  fi

  # From here the node's observed version is known, so an envelope conforms and
  # every remaining problem can be stated inside one.
  tail="$(facts_envelope_tail "$locator" "$observed" "$updated")"

  # A field being PRESENT does not make it canonical. A full_name outside the
  # repository grammar would become an identity; a branch outside the ref grammar
  # would become a default branch Git could not name. Either would be an
  # ESTABLISHED fact violating the schema it declares conformance to, which is
  # worse than an unknown, because a consumer is entitled to act on what is
  # established. This UNKNOWN is schema-valid: the node was read, so its version
  # is recorded, and only the value is missing (R6).
  local host="${locator%%/*}" nwo="${locator#*/}"
  if [ -z "$full" ] || [ -z "$branch" ] \
     || ! facts_canonical "$FACTS_RE_REF" "$FACTS_CON_REF" "$branch" \
     || ! facts_canonical "$FACTS_RE_REPOSITORY" "$FACTS_CON_REPOSITORY" "$host/${full,,}"; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    FACTS_JSON="$head"'"UNKNOWN"'"$tail"',"detail":{"reason":"malformed","candidates":[]}}'
    return 0
  fi

  # GitHub compares owner and name case-insensitively, and so does the locator
  # now, so a case difference is not a disagreement. A different name is.
  if [ "${full,,}" != "$nwo" ]; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_JSON="$head"'"CONFLICT"'"$tail"',"detail":{"reason":"the repository names itself differently","candidates":["'"$(json_escape "$locator")"'","'"$(json_escape "$host/${full,,}")"'"]}}'
    return 0
  fi

  FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
  FACTS_JSON="$head"'"ESTABLISHED","value":{"id":"'"$(json_escape "$locator")"'","default_branch":"'"$(json_escape "$branch")"'"}'"$tail"'}'
}

# facts_state_canonical <github state> — the model's vocabulary, not GitHub's.
#
# GitHub answers OPEN/CLOSED through GraphQL and open/closed through REST, and
# the runtime has carried all three spellings plus an UNKNOWN in different
# readers. The model admits exactly open|closed, so the translation happens once,
# here, and anything outside the pair is refused rather than lower-cased and
# hoped for — that is the residual ambiguity acceptance item 7 names.
facts_state_canonical() {
  case "$1" in
    OPEN|open)     printf 'open' ;;
    CLOSED|closed) printf 'closed' ;;
    *)             return 1 ;;
  esac
}

# facts_graph_entry <locator-host> <number> <state> <nwo> <typename> — one
# relationship entry as JSON, then its canonical work-unit locator and its kind,
# tab-separated. Returns non-zero when the node cannot be named canonically, so
# the caller refuses rather than emitting a locator outside the grammar.
#
# Identity and kind are returned apart because they are different things. The
# work unit IS the locator; the kind is something observed about it. Keying
# identity by `<kind>:<locator>` would make one work unit returned as an issue
# and as a pull request look like two nodes — and two contradictory kinds would
# both survive, which is exactly what "one node, one state" forbids.
# facts_unit_kind <__typename> — the model's kind vocabulary, not GraphQL's.
#
# Extracted because two classes now decide it and a second copy is how the two
# would drift: `work_unit` reports the kind as its own value while `graph`
# reports it per relationship, but "what GitHub calls this node" is one
# question with one answer. Anything outside the pair is refused rather than
# lower-cased, for the same reason facts_state_canonical refuses.
facts_unit_kind() {
  case "$1" in
    Issue)       printf 'issue' ;;
    PullRequest) printf 'pull_request' ;;
    *)           return 1 ;;
  esac
}

# facts_unit_locator <host> <owner/name> <number> — the canonical work-unit
# locator, or non-zero when the three parts do not compose one.
#
# The lower-casing is GitHub's own comparison rule for owner and name, applied
# in the one place that builds this identity so a node returned with different
# casing is not mistaken for a different work unit.
facts_unit_locator() {
  local wu
  wu="$(printf '%s/%s#%s' "$1" "${2,,}" "$3")"
  facts_canonical "$FACTS_RE_WORK_UNIT" "$FACTS_CON_WORK_UNIT" "$wu" || return 1
  printf '%s' "$wu"
}

facts_graph_entry() {
  local host="$1" number="$2" state="$3" nwo="$4" typename="$5" wu kind st
  kind="$(facts_unit_kind "$typename")" || return 1
  st="$(facts_state_canonical "$state")" || return 1
  wu="$(facts_unit_locator "$host" "$nwo" "$number")" || return 1
  printf '{"kind":"%s","id":"%s","state":"%s"}\t%s\t%s' \
    "$kind" "$(json_escape "$wu")" "$st" "$wu" "$kind"
}

# facts_graph_fact <locator> <number> <observed_at> — sets FACTS_JSON to the
# graph.native fact, or FACTS_REFUSED when no conforming fact can be built.
#
# The statuses, and what decides them:
#
#   ESTABLISHED  the whole relationship set was read, every node named
#                canonically, every state in the model's vocabulary;
#   UNKNOWN      a list was truncated. The node's own version WAS observed, so
#                the envelope conforms; what is missing is the value, and a
#                bounded read is an unknown rather than a shorter graph;
#   refused      the read failed, the work unit is absent, or a node cannot be
#                named or its state canonicalized — no observed version, or no
#                canonical representation, so no fact.
facts_graph_fact() {
  local locator="$1" number="$2" observed="$3" rc=0 host="${1%%/*}"
  local wu="$locator#$number"
  FACTS_JSON=""
  FACTS_REFUSED=""
  facts_load_grammars

  facts_canonical "$FACTS_RE_WORK_UNIT" "$FACTS_CON_WORK_UNIT" "$wu" || {
    FACTS_REFUSED="the work unit cannot be named canonically"; return 3; }

  facts_unit_read "$locator" "$number" || {
    FACTS_REFUSED="$(facts_unreadable_reason "$FACTS_NODE")"; return 3; }

  case "$FACTS_NODE" in
    absent*)
      # Nothing by that number in this repository at all. One request now
      # answers what used to need a second: `issueOrPullRequest` returns a pull
      # request as DATA carrying its own __typename, so "that is a pull request"
      # is read off the same observation instead of probed for afterwards. What
      # reaches here is genuine absence — no node, so no observed version and no
      # envelope that could carry it.
      FACTS_REFUSED="no work unit by that number"; return 3 ;;
    # A reply that carried errors, or one whose relationship structures were
    # missing, was not a reading of this graph. Compiling it would state that
    # the work unit has no relationships, which is a different fact from not
    # having been able to see them.
    errored*) FACTS_REFUSED="malformed"; return 3 ;;
    partial*) FACTS_REFUSED="malformed"; return 3 ;;
  esac

  # `none` in a value shape is the model's literal for "no such relationship",
  # and its own next_action example writes it as a JSON string. A bare token
  # would not parse at all, which is a fact nobody can read.
  # Truncation is decided BEFORE the relationships are walked. An UNKNOWN graph
  # represents none of them, so it must list none of them as invalidators (R17);
  # accumulating the partial page's nodes first and discarding them afterwards
  # invites exactly the bug where the fact denies knowing the set and still
  # claims a freshness contract over part of it.
  # Every incomplete list, not the first one: a fact that says what it could not
  # see must say all of it.
  local truncated
  truncated="$(printf '%s' "$FACTS_NODE" | awk -F'\t' \
    '$1 == "truncated" && ($2 == "children" || $2 == "blockers") { print $2 }' \
    | sort -u | tr '\n' ' ')"
  truncated="${truncated% }"

  # Membership is per list and identity is global, which are different rules.
  #
  # The model has a work unit appear at most once IN EACH list, and a node can
  # legitimately be both a child and a blocker — so tracking uniqueness across
  # the lists silently dropped a real edge. What must be unique globally is the
  # node's invalidator and its observed version: one node has one version, and a
  # node reported twice with different states or versions is refused rather
  # than reconciled by preferring one.
  local self_version parent='"none"' kids="" blocks=""
  local seen_parent="" seen_child="" seen_blocker="" known=""
  local inv="issue:$wu" vers="" kind line f1 f2 f3 f4 f5 f6 entry tok rel_wu rel_kind
  # The node returned must be the node asked for. Without this a response naming
  # a different issue would compile that issue's version and relationships under
  # this work unit's identity — one node wearing another's name, which is the
  # failure the identity discipline exists to prevent.
  # A pull request HAS no native graph — the schema gives parent, subIssues and
  # blockedBy to Issue alone — and the model offers no conforming fact to say
  # so: graph admits ESTABLISHED, UNKNOWN and CONFLICT, and NOT_APPLICABLE
  # belongs to the HEAD-bound classes. So this is a refusal with an accurate
  # reason, now read from the shared observation rather than a second request.
  #
  # Stated positively: this class needs an ISSUE, so anything else is refused by
  # what it is rather than by a list of what it is not. Naming only the pull
  # request left every other kind to fall through and establish an empty graph.
  local self_kind
  self_kind="$(printf '%s' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $5; exit }')"
  if [ "$self_kind" = "PullRequest" ]; then
    FACTS_REFUSED="a pull request has no native graph"
    return 3
  elif [ "$self_kind" != "Issue" ]; then
    FACTS_REFUSED="malformed"
    return 3
  fi

  local self_number self_repo
  self_number="$(printf '%s' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $2; exit }')"
  self_repo="$(printf '%s' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $3; exit }')"
  # Both halves of the identity, because checking the number alone leaves the
  # repository assumed — and a reply from another repository would then have its
  # issue's version and relationships bound to this repository's name.
  if [ "$self_number" != "$number" ] || [ "$host/${self_repo,,}" != "$locator" ]; then
    FACTS_REFUSED="malformed"
    return 3
  fi
  self_version="$(printf '%s' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $4; exit }')"
  if [ -z "$self_version" ] || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$self_version"; then
    FACTS_REFUSED="malformed"
    return 3
  fi
  vers='"'"$(json_escape "$inv")"'":"'"$(json_escape "$self_version")"'"'
  # The root is inside the identity tracking, not beside it. Without this a
  # relation naming the root would append its invalidator a second time and
  # write the same key into `versions` twice — an object with one key twice,
  # which is not a conforming fact at all.
  known=" $wu=ROOT@$self_version"

  # Every returned row is walked and validated, whatever the truncation state: a
  # node the reply DID return is a node it claimed, and a malformed claim makes
  # the reply malformed. What truncation changes is representation, not
  # validation — a partial reading may not contribute to the value, the
  # invalidators or the versions, because the fact would then assert a freshness
  # contract over a set it admits it could not see.
  while IFS=$'\t' read -r f1 f2 f3 f4 f5 f6; do
    [ -n "$f1" ] || continue
    case "$f1" in
      self|truncated) continue ;;
      parent|child|blocker)
        entry="$(facts_graph_entry "$host" "$f2" "$f3" "$f5" "$f6")" || {
          FACTS_REFUSED="malformed"; return 3; }
        rel_kind="${entry##*$'\t'}"
        entry="${entry%$'\t'*}"; rel_wu="${entry##*$'\t'}"; entry="${entry%$'\t'*}"
        tok="$rel_kind:$rel_wu"
        if ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$f4"; then
          FACTS_REFUSED="malformed"; return 3
        fi

        # A work unit is not its own parent, child or blocker. A reply saying so
        # is malformed, and treating it as a relationship would make the fact
        # name the same node twice with two roles.
        if [ "$rel_wu" = "$wu" ]; then
          FACTS_REFUSED="malformed"; return 3
        fi

        # Identity is the work unit; kind and state are observed about it. So a
        # node reported twice consistently is one node in two relationships,
        # while one reported with two kinds, two states or two versions has no
        # representation in this schema and is refused rather than reconciled.
        case " $known " in
          *" $rel_wu=$entry@$f4 "*) ;;
          *" $rel_wu="*) FACTS_REFUSED="malformed"; return 3 ;;
          *) known="$known $rel_wu=$entry@$f4"
             # The identity is remembered so a later contradiction is still
             # caught, but a truncated reading contributes nothing a consumer
             # could act on.
             if [ -z "$truncated" ]; then
               vers="$vers,\"$(json_escape "$tok")\":\"$(json_escape "$f4")\""
               inv="$inv $tok"
             fi ;;
        esac

        # Validated; and represented only when the whole set was returned.
        [ -z "$truncated" ] || continue

        # Membership is then per list, keyed by the work unit, so a node that is
        # both a child and a blocker appears in both — one edge is not a
        # duplicate of the other.
        case "$f1" in
          parent)
            case " $seen_parent " in *" $rel_wu "*) continue ;; esac
            seen_parent="$seen_parent $rel_wu"; parent="$entry" ;;
          child)
            case " $seen_child " in *" $rel_wu "*) continue ;; esac
            seen_child="$seen_child $rel_wu"; kids="${kids:+$kids,}$entry" ;;
          blocker)
            case " $seen_blocker " in *" $rel_wu "*) continue ;; esac
            seen_blocker="$seen_blocker $rel_wu"; blocks="${blocks:+$blocks,}$entry" ;;
        esac ;;
    esac
  done <<EOF
$FACTS_NODE
EOF

  local inv_json="" t
  for t in $inv; do inv_json="${inv_json:+$inv_json,}\"$(json_escape "$t")\""; done

  local head tail
  head='{"schema_version":'"$FACTS_SCHEMA_VERSION"',"key":"graph.native","class":"graph","status":'
  tail=',"source":{"type":"github-api","identity":"'"$(json_escape "$wu")"'","version":"'"$(json_escape "$self_version")"'"}'
  tail="$tail"',"observed_at":"'"$observed"'","invalidators":['"$inv_json"'],"versions":{'"$vers"'}'
  tail="$tail"',"provenance":"'"$(json_escape "https://$locator/issues/$number")"'"'

  FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
  if [ -n "$truncated" ]; then
    # The relationships this fact would describe were not all returned, so it
    # describes none of them. The node's version is recorded, so a later read
    # can tell whether anything changed since the truncation.
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    local which
    case "$truncated" in
      *" "*) which="the ${truncated% *} and ${truncated##* } lists were truncated" ;;
      *)     which="the $truncated list was truncated" ;;
    esac
    FACTS_JSON="$head"'"UNKNOWN"'"$tail"',"detail":{"reason":"'"$(json_escape "$which")"'","candidates":[]}}'
    return 0
  fi
  FACTS_JSON="$head"'"ESTABLISHED","value":{"parent":'"$parent"',"children":['"$kids"'],"blocked_by":['"$blocks"']}'"$tail"'}'
}

# facts_error_absent <response body> — true when the reply carries a GraphQL
# error that is itself a NOT_FOUND at the node this query asked for, AND the
# enclosing shape confirms it: `.data.repository` is present and its
# `issueOrPullRequest` key is explicitly null.
#
# This is PARSED, not pattern-matched, and the reason is a reply that is valid
# and still contains both tokens in the wrong places:
#
#   {"type":"NOT_FOUND","path":["repository","milestone"],
#    "extensions":{"path":["repository","issueOrPullRequest"]}}
#
# Text matching cannot tell a top-level `path` from one nested under
# `extensions`, and splitting on object boundaries splits nested objects too —
# so that error, which is about a milestone, read as this work unit's absence.
# Only a parser can say that ONE error object has BOTH `.type == "NOT_FOUND"`
# and its own `.path` equal to the node's.
#
# The error alone is not enough, either. GraphQL returns partial `data`
# alongside `errors`, so a reply can carry a NOT_FOUND at this node's path
# while `data.repository.issueOrPullRequest` is a non-null node — the two
# halves of the same reply disagreeing about whether the node exists. That is
# contradictory evidence, not a reading of the world, and reporting it as
# absence would send a caller to create something the same reply just
# described. Absence is the ERROR paired with the null the schema promises for
# it, never the error alone.
#
# Zero runtime dependencies still holds: with no parser available this returns
# false, so no absence is established and the failure keeps its own reason.
# That is the safe direction — absence is a claim about the world, and the cost
# of not making it is a less specific reason, while the cost of making it
# wrongly is sending a caller to create something that already exists.
facts_error_absent() {
  local body="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$body" | jq -e '
      (type == "object") and (.errors | type == "array")
      and any(.errors[]; (type == "object")
              and (.type == "NOT_FOUND")
              and (.path == ["repository", "issueOrPullRequest"]))
      and ((.data | type) == "object")
      and ((.data.repository | type) == "object")
      and (.data.repository | has("issueOrPullRequest"))
      and (.data.repository.issueOrPullRequest == null)' >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$body" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not isinstance(d, dict):
    sys.exit(1)
errs = d.get("errors")
if not isinstance(errs, list):
    sys.exit(1)
want = ["repository", "issueOrPullRequest"]
if not any(
    isinstance(e, dict) and e.get("type") == "NOT_FOUND" and e.get("path") == want
    for e in errs):
    sys.exit(1)
data = d.get("data")
if not isinstance(data, dict):
    sys.exit(1)
repo = data.get("repository")
if not isinstance(repo, dict):
    sys.exit(1)
if "issueOrPullRequest" not in repo:
    sys.exit(1)
sys.exit(0 if repo["issueOrPullRequest"] is None else 1)
' >/dev/null 2>&1
  else
    return 1
  fi
}

# facts_unit_node <locator> <number> — ONE read of a work unit's OWN identity.
#
# `issueOrPullRequest` answers for both kinds in a single request, which is why
# this class can tell them apart where `graph` cannot: `parent`, `subIssues` and
# `blockedBy` belong to Issue alone, so asking for both kinds there made a
# legitimately-absent alternative a NOT_FOUND error and refused every issue's
# graph. Nothing this class reads is Issue-only, so one request is enough and
# the kind arrives as data rather than as a second probe.
#
# `closingIssuesReferences` is what GitHub means by "this pull request closes
# that issue" — the declared relationship R17 requires before a fact read from
# an issue may be bound to a pull request's work unit. Prose in a PR body does
# not create it. The list is BOUNDED at 100 and its truncation is reported,
# because a subset of the closing references is not a shorter `implements`: it
# is not knowing which issue the pull request implements.
#
# Rows: "self <number> <owner/name> <updatedAt> <typename>", then
# "truncated implements" when the reference list was cut, then
# "implements <number> <owner/name> <typename>" per closing reference.
facts_unit_node() {
  local locator="$1" number="$2" host="${1%%/*}" nwo="${1#*/}" out rc=0
  FACTS_API_CALLS=$(( FACTS_API_CALLS + 1 ))
  # stdout and stderr are captured SEPARATELY. Merging them put gh's diagnostic
  # line inside the JSON body, so the body a parser needs was not parseable —
  # and the classification below could only ever have been text matching.
  local errfile err=""
  errfile="$(mktemp "${TMPDIR:-/tmp}/spark-facts.XXXXXX")" || {
    FACTS_NODE="could not create a temp file"; return 1; }
  out="$(gh api graphql --hostname "$host" \
    -F owner="${nwo%%/*}" -F name="${nwo##*/}" -F number="$number" -f query='
    query($owner:String!,$name:String!,$number:Int!){
      repository(owner:$owner,name:$name){
        issueOrPullRequest(number:$number){
          __typename
          ... on Issue {
            number updatedAt repository{ nameWithOwner }
            milestone{ number updatedAt }
            parent{ __typename number state updatedAt repository{ nameWithOwner } }
            subIssues(first:100){ pageInfo{ hasNextPage } nodes{ __typename number state updatedAt repository{ nameWithOwner } } }
            blockedBy(first:100){ pageInfo{ hasNextPage } nodes{ __typename number state updatedAt repository{ nameWithOwner } } }
          }
          ... on PullRequest {
            number updatedAt repository{ nameWithOwner }
            milestone{ number updatedAt }
            headRefOid baseRefName baseRefOid
            baseRef{ target{ oid } }
            commits(last:1){ nodes{ commit{ oid statusCheckRollup{
              contexts(first:100){ pageInfo{ hasNextPage } nodes{
                __typename
                ... on CheckRun { name conclusion status checkSuite{ app{ databaseId } } }
                ... on StatusContext { context state }
              } }
            } } } }
            comments(last:100){
              pageInfo{ hasPreviousPage }
              nodes{ databaseId updatedAt author{ login } body }
            }
            closingIssuesReferences(first:100){
              pageInfo{ hasNextPage }
              nodes{ __typename number repository{ nameWithOwner } }
            }
          }
        }
      }
    }' --jq '
    # Ordered outside-in, exactly as the graph projection is: jq raises on
    # reaching into a scalar, and that error would arrive as a source-read
    # failure rather than the malformed refusal this path documents.
    def obj: type == "object";
    def whole:
      obj
      and (.number | type) == "number" and (.number == (.number | floor))
      and (.updatedAt | type) == "string"
      and (.__typename | type) == "string"
      and (.repository | obj) and (.repository.nameWithOwner | type) == "string";
    # A closing reference needs an identity and a kind, and no version of its
    # own: `implements` is a declared relationship this work unit carries, and
    # the node it names is not an invalidator of this fact.
    #
    # The kind is required to be exactly `Issue`, not merely a string. A pull
    # request cannot close a pull request, so any other kind is a reply this
    # class cannot read — and accepting the string here let a malformed
    # reference through the projection and reach a caller that had already
    # decided the fact was bounded.
    def ref_ok:
      obj
      and (.number | type) == "number" and (.number == (.number | floor))
      and (.__typename == "Issue")
      and (.repository | obj) and (.repository.nameWithOwner | type) == "string";
    # A milestone carries an identity and nothing else this fact reads: its
    # title is a name, never an identity, which is precisely the distinction
    # the placement ruling turns on. `none` is a real answer here — GitHub
    # saying the work unit carries no milestone is authoritative — so the key
    # must be PRESENT and either null or whole. A reply that omits it has not
    # said the work unit has no milestone, and silence is not that answer.
    def ms_ok:
      obj
      and (.number | type) == "number" and (.number == (.number | floor))
      and (.updatedAt | type) == "string";
    # The HEAD half of the same observation. `base` is the TARGET commit of the
    # base branch, not the commit the pull request was opened against: R20
    # makes value.base the version of the `ref:` invalidator, so the two must
    # be one commit or the freshness contract compares a version against
    # something it does not name.
    #
    # `baseRef` may be null — a base branch can be deleted while the pull
    # request survives — and that is a fact about the branch rather than a
    # malformed reply, so the key must be present and either null or whole.
    # (No apostrophes below: this whole projection is one single-quoted shell
    # string, and one would end it.)
    def head_ok:
      (.headRefOid | type) == "string"
      and (.baseRefName | type) == "string"
      and (.baseRefOid | type) == "string"
      and has("baseRef")
      and ((.baseRef == null)
           or ((.baseRef | obj) and (.baseRef.target | obj)
               and (.baseRef.target.oid | type) == "string"));
    # The check half, read off the SAME pull request rather than by asking for
    # the commit again. `statusCheckRollup` is null when nothing has reported,
    # which is a real answer (no run observed) and not a malformed reply, so it
    # must be present and either null or whole.
    #
    # A context is one of two shapes and each must carry its own fields: a
    # CheckRun has a name, a status and a conclusion that is null until it
    # completes; a StatusContext has a context and a state.
    def ctx_ok:
      obj
      and (if .__typename == "CheckRun"
           then (.name | type) == "string" and (.status | type) == "string"
                and (has("conclusion"))
                # A run may legitimately have no suite and a suite no app — a
                # status posted by a user is not produced by an installation.
                # What is not admissible is an app whose id is not a number,
                # because that id is what a requirement binds to.
                and ((.checkSuite == null)
                     or (((.checkSuite | type) == "object")
                         and ((.checkSuite.app == null)
                              or (((.checkSuite.app | type) == "object")
                                  and ((.checkSuite.app.databaseId | type) == "number")))))
           elif .__typename == "StatusContext"
           then (.context | type) == "string" and (.state | type) == "string"
           else false end);
    def rollup_ok:
      obj and (.contexts | obj)
      and (.contexts.pageInfo | obj)
      and (.contexts.pageInfo.hasNextPage | type) == "boolean"
      and (.contexts.nodes | type) == "array"
      and ([.contexts.nodes[] | ctx_ok] | all);
    # EXACTLY one, not at most one. `commits(last:1)` on a pull request always
    # answers with its head commit, so an empty array is not a pull request
    # with no commits, it is a reply that did not carry the observation. Left
    # admissible it binds nothing to the head, every required check reads
    # `missing`, and the fact ESTABLISHES that state of affairs from no
    # evidence at all.
    def commits_ok:
      obj and (.nodes | type) == "array" and ((.nodes | length) == 1)
      and ([.nodes[] | obj and (.commit | obj) and (.commit.oid | type) == "string"
            and has("commit") and (.commit | has("statusCheckRollup"))
            and ((.commit.statusCheckRollup == null)
                 or (.commit.statusCheckRollup | rollup_ok))] | all);
    # A comment carries the verdict, so its identity and its instant matter as
    # much as its text: an id that is not a number names nothing, and a record
    # with no updatedAt cannot be versioned, so an edit to it could never make
    # the fact stale. `author` is null for a deleted account, which is a
    # readable comment by nobody — not a malformed one.
    def comment_ok:
      obj and (.databaseId | type) == "number"
      and (.updatedAt | type) == "string"
      and (.body | type) == "string"
      and ((.author == null) or (((.author | type) == "object")
                                 and ((.author.login | type) == "string")));
    def comments_ok:
      obj and (.nodes | type) == "array"
      and (.pageInfo | obj) and (.pageInfo.hasPreviousPage | type) == "boolean"
      and ([.nodes[] | comment_ok] | all);
    def closing_ok:
      obj and (.nodes | type) == "array"
      and (.pageInfo | obj) and (.pageInfo.hasNextPage | type) == "boolean"
      and ([.nodes[] | ref_ok] | all);
    # A relationship node is held to the same standard as the root, and also
    # carries a state: this is the graph half of the same observation.
    def relation_ok: whole and (.state | type) == "string";
    def list_ok:
      obj and (.nodes | type) == "array"
      and (.pageInfo | obj) and (.pageInfo.hasNextPage | type) == "boolean"
      and ([.nodes[] | relation_ok] | all);
    # Each kind must carry ITS OWN fields whole, and must not be required to
    # carry those of the other kind: the fragments never ask an issue for closing
    # references or a pull request for a native graph, so requiring either of
    # both would make every node of the other kind malformed.
    #
    # `parent` must be present and either absent-as-null or a whole relation: a
    # reply that omits it has not said the work unit has no parent.
    #
    # An unrecognised kind is NOT passed through. `else true` let a Discussion
    # node satisfy the projection carrying only a self row, and a self row with
    # no relationship rows is indistinguishable from an issue with no
    # relationships — so the graph class established an empty graph for a node
    # that has none because it is not a work unit at all.
    def root_ok:
      whole
      and has("milestone") and ((.milestone == null) or (.milestone | ms_ok))
      and (if .__typename == "PullRequest"
           then head_ok and (.commits | commits_ok)
                and has("comments") and (.comments | comments_ok)
                and has("closingIssuesReferences") and (.closingIssuesReferences | closing_ok)
           elif .__typename == "Issue"
           then has("parent") and ((.parent == null) or (.parent | relation_ok))
                and (.subIssues | list_ok) and (.blockedBy | list_ok)
           else false end);
    if (obj | not) then (["partial"] | @tsv)
    elif has("errors") then (["errored"] | @tsv)
    elif (.data | obj | not) then (["partial"] | @tsv)
    elif (.data.repository | obj | not) then (["partial"] | @tsv)
    elif (.data.repository | has("issueOrPullRequest") | not) then (["partial"] | @tsv)
    elif .data.repository.issueOrPullRequest == null then (["absent"] | @tsv)
    elif (.data.repository.issueOrPullRequest | root_ok | not) then (["partial"] | @tsv)
    else
      .data.repository.issueOrPullRequest as $u
      |
        (["self", ($u.number | tostring), $u.repository.nameWithOwner,
          $u.updatedAt, $u.__typename] | @tsv),
        (if $u.milestone != null then
           ["milestone", ($u.milestone.number | tostring), $u.repository.nameWithOwner,
            $u.milestone.updatedAt] | @tsv
         else empty end),
        (if $u.__typename == "PullRequest" then
           (["head", $u.headRefOid, $u.baseRefName, $u.baseRefOid,
             (if $u.baseRef == null then "" else $u.baseRef.target.oid end)] | @tsv),
           ($u.commits.nodes[] | ["rollup_commit", .commit.oid,
             (if .commit.statusCheckRollup == null then "none" else "some" end)] | @tsv),
           (if (($u.commits.nodes | length) > 0)
                and ($u.commits.nodes[0].commit.statusCheckRollup != null)
                and $u.commits.nodes[0].commit.statusCheckRollup.contexts.pageInfo.hasNextPage
            then ["truncated", "checks"] | @tsv else empty end),
           ($u.commits.nodes[]? | .commit.statusCheckRollup?.contexts.nodes[]?
             | if .__typename == "CheckRun"
               then ["check", .name, (.conclusion // ""), .status,
                     (if (.checkSuite != null) and (.checkSuite.app != null)
                      then (.checkSuite.app.databaseId | tostring) else "" end)]
               else ["check", .context, .state, "STATUS_CONTEXT", ""] end | @tsv),
           (if $u.comments.pageInfo.hasPreviousPage
            then ["truncated", "comments"] | @tsv else empty end),
           # Only the marker is carried out of a comment. A body is arbitrary
           # prose and can be enormous; what decides this fact is the machine
           # marker the reviewer lane writes, and it must be at the START of
           # the body. A marker quoted inside another comment is a quotation
           # of a verdict, never a verdict. (No apostrophes in this jq program:
           # it is a single-quoted shell string and one would close it.)
           ($u.comments.nodes[]
             | . as $c
             | ($c.body | capture("^<!-- spark-openai-review pr=(?<pr>[1-9][0-9]*) head=(?<head>[0-9a-f]{40}) verdict=(?<verdict>PASS|CHANGES REQUIRED|DECISION REQUIRED|NOT ASSESSED) -->")?)
             | select(. != null)
             | select(.pr == ($u.number | tostring))
             | ["verdict", ($c.databaseId | tostring), $c.updatedAt,
                (if $c.author == null then "" else $c.author.login end),
                .head, .verdict] | @tsv),
           (if $u.closingIssuesReferences.pageInfo.hasNextPage
            then ["truncated", "implements"] | @tsv else empty end),
           ($u.closingIssuesReferences.nodes[]
             | ["implements", (.number|tostring), .repository.nameWithOwner, .__typename] | @tsv)
         elif $u.__typename == "Issue" then
           (if $u.parent != null then
              ["parent", ($u.parent.number|tostring), $u.parent.state, $u.parent.updatedAt,
               $u.parent.repository.nameWithOwner, $u.parent.__typename] | @tsv
            else empty end),
           (if $u.subIssues.pageInfo.hasNextPage then ["truncated", "children"] | @tsv else empty end),
           ($u.subIssues.nodes[] | ["child", (.number|tostring), .state, .updatedAt,
                                    .repository.nameWithOwner, .__typename] | @tsv),
           (if $u.blockedBy.pageInfo.hasNextPage then ["truncated", "blockers"] | @tsv else empty end),
           ($u.blockedBy.nodes[] | ["blocker", (.number|tostring), .state, .updatedAt,
                                    .repository.nameWithOwner, .__typename] | @tsv)
         else empty end)
    end' 2>"$errfile")" || rc=$?
  err="$(cat "$errfile" 2>/dev/null)"
  rm -f "$errfile"
  # A work unit that does not exist is not a transport failure, and GraphQL
  # reports it as an error with a non-zero exit. Without this the absent path is
  # unreachable and a missing work unit reads as an unreadable source, sending a
  # caller to check access it already has.
  #
  # The structured errors ARE reachable. When a GraphQL reply carries an
  # `errors` array, gh ignores `--jq` entirely and writes the RAW response body
  # to stdout (the message goes to stderr, and it exits non-zero) — so the
  # projection above never ran, but the typed errors are right here.
  #
  # What decides absence is the error's own PATH. The query asks for exactly one
  # node, at `repository.issueOrPullRequest`, so a NOT_FOUND reported at that
  # path is GitHub saying the node this request asked for does not exist.
  # Nothing is read out of the sentence, which is what five rounds of matching
  # on it kept getting wrong:
  #
  #   * a glob on the number had no digit boundary, so 73 matched 733;
  #   * stripping to the first occurrence made the answer order-dependent;
  #   * requiring the named numbers to be exactly the one requested rejected a
  #     reply that legitimately named another node;
  #   * every number-based rule accepted the wrong ENTITY, so a milestone
  #     NOT_FOUND naming this number read as this work unit's absence;
  #   * and token matching on the structured fields could not tell a top-level
  #     `path` from one nested under `extensions`.
  #
  # The last of those is why this is parsed rather than matched: only a parser
  # can require that ONE error object carries both facts itself.
  if [ "$rc" -ne 0 ]; then
    if facts_error_absent "$out"; then
      FACTS_NODE="absent"; return 0
    fi
    # The reason is what gh SAID, which is now separate from the body it
    # printed, so a JSON payload can never be classified as a diagnostic.
    FACTS_NODE="$err"
    return "$rc"
  fi
  FACTS_NODE="$out"
  return "$rc"
}

# facts_unit_read <locator> <number> — ONE observation of a work-unit node,
# shared by every class derived from it.
#
# work_unit and graph are two facts about the SAME node, and reading it twice
# would let them describe it in two different states — the defect this whole
# compiler exists to prevent, reintroduced one level up. So the read happens
# once and both classes consume the same rows, which is also what makes the
# cache counters mean something: before this, hits and misses were always zero
# because nothing ever asked twice.
#
# The memo is keyed by the repository AND the number. Keying it by the number
# alone would answer for one repository with another repository's node, which is
# the trap recorded on the packet plan.
FACTS_UNIT_KEY=""
FACTS_UNIT_ROWS=""
FACTS_UNIT_RC=0
facts_unit_read() {
  local key="$1#$2" rc=0
  if [ -n "$FACTS_UNIT_KEY" ] && [ "$FACTS_UNIT_KEY" = "$key" ]; then
    FACTS_CACHE_HITS=$(( FACTS_CACHE_HITS + 1 ))
    FACTS_NODE="$FACTS_UNIT_ROWS"
    return "$FACTS_UNIT_RC"
  fi
  FACTS_CACHE_MISSES=$(( FACTS_CACHE_MISSES + 1 ))
  facts_unit_node "$1" "$2" || rc=$?
  FACTS_UNIT_KEY="$key"
  FACTS_UNIT_ROWS="$FACTS_NODE"
  FACTS_UNIT_RC="$rc"
  return "$rc"
}

# facts_work_unit_fact <locator> <number> <observed_at> — sets FACTS_JSON to the
# work_unit.identity fact, or FACTS_REFUSED when no conforming fact exists.
#
# The statuses, and what decides them:
#
#   ESTABLISHED  the node was read, named canonically, its kind is in the
#                model's vocabulary, and `implements` is settled — `none` for an
#                issue or a pull request that closes nothing, or the one issue
#                it closes;
#   UNKNOWN      the closing-reference list was truncated. The node's own
#                version WAS observed, so the envelope conforms; what is missing
#                is the value, and a bounded read is an unknown rather than a
#                shorter answer (R6);
#   CONFLICT     the pull request declares more than one closing issue. The
#                model gives `implements` one work unit, so two authoritative
#                references disagree about which issue this unit implements and
#                both are named — no first-write or plausibility rule picks one
#                (R8);
#   refused      the read failed, the node is absent, or it cannot be named
#                canonically — no observed version, so no envelope.
facts_work_unit_fact() {
  local locator="$1" number="$2" observed="$3" host="${1%%/*}"
  local wu head tail inv kind self_version self_num self_nwo self_type
  FACTS_JSON=""
  FACTS_REFUSED=""
  facts_load_grammars

  wu="$(facts_unit_locator "$host" "${locator#*/}" "$number")" || {
    FACTS_REFUSED="the work unit cannot be named canonically"; return 3; }

  facts_unit_read "$locator" "$number" || {
    FACTS_REFUSED="$(facts_unreadable_reason "$FACTS_NODE")"; return 3; }

  case "$FACTS_NODE" in
    absent*)
      # Nothing by that number in this repository. There is no node, so there is
      # no observed version and no envelope that could carry the absence.
      FACTS_REFUSED="no work unit by that number"; return 3 ;;
    partial*|errored*)
      FACTS_REFUSED="malformed"; return 3 ;;
  esac

  self_num="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $2; exit }')"
  self_nwo="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $3; exit }')"
  self_version="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $4; exit }')"
  self_type="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $5; exit }')"

  # The node returned must be the node asked for, in BOTH halves of its
  # identity. Checking the number alone leaves the repository assumed, and a
  # fact that names a repository it never observed is what this class exists to
  # prevent.
  if [ "$self_num" != "$number" ] \
     || [ "$(printf '%s' "$host/${self_nwo,,}#$number")" != "$wu" ]; then
    FACTS_REFUSED="malformed"; return 3
  fi

  # The version decides whether any envelope can be built, so it is checked
  # first and alone. Every other failure is reportable inside a conforming fact.
  if [ -z "$self_version" ] || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$self_version"; then
    FACTS_REFUSED="malformed"; return 3
  fi

  # The kind decides the invalidator's canonical form (R17: an issue is named
  # `issue:`, a pull request `pull_request:`, never both), so a kind outside the
  # model's vocabulary is not a fact with a reason — it is a fact whose
  # freshness token could not be spelled.
  kind="$(facts_unit_kind "$self_type")" || {
    FACTS_REFUSED="malformed"; return 3; }

  inv="$kind:$wu"
  head='{"schema_version":'"$FACTS_SCHEMA_VERSION"',"key":"work_unit.identity","class":"work_unit","status":'
  tail=',"source":{"type":"github-api","identity":"'"$(json_escape "$wu")"'","version":"'"$(json_escape "$self_version")"'"}'
  tail="$tail"',"observed_at":"'"$observed"'","invalidators":["'"$(json_escape "$inv")"'"]'
  tail="$tail"',"versions":{"'"$(json_escape "$inv")"'":"'"$(json_escape "$self_version")"'"}'
  tail="$tail"',"provenance":"'"$(json_escape "https://$locator/issues/$number")"'"}'

  # Every reference the reply DID return is validated BEFORE truncation is
  # decided. Returning the bounded UNKNOWN first skipped this walk entirely, so
  # a truncated reply carrying a malformed reference emitted a fact from an
  # observation the schema does not admit — the truncation flag became a way to
  # avoid being checked. A node the reply returned is a node it claimed,
  # however short the list.
  #
  # Validating first is safe here in a way it would not be for the graph class:
  # a closing reference is a declared relationship, never an invalidator of this
  # fact, so walking the rows accumulates no freshness contract that an UNKNOWN
  # would then have to disown.
  local implements="none" candidates="" n=0 row rnum rnwo rtype rwu
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    rnum="$(printf '%s' "$row" | cut -f2)"
    rnwo="$(printf '%s' "$row" | cut -f3)"
    rtype="$(printf '%s' "$row" | cut -f4)"
    # A closing reference is an ISSUE. A pull request cannot close a pull
    # request, so a reference returned as anything else is a reply this class
    # cannot read rather than a relationship it can record. The projection
    # already refuses this shape; the check stays because two layers deciding
    # the same thing is the point — one of them was skippable.
    [ "$rtype" = "Issue" ] || { FACTS_REFUSED="malformed"; return 3; }
    rwu="$(facts_unit_locator "$host" "$rnwo" "$rnum")" || {
      FACTS_REFUSED="malformed"; return 3; }
    n=$(( n + 1 ))
    implements="$rwu"
    candidates="${candidates:+$candidates,}\"$(json_escape "$rwu")\""
  done <<EOF
$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "implements"')
EOF

  # Only now is a bounded list an unknown value: what the reply returned has
  # been checked, and what it withheld is what cannot be known.
  if printf '%s\n' "$FACTS_NODE" \
     | awk -F'\t' '$1 == "truncated" && $2 == "implements" { found = 1 } END { exit !found }'; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"bounded","candidates":[]}'"$tail"
    return 0
  fi

  if [ "$n" -gt 1 ]; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_JSON="$head"'"CONFLICT","detail":{"reason":"the pull request declares more than one closing issue","candidates":['"$candidates"']}'"$tail"
    return 0
  fi

  FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
  FACTS_JSON="$head"'"ESTABLISHED","value":{"kind":"'"$kind"'","id":"'"$(json_escape "$wu")"'","implements":"'"$(json_escape "$implements")"'"}'"$tail"
  return 0
}

# facts_record_telemetry — the compiler's efficiency observability, recorded
# only when a run is being observed, exactly like the runtime footprint. Five
# counts and nothing else: the facts themselves are this verb's output, and
# copying them into a telemetry value is the cost that contract refuses.
#
# Called on every exit that ran the compiler, including the ones that compiled
# nothing. Zero emitted and zero reads is a real answer — this verb ran and
# found nothing it could name — and it is precisely the answer that would be
# lost if a not-assessed return skipped recording, leaving an observed run
# indistinguishable from a run that never happened.
# facts_placement_fact <locator> <number> <observed_at> — the placement.current
# fact for one work unit.
#
# The class carries three placements — milestone, release and gate — and the
# release half is governed by a recorded human decision (#733, comment
# 5608275480):
#
#   `placement.release` may be ESTABLISHED only from an explicit authoritative
#   release declaration that maps the work unit to an exact SemVer `vX.Y.Z`. A
#   milestone name, an inferred version, a Release Please prediction, or the
#   absence of evidence is not sufficient. Where no such declaration exists,
#   `placement.current` is UNKNOWN — never `release: none`.
#
# The distinction is load-bearing rather than pedantic. `release: none` is a
# positive claim that the work sits outside every release, and the model fires
# the `placement:release` reserved boundary whenever release is `not-none`
# (fact-model.tsv:241). Reporting `none` from an absence of evidence would
# therefore SUPPRESS a human boundary by asserting the one thing nobody
# observed. The <release> grammar says it mechanically too: `^v[0-9]+\.[0-9]+\.[0-9]+$`
# admits a published tag and nothing else, so a milestone titled
# `v0.23 — Never automate inefficiency` could never satisfy it.
#
# This repository declares no authoritative exact-release mapping anywhere this
# compiler may read, so the fact is UNKNOWN here today. That is the ruling's
# answer rather than a gap in it, and the compiler does not supply the missing
# declaration: #733 forbids inventing authority semantics in the compiler.
#
# What this fact does NOT carry is a freshness token for a declaration that
# does not exist yet, and an independent review stopped on exactly that:
# introduce a declaration source later and a held UNKNOWN would not go stale,
# because no invalidator names the thing that changed. Ruled shippable as
# current-truth-only (#777) on measurable grounds — the only memo is
# `facts_unit_read`'s pair of shell variables, scoped to one invocation, and
# nothing consumes this compiler yet, so every run recompiles from a fresh
# read and the first run after a declaration exists would see it.
#
# That makes it an ordering constraint rather than a defect, and the
# constraint is recorded against #734, where a durable snapshot first becomes
# possible: no durable snapshot or reuse of placement.current until its
# release-declaration dependency has a real invalidator. A snapshot must
# otherwise omit this fact or recompute it on every read.
#
#   UNKNOWN   the node was read and its version observed, and no authoritative
#             declaration places it in a release. The milestone that WAS
#             observed is carried as an invalidator, so the answer re-derives
#             when the work unit is moved between milestones;
#   refused   the read failed, the node is absent, or it cannot be named
#             canonically — there is no observed version, so no envelope (R6).
facts_placement_fact() {
  local locator="$1" number="$2" observed="$3" host="${1%%/*}"
  local wu head tail inv kind self_num self_nwo self_version self_type
  local ms_num ms_nwo ms_version ms_id ms_inv
  FACTS_JSON=""
  FACTS_REFUSED=""
  facts_load_grammars

  wu="$(facts_unit_locator "$host" "${locator#*/}" "$number")" || {
    FACTS_REFUSED="the work unit cannot be named canonically"; return 3; }

  # The SAME observation the work-unit and graph classes read. Placement is a
  # third fact about one node, and reading it again would let the three
  # describe that node in three different states.
  facts_unit_read "$locator" "$number" || {
    FACTS_REFUSED="$(facts_unreadable_reason "$FACTS_NODE")"; return 3; }

  case "$FACTS_NODE" in
    absent*)  FACTS_REFUSED="no work unit by that number"; return 3 ;;
    partial*|errored*) FACTS_REFUSED="malformed"; return 3 ;;
  esac

  self_num="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $2; exit }')"
  self_nwo="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $3; exit }')"
  self_version="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $4; exit }')"
  self_type="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $5; exit }')"

  if [ "$self_num" != "$number" ] \
     || [ "$(printf '%s' "$host/${self_nwo,,}#$number")" != "$wu" ]; then
    FACTS_REFUSED="malformed"; return 3
  fi
  if [ -z "$self_version" ] || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$self_version"; then
    FACTS_REFUSED="malformed"; return 3
  fi

  kind="$(facts_unit_kind "$self_type")" || {
    FACTS_REFUSED="malformed"; return 3; }
  inv="$kind:$wu"

  # The milestone is an INVALIDATOR, not the answer. It is read so that moving
  # the work unit between milestones changes this fact's freshness — and it is
  # held to its own grammar first, because an invalidator token outside its
  # grammar is a freshness contract that cannot be spelled (R20). Its version
  # is the milestone node's own updated_at, which is why the query asks for it.
  ms_num="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "milestone" { print $2; exit }')"
  ms_nwo="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "milestone" { print $3; exit }')"
  ms_version="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "milestone" { print $4; exit }')"
  ms_inv=""
  if [ -n "$ms_num" ]; then
    ms_id="$host/${ms_nwo,,}/milestone/$ms_num"
    if ! facts_canonical "$FACTS_RE_MILESTONE" "" "$ms_id" \
       || [ -z "$ms_version" ] \
       || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$ms_version"; then
      FACTS_REFUSED="malformed"; return 3
    fi
    ms_inv="milestone:$ms_id"
  fi

  head='{"schema_version":'"$FACTS_SCHEMA_VERSION"',"key":"placement.current","class":"placement","status":'
  tail=',"source":{"type":"github-api","identity":"'"$(json_escape "$wu")"'","version":"'"$(json_escape "$self_version")"'"}'
  tail="$tail"',"observed_at":"'"$observed"'","invalidators":["'"$(json_escape "$inv")"'"'
  [ -z "$ms_inv" ] || tail="$tail"',"'"$(json_escape "$ms_inv")"'"'
  tail="$tail"']'
  tail="$tail"',"versions":{"'"$(json_escape "$inv")"'":"'"$(json_escape "$self_version")"'"'
  [ -z "$ms_inv" ] || tail="$tail"',"'"$(json_escape "$ms_inv")"'":"'"$(json_escape "$ms_version")"'"'
  tail="$tail"'}'
  tail="$tail"',"provenance":"'"$(json_escape "https://$locator/issues/$number")"'"}'

  # APPROVED SEMANTICS — current-truth-only (#777). Read this before caching.
  #   * this UNKNOWN is intentional, and intentionally recomputed every run;
  #   * there is no durable fact cache today — the only memo is
  #     facts_unit_read's shell variables, scoped to one invocation;
  #   * it must NOT become durably cached or reused until an authoritative
  #     release-declaration source exists WITH an invalidator, or a held
  #     UNKNOWN will survive the declaration that should have staled it;
  #   * #734 owns that prerequisite: no durable snapshot or reuse ships first;
  #   * and the missing source is not to be invented here — release-placement
  #     authority is outside #733.
  FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
  FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
  FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"no authoritative declaration places this work unit in an exact release","candidates":[]}'"$tail"
  return 0
}

# facts_head_fact <locator> <number> <observed_at> — the head.exact fact.
#
# HEAD-bound, so it is the first class that can be NOT_APPLICABLE: an issue has
# no change and therefore no HEAD, and that is an answer rather than a gap. Such
# a fact carries no value and no detail (detail belongs to UNKNOWN and CONFLICT
# alone), lists no ref, and is invalidated by its work unit — R17 and R18.
#
# `base` is the base branch TARGET commit, not the commit the pull request was
# opened against, and the difference is the whole point of the class. R20 makes
# value.base the version of the `ref:` invalidator, so if base were the pull
# request's own base the fact would carry a version for a token naming
# something else. Measured against the live API, the two genuinely differ:
# PR #775 sat on c340b093 while master pointed at 35489172.
#
#   `current` is that comparison — the pull request is current when what it is
#   based on is still what the branch points at.
#
#   ESTABLISHED     the HEAD, the base ref, the branch target and the staleness
#                   they imply were all read and are all canonical;
#   UNKNOWN         the node was read and versioned, but a field is not
#                   canonical, so the value cannot be asserted (R6);
#   NOT_APPLICABLE  the work unit is an issue: no HEAD exists to report;
#   refused         the read failed, the node is absent, cannot be named, or
#                   its base branch names no target commit — the last because
#                   the `ref:` token would then have no version, and an
#                   invalidator that cannot be versioned is not a contract.
facts_head_fact() {
  local locator="$1" number="$2" observed="$3" host="${1%%/*}"
  local wu head tail inv kind self_num self_nwo self_version self_type
  local h_head h_baseref h_baseoid h_target ref_id ref_inv current
  FACTS_JSON=""
  FACTS_REFUSED=""
  facts_load_grammars

  wu="$(facts_unit_locator "$host" "${locator#*/}" "$number")" || {
    FACTS_REFUSED="the work unit cannot be named canonically"; return 3; }

  facts_unit_read "$locator" "$number" || {
    FACTS_REFUSED="$(facts_unreadable_reason "$FACTS_NODE")"; return 3; }
  case "$FACTS_NODE" in
    absent*)  FACTS_REFUSED="no work unit by that number"; return 3 ;;
    partial*|errored*) FACTS_REFUSED="malformed"; return 3 ;;
  esac

  self_num="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $2; exit }')"
  self_nwo="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $3; exit }')"
  self_version="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $4; exit }')"
  self_type="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $5; exit }')"

  if [ "$self_num" != "$number" ] \
     || [ "$(printf '%s' "$host/${self_nwo,,}#$number")" != "$wu" ]; then
    FACTS_REFUSED="malformed"; return 3
  fi
  if [ -z "$self_version" ] || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$self_version"; then
    FACTS_REFUSED="malformed"; return 3
  fi
  kind="$(facts_unit_kind "$self_type")" || { FACTS_REFUSED="malformed"; return 3; }
  inv="$kind:$wu"

  head='{"schema_version":'"$FACTS_SCHEMA_VERSION"',"key":"head.exact","class":"head","status":'
  tail=',"source":{"type":"github-api","identity":"'"$(json_escape "$wu")"'","version":"'"$(json_escape "$self_version")"'"}'

  # An issue has no HEAD. The envelope still names the node it was read from and
  # is invalidated by it, so the answer goes stale if the issue becomes
  # something else; it lists no ref, because there is no base to be stale
  # against.
  if [ "$kind" = "issue" ]; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_JSON="$head"'"NOT_APPLICABLE"'"$tail"',"observed_at":"'"$observed"'","invalidators":["'"$(json_escape "$inv")"'"],"versions":{"'"$(json_escape "$inv")"'":"'"$(json_escape "$self_version")"'"},"provenance":"'"$(json_escape "https://$locator/issues/$number")"'"}'
    return 0
  fi

  h_head="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "head" { print $2; exit }')"
  h_baseref="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "head" { print $3; exit }')"
  h_baseoid="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "head" { print $4; exit }')"
  h_target="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "head" { print $5; exit }')"

  # A deleted base branch names no target commit, so the `ref:` token this fact
  # must carry (R17) could not be versioned (R20). Refused rather than emitted
  # with a token whose freshness nothing can decide.
  if [ -z "$h_target" ]; then
    FACTS_REFUSED="the base branch names no target commit"; return 3
  fi

  # ENVELOPE-CRITICAL first, and refused rather than reported. The `ref:`
  # invalidator and its version are part of every status this class can emit,
  # so a base ref that cannot be canonically named, or a target that is not a
  # commit, leaves the fact unable to say what it depends on or as of when.
  #
  # Emitting an UNKNOWN there would put the malformed token and version inside
  # the envelope — a fact whose freshness nothing can decide, which is strictly
  # worse than no fact. It would also contradict the refusal one branch above:
  # an ABSENT target is refused, so a malformed one cannot be reported.
  #
  # Only value-only fields survive into an UNKNOWN, below.
  ref_id="$locator/$h_baseref"
  ref_inv="ref:$ref_id"
  if ! facts_canonical "$FACTS_RE_REF" "$FACTS_CON_REF" "$h_baseref" \
     || ! facts_canonical "$FACTS_RE_REF" "$FACTS_CON_REF" "$ref_id" \
     || ! facts_canonical "$FACTS_RE_COMMIT" "" "$h_target"; then
    FACTS_REFUSED="the base branch cannot be canonically named or versioned"
    return 3
  fi

  tail="$tail"',"observed_at":"'"$observed"'","invalidators":["'"$(json_escape "$inv")"'","'"$(json_escape "$ref_inv")"'"]'
  tail="$tail"',"versions":{"'"$(json_escape "$inv")"'":"'"$(json_escape "$self_version")"'","'"$(json_escape "$ref_inv")"'":"'"$(json_escape "$h_target")"'"}'
  tail="$tail"',"provenance":"'"$(json_escape "https://$locator/pull/$number")"'"}'

  # Value-only fields. The envelope is already sound, so these can be reported
  # inside a conforming UNKNOWN (R6): the node was read and versioned, and only
  # the value is missing.
  if ! facts_canonical "$FACTS_RE_COMMIT" "" "$h_head" \
     || ! facts_canonical "$FACTS_RE_COMMIT" "" "$h_baseoid"; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"malformed","candidates":[]}'"$tail"
    return 0
  fi

  if [ "$h_baseoid" = "$h_target" ]; then current=true; else current=false; fi

  FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
  FACTS_JSON="$head"'"ESTABLISHED","value":{"head":"'"$(json_escape "$h_head")"'","base_ref":"'"$(json_escape "$h_baseref")"'","base":"'"$(json_escape "$h_target")"'","current":'"$current"'}'"$tail"
  return 0
}

# facts_rules_read <locator> <branch> — the checks a branch actually requires,
# in ONE request, with the digest that versions them.
#
# `repos/<nwo>/rules/branches/<branch>` answers with the rules in EFFECT on that
# branch — the union of every ruleset that applies — rather than making the
# caller enumerate rulesets and work out which ones match. Measured on this
# repository it returns `doctor` and `tests`, which is fewer than the checks
# that actually run: required and present are different questions, and this
# class answers the first.
#
# R20 versions a `ruleset:` token with the collection digest, so the digest is
# computed over the canonical serialization of what was read — every requiring
# ruleset id paired with every context it requires, sorted, one per line. Any
# change to the required set, or to which ruleset requires it, changes the
# digest and stales the fact. The digest is a sha1, which the source-version
# grammar already admits as a 40-hex.
FACTS_RULES_KEY=""
FACTS_RULES_ROWS=""
FACTS_RULES_RC=0
facts_rules_read() {
  local locator="$1" branch="$2" host="${1%%/*}" nwo="${1#*/}" key="$1@$2" out rc=0 digest enc
  if [ -n "$FACTS_RULES_KEY" ] && [ "$FACTS_RULES_KEY" = "$key" ]; then
    FACTS_CACHE_HITS=$(( FACTS_CACHE_HITS + 1 ))
    FACTS_RULES="$FACTS_RULES_ROWS"
    return "$FACTS_RULES_RC"
  fi
  FACTS_CACHE_MISSES=$(( FACTS_CACHE_MISSES + 1 ))
  FACTS_API_CALLS=$(( FACTS_API_CALLS + 1 ))
  # The projection is total: anything that is not the expected shape yields no
  # rows, and no rows is then decided by the caller rather than erroring here.
  # The branch is ONE path segment. `feat/x` interpolated raw becomes two, and
  # the lookup then fails for a base branch that is perfectly valid.
  enc="$(printf '%s' "$branch" | jq -sRr '@uri' 2>/dev/null)"
  enc="${enc%%$'\n'*}"
  [ -n "$enc" ] || enc="$branch"
  # `ok` is emitted only when the body is the array this endpoint promises, so
  # its ABSENCE distinguishes a malformed reply from a branch that genuinely
  # requires nothing. Both would otherwise be an empty required set, and one of
  # them is a valid answer while the other is no answer at all.
  # A rule of the relevant TYPE that is then the wrong SHAPE is not a rule that
  # requires nothing; it is a rule that could not be read. Dropping it silently
  # would let a malformed reply establish "nothing is required", which is the
  # most dangerous possible answer this endpoint can give: everything merges.
  # So relevant rules are validated, and any malformed one refuses the read.
  # Rules of OTHER types are still ignored, because they say nothing about
  # required checks and their shape is not this function to police.
  # A requirement is (ruleset, integration, context), not a context. GitHub
  # lets a rule bind a context to the app that must produce it, and a check of
  # that NAME from any other producer then does not satisfy it. Dropping the
  # binding would let a look-alike check satisfy a requirement, and would leave
  # the digest unchanged when the required producer is swapped — a change in
  # what is required that freshness could not see.
  #
  # A context carrying a tab or a newline is refused rather than transported.
  # These rows are TSV and the required names travel newline-delimited, so a
  # control character inside a context splits a row, mismatches an observed
  # name, and lets two different collections serialize to one digest. GitHub
  # does not issue such names; a reply bearing one is not a requirement this
  # reader can carry faithfully, so it carries none.
  out="$(gh api --hostname "$host" "repos/$nwo/rules/branches/$enc" \
    --jq 'if type == "array" then
            [ .[] | select((type == "object") and (.type? == "required_status_checks")) ] as $rel
            | if ($rel | map(select(((.parameters?.required_status_checks? | type) != "array")
                                    or ((.ruleset_id? | type) != "number")))
                       | length) > 0
              then "malformed"
              elif ($rel | map(.parameters.required_status_checks[]
                               | select((type != "object")
                                        or ((.context? | type) != "string")
                                        or (.context | test("[\\t\\n\\r]"))
                                        or ((.integration_id? | type) as $t
                                            | ($t != "number") and ($t != "null"))))
                         | length) > 0
              then "malformed"
              else
                "ok",
                ([ $rel[]
                  | .ruleset_id as $r
                  | .parameters.required_status_checks[]
                  | [($r | tostring),
                     (if .integration_id == null then "" else (.integration_id | tostring) end),
                     .context] | @tsv ]
                 | sort | unique | .[])
              end
          else empty end' 2>/dev/null)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    FACTS_RULES=""
    FACTS_RULES_KEY="$key"; FACTS_RULES_ROWS=""; FACTS_RULES_RC="$rc"
    return "$rc"
  fi
  # A missing `ruleset_id` is malformed rather than defaulted: the digest is
  # declared to cover every requiring ruleset, so a fabricated id would make
  # "some ruleset whose identity was not read" hash the same as a real
  # ruleset 0, and freshness would then rest on provenance nobody observed.
  # A reply that was not the promised array, or one whose relevant rules were
  # malformed, said nothing about what is required, and "nothing required" is a
  # claim. Both are refused rather than hashed.
  case "$out" in
    ok|ok$'\n'*) ;;
    *) FACTS_RULES=""; FACTS_RULES_KEY="$key"; FACTS_RULES_ROWS=""; FACTS_RULES_RC=3
       return 3 ;;
  esac
  out="${out#ok}"; out="${out#$'\n'}"
  # The digest covers the serialization exactly as read, including the empty
  # case: a branch that requires nothing has a stable digest of its own, so
  # "nothing required" is a versioned answer rather than an absent one.
  digest="$(printf '%s\n' "$out" | sha1sum 2>/dev/null | cut -d" " -f1)"
  if [ -z "$digest" ]; then
    digest="$(printf '%s\n' "$out" | shasum 2>/dev/null | cut -d" " -f1)"
  fi
  # The DIGEST is over every (ruleset, integration, context) triple, because
  # two rulesets each requiring `doctor`, or one ruleset requiring it from a
  # different app, is a different configuration; R20 versions the collection as
  # read. The REQUIREMENT rows drop the ruleset and keep the producer binding,
  # deduplicated: which ruleset asked does not change what must be satisfied,
  # but which app must answer does.
  FACTS_RULES="$(printf 'digest\t%s\n' "$digest"; printf '%s\n' "$out" \
    | while IFS= read -r row; do
        [ -n "$row" ] || continue
        printf '%s\t%s\n' "$(printf '%s' "$row" | cut -f2)" "$(printf '%s' "$row" | cut -f3-)"
      done \
    | LC_ALL=C sort -u \
    | while IFS= read -r ctx; do printf 'required\t%s\n' "$ctx"; done)"
  FACTS_RULES_KEY="$key"
  FACTS_RULES_ROWS="$FACTS_RULES"
  FACTS_RULES_RC=0
  return 0
}

# facts_check_state <status> <conclusion> — GitHub answer to the closed
# check-state vocabulary: success | failure | pending | missing.
#
# A run that has not completed is pending whatever it currently reports. A
# completed run is success only when it concluded SUCCESS.
#
# SKIPPED and NEUTRAL land in failure DELIBERATELY. The vocabulary admits no
# fifth state, and R12 — the rule governing THIS class — makes merge derivable
# only when every result is success. Mapping a required check that never ran
# its assertions to success would open exactly the hole this class exists to
# close. Reporting it as failure is the fail-closed direction: the cost is a
# merge that waits, and the cost of the other choice is a merge that should not
# have happened.
#
# Ruled for schema v1 on #779 (comment 5618697944): SKIPPED and NEUTRAL are
# observed and completed, and do not satisfy the required-check contract.
# Anything more permissive is a schema or governance change, and belongs to a
# future one rather than to #733.
# Which of two states a name should report when several requirements wear it.
# `success` survives only when nothing else appears; otherwise the most
# decisive obstacle wins, decisive meaning what a reader must act on first: a
# failure is settled, a check that never ran is a gap, and a pending one is
# merely unfinished. An empty left operand is the identity, so the first
# requirement examined sets the state.
facts_check_worse() {
  case "$1" in "") printf '%s' "$2"; return 0 ;; esac
  case "$1$2" in
    *failure*) printf 'failure' ;;
    *missing*) printf 'missing' ;;
    *pending*) printf 'pending' ;;
    *)         printf 'success' ;;
  esac
}

facts_check_state() {
  # A legacy status context has no separate status field: its state IS both
  # what it is doing and how it ended. Synthesizing COMPLETED for it turned
  # PENDING and EXPECTED into completed non-successes -- a check still running
  # reported as one that failed, which is the opposite of what a caller waiting
  # on it needs.
  if [ "$1" = "STATUS_CONTEXT" ]; then
    case "$2" in
      SUCCESS|success)                   printf 'success' ;;
      PENDING|pending|EXPECTED|expected) printf 'pending' ;;
      *)                                 printf 'failure' ;;
    esac
    return 0
  fi
  case "$1" in
    COMPLETED|completed) ;;
    *) printf 'pending'; return 0 ;;
  esac
  case "$2" in
    SUCCESS|success) printf 'success' ;;
    *)               printf 'failure' ;;
  esac
}

# facts_review_fact <locator> <number> <observed_at> — the review.independent fact.
#
# The independent verdict bound to an exact HEAD. HEAD-bound, so an issue is
# NOT_APPLICABLE: there is no change to have been reviewed.
#
# WHAT THIS FACT DOES NOT DECIDE. The model gives the value a `reviewer` field,
# not a trusted-producer filter, and #733 must not invent authority semantics.
# So this fact reports the verdict record it found and NAMES its author; it
# does not judge whether that author holds review authority. That judgement is
# `authority.standing`, a class of this same model and a remaining packet of
# this same issue, and a consumer deciding a merge needs both facts, never this
# one alone. Recording that here so the gap is visible at the point of use:
# a lone verdict comment establishes what the comment SAYS, not that the person
# who wrote it was entitled to say it.
#
# What does protect the fact without inventing authority is R8. Two records
# naming this HEAD are a CONFLICT with both named as candidates, so a forged
# verdict beside a real one cannot resolve to either. The marker must also open
# the comment body and name this pull request, because a marker quoted inside
# another comment is a quotation of a verdict rather than one.
facts_review_fact() {
  local locator="$1" number="$2" observed="$3" host="${1%%/*}"
  local wu head tail inv kind self_num self_nwo self_version self_type
  local h_head head_inv rows n rec_id rec_at rec_login rec_head rec_verdict
  local record rec_inv login cands invs vers
  FACTS_JSON=""
  FACTS_REFUSED=""
  facts_load_grammars

  wu="$(facts_unit_locator "$host" "${locator#*/}" "$number")" || {
    FACTS_REFUSED="the work unit cannot be named canonically"; return 3; }

  facts_unit_read "$locator" "$number" || {
    FACTS_REFUSED="$(facts_unreadable_reason "$FACTS_NODE")"; return 3; }
  case "$FACTS_NODE" in
    absent*)  FACTS_REFUSED="no work unit by that number"; return 3 ;;
    partial*|errored*) FACTS_REFUSED="malformed"; return 3 ;;
  esac

  self_num="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $2; exit }')"
  self_nwo="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $3; exit }')"
  self_version="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $4; exit }')"
  self_type="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $5; exit }')"

  if [ "$self_num" != "$number" ] \
     || [ "$(printf '%s' "$host/${self_nwo,,}#$number")" != "$wu" ]; then
    FACTS_REFUSED="malformed"; return 3
  fi
  if [ -z "$self_version" ] || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$self_version"; then
    FACTS_REFUSED="malformed"; return 3
  fi
  kind="$(facts_unit_kind "$self_type")" || { FACTS_REFUSED="malformed"; return 3; }
  inv="$kind:$wu"

  head='{"schema_version":'"$FACTS_SCHEMA_VERSION"',"key":"review.independent","class":"review","status":'

  # An issue has no HEAD, so there is no verdict bound to one. R17: the
  # NOT_APPLICABLE fact names the work unit it was read from and is invalidated
  # by it.
  if [ "$kind" = "issue" ]; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_JSON="$head"'"NOT_APPLICABLE","source":{"type":"github-api","identity":"'"$(json_escape "$wu")"'","version":"'"$(json_escape "$self_version")"'"},"observed_at":"'"$observed"'","invalidators":["'"$(json_escape "$inv")"'"],"versions":{"'"$(json_escape "$inv")"'":"'"$(json_escape "$self_version")"'"},"provenance":"'"$(json_escape "https://$locator/issues/$number")"'"}'
    return 0
  fi

  h_head="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "head" { print $2; exit }')"
  # ENVELOPE-CRITICAL. Every status this class emits for a pull request carries
  # the `head:` token, because the verdict is only ever about one commit. A head
  # that is not a commit leaves the fact unable to say which commit it is about,
  # which is worse than no fact.
  if ! facts_canonical "$FACTS_RE_COMMIT" "" "$h_head"; then
    FACTS_REFUSED="the head is not a commit, so no verdict could be bound to it"; return 3
  fi
  head_inv="head:$h_head"

  # The pull request is listed too (R17): its comments are where the verdicts
  # live, so a record posted after this read must fire a token the fact already
  # carries.
  invs='"'"$(json_escape "$head_inv")"'","'"$(json_escape "$inv")"'"'
  vers='"'"$(json_escape "$head_inv")"'":"'"$(json_escape "$h_head")"'","'"$(json_escape "$inv")"'":"'"$(json_escape "$self_version")"'"'
  tail=',"source":{"type":"github-api","identity":"'"$(json_escape "$wu")"'","version":"'"$(json_escape "$self_version")"'"}'
  tail="$tail"',"observed_at":"'"$observed"'","invalidators":['"$invs"'],"versions":{'"$vers"'}'
  tail="$tail"',"provenance":"'"$(json_escape "https://$locator/pull/$number")"'"}'

  # A window that did not reach the beginning of the conversation cannot say
  # that no verdict names this head, and an older record could contradict the
  # one seen. Bounded is an unknown, never an absence.
  if printf '%s\n' "$FACTS_NODE" \
     | awk -F'\t' '$1 == "truncated" && $2 == "comments" { found = 1 } END { exit !found }'; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"bounded","candidates":[]}'"$tail"
    return 0
  fi

  rows="$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' -v h="$h_head" '$1 == "verdict" && $5 == h { print }')"
  n=0
  [ -z "$rows" ] || n="$(printf '%s\n' "$rows" | wc -l)"

  if [ "$n" -eq 0 ]; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"no independent verdict names this head","candidates":[]}'"$tail"
    return 0
  fi

  # More than one record naming one head is a CONFLICT even when the verdicts
  # agree. The value must name ONE record, and choosing among them by position
  # is the first-write rule R8 forbids; two records for one head also means the
  # lane guarantee of one review per head did not hold, which a reader must see
  # rather than have resolved for them. Every named comment becomes both a
  # candidate and an invalidator, so an edit to any of them stales the fact.
  if [ "$n" -gt 1 ]; then
    cands=""
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      rec_id="$(printf '%s' "$r" | cut -f2)"
      record="$locator#$number/comment/$rec_id"
      rec_at="$(printf '%s' "$r" | cut -f3)"
      if ! facts_canonical "$FACTS_RE_COMMENT" "" "$record" \
         || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$rec_at"; then
        FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
        FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
        FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"a record naming this head could not be named or versioned","candidates":[]}'"$tail"
        return 0
      fi
      cands="${cands:+$cands,}\"$(json_escape "$record")\""
      invs="$invs,\"$(json_escape "comment:$record")\""
      vers="$vers,\"$(json_escape "comment:$record")\":\"$(json_escape "$rec_at")\""
    done <<EOF
$rows
EOF
    tail=',"source":{"type":"github-api","identity":"'"$(json_escape "$wu")"'","version":"'"$(json_escape "$self_version")"'"}'
    tail="$tail"',"observed_at":"'"$observed"'","invalidators":['"$invs"'],"versions":{'"$vers"'}'
    tail="$tail"',"provenance":"'"$(json_escape "https://$locator/pull/$number")"'"}'
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_JSON="$head"'"CONFLICT","detail":{"reason":"more than one record names this head","candidates":['"$cands"']}'"$tail"
    return 0
  fi

  rec_id="$(printf '%s' "$rows" | cut -f2)"
  rec_at="$(printf '%s' "$rows" | cut -f3)"
  rec_login="$(printf '%s' "$rows" | cut -f4)"
  rec_verdict="$(printf '%s' "$rows" | cut -f6)"
  record="$locator#$number/comment/$rec_id"
  rec_inv="comment:$record"
  login="login:${rec_login,,}"

  # Value-only fields, so a malformed one is an UNKNOWN rather than a refusal:
  # the envelope above is already complete and can say what it depends on. A
  # comment by a deleted account has no login and so no reviewer to name.
  if ! facts_canonical "$FACTS_RE_COMMENT" "" "$record" \
     || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$rec_at" \
     || ! facts_canonical "$FACTS_RE_VERDICT" "" "$rec_verdict" \
     || [ -z "$rec_login" ] || ! facts_canonical "$FACTS_RE_LOGIN" "" "$login"; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"the record naming this head could not be read as a verdict","candidates":[]}'"$tail"
    return 0
  fi

  # R17: an ESTABLISHED review names its RECORD as the source and lists it as a
  # comment: invalidator; R20 versions that token by the comment updated_at, so
  # an edited verdict goes stale rather than standing.
  invs="$invs,\"$(json_escape "$rec_inv")\""
  vers="$vers,\"$(json_escape "$rec_inv")\":\"$(json_escape "$rec_at")\""
  tail=',"source":{"type":"github-api","identity":"'"$(json_escape "$record")"'","version":"'"$(json_escape "$rec_at")"'"}'
  tail="$tail"',"observed_at":"'"$observed"'","invalidators":['"$invs"'],"versions":{'"$vers"'}'
  tail="$tail"',"provenance":"'"$(json_escape "https://$locator/pull/$number")"'"}'

  FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
  FACTS_JSON="$head"'"ESTABLISHED","value":{"verdict":"'"$(json_escape "$rec_verdict")"'","head":"'"$(json_escape "$h_head")"'","reviewer":"'"$(json_escape "$login")"'","record":"'"$(json_escape "$record")"'"}'"$tail"
  return 0
}

# facts_checks_fact <locator> <number> <observed_at> — the checks.required fact.
#
# The class answers one question: on THIS exact HEAD, what does the base branch
# require, and what is the state of each required check. Required and present
# are different questions — this repository runs five checks and requires two —
# so the value is keyed by the required set, and a required name with no run
# observed is `missing` rather than absent from the answer.
#
# R17 gives this class a source the others do not have: checks name the
# REPOSITORY, not the work unit, and list ruleset:<repository>. It is also
# HEAD-bound, so it lists head:<commit> and is NOT_APPLICABLE for an issue.
#
#   ESTABLISHED     the HEAD, the required set and every required state were
#                   read, and the envelope tokens can all be versioned;
#   UNKNOWN         the rollup was bounded, or the reply named a different
#                   commit than the HEAD it was read for;
#   NOT_APPLICABLE  an issue: no HEAD, so no required check to be in a state;
#   refused         the read failed, the node is absent or cannot be named, the
#                   required set could not be read, or a token could not be
#                   versioned.
facts_checks_fact() {
  local locator="$1" number="$2" observed="$3" host="${1%%/*}"
  local wu head tail inv kind self_num self_nwo self_version self_type
  local h_head h_baseref r_oid r_has digest repo_version rs_inv head_inv
  local states conflict
  local required results n state row name unit_rows
  FACTS_JSON=""
  FACTS_REFUSED=""
  facts_load_grammars

  wu="$(facts_unit_locator "$host" "${locator#*/}" "$number")" || {
    FACTS_REFUSED="the work unit cannot be named canonically"; return 3; }

  facts_unit_read "$locator" "$number" || {
    FACTS_REFUSED="$(facts_unreadable_reason "$FACTS_NODE")"; return 3; }
  case "$FACTS_NODE" in
    absent*)  FACTS_REFUSED="no work unit by that number"; return 3 ;;
    partial*|errored*) FACTS_REFUSED="malformed"; return 3 ;;
  esac

  # The work-unit rows are taken NOW, because FACTS_NODE is one shared slot and
  # reading the repository node below overwrites it. Keeping a local copy is
  # what lets this fact consult both observations without either erasing the
  # other.
  unit_rows="$FACTS_NODE"

  self_num="$(printf '%s\n' "$unit_rows" | awk -F'\t' '$1 == "self" { print $2; exit }')"
  self_nwo="$(printf '%s\n' "$unit_rows" | awk -F'\t' '$1 == "self" { print $3; exit }')"
  self_version="$(printf '%s\n' "$unit_rows" | awk -F'\t' '$1 == "self" { print $4; exit }')"
  self_type="$(printf '%s\n' "$unit_rows" | awk -F'\t' '$1 == "self" { print $5; exit }')"
  if [ "$self_num" != "$number" ] \
     || [ "$(printf '%s' "$host/${self_nwo,,}#$number")" != "$wu" ]; then
    FACTS_REFUSED="malformed"; return 3
  fi
  if [ -z "$self_version" ] || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$self_version"; then
    FACTS_REFUSED="malformed"; return 3
  fi
  kind="$(facts_unit_kind "$self_type")" || { FACTS_REFUSED="malformed"; return 3; }

  head='{"schema_version":'"$FACTS_SCHEMA_VERSION"',"key":"checks.required","class":"checks","status":'

  # An issue has no HEAD, so there is no required check to be in a state. R17
  # is explicit that a NOT_APPLICABLE HEAD-bound fact names the WORK UNIT it
  # was read from rather than the repository, and lists only that.
  if [ "$kind" = "issue" ]; then
    inv="$kind:$wu"
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_JSON="$head"'"NOT_APPLICABLE","source":{"type":"github-api","identity":"'"$(json_escape "$wu")"'","version":"'"$(json_escape "$self_version")"'"},"observed_at":"'"$observed"'","invalidators":["'"$(json_escape "$inv")"'"],"versions":{"'"$(json_escape "$inv")"'":"'"$(json_escape "$self_version")"'"},"provenance":"'"$(json_escape "https://$locator/issues/$number")"'"}'
    return 0
  fi

  h_head="$(printf '%s\n' "$unit_rows" | awk -F'\t' '$1 == "head" { print $2; exit }')"
  h_baseref="$(printf '%s\n' "$unit_rows" | awk -F'\t' '$1 == "head" { print $3; exit }')"
  r_oid="$(printf '%s\n' "$unit_rows" | awk -F'\t' '$1 == "rollup_commit" { print $2; exit }')"

  # The repository is this fact's source, and it is read from the SAME shared
  # observation the repository class uses rather than asked again.
  facts_repo_node "$locator" || {
    FACTS_REFUSED="$(facts_unreadable_reason "$FACTS_NODE")"; return 3; }
  repo_version="$(printf '%s' "$FACTS_NODE" | awk -F'\t' 'NR == 1 { print $3 }')"
  if [ -z "$repo_version" ] || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$repo_version"; then
    FACTS_REFUSED="malformed"; return 3
  fi

  # ENVELOPE-CRITICAL before the envelope, which is the lesson of the head
  # class: a token that cannot be versioned must be refused, never reported
  # inside a conforming-looking fact.
  if ! facts_canonical "$FACTS_RE_COMMIT" "" "$h_head"; then
    FACTS_REFUSED="the head is not a commit, so no check state could be bound to it"; return 3
  fi
  if ! facts_rules_read "$locator" "$h_baseref"; then
    FACTS_REFUSED="the required checks of the base branch could not be read"; return 3
  fi
  digest="$(printf '%s\n' "$FACTS_RULES" | awk -F'\t' '$1 == "digest" { print $2; exit }')"
  if [ -z "$digest" ] || ! facts_canonical "$FACTS_RE_COMMIT" "" "$digest"; then
    FACTS_REFUSED="the required checks could not be versioned"; return 3
  fi

  head_inv="head:$h_head"
  rs_inv="ruleset:$locator"
  tail=',"source":{"type":"github-api","identity":"'"$(json_escape "$locator")"'","version":"'"$(json_escape "$repo_version")"'"}'
  tail="$tail"',"observed_at":"'"$observed"'","invalidators":["'"$(json_escape "$head_inv")"'","'"$(json_escape "$rs_inv")"'"]'
  tail="$tail"',"versions":{"'"$(json_escape "$head_inv")"'":"'"$(json_escape "$h_head")"'","'"$(json_escape "$rs_inv")"'":"'"$(json_escape "$digest")"'"}'
  tail="$tail"',"provenance":"'"$(json_escape "https://$locator/pull/$number")"'"}'

  # A reply whose rollup belongs to a different commit is not a state of THIS
  # head. Reconciling them would be inventing which one to believe.
  if [ -n "$r_oid" ] && [ "$r_oid" != "$h_head" ]; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"the rollup names a different commit than the head","candidates":[]}'"$tail"
    return 0
  fi
  if printf '%s\n' "$unit_rows" \
     | awk -F'\t' '$1 == "truncated" && $2 == "checks" { found = 1 } END { exit !found }'; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"bounded","candidates":[]}'"$tail"
    return 0
  fi

  # One result per REQUIRED name, in the required order, whatever else ran. A
  # name with no run observed is `missing`: required and not answered is a
  # state, not an absence.
  #
  # A rollup can carry SEVERAL runs under one name — a re-run beside the run it
  # replaces, or two workflows that named their jobs alike. Every state derived
  # for one name is collected, not the first one found: taking the first is a
  # first-write rule, and R8 says two authoritative inputs that disagree are a
  # CONFLICT that no first-write, last-write or plausibility rule resolves.
  # Resolving them properly would need ordering or run identity the model does
  # not define a precedence over, and inventing one here is exactly what R8
  # forbids. Duplicates that AGREE are not a disagreement, so they answer
  # normally: the ambiguity is in contradictory states, not in repetition.
  # Several REQUIREMENTS can share one displayed context — the same name bound
  # to two apps, or required by two rulesets — while R12 admits exactly one
  # result per name. They are aggregated conservatively: the name is `success`
  # only when every requirement wearing it is satisfied, and otherwise reports
  # the most decisive obstacle among them. That is a derivation over DIFFERENT
  # requirements, not a resolution of contradictory claims about one, so it is
  # not the precedence R8 forbids.
  required=""; results=""; conflict=""
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    required="${required:+$required,}\"$(json_escape "$name")\""
    state=""
    while IFS= read -r integ; do
      # A requirement that binds no integration is satisfied by the name alone;
      # one that binds an app is satisfied only by that app's run. A status
      # context carries no app, so it can never answer an app-bound
      # requirement, and reads `missing` rather than being counted.
      states="$(printf '%s\n' "$unit_rows" \
        | awk -F'\t' -v n="$name" -v i="$integ" \
              '$1 == "check" && $2 == n && (i == "" || $5 == i) { print }' \
        | while IFS= read -r row; do
            [ -n "$row" ] || continue
            facts_check_state "$(printf '%s' "$row" | cut -f4)" "$(printf '%s' "$row" | cut -f3)"
            printf '\n'
          done | LC_ALL=C sort -u)"
      if [ -z "$states" ]; then
        one=missing
      elif [ "$(printf '%s\n' "$states" | wc -l)" -gt 1 ]; then
        conflict="$name"
        break
      else
        one="$states"
      fi
      state="$(facts_check_worse "$state" "$one")"
    done <<REQ
$(printf '%s\n' "$FACTS_RULES" | awk -F'\t' -v c="$name" '$1 == "required" && $3 == c { print $2 }')
REQ
    [ -z "$conflict" ] || break
    results="${results:+$results,}{\"name\":\"$(json_escape "$name")\",\"state\":\"$state\"}"
  done <<EOF
$(printf '%s\n' "$FACTS_RULES" | awk -F'\t' '$1 == "required" { print $3 }' | LC_ALL=C sort -u)
EOF

  if [ -n "$conflict" ]; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_JSON="$head"'"CONFLICT","detail":{"reason":"a required check was observed in more than one state: '"$(json_escape "$conflict")"'","candidates":[]}'"$tail"
    return 0
  fi

  FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
  FACTS_JSON="$head"'"ESTABLISHED","value":{"head":"'"$(json_escape "$h_head")"'","required":['"$required"'],"results":['"$results"']}'"$tail"
  return 0
}

facts_record_telemetry() {
  [ -n "${SPARK_RUN_ID:-}" ] || return 0
  SPARK_RECORDING=1 "$SPARK_ROOT/bin/spark" telemetry record --run "$SPARK_RUN_ID" \
    facts_emitted="$FACTS_EMITTED" \
    facts_unknown="$FACTS_UNKNOWN" \
    facts_api_calls="$FACTS_API_CALLS" \
    facts_cache_hits="$FACTS_CACHE_HITS" \
    facts_cache_misses="$FACTS_CACHE_MISSES" >/dev/null 2>&1 || true
  return 0
}

cmd_facts() {
  local usage_line="usage: spark facts [--issue <number>] [--help]"
  local issue="" issue_given=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --issue)   issue_given=1; shift; issue="${1:-}" ;;
      --issue=*) issue_given=1; issue="${1#--issue=}" ;;
      -h|--help) echo "$usage_line"; return 0 ;;
      *) red "unknown option: $1"; echo "$usage_line"; return 1 ;;
    esac
    if [ "$#" -gt 0 ]; then shift; fi
  done
  # Whether the flag was SUPPLIED is tracked separately from its value. `--issue`
  # with nothing after it, and `--issue=`, are caller errors: treating them as
  # the flag's absence would quietly compile a different set of facts than the
  # caller asked for, which is worse than refusing.
  #
  # The value is then validated before it reaches a query and refused rather than
  # coerced: a work unit is a positive integer, and anything else names no node.
  if [ -n "$issue_given" ]; then
    case "$issue" in
      ''|0|0*|*[!0-9]*)
        red "--issue takes an issue number"; echo "$usage_line"; return 1 ;;
    esac
  fi

  local top; top="$(git_root)"
  if [ -z "$top" ]; then
    red "spark facts needs a git repo — run it from inside the project."
    return 1
  fi

  facts_load_grammars

  # Every envelope carries the instant its source was read, whatever the status,
  # so one instant is taken and validated before anything is built. An envelope
  # cannot report the absence of its own observation instant — an UNKNOWN needs
  # one as much as an ESTABLISHED does — so an unusable clock is not a fact with
  # a reason, it is a reason there is no fact.
  local observed; observed="$(facts_now)"
  if ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$observed"; then
    yellow "NOT ASSESSED — the clock gave no usable observation instant" >&2
    facts_record_telemetry
    return 3
  fi

  local locator
  locator="$(repo_locator_normalize "$(git -C "$top" remote get-url origin 2>/dev/null || true)")"
  # Without a locator, or with one that does not normalize to a canonical
  # repository, the compiler cannot NAME the node it would read, so there is no
  # subject to be unknown about. An UNKNOWN still identifies its node, so this
  # is not one: nothing is emitted, because an identity invented to fill that
  # field would be worse than reporting that none could be read. The remote is
  # arbitrary text, which is why the grammar decides and not emptiness alone.
  if [ -z "$locator" ] \
     || ! facts_canonical "$FACTS_RE_REPOSITORY" "$FACTS_CON_REPOSITORY" "$locator"; then
    yellow "NOT ASSESSED — no origin remote names a canonical repository here" >&2
    facts_record_telemetry
    return 3
  fi

  # Each class is compiled independently and the fragment carries the ones that
  # could be built. A class that could not be established is absent rather than
  # present-and-empty, and the reasons are reported, so a caller can never read
  # silence as an answer.
  local facts="" why=""
  if facts_repository_fact "$locator" "$observed"; then
    facts="$FACTS_JSON"
  else
    why="repository: $FACTS_REFUSED"
  fi

  if [ -n "$issue" ]; then
    if facts_work_unit_fact "$locator" "$issue" "$observed"; then
      facts="${facts:+$facts,}$FACTS_JSON"
    else
      why="${why:+$why; }work_unit: $FACTS_REFUSED"
    fi

    if facts_graph_fact "$locator" "$issue" "$observed"; then
      facts="${facts:+$facts,}$FACTS_JSON"
    else
      why="${why:+$why; }graph: $FACTS_REFUSED"
    fi

    if facts_placement_fact "$locator" "$issue" "$observed"; then
      facts="${facts:+$facts,}$FACTS_JSON"
    else
      why="${why:+$why; }placement: $FACTS_REFUSED"
    fi

    if facts_head_fact "$locator" "$issue" "$observed"; then
      facts="${facts:+$facts,}$FACTS_JSON"
    else
      why="${why:+$why; }head: $FACTS_REFUSED"
    fi

    if facts_review_fact "$locator" "$issue" "$observed"; then
      facts="${facts:+$facts,}$FACTS_JSON"
    else
      why="${why:+$why; }review: $FACTS_REFUSED"
    fi

    if facts_checks_fact "$locator" "$issue" "$observed"; then
      facts="${facts:+$facts,}$FACTS_JSON"
    else
      why="${why:+$why; }checks: $FACTS_REFUSED"
    fi
  fi

  # Every diagnostic goes to stderr. This verb's stdout is a machine surface, and
  # a fragment followed by a human note is not parseable JSON — which is exactly
  # what a caller piping it would discover at the worst moment.
  if [ -z "$facts" ]; then
    yellow "NOT ASSESSED — nothing could be established: $why" >&2
    facts_record_telemetry
    return 3
  fi
  # The fragment shape: a bare list, never an object, so it can never be read as
  # the {observer, facts} snapshot a consumer is allowed to act on (R22). Two
  # classes are not the required set either, so this stays a fragment however
  # many facts it carries.
  printf '[%s]\n' "$facts"
  [ -z "$why" ] || yellow "not established — $why" >&2
  facts_record_telemetry
}
