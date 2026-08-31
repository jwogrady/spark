#!/usr/bin/env bash
# Stage 3 — the deterministic publisher for the Claude coding lane (#583).
#
# This is the only job that holds a write credential, and it is a Git-only SSH
# deploy key: it can push a ref, and it cannot authenticate to GitHub's REST or
# GraphQL API, so it cannot merge — the merge endpoints have no transport here.
# The key belongs to this job alone; Claude's job never references it.
#
# Everything the publisher runs is TRUSTED code from the default-branch checkout
# ($TRUSTED_DIR). It treats Claude's patch as untrusted DATA: it applies it with
# git plumbing (hooks disabled) and never executes anything from the PR-head
# tree ($TARGET_DIR) while the key is present. The patch is admitted only after
# identity, freshness, and path/mode validation all pass; a moved head refuses
# rather than rebases.
#
# Required env:
#   CTX_REPO, CTX_PR         the workflow's own view (github.repository, PR number)
#   REPO, PR_NUMBER          the resolver's recorded identity
#   HEAD_REPO, HEAD_REF      resolved head repository and branch
#   HEAD_SHA                 the exact head SHA captured before Claude ran
#   DEFAULT_BRANCH           the base repo default branch
#   PATCH                    path to the unified-diff change artifact
#   TRUSTED_DIR, TARGET_DIR  default-branch and PR-head checkouts
#   DEPLOY_KEY               the write SSH deploy key (private), this job only
#   RUNNER_TEMP              a private temp dir
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$here/lib.sh"

refuse() { echo "PUBLISH REFUSED: $*" >&2; exit 1; }

: "${CTX_REPO:?}" "${CTX_PR:?}" "${REPO:?}" "${PR_NUMBER:?}" "${HEAD_REPO:?}"
: "${HEAD_REF:?}" "${HEAD_SHA:?}" "${DEFAULT_BRANCH:?}" "${PATCH:?}"
: "${TRUSTED_DIR:?}" "${TARGET_DIR:?}" "${RUNNER_TEMP:?}"

# 1. Identity — the resolver's record must match the workflow's own context, and
#    must describe a same-repository non-default branch.
if id="$(cl_check_identity "$REPO" "$CTX_REPO" "$PR_NUMBER" "$CTX_PR" "$HEAD_REPO" "$HEAD_REF" "$DEFAULT_BRANCH")"; then :; else
  refuse "$id"
fi
[ -f "$PATCH" ] || refuse "no change artifact at $PATCH"

# 2. Target must actually be at the expected head before anything is applied.
target_head="$(git -C "$TARGET_DIR" rev-parse HEAD)"
cl_check_stale_head "$HEAD_SHA" "$target_head" || refuse "target checkout $target_head is not expected head $HEAD_SHA"

# 3. Pin the SSH credential and GitHub's host key. No StrictHostKeyChecking=no:
#    an unverified host is a refusal, not a warning.
key_file="$RUNNER_TEMP/claude_publish_key"
known_hosts="$RUNNER_TEMP/claude_known_hosts"
( umask 077; printf '%s\n' "$DEPLOY_KEY" > "$key_file" )
cat > "$known_hosts" <<'KH'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
KH
export GIT_SSH_COMMAND="ssh -i $key_file -o IdentitiesOnly=yes -o UserKnownHostsFile=$known_hosts -o StrictHostKeyChecking=yes"
ssh_url="git@github.com:$REPO.git"

# 4. Freshness against the remote — the branch tip must still be the captured
#    SHA. A head that moved while Claude worked refuses; it never rebases.
remote_head="$(git ls-remote "$ssh_url" "refs/heads/$HEAD_REF" | awk 'NR==1{print $1}')"
cl_check_stale_head "$HEAD_SHA" "$remote_head" || refuse "stale head: remote $HEAD_REF is $remote_head, expected $HEAD_SHA"

# 5. Apply the patch to the index with hooks disabled and no unsafe paths. git
#    apply already refuses paths outside the repo; the mode/path validator below
#    is the second, load-bearing gate.
git -C "$TARGET_DIR" -c core.hooksPath=/dev/null reset -q
git -C "$TARGET_DIR" -c core.hooksPath=/dev/null apply --index --whitespace=nowarn "$PATCH" \
  || refuse "patch does not apply cleanly to $HEAD_SHA"

# 6. Validate the resulting tree by git's own index — modes and paths, both
#    sides of every rename. Any forbidden path or indirection mode refuses.
if violation="$(cl_index_changes "$TARGET_DIR" | cl_validate_paths)"; then :; else
  refuse "${violation:-forbidden change}"
fi
[ -n "$(git -C "$TARGET_DIR" diff --cached --name-only)" ] || refuse "empty change — nothing to publish"

# 7. Commit with plumbing: no hooks, a fixed identity, parent = the captured
#    head, so the push below is a plain fast-forward or nothing.
commit="$(git -C "$TARGET_DIR" \
  -c core.hooksPath=/dev/null \
  -c user.name="spark-claude-lane" \
  -c user.email="claude-lane@users.noreply.github.com" \
  commit --no-verify -q -m "$(printf 'chore: publish Claude change for PR #%s\n\nProduced by the Claude coding lane and published deterministically (#583).\nBase %s.' "$PR_NUMBER" "$HEAD_SHA")" >/dev/null; git -C "$TARGET_DIR" rev-parse HEAD)"

# 8. Re-check the remote immediately before pushing — the race window closes
#    with a rejected fast-forward, never an overwrite. No force, no lease, no
#    caller-supplied refspec: exactly resulting_commit -> the resolved branch.
remote_head2="$(git ls-remote "$ssh_url" "refs/heads/$HEAD_REF" | awk 'NR==1{print $1}')"
cl_check_stale_head "$HEAD_SHA" "$remote_head2" || refuse "head moved during publication ($remote_head2)"

git -C "$TARGET_DIR" push "$ssh_url" "$commit:refs/heads/$HEAD_REF"
echo "published $commit to $REPO $HEAD_REF (fast-forward from $HEAD_SHA)"
