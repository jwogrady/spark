#!/usr/bin/env bash
# Roadmap completeness / release-assignment checker for the plan skill (#188).
#
# Answers one question, deterministically: does every piece of planned work
# have a release decision? Four checks feed it:
#   A. the roadmap names a current release (some ## vX.Y with Status Shipped)
#   B. the roadmap names a next release    (some ## vX.Y not yet Shipped)
#   C. every open `feature` issue is milestone-assigned, explicitly
#      backlogged, or explicitly blocked — anything else is a gap
#   D. every unshipped ## vX.Y section links at least one issue or carries a
#      deferred/backlog marker
#
# Read-only by design: release decisions are human calls, so the checker only
# reports gaps (one `GAP: …` line each, exit 1) and never fixes them.
#
# Exit codes: 0 complete, 1 gaps, 2 usage/input error, 3 not assessed —
# neither jq nor python3 is available, OR the open-feature inventory could not
# be retrieved (no --issues and gh missing/failing). Exit 3 is never a clean
# pass: an unassessed inventory must not read as "complete" (#224).

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
if [ "$have_jq" -eq 0 ] && [ "$have_py" -eq 0 ]; then
  echo "not assessed (needs jq or python3)"
  exit 3
fi

if [ -z "$roadmap" ]; then
  roadmap="$(git rev-parse --show-toplevel 2>/dev/null || echo .)/ROADMAP.md"
fi

gaps=0
gap() { echo "GAP: $1"; gaps=$((gaps + 1)); }

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

  # Vocabulary: every section's Status must lead with a known term, or the
  # roadmap drifts into ad-hoc statuses no reader or tool can rely on.
  while IFS=$'\t' read -r ver status ref marker; do
    [ -n "$ver" ] || continue
    case "$status" in
      Planned*|"In progress"*|Merged*|[Ss]hipped*|Complete*|Deferred*|Backlog*)
        echo "ok: roadmap section \"$ver\" uses a vocabulary status" ;;
      *)
        gap "roadmap section \"$ver\" Status \"${status:-unknown}\" is outside the vocabulary (Planned|In progress|Merged|Shipped|Complete|Deferred|Backlog)" ;;
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

# classify_features <file> — one "number<TAB>class" line per open `feature`
# issue. Classes, first match wins:
#   assigned  — has a milestone
#   backlog   — `backlog` label, or a body line *starting with* Backlog and
#               carrying a reason (the word mid-sentence does not count)
#               (a bare "Backlog" records no decision anyone can revisit)
#   blocked   — "[Bb]locked by/pending …" or a "Depends on: #N" header
#   undecided — none of the above: the gap #188 exists to catch
# labels/milestone arrive either in gh's object form ({"name":…}/{"title":…})
# or already flattened to strings; both normalize here. Prefer jq, fall back
# to python3 — same degradation ladder as the rest of the repo.
classify_features() {
  if [ "$have_jq" -eq 1 ]; then
    jq -r '
      .[]
      | . as $i
      | [ ($i.labels // [])[] | if type == "object" then (.name // "") else . end ] as $labels
      | select($labels | index("feature"))
      | (($i.milestone // "") | if type == "object" then (.title // "") else . end) as $ms
      | ($i.body // "") as $body
      | (if $ms != "" then "assigned"
         elif ($labels | index("backlog")) != null then "backlog"
         elif ($body | test("(^|\\n)[ \\t]*backlog\\b[:\u2014 -]*[^\\n]*[a-zA-Z0-9#]"; "i")) then "backlog"
         elif ($body | test("[Bb]locked (by|pending)"))
              or ($body | test("(^|\\n)[Dd]epends on:[^\\n]*#[0-9]+")) then "blocked"
         else "undecided" end) as $cls
      | "\($i.number)\t\($cls)"
    ' "$1"
    return $?
  fi
  python3 - "$1" <<'PY'
import json, re, sys

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
    elif "backlog" in labels:
        cls = "backlog"
    elif re.search(r"(^|\n)[ \t]*backlog\b[:\u2014 -]*[^\n]*[a-zA-Z0-9#]", body, re.I):
        cls = "backlog"
    elif re.search(r"[Bb]locked (by|pending)", body) or \
         re.search(r"(^|\n)[Dd]epends on:[^\n]*#[0-9]+", body):
        cls = "blocked"
    else:
        cls = "undecided"
    print("%s\t%s" % (issue["number"], cls))
PY
}

if [ -n "$issues_source" ]; then
  classified="$(classify_features "$issues_source")" \
    || { echo "could not parse issues JSON: $issues_source" >&2; exit 2; }
  features=0
  while IFS=$'\t' read -r num cls; do
    [ -n "$num" ] || continue
    features=$((features + 1))
    case "$cls" in
      assigned) echo "ok: feature #$num — assigned to a milestone" ;;
      backlog)  echo "ok: feature #$num — explicitly backlogged" ;;
      blocked)  echo "ok: feature #$num — blocked on a named dependency/decision" ;;
      *) gap "feature #$num has no release decision (assign a milestone, record a backlog reason, or name the blocking decision)" ;;
    esac
  done <<< "$classified"
  if [ "$features" -eq 0 ]; then
    echo "note: no open feature issues to assess"
  fi
fi

echo "roadmap-check: $gaps gap(s)"
# Definitive gaps always fail. Otherwise, a run that could not assess the open
# feature inventory is incomplete — exit 3 (not assessed), never a clean 0
# (#224); only a fully-assessed, gap-free run passes.
if [ "$gaps" -gt 0 ]; then
  exit 1
fi
if [ "$issues_assessed" -eq 0 ]; then
  echo "roadmap-check: incomplete — the open-feature inventory was not assessed, so this is NOT a clean pass (exit 3)."
  exit 3
fi
exit 0
