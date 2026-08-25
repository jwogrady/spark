# Reference — the merge convention that keeps release notes truthful

> Reference — information-oriented. Developer/operations doc for this
> repository; not shipped with the plugin. Owner: `jwogrady`. The shipped
> ownership model lives at
> `plugins/spark/docs/explanation/release-ownership.md`; this doc records the
> merge-commit mechanism behind issue #372 and the convention chosen for
> *this* repo.

## The rule

**Title a pull request plainly. Never as a conventional commit.**

```
branch commits    fix: validate the whole hub locator scheme and authority
PR title          Harden hub locator validation (#393)     ← plain, no type prefix
```

A conventional-shaped PR title puts the same change in the release notes
twice. A plain one does not. Everything below is why, and why nothing else
works.

## The mechanism

Release Please reads a commit's **subject and its body**. This repository's
merge-button settings are `merge_commit_title: MERGE_MESSAGE` (generic subject)
and `merge_commit_message: PR_TITLE` (the body is the PR's title verbatim), so
a merge commit looks like this:

```
$ git log -1 --format='%s' 5d7d4b7
Merge pull request #403 from jwogrady/fix/393-hub-locator-grammar
$ git log -1 --format='%b' 5d7d4b7
fix: validate the whole hub locator scheme and authority (#393)
```

The subject is not conventional, but the body is — so Release Please gave
`5d7d4b7` its own `0.18.0` changelog entry, alongside the branch commit
`9ddfeb4` that actually made the change. One change, two bullets.

`.github/scripts/release-notes-runner.sh` builds its commit list with `git log
--no-merges`, so the completeness check never saw the merge commit: from its
view exactly one commit existed, satisfied by one of the two bullets, leaving
the second invisible. #372 closed that detection gap in
`.github/scripts/release-notes-check.sh` (a "duplicate bullet" failure mode,
proven against historical commits as fixtures). That fixed **detection**, not
the cause.

## Why no repository setting fixes it

Two earlier revisions of this doc proposed setting changes. Both were wrong,
in opposite directions, and the second printed a command that cannot run. The
question is settled by asking GitHub directly:

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

The three options on the settings page are not a subset of what the API
permits — they are **exactly** what it permits. There is no fourth state, and
a classic subject with a blank body is not reachable.

Walk all three against a conventional PR title:

| `merge_commit_title` | `merge_commit_message` | Merge commit carries the title in | Duplicates? |
|---|---|---|---|
| `MERGE_MESSAGE` (current) | `PR_TITLE` | the **body** | **Yes** |
| `PR_TITLE` | `BLANK` | the **subject** | **Yes** |
| `PR_TITLE` | `PR_BODY` | the **subject**, plus a body that may carry footers | **Yes** |

Every combination duplicates, because every one puts the PR title somewhere
Release Please looks. **The controlling variable is the PR title, not the
setting.**

## Why not squash-merge

Keep true merge commits. Spark's delivery model wants a branch's focused
commit series visible in trunk's `git log`, not flattened into one squash
commit — that series is what step-by-step Conventional Commits through
`codify`/`validate` are *for*. Squashing would remove exactly the history the
branch was built to preserve.

Squashing would also fix the duplication, and it is worth being honest that it
is *lossless for a single-commit branch* — which is what most of the #403-#414
sweep consisted of. A split rule (squash one-commit branches, merge-commit the
rest) was considered and rejected as a decision at every merge, in exchange
for something a plain PR title solves with no decision at all.

## How the rule is held

Nothing enforces a PR title mechanically, and this doc does not pretend
otherwise. Two doors cover it:

- **Prevention, where PRs are created.** `skills/ship/SKILL.md` step 5
  instructs a plain title, with the reason inline. Spark's own flow opens PRs
  through `ship`, so the common path is covered.
- **Detection, at release time.** `.github/scripts/release-notes-check.sh`
  fails the `release-notes` advisory check on a duplicate bullet, before a
  human approves the release PR.

A PR titled by hand in the GitHub web UI passes neither door until release
time. That is a known gap, not an oversight: the release check is the backstop
and it fails loud.

`spark doctor` cannot help here — it has no pull-request context — and
`.github/workflows/validate.yml` is deliberately a thin wrapper around
`doctor` and `tests/run.sh` ("Do not add check logic here"), so a PR-title
lint would need its own workflow. That was judged disproportionate while the
release check already catches it.

## Historical notes: not corrected

`CHANGELOG.md` and the published `v0.16.0`, `v0.16.1`, `v0.17.0` and `v0.18.0`
Releases keep their duplicate entries. Per `AGENTS.md` ("Release Please builds
`CHANGELOG.md` from them. Never hand-edit the changelog") and ADR-0006/0009
(Release Please owns the changelog; a human merging its PR is the release
act), hand-editing an already-published changelog or release body would create
exactly the kind of second, unreviewable source of release truth those
decisions exist to prevent.

A merge commit's message is also immutable once written, so no convention
change can retroactively clean a release whose commits are already on the
trunk. The duplication is cosmetic — it overstates the count of changes, it
does not misrepresent what shipped — so it stays as the historical record,
explained here rather than silently rewritten.

**v0.18.0 is the largest instance.** The #403-#414 sweep put ten one-commit
branches on the trunk through merge commits, each PR titled from its lead
commit's subject, so every entry in the `0.18.0` section appears exactly
twice. The `release-notes` check failed on PR #392 as designed, the
duplication was surfaced to the human merging it, and the release shipped on
that informed decision.

Two lessons from it, both now encoded in the rule above:

- A **one-commit branch** merged with a merge commit produces an *exact*
  duplicate pair — the most visible form of this bug.
- Writing the lead commit subject and the PR title to **match** makes it
  strictly worse, not better. An earlier revision of this doc suggested
  exactly that. Matching texts produce an exact duplicate pair instead of two
  differently-worded entries; only a plain PR title removes the second bullet.

For the record, the differently-worded variant is the same bug: on the
v0.17.0 release PR, three feature PRs (#375, #376, #377) each rendered as two
Features entries — one from the branch's lead commit subject, one from the
merge commit's body — because the two texts were worded differently.
`notes_normalize`'s exact-match comparison correctly does not flag those as
duplicates (collapsing differently-worded entries would risk false positives
on genuinely distinct changes that happen to read similarly), so they reach
the changelog as extra, not-technically-duplicate bullets.

## Related docs

- [`plugins/spark/docs/explanation/release-ownership.md`](../../plugins/spark/docs/explanation/release-ownership.md) — the shipped ownership model this doc extends for one repo-operations fact.
- [`.github/scripts/release-notes-check.sh`](../../.github/scripts/release-notes-check.sh) — the detection mechanism (failure mode 4).
- [`plugins/spark/skills/ship/SKILL.md`](../../plugins/spark/skills/ship/SKILL.md) — step 5 states the rule where PRs are opened.
- GitHub issue #372 — the record of this investigation and decision.
