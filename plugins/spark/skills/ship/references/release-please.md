# Release Please — the milestone-completion motion

> Reference for the `ship` skill, for repos where Release Please is configured
> (a `release-please-config.json` or release-please workflow at the root).
> Ship never bumps a version, rolls the changelog, tags, or creates a Release —
> this reference is what to know when a **milestone completes** and the release
> motion starts. Doctrine: the milestone is the version authority; Release
> Please is the release mechanic; the human merge of the release PR is the
> release act (sdlc-doctrine.md, ADR-0006/0009).

## When a milestone completes

1. **Confirm the milestone is actually done** — zero open issues, validation
   green on trunk (the milestone gate posts exactly this readiness signal when
   configured). A docs-truth pass (`spark-audit` assess) belongs here: a
   release publishes the repo's claims. This is also a natural provenance
   boundary (ADR-0028): would the milestone's outcome still be true and useful
   if this implementation disappeared? A "no" needs no ceremony; a "yes" hands
   the evidence to [`knowledge`](../../knowledge/SKILL.md) — once per
   milestone, not once per issue already asked and answered.
2. **Mint the milestone's version deliberately.** Day-to-day merges bump the
   patch line (`always-bump-patch`); the milestone boundary is declared, not
   computed: land the final change (or annotate the release PR's commit) with
   a `Release-As: X.Y.0` footer carrying the version the milestone named.
   Commit types never decide that a milestone happened.
3. **Verify the release PR is fresh** (trap below), then hand it to the human.
   Merging the Release Please PR *is* the release — never merge it, tag, or
   `gh release create` yourself.

## First release of a fresh repository

With **zero existing releases**, release-please ignores the manifest baseline
and bump strategy entirely and uses `initialReleaseVersion()` — which is
**hardcoded to `1.0.0`** unless `initial-version` is set. The seeded template
sets `initial-version: 0.0.1`, so a new project's first release cannot
accidentally declare itself stable. Verify the guard survives in any
hand-edited config before the first release PR is approved (the zd-dns field
test hit this exact default and had to retire an accidental release).

## The stale release-PR trap

Release Please regenerates its PR **only on a trunk push it considers
relevant**. A commit that lands after the PR was cut and changes a generated
file's *base* (say, `CHANGELOG.md`'s surroundings) without changing the
computed notes can leave the open release PR **stale but mergeable** — it
would ship a malformed changelog. The field-proven fix: **close the release
PR** and let the workflow recreate it fresh on the next run; never hand-edit
the PR's branch. If the recreated PR proposes a wrong version, the input is
wrong (missing `Release-As`, a mis-typed commit) — fix the input, not the
artifact.

### Detect it before merging, not after

A release PR carries the notes in **two** places, and they can disagree: the
PR **body** (which becomes the GitHub Release body) and the PR **diff** (the
`CHANGELOG.md` change). Release Please regenerates the changelog on every
relevant push but can leave the body behind. Compare them:

```bash
body=$(gh pr view <N> --json body --jq .body | grep -c '^\*')
diff=$(gh pr diff <N> | grep -c '^+\*')
[ "$body" = "$diff" ] || echo "STALE — close the PR and let it recreate"
```

Unequal counts mean the body is stale. **Close the PR**; do not merge it and
do not hand-edit it. Merging a stale one publishes a GitHub Release whose body
is missing entries while `CHANGELOG.md` has them — the artifact most readers
see is then the wrong one.

### Read the release-notes check by its finding, not its colour

The advisory `release-notes` status distinguishes two findings, and they carry
opposite weight:

| Finding | Meaning | Action |
|---|---|---|
| **omission** | a changelog-visible commit's subject is absent from the notes | **Blocks.** The notes misrepresent what shipped. Close and recreate. |
| **duplicate bullet** | one logical change rendered twice | Known and accepted here (see `docs/reference/release-merge-convention.md`). Ship it. |

The word "notes" in that check's message means the **PR body**, not the
changelog — `release-notes-check.sh --notes` expects the body. Feeding it the
diff instead produces a false pass, because the diff is exactly the half that
was *not* stale. A failing status is never disproved by re-running the check
with different inputs; read what the finding names first.

## The PR title depends on how PRs land

Release Please reads a commit's subject **and** its body, so whichever of
those the PR title ends up in, it is parsed as a commit. Which one that is
depends on the repo's merge strategy — and the right title is the opposite in
each case.

**Merge commits** (`merge_commit_message: PR_TITLE`, GitHub's default) put the
PR title in the merge commit's **body**. The branch commit already carries the
real conventional message, so a conventional PR title lands the same change in
the notes **twice**:

```
Merge pull request #N from jwogrady/fix/hub-locator        ← subject

fix: validate the whole hub locator scheme and authority    ← body, counted again
```

→ **Title plainly** (`Harden hub locator validation`). The body then
parses as nothing and the change appears once.

**Squash merges** collapse the branch into one commit, and
`squash_merge_commit_title: COMMIT_OR_PR_TITLE` (GitHub's default) uses the
**PR title as the trunk subject** whenever the branch had more than one
commit. That subject is now the *only* conventional message on the trunk, so a
plain title means Release Please classifies nothing releasable: the change is
**silently omitted from the changelog and does not bump the version** — a
worse failure than duplication, because nothing looks wrong.

→ **Title conventionally** (`fix: harden hub locator validation`).

Neither case is a repository setting you can fix; both defaults are valid and
the API permits no combination that avoids the problem (see this repo's
`docs/reference/release-merge-convention.md` for the refusal). Check which
strategy the repo uses before titling — `gh api repos/{owner}/{repo} --jq
'{allow_merge_commit,allow_squash_merge}'` — and when both are allowed, title
for the one the project actually uses.

## Ownership

The full ownership boundary — what Release Please owns, what `ship` owns, and
why the human merge is the release act — is stated once in
[release-ownership.md](../../../docs/explanation/release-ownership.md).

The consequence to hold on to while running the motion above: hand-editing
`CHANGELOG.md` or a version file in a Release Please repo violates that
boundary, which is why doctor flags a hand-curated `[Unreleased]` section.
