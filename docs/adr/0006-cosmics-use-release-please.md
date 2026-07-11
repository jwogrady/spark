# ADR: Generated Cosmics release via Release Please; `ship` defers to it

Date: 2026-07-08
Status: Accepted; vocabulary superseded by [ADR-0015](0015-generated-projects-without-the-cosmic-model.md) — "Cosmic" is retired from the public docs
Owner: jwogrady

## Context

The operator prefers **Release Please** for releases: automated changelog,
version bumps derived from commit types, published GitHub Releases, and annotated
tags. Spark's `ship` skill already performs a commit-type → SemVer bump mapping by
hand. Both cover the act of releasing, so the two overlap — exactly the kind of
"which do I use?" ambiguity the operator wants gone.

## Decision

- **Generated Cosmics release via Release Please.** `bootstrap` scaffolds its
  configuration and the matching Actions wiring.
- **`ship` defers to it.** `ship` owns the conventional commit and the pull
  request; Release Please owns versioning, changelog, tags, and the GitHub
  Release.

Why: Release Please is the mature, native-adjacent tool that does automatically
and continuously what `ship`'s mapping does by hand. Per the operator's own
principle — lean on great tools, don't reinvent — `ship` should stop competing
and hand off. Less bespoke logic to maintain; releases become mechanical.

## Alternatives Considered

- **Keep `ship`'s hand-rolled bump mapping as the release mechanism.** Rejected:
  duplicates a maintained tool, drifts from it, and is more surface to own.
- **Run both.** Rejected: two release mechanisms is the overlap that erodes trust
  in which one is authoritative.

## Consequences

- `ship`'s scope narrows to commit + PR; its release-bump documentation must be
  corrected to point at Release Please.
- Cosmics need a Release Please config template plus the GitHub Actions wiring
  from ADR-0005.
- Spark's *own* repository release flow is a separate question, not settled here.

## Open Questions

- Whether Spark's own repository adopts Release Please or keeps `ship`'s mapping
  for its releases. Owner: jwogrady.

## Related Docs

- [0005-cosmics-ship-ci-spark-stays-ci-free.md](0005-cosmics-ship-ci-spark-stays-ci-free.md) — the CI wiring Release Please runs on
- [../reference/skills.md](../../plugins/spark/docs/reference/skills.md) — where `ship` sits
