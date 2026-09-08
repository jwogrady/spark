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
#   * let an unreadable source read as a small success. Unreadable is UNKNOWN
#     with a reason, and the old value never survives as authority (F5).
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
    *) printf 'unreadable' ;;
  esac
}

# facts_repo_node — ONE read of the repository node. Sets FACTS_NODE to
# "<full_name>\t<default_branch>\t<updated_at>" and returns 0, or sets it to the
# failure output and returns non-zero.
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
  local out rc=0
  FACTS_API_CALLS=$(( FACTS_API_CALLS + 1 ))
  out="$(gh api 'repos/{owner}/{repo}' \
    --jq '[.full_name, .default_branch, .updated_at] | @tsv' 2>&1)" || rc=$?
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

# facts_repository_fact <locator> — sets FACTS_JSON to the repository.identity
# fact, whatever the outcome. There is always exactly one fact for the class;
# what varies is its status, never whether it was emitted.
#
# The identity is the repository the local remote names, canonicalized by
# repository.sh. The node read then says what GitHub currently calls it. When
# those disagree the fact is a CONFLICT naming both candidates (R8): a rename or
# a redirect is exactly the case where picking one would be the compiler
# inventing precedence the model does not define.
facts_repository_fact() {
  local locator="$1" rc=0 observed head tail
  observed="$(facts_now)"
  facts_repo_node || rc=$?
  head='{"schema_version":'"$FACTS_SCHEMA_VERSION"',"key":"repository.identity","class":"repository","status":'

  FACTS_EMITTED=$(( FACTS_EMITTED + 1 ))

  if [ "$rc" -ne 0 ]; then
    # An UNKNOWN still names the node it failed to read and lists it as an
    # invalidator, so the failure goes stale the moment that node changes. It
    # carries no value and no source version, because nothing was read (R6).
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    tail="$(facts_envelope_tail "$locator" "$observed" "")"
    FACTS_JSON="$head"'"UNKNOWN"'"$tail"',"detail":{"reason":"'"$(json_escape "$(facts_unreadable_reason "$FACTS_NODE")")"'","candidates":[]}}'
    return 0
  fi

  local full branch updated
  full="$(printf '%s' "$FACTS_NODE" | awk -F'\t' 'NR == 1 { print $1 }')"
  branch="$(printf '%s' "$FACTS_NODE" | awk -F'\t' 'NR == 1 { print $2 }')"
  updated="$(printf '%s' "$FACTS_NODE" | awk -F'\t' 'NR == 1 { print $3 }')"

  # A response that parsed but does not carry the fields is malformed, not a
  # smaller success: an empty default branch is not a repository with no trunk.
  if [ -z "$full" ] || [ -z "$branch" ] || [ -z "$updated" ]; then
    FACTS_UNKNOWN=$(( FACTS_UNKNOWN + 1 ))
    tail="$(facts_envelope_tail "$locator" "$observed" "")"
    FACTS_JSON="$head"'"UNKNOWN"'"$tail"',"detail":{"reason":"malformed","candidates":[]}}'
    return 0
  fi

  tail="$(facts_envelope_tail "$locator" "$observed" "$updated")"

  # GitHub compares owner and name case-insensitively, and so does the locator
  # now, so a case difference is not a disagreement. A different name is.
  local host="${locator%%/*}" nwo="${locator#*/}"
  if [ "${full,,}" != "$nwo" ]; then
    FACTS_JSON="$head"'"CONFLICT"'"$tail"',"detail":{"reason":"the repository names itself differently","candidates":["'"$(json_escape "$locator")"'","'"$(json_escape "$host/${full,,}")"'"]}}'
    return 0
  fi

  FACTS_JSON="$head"'"ESTABLISHED","value":{"id":"'"$(json_escape "$locator")"'","default_branch":"'"$(json_escape "$branch")"'"}'"$tail"'}'
}

# facts_record_telemetry — the compiler's efficiency observability, recorded
# only when a run is being observed, exactly like the runtime footprint. Five
# counts and nothing else: the facts themselves are this verb's output, and
# copying them into a telemetry value is the cost that contract refuses.
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
  local usage_line="usage: spark facts [--help]"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) echo "$usage_line"; return 0 ;;
      *) red "unknown option: $1"; echo "$usage_line"; return 1 ;;
    esac
  done

  local top; top="$(git_root)"
  if [ -z "$top" ]; then
    red "spark facts needs a git repo — run it from inside the project."
    return 1
  fi

  local locator
  locator="$(repo_locator_normalize "$(git -C "$top" remote get-url origin 2>/dev/null || true)")"
  # Without a locator the compiler cannot NAME the node it would read, so there
  # is no subject to be unknown about. That is not an UNKNOWN fact — an UNKNOWN
  # still identifies its node — so it is reported as not assessed and nothing is
  # emitted, rather than a fact whose identity was invented to fill the field.
  if [ -z "$locator" ]; then
    yellow "NOT ASSESSED — no origin remote, so this repository cannot be named"
    return 3
  fi

  facts_repository_fact "$locator"
  # The fragment shape: a bare list, never an object, so it can never be read as
  # the {observer, facts} snapshot a consumer is allowed to act on (R22).
  printf '[%s]\n' "$FACTS_JSON"
  facts_record_telemetry
}
