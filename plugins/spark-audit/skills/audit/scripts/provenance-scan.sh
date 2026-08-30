#!/usr/bin/env bash
# provenance-scan.sh — THE deterministic producer for provenance-leakage
# evidence (#476).
#
# ONE PRODUCER, MANY CONSUMERS. The Evidence Gatherer, the Health Assessor and
# the Synthesis Lead all need the same answer to "what does this artifact own,
# and is this passage a second account of something a record already holds?".
# Three roles deriving that separately is three answers, and the one that
# reaches the slate is whichever ran last. So the mechanical half lives here and
# is read, never re-derived. The judgment half is the contract in
# `../references/provenance-leakage.md`, which is prose because it is judgment.
#
# WHAT THIS IS NOT. It does not grade prose, detect staleness, or treat dates,
# issue references, historical nouns or document age as evidence of anything.
# Those are the false signals #476 names: a current-state document may cite
# history, an ADR may explain a rejected alternative, a runbook may explain the
# incident that justifies its rule. None of that is leakage, and none of it is
# detectable by looking for old-sounding words.
#
# THE RULE IT MECHANIZES. Leakage is a SECOND MAINTAINED ACCOUNT of how state
# changed over time, on a surface that does not own that account. Three clauses,
# each carrying its share of the discrimination:
#
#   1. the surface does not own chronology
#   2. the passage ties together TWO OR MORE subjects that have owning records
#   3. the passage cites none of those owners
#
# Clause 2 is what separates an account from a mention. A roadmap section headed
# `## v0.10` naming its own version is a status line, not a narrative; a
# paragraph that carries v0.17, v0.18 and v0.19 through a sequence of events is
# telling a story across them, and that story already exists in the records and
# in Git. Requiring two subjects is not a heuristic about wording — it is the
# structural difference between stating a fact and recounting a chain.
#
# Clause 3 is ADR-0031 stated mechanically: a citation carries the evidence, the
# tree carries the conclusion. A passage that points at the record which owns the
# account is doing exactly what the contract asks. A passage that re-tells it
# while that record sits right there is the second copy that will drift — and
# did drift, which is why #475 existed.
#
# Usage:
#   provenance-scan.sh role <path>          the surface's ownership role
#   provenance-scan.sh owners [root]        subjects that have an owning record
#   provenance-scan.sh scan <path> [root]   classified rows for one file
#
# `scan` emits one TSV row per finding:
#   <path> <TAB> <class> <TAB> <disposition> <TAB> <subjects> <TAB> <detail>
#
# Classes, and the #468 disposition each maps to:
#
#   PROVENANCE-ONLY       REWRITE-COLLAPSE   a second account; collapse to the
#                                            conclusion and cite the owner
#   RETAINED-EVIDENCE     KEEP               chronology on a surface that owns it
#   GENERATED-PROJECTION  KEEP               rendered from commits, not authored
#   DURABLE-RATIONALE     KEEP               why the system is as it is
#   CURRENT-STATE         KEEP               what is true now
#   NOT-ASSESSED          (empty)            evidence could not be read
#
# NOT-ASSESSED CARRIES NO DISPOSITION. That is core's two-axis rule — evidence is
# `known`/`unread`, disposition is a separate column — and the reason it exists:
# proposing a disposition for something that could not be read is how missing
# evidence becomes a guessed decision. An unreadable path is never PASS, and
# never KEEP.
#
# Nothing here mutates anything. Classification is discovery; carrying a finding
# out is #468's approval-gated path and the human's authority (#476 non-goal).
set -uo pipefail

usage() {
  cat <<'EOF'
usage: provenance-scan.sh role <path>
       provenance-scan.sh owners [root]
       provenance-scan.sh scan <path> [root]
EOF
}

# --- surface roles -----------------------------------------------------------
#
# The projection of ADR-0031's kind-of-truth axis onto ADR-0029's tiers. A
# declared table, not a guess, and a path it does not name is `unknown` — never
# "probably current state". Absence of a rule is not a rule.
#
#   provenance    owns change-over-time chronology; that is the artifact's job
#   generated     rendered from commits by release tooling, not hand-authored
#   decision      durable rationale and supersession; not an event diary
#   operational   a current rule, which may cite the incident that justifies it
#   current       what is true now
#   unknown       not declared here — judgment required, never auto-classified
surface_role() {
  case "$1" in
    docs/releases/*)             printf 'provenance' ;;
    docs/governance/*)           printf 'provenance' ;;
    CHANGELOG.md|*/CHANGELOG.md) printf 'generated' ;;
    docs/adr/*)                  printf 'decision' ;;
    docs/ops/*)                  printf 'operational' ;;
    docs/architecture/*)         printf 'current' ;;
    README.md|ROADMAP.md)        printf 'current' ;;
    plugins/*/docs/*)            printf 'current' ;;
    *)                           printf 'unknown' ;;
  esac
}

owns_chronology() {
  case "$1" in provenance|generated) return 0 ;; *) return 1 ;; esac
}

# --- provenance owners -------------------------------------------------------
#
# The subjects that already HAVE an owning record, derived from the repository
# rather than hard-coded: a release record's filename is the subject it owns.
#
# Only canonical version records qualify (`vN.N`). A compound record such as
# `v0.17-plan` or `v0.14-v0.15-launch-record` is a document about a subject, not
# the subject's own record, and admitting it would make one mention of `v0.17`
# look like two different owned subjects — a false account out of a single
# reference.
#
# An unreadable directory returns UNREADABLE, because "no owners" and "could not
# look" are different answers and only one of them is safe to act on.
owners_of() {
  local root="${1:-.}" f base
  [ -d "$root/docs/releases" ] || { printf 'UNREADABLE\n'; return 1; }
  for f in "$root"/docs/releases/*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .md)"
    case "$base" in
      v[0-9]*.[0-9]*) ;;
      *) continue ;;
    esac
    case "$base" in *-*) continue ;; esac
    printf '%s\t%s\n' "$base" "docs/releases/$base.md"
  done
}

# --- scan --------------------------------------------------------------------
#
# Passages are blank-line-separated blocks: the smallest unit a reviewer can act
# on. A finding an author cannot locate is not actionable evidence.
scan_file() {
  local path="$1" root="${2:-.}" role owners rc=0
  local abs="$root/$path"

  role="$(surface_role "$path")"

  if [ ! -r "$abs" ]; then
    printf '%s\tNOT-ASSESSED\t\t-\tpath is not readable; evidence was not obtained\n' "$path"
    return 3
  fi
  if [ "$role" = unknown ]; then
    printf '%s\tNOT-ASSESSED\t\t-\tno declared ownership role for this path; judgment required\n' "$path"
    return 3
  fi

  owners="$(owners_of "$root")" || rc=$?
  if [ "$rc" -ne 0 ] || [ "$owners" = "UNREADABLE" ]; then
    printf '%s\tNOT-ASSESSED\t\t-\tthe provenance-owner index could not be read\n' "$path"
    return 3
  fi

  # A surface that owns chronology is not leaking when it holds it. This is why
  # release records and the changelog are never ordinary findings: their role IS
  # the account.
  if owns_chronology "$role"; then
    case "$role" in
      provenance)
        printf '%s\tRETAINED-EVIDENCE\tKEEP\t-\tthis surface owns change-over-time chronology; retained history is evidence, not leakage\n' "$path" ;;
      generated)
        printf '%s\tGENERATED-PROJECTION\tKEEP\t-\trendered from commits by release tooling; not hand-authored chronology\n' "$path" ;;
    esac
    return 0
  fi

  printf '%s\n' "$owners" | awk -v p="$path" -v role="$role" '
    NR == FNR { subj[++n] = $1; owner[$1] = $2; next }
    { block = block $0 "\n" }
    /^$/ { flush() }
    END { flush(); if (!found) clean() }

    # A subject matches only on a real boundary: `v0.17` inside `v0.17-plan` is a
    # different token and must not count. Trailing `.0` is the same subject, so a
    # following dot or digit is allowed and a dash or letter is not.
    function names(b, s,   i, c) {
      i = index(b, s)
      while (i > 0) {
        c = substr(b, i + length(s), 1)
        if (c !~ /[-A-Za-z]/) return 1
        i = index(substr(b, i + 1), s)
        if (i > 0) i = i + 1; else return 0
      }
      return 0
    }

    # ANCHORED TO PROVENANCE, OR NOT. A passage that names a resolvable
    # identifier — the owning record, a commit, a pull request or issue, a
    # GitHub URL — is pointing at the authority that holds the fact. That is
    # what the contract asks current-state prose to do, and it is the difference
    # between "here is the instance that proves this rule" and "here is what
    # happened, in order".
    #
    # Reading a citation as EVIDENCE OF LEGITIMACY is deliberate and is the
    # opposite of treating citations as violations. The cost is that a genuine
    # retelling which happens to carry an issue number is not flagged. That is
    # the safe direction to be wrong in: #476 asks for uncertainty to be
    # preserved rather than turned into a confident finding, and a false
    # accusation against correctly-cited prose would teach authors to stop
    # citing.
    function anchored(b) {
      if (b ~ /github\.com\//) return 1
      if (b ~ /#[0-9]+/) return 1
      if (b ~ /`[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]+`/) return 1
      return 0
    }

    function flush(   i, hits, list, cited, ex) {
      if (block ~ /^[[:space:]]*$/) { block = ""; return }
      hits = 0; list = ""; cited = 0
      for (i = 1; i <= n; i++) {
        if (!names(block, subj[i])) continue
        hits++
        list = list (list == "" ? "" : ",") subj[i]
        if (index(block, owner[subj[i]]) > 0) cited = 1
      }
      if (anchored(block)) cited = 1
      # TWO subjects make an account; one is a mention. A cited owner means the
      # passage is pointing at the authority rather than replacing it.
      if (hits >= 2 && !cited) {
        ex = block; gsub(/\n/, " ", ex); gsub(/[[:space:]]+/, " ", ex)
        printf "%s\tPROVENANCE-ONLY\tREWRITE-COLLAPSE\t%s\tties %d owned subjects together without citing any owning record: %s\n",
          p, list, hits, substr(ex, 1, 110)
        found = 1
      }
      block = ""
    }

    # Silence is a real answer, and saying so lets a consumer tell "checked,
    # clean" from "never ran".
    function clean() {
      if (role == "decision")
        printf "%s\tDURABLE-RATIONALE\tKEEP\t-\tdecision record; rationale and supersession are its content, and no uncited multi-subject account was found\n", p
      else if (role == "operational")
        printf "%s\tCURRENT-STATE\tKEEP\t-\toperational rule; any history it names is cited to the record that owns it\n", p
      else
        printf "%s\tCURRENT-STATE\tKEEP\t-\tno passage here retells an account a record already owns\n", p
    }
  ' - "$abs"
  return 0
}

case "${1:-}" in
  role)   [ $# -ge 2 ] || { usage; exit 2; }; surface_role "$2"; printf '\n' ;;
  owners) owners_of "${2:-.}" ;;
  scan)   [ $# -ge 2 ] || { usage; exit 2; }; scan_file "$2" "${3:-.}" ;;
  ''|-h|--help) usage ;;
  *)      usage; exit 2 ;;
esac
