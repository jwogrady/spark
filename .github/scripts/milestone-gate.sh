#!/usr/bin/env bash
# Milestone-gate decision logic for #194. Pure and side-effect-free: it reads
# the release version and the milestone's issues, then prints a verdict. It
# NEVER merges, tags, or publishes anything, and needs no write access — the
# workflow that calls it posts the commit status and summary from this output.
#
# Mapping: a release whose version is X.Y.* maps to the milestone whose title
# starts with "vX.Y". The gate is:
#   ready    — the mapped milestone has zero open issues AND validate is green
#   blocked  — the milestone has open issues, or validate is not green
#   neutral  — no milestone maps to this version (today's behavior; no signal)
#
# First stdout line is "gate-state: ready|blocked|neutral" for the caller to
# parse; the rest is the human summary. Exit 0 for ready/neutral, 1 for
# blocked, 2 for usage/input error, 3 for not-assessed (no jq/python3).
set -euo pipefail

usage="usage: milestone-gate.sh --manifest FILE --issues FILE [--checks green|red|unknown]"

manifest="" issues_file="" checks="unknown"
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest|--issues|--checks)
      [ $# -ge 2 ] || { echo "$1 needs an argument" >&2; echo "$usage" >&2; exit 2; }
      case "$1" in
        --manifest) manifest="$2" ;;
        --issues)   issues_file="$2" ;;
        --checks)   checks="$2" ;;
      esac
      shift 2 ;;
    -h|--help) echo "$usage"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; echo "$usage" >&2; exit 2 ;;
  esac
done

[ -n "$manifest" ] && [ -f "$manifest" ] || { echo "manifest not found: ${manifest:-<none>}" >&2; exit 2; }
[ -n "$issues_file" ] && [ -f "$issues_file" ] || { echo "issues file not found: ${issues_file:-<none>}" >&2; exit 2; }

have_jq=0 have_py=0
command -v jq >/dev/null 2>&1 && have_jq=1
command -v python3 >/dev/null 2>&1 && have_py=1
if [ "$have_jq" -eq 0 ] && [ "$have_py" -eq 0 ]; then
  echo "gate-state: neutral"
  echo "not assessed (needs jq or python3)"
  exit 3
fi

# Root package version → major.minor (the "." key of the manifest).
if [ "$have_jq" -eq 1 ]; then
  version="$(jq -r '."."' "$manifest" 2>/dev/null || true)"
else
  version="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get(".",""))' "$manifest" 2>/dev/null || true)"
fi
case "$version" in
  ""|null) echo "gate-state: neutral"; echo "release manifest has no root (\".\") version; gate is neutral"; exit 0 ;;
esac
xy="$(printf '%s' "$version" | cut -d. -f1-2)"   # 0.10.0 -> 0.10

# Emit "number<TAB>state" for every issue whose milestone title starts vX.Y.
select_matched() {
  if [ "$have_jq" -eq 1 ]; then
    jq -r --arg xy "$xy" '
      .[]
      | . as $i
      | (($i.milestone // "") | if type == "object" then (.title // "") else . end) as $ms
      | select($ms | test("^v" + $xy + "([^0-9]|$)"))
      | "\($i.number)\t\($i.state // "open")"
    ' "$1"
    return $?
  fi
  python3 - "$1" "$xy" <<'PY'
import json, re, sys
data = json.load(open(sys.argv[1])); xy = sys.argv[2]
pat = re.compile(r"^v" + re.escape(xy) + r"([^0-9]|$)")
for i in data:
    ms = i.get("milestone") or ""
    if isinstance(ms, dict):
        ms = ms.get("title") or ""
    if pat.search(ms):
        print("%s\t%s" % (i["number"], i.get("state") or "open"))
PY
}

matched="$(select_matched "$issues_file")" \
  || { echo "could not parse issues JSON: $issues_file" >&2; exit 2; }

if [ -z "$matched" ]; then
  echo "gate-state: neutral"
  echo "release v${version} maps to no milestone \"v${xy} …\" with issues; gate is neutral (release behavior unchanged)"
  exit 0
fi

open_nums="" open_count=0 closed_count=0
while IFS=$'\t' read -r num state; do
  [ -n "$num" ] || continue
  case "$state" in
    open) open_count=$((open_count + 1)); open_nums="$open_nums #$num" ;;
    *)    closed_count=$((closed_count + 1)) ;;
  esac
done <<< "$matched"

if [ "$open_count" -gt 0 ]; then
  echo "gate-state: blocked"
  echo "Milestone v${xy} is not complete: $open_count open issue(s) —$open_nums. Close them (or move them out of the milestone) before this release is ready."
  exit 1
fi

# Milestone complete. Validation must also be green.
case "$checks" in
  green)
    echo "gate-state: ready"
    echo "Milestone v${xy} is complete: all $closed_count issue(s) closed and validation is green. Ready for human approval — merge the Release Please PR to release v${version}. (This gate performs no release mechanics.)"
    exit 0 ;;
  *)
    echo "gate-state: blocked"
    echo "Milestone v${xy} is complete ($closed_count issue(s) closed) but validation is not green (checks: ${checks}). Not ready."
    exit 1 ;;
esac
