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

### Correction, second pass: there is no valid setting that fixes it

The revision above proposed reaching a classic subject with a blank body
(`MERGE_MESSAGE` + `BLANK`) through the REST API, since the settings page
offers only three combinations. **GitHub rejects that combination.** Tried
directly:

```
$ gh api -X PATCH repos/jwogrady/spark \
    -f merge_commit_title=MERGE_MESSAGE -f merge_commit_message=BLANK
{
  "message": "Validation Failed",
  "errors": [{
    "message": "Sorry, invalid setting combination. The following are valid
      combinations for the merge commit title and message: PR_TITLE and
      PR_BODY, PR_TITLE and BLANK, MERGE_MESSAGE and PR_TITLE.
      (invalid_merge_commit_setting_combo)",
    "code": "invalid"
  }],
  "status": "422"
}
```

So the three UI options are not a subset of what the API allows — they are
**exactly** what the API allows. There is no fourth state to reach.

That settles the question the two previous revisions kept getting wrong. Walk
all three permitted combinations against a conventional PR title:

| `merge_commit_title` | `merge_commit_message` | Merge commit contains | Duplicates? |
|---|---|---|---|
| `MERGE_MESSAGE` (current) | `PR_TITLE` | conventional line in the **body** | **Yes** |
| `PR_TITLE` | `BLANK` | conventional line in the **subject** | **Yes** |
| `PR_TITLE` | `PR_BODY` | conventional **subject** + a body that may carry footers | **Yes** |

Every one duplicates, because Release Please reads both a commit's subject and
its body. Verified against this repo's own history:

```
$ git log -1 --format='%s' 5d7d4b7
Merge pull request #403 from jwogrady/fix/393-hub-locator-grammar
$ git log -1 --format='%b' 5d7d4b7
fix: validate the whole hub locator scheme and authority (#393)
```

`5d7d4b7` carries a non-conventional *subject*, and Release Please still gave
it its own `0.18.0` changelog entry — from the body alone.

**The controlling variable is therefore not the setting. It is whether the PR
title is conventional-shaped.** No repository setting can help, because all
three permitted combinations put the PR title somewhere Release Please looks.

Nothing currently requires a conventional PR title: `ship/SKILL.md` does not
specify one, no workflow lints it, and the `commit-msg` hook governs commits,
not pull requests. The convention arose only because a PR is conventionally
titled from its lead commit's subject. That makes it changeable — but changing
it is a convention decision, not a bug fix, and it is recorded below as open
rather than decided here.

### Status: open, and not a setting change

The duplicate-detection check is what stands between a doubled entry and a
published release — it fails the advisory check and requires reconciliation
before a human approves the release PR, rather than letting the pattern repeat
silently. It did exactly that on the v0.18.0 release PR (#392), which shipped
with every entry doubled.

The options that remain are all conventions, not settings:

1. **Non-conventional PR titles.** Keep merge commits and the current setting;
   title PRs without a conventional prefix (`Harden hub locator validation
   (#393)`). The merge commit body stops parsing as a commit and the duplicate
   disappears. Costs nothing structurally; relies on discipline, since nothing
   enforces PR titles.
2. **Squash-merge.** One conventional commit per PR, no duplication at all.
   Rejected earlier for flattening the focused commit series — though note it
   is *lossless* for a single-commit branch, which is what most of the
   #403-#414 sweep consisted of. A split rule (squash single-commit branches,
   merge-commit multi-commit ones) would be a narrower version of this.
3. **Accept it.** The duplication overstates the change count; it does not
   misrepresent what shipped. The check keeps it visible at release time.

Whichever is chosen affects **future** merges only. A merge commit's message is
immutable once written, so nothing can retroactively clean a release whose
commits are already on the trunk.

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
case above, and no setting closes either one (see the second correction above).
Note that the discipline an earlier revision suggested here — writing the
branch's lead commit subject and the PR title to *match* — makes this strictly
worse, not better: matching texts produce an **exact** duplicate pair rather
than two differently-worded entries. Only a non-conventional PR title, or
squashing, removes the second entry.

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
