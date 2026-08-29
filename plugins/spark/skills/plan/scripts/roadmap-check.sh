#!/usr/bin/env bash
# Roadmap completeness / release-assignment checker for the plan skill (#188).
#
# Answers one question, deterministically: does every piece of planned work
# have a release decision? Four checks feed it:
#   A. the roadmap names a current release (some ## vX.Y with Status Shipped)
#   B. the roadmap names a next release    (some ## vX.Y not yet Shipped)
#   C. every open `feature` issue carries a release decision in a GOVERNED
#      FIELD — a milestone, or a label from the model's disposition family.
#      Anything else needs a human decision
#   D. every unshipped ## vX.Y section links at least one issue or carries a
#      deferred/backlog marker
#
# WHICH SURFACES CARRY AUTHORITY (#570)
#
# Exactly two, and both are structured fields a human sets deliberately:
#
#   milestone            the work is scheduled into a release
#   disposition label    the decision NOT to schedule it yet, read from the
#                        governance model's `disposition` family rather than
#                        named here, so the member set has one authority
#
# An issue BODY carries none. A line reading `Backlog: …`, `Blocked pending …`
# or `Depends on: #N` is evidence about a decision, never the decision — the
# governance model already says so of dependencies ("a `Blocked by #N` sentence
# explains a prerequisite; it never creates one") and the same holds for the
# release disposition.
#
# This checker used to accept all three spellings, so an agent could clear
# DECISION REQUIRED by writing one sentence into an issue body — the false green
# the authority boundary exists to prevent, reachable by prose. Recommendation
# text is still allowed and is still reported; it simply has no authority on its
# own.
#
# Read-only by design: release decisions are human calls, so the checker only
# reports findings and never fixes them. Two kinds, kept apart (#559):
#   `GAP: …`               a mechanical gap — the roadmap contradicts itself or
#                          cannot be read. Anyone may correct it.
#   `DECISION REQUIRED: …` an open issue has no release decision. Only the human
#                          may supply one, and an agent writing a milestone or a
#                          backlog label to make this check pass is the defect
#                          #559 exists to prevent. Reported, never chosen.
#
# Exit codes: 0 complete, 1 gaps, 2 usage/input error, 3 not assessed —
# neither jq nor python3 is available, OR the open-feature inventory could not
# be retrieved (no --issues and gh missing/failing) — 5 decision required.
# Exit 3 is never a clean pass: an unassessed inventory must not read as
# "complete" (#224). Exit 5 is never a clean pass either, and it must not be
# cleared by the same run that reported it.

set -euo pipefail

usage="usage: roadmap-check.sh [--roadmap FILE] [--issues FILE]"

roadmap="" issues_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --roadmap|--issues)
      [ $# -ge 2 ] || { echo "$1 needs a file argument" >&2; echo "$usage" >&2; exit 2; }
      case "$1" in
        --roadmap) roadmap="$2" ;;
        *)         issues_file="$2" ;;
      esac
      shift 2 ;;
    -h|--help) echo "$usage"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; echo "$usage" >&2; exit 2 ;;
  esac
done

# JSON parsing needs one of the two readers this repo already degrades
# between. Unlike doctor's silent skips, planning without any assessment is
# worth a distinct signal, hence exit 3 rather than 0.
have_jq=0 have_py=0
command -v jq >/dev/null 2>&1 && have_jq=1
command -v python3 >/dev/null 2>&1 && have_py=1

# The disposition family's members come from the resolved governance model, via
# the sibling binary in this same plugin. Naming `backlog` here would be a
# second authority for a set the schema owns, and a hard-coded fallback would be
# worse still: it would take over at exactly the moment the real authority was
# unusable. So an unresolvable family is NOT ASSESSED, never a guess.
spark_bin="$(cd "$(dirname "$0")/../../.." 2>/dev/null && pwd)/bin/spark"
disp_members=""
if [ -x "$spark_bin" ]; then
  # ONE MEMBER PER LINE. A GitHub label may contain spaces — `not planned` is a
  # perfectly ordinary disposition — so a space-delimited list silently split a
  # valid member in two and reported the issue carrying it as undecided. The
  # governed value resolved, provisioned, and still produced a false DECISION
  # REQUIRED.
  #
  # A newline is the one character a member cannot contain: this model is a
  # line-oriented TSV, so a label with a newline in it could not be declared in
  # the first place. That makes the boundary lossless rather than merely wider,
  # which a rarer delimiter would not.
  disp_members="$("$spark_bin" governance --tsv 2>/dev/null \
    | awk -F'\t' '$1 == "member" && $2 == "disposition" { print $3 }')"
fi
# A comma-joined form for prose only. Never parsed back.
disp_display="$(printf '%s' "$disp_members" | awk 'NF { printf "%s%s", (n++ ? ", " : ""), $0 }')"
if [ "$have_jq" -eq 0 ] && [ "$have_py" -eq 0 ]; then
  echo "not assessed (needs jq or python3)"
  exit 3
fi

if [ -z "$roadmap" ]; then
  roadmap="$(git rev-parse --show-toplevel 2>/dev/null || echo .)/ROADMAP.md"
fi

gaps=0
gap() { echo "GAP: $1"; gaps=$((gaps + 1)); }
# A missing release decision is not a gap in the roadmap; it is an absent human
# judgment. Counting the two together is what let the #558 incident resolve
# itself: the only route from exit 1 to exit 0 was to write the decision.
decisions=0
decision() { echo "DECISION REQUIRED: $1"; decisions=$((decisions + 1)); }

# --- roadmap (checks A, B, D) ----------------------------------------------
# One record per ## vX.Y section: "heading<TAB>status<TAB>has-ref<TAB>has-marker".
# Non-version headings (e.g. "## Later — …") only terminate the current
# section: they carry no Status line, so they hold ideas, not releases, and
# holding them to check D would flag prose that made no release claim.
sections=""
if [ -f "$roadmap" ]; then
  sections="$(awk '
    function flush() {
      if (ver != "") printf "%s\t%s\t%d\t%d\n", ver, status, ref, marker
      ver = ""
    }
    /^## v[0-9]+\.[0-9]+/ { flush(); ver = substr($0, 4); status = ""; ref = 0; marker = 0; next }
    /^## /                { flush() }
    ver != "" {
      if ($0 ~ /^\*\*Status:\*\*/) { status = $0; sub(/^\*\*Status:\*\*[[:space:]]*/, "", status) }
      if ($0 ~ /#[0-9]+/) ref = 1
      if (tolower($0) ~ /deferred|backlog/) marker = 1
    }
    END { flush() }
  ' "$roadmap")"

  shipped=0 unshipped=0
  while IFS=$'\t' read -r ver status ref marker; do
    [ -n "$ver" ] || continue
    case "$status" in
      [Ss]hipped*) shipped=$((shipped + 1)) ;;
      *)           unshipped=$((unshipped + 1)) ;;
    esac
  done <<< "$sections"

  if [ "$shipped" -gt 0 ]; then
    echo "ok: roadmap names a shipped (current) release"
  else
    gap "roadmap names no current release (no ## vX.Y section with **Status:** Shipped)"
  fi
  if [ "$unshipped" -gt 0 ]; then
    echo "ok: roadmap names a next (unshipped) release"
  else
    gap "roadmap names no next release (every ## vX.Y section is already Shipped)"
  fi

  # --- the headline baseline must not lag the newest Shipped entry ----------
  #
  # The first summary a reader sees is where release state gets established, and
  # it drifted independently of the sections below it: the v0.20 section said
  # Shipped while the headline still named v0.19.0 as the published baseline, so
  # the document contradicted itself and an operator could plan from the wrong
  # release (#521).
  #
  # Planning-wave names and published tags are deliberately NOT the same thing.
  # A section heading is a wave (`## v0.20`); what shipped is a tag (`v0.20.0`),
  # and one wave may carry several (`v0.16.0`–`v0.16.2`). The comparison
  # therefore reads tags out of Shipped **Status** lines and never out of
  # headings, so a wave that has not shipped can never be mistaken for a
  # release.
  # THE HEADLINE REGION is the prose before the first `## ` section heading,
  # excluding blockquoted lines.
  #
  # The first cut scanned the WHOLE file and took the greatest version it found,
  # so a later migration note mentioning the current tag masked a stale summary —
  # the guard could positively certify the exact contradiction it was added to
  # prevent (#541). A boundary is not a refinement here; without one the check is
  # unsound.
  #
  # Blockquotes are excluded because that is where a roadmap keeps its historical
  # asides, and history legitimately names superseded baselines. Applying the
  # boundary to this repository immediately found the case: a reconciliation note
  # recording that withdrawn releases "returned the published baseline to
  # `v0.16.2`" sits above the first heading. It is true, it is not the headline,
  # and counting it made the summary ambiguous.
  #
  # A claim written only inside a blockquote is therefore invisible here, and the
  # check says "no claim" rather than passing — which is the safe direction to be
  # wrong in.
  head_base="$(awk '
    /^## / { exit }
    /^[[:space:]]*>/ { next }
    tolower($0) ~ /published baseline/ {
      line = $0
      while (match(line, /`v[0-9]+\.[0-9]+\.[0-9]+`/)) {
        print substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, RSTART + RLENGTH)
      }
    }' "$roadmap" | LC_ALL=C sort -u)"
  head_count="$(printf '%s\n' "$head_base" | grep -c . || true)"
  # More than one DISTINCT claim in the summary is ambiguity, and reducing it to
  # the greatest version is how the unsound version hid a stale headline. Name it.
  if [ "$head_count" -gt 1 ]; then
    gap "the summary names more than one published baseline ($(printf '%s' "$head_base" | paste -sd' ' -)) — one claim, or the check cannot judge it"
    head_base=""
    head_ambiguous=1
  else
    head_ambiguous=0
  fi
  newest_tag="$(printf '%s\n' "$sections" \
    | awk -F'\t' '$2 ~ /^[Ss]hipped/ { print $2 }' \
    | awk '{
        line = $0
        while (match(line, /v[0-9]+\.[0-9]+\.[0-9]+/)) {
          print substr(line, RSTART, RLENGTH)
          line = substr(line, RSTART + RLENGTH)
        }
      }' | LC_ALL=C sort -V | awk 'END { print }')"

  if [ "$head_ambiguous" -eq 1 ]; then
    : # already reported above; do not also claim a limit or a match
  elif [ -z "$head_base" ]; then
    # Stated as a limit, not as a pass: the check looked, found no claim, and
    # says so rather than implying the baseline was verified.
    echo "ok: the summary makes no published-baseline claim, so there is nothing to contradict"
  elif [ -z "$newest_tag" ]; then
    gap "the summary names \`$head_base\` as the published baseline, but no roadmap section marked Shipped records a published tag"
  elif [ "$head_base" = "$newest_tag" ]; then
    echo "ok: the summary's published baseline (\`$head_base\`) is the newest Shipped tag"
  else
    latest="$(printf '%s\n%s\n' "$head_base" "$newest_tag" | LC_ALL=C sort -V | awk 'END { print }')"
    if [ "$latest" = "$newest_tag" ]; then
      gap "the summary names \`$head_base\` as the published baseline, but the newest Shipped tag is \`$newest_tag\` — the headline lags the roadmap"
    else
      gap "the summary names \`$head_base\` as the published baseline, which is newer than any Shipped tag (\`$newest_tag\`) — the headline claims a release the roadmap does not record"
    fi
  fi

  # Vocabulary: every section's Status must lead with a known term, or the
  # roadmap drifts into ad-hoc statuses no reader or tool can rely on.
  #
  # `Blocked` was added because the vocabulary could not express a release whose
  # certification has been withdrawn. Every available term was a lie for that
  # state: `Merged` and `Shipped` overclaim, `In progress` reads as ordinary
  # progress, and `Deferred`/`Backlog` say the work was chosen against. A
  # roadmap check meant to enforce truthfulness must not force an untruth.
  while IFS=$'\t' read -r ver status ref marker; do
    [ -n "$ver" ] || continue
    case "$status" in
      Planned*|"In progress"*|Merged*|[Ss]hipped*|Complete*|Deferred*|Backlog*|Blocked*)
        echo "ok: roadmap section \"$ver\" uses a vocabulary status" ;;
      *)
        gap "roadmap section \"$ver\" Status \"${status:-unknown}\" is outside the vocabulary (Planned|In progress|Merged|Shipped|Complete|Deferred|Backlog|Blocked)" ;;
    esac
  done <<< "$sections"

  while IFS=$'\t' read -r ver status ref marker; do
    [ -n "$ver" ] || continue
    case "$status" in [Ss]hipped*|Complete*) continue ;; esac
    if [ "$ref" -eq 1 ] || [ "$marker" -eq 1 ]; then
      echo "ok: roadmap section \"$ver\" links issues or defers explicitly"
    else
      gap "roadmap section \"$ver\" (Status: ${status:-unknown}) links no issue and carries no deferred/backlog marker"
    fi
  done <<< "$sections"
else
  gap "roadmap not found: $roadmap (cannot assess releases)"
fi

# --- issues (check C) --------------------------------------------------------
issues_source="" issues_assessed=0
if [ -n "$issues_file" ]; then
  [ -f "$issues_file" ] || { echo "issues file not found: $issues_file" >&2; exit 2; }
  issues_source="$issues_file"; issues_assessed=1
elif command -v gh >/dev/null 2>&1; then
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  if gh issue list --state open --json number,title,labels,milestone,body --limit 200 > "$tmp" 2>/dev/null; then
    issues_source="$tmp"; issues_assessed=1
  else
    # gh is present but could not list — offline, unauthenticated, or no GitHub
    # remote. This is NOT the same as "no open features": the inventory was not
    # assessed, so the run is incomplete (exit 3 below), never a clean pass
    # (#224). Report an actionable, credential-free reason.
    echo "issues: NOT assessed — 'gh issue list' failed (offline, unauthenticated, or no GitHub remote?). Run 'gh auth status', or pass --issues FILE."
  fi
else
  echo "issues: NOT assessed — no --issues file and gh is not installed. Install gh, or pass --issues FILE."
fi

# classify_features <file> — one `number<TAB>class<TAB>prose` line per open
# `feature` issue.
#
#   assigned   carries a milestone
#   backlog    carries a label from the model's disposition family
#   undecided  neither: the release decision has not been recorded anywhere
#              a governed field can be read from
#
# The third column is 0/1 for "the body contains disposition-shaped prose". It
# is REPORTING ONLY and never changes the class — its whole purpose is to let
# the message tell a human that a proposal exists and is not a decision.
#
# labels/milestone arrive either in gh's object form ({"name":…}/{"title":…})
# or already flattened to strings; both normalize here. Prefer jq, fall back
# to python3 — same degradation ladder as the rest of the repo, and both
# branches now implement the same short rule rather than two copies of three
# regexes.
classify_features() {
  if [ "$have_jq" -eq 1 ]; then
    jq -r --arg disp "$disp_members" '
      ($disp | split("\n") | map(select(. != ""))) as $dm
      | .[]
      | . as $i
      | [ ($i.labels // [])[] | if type == "object" then (.name // "") else . end ] as $labels
      | select($labels | index("feature"))
      | (($i.milestone // "") | if type == "object" then (.title // "") else . end) as $ms
      | ($i.body // "") as $body
      | ([ $labels[] | select(. as $l | $dm | index($l)) ] | length > 0) as $hasdisp
      | (if $ms != "" then "assigned"
         elif $hasdisp then "backlog"
         else "undecided" end) as $cls
      | (if ($body | test("(^|\\n)[ \\t]*backlog\\b"; "i"))
            or ($body | test("[Bb]locked (by|pending)"))
            or ($body | test("(^|\\n)[Dd]epends on:[^\\n]*#[0-9]+"))
         then "1" else "0" end) as $prose
      | "\($i.number)\t\($cls)\t\($prose)"
    ' "$1"
    return $?
  fi
  python3 - "$1" "$disp_members" <<'PY'
import json, re, sys

dm = [d for d in (sys.argv[2] if len(sys.argv) > 2 else "").split("\n") if d]
for issue in json.load(open(sys.argv[1])):
    labels = [l.get("name", "") if isinstance(l, dict) else str(l)
              for l in (issue.get("labels") or [])]
    if "feature" not in labels:
        continue
    milestone = issue.get("milestone") or ""
    if isinstance(milestone, dict):
        milestone = milestone.get("title") or ""
    body = issue.get("body") or ""
    if milestone:
        cls = "assigned"
    elif any(l in dm for l in labels):
        cls = "backlog"
    else:
        cls = "undecided"
    prose = "1" if (
        re.search(r"(^|\n)[ \t]*backlog\b", body, re.I)
        or re.search(r"[Bb]locked (by|pending)", body)
        or re.search(r"(^|\n)[Dd]epends on:[^\n]*#[0-9]+", body)
    ) else "0"
    print("%s\t%s\t%s" % (issue["number"], cls, prose))
PY
}

if [ -n "$issues_source" ]; then
  # The governed disposition family is what makes check C answerable. Without
  # it the run is incomplete, never a pass.
  if [ -z "$disp_members" ]; then
    echo "roadmap-check: NOT assessed — the governed disposition family could not be resolved, so which labels record a release decision is unknown. This is NOT a clean pass (exit 3)."
    exit 3
  fi
  classified="$(classify_features "$issues_source")" \
    || { echo "could not parse issues JSON: $issues_source" >&2; exit 2; }
  features=0
  while IFS=$'\t' read -r num cls prose; do
    [ -n "$num" ] || continue
    features=$((features + 1))
    case "$cls" in
      assigned) echo "ok: feature #$num — assigned to a milestone" ;;
      backlog)  echo "ok: feature #$num — carries a governed disposition label" ;;
      *)
        if [ "${prose:-0}" = "1" ]; then
          decision "feature #$num has no release decision — its body proposes one in prose, which is evidence, not authority. Record it in a governed field: assign a milestone, or apply a disposition label ($disp_display)."
        else
          decision "feature #$num has no release decision — assign a milestone, or apply a disposition label ($disp_display). Spark reports the gap; the choice is yours, and an agent may propose one with evidence but must not persist it to clear this line."
        fi ;;
    esac
  done <<< "$classified"
  if [ "$features" -eq 0 ]; then
    echo "note: no open feature issues to assess"
  fi
fi

echo "roadmap-check: $gaps gap(s), $decisions decision(s) requiring human authority"
# Definitive gaps always fail — they are correctable without authority, so they
# outrank an owed decision. Then owed decisions (exit 5). Then a run that could
# not assess the open feature inventory is incomplete — exit 3 (not assessed),
# never a clean 0 (#224); only a fully-assessed, gap-free, decision-free run
# passes.
if [ "$gaps" -gt 0 ]; then
  exit 1
fi
if [ "$decisions" -gt 0 ]; then
  echo "roadmap-check: $decisions release decision(s) await human authority, so this is NOT a clean pass (exit 5)."
  echo "roadmap-check: a recommendation is not authority — this check clears when the issue itself carries the decision."
  exit 5
fi
if [ "$issues_assessed" -eq 0 ]; then
  echo "roadmap-check: incomplete — the open-feature inventory was not assessed, so this is NOT a clean pass (exit 3)."
  exit 3
fi
exit 0
