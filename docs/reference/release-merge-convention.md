# Reference — the merge convention that keeps release notes truthful

> Reference — information-oriented. Developer/operations doc for this
> repository; not shipped with the plugin. Owner: `jwogrady`. The shipped
> ownership model lives at
> `plugins/spark/docs/explanation/release-ownership.md`; this doc records the
> merge-commit mechanism behind issue #372 and the decision for *this* repo.

## The mechanism (confirmed against real history)

v0.16.0 and v0.16.1 each listed one logical change twice in the published
changelog: once for the branch commit, once for the merge commit that landed
it. Confirmed directly against the actual commits:

```
$ git log -1 --format='%s' 5a95763   # the merge commit for PR #367
Merge pull request #367 from jwogrady/fix/milestone-gate-state-case
$ git log -1 --format='%b' 5a95763
fix: normalize issue state case in the milestone gate
```

This repository's GitHub merge-button settings are `merge_commit_title:
MERGE_MESSAGE` (subject stays the generic "Merge pull request #N…") and
`merge_commit_message: PR_TITLE` (the **body** carries the PR's title
verbatim). When a PR's title is itself a conventional-commit subject — the
norm here, since PR titles are commit-msg-hook-enforced — the merge commit's
body reads as a second, independent conventional commit. Release Please
classifies both the branch commit and the merge commit as releasable,
producing two bullets for one change.

`.github/scripts/release-notes-runner.sh` builds its commit list with `git log
--no-merges`, so the existing completeness check never saw the merge commit at
all — from its view exactly one commit existed, satisfied by one of the two
duplicate bullets, leaving the second invisible. #372 closed that detection
gap in `.github/scripts/release-notes-check.sh` (a new "duplicate bullet"
failure mode, proven against these exact historical commits as fixtures). That
fixes **detection** — it makes the next release PR's advisory check fail loud
instead of silently shipping a doubled entry. It does not fix the **cause**.

## The convention chosen

Keep true merge commits (not squash-merge). Spark's own delivery model wants
a branch's focused commit series visible in trunk's `git log`, not flattened
into one squash commit — that's what step-by-step Conventional Commits
through `codify`/`validate` are *for*. Squashing would remove exactly the
history the branch was built to preserve.

The fix is therefore to stop the merge commit's own message from containing a
second conventional-shaped line: change this repository's **GitHub Settings →
General → Pull Requests → "Allow merge commits" → default commit message**
from **"Pull request title"** to **"Default message"** (blank/generic body).
That is a repository setting Spark's own guardrails do not let an agent change
unattended (`AGENTS.md`: "never change repository settings... applying policy
is the human's"), so it is recorded here as the pending human action rather
than applied.

**Status: pending.** Until the setting changes, the new duplicate-detection
check is what stands between a doubled entry and a published release — it
will fail the advisory check and require reconciliation before a human
approves the release PR, rather than letting the pattern repeat silently.

## Historical notes: not corrected

`CHANGELOG.md` and the published `v0.16.0`/`v0.16.1` GitHub Releases keep
their duplicate entries. Per `AGENTS.md` ("Behavior changes ride your
Conventional Commit types — Release Please builds `CHANGELOG.md` from them.
Never hand-edit the changelog") and ADR-0006/0009 (Release Please owns the
changelog; a human merging its PR is the release act), hand-editing an
already-published changelog or release body would create exactly the kind of
second, unreviewable source of release truth those decisions exist to
prevent. The duplication is cosmetic — it overstates the count of changes,
it does not misrepresent what shipped — so it is left as the historical
record, explained here rather than silently rewritten.

## Related docs

- [`plugins/spark/docs/explanation/release-ownership.md`](../../plugins/spark/docs/explanation/release-ownership.md) — the shipped ownership model this doc extends for one repo-operations fact.
- [`.github/scripts/release-notes-check.sh`](../../.github/scripts/release-notes-check.sh) — the detection mechanism (failure mode 4).
- GitHub issue #372 — the record of this investigation and decision.
