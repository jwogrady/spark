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
# STATE FILE records, appended as each mutation lands:
#   created <TAB> KEY       <TAB> number <TAB> id      (an issue)
#   created <TAB> ms:KEY    <TAB> number <TAB>         (a milestone)
#   wired   <TAB> subissue  <TAB> REF    <TAB> REF
#   wired   <TAB> blockedby <TAB> REF    <TAB> REF
#   wired   <TAB> update    <TAB> #N     <TAB> field   (one per updated field)
#
# RESUME-TRUTH LIMITS (stated, not hidden): state records what the CLIENT saw.
# Two windows exist where reality and state can diverge, and no retry policy
# can close them without server-side idempotency keys (GitHub has none for
# issue creation): (a) a create that succeeded server-side whose response was
# lost in transit is not in state — a rerun re-creates it; (b) a kill between
# a create's success and the state append does the same. Reruns therefore skip
# exactly what the state RECORDS, and the operator reconciles the rare
# ack-lost duplicate by hand. The helper never retries blindly, which is what
# keeps the common path double-create-free.
#
# MANIFEST — line-oriented, tab-separated, '#'-comment and blank-line
# tolerant. Three record types:
#
#   issue     <TAB> KEY <TAB> title <TAB> labels,csv <TAB> milestone <TAB> body-file
#   milestone <TAB> KEY <TAB> title <TAB> description
#   subissue  <TAB> PARENT_REF <TAB> CHILD_REF
#   blockedby <TAB> ISSUE_REF  <TAB> BLOCKER_REF [<TAB> reason]
#   order     <TAB> REF <TAB> position
#   update    <TAB> #N <TAB> title|labels|milestone|body-file <TAB> value
#   decision  <TAB> REF <TAB> question
#
#   KEY         manifest-local name ([A-Za-z0-9_-]+) for a not-yet-created
#               issue or milestone.
#   REF         a KEY defined by an `issue` record, or `#N` for an issue that
#               already exists on GitHub.
#   labels,csv  may be empty; every named label must already exist in the repo.
#   milestone   may be empty; a literal title, or a KEY a `milestone` record
#               defines. More than one milestone per manifest is allowed now
#               that a manifest can bring its own release scope.
#   body-file   required; a relative path resolves against the manifest's dir.
#
# THE NEW RECORDS, and why each exists rather than being folded into another:
#
#   milestone   a slate could not previously bring its own release scope —
#               milestones were lookup-only and a missing one was a hard error.
#   order       preferred delivery order needs its own home. Without one it gets
#               encoded as `blockedby`, and an edge added to express sequence
#               becomes a false prerequisite the codify preflight then reports
#               as a permanent blocker. A `blockedby` record whose optional
#               reason names order or sequence is REFUSED for the same reason.
#   update      an existing issue could only ever be a link target. Every
#               restructuring of this repository was therefore hand-applied.
#   decision    unresolved meaning has to be representable, and it refuses the
#               run rather than being applied around.
#
# VALIDATION runs fully before any call. Rejected (exit 2, nothing touched):
# unknown record type, wrong field count, empty/malformed/duplicate KEY, empty
# title, missing body file, a link ref that is neither `#N` nor a defined KEY,
# self-links, duplicate links, a duplicate order position or a ref ordered
# twice, an update to anything but an existing `#N`, an unknown update field, a
# `blockedby` declared as preferred order, and a DEPENDENCY CYCLE — which is
# structural: every issue in one is permanently unstartable, and the preflight
# would otherwise report each as blocked forever without naming the cause.
#
# Category and priority MEANING is validated by `spark plan validate`, which
# resolves them against the governance model. Structure is this script's;
# meaning belongs to the schema, and neither restates the other.
#
# EXECUTION — call count grows with mutations, never with lookups:
#   lookups (at most 3 for the whole slate):
#     GET  repos/{owner}/{repo}/milestones?state=all&per_page=100  (title -> number)
#     GET  repos/{owner}/{repo}/labels?per_page=100                (verify labels)
#     GraphQL aliased issue(number:N){fullDatabaseId}              (ids of #N refs)
#   mutations (one per manifest record):
#     POST  repos/{owner}/{repo}/milestones                       (create-ms)
#     PATCH repos/{owner}/{repo}/issues/{n}                          (update)
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

# The milestone KEYs a manifest defines, fenced the same way. Milestones used to
# be lookup-only — a title resolved to a number, and one that did not exist was
# a hard error — so a slate could never bring its own release scope with it.
im_ms_keys() { # <manifest-file>
  printf '\n%s\n' "$(im_records "$1" \
    | awk 'BEGIN { FS = "\037" } $3 == "milestone" && $4 ~ /^[A-Za-z0-9_-]+$/ { print $4 }')"
}

# im_issue_ref_ok <ref> — 0 iff <ref> is a canonical positive issue reference.
#
# THE one rule for "#N", so every record type that names an issue agrees. The
# `update` validator carried its own `'#'*` test that accepted any string
# starting with '#', so `#abc` validated locally and then became the live path
# repos/{owner}/{repo}/issues/abc — after the creates had already run (#515).
# `#0` was accepted here too: numerically a valid digit string, never a valid
# issue.
#
# Leading zeros are accepted (`#007` is issue 7); only a value that is actually
# zero is not. Signed forms need no separate case — '+' and '-' are non-digits.
im_issue_ref_ok() {
  local n="${1#'#'}" t
  case "$1" in '#'*) ;; *) return 1 ;; esac
  case "$n" in ''|*[!0-9]*) return 1 ;; esac
  # Positive, without arithmetic: strip leading zeros and require something left.
  t="$n"; while [ "${t#0}" != "$t" ]; do t="${t#0}"; done
  [ -n "$t" ] || return 1
  return 0
}

im_ref_ok() { # <ref> <keys-fenced-list> — 0 iff ref is #N or a defined KEY
  case "$1" in
    '#'*) im_issue_ref_ok "$1" ;;
    *)    case "$2" in *$'\n'"$1"$'\n'*) return 0 ;; *) return 1 ;; esac ;;
  esac
}

# --- validation (pure; prints one "invalid: ..." line per problem) -----------

im_validate() { # <manifest-file> — rc 1 and a report if anything is wrong
  local manifest="$1" mdir records keys errors=0
  local ln nf type f1 f2 f3 f4 f5 seen=$'\n' linksigs=$'\n' bp sig
  local msseen=$'\n' orderrefs=$'\n' mskeys edgelist="" 
  mdir="$(cd "$(dirname "$manifest")" && pwd)"
  records="$(im_records "$manifest")"
  # Re-fence: command substitution strips the trailing newline, which would
  # unfence the LAST key and make membership checks miss it.
  keys="$(im_keys "$manifest")"$'\n'
  mskeys="$(im_ms_keys "$manifest")"$'\n'

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
        # The milestone field is a literal title or a KEY a milestone record
        # defines. More than one milestone per manifest is now representable:
        # the old single-milestone rule existed because milestones were
        # lookup-only, so a slate could not bring its own release scope.
        ;;
      milestone)
        if [ "$nf" -ne 4 ]; then
          echo "invalid: line $ln: milestone record needs 4 tab-separated fields, got $nf"
          errors=$((errors + 1)); continue
        fi
        case "$f1" in
          '') echo "invalid: line $ln: milestone KEY is empty"; errors=$((errors + 1)) ;;
          *[!A-Za-z0-9_-]*)
            echo "invalid: line $ln: milestone KEY '$f1' has characters outside [A-Za-z0-9_-]"
            errors=$((errors + 1)) ;;
          *)
            case "$msseen" in
              *$'\n'"$f1"$'\n'*)
                echo "invalid: line $ln: duplicate milestone KEY '$f1'"; errors=$((errors + 1)) ;;
              *) msseen="${msseen}${f1}"$'\n' ;;
            esac ;;
        esac
        [ -n "$f2" ] || { echo "invalid: line $ln: milestone title is empty"; errors=$((errors + 1)); }
        ;;
      order)
        if [ "$nf" -ne 3 ]; then
          echo "invalid: line $ln: order record needs 3 tab-separated fields, got $nf"
          errors=$((errors + 1)); continue
        fi
        if ! im_ref_ok "$f1" "$keys"; then
          echo "invalid: line $ln: order ref '$f1' is neither #N nor a KEY defined by an issue record"
          errors=$((errors + 1))
        fi
        case "$f2" in
          ''|*[!0-9]*) echo "invalid: line $ln: order position '$f2' is not a number"
            errors=$((errors + 1)) ;;
        esac
        # Position uniqueness is checked per PARENT after the loop, not here.
        # Globally, two independent gates could not each declare a first child —
        # and preferred order is a fact about siblings, so a position only means
        # anything relative to the other children of the same parent (#518).
        case "$orderrefs" in
          *$'\n'"$f1"$'\n'*)
            echo "invalid: line $ln: '$f1' already has an order position"; errors=$((errors + 1)) ;;
          *) orderrefs="${orderrefs}${f1}"$'\n' ;;
        esac
        ;;
      update)
        if [ "$nf" -ne 4 ]; then
          echo "invalid: line $ln: update record needs 4 tab-separated fields, got $nf"
          errors=$((errors + 1)); continue
        fi
        # The same canonical rule as every other issue reference. An update
        # target that is locally, deterministically invalid must be rejected
        # BEFORE any call, or the creates land and the run fails half-done.
        if ! im_issue_ref_ok "$f1"; then
          echo "invalid: line $ln: update targets '$f1' — only an existing #N can be updated, where N is a positive issue number"
          errors=$((errors + 1))
        fi
        case "$f2" in
          title|labels|milestone|body-file) ;;
          *) echo "invalid: line $ln: update field '$f2' is not title|labels|milestone|body-file"
             errors=$((errors + 1)) ;;
        esac
        if [ -z "$f3" ]; then
          echo "invalid: line $ln: update value is empty — use an explicit value, never a blank"
          errors=$((errors + 1))
        elif [ "$f2" = "body-file" ]; then
          bp="$f3"; case "$bp" in /*) ;; *) bp="$mdir/$bp" ;; esac
          [ -f "$bp" ] || { echo "invalid: line $ln: update body file not found: $f3"
            errors=$((errors + 1)); }
        fi
        sig="update/$f1/$f2"
        case "$linksigs" in
          *$'\n'"$sig"$'\n'*)
            echo "invalid: line $ln: '$f2' is updated twice for $f1"; errors=$((errors + 1)) ;;
          *) linksigs="${linksigs}${sig}"$'\n' ;;
        esac
        ;;
      decision)
        if [ "$nf" -ne 3 ]; then
          echo "invalid: line $ln: decision record needs 3 tab-separated fields, got $nf"
          errors=$((errors + 1)); continue
        fi
        if ! im_ref_ok "$f1" "$keys"; then
          echo "invalid: line $ln: decision ref '$f1' is neither #N nor a KEY defined by an issue record"
          errors=$((errors + 1))
        fi
        [ -n "$f2" ] || { echo "invalid: line $ln: decision question is empty"; errors=$((errors + 1)); }
        ;;
      subissue|blockedby)
        # The optional reason belongs to blockedby only. Relaxing both meant a
        # subissue record with a stray trailing field passed validation and had
        # it silently discarded.
        if [ "$type" = "subissue" ] && [ "$nf" -ne 3 ]; then
          echo "invalid: line $ln: subissue record needs 3 tab-separated fields, got $nf"
          errors=$((errors + 1)); continue
        fi
        if [ "$type" = "blockedby" ] && [ "$nf" -ne 3 ] && [ "$nf" -ne 4 ]; then
          echo "invalid: line $ln: blockedby record needs 3 or 4 tab-separated fields, got $nf"
          errors=$((errors + 1)); continue
        fi
        # A blocked-by edge may state WHY it exists. Naming preferred order as
        # the reason is refused outright: order has its own record type, and an
        # edge added to express sequence becomes a false prerequisite that the
        # codify preflight then reports as a permanent blocker.
        if [ "$type" = "blockedby" ] && [ "$nf" -eq 4 ]; then
          # Matched loosely and case-insensitively: "ORDER", "Order",
          # "preferred order", and "ordering" all mean the same thing, and an
          # exact lowercase list let every one of them through to wire a real
          # prerequisite.
          #
          # STEMS, not whole words. `priorit` was already a stem but `sequence`
          # was not, so "for sequencing" — as natural a phrasing as any here —
          # passed straight through while "ordering" was caught. Found by the
          # #472 re-audit, which is exactly the inconsistency this list exists
          # to prevent.
          case "$(printf '%s' "$f3" | tr '[:upper:]' '[:lower:]')" in
            *order*|*sequenc*|*preferen*|*priorit*)
              echo "invalid: line $ln: blockedby $f1<-$f2 is declared as '$f3' — preferred order is not a prerequisite; use an order record"
              errors=$((errors + 1)) ;;
          esac
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
        [ "$type" = "blockedby" ] && edgelist="${edgelist}${f1}	${f2}
"
        ;;
      *)
        echo "invalid: line $ln: unknown record type '$type'"; errors=$((errors + 1))
        ;;
    esac
  done <<< "$records"

  # ORDER is scoped to a parent, and both facts it needs — the order records and
  # the hierarchy that gives them meaning — are only all known once every line
  # has been read. A `subissue` may follow the `order` it applies to.
  #
  # Two things are wrong globally and right per parent: a duplicate position
  # (two gates may each have a first child) and, before this, nothing at all
  # rejected a child attached to two parents, whose order parent is then
  # undecidable rather than merely ambiguous.
  local orderfindings
  orderfindings="$(printf '%s' "$records" | awk 'BEGIN { FS = "\037" }
    $3 == "subissue" { np[$5]++; par[$5] = par[$5] " " $4 }
    $3 == "order"    { pos[$4] = $5; seen[$4] = 1 }
    END {
      for (r in seen) {
        if (np[r] > 1) {
          printf "invalid: order ref %s is a sub-issue of more than one parent (%s), so its order parent cannot be determined\n", r, substr(par[r], 2)
          continue
        }
        # "No parent" is its own scope rather than an exemption. Such records are
        # unplaceable and reported as that at plan time, but two of them claiming
        # one position is still an authoring mistake, and it stops being visible
        # the moment the parents are added.
        p = (np[r] == 0) ? "" : substr(par[r], 2)
        k = p SUBSEP pos[r]
        if (k in taken) {
          if (p == "")
            printf "invalid: duplicate order position %s — both %s and %s claim it, and neither is a sub-issue of anything\n", pos[r], taken[k], r
          else
            printf "invalid: duplicate order position %s — both %s and %s claim it under parent %s\n", pos[r], taken[k], r, p
        } else taken[k] = r
      }
    }' | LC_ALL=C sort)"
  if [ -n "$orderfindings" ]; then
    printf '%s\n' "$orderfindings"
    errors=$((errors + $(printf '%s\n' "$orderfindings" | grep -c .)))
  fi

  # A dependency CYCLE is structural, so it belongs here rather than in a
  # caller: every issue in it is permanently unstartable, and the preflight
  # would report each one blocked forever without naming the cause. Peel off
  # whatever has no prerequisite; anything left is in, or behind, a cycle.
  local stuck
  stuck="$(printf '%s' "$edgelist" | awk -F'\t' '
    NF == 2 { indeg[$1]++; adj[$2] = adj[$2] " " $1; node[$1] = 1; node[$2] = 1 }
    END {
      for (v in node) if (!(v in indeg)) indeg[v] = 0
      changed = 1
      while (changed) {
        changed = 0
        for (v in node) {
          if (gone[v] || indeg[v] > 0) continue
          gone[v] = 1; changed = 1
          k = split(adj[v], a, " ")
          for (i = 1; i <= k; i++) if (a[i] != "") indeg[a[i]]--
        }
      }
      out = ""
      for (v in node) if (!gone[v]) out = out " " v
      if (out != "") print out
    }')"
  if [ -n "$stuck" ]; then
    echo "invalid: dependency cycle — these cannot be ordered:$stuck"
    errors=$((errors + 1))
  fi

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
  local mscreates="" updates="" decisions="" mstitle resolves="" orders="" 
  # Titles this manifest brings with it. An issue pointing at one of them must
  # not also trigger a lookup that hard-fails for "not found on GitHub" — the
  # create is the thing that makes it exist.
  local own_ms
  own_ms=$'\n'"$(awk 'BEGIN { FS = "\037" } $3 == "milestone" { print $4; print $5 }' \
    <<< "$(im_records "$manifest")")"$'\n'
  mdir="$(cd "$(dirname "$manifest")" && pwd)"
  records="$(im_records "$manifest")"

  while IFS=$'\037' read -r ln nf type f1 f2 f3 f4 f5; do
    [ -n "$ln" ] || continue
    case "$type" in
      milestone)
        # Resumable exactly like an issue: the state file records the number a
        # created milestone landed on, so a rerun assigns rather than duplicates.
        st="$(im_state_created "$state" "ms:$f1")"
        if [ -n "$st" ]; then
          # The TITLE has to travel with the skip. Without it a resumed run
          # seeded msmap with the KEY alone, while the lookup for the title was
          # suppressed (this manifest owns it) — so an issue referencing the
          # milestone by title could never be resolved again, and every rerun
          # died. That is the exact opposite of the resume contract.
          mscreates="${mscreates}skip-create-ms"$'\037'"$f1"$'\037'"${st%%$'\t'*}"$'\037'"$f2"$'\n'
        else
          mscreates="${mscreates}create-ms"$'\037'"$f1"$'\037'"$f2"$'\037'"$f3"$'\n'
        fi
        ;;
      issue)
        if [ -n "$f4" ]; then
          case "$own_ms" in
            *$'\n'"$f4"$'\n'*) resolves="${resolves}resolve-ms"$'\037'"$f4"$'\037'"milestone"$'\n' ;;
          esac
        fi
        st="$(im_state_created "$state" "$f1")"
        if [ -n "$st" ]; then
          creates="${creates}skip-create"$'\037'"$f1"$'\037'"${st%%$'\t'*}"$'\n'
        else
          bp="$f5"; case "$bp" in /*) ;; *) bp="$mdir/$bp" ;; esac
          creates="${creates}create"$'\037'"$f1"$'\037'"$f2"$'\037'"$f3"$'\037'"$f4"$'\037'"$bp"$'\n'
          case "$own_ms" in
            *$'\n'"$f4"$'\n'*) ;;                       # this manifest creates it
            *) [ -n "$f4" ] && need_ms="${need_ms}${f4}"$'\n' ;;
          esac
          if [ -n "$f3" ]; then need_labels="${need_labels}${f3},"; fi
        fi
        ;;
      update)
        # Keyed by target+field so a rerun that already applied it is skipped:
        # updating an existing issue has to be idempotent the same way creating
        # one is, or a resumed run would rewrite what it already wrote.
        if im_state_wired "$state" "update" "$f1" "$f2"; then
          updates="${updates}skip-update"$'\037'"$f1"$'\037'"$f2"$'\037'"$f3"$'\n'
        else
          bp="$f3"
          if [ "$f2" = "body-file" ]; then case "$bp" in /*) ;; *) bp="$mdir/$bp" ;; esac; fi
          updates="${updates}update"$'\037'"$f1"$'\037'"$f2"$'\037'"$bp"$'\n'
          if [ "$f2" = "labels" ]; then need_labels="${need_labels}${f3},"; fi
          if [ "$f2" = "milestone" ]; then
            case "$own_ms" in
              *$'\n'"$f3"$'\n'*) ;;
              *) need_ms="${need_ms}${f3}"$'\n' ;;
            esac
          fi
        fi
        ;;
      order)
        # Preferred order lives on GitHub as the sub-issue order under a parent
        # — the authority `spark next` reads to break a priority tie. Collected
        # here and applied after the wiring, once every child exists and is
        # attached; without that it was validated and then silently discarded,
        # while SKILL.md told the agent to use it.
        orders="${orders}${f2}	${f1}"$'\n'
        ;;
      decision)
        # An unresolved decision is not work to do — it is a reason not to act.
        decisions="${decisions}decision"$'\037'"$f1"$'\037'"$f2"$'\n'
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

  # ONE action for every title, so a single listing resolves them all. Emitting
  # one lookup per title meant an identical paginated GET per milestone, and
  # broke the header's "at most 3 lookups for the whole slate" promise.
  if [ -n "$need_ms" ]; then
    printf 'lookup-ms\037%s\n' \
      "$(printf '%s' "$need_ms" | awk 'NF' | LC_ALL=C sort -u | paste -sd'\036' -)"
  fi
  if [ -n "$need_labels" ]; then
    printf 'lookup-labels\037%s\n' \
      "$(printf '%s' "$need_labels" | tr ',' '\n' | grep -v '^[[:space:]]*$' | sort -u | paste -sd, -)"
  fi
  if [ -n "$need_ids" ]; then
    printf 'lookup-ids\037%s\n' \
      "$(printf '%s' "$need_ids" | sort -n -u | tr '\n' ' ' | sed 's/ $//')"
  fi
  printf '%s' "$decisions"
  printf '%s' "$(printf '%s' "$resolves" | awk 'NF' | sort -u)"
  [ -n "$resolves" ] && printf '\n'
  printf '%s' "$mscreates"
  printf '%s' "$creates"
  printf '%s' "$updates"
  printf '%s' "$wires"
  # Ordered by position, and only for a child the manifest actually attaches to
  # a parent: sub-issue order is the only place GitHub can hold this, so an
  # order record for an unattached issue has nowhere to go and says so.
  if [ -n "$orders" ]; then
    # `after_id` names the sibling to place this child behind, so the chain must
    # RESET at each parent. One global `prev` handed parent P2's first child an
    # `after_id` belonging to a child of P1 — a placement GitHub cannot make,
    # after the creates and wires had already landed (#518).
    #
    # Emitted grouped by parent, ascending position within the group, because
    # each placement references the sibling placed immediately before it.
    local pos ref parent prevs="" prev
    while IFS=$'\t' read -r parent pos ref; do
      [ -n "$ref" ] || continue
      if [ "$parent" = "-" ]; then
        printf 'order-unplaceable\037%s\037%s\n' "$ref" "$pos"
        continue
      fi
      prev="$(printf '%s' "$prevs" | awk -F'\t' -v p="$parent" 'NF == 2 && $1 == p { v = $2 } END { print v }')"
      printf 'order\037%s\037%s\037%s\037%s\n' "$parent" "$ref" "$pos" "$prev"
      prevs="${prevs}${parent}	${ref}
"
    done <<EOF_ORD
$(printf '%s' "$orders" | awk 'NF' \
  | awk -F'\t' -v recs="$records" '
      BEGIN {
        n = split(recs, rl, "\n")
        for (i = 1; i <= n; i++) {
          split(rl[i], f, "\037")
          if (f[3] == "subissue") { par[f[5]] = f[4]; ord[f[4]] = ord[f[4]] ? ord[f[4]] : ++np }
        }
      }
      { p = ($2 in par) ? par[$2] : "-"
        # Parents keep first-appearance order so the emitted plan is stable;
        # unplaceable refs sort last and carry no parent.
        printf "%d\t%s\t%s\t%s\n", (p == "-" ? 999999 : ord[p]), p, $1, $2 }' \
  | LC_ALL=C sort -t"$(printf '\t')" -k1,1n -k3,3n \
  | cut -f2-)
EOF_ORD
  fi
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
  local a b c d e f n ncreate=0 nwire=0 nskip=0 nupdate=0 ndecision=0 norder=0 refs
  pending="$(im_pending "$manifest" "$state")"

  while IFS=$'\037' read -r a b c d e f; do
    [ -n "$a" ] || continue
    case "$a" in
      lookup-ms)
        echo "lookup: milestones GET repos/{owner}/{repo}/milestones?state=all&per_page=100 resolve \"$(printf '%s' "$b" | tr '\036' '|')\"" ;;
      resolve-ms)
        echo "resolve: milestone \"$b\" -> this manifest's $c record" ;;
      lookup-labels)
        echo "lookup: labels GET repos/{owner}/{repo}/labels?per_page=100 verify $b" ;;
      lookup-ids)
        refs=""
        for n in $b; do refs="${refs}#$n "; done
        echo "lookup: ids GraphQL issue fullDatabaseId for ${refs% }" ;;
      decision)
        ndecision=$((ndecision + 1))
        echo "decision: $b needs a human answer — \"$c\"" ;;
      create-ms)
        ncreate=$((ncreate + 1))
        echo "create: milestone $b POST repos/{owner}/{repo}/milestones title=\"$c\"" ;;
      skip-create-ms)
        nskip=$((nskip + 1))
        echo "skip: milestone $b = exists #$c (state)" ;;
      update)
        nupdate=$((nupdate + 1))
        echo "update: $b PATCH repos/{owner}/{repo}/issues/${b#'#'} $c=\"$d\"" ;;
      skip-update)
        nskip=$((nskip + 1))
        echo "skip: update $b $c (state)" ;;
      order)
        norder=$((norder + 1))
        echo "order: $c at position $d under $b PATCH repos/{owner}/{repo}/issues/<$b.number>/sub_issues/priority" ;;
      order-unplaceable)
        echo "order: $b at position $c CANNOT be applied — sub-issue order is the only place GitHub holds it, and $b is not a sub-issue of anything in this manifest" ;;
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

  # The update count appears only when there is one: manifests that predate
  # update records keep their exact tally line, which is a documented contract.
  if [ "$nupdate" -gt 0 ]; then
    echo "dry-run: $ncreate create(s), $nupdate update(s), $nwire wire(s); $nskip skip(s); no calls made"
  else
    echo "dry-run: $ncreate create(s), $nwire wire(s); $nskip skip(s); no calls made"
  fi
  if [ "$norder" -gt 0 ]; then
    echo "dry-run: $norder order placement(s)"
  fi
  if [ "$ndecision" -gt 0 ]; then
    echo "dry-run: $ndecision unresolved decision(s) — apply refuses until they are answered"
  fi
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

api_create_milestone() { # <title> <description> -> "number"
  gh api "repos/{owner}/{repo}/milestones" -X POST -f "title=$1" -f "description=$2" --jq '.number'
}

api_order_subissue() { # <parent-number> <child-id> <after-id-or-empty>
  local args=("repos/{owner}/{repo}/issues/$1/sub_issues/priority" -X PATCH -F "sub_issue_id=$2")
  if [ -n "$3" ]; then args+=(-F "after_id=$3"); fi
  gh api "${args[@]}" >/dev/null
}

# The resolved-label sidecar `spark plan` writes: "#N<TAB>csv" lines giving the
# label set each issue should be LEFT with. Empty when the script is driven
# directly.
IM_LABELS_RESOLVED="${IM_LABELS_RESOLVED:-}"

# im_resolved_labels <number> <artifact-csv> — the set to write for this issue.
#
# `api_update_issue labels` replaces the WHOLE set, so whoever calls it must
# already have decided what the whole set should be. `spark plan` decides that
# family-scoped (#637) and passes the answer in via --labels-resolved: Spark
# owns the families the plan declares and leaves every other label alone.
#
# Without the sidecar the artifact's own CSV is the whole set, unchanged. That
# is the low-level, explicitly destructive operation — running this script by
# hand means saying "these are the labels", and nothing here quietly softens it.
im_resolved_labels() {
  local hit
  [ -n "$IM_LABELS_RESOLVED" ] && [ -f "$IM_LABELS_RESOLVED" ] || { printf '%s' "$2"; return 0; }
  hit="$(awk -F'\t' -v k="#$1" '$1 == k { print $2; found = 1; exit }
    END { if (!found) exit 1 }' "$IM_LABELS_RESOLVED")" || { printf '%s' "$2"; return 0; }
  printf '%s' "$hit"
}

api_update_issue() { # <number> <field> <value> -> nothing
  case "$2" in
    title)     gh api "repos/{owner}/{repo}/issues/$1" -X PATCH -f "title=$3" >/dev/null ;;
    body-file) gh api "repos/{owner}/{repo}/issues/$1" -X PATCH -F "body=@$3" >/dev/null ;;
    milestone) gh api "repos/{owner}/{repo}/issues/$1" -X PATCH -F "milestone=$3" >/dev/null ;;
    labels)
      # Replace the whole set, which is the only unambiguous reading of "set the
      # labels to this": a merge would silently keep a label the plan removed.
      local args=("repos/{owner}/{repo}/issues/$1" -X PATCH) l
      while IFS= read -r l; do
        [ -n "$l" ] && args+=(-f "labels[]=$l")
      done <<< "$(printf '%s' "$3" | tr ',' '\n')"
      gh api "${args[@]}" >/dev/null ;;
  esac
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
im_fail() { # <step> <verbatim-error> <created> <wired> <skipped> <state-path> [updated]
  echo "failed: $1"
  if [ -n "$2" ]; then printf '%s\n' "$2" | sed 's/^/  /'; fi
  # The updates that DID land must appear: a run that applied three PATCHes and
  # then failed on a wire reported "created 0, wired 0" and made them invisible.
  if [ -n "${7:-}" ] && [ "${7:-0}" -gt 0 ]; then
    echo "report: created $3, updated $7, wired $4, skipped $5, failed 1"
  else
    echo "report: created $3, wired $4, skipped $5, failed 1"
  fi
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

  local st_prior="$state"
  [ "$fresh" -eq 1 ] && st_prior=""

  local pending resolved="" ms_number="" created=0 wired=0 skipped=0 updated=0
  local act b c d e f out errf n num id lab missing msn
  # title<TAB>number per line. One variable could only ever hold one milestone,
  # which is why a slate was limited to a single release scope.
  local msmap=$'\n' ms_matches ndecision=0 target

  # LOCAL REFUSALS COME FIRST, before `gh` is required and before anything is
  # written. Detecting an unresolved decision needs no network, so demanding gh
  # to reach that answer reported the wrong problem: on a machine without gh the
  # run failed with "gh was not found" and the blocking human decision in the
  # artifact was never surfaced at all (#516).
  #
  # `--fresh` truncates the state file, so it must also wait: a refused run had
  # already forgotten prior landings, which is a write on a path that promises
  # none.
  pending="$(im_pending "$manifest" "$st_prior")"

  # An unresolved decision refuses the whole run BEFORE the first call. Acting
  # around one would commit Spark to a meaning nobody chose, and doing it
  # part-way through would leave the slate half-applied on top of that.
  if printf '%s\n' "$pending" | grep -q "^decision$(printf '\037')"; then
    printf '%s\n' "$pending" | awk 'BEGIN { FS = "\037" }
      $1 == "decision" { printf "decision: %s needs a human answer — \"%s\"\n", $2, $3 }' >&2
    echo "unresolved decision(s) — nothing was created, updated, or wired" >&2
    return 2
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "gh (GitHub CLI) is required for a live run and was not found — install gh, or preview with --dry-run" >&2
    return 2
  fi

  # Only now, past every refusal: this is the first thing that writes.
  [ "$fresh" -eq 1 ] && : > "$state"   # prior landings are deliberately forgotten

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
            "$created" "$wired" "$skipped" "$state" "$updated"; return 1
        fi
        # Every requested title resolves from this ONE listing.
        local want_t
        while IFS= read -r want_t; do
          [ -n "$want_t" ] || continue
          # Reject ambiguity rather than resolve it silently: two milestones with
          # the same title (possible across open/closed states) must be a named
          # error, not a first-match guess.
          ms_matches="$(printf '%s\n' "$out" | awk -v t="$want_t" 'BEGIN { FS = "\t" } $2 == t { print $1 }')"
          if [ "$(printf '%s\n' "$ms_matches" | grep -c .)" -gt 1 ]; then
            im_fail "resolving milestone \"$want_t\" — $(printf '%s\n' "$ms_matches" | grep -c .) milestones share this title (ambiguous); disambiguate on GitHub first" "" \
              "$created" "$wired" "$skipped" "$state" "$updated"; return 1
          fi
          ms_number="$ms_matches"
          if [ -z "$ms_number" ]; then
            im_fail "resolving milestone \"$want_t\" — not found on GitHub; declare it with a milestone record so this manifest creates it, or create it first" "" \
              "$created" "$wired" "$skipped" "$state" "$updated"; return 1
          fi
          msmap="${msmap}${want_t}	${ms_number}"$'\n'
          echo "resolved: milestone \"$want_t\" -> $ms_number"
        done <<EOF_WANT
$(printf '%s' "$b" | tr '\036' '\n')
EOF_WANT
        ;;
      decision) ;;   # already refused above, before any call was made
      create-ms)
        if ! out="$(api_create_milestone "$c" "$d" 2>"$errf")"; then
          im_fail "creating milestone \"$c\" (POST repos/{owner}/{repo}/milestones)" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state" "$updated"; return 1
        fi
        printf 'created\tms:%s\t%s\t\n' "$b" "$out" >> "$state"
        msmap="${msmap}${b}	${out}"$'\n'
        msmap="${msmap}${c}	${out}"$'\n'
        created=$((created + 1))
        echo "created: milestone $b -> #$out"
        ;;
      skip-create-ms)
        skipped=$((skipped + 1))
        msmap="${msmap}${b}	${c}"$'\n'
        [ -n "$d" ] && msmap="${msmap}${d}	${c}"$'\n'
        echo "skip: milestone $b = #$c (state)"
        ;;
      update)
        target="${b#'#'}"
        if [ "$c" = "milestone" ]; then
          msn="$(printf '%s' "$msmap" | awk -F'\t' -v t="$d" 'NF == 2 && $1 == t { print $2; exit }')"
          if [ -z "$msn" ]; then
            im_fail "resolving milestone \"$d\" for $b — neither looked up nor created in this run" "" \
              "$created" "$wired" "$skipped" "$state" "$updated"; return 1
          fi
          d="$msn"
        fi
        if [ "$c" = "labels" ]; then d="$(im_resolved_labels "$target" "$d")"; fi
        if ! api_update_issue "$target" "$c" "$d" 2>"$errf"; then
          im_fail "updating #$target $c (PATCH repos/{owner}/{repo}/issues/$target)" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state" "$updated"; return 1
        fi
        printf 'wired\tupdate\t%s\t%s\n' "$b" "$c" >> "$state"
        updated=$((updated + 1))
        echo "updated: $b $c"
        ;;
      skip-update)
        skipped=$((skipped + 1))
        echo "skip: update $b $c (state)"
        ;;
      order)
        # after_id empty puts the child first; otherwise it follows the child
        # placed immediately before it, which is what makes the declared
        # positions come out in order.
        local after_id=""
        [ -n "$e" ] && after_id="$(im_id_of "$e")"
        if ! api_order_subissue "$(im_num_of "$b")" "$(im_id_of "$c")" "$after_id" 2>"$errf"; then
          im_fail "ordering $c under $b (PATCH .../sub_issues/priority)" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state" "$updated"; return 1
        fi
        wired=$((wired + 1))
        echo "ordered: $c at position $d under $b"
        ;;
      order-unplaceable)
        echo "order: $b at position $c was NOT applied — it is not a sub-issue of anything in this manifest" >&2
        ;;
      lookup-labels)
        if ! out="$(api_list_labels 2>"$errf")"; then
          im_fail "listing labels (GET repos/{owner}/{repo}/labels)" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state" "$updated"; return 1
        fi
        missing=""
        while IFS= read -r lab; do
          if [ -n "$lab" ] && ! printf '%s\n' "$out" | grep -Fxq -- "$lab"; then
            missing="${missing}${lab} "
          fi
        done <<< "$(printf '%s' "$b" | tr ',' '\n')"
        if [ -n "$missing" ]; then
          im_fail "verifying labels — not found on GitHub: ${missing% } (the helper never invents label taxonomies)" "" \
            "$created" "$wired" "$skipped" "$state" "$updated"; return 1
        fi
        echo "resolved: labels $b"
        ;;
      lookup-ids)
        # shellcheck disable=SC2086 — $b is a space-separated number list.
        if ! out="$(api_resolve_existing $b 2>"$errf")"; then
          im_fail "resolving existing issue ids (GraphQL)" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state" "$updated"; return 1
        fi
        for n in $b; do
          id="$(printf '%s\n' "$out" | awk -v n="$n" 'BEGIN { FS = "\t" } $1 == n { print $2; exit }')"
          if [ -z "$id" ]; then
            im_fail "resolving existing issue #$n — not found in this repo" "" \
              "$created" "$wired" "$skipped" "$state" "$updated"; return 1
          fi
          resolved="${resolved}#$n $n $id"$'\n'
        done
        echo "resolved: ids for $(printf '#%s ' $b | sed 's/ $//')"
        ;;
      create)
        # Resolve THIS issue's milestone from the map, by KEY or by title. A
        # single ms_number could only ever serve one milestone, which is what
        # limited a slate to one release scope.
        msn=""
        if [ -n "$e" ]; then
          msn="$(printf '%s' "$msmap" | awk -F'\t' -v t="$e" 'NF == 2 && $1 == t { print $2; exit }')"
          if [ -z "$msn" ]; then
            im_fail "resolving milestone \"$e\" for $b — neither looked up nor created in this run" "" \
              "$created" "$wired" "$skipped" "$state" "$updated"; return 1
          fi
        fi
        if ! out="$(api_create_issue "$c" "$d" "$msn" "$f" 2>"$errf")"; then
          im_fail "creating $b (\"$c\")" "$(cat "$errf")" \
            "$created" "$wired" "$skipped" "$state" "$updated"; return 1
        fi
        num="${out%%$'\t'*}"; id="${out#*$'\t'}"
        case "$num" in
          ''|*[!0-9]*)
            im_fail "parsing the create response for $b (expected \"number<TAB>id\")" "$out" \
              "$created" "$wired" "$skipped" "$state" "$updated"; return 1 ;;
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
            "$created" "$wired" "$skipped" "$state" "$updated"; return 1
        fi
        if [ "$b" = "subissue" ]; then
          out="$(api_wire_subissue "$num" "$id" 2>"$errf")" || {
            im_fail "wiring subissue $c<-$d" "$(cat "$errf")" \
              "$created" "$wired" "$skipped" "$state" "$updated"; return 1; }
        else
          out="$(api_wire_blockedby "$num" "$id" 2>"$errf")" || {
            im_fail "wiring blockedby $c<-$d" "$(cat "$errf")" \
              "$created" "$wired" "$skipped" "$state" "$updated"; return 1; }
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

  # The updated count appears only when there is one, so a manifest that
  # predates update records keeps its exact report line.
  if [ "$updated" -gt 0 ]; then
    echo "report: created $created, updated $updated, wired $wired, skipped $skipped, failed 0"
  else
    echo "report: created $created, wired $wired, skipped $skipped, failed 0"
  fi
}

# --- entry point ---------------------------------------------------------------

main() {
  set -euo pipefail
  local usage="usage: issue-manifest.sh [--dry-run] [--state FILE] [--fresh] [--labels-resolved FILE] MANIFEST"
  local dry=0 fresh=0 state="./.issue-manifest.state" manifest=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      --fresh)   fresh=1; shift ;;
      --state)
        [ $# -ge 2 ] || { echo "--state needs a file argument" >&2; echo "$usage" >&2; exit 2; }
        state="$2"; shift 2 ;;
      --labels-resolved)
        [ $# -ge 2 ] || { echo "--labels-resolved needs a file argument" >&2; echo "$usage" >&2; exit 2; }
        [ -f "$2" ] || { echo "labels file not found: $2" >&2; exit 2; }
        IM_LABELS_RESOLVED="$2"; shift 2 ;;
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
