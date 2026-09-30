#!/usr/bin/env bash
# branch-census.sh [--delete] — remote-branch disposition for #744, from GitHub truth, fail-closed.
#
# A remote branch is a SAFE STALE REF only when every one of these holds, each read from its own source:
#   1. its current SHA on origin equals the head SHA of a MERGED pull request whose head ref is that branch
#      (`gh api pulls`, all pages); a familiar name, or "looks merged", is not evidence;
#   2. it is not the default branch and not a release-please branch;
#   3. it is not the head of an OPEN pull request;
#   4. it is recreatable from durable history: the SHA is an ancestor of origin/master (merge-commit landing)
#      OR GitHub still serves it as refs/pull/<n>/head (squash landing) — checked by ls-remote, not assumed.
# Everything else is KEEP or REVIEW, never deleted here. With --delete, each safe ref is deleted through the
# API one at a time and the outcome is recorded per row; the first API failure aborts the run.
#
# Output: a TSV on stdout — branch, sha, last_commit_date, disposition, pr, pr_state, in_master, pull_ref,
# action, result — preceded by a provenance line. Deterministic for a given remote state. The #744 record
# keeps it as docs/research/v0.23-cleanup/744-branch-census.tsv.
set -euo pipefail

mode="census"
TMPDIR_ERR="$(mktemp)"; trap 'rm -f "$TMPDIR_ERR"' EXIT
[ "${1:-}" = "--delete" ] && mode="delete"

repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"; [ -n "$repo" ]
default="$(gh api "repos/$repo" --jq .default_branch)"; [ -n "$default" ]
git fetch -q --prune origin
fetched_at="$(date -u +%FT%TZ)"; [ -n "$fetched_at" ]

# Remote heads from the remote itself, not from local tracking refs.
heads="$(git ls-remote --heads origin)"; [ -n "$heads" ]
n_heads="$(printf '%s\n' "$heads" | grep -c .)"

# Every pull request, every page: number, state, merged_at, head ref, head sha.
prs="$(gh api --paginate "repos/$repo/pulls?state=all&per_page=100" \
  --jq '.[] | [.number, .state, (.merged_at // ""), .head.ref, .head.sha] | @tsv')"; [ -n "$prs" ]
n_prs="$(printf '%s\n' "$prs" | grep -c .)"

# Pull refs the remote still serves — the durable-recreation check for squash landings.
pull_refs="$(git ls-remote origin 'refs/pull/*/head')"; [ -n "$pull_refs" ]

printf '# provenance: repo %s; default %s; fetched %s; remote heads %s; pull requests %s; mode %s\n' \
  "$repo" "$default" "$fetched_at" "$n_heads" "$n_prs" "$mode"
printf 'branch\tsha\tlast_commit_date\tdisposition\tpr\tpr_state\tin_master\tpull_ref\taction\tresult\n'

n=0; safe=0; deleted=0
while IFS=$'\t' read -r sha ref; do
  [ -n "$ref" ] || continue
  branch="${ref#refs/heads/}"
  date_="$(git log -1 --format=%cs "$sha" 2>/dev/null || echo unknown)"
  disposition=""; pr="-"; pr_state="-"; in_master="-"; pull_ref="-"; action="keep"

  if [ "$branch" = "$default" ]; then
    disposition="protected-default"
  elif [ "${branch#release-please--}" != "$branch" ]; then
    disposition="protected-release"
  else
    # Lookups read their whole input: an early `exit` closes the pipe under printf, and pipefail
    # rightly turns that SIGPIPE into a failed run.
    open_pr="$(printf '%s\n' "$prs" | awk -F'\t' -v b="$branch" '$4 == b && $2 == "open" && !f { f = 1; r = $1 } END { if (f) print r }')"
    if [ -n "$open_pr" ]; then
      disposition="active-pr-head"; pr="$open_pr"; pr_state="open"
    else
      # exact SHA against a MERGED pull request's head — merged_at set, never inferred from "closed"
      merged_pr="$(printf '%s\n' "$prs" | awk -F'\t' -v b="$branch" -v s="$sha" '$4 == b && $5 == s && $3 != "" && !f { f = 1; r = $1 } END { if (f) print r }')"
      any_pr="$(printf '%s\n' "$prs" | awk -F'\t' -v b="$branch" '$4 == b && !f { f = 1; r = $1 ":" $2 ($3 != "" ? "/merged" : "") } END { if (f) print r }')"
      if [ -n "$merged_pr" ]; then
        pr="$merged_pr"; pr_state="merged"
        if git merge-base --is-ancestor "$sha" origin/master; then in_master=yes
        else rc=$?; [ "$rc" -eq 1 ] || { echo "git merge-base failed ($rc) for $branch" >&2; exit "$rc"; }; in_master=no; fi
        if printf '%s\n' "$pull_refs" | awk -F'\t' -v s="$sha" -v r="refs/pull/$merged_pr/head" '$1 == s && $2 == r { f = 1 } END { exit !f }'
        then pull_ref=yes; else pull_ref=no; fi
        if [ "$in_master" = yes ] || [ "$pull_ref" = yes ]; then
          disposition="safe-stale"; action="delete"; safe=$((safe + 1))
        else
          disposition="review-not-recreatable"; action="review"
        fi
      elif [ -n "$any_pr" ]; then
        pr="${any_pr%%:*}"; pr_state="${any_pr#*:}"
        case "$pr_state" in
          *merged*) disposition="review-sha-differs"; action="review" ;;
          *)        disposition="review-closed-unmerged"; action="review" ;;
        esac
      else
        disposition="review-no-pr"; action="review"
      fi
    fi
  fi

  result="-"
  if [ "$mode" = delete ] && [ "$action" = delete ]; then
    # One ref per call; a failure stops the run so a partial deletion is never reported as complete.
    if gh api -X DELETE "repos/$repo/git/refs/heads/$branch" >/dev/null 2>"$TMPDIR_ERR"; then
      result="deleted"; deleted=$((deleted + 1))
    else
      echo "delete failed for $branch: $(cat "$TMPDIR_ERR")" >&2; exit 1
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$branch" "$sha" "$date_" "$disposition" "$pr" "$pr_state" "$in_master" "$pull_ref" "$action" "$result"
  n=$((n + 1))
done < <(printf '%s\n' "$heads" | awk -F'\t' '{ print $1 "\t" $2 }')

[ "$n" -eq "$n_heads" ] || { echo "inventoried $n of $n_heads heads" >&2; exit 1; }
printf '# summary: heads %s; safe-stale %s; deleted %s\n' "$n" "$safe" "$deleted"
