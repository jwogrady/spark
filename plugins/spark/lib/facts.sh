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
# The output is a FRAGMENT, not a snapshot: a bare list of facts (R11, R22). A
# snapshot is exactly {observer, facts} with every required class present, and
# this module compiles one class so far, so calling its output a snapshot would
# be a lie a consumer is entitled to act on.
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
      identifier/issue-state) FACTS_RE_ISSUE_STATE="$rest" ;;
      constraint/work-unit)  FACTS_CON_WORK_UNIT="$FACTS_CON_WORK_UNIT$rest"$'\n' ;;
      identifier/ref)        FACTS_RE_REF="$rest" ;;
      identifier/timestamp)  FACTS_RE_TIMESTAMP="$rest" ;;
      constraint/repository) FACTS_CON_REPOSITORY="$FACTS_CON_REPOSITORY$rest"$'\n' ;;
      constraint/ref)        FACTS_CON_REF="$FACTS_CON_REF$rest"$'\n' ;;
    esac
  done < <(awk -F'\t' '
    $1 == "identifier" && ($2 == "repository" || $2 == "ref" || $2 == "timestamp" || $2 == "work-unit" || $2 == "issue-state") { print $1 "\t" $2 "\t" $3 }
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
# unrecognised failure is `unreadable`, which is still an UNKNOWN with a stated
# reason and never a guess at which failure it was.
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
facts_repo_node() {
  local locator="$1" host="${1%%/*}" nwo="${1#*/}" out rc=0
  FACTS_API_CALLS=$(( FACTS_API_CALLS + 1 ))
  # The projection is TOTAL: any valid JSON produces three fields, and anything
  # that is not a string — an object, an array, a number, a null, or a body that
  # is not an object at all — produces an empty one. A field of the wrong type is
  # then malformed by the check that already exists, instead of erroring here and
  # being reported as a failure to reach GitHub.
  out="$(gh api --hostname "$host" "repos/$nwo" \
    --jq '[.full_name?, .default_branch?, .updated_at?] | map(if type == "string" then . else "" end) | @tsv' 2>&1)" || rc=$?
  FACTS_NODE="$out"
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

# facts_graph_node <locator> <number> — ONE read of an ISSUE's native
# relationships.
#
# The root is an issue, and that is a property of GitHub rather than a
# simplification: the schema gives `parent`, `subIssues` and `blockedBy` to
# Issue and to nothing else, so a pull request has no native graph to report.
#
# Asking for the pull request in the SAME query does not work — GitHub reports a
# legitimately-absent alternative as a NOT_FOUND entry in `errors`, which would
# make every issue's graph refuse. So the kinds are told apart only where the
# issue turned out to be absent, by one targeted read, and the normal path stays
# a single request. Sets FACTS_NODE to TSV rows and returns 0, or sets it to the
# failure output and returns non-zero.
#
# Rows: "self <number> <updatedAt>", then "parent|child|blocker <number> <state>
# <updatedAt> <owner/name>" per related node, then "truncated <which>" for any
# relationship list GitHub could not return whole.
#
# The root's own state is neither read nor projected: this class carries the
# state of each RELATION, and the work unit's own belongs to another fact. An
# unused field that could gate the fact is worse than no field at all.
#
# The root's own number is carried so the caller can check that the node
# returned is the node asked for.
#
# One request for the whole graph, for the same reason the repository fact makes
# one: a request per relationship could observe the graph in three states, and
# since the model wants a version per invalidator, each of those reads would have
# to be re-read to stay mutually consistent.
#
# `__typename` is carried and checked rather than assumed. The invalidator form
# differs for an issue and a pull request (R14) and a compiler that guessed would
# emit a token naming the wrong kind of node.
facts_graph_node() {
  local locator="$1" number="$2" host="${1%%/*}" nwo="${1#*/}" out rc=0
  FACTS_API_CALLS=$(( FACTS_API_CALLS + 1 ))
  out="$(gh api graphql --hostname "$host" \
    -F owner="${nwo%%/*}" -F name="${nwo##*/}" -F number="$number" -f query='
    query($owner:String!,$name:String!,$number:Int!){
      repository(owner:$owner,name:$name){
        issue(number:$number){
          number updatedAt
          parent{ __typename number state updatedAt repository{ nameWithOwner } }
          subIssues(first:100){ pageInfo{ hasNextPage } nodes{ __typename number state updatedAt repository{ nameWithOwner } } }
          blockedBy(first:100){ pageInfo{ hasNextPage } nodes{ __typename number state updatedAt repository{ nameWithOwner } } }
        }
      }
    }' --jq '
    # A GraphQL reply can carry errors beside partial data, and a null list is
    # not an empty one. Both are refused here rather than projected into rows
    # that would read as a complete graph with no relationships.
    #
    # hasNextPage is required to be a BOOLEAN, not merely present: a pageInfo
    # that does not say whether more pages exist has not told us the list is
    # complete, and absence of a completeness signal is not a completeness
    # signal.
    if has("errors") then (["errored"] | @tsv)
    # Only an explicitly present, null `issue` is GitHub saying there is no such
    # issue. A missing `data`, a missing or null `repository`, or no `issue` key
    # at all are replies that did not answer the question — and calling those
    # absence produces a confident wrong reason two steps later.
    elif (.data | type) != "object" then (["partial"] | @tsv)
    elif (.data.repository | type) != "object" then (["partial"] | @tsv)
    elif (.data.repository | has("issue") | not) then (["partial"] | @tsv)
    elif .data.repository.issue == null then (["absent"] | @tsv)
    elif (.data.repository.issue
          | ((.number | type) != "number") or (.updatedAt == null)
            # `parent` gets the same rule as every other relationship field: a
            # reply that omits it has not said the work unit has no parent.
            or (has("parent") | not)
            or ((.parent | type) as $pt | $pt != "object" and $pt != "null")
            or ((.subIssues.nodes | type) != "array")
            or ((.subIssues.pageInfo.hasNextPage | type) != "boolean")
            or ((.blockedBy.nodes | type) != "array")
            or ((.blockedBy.pageInfo.hasNextPage | type) != "boolean"))
      then (["partial"] | @tsv)
    else
      .data.repository.issue as $i
      |
        (["self", ($i.number | tostring), $i.updatedAt] | @tsv),
        (if $i.parent != null then
           ["parent", ($i.parent.number|tostring), $i.parent.state, $i.parent.updatedAt,
            $i.parent.repository.nameWithOwner, $i.parent.__typename] | @tsv
         else empty end),
        (if $i.subIssues.pageInfo.hasNextPage then ["truncated", "children"] | @tsv else empty end),
        ($i.subIssues.nodes[] | ["child", (.number|tostring), .state, .updatedAt,
                                 .repository.nameWithOwner, .__typename] | @tsv),
        (if $i.blockedBy.pageInfo.hasNextPage then ["truncated", "blockers"] | @tsv else empty end),
        ($i.blockedBy.nodes[] | ["blocker", (.number|tostring), .state, .updatedAt,
                                 .repository.nameWithOwner, .__typename] | @tsv)
    end' 2>&1)" || rc=$?
  # A work unit that does not exist is not a transport failure. GraphQL reports
  # it as a NOT_FOUND error and gh exits non-zero, so without this the absent
  # path is unreachable and a missing issue reads as an unreadable source —
  # which would send a caller to check access it has.
  if [ "$rc" -ne 0 ]; then
    case "$out" in
      *"Could not resolve to an Issue"*) FACTS_NODE="absent"; return 0 ;;
    esac
  fi
  FACTS_NODE="$out"
  return "$rc"
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
# relationship entry as JSON, and its invalidator token, separated by a tab.
# Returns non-zero when the node cannot be named canonically, so the caller
# refuses rather than emitting a locator outside the grammar.
facts_graph_entry() {
  local host="$1" number="$2" state="$3" nwo="$4" typename="$5" wu kind st
  case "$typename" in
    Issue)       kind=issue ;;
    PullRequest) kind=pull_request ;;
    *)           return 1 ;;
  esac
  st="$(facts_state_canonical "$state")" || return 1
  wu="$(printf '%s/%s#%s' "$host" "${nwo,,}" "$number")"
  facts_canonical "$FACTS_RE_WORK_UNIT" "$FACTS_CON_WORK_UNIT" "$wu" || return 1
  printf '{"kind":"%s","id":"%s","state":"%s"}\t%s:%s' \
    "$kind" "$(json_escape "$wu")" "$st" "$kind" "$(json_escape "$wu")"
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

  facts_graph_node "$locator" "$number" || {
    FACTS_REFUSED="$(facts_unreadable_reason "$FACTS_NODE")"; return 3; }

  case "$FACTS_NODE" in
    absent*)
      # No issue by that number. One targeted read then says whether the number
      # names a pull request, because "that is a pull request" and "there is no
      # such work unit" send a caller to different places. A pull request HAS no
      # native graph — the schema gives those fields to Issue alone — and the
      # model offers no conforming fact to say so: `graph` admits ESTABLISHED,
      # UNKNOWN and CONFLICT, and NOT_APPLICABLE belongs to the HEAD-bound
      # classes. So this is a refusal with an accurate reason, not a fact.
      FACTS_API_CALLS=$(( FACTS_API_CALLS + 1 ))
      local probe prc=0
      # The projection asks for a NUMBER: `jq -r .number` would print a string
      # "733" indistinguishably from the integer 733, and a reply that names its
      # number as a string has not answered in the shape the API defines.
      probe="$(gh api --hostname "${locator%%/*}" "repos/${locator#*/}/pulls/$number" \
        --jq 'select((.number | type) == "number") | .number' 2>&1)" || prc=$?
      # A zero exit is not proof: `gh --jq .number` exits zero for a null or
      # missing field, and a reply naming a DIFFERENT pull request is not this
      # work unit. The probe must return this number, as a number.
      if [ "$prc" -eq 0 ] && [ "$probe" = "$number" ]; then
        FACTS_REFUSED="a pull request has no native graph"
      elif [ "$prc" -eq 0 ]; then
        FACTS_REFUSED="malformed"
      else
        # Absence is a claim about the world; failing to look is not. A real 404
        # means no pull request either, so the work unit is genuinely absent —
        # the ladder maps that to not-found. A 401, a rate limit or a transport
        # error keeps its own reason instead of asserting the work unit does not
        # exist, which would send a caller to create something that may be there.
        FACTS_REFUSED="$(facts_unreadable_reason "$probe")"
      fi
      return 3 ;;
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
  truncated="$(printf '%s' "$FACTS_NODE" | awk -F'\t' '$1 == "truncated" { print $2 }' \
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
  local inv="issue:$wu" vers="" kind line f1 f2 f3 f4 f5 f6 entry tok
  # The node returned must be the node asked for. Without this a response naming
  # a different issue would compile that issue's version and relationships under
  # this work unit's identity — one node wearing another's name, which is the
  # failure the identity discipline exists to prevent.
  local self_number
  self_number="$(printf '%s' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $2; exit }')"
  if [ "$self_number" != "$number" ]; then
    FACTS_REFUSED="malformed"
    return 3
  fi
  self_version="$(printf '%s' "$FACTS_NODE" | awk -F'\t' '$1 == "self" { print $3; exit }')"
  if [ -z "$self_version" ] || ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$self_version"; then
    FACTS_REFUSED="malformed"
    return 3
  fi
  vers='"'"$(json_escape "$inv")"'":"'"$(json_escape "$self_version")"'"'

  # Only walked when the whole set was returned. A truncated read has no value to
  # build and no relationship it may claim to represent.
  while [ -z "$truncated" ] && IFS=$'\t' read -r f1 f2 f3 f4 f5 f6; do
    [ -n "$f1" ] || continue
    case "$f1" in
      self|truncated) continue ;;
      parent|child|blocker)
        entry="$(facts_graph_entry "$host" "$f2" "$f3" "$f5" "$f6")" || {
          FACTS_REFUSED="malformed"; return 3; }
        tok="${entry#*$'\t'}"; entry="${entry%%$'\t'*}"
        if ! facts_canonical "$FACTS_RE_TIMESTAMP" "" "$f4"; then
          FACTS_REFUSED="malformed"; return 3
        fi

        # One node, one state and one observed version, wherever it appears. A
        # node reported twice consistently is one node in two relationships; a
        # node reported twice with different states or versions has no
        # representation in this schema.
        case " $known " in
          *" $tok=$entry@$f4 "*) ;;
          *" $tok="*) FACTS_REFUSED="malformed"; return 3 ;;
          *) known="$known $tok=$entry@$f4"
             vers="$vers,\"$(json_escape "$tok")\":\"$(json_escape "$f4")\""
             inv="$inv $tok" ;;
        esac

        # Membership is then per list, so a node that is both a child and a
        # blocker appears in both — one edge is not a duplicate of the other.
        case "$f1" in
          parent)
            case " $seen_parent " in *" $tok "*) continue ;; esac
            seen_parent="$seen_parent $tok"; parent="$entry" ;;
          child)
            case " $seen_child " in *" $tok "*) continue ;; esac
            seen_child="$seen_child $tok"; kids="${kids:+$kids,}$entry" ;;
          blocker)
            case " $seen_blocker " in *" $tok "*) continue ;; esac
            seen_blocker="$seen_blocker $tok"; blocks="${blocks:+$blocks,}$entry" ;;
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
    if facts_graph_fact "$locator" "$issue" "$observed"; then
      facts="${facts:+$facts,}$FACTS_JSON"
    else
      why="${why:+$why; }graph: $FACTS_REFUSED"
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
