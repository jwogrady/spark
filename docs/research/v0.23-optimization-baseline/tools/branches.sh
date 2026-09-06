#!/usr/bin/env bash
# branches.sh [--fetch] — inventory of remote-tracking refs (refs/remotes/origin/*) relative to the frozen master 921c982.
# What is measured: the LOCAL remote-tracking refs at observation time — i.e. GitHub's branches as of the last
# `git fetch --prune origin`. With --fetch the script fetches first and records that; without it, it records the
# observation as "local remote-tracking state, not refreshed". Ancestry ("merged") is `git merge-base --is-ancestor`
# against 921c982, which cannot see squash merges. Fail-closed: any git failure aborts with a non-zero status.
set -euo pipefail
M=921c9820b92e99ef3620f4f46a0a8a6d7bb0c8b5
prov="local remote-tracking refs, not refreshed by this run"
if [ "${1:-}" = "--fetch" ]; then
  git fetch -q --prune origin
  prov="after git fetch --prune origin at $(date -u +%FT%TZ); remote heads by ls-remote: $(git ls-remote --heads origin | wc -l)"
fi
printf '# provenance: %s; observed at %s; ancestry vs %s\n' "$prov" "$(date -u +%FT%TZ)" "$M"
printf 'branch\tlast_commit_date\tahead_of_master\tbehind_master\tmerged_into_master\n'
refs="$(git for-each-ref --format='%(refname:short)' refs/remotes/origin)"
[ -n "$refs" ] || { echo "no remote-tracking refs found under refs/remotes/origin" >&2; exit 1; }
n=0
for ref in $refs; do
  case "$ref" in origin|origin/HEAD|origin/master) continue ;; esac
  d="$(git log -1 --format=%cs "$ref")"
  ab="$(git rev-list --left-right --count "$M...$ref")"
  behind="${ab%%	*}"; ahead="${ab##*	}"
  if git merge-base --is-ancestor "$ref" "$M"; then merged=yes; else merged=no; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$ref" "$d" "$ahead" "$behind" "$merged"
  n=$((n + 1))
done
[ "$n" -gt 0 ] || { echo "no branches inventoried" >&2; exit 1; }
