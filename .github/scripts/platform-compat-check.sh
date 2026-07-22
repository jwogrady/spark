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
# First stdout line is "gate-state: ready|blocked|neutral" for the caller to
# parse; the rest is the human summary. Exit 0 for ready/neutral, 1 for blocked,
# 2 for usage/input error, 3 for not-assessed (no reliable release range).
set -euo pipefail

usage="usage: platform-compat-check.sh --index FILE --capabilities FILE --evaluations-root DIR [--no-range]"

index="" caps="" eval_root="" no_range=0
while [ $# -gt 0 ]; do
  case "$1" in
    --index)            index="${2:-}"; shift 2 ;;
    --capabilities)     caps="${2:-}"; shift 2 ;;
    --evaluations-root) eval_root="${2:-}"; shift 2 ;;
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

case "$state" in
  blocked) exit 1 ;;
  *)       exit 0 ;;
esac
