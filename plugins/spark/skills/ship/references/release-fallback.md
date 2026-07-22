# Release fallback — repos without Release Please

> Reference for the `ship` skill. Applies ONLY to repos that do not use Release
> Please, and ONLY with explicit user go-ahead — never cut a tag or Release
> unprompted. Where Release Please is configured, ship never touches versions,
> changelog, tags, or Releases (ADR-0006/0009).

Derive the bump from the commit types in the range per the version ladder in
[`../../../docs/explanation/sdlc-doctrine.md`](../../../docs/explanation/sdlc-doctrine.md)
(`feat:` → minor; `fix:`/`docs:`/`chore:`/`refactor:`/`test:` → patch; `!` or
`BREAKING CHANGE:` → major; take the highest), then in order: roll
`[Unreleased]` into a dated `vX.Y.Z` section, bump the version file, annotated
tag, `gh release create` with the CHANGELOG section as notes, fresh
`[Unreleased]`.

Non-version-bumping ships still update `[Unreleased]` when behavior changed.

**A changelog records what changed in the product, not how it was built.** Every
`[Unreleased]` entry describes a user-facing change — a feature, fix, or
behavior. It is not a process journal: never log phase transitions ("Completed
Phase 1 — Plan"), grill reviews, QC passes, planning bookkeeping, or `/spark:`
stage activity. If an entry only makes sense to someone running the Spark
lifecycle, it does not belong in the changelog.
