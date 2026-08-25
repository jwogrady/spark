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
second conventional-shaped line. That means a **classic subject with a blank
body**, and reaching it is less obvious than it looks.

### Correction: the UI cannot express the fix

An earlier revision of this doc said to change **GitHub Settings → General →
Pull Requests → "Allow merge commits" → default commit message** from
**"Pull request title"** to **"Default message"**. That is backwards. It was
repeated verbatim while releasing v0.18.0 and only caught by reading the live
settings, which are, and have been:

```
$ gh api repos/jwogrady/spark --jq '{merge_commit_title,merge_commit_message}'
{"merge_commit_title":"MERGE_MESSAGE","merge_commit_message":"PR_TITLE"}
```

That pair **is** "Default message" — the repository was already on the option
this doc recommended switching to, because GitHub's classic merge commit has
always been a `Merge pull request #N from branch` subject with the PR title as
its body. The recommended change was therefore a no-op, and the body carrying
a conventional subject is exactly the cause.

The dropdown offers three options and **none of them fix this**:

| UI option | Subject (`merge_commit_title`) | Body (`merge_commit_message`) | Duplicates? |
|---|---|---|---|
| **Default message** | `MERGE_MESSAGE` — `Merge pull request #N…` | `PR_TITLE` | **Yes** — the body is a second conventional commit |
| Pull request title | `PR_TITLE` | `BLANK` | **Yes** — now the *subject* is the conventional commit |
| Pull request title and description | `PR_TITLE` | `PR_BODY` | **Yes** — subject, plus a body that may carry footers |

The state that actually fixes it — classic subject, blank body — is not one of
the three, so it cannot be set from the settings page. It has to go through the
REST API:

```
gh api -X PATCH repos/jwogrady/spark \
  -f merge_commit_title=MERGE_MESSAGE \
  -f merge_commit_message=BLANK
```

The resulting merge commit is `Merge pull request #N from branch` with nothing
after it. Release Please does not classify it as releasable, so each logical
change appears exactly once.

This is still a repository setting, which Spark's own guardrails do not let an
agent change unattended (`AGENTS.md`: "never change repository settings…
applying policy is the human's"), so it stays recorded here as the pending
human action rather than applied.

**Status: pending.** Until the setting changes, the duplicate-detection check
is what stands between a doubled entry and a published release — it will fail
the advisory check and require reconciliation before a human approves the
release PR, rather than letting the pattern repeat silently. It did exactly
that on the v0.18.0 release PR (#392), which shipped with every entry doubled;
see the note below.

Changing the setting only affects **future** merges. A merge commit's message
is immutable once written, so no setting change can retroactively clean a
release whose commits are already on the trunk.

## Live confirmation against the actual v0.17.0 release PR

The mechanism and the fix were both confirmed against production, not just
fixtures. PR #382 (`chore: release spark v0.17.0`) currently carries one real
exact duplicate — "reconcile the v0.17 release record with milestone
reality," once for #380's branch commit (`4656c7e`) and once for its merge
commit (`4fc7bef`) — and the `release-notes` advisory check on that PR is
**failing right now** because of it, exactly as #372's fix is meant to do:

```
$ gh pr checks 382
release-notes  fail  0  core: fail; spark-audit: not-assessed; ...
```

The same PR also shows a **broader, related pattern #372 was not scoped to
fix**: three feature PRs (#375, #376, #377) each render as two Features
entries — one from the branch's lead commit subject, one from the merge
commit's body (the PR title) — because the two texts were worded
*differently*, not identically. `notes_normalize`'s exact-match comparison
correctly does not flag these as duplicates (collapsing differently-worded
entries would risk false positives on genuinely distinct changes that happen
to read similarly), so this pattern reaches the published changelog as extra,
not-technically-duplicate entries. It has the same root cause as the exact
case above and the same pending fix; closing it further would mean either the
API-only setting change (see the correction above — the settings-page dropdown
cannot express it) or discipline going forward: write the branch's lead commit
subject and the PR title to match, so the merge commit's body restates rather
than adds.

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

The same decision extends forward to v0.17.0 itself: its release PR's
duplicate and near-duplicate entries (above) exist because the commits
producing them are already merged with the old setting in effect — a repo
setting change only prevents the pattern in future merges, it cannot
retroactively rewrite an immutable commit's own message. Hand-editing PR
#382's generated body would (a) violate the same never-hand-edit-the-changelog
rule and (b) get silently overwritten the next time a push to `master`
regenerates it, which further work on this milestone guarantees will happen
at least once more. The `release-notes` advisory check surfaces the known
duplicate to whoever merges the release PR; that visibility, not a clean
render, is what the check is for.

v0.18.0 is the largest instance so far, and is likewise left uncorrected. The
#403-#414 sweep put ten one-commit branches on the trunk through true merge
commits, so every entry in the `0.18.0` section appears exactly twice — once
for the branch commit, once for its merge commit's body. The `release-notes`
check failed on PR #392 as designed, the duplication was surfaced to the human
merging it, and the release shipped on that informed decision. The same two
reasons as above apply: the generated section is Release Please's to write, and
the commits producing it are immutable.

The lesson worth carrying: a one-commit branch merged with a merge commit
produces an *exact* duplicate pair, which is the most visible form of this bug.
Until the API-level setting change lands, expect the check to fail on any
release built that way.

## Related docs

- [`plugins/spark/docs/explanation/release-ownership.md`](../../plugins/spark/docs/explanation/release-ownership.md) — the shipped ownership model this doc extends for one repo-operations fact.
- [`.github/scripts/release-notes-check.sh`](../../.github/scripts/release-notes-check.sh) — the detection mechanism (failure mode 4).
- GitHub issue #372 — the record of this investigation and decision.
