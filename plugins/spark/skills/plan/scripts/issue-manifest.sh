#!/usr/bin/env bash
# issue-manifest.sh — create and wire a whole slate of GitHub issues from one
# manifest, deterministically and resumably (plan skill, #214).
#
# WHY: the plan skill used to narrate ~20 sequential `gh` calls per milestone
# slate — create each issue, then link sub-issues and blocked-by dependencies
# one at a time. That seam was stochastic (every run re-improvised the calls)
# and unresumable (a mid-slate failure left no record of what had landed).
# This helper replaces the narration: validate everything up front, execute
# with batched lookups, record every landing, and report only what is true.
#
# USAGE
#   issue-manifest.sh [--dry-run] [--state FILE] [--fresh] MANIFEST
#
#   --dry-run   validate, then print the exact planned calls (format below)
#               and stop. Needs no network and no gh.
#   --state F   resume-state path (default ./.issue-manifest.state).
#   --fresh     ignore — and, on a live run, overwrite — existing state. This
#               forgets prior landings and CAN double-create; explicit only.
#
# MANIFEST — line-oriented, tab-separated, '#'-comment and blank-line
# tolerant. Three record types:
#
#   issue <TAB> KEY <TAB> title <TAB> labels,csv <TAB> milestone-title <TAB> body-file
#   subissue  <TAB> PARENT_REF <TAB> CHILD_REF
#   blockedby <TAB> ISSUE_REF  <TAB> BLOCKER_REF
#
#   KEY         manifest-local name ([A-Za-z0-9_-]+) for a not-yet-created issue.
#   REF         a KEY defined by an `issue` record, or `#N` for an issue that
#               already exists on GitHub.
#   labels,csv  may be empty; every named label must already exist in the repo.
#   milestone   may be empty; at most ONE distinct title per manifest, and it
#               must already exist — the helper assigns, it never creates.
#   body-file   required; a relative path resolves against the manifest's dir.
#
# VALIDATION runs fully before any call. Rejected (exit 2, nothing touched):
# unknown record type, wrong field count, empty/malformed/duplicate KEY, empty
# title, missing body file, two different milestone titles, a link ref that is
# neither `#N` nor a defined KEY, self-links, duplicate links.
#
# EXECUTION — call count grows with mutations, never with lookups:
#   lookups (at most 3 for the whole slate):
#     GET  repos/{owner}/{repo}/milestones?state=all&per_page=100  (title -> number)
#     GET  repos/{owner}/{repo}/labels?per_page=100                (verify labels)
#     GraphQL aliased issue(number:N){fullDatabaseId}              (ids of #N refs)
#   mutations (one per manifest record):
#     POST repos/{owner}/{repo}/issues                                  (create)
#     POST repos/{owner}/{repo}/issues/{n}/sub_issues            -F sub_issue_id=ID
#     POST repos/{owner}/{repo}/issues/{n}/dependencies/blocked_by -F issue_id=ID
#   Each endpoint lives in exactly one api_* function so a shape change is a
#   one-line fix. API errors surface verbatim; the first failure stops the run
#   with a truthful report and resume guidance. Nothing is ever retried
#   silently — a blind retry that raced a success could double-create.
#
# STATE FILE — append-only, one line as each mutation lands:
#     created <TAB> KEY <TAB> number <TAB> id
#     wired   <TAB> subissue|blockedby <TAB> REF <TAB> REF
# On rerun, records already in state are skipped and reported as
# "skip: ... (state)", so rerunning the same command resumes a failed run.
#
# DRY-RUN PLAN — deterministic, one line per lookup/mutation:
#     lookup: milestones GET ... resolve "TITLE"
#     lookup: labels GET ... verify a,b
#     lookup: ids GraphQL issue fullDatabaseId for #N ...
#     create: KEY POST repos/{owner}/{repo}/issues title="..." labels="..." milestone="..." body=FILE
#     wire: subissue P<-C POST repos/{owner}/{repo}/issues/NUM/sub_issues -F sub_issue_id=ID
#     wire: blockedby I<-B POST repos/{owner}/{repo}/issues/NUM/dependencies/blocked_by -F issue_id=ID
#     skip: ... (state)
#     dry-run: X create(s), Y wire(s); Z skip(s); no calls made
# Numbers/ids already known (an existing #N, or a key in state) print
# literally; the rest print as <REF.number> / <REF.id> placeholders that the
# live run resolves as creations land.
#
# SCOPE: the helper wires, it does not govern — it never closes, comments on,
# edits, or relabels an issue it did not just create.
#
# Exit codes: 0 complete, 1 partial failure (resumable), 2 invalid manifest or
# usage. gh (GitHub CLI) is required for live runs only; its embedded --jq
# does all JSON parsing, so neither jq nor python3 is needed.
#
# The pure functions below are factored out and main is source-guarded so the
# offline suite (tests/test-issue-manifest.sh) can exercise validation and the
# call plan with zero side effects.

# --- manifest parsing --------------------------------------------------------

# Normalize the manifest: drop comments/blanks, prefix line number and field
# count, and swap the tab separator for \037 — `read` treats tabs as
# collapsible IFS whitespace, which would eat legitimate empty fields.
im_records() { # <manifest-file>
  awk 'BEGIN { FS = "\t" }
    /^[[:space:]]*(#|$)/ { next }
    {
      out = NR "\037" NF
      for (i = 1; i <= NF; i++) out = out "\037" $i
      print out
    }
  ' "$1"
}

# The KEYs every well-formed issue record defines, newline-delimited and
# newline-fenced so membership is an exact-string check.
im_keys() { # <manifest-file>
  printf '\n%s\n' "$(im_records "$1" \
    | awk 'BEGIN { FS = "\037" } $3 == "issue" && $4 ~ /^[A-Za-z0-9_-]+$/ { print $4 }')"
}

im_ref_ok() { # <ref> <keys-fenced-list> — 0 iff ref is #N or a defined KEY
  case "$1" in
    '#'*) case "${1#'#'}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac ;;
    *)    case "$2" in *$'\n'"$1"$'\n'*) return 0 ;; *) return 1 ;; esac ;;
  esac
}

# --- validation (pure; prints one "invalid: ..." line per problem) -----------

im_validate() { # <manifest-file> — rc 1 and a report if anything is wrong
  local manifest="$1" mdir records keys errors=0
  local ln nf type f1 f2 f3 f4 f5 seen=$'\n' milestone="" linksigs=$'\n' bp sig
  mdir="$(cd "$(dirname "$manifest")" && pwd)"
  records="$(im_records "$manifest")"
  # Re-fence: command substitution strips the trailing newline, which would
  # unfence the LAST key and make membership checks miss it.
  keys="$(im_keys "$manifest")"$'\n'

  while IFS=$'\037' read -r ln nf type f1 f2 f3 f4 f5; do
    [ -n "$ln" ] || continue
    case "$type" in
      issue)
        if [ "$nf" -ne 6 ]; then
          echo "invalid: line $ln: issue record needs 6 tab-separated fields, got $nf"
          errors=$((errors + 1)); continue
        fi
        case "$f1" in
          '') echo "invalid: line $ln: issue KEY is empty"; errors=$((errors + 1)) ;;
          *[!A-Za-z0-9_-]*)
            echo "invalid: line $ln: issue KEY '$f1' has characters outside [A-Za-z0-9_-]"
            errors=$((errors + 1)) ;;
          *)
            case "$seen" in
              *$'\n'"$f1"$'\n'*)
                echo "invalid: line $ln: duplicate KEY '$f1'"; errors=$((errors + 1)) ;;
              *) seen="${seen}${f1}"$'\n' ;;
            esac ;;
        esac
        if [ -z "$f2" ]; then
          echo "invalid: line $ln: empty title"; errors=$((errors + 1))
        fi
        if [ -z "$f5" ]; then
          echo "invalid: line $ln: missing body file path"; errors=$((errors + 1))
        else
          bp="$f5"; case "$bp" in /*) ;; *) bp="$mdir/$bp" ;; esac
          if [ ! -f "$bp" ]; then
            echo "invalid: line $ln: body file not found: $f5"; errors=$((errors + 1))
          fi
        fi
        if [ -n "$f4" ]; then
          if [ -z "$milestone" ]; then
            milestone="$f4"
          elif [ "$milestone" != "$f4" ]; then
            echo "invalid: line $ln: milestone '$f4' conflicts with '$milestone' — one milestone per manifest"
            errors=$((errors + 1))
          fi
        fi
        ;;
      subissue|blockedby)
        if [ "$nf" -ne 3 ]; then
          echo "invalid: line $ln: $type record needs 3 tab-separated fields, got $nf"
          errors=$((errors + 1)); continue
        fi
        local r
        for r in "$f1" "$f2"; do
          if ! im_ref_ok "$r" "$keys"; then
            echo "invalid: line $ln: ref '$r' is neither #N nor a KEY defined by an issue record"
            errors=$((errors + 1))
          fi
        done
        if [ "$f1" = "$f2" ]; then
          echo "invalid: line $ln: self-link ($type $f1<-$f2)"; errors=$((errors + 1))
        fi
        sig="$type/$f1/$f2"
        case "$linksigs" in
          *$'\n'"$sig"$'\n'*)
            echo "invalid: line $ln: duplicate link ($type $f1<-$f2)"; errors=$((errors + 1)) ;;
          *) linksigs="${linksigs}${sig}"$'\n' ;;
        esac
        ;;
      *)
        echo "invalid: line $ln: unknown record type '$type'"; errors=$((errors + 1))
        ;;
    esac
  done <<< "$records"

  [ "$errors" -eq 0 ]
}

# --- resume state -------------------------------------------------------------

im_state_created() { # <state-file> <key> -> "number<TAB>id" (empty if unknown)
  if [ -n "$1" ] && [ -f "$1" ]; then
    awk -v k="$2" 'BEGIN { FS = "\t" } $1 == "created" && $2 == k { print $3 "\t" $4; exit }' "$1"
  fi
}

im_state_wired() { # <state-file> <type> <a> <b> — 0 iff this link already landed
  [ -n "$1" ] && [ -f "$1" ] || return 1
  awk -v t="$2" -v a="$3" -v b="$4" 'BEGIN { FS = "\t" }
    $1 == "wired" && $2 == t && $3 == a && $4 == b { found = 1; exit }
    END { exit !found }' "$1"
}

# --- pending-work analyzer ----------------------------------------------------

# The single source of truth for what a run would do: one \037-separated action
# per line — lookups first, then creates, then wires, manifest order preserved
# within each group. im_plan renders this stream and im_execute executes it, so
# the dry-run plan and the live call sequence cannot drift apart.
#   lookup-ms \037 TITLE            lookup-labels \037 a,b       lookup-ids \037 N N
#   create \037 KEY \037 title \037 labels \037 ms \037 abs-body-path
#   skip-create \037 KEY \037 number
#   wire \037 type \037 REF \037 REF          skip-wire \037 type \037 REF \037 REF
im_pending() { # <manifest-file> <state-file-or-empty>
  local manifest="$1" state="${2:-}" mdir records
  local ln nf type f1 f2 f3 f4 f5 st bp
  local need_ms="" need_labels="" need_ids="" creates="" wires=""
  mdir="$(cd "$(dirname "$manifest")" && pwd)"
  records="$(im_records "$manifest")"

  while IFS=$'\037' read -r ln nf type f1 f2 f3 f4 f5; do
    [ -n "$ln" ] || continue
    case "$type" in
      issue)
        st="$(im_state_created "$state" "$f1")"
        if [ -n "$st" ]; then
          creates="${creates}skip-create"$'\037'"$f1"$'\037'"${st%%$'\t'*}"$'\n'
        else
          bp="$f5"; case "$bp" in /*) ;; *) bp="$mdir/$bp" ;; esac
          creates="${creates}create"$'\037'"$f1"$'\037'"$f2"$'\037'"$f3"$'\037'"$f4"$'\037'"$bp"$'\n'
          if [ -n "$f4" ]; then need_ms="$f4"; fi
          if [ -n "$f3" ]; then need_labels="${need_labels}${f3},"; fi
        fi
        ;;
      subissue|blockedby)
        if im_state_wired "$state" "$type" "$f1" "$f2"; then
          wires="${wires}skip-wire"$'\037'"$type"$'\037'"$f1"$'\037'"$f2"$'\n'
        else
          wires="${wires}wire"$'\037'"$type"$'\037'"$f1"$'\037'"$f2"$'\n'
          # Only the second ref is the API object (sub_issue_id / issue_id) and
          # so needs a database id; an existing #N there must be looked up.
          case "$f2" in '#'*) need_ids="${need_ids}${f2#'#'}"$'\n' ;; esac
        fi
        ;;
    esac
  done <<< "$records"

  if [ -n "$need_ms" ]; then printf 'lookup-ms\037%s\n' "$need_ms"; fi
  if [ -n "$need_labels" ]; then
    printf 'lookup-labels\037%s\n' \
      "$(printf '%s' "$need_labels" | tr ',' '\n' | grep -v '^[[:space:]]*$' | sort -u | paste -sd, -)"
  fi
  if [ -n "$need_ids" ]; then
    printf 'lookup-ids\037%s\n' \
      "$(printf '%s' "$need_ids" | sort -n -u | tr '\n' ' ' | sed 's/ $//')"
  fi
  printf '%s' "$creates"
  printf '%s' "$wires"
}

# Render a ref's issue number / database id for the plan: literal when already
# known (an existing #N, or a key recorded in state), a placeholder otherwise.
im_plan_num() { # <ref> <state-file-or-empty>
  local st
  case "$1" in '#'*) printf '%s' "${1#'#'}"; return 0 ;; esac
  st="$(im_state_created "${2:-}" "$1")"
  if [ -n "$st" ]; then printf '%s' "${st%%$'\t'*}"; else printf '<%s.number>' "$1"; fi
}

im_plan_id() { # <ref> <state-file-or-empty>
  local st
  case "$1" in '#'*) printf '<%s.id>' "$1"; return 0 ;; esac
  st="$(im_state_created "${2:-}" "$1")"
  if [ -n "$st" ]; then printf '%s' "${st#*$'\t'}"; else printf '<%s.id>' "$1"; fi
}

im_plan() { # <manifest-file> <state-file-or-empty> — print the dry-run plan
  local manifest="$1" state="${2:-}" pending
  local a b c d e f n ncreate=0 nwire=0 nskip=0 refs
  pending="$(im_pending "$manifest" "$state")"

  while IFS=$'\037' read -r a b c d e f; do
    [ -n "$a" ] || continue
    case "$a" in
      lookup-ms)
        echo "lookup: milestones GET repos/{owner}/{repo}/milestones?state=all&per_page=100 resolve \"$b\"" ;;
      lookup-labels)
        echo "lookup: labels GET repos/{owner}/{repo}/labels?per_page=100 verify $b" ;;
      lookup-ids)
        refs=""
        for n in $b; do refs="${refs}#$n "; done
        echo "lookup: ids GraphQL issue fullDatabaseId for ${refs% }" ;;
      create)
        ncreate=$((ncreate + 1))
        echo "create: $b POST repos/{owner}/{repo}/issues title=\"$c\" labels=\"$d\" milestone=\"$e\" body=$f" ;;
      skip-create)
        nskip=$((nskip + 1))
        echo "skip: $b = exists #$c (state)" ;;
      wire)
        nwire=$((nwire + 1))
        if [ "$b" = "subissue" ]; then
          echo "wire: subissue $c<-$d POST repos/{owner}/{repo}/issues/$(im_plan_num "$c" "$state")/sub_issues -F sub_issue_id=$(im_plan_id "$d" "$state")"
        else
          echo "wire: blockedby $c<-$d POST repos/{owner}/{repo}/issues/$(im_plan_num "$c" "$state")/dependencies/blocked_by -F issue_id=$(im_plan_id "$d" "$state")"
        fi ;;
      skip-wire)
        nskip=$((nskip + 1))
        echo "skip: $b $c<-$d (state)" ;;
    esac
  done <<< "$pending"

  echo "dry-run: $ncreate create(s), $nwire wire(s); $nskip skip(s); no calls made"
}

# --- GitHub endpoints (one function per endpoint; adjust shapes here) ---------
# gh's {owner}/{repo} placeholders resolve from the current repo's remote; its
# embedded --jq does the JSON parsing, so no external jq is needed.

api_list_milestones() { # -> "number<TAB>title" lines
  gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" --paginate \
    --jq '.[] | "\(.number)\t\(.title)"'
}

api_list_labels() { # -> one label name per line
  gh api "repos/{owner}/{repo}/labels?per_page=100" --paginate --jq '.[].name'
}

api_create_issue() { # <title> <labels-csv> <milestone-number-or-empty> <body-file> -> "number<TAB>id"
  local args=("repos/{owner}/{repo}/issues" -X POST -f "title=$1" -F "body=@$4") l
  while IFS= read -r l; do
    if [ -n "$l" ]; then args+=(-f "labels[]=$l"); fi
  done <<< "$(printf '%s' "$2" | tr ',' '\n')"
  if [ -n "$3" ]; then args+=(-F "milestone=$3"); fi
  gh api "${args[@]}" --jq '"\(.number)\t\(.id)"'
}

api_wire_subissue() { # <parent-number> <child-id>
  gh api -X POST "repos/{owner}/{repo}/issues/$1/sub_issues" -F "sub_issue_id=$2"
}

api_wire_blockedby() { # <issue-number> <blocker-id>
  gh api -X POST "repos/{owner}/{repo}/issues/$1/dependencies/blocked_by" -F "issue_id=$2"
}

api_resolve_existing() { # <number>... -> "number<TAB>id" lines, ONE call
  local q="query(\$owner: String!, \$name: String!) { repository(owner: \$owner, name: \$name) {" n
  for n in "$@"; do q="$q i$n: issue(number: $n) { number fullDatabaseId }"; done
  q="$q } }"
  gh api graphql -F owner=':owner' -F name=':repo' -f "query=$q" \
    --jq '.data.repository | to_entries[] | select(.value != null) | "\(.value.number)\t\(.value.fullDatabaseId)"'
}

# --- live execution ------------------------------------------------------------

# Truthful failure epilogue: the verbatim error, the tally of what actually
# landed, and how to resume. Never retries — state already records every
# landing, so rerunning the same command skips them.
im_fail() { # <step> <verbatim-error> <created> <wired> <skipped> <state-path>
  echo "failed: $1"
  if [ -n "$2" ]; then printf '%s\n' "$2" | sed 's/^/  /'; fi
  echo "report: created $3, wired $4, skipped $5, failed 1"
  echo "resume: fix the cause and rerun the same command — state at $6 skips what already landed"
}

# Resolve a ref's issue number / database id from the run's resolved map
# (space-separated "ref number id" lines, dynamically scoped from im_execute).
im_num_of() { # <ref>
  case "$1" in '#'*) printf '%s' "${1#'#'}"; return 0 ;; esac
  awk -v r="$1" '$1 == r { print $2; exit }' <<< "$resolved"
}

im_id_of() { # <ref>
  awk -v r="$1" '$1 == r { print $3; exit }' <<< "$resolved"
}

im_execute() { # <manifest-file> <state-file> <fresh-0-or-1>
  local manifest="$1" state="$2" fresh="$3"
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh (GitHub CLI) is required for a live run and was not found — install gh, or preview with --dry-run" >&2
    return 2
  fi

  local st_prior="$state"
  if [ "$fresh" -eq 1 ]; then
    st_prior=""
    : > "$state"   # --fresh: prior landings are deliberately forgotten
  fi

  local pending resolved="" ms_number="" created=0 wired=0 skipped=0
  local act b c d e f out errf n num id lab missing msn
  pending="$(im_pending "$manifest" "$st_prior")"
  if [ -n "$st_prior" ] && [ -f "$st_prior" ]; then
    # Preload prior landings so wiring can reference skip-created keys.
    resolved="$(awk 'BEGIN { FS = "\t" } $1 == "created" { print $2, $3, $4 }' "$st_prior")"$'\n'
  fi
  errf="$(mktemp)"
  # shellcheck disable=SC2064 — expand errf now; it never changes.
  trap "rm -f '$errf'" RETURN

  while IFS=$'\037' read -r act b c d e f; do
    [ -n "$act" ] || continue
    case "$act" in
      lookup-ms)
        if ! out="$(api_list_milestones 2>"$errf")"; then
          im_fail "listing milestones (GET repos/{owner}/{repo}/milestones)" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state"; return 1
        fi
        ms_number="$(printf '%s\n' "$out" | awk -v t="$b" 'BEGIN { FS = "\t" } $2 == t { print $1; exit }')"
        if [ -z "$ms_number" ]; then
          im_fail "resolving milestone \"$b\" — not found on GitHub; create it first (the helper assigns milestones, it never creates them)" "" \
            "$created" "$wired" "$skipped" "$state"; return 1
        fi
        echo "resolved: milestone \"$b\" -> $ms_number"
        ;;
      lookup-labels)
        if ! out="$(api_list_labels 2>"$errf")"; then
          im_fail "listing labels (GET repos/{owner}/{repo}/labels)" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state"; return 1
        fi
        missing=""
        while IFS= read -r lab; do
          if [ -n "$lab" ] && ! printf '%s\n' "$out" | grep -Fxq -- "$lab"; then
            missing="${missing}${lab} "
          fi
        done <<< "$(printf '%s' "$b" | tr ',' '\n')"
        if [ -n "$missing" ]; then
          im_fail "verifying labels — not found on GitHub: ${missing% } (the helper never invents label taxonomies)" "" \
            "$created" "$wired" "$skipped" "$state"; return 1
        fi
        echo "resolved: labels $b"
        ;;
      lookup-ids)
        # shellcheck disable=SC2086 — $b is a space-separated number list.
        if ! out="$(api_resolve_existing $b 2>"$errf")"; then
          im_fail "resolving existing issue ids (GraphQL)" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state"; return 1
        fi
        for n in $b; do
          id="$(printf '%s\n' "$out" | awk -v n="$n" 'BEGIN { FS = "\t" } $1 == n { print $2; exit }')"
          if [ -z "$id" ]; then
            im_fail "resolving existing issue #$n — not found in this repo" "" \
              "$created" "$wired" "$skipped" "$state"; return 1
          fi
          resolved="${resolved}#$n $n $id"$'\n'
        done
        echo "resolved: ids for $(printf '#%s ' $b | sed 's/ $//')"
        ;;
      create)
        msn=""
        if [ -n "$e" ]; then msn="$ms_number"; fi
        if ! out="$(api_create_issue "$c" "$d" "$msn" "$f" 2>"$errf")"; then
          im_fail "creating $b (\"$c\")" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state"; return 1
        fi
        num="${out%%$'\t'*}"; id="${out#*$'\t'}"
        case "$num" in
          ''|*[!0-9]*)
            im_fail "parsing the create response for $b (expected \"number<TAB>id\")" "$out" \
              "$created" "$wired" "$skipped" "$state"; return 1 ;;
        esac
        printf 'created\t%s\t%s\t%s\n' "$b" "$num" "$id" >> "$state"
        resolved="${resolved}$b $num $id"$'\n'
        created=$((created + 1))
        echo "created: $b #$num"
        ;;
      skip-create)
        skipped=$((skipped + 1))
        echo "skip: $b = exists #$c (state)"
        ;;
      wire)
        num="$(im_num_of "$c")"; id="$(im_id_of "$d")"
        if [ -z "$num" ] || [ -z "$id" ]; then
          im_fail "wiring $b $c<-$d — unresolved ref (number='$num' id='$id'); state may be stale" "" \
            "$created" "$wired" "$skipped" "$state"; return 1
        fi
        if [ "$b" = "subissue" ]; then
          out="$(api_wire_subissue "$num" "$id" 2>"$errf")" || {
            im_fail "wiring subissue $c<-$d" "$(cat "$errf")" \
              "$created" "$wired" "$skipped" "$state"; return 1; }
        else
          out="$(api_wire_blockedby "$num" "$id" 2>"$errf")" || {
            im_fail "wiring blockedby $c<-$d" "$(cat "$errf")" \
              "$created" "$wired" "$skipped" "$state"; return 1; }
        fi
        printf 'wired\t%s\t%s\t%s\n' "$b" "$c" "$d" >> "$state"
        wired=$((wired + 1))
        echo "wired: $b $c<-$d"
        ;;
      skip-wire)
        skipped=$((skipped + 1))
        echo "skip: $b $c<-$d (state)"
        ;;
    esac
  done <<< "$pending"

  echo "report: created $created, wired $wired, skipped $skipped, failed 0"
}

# --- entry point ---------------------------------------------------------------

main() {
  set -euo pipefail
  local usage="usage: issue-manifest.sh [--dry-run] [--state FILE] [--fresh] MANIFEST"
  local dry=0 fresh=0 state="./.issue-manifest.state" manifest=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      --fresh)   fresh=1; shift ;;
      --state)
        [ $# -ge 2 ] || { echo "--state needs a file argument" >&2; echo "$usage" >&2; exit 2; }
        state="$2"; shift 2 ;;
      -h|--help) echo "$usage"; exit 0 ;;
      -*) echo "unknown argument: $1" >&2; echo "$usage" >&2; exit 2 ;;
      *)
        if [ -n "$manifest" ]; then echo "only one manifest is accepted" >&2; echo "$usage" >&2; exit 2; fi
        manifest="$1"; shift ;;
    esac
  done
  [ -n "$manifest" ] || { echo "$usage" >&2; exit 2; }
  [ -f "$manifest" ] || { echo "manifest not found: $manifest" >&2; exit 2; }

  # Validate everything before ANY call: an invalid manifest changes nothing.
  local verrs=""
  if ! verrs="$(im_validate "$manifest")"; then
    printf '%s\n' "$verrs"
    echo "invalid manifest — nothing was created or wired"
    exit 2
  fi

  if [ "$dry" -eq 1 ]; then
    local st="$state"
    if [ "$fresh" -eq 1 ]; then st=""; fi
    im_plan "$manifest" "$st"
    exit 0
  fi

  im_execute "$manifest" "$state" "$fresh"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
