#!/usr/bin/env bash
# Platform Compatibility Review — decision logic for the Evaluation -> Release
# seam (#300, Constitution Article VII, ADR-0026). Pure and deterministic: it
# reads the evidence index and the list of capabilities in a release, then
# prints a verdict. It NEVER merges, tags, or releases; the runner that calls it
# posts the status and comment from this output.
#
# It CONSUMES the Evaluation surface — for a `required` capability it invokes the
# suite's own `run.sh validate <topology>` (ADR-0025/eval.sh) and reads only
# pass/fail. It never scores, recomputes, compares, or reinterprets results.
#
# Classification (see ADR-0026):
#   declared-and-valid   required + suite/topology resolve + validate passes
#   not-required         a deliberate CEF decision; reported, never blocks
#   declared-but-invalid required but incomplete/missing/malformed/validate-fails
#   undeclared           has a stable id but no index entry; advisory
#   unresolved-identity  no stable capability id at all (empty id); advisory
#
# Only declared-but-invalid `required` evidence blocks the release in this phase.
# A capabilities line with a "-" sentinel id (no resolvable issue reference) is
# unresolved — reported, never blocking, never assigned an invented identity.
#
# It also carries the ADR-status ADVISORY (#305, Constitution Article VII):
# when --adr-dir (and optionally --issues) is provided, it reports whether each
# ADR has a recognized Status and — a labeled HEURISTIC — whether a Status that
# references gate issues in its parenthetical points only at closed issues, so a
# human can confirm the Status still matches the recorded verdict. ADR findings
# never change gate-state and never change the exit code: the release verdict
# stays driven purely by the declared-evidence findings above.
#
# First stdout line is "gate-state: ready|blocked|neutral" for the caller to
# parse; the rest is the human summary. Exit 0 for ready/neutral, 1 for blocked,
# 2 for usage/input error, 3 for not-assessed (no reliable release range).
set -euo pipefail

usage="usage: platform-compat-check.sh --index FILE --capabilities FILE --evaluations-root DIR [--adr-dir DIR] [--issues FILE] [--no-range]"

index="" caps="" eval_root="" adr_dir="" issues_file="" no_range=0
while [ $# -gt 0 ]; do
  case "$1" in
    --index)            index="${2:-}"; shift 2 ;;
    --capabilities)     caps="${2:-}"; shift 2 ;;
    --evaluations-root) eval_root="${2:-}"; shift 2 ;;
    --adr-dir)          adr_dir="${2:-}"; shift 2 ;;
    --issues)           issues_file="${2:-}"; shift 2 ;;
    --no-range)         no_range=1; shift ;;
    -h|--help)          echo "$usage"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; echo "$usage" >&2; exit 2 ;;
  esac
done

# No reliable release range: report honestly, do not guess. Mirrors the
# milestone gate's not-assessed convention (exit 3).
if [ "$no_range" -eq 1 ]; then
  echo "gate-state: neutral"
  echo "not assessed: release range unavailable — no capabilities could be resolved."
  exit 3
fi

[ -n "$index" ] && [ -f "$index" ] || { echo "index not found: ${index:-<none>}" >&2; echo "$usage" >&2; exit 2; }
[ -n "$caps" ] && [ -f "$caps" ]   || { echo "capabilities file not found: ${caps:-<none>}" >&2; echo "$usage" >&2; exit 2; }
[ -n "$eval_root" ]                || { echo "--evaluations-root is required" >&2; echo "$usage" >&2; exit 2; }
# The ADR inputs are optional, but once PROVIDED they must resolve — a typo'd
# path is an input error (exit 2), never a silently-skipped advisory.
[ -z "$adr_dir" ] || [ -d "$adr_dir" ]         || { echo "adr dir not found: $adr_dir" >&2; echo "$usage" >&2; exit 2; }
[ -z "$issues_file" ] || [ -f "$issues_file" ] || { echo "issues file not found: $issues_file" >&2; echo "$usage" >&2; exit 2; }

# All index rows whose column-1 id equals $1, as "requirement<TAB>suite<TAB>topology".
index_rows_for() {
  awk -F'\t' -v id="$1" '
    /^[[:space:]]*#/ {next} /^[[:space:]]*$/ {next}
    $1==id { print $2 "\t" $3 "\t" $4 }' "$index"
}

valid=() notreq=() undeclared=() unresolved=() blocked=()

while IFS=$'\t' read -r cid label || [ -n "${cid:-}${label:-}" ]; do
  cid="${cid:-}"; label="${label:-}"
  # Skip comment lines and truly blank lines (no id, no label).
  case "$cid" in \#*) continue ;; esac
  [ -z "$cid" ] && continue
  if [ "$cid" = "-" ]; then
    # A feat with no resolvable stable id (the "-" sentinel). Never invent an
    # identity from the subject (ADR-0026) — classify as unresolved, advisory.
    [ -n "$label" ] && unresolved+=("  feat \"$label\" — no issue reference; capability identity unresolved (advisory)")
    continue
  fi
  who="capability $cid${label:+ ($label)}"

  rows="$(index_rows_for "$cid")"
  count=0
  [ -n "$rows" ] && count="$(printf '%s\n' "$rows" | grep -c .)"

  if [ "$count" -eq 0 ]; then
    undeclared+=("  $who — no evidence-index entry"); continue
  fi
  if [ "$count" -gt 1 ]; then
    blocked+=("  $who — ambiguous: $count evidence-index entries for one capability"); continue
  fi

  IFS=$'\t' read -r requirement suite topology <<EOF
$rows
EOF
  case "$requirement" in
    not-required)
      notreq+=("  $who — declared not-required (deliberate CEF decision)") ;;
    required)
      if [ -z "$suite" ] || [ -z "$topology" ]; then
        blocked+=("  $who — incomplete required declaration (suite/topology empty)"); continue
      fi
      if [ ! -f "$eval_root/$suite/run.sh" ]; then
        blocked+=("  $who — required suite '$suite' is missing"); continue
      fi
      if [ ! -d "$eval_root/$suite/runs/$topology" ]; then
        blocked+=("  $who — required topology '$topology' is missing under suite '$suite'"); continue
      fi
      if bash "$eval_root/$suite/run.sh" validate "$topology" >/dev/null 2>&1; then
        valid+=("  $who — declared required; evidence valid ($suite/$topology)")
      else
        blocked+=("  $who — required evidence failed the suite's validate ($suite/$topology)")
      fi ;;
    *)
      blocked+=("  $who — unknown requirement value '$requirement' (want required|not-required)") ;;
  esac
done < "$caps"

# Verdict: block on any invalid required declaration; ready only when at least
# one required capability was verified; neutral when there is nothing to enforce.
if [ "${#blocked[@]}" -gt 0 ]; then
  state="blocked"
elif [ "${#valid[@]}" -gt 0 ]; then
  state="ready"
else
  state="neutral"
fi

echo "gate-state: $state"
echo "Platform Compatibility Review — declared evaluation evidence for this release."
echo "(This gate checks DECLARED evidence only; it does not claim all capabilities were evaluated.)"
echo
echo "declared and valid (required):   ${#valid[@]}"
[ "${#valid[@]}" -gt 0 ] && printf '%s\n' "${valid[@]}"
echo "explicitly not required:         ${#notreq[@]}"
[ "${#notreq[@]}" -gt 0 ] && printf '%s\n' "${notreq[@]}"
echo "declared but invalid (required): ${#blocked[@]}"
[ "${#blocked[@]}" -gt 0 ] && printf '%s\n' "${blocked[@]}"
echo "undeclared (advisory):           ${#undeclared[@]}"
[ "${#undeclared[@]}" -gt 0 ] && printf '%s\n' "${undeclared[@]}"
echo "unresolved identity (advisory):  ${#unresolved[@]}"
[ "${#unresolved[@]}" -gt 0 ] && printf '%s\n' "${unresolved[@]}"

# ----------------------------------------------------------------------------
# ADR status (advisory) — the automatable half of #305 (Article VII: an
# Accepted, experiment-gated ADR must carry a status matching its experiment's
# verdict; re-status, never implement around a killed experiment).
#
# ADVISORY ONLY: nothing below touches $state or the exit code — the gate
# verdict above is driven purely by declared-evidence findings. Two rules:
#   (1) DETERMINISTIC — every ADR (except 0000-template.md) must have a
#       `Status:` line whose value starts with Proposed|Accepted|Superseded.
#   (2) HEURISTIC (labeled as such in the output) — when the Status line's
#       parenthetical references gate/experiment issues (#N) and EVERY such
#       issue is closed, prompt a human to CONFIRM the Status still reflects
#       the recorded verdict. A closed gate is not proof the Status is wrong,
#       so the wording asks for confirmation — it never asserts an error.
#       An issue that is open, or not present in the issues file, suppresses
#       the prompt: we only prompt on positive evidence of closure.
echo
if [ -z "$adr_dir" ]; then
  echo "ADR status (advisory): not assessed (--adr-dir not provided)."
else
  adr_total=0 adr_recognized=0 heuristic_note=""
  adr_findings=()
  closed=""   # newline-separated closed issue numbers from --issues
  if [ -z "$issues_file" ]; then
    heuristic_note="closed-gate heuristic not assessed (--issues not provided)"
  else
    # Same graceful degradation as milestone-gate.sh: jq, then python3, then an
    # honest "not assessed" — never a fabricated clean sweep.
    if command -v jq >/dev/null 2>&1; then
      if ! closed="$(jq -r '.[] | select(((.state // "") | ascii_upcase) == "CLOSED") | .number' "$issues_file" 2>/dev/null)"; then
        closed=""; heuristic_note="closed-gate heuristic not assessed (issues file unparseable)"
      fi
    elif command -v python3 >/dev/null 2>&1; then
      if ! closed="$(python3 -c '
import json, sys
for i in json.load(open(sys.argv[1])):
    if str(i.get("state") or "").upper() == "CLOSED":
        print(i.get("number", ""))' "$issues_file" 2>/dev/null)"; then
        closed=""; heuristic_note="closed-gate heuristic not assessed (issues file unparseable)"
      fi
    else
      heuristic_note="closed-gate heuristic not assessed (needs jq or python3)"
    fi
  fi

  for adr in "$adr_dir"/*.md; do
    [ -e "$adr" ] || continue
    name="$(basename "$adr")"
    # The template's Status line is the placeholder menu, not a decision.
    [ "$name" = "0000-template.md" ] && continue
    adr_total=$((adr_total + 1))
    status_line="$(grep -m1 '^Status:' "$adr" || true)"
    if ! printf '%s' "$status_line" | grep -qE '^Status:[[:space:]]*(Proposed|Accepted|Superseded)'; then
      adr_findings+=("  $name — no recognized Status line (want Proposed|Accepted|Superseded)")
      continue
    fi
    adr_recognized=$((adr_recognized + 1))
    [ -n "$heuristic_note" ] && continue
    # HEURISTIC: issue refs are read only from the Status line's parenthetical
    # (the experiment-gated pattern, e.g. "Accepted (…, at the #198 decision
    # gate — …)"), not from the rest of the line or the document.
    refs="$(printf '%s' "$status_line" | grep -oE '\([^)]*\)' | grep -oE '#[0-9]+' | tr -d '#' | sort -u || true)"
    [ -z "$refs" ] && continue
    # A recorded resolution IS the confirmation this prompt asks for: a Status
    # line carrying "verdict annotated/confirmed <date>" has already answered
    # the closed-gate question, so re-prompting every release would be noise.
    if printf '%s' "$status_line" | grep -qiE 'verdict (annotated|confirmed)'; then
      continue
    fi
    all_closed=1
    while IFS= read -r n; do
      printf '%s\n' "$closed" | grep -qx "$n" || all_closed=0
    done <<EOF
$refs
EOF
    if [ "$all_closed" -eq 1 ]; then
      reflist="$(printf '%s\n' "$refs" | sed 's/^/#/' | tr '\n' ' ' | sed 's/ $//')"
      adr_findings+=("  $name — Status references closed gate issue(s) $reflist; confirm the Status still reflects the recorded verdict (re-status or annotate)")
    fi
  done

  if [ "${#adr_findings[@]}" -gt 0 ]; then
    echo "ADR status (advisory): $adr_recognized of $adr_total ADRs have a recognized Status; ${#adr_findings[@]} advisory finding(s) (heuristic — Status-line issue refs only); gate-state and exit code above are unchanged."
    printf '%s\n' "${adr_findings[@]}"
  else
    echo "ADR status (advisory): $adr_total ADRs have a recognized Status; no closed-gate confirmation prompts (heuristic — Status-line issue refs only)."
  fi
  [ -n "$heuristic_note" ] && echo "  note: $heuristic_note"
fi

case "$state" in
  blocked) exit 1 ;;
  *)       exit 0 ;;
esac
