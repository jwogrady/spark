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
  local locator="$1" number="$2" host="${1%%/*}" nwo="${1#*/}" out rc=0 rest
  FACTS_API_CALLS=$(( FACTS_API_CALLS + 1 ))
  out="$(gh api graphql --hostname "$host" \
    -F owner="${nwo%%/*}" -F name="${nwo##*/}" -F number="$number" -f query='
    query($owner:String!,$name:String!,$number:Int!){
      repository(owner:$owner,name:$name){
        issueOrPullRequest(number:$number){
          __typename
          ... on Issue {
            number updatedAt repository{ nameWithOwner }
            parent{ __typename number state updatedAt repository{ nameWithOwner } }
            subIssues(first:100){ pageInfo{ hasNextPage } nodes{ __typename number state updatedAt repository{ nameWithOwner } } }
            blockedBy(first:100){ pageInfo{ hasNextPage } nodes{ __typename number state updatedAt repository{ nameWithOwner } } }
          }
          ... on PullRequest {
            number updatedAt repository{ nameWithOwner }
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
    def ref_ok:
      obj
      and (.number | type) == "number" and (.number == (.number | floor))
      and (.__typename | type) == "string"
      and (.repository | obj) and (.repository.nameWithOwner | type) == "string";
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
      and (if .__typename == "PullRequest"
           then has("closingIssuesReferences") and (.closingIssuesReferences | closing_ok)
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
        (if $u.__typename == "PullRequest" then
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
    end' 2>&1)" || rc=$?
  # A work unit that does not exist is not a transport failure, and GraphQL
  # reports it as an error with a non-zero exit. Without this the absent path is
  # unreachable and a missing work unit reads as an unreadable source, sending a
  # caller to check access it already has.
  #
  # There is no structured error to prefer here: a NOT_FOUND at the node scope
  # is exactly the case where gh's own formatting collapses the GraphQL errors
  # array to this text on stderr before --jq ever runs, so the JSON path/type
  # this handler would rather key off never reaches the process. Text is what
  # was actually observed, so text is what is classified.
  #
  # The match is narrow on purpose, in two ways. GitHub phrases a REPOSITORY
  # failure the same way — "Could not resolve to a Repository with the name
  # ..." — so requiring "with the number of" (never present in that phrasing)
  # keeps an inaccessible or nonexistent repository from reading as "no work
  # unit by that number": a confident claim about a node in a repository that
  # was never read. And the number itself must match EXACTLY, not as a prefix:
  # a request for 73 must not be satisfied by an error naming 733, so the
  # digits are required to end where the requested number ends — a non-digit
  # or the end of the line — rather than merely begin the same way. Only the
  # node-scoped form, for the number actually asked for, says anything about
  # this work unit; a reply about another number is not an answer about this
  # one.
  if [ "$rc" -ne 0 ]; then
    case "$out" in
      *"Could not resolve to"*"with the number of $number"*)
        # The case pattern above only proved $number occurs somewhere after the
        # phrase — which a LONGER number satisfies too, since "73" is a prefix
        # of "733". Stripping the shortest match up through that phrase and
        # the requested digits leaves what GitHub wrote right after them; a
        # further digit there means the number actually named is longer than
        # the one asked for, so it is a reply about a different work unit.
        rest="${out#*"with the number of $number"}"
        case "$rest" in
          [0-9]*) ;;
          *) FACTS_NODE="absent"; return 0 ;;
        esac ;;
    esac
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

  # A truncated reference list is decided before the references are read, so a
  # shorter list can never be mistaken for the whole one.
  if printf '%s\n' "$FACTS_NODE" \
     | awk -F'\t' '$1 == "truncated" && $2 == "implements" { found = 1 } END { exit !found }'; then
    FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    FACTS_JSON="$head"'"UNKNOWN","detail":{"reason":"bounded","candidates":[]}'"$tail"
    return 0
  fi

  local implements="none" candidates="" n=0 row rnum rnwo rtype rwu
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    rnum="$(printf '%s' "$row" | cut -f2)"
    rnwo="$(printf '%s' "$row" | cut -f3)"
    rtype="$(printf '%s' "$row" | cut -f4)"
    # A closing reference is an ISSUE. A pull request cannot close a pull
    # request, so a reference returned as anything else is a reply this class
    # cannot read rather than a relationship it can record.
    [ "$rtype" = "Issue" ] || { FACTS_REFUSED="malformed"; return 3; }
    rwu="$(facts_unit_locator "$host" "$rnwo" "$rnum")" || {
      FACTS_REFUSED="malformed"; return 3; }
    n=$(( n + 1 ))
    implements="$rwu"
    candidates="${candidates:+$candidates,}\"$(json_escape "$rwu")\""
  done <<EOF
$(printf '%s\n' "$FACTS_NODE" | awk -F'\t' '$1 == "implements"')
EOF

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
