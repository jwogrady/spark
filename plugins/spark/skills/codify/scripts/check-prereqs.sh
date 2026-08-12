#!/usr/bin/env bash
# check-prereqs.sh <issue-number> — Codify's dependency-readiness preflight
# (ADR-0027's ordering invariant: if B depends on A, the state used to Codify
# B must contain A's ACCEPTED INTEGRATED RESULT).
#
# WHY: the zd-dns field test showed scope discipline alone is not enough — a
# dependent issue built on a base that did not contain its prerequisite
# produced locally-valid, semantically-inert work. "Issue A is CLOSED" is not
# that proof (an issue can be closed by hand with nothing merged), and "not
# behind the trunk" is not that proof either (a diverged HEAD shows zero
# behind). This preflight demands POSITIVE proof on two axes before a
# dependent branch is created:
#
#   PREREQUISITE PROOF — every declared blocker's accepted result (the merged
#   pull request GitHub records as closing it) is an ancestor of HEAD.
#   BASE PROOF — HEAD sits exactly at the fresh remote trunk (neither behind
#   nor ahead), so the new issue branch demonstrably originates from the
#   accepted base, not an arbitrary current branch.
#
# Three verdicts, semantically distinct — absence of a detected problem is
# never READY:
#   READY (exit 0)        positive proof on both axes (or no prerequisites
#                         declared, which satisfies the invariant vacuously).
#   BLOCKED (exit 1)      positive proof the invariant is violated (open
#                         blocker, merged result absent from this base, stale
#                         or diverged base, malformed evidence).
#   NOT ASSESSED (exit 3) insufficient evidence (gh unreachable, a closed
#                         blocker with no merged closing PR to verify, a
#                         merged result not present in local history, no
#                         resolvable trunk — or a trunk whose refresh FAILED —
#                         while prerequisites exist). Verify
#                         by hand; this script never guesses.
#
# Blockers come from GitHub's native blocked-by dependencies (what the plan
# skill's manifest writes) plus "Blocked by #N" body lines (the templates'
# convention), deduped. The verdict is a pure function over evidence lines so
# the policy is testable offline; gathering (gh + git) runs only when executed
# directly. All GitHub access is read-only; nothing is fetched destructively
# and drift is never repaired silently.
set -euo pipefail

# prereq_verdict — read evidence lines on stdin, print the human verdict,
# return 0 READY / 1 BLOCKED / 3 NOT ASSESSED.
#   blocker <TAB> <n> <TAB> OPEN|UNKNOWN|INTEGRATED|UNINTEGRATED|UNPROVEN:<why>
#   behind  <TAB> <count> <TAB> <trunk-ref>
#   ahead   <TAB> <count> <TAB> <trunk-ref>
#   trunk   <TAB> none | unrefreshed <TAB> <trunk-ref>
prereq_verdict() {
  local kind a b blockers=0 blocked=0 unassessed=0 trunk="" fresh_seen=0 fresh_ok=1 unrefreshed=
  local blocked_lines="" unassessed_lines=""
  bl() { blocked_lines="${blocked_lines}${1}
"; blocked=$((blocked+1)); }
  na() { unassessed_lines="${unassessed_lines}${1}
"; unassessed=$((unassessed+1)); }
  while IFS=$'\t' read -r kind a b; do
    case "$kind" in
      blocker)
        blockers=$((blockers+1))
        case "$b" in
          INTEGRATED) ;;
          OPEN|UNKNOWN)
            bl "blocked: prerequisite issue #$a is ${b} — its result cannot be in any base yet" ;;
          UNINTEGRATED)
            bl "blocked: prerequisite issue #$a has a merged result that is NOT in this base — start from a base that contains it" ;;
          UNPROVEN:no-merged-result)
            na "not assessed: prerequisite issue #$a is closed but GitHub records no merged pull request closing it — a manual close is not an accepted result; verify integration by hand" ;;
          UNPROVEN:result-not-local)
            na "not assessed: prerequisite issue #$a's merged result is not in local history — fetch the trunk, then re-run" ;;
          *)
            # Malformed classification never passes silently.
            bl "blocked: unreadable prerequisite evidence for #$a ('$b') — verify by hand" ;;
        esac ;;
      behind|ahead)
        fresh_seen=1
        case "$a" in
          ''|*[!0-9]*)
            fresh_ok=0
            bl "blocked: trunk-freshness evidence unreadable ('$a') — verify the base by hand" ;;
          *)
            if [ "$a" -gt 0 ]; then
              fresh_ok=0
              if [ "$kind" = "behind" ]; then
                bl "blocked: this base is $a commit(s) behind $b — a merged prerequisite may be missing; branch from a fresh $b"
              else
                bl "blocked: HEAD is $a commit(s) ahead of/diverged from $b — a branch created here would not originate from the accepted trunk; check out $b (or branch with an explicit start point: git checkout -b <branch> $b)"
              fi
            fi ;;
        esac
        trunk="$b" ;;
      trunk)
        case "$a" in
          none) fresh_seen=0 ;;
          unrefreshed) fresh_seen=0; unrefreshed="$b" ;;
        esac ;;
    esac
  done

  if [ "$blocked" -gt 0 ]; then
    printf '%s' "$blocked_lines"
    [ "$unassessed" -gt 0 ] && printf '%s' "$unassessed_lines"
    return 1
  fi
  if [ "$unassessed" -gt 0 ]; then
    printf '%s' "$unassessed_lines"
    return 3
  fi
  if [ "$blockers" -gt 0 ]; then
    if [ "$fresh_seen" -ne 1 ]; then
      if [ -n "$unrefreshed" ]; then
        echo "not assessed: prerequisites are integrated into HEAD, but $unrefreshed could not be refreshed (git fetch failed) — the freshness of this base is unproven; fetch and re-run"
      else
        echo "not assessed: prerequisites are integrated into HEAD, but no remote trunk is readable to prove this base is the accepted fresh trunk — verify by hand"
      fi
      return 3
    fi
    # fresh_seen=1 and nothing blocked: ahead=0 and behind=0 were proven.
    echo "ready: every prerequisite's merged result is contained in this base, and HEAD is exactly at $trunk"
    return 0
  fi
  # No prerequisites: the ordering invariant is satisfied vacuously.
  if [ "$fresh_seen" -eq 1 ] && [ "$fresh_ok" -eq 1 ]; then
    echo "ready: no prerequisites declared, and HEAD is exactly at $trunk"
  elif [ -n "$unrefreshed" ]; then
    echo "ready: no prerequisites declared ($unrefreshed could not be refreshed — freshness not assessed; fetch before branching)"
  else
    echo "ready: no prerequisites declared (no remote trunk readable — freshness not assessed; branch deliberately)"
  fi
  return 0
}

# resolve_integration <n> — classify a CLOSED blocker's integration state via
# the merged pull request(s) GitHub records as closing it. Echoes one token:
# INTEGRATED | UNINTEGRATED | UNPROVEN:<why>. Returns 1 only when GitHub
# cannot answer at all (caller degrades to NOT ASSESSED).
resolve_integration() {
  local n="$1" oids oid unknown_local=0 saw_merged=0
  oids="$(gh api graphql -F owner=':owner' -F name=':repo' -F num="$n" -f query='
    query($owner: String!, $name: String!, $num: Int!) {
      repository(owner: $owner, name: $name) {
        issue(number: $num) {
          closedByPullRequestsReferences(first: 20, includeClosedPrs: true) {
            nodes { merged mergeCommit { oid } }
          }
        }
      }
    }' --jq '.data.repository.issue.closedByPullRequestsReferences.nodes[] | select(.merged) | .mergeCommit.oid // empty' 2>/dev/null)" || return 1
  for oid in $oids; do
    saw_merged=1
    if ! git cat-file -e "$oid^{commit}" 2>/dev/null; then
      unknown_local=1
    elif git merge-base --is-ancestor "$oid" HEAD 2>/dev/null; then
      echo "INTEGRATED"; return 0
    fi
  done
  if [ "$saw_merged" -eq 0 ]; then
    echo "UNPROVEN:no-merged-result"
  elif [ "$unknown_local" -eq 1 ]; then
    echo "UNPROVEN:result-not-local"
  else
    echo "UNINTEGRATED"
  fi
  return 0
}

# gather_evidence <issue> — emit the evidence lines prereq_verdict reads.
gather_evidence() {
  local issue="$1" nums n state cls body trunk counts behind ahead t
  command -v gh >/dev/null 2>&1 || return 3

  # Resolve and refresh the trunk FIRST, so merged prerequisite commits are in
  # local history before ancestry is judged. A FAILED refresh is recorded —
  # freshness judged against an unrefreshed tracking ref would positively
  # claim "exactly at the fresh trunk" from evidence that may be stale.
  local fetch_ok=1
  trunk="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -z "$trunk" ]; then
    for t in origin/master origin/main; do
      git show-ref --verify --quiet "refs/remotes/$t" && { trunk="$t"; break; }
    done
  fi
  if [ -n "$trunk" ]; then
    git fetch -q origin "${trunk#origin/}" 2>/dev/null || fetch_ok=0
  fi

  # The native blocked-by list is the canonical channel, so a FAILED read is
  # "cannot answer", never "no blockers" — return 3 rather than fail open. An
  # issue with no dependencies answers 200 + [] (rc 0, empty output).
  nums="$(gh api "repos/{owner}/{repo}/issues/$issue/dependencies/blocked_by" \
            --jq '.[].number' 2>/dev/null)" || return 3
  body="$(gh issue view "$issue" --json body --jq .body 2>/dev/null)" || return 3
  nums="$(printf '%s\n%s\n' "$nums" \
      "$(printf '%s\n' "$body" | grep -ioE 'blocked[- ]by[: ]*(#[0-9]+[, ]*)+' \
         | grep -oE '#[0-9]+' | tr -d '#' || true)" \
    | awk 'NF' | sort -un)"

  for n in $nums; do
    state="$(gh issue view "$n" --json state --jq .state 2>/dev/null || echo UNKNOWN)"
    if [ "$state" = "CLOSED" ]; then
      # CLOSED alone proves nothing (#344): resolve the accepted merged
      # result and its ancestry, or say honestly that it cannot be proven.
      cls="$(resolve_integration "$n")" || return 3
      printf 'blocker\t%s\t%s\n' "$n" "$cls"
    else
      printf 'blocker\t%s\t%s\n' "$n" "$state"
    fi
  done

  # Base freshness: both directions. "Not behind" alone is not fresh — a
  # diverged HEAD shows zero behind while starting a branch somewhere else
  # entirely. A failed count emits nothing → freshness stays unproven, and a
  # failed refresh downgrades the whole freshness axis: counts against a
  # stale tracking ref must never back a positive "fresh trunk" claim.
  if [ -n "$trunk" ]; then
    if [ "$fetch_ok" -ne 1 ]; then
      printf 'trunk\tunrefreshed\t%s\n' "$trunk"
    elif counts="$(git rev-list --left-right --count "$trunk...HEAD" 2>/dev/null)"; then
      behind="$(printf '%s' "$counts" | awk '{print $1}')"
      ahead="$(printf '%s' "$counts" | awk '{print $2}')"
      printf 'behind\t%s\t%s\n' "$behind" "$trunk"
      printf 'ahead\t%s\t%s\n' "$ahead" "$trunk"
    fi
  else
    printf 'trunk\tnone\n'
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
    echo "not assessed: gh unavailable or GitHub unreachable — verify prerequisites by hand (issue #$issue's blocked-by list, their merged results, and a fresh trunk base) before branching"
    exit 3
  }
  rc=0
  printf '%s\n' "$evidence" | prereq_verdict || rc=$?
  exit "$rc"
fi
