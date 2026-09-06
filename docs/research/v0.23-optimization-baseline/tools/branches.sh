#!/usr/bin/env bash
# Remote branch inventory relative to frozen master 921c982 (read-only, from this worktree's shared object store)
set -uo pipefail
M=921c9820b92e99ef3620f4f46a0a8a6d7bb0c8b5
printf 'branch\tlast_commit_date\tahead_of_master\tbehind_master\tmerged_into_master\n'
for ref in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v -e '^origin$' -e '^origin/HEAD$' -e '^origin/master$'); do
  d="$(git log -1 --format=%cs "$ref")"
  ab="$(git rev-list --left-right --count "$M...$ref")"
  behind="${ab%%	*}"; ahead="${ab##*	}"
  if git merge-base --is-ancestor "$ref" "$M"; then merged=yes; else merged=no; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$ref" "$d" "$ahead" "$behind" "$merged"
done
