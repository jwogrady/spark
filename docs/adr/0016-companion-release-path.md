# ADR: Companions release through Release Please multi-package mode

Date: 2026-07-11
Status: Accepted; answers ADR-0014's open question. Amended 2026-07-11:
root-only GitHub Releases (see addendum)
Owner: jwogrady

## Context

ADR-0014 split the marketplace into a focused core and three companions
(`spark-audit`, `spark-connect`, `spark-docs`), each versioning independently
from `0.1.0` — but deferred the release automation: Release Please versioned
only the core, and no companion had a changelog, a tag, or a mechanical bump
path. A companion change merged to master shipped silently: marketplace
consumers received it on `/plugin update`, while the companion's
`plugin.json` version, the tag history, and the release record all stood
still.

The repo already runs Release Please in manifest mode
(`release-please-config.json` + `.release-please-manifest.json`) with a
single root package. Release Please attributes each conventional commit to
packages by the paths it touches, so nested packages are an extension of the
existing mechanism, not a second one.

One structural fact bounds the options: a Claude Code marketplace serves the
repository's current state. There is no per-tag plugin fetch, so the catalog
cannot pin companion versions — `plugin.json` is the version of record a
consumer sees, and tags/changelogs are the durable release history behind it.

## Decision

- **Extend the existing Release Please manifest to four packages.** The root
  `.` package is unchanged: the core + repo train, tag `vX.Y.Z` (no
  component), root `CHANGELOG.md`, bumping
  `plugins/spark/.claude-plugin/plugin.json`.
- **Each companion becomes a nested package** at `plugins/<name>/` with a
  component tag (`spark-audit-vX.Y.Z`), its own `CHANGELOG.md` inside the
  plugin directory (so the changelog ships to consumers with the plugin),
  and an extra-files updater bumping its own `plugin.json`.
- **One release PR, four trains.** `separate-pull-requests` stays at its
  default (false): Release Please maintains a single combined release PR;
  merging it cuts a tag and a GitHub Release per pending package. The
  operator's one release decision covers the marketplace.
- **The catalog keeps floating.** `marketplace.json` continues to reference
  plugin directories; versions live in each `plugin.json`, maintained by
  Release Please — never hand-bumped (extends the ADR-0009 rule to
  companions).

Why this shape: it reuses the mechanism ADR-0009 already adopted instead of
adding a second one, keeps the human decision count at one merge per release
wave, and puts each companion's changelog where its consumers actually look —
inside the installed plugin.

## Alternatives Considered

- **One version for the whole marketplace** (bump all four `plugin.json`
  files from the root train). Rejected: it re-couples what ADR-0014
  deliberately decoupled — a core-only fix would fake-release three untouched
  companions, and their changelogs would be empty noise.
- **Separate repositories with their own Release Please.** Rejected by
  ADR-0014 already (three repos to bootstrap, history lost on the move);
  nothing about releasing changes that calculus.
- **Manual tags per companion.** Rejected for the reason ADR-0009 retired the
  manual core flow: hand-run steps drift, and the commit-type ladder already
  encodes the bump size mechanically.

## Consequences

- Commit path discipline becomes version-load-bearing: a commit touching a
  companion's directory drives that companion's next version, so a sloppy
  multi-plugin commit mis-attributes a bump. "One concern per PR" plus
  squash-merge already enforce the needed hygiene.
- No `spark-<name>-v0.1.0` tags exist, so each companion's first release PR
  scans its path history back to the reshape (`plugins/<name>/` paths were
  born there) and proposes `0.2.0` carrying those commits — the honest
  record: `0.1.0` was never released.
- The combined release PR can retitle/regrow as commits land; the release
  remains the operator's explicit merge (ADR-0009, unchanged).
- Doctor is untouched: the catalog still references directories, which is
  what doctor validates.

## Addendum (2026-07-11): root-only GitHub Releases

GitHub Releases are repo-wide, not package-aware: "Latest" is simply the most
recently created release, so a companion release (`spark-docs-v0.2.0`)
displaced the core `v0.8.0` as the repo's Latest — misleading for users, since
the core plugin is the product. Of the clean options — always re-mark the root
release as latest, stop companion Release pages, or split companions into
their own repositories — we chose **root-only GitHub Releases**:

- Companions keep independent versions, per-plugin changelogs, and
  `spark-<name>-vX.Y.Z` tags. They lose only the GitHub Release page.
- `skip-github-release: true` in the config suppresses the companion Release
  pages, but per its contract it also stops Release Please's own tagging —
  so the release workflow gains a `tag companions` step that creates any
  missing companion tag from `.release-please-manifest.json`, idempotently.
  Those tags are what Release Please anchors the next version range on.
- The rest of the multi-package decision above is unchanged.

## Addendum (2026-07-21): companions publish as prereleases, not skip-github-release

The 2026-07-11 addendum used `skip-github-release: true` to keep companions off
"Latest". But that flag also stops Release Please's own tagging, which forced a
post-hoc `tag companions` step in the workflow — and that step created the
companion tag *after* Release Please had already computed the next release PR in
the same run. On a release-merge run the just-shipped companion tag did not yet
exist, so Release Please mis-anchored the companion's version range and
re-proposed already-shipped work as an orphan release PR (#248, symptom #218). A
later run reported "no commits" but never closed the orphan.

Fix: companions now carry `prerelease: true` instead of `skip-github-release`.
Release Please creates each companion's tag **and** a GitHub Release marked
prerelease, atomically, at the moment it computes the next range — so the tag
always exists when anchoring, and the race is gone. GitHub never marks a
prerelease as "Latest", so the invariant this addendum's predecessor protected —
**Latest always names the core** — still holds; it even holds on a
companion-only release wave, where no new core Release is created and Latest
stays on the last core release. The custom `tag companions` workflow step and
its checkout are removed: Release Please owns companion tagging again.

The trade the predecessor made (companions lose their Release page) is partly
reversed: companion releases now appear as prereleases. That is an acceptable —
arguably better — outcome: the companion release history becomes visible without
ever competing for Latest.

## Open Questions

- None.

## Related Docs

- [0014-core-plus-companion-plugins.md](0014-core-plus-companion-plugins.md) — the boundary whose open question this answers
- [0009-spark-release-mechanism.md](0009-spark-release-mechanism.md) — the release mechanism this extends
- `release-please-config.json` / `.release-please-manifest.json` — the configuration of record
