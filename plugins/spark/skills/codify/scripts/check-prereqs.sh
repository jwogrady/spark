#!/usr/bin/env bash
# check-prereqs.sh <issue-number> — Codify's dependency-readiness preflight
# (the delivery ADR's ordering invariant: if B depends on A, the state used to
# Codify B must contain A's accepted integrated result).
#
# WHY: the zd-dns field test showed scope discipline alone is not enough — a
# dependent issue branched from a trunk that did not yet contain its
# prerequisite produces locally-valid, semantically-inert work whose
# integration debt surfaces weeks later. The plan skill records dependencies
# in GitHub (native blocked-by links via issue-manifest.sh, and/or a
# "Blocked by #N" line in the issue body per the issue templates); this is the
# read side: fail closed before a branch is created when a declared
# prerequisite is not yet part of the base being built on.
#
# MECHANICS: a prerequisite is "present in the base" when (a) the blocker
# issue is CLOSED — its work landed — and (b) the local HEAD is not behind
# origin/<trunk>, so everything that landed is actually in this base. That
# pair is exact for the observed failure (open blocker, or stale base) and
# needs no per-commit archaeology.
#
# EXIT: 0 ready · 1 blocked (each reason printed, one per line) · 2 usage ·
# 3 not assessed (no gh / no network — the caller must verify by hand; this
# script never guesses).
#
# The verdict is a pure function over evidence lines so the policy is testable
# offline; gathering runs only when executed directly, gh-degrading to 3.
set -euo pipefail

# prereq_verdict — read evidence lines on stdin, print findings, return 0/1.
#   blocker <TAB> <number> <TAB> <OPEN|CLOSED>
#   behind  <TAB> <count>  <TAB> <trunk-ref>
prereq_verdict() {
  local rc=0 kind a b
  while IFS=$'\t' read -r kind a b; do
    case "$kind" in
      blocker)
        if [ "$b" != "CLOSED" ]; then
          echo "blocked: prerequisite issue #$a is $b — its result cannot be in any base yet"
          rc=1
        fi ;;
      behind)
        if [ "${a:-0}" -gt 0 ]; then
          echo "blocked: this base is $a commit(s) behind $b — a merged prerequisite may be missing; branch from a fresh $b"
          rc=1
        fi ;;
    esac
  done
  return $rc
}

# gather_evidence <issue> — emit the evidence lines prereq_verdict reads.
# Blockers come from GitHub's native blocked-by dependencies, plus any
# "Blocked by #N" lines in the issue body (the templates' convention), deduped.
gather_evidence() {
  local issue="$1" nums n state body trunk behind
  command -v gh >/dev/null 2>&1 || return 3

  nums="$(gh api "repos/{owner}/{repo}/issues/$issue/dependencies/blocked_by" \
            --jq '.[].number' 2>/dev/null || true)"
  body="$(gh issue view "$issue" --json body --jq .body 2>/dev/null)" || return 3
  nums="$(printf '%s\n%s\n' "$nums" \
      "$(printf '%s\n' "$body" | grep -ioE 'blocked[- ]by[: ]*(#[0-9]+[, ]*)+' \
         | grep -oE '#[0-9]+' | tr -d '#' || true)" \
    | awk 'NF' | sort -un)"

  for n in $nums; do
    state="$(gh issue view "$n" --json state --jq .state 2>/dev/null || echo UNKNOWN)"
    printf 'blocker\t%s\t%s\n' "$n" "$state"
  done

  # Base freshness against the remote trunk (best-effort fetch keeps this
  # honest without requiring one).
  trunk="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -z "$trunk" ]; then
    for t in origin/master origin/main; do
      git show-ref --verify --quiet "refs/remotes/$t" && { trunk="$t"; break; }
    done
  fi
  if [ -n "$trunk" ]; then
    git fetch -q origin "${trunk#origin/}" 2>/dev/null || true
    behind="$(git rev-list --count "HEAD..$trunk" 2>/dev/null || echo 0)"
    printf 'behind\t%s\t%s\n' "$behind" "$trunk"
  fi
  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  issue="${1:-}"
  case "$issue" in
    ''|*[!0-9]*) echo "usage: check-prereqs.sh <issue-number>" >&2; exit 2 ;;
  esac
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 2; }

  evidence="$(gather_evidence "$issue")" || {
    echo "not assessed: gh unavailable or GitHub unreachable — verify prerequisites by hand (issue #$issue's blocked-by list, and a fresh trunk base) before branching"
    exit 3
  }
  if out="$(printf '%s\n' "$evidence" | prereq_verdict)"; then
    echo "ready: no open prerequisite and the base is current with the trunk"
    exit 0
  else
    printf '%s\n' "$out"
    exit 1
  fi
fi
