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

**This rule is specific to merge commits, which is how this repository lands
PRs.** It inverts under squash-merging: `squash_merge_commit_title:
COMMIT_OR_PR_TITLE` makes the PR title the *trunk subject* on any multi-commit
branch, so a plain title there means Release Please finds nothing releasable
and the change is silently omitted from the changelog with no version bump —
a worse failure than duplication. The shipped `ship` skill states the
conditional form for both strategies; see
[`skills/ship/references/release-please.md`](../../plugins/spark/skills/ship/references/release-please.md).

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
`9ddfeb4` that actually made the change. One change, two bullets. (The `v0.18.0`
*release* was withdrawn on 2026-08-26; both commits and the `0.18.0` changelog
section remain on `master`, so this example is still inspectable there.)

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
  reports a duplicate bullet before a human approves the release PR. Since
  #487 it reports it as what it is: exit `3`, projecting to a `success` status
  whose description discloses the accepted count. A duplicate is cosmetic and
  does not block, so it must not render as the same red `failure` an omission
  does — a red the operator is told to ship past teaches them to ship past the
  next one.

A PR titled by hand in the GitHub web UI passes neither door until release
time. That is a known gap, not an oversight: the release check is the backstop
and it fails loud.

`spark doctor` cannot help here — it has no pull-request context — and
`.github/workflows/validate.yml` is deliberately a thin wrapper around
`doctor` and `tests/run.sh` ("Do not add check logic here"), so a PR-title
lint would need its own workflow. That was judged disproportionate while the
release check already catches it.

## What the historical instances taught

The duplication was observed across the `v0.16`–`v0.18` publications. The
`v0.17` and `v0.18` releases were **withdrawn** on 2026-08-26, so their Release
bodies can no longer be inspected; the commits and `CHANGELOG.md` sections remain
on `master`, and `docs/releases/v0.19.md` records the withdrawal. What survives is
below, all of it encoded in the rule above.

**On the shape of the bug:**

- A **one-commit branch** merged with a merge commit produces an *exact*
  duplicate pair — the most visible form.
- Making the lead commit subject **match** the PR title makes it strictly
  worse, not better. Matching texts produce an exact duplicate pair instead of
  two differently-worded entries; only a **plain PR title** removes the second
  bullet. An earlier revision of this document recommended matching them, which
  was wrong.
- The differently-worded variant is the **same bug**, and `notes_normalize`'s
  exact-match comparison correctly does not flag it: collapsing differently-worded
  entries would risk false positives on genuinely distinct changes. Those reach
  the changelog as extra, not-technically-duplicate bullets.

**On what ships anyway, and what does not:**

- **A duplicate bullet ships.** It is cosmetic — it overstates a count, it does
  not misrepresent what shipped. A merge commit's message is immutable once
  written, and hand-editing a published changelog or Release body would create the
  second, unreviewable source of release truth that `AGENTS.md` and ADR-0006/0009
  exist to prevent.
- **An omission does not ship.** It understates what shipped, and the Release
  page is what most readers see. The one sanctioned remedy is to sync the Release
  body *verbatim* from the canonical `CHANGELOG.md` section — copying, never
  composing — which reduces divergence between two artifacts instead of creating
  a third opinion.

**On detecting it — the stale release-PR trap:**

The release PR's **body** becomes the Release body, and it can be stale relative
to the PR's **diff**: Release Please regenerates `CHANGELOG.md` when a later fix
merges without necessarily rewriting the body. So the `release-notes` check must
be given the **PR body** as `--notes` — running it against the diff produces a
**false pass** that hides the staleness, which is how an `omission` finding was
once wrongly overridden. Rapid merges can also race two release PRs into
existence, leaving the stale one at risk of being merged. Detection before
merging, and how to read the check's findings, are in the ship reference below.

## A second failure mode: the commit dated before the tag it merges after

Duplication is not the only way generated notes go wrong. **A commit whose date
precedes the previous release tag is silently dropped from the next release's
notes, even though it is genuinely unreleased.**

Observed at the `v0.20.0` cut. Commit `2a88518`
(*"docs: reserve blocked-by for true prerequisites"*, PR #464) was committed
`2026-08-26T16:19:45-05:00` on a branch opened before the `v0.19.0` cut, and
merged to `master` **after** that tag existed. It is not an ancestor of
`v0.19.0`, so it shipped for the first time in `v0.20.0` — and Release Please
omitted it.

The mechanism is the walk, not the parse. Release Please enumerates commits in
reverse chronological order and stops when it reaches the previous release's
SHA. A commit dated *earlier* than that SHA sits beyond the stop point, so the
walk never reaches it. Its subject is perfectly conventional; it is simply never
read.

The correlation at that cut was exact: of the 23 non-merge commits in
`v0.19.0..master`, `2a88518` was the only one dated before the tag commit
(`2026-08-26T18:58:43-05:00`), and it was the only one missing from the notes.

**Regenerating does not fix it.** Closing and recreating the release pull
request reruns the same date-ordered walk against the same history and reaches
the same stop point, so the omission reproduces. This is the one `omission`
finding that a rebuild cannot clear.

**What does fix it** is making the change visible inside the walk window — a
commit dated after the previous tag that carries the same conventional subject.
The original commit stays exactly where it is; nothing is rewritten,
force-pushed, or re-dated. The generated notes then state what shipped, which
is the only property that matters.

**That carrier must touch a file, and it must be path-scoped.** An *empty*
carrier (`git commit --allow-empty`) is worse than the problem it solves.
Release Please's manifest mode runs with `includeEmpty: true`: a commit with no
files is assigned to **every configured package path**, because path filtering
has nothing to filter on. At the `v0.20.0` cut an empty carrier broadcast one
`docs:` entry into all three companions and falsely proposed `spark-audit`
`0.2.3`, `spark-connect` `0.2.3`, and `spark-docs` `0.3.2` — three releases for
components that had not changed, each carrying a changelog line about work they
do not contain. Scope the carrier to a file the package owns and it cannot
reach the others.

**Retracting a merged commit's changelog entry** is possible without touching
history. Release Please reads a `BEGIN_COMMIT_OVERRIDE` / `END_COMMIT_OVERRIDE`
block in the *pull request body* and parses that instead of the merged commit
message. The association is only unambiguous when the pull request contains
exactly one commit. Putting a non-conventional line inside the block makes the
parser yield no entry at all, which retracts the commit from every package's
notes — the escape hatch for a carrier that went wrong.

**Prevention:** a long-lived branch that spans a release cut carries this risk.
Bringing the trunk into the branch does not help — that adds a *merge* commit
whose date is current while the branch's own commits keep their original dates.
Where a branch is expected to outlive a cut, land it before the cut or expect to
carry its subject forward deliberately.

The detection is unchanged and worked: `release-notes-check.sh` reported it as
an `omission`, which **blocks**, and is exactly the class that must never be
waved through. A release that needs a human to override its own gate has no
gate.

## Related docs

- [`plugins/spark/docs/explanation/release-ownership.md`](../../plugins/spark/docs/explanation/release-ownership.md) — the shipped ownership model this doc extends for one repo-operations fact.
- [`.github/scripts/release-notes-check.sh`](../../.github/scripts/release-notes-check.sh) — the detection mechanism (failure mode 4).
- [`plugins/spark/skills/ship/SKILL.md`](../../plugins/spark/skills/ship/SKILL.md) — step 5 states the rule where PRs are opened.
- GitHub issue #372 — the record of this investigation and decision.
