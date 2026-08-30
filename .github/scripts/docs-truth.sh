#!/usr/bin/env bash
# docs-truth — is the repository describing the state that will exist after this
# release? (#484)
#
# Spark's three binding gates are doctor, tests and milestone-gate. Documentation
# was a human checkbox, so a release could go green while current-state docs were
# stale. This makes the documentation state provable.
#
# It COMPOSES existing authorities and reimplements none of them:
#
#   Layer 1  structural   -> spark doctor, which already owns every list-vs-list
#                            parity check, plus the release-scope checks that
#                            need GitHub and therefore cannot live in an offline
#                            deterministic binary
#   Layer 2  interface    -> the CLI compatibility classification, enforced
#                            inside doctor against preferences/cli-stability.tsv
#   Layer 3  semantic     -> a BOUNDED per-issue claim list, verified by a human
#                            whose verdict lives in GitHub evidence on the
#                            release PR
#
# Three rules the design turns on:
#
#   * NOT ASSESSED is never green, and the report always names which layer could
#     not be assessed and why. A gate that cannot tell "passed" from "could not
#     look" is not a gate.
#   * The semantic verdict is never committed to the tree. Writing a review
#     verdict into repository documentation would put change-over-time evidence
#     into a current-state surface -- exactly what the state/provenance contract
#     forbids. A gate that forces its own violation is worthless.
#   * A verdict is bound to an exact HEAD SHA. When the release PR moves, the
#     previous verdict is stale by arithmetic, with no grace period and no
#     judgement call.
set -uo pipefail

REPO="${DOCS_TRUTH_REPO:-}"
PR=""
HEAD_SHA=""
MILESTONE="${DOCS_TRUTH_MILESTONE:-}"
SPARK_BIN=""

usage() {
  cat <<'USAGE'
usage: docs-truth.sh [--pr <n>] [--head <sha>] [--repo <owner/name>] [--milestone <title>]

Exits 0 PASS, 1 FAIL, 3 NOT ASSESSED, 2 usage.
NOT ASSESSED is never green; the report names the layer that could not be read.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pr)        shift; PR="${1:-}" ;;
    --pr=*)      PR="${1#--pr=}" ;;
    --head)      shift; HEAD_SHA="${1:-}" ;;
    --head=*)    HEAD_SHA="${1#--head=}" ;;
    --repo)      shift; REPO="${1:-}" ;;
    --repo=*)    REPO="${1#--repo=}" ;;
    --milestone) shift; MILESTONE="${1:-}" ;;
    --milestone=*) MILESTONE="${1#--milestone=}" ;;
    -h|--help)   usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  if [ "$#" -gt 0 ]; then shift; fi
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  printf 'docs-truth must run inside a git repository\n' >&2
  exit 2
fi
SPARK_BIN="$ROOT/plugins/spark/bin/spark"

# Verdict accumulation. FAIL beats NOT ASSESSED beats PASS, because a gate must
# never report the most flattering answer it can justify.
fails=0
unassessed=0
report=""
row() { report="${report}$1"$'\n'; }
fail()   { row "  FAIL          $1"; fails=$((fails+1)); }
unknown(){ row "  NOT ASSESSED  $1"; unassessed=$((unassessed+1)); }
pass()   { row "  PASS          $1"; }

have_gh() { command -v gh >/dev/null 2>&1; }

# --- Layer 1: structural -----------------------------------------------------
# doctor is the authority. This runs it and reports its verdict; it does not
# re-derive a single one of its checks.
if [ -x "$SPARK_BIN" ]; then
  if "$SPARK_BIN" doctor >/dev/null 2>&1; then
    pass "structural — spark doctor reports no errors"
  else
    fail "structural — spark doctor reports errors (run it for the detail)"
  fi
else
  unknown "structural — the repository spark binary was not found at plugins/spark/bin/spark"
fi

# --- Layer 1b: every open milestone has a ROADMAP section --------------------
# roadmap-check.sh validates the sections that exist; nothing proved one exists
# per milestone, which is how a milestone ships with no published outcome.
if [ ! -f "$ROOT/ROADMAP.md" ]; then
  unknown "roadmap — ROADMAP.md is absent"
elif ! have_gh; then
  unknown "roadmap — gh is unavailable, so open milestones could not be listed"
else
  # Written out rather than defaulted inline: `${REPO:-{owner}/{repo}}` ends the
  # expansion at the first brace and builds a malformed URL.
  api_target="$REPO"
  [ -n "$api_target" ] || api_target='{owner}/{repo}'
  ms="$(gh api "repos/$api_target/milestones?state=open&per_page=100" \
        --jq '.[].title' 2>/dev/null)" || ms="__unreadable__"
  if [ "$ms" = "__unreadable__" ]; then
    unknown "roadmap — the milestone list could not be read"
  elif [ -z "$ms" ]; then
    pass "roadmap — no open milestone requires a section"
  else
    missing=""
    while IFS= read -r title; do
      [ -n "$title" ] || continue
      # Match the version token (e.g. v0.23) rather than the full prose title,
      # which carries a theme the ROADMAP heading does not repeat.
      ver="$(printf '%s' "$title" | grep -o 'v[0-9]\+\.[0-9]\+' | head -n1)"
      key="${ver:-$title}"
      grep -q -- "$key" "$ROOT/ROADMAP.md" || missing="${missing}${missing:+, }${key}"
    done <<EOF
$ms
EOF
    if [ -n "$missing" ]; then
      fail "roadmap — open milestone(s) with no ROADMAP section: $missing"
    else
      pass "roadmap — every open milestone has a ROADMAP section"
    fi
  fi
fi

# --- Layer 1c: every issue in the release declares a documentation impact -----
if [ -z "$MILESTONE" ]; then
  unknown "dispositions — no milestone given, so the release scope is unknown"
elif ! have_gh; then
  unknown "dispositions — gh is unavailable, so release issues could not be listed"
else
  # An empty --repo is an error to gh, so the flag is omitted rather than blank.
  set -- ; [ -n "$REPO" ] && set -- --repo "$REPO"
  rows="$(gh issue list "$@" --milestone "$MILESTONE" --state all --limit 200 \
          --json number,labels --jq '.[] | [(.number|tostring), ([.labels[].name] | map(select(startswith("docs-impact:"))) | join(","))] | @tsv' 2>/dev/null)" \
    || rows="__unreadable__"
  if [ "$rows" = "__unreadable__" ]; then
    unknown "dispositions — the milestone's issues could not be read"
  else
    undeclared=""
    claims=""
    while IFS=$'\t' read -r num imp; do
      [ -n "$num" ] || continue
      if [ -z "$imp" ]; then
        undeclared="${undeclared}${undeclared:+, }#${num}"
        continue
      fi
      # A claim is an issue that changed documentation. `none` declares that it
      # did not, and is a complete answer, not an omission.
      case "$imp" in
        docs-impact:none) ;;
        *) claims="${claims}${num}"$'\t'"${imp}"$'\n' ;;
      esac
    done <<EOF
$rows
EOF
    if [ -n "$undeclared" ]; then
      fail "dispositions — issue(s) with no docs-impact declaration: $undeclared"
    else
      pass "dispositions — every issue in the release declares a documentation impact"
    fi
  fi
fi

# --- Layer 3: the bounded semantic claim list --------------------------------
# The value is entirely in the narrowing. Not "review the docs" but "these
# issues changed behaviour; verify these current-state documents."
verdict_sha=""
verdict_author=""
verdict_body=""
if [ -n "${claims:-}" ] && [ -n "$PR" ] && have_gh; then
  # Reviewer identity comes from GitHub, never from prose inside the comment.
  set -- ; [ -n "$REPO" ] && set -- --repo "$REPO"
  verdict_body="$(gh pr view "$PR" "$@" --json comments \
    --jq '[.comments[] | select(.body | test("^docs-truth: [0-9a-f]{7,40}"))] | last | (.author.login // "") + ":::" + (.body // "")' 2>/dev/null)" \
    || verdict_body=""
  verdict_author="${verdict_body%%:::*}"
  verdict_body="${verdict_body#*:::}"
  verdict_sha="$(printf '%s' "$verdict_body" | head -n1 | sed -n 's/^docs-truth: \([0-9a-f]\{7,40\}\).*/\1/p')"
fi

if [ -z "${claims:-}" ]; then
  if [ "$unassessed" -gt 0 ]; then
    unknown "semantic — the claim list could not be derived"
  else
    pass "semantic — no issue in this release changed documentation"
  fi
elif [ -z "$PR" ]; then
  unknown "semantic — no release PR given, so no verdict could be located"
elif [ -z "$verdict_sha" ]; then
  unknown "semantic — no docs-truth verdict found on PR #$PR"
  row ""
  row "  Claims requiring review:"
  while IFS=$'\t' read -r num imp; do
    [ -n "$num" ] || continue
    row "    #$num  $imp"
  done <<EOF
$claims
EOF
elif [ -n "$HEAD_SHA" ] && [ "$verdict_sha" != "${HEAD_SHA:0:${#verdict_sha}}" ]; then
  # Staleness is arithmetic. The PR moved; the verdict describes an earlier tree.
  fail "semantic — the verdict covers $verdict_sha but the PR head is $HEAD_SHA"
else
  unresolved=""
  while IFS=$'\t' read -r num imp; do
    [ -n "$num" ] || continue
    if ! printf '%s' "$verdict_body" | grep -qE "^#${num}[[:space:]]+(PASS|FAIL)\b"; then
      unresolved="${unresolved}${unresolved:+, }#${num}"
    elif printf '%s' "$verdict_body" | grep -qE "^#${num}[[:space:]]+FAIL\b"; then
      unresolved="${unresolved}${unresolved:+, }#${num}(FAIL)"
    fi
  done <<EOF
$claims
EOF
  if [ -n "$unresolved" ]; then
    fail "semantic — unverified or failing claim(s): $unresolved"
  else
    pass "semantic — every claim verified at $verdict_sha by @${verdict_author:-unknown}"
  fi
fi

# --- Report ------------------------------------------------------------------
echo "docs-truth — does the repository describe the state this release will ship?"
echo
printf '%s' "$report"
echo

if [ "$fails" -gt 0 ]; then
  echo "FAIL — documentation truth is not established."
  exit 1
fi
if [ "$unassessed" -gt 0 ]; then
  echo "NOT ASSESSED — a layer could not be evaluated; that is never green."
  exit 3
fi
echo "PASS — the repository describes the state this release will ship."
exit 0
