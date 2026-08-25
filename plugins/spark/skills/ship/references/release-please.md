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

## Ownership

The full ownership boundary — what Release Please owns, what `ship` owns, and
why the human merge is the release act — is stated once in
[release-ownership.md](../../../docs/explanation/release-ownership.md).

The consequence to hold on to while running the motion above: hand-editing
`CHANGELOG.md` or a version file in a Release Please repo violates that
boundary, which is why doctor flags a hand-curated `[Unreleased]` section.
