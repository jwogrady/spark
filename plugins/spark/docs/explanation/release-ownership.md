# Release ownership

> Explanation — understanding-oriented.

Spark's own repo draws one boundary between two tools: `ship` and Release
Please. This doc is that boundary's canonical record — not a proposal. A
generated project inherits the same model as its default
(`reference/engineering-preferences.md`'s "Releases" section).

## The one ownership model

**Ship owns the commit and the PR. Release Please owns the release** —
versioning, changelog, the tag, and the GitHub Release.

| Release Please owns | Spark (`ship`) owns |
|---|---|
| Deriving the version bump from conventional-commit types | The conventional commit — type, subject, body |
| Rolling `CHANGELOG.md` entries into a dated version section | Curating `[Unreleased]` entries as behavior ships |
| Cutting the annotated tag | Opening the focused PR |
| Creating the GitHub Release | Everything that ends at "PR is open" |

Already decided, verbatim, in [`skills/ship/SKILL.md`](../../skills/ship/SKILL.md)'s
"Releases: defer to Release Please" section and the ADRs below; this doc
exists so the same wording holds everywhere else it's mentioned.

The rule is conditional: it applies wherever a `release-please-config.json`
(or a `release-please` workflow) exists. A repo without one keeps `ship`'s
manual fallback — bump, roll the changelog, tag, and release, with explicit
human go-ahead. This repo has the config, so the fallback never fires here.

**The human merge is the release act.** Release Please keeps a standing
release PR up to date from conventional commits on `master`; merging it is
always a human decision, and that single merge is what produces the bump,
the changelog entry, the tag, and the GitHub Release together.

## How the model plays out in this repo

Manifest mode across four packages (`release-please-config.json`,
`.release-please-manifest.json`):

- **Root (`.`)** — the core plugin and repo train. Tag `vX.Y.Z`, no
  component in the tag, changelog at `CHANGELOG.md`, `extra-files` bump of
  `plugins/spark/.claude-plugin/plugin.json`. The only package that gets a
  GitHub Release.
- **Three companions** (`plugins/spark-audit`, `plugins/spark-connect`,
  `plugins/spark-docs`) — each an independently versioned nested package: a
  component tag (`spark-<name>-vX.Y.Z`), its own `CHANGELOG.md` inside the
  plugin directory, its own `plugin.json` bump, and `skip-github-release:
  true`.
- **One combined release PR** covers all four trains — one human merge is
  one release wave.

Companions skip the GitHub Release because GitHub Releases are repo-wide,
not package-aware: a companion release would otherwise displace the core
plugin as the repo's "Latest." `skip-github-release` also suppresses Release
Please's own tagging for those packages, so the **companion tag step** in
`.github/workflows/release-please.yml` compensates — after the release runs,
it reads each companion's just-released version out of
`.release-please-manifest.json` and creates any missing
`spark-<name>-vX.Y.Z` tag idempotently, a no-op once the tag exists.

## The mechanical backstop

The model above is prose; Spark also enforces it. `hooks/guard-bash.sh`'s
PreToolUse guard blocks the hand-cut release vectors — `git tag <name>`
(creation forms), `gh release create`, push refspecs targeting `refs/tags/…`,
`git push --tags`/`--follow-tags`, and `git update-ref refs/tags/…` — but
**only when the Release Please marker exists at the repo root** (the config
file or a `release-please` workflow, the same conditional the fallback
describes). Non-creating tag and release subcommands stay allowed everywhere.
See [`reference/hooks.md`](../reference/hooks.md) for the exact forms and
where the boundary stops (it reads command text, not branch state).

## Verification surfaces

- **`spark doctor --requirements`'s `release` group** — reports whether
  `release.mechanism` resolves to `release-please` and, if so, whether
  `release-please-config.json` and the workflow file are both present. It
  checks that the wiring exists, not that the config's contents are correct.
- **`tests/test-guard-bash.sh`** (via `bash tests/run.sh`) — asserts the
  guard's conditional: tag creation (plain, `-c`-prefixed, companion-style
  names), `gh release create`, `refs/tags/` push refspecs, `--tags` pushes,
  and `update-ref refs/tags/` writes are denied with the marker present
  (config file or workflow), allowed without it, and non-creating forms stay
  allowed in both.

Neither surface verifies Release Please's config content or resulting
artifacts beyond presence. Closing that gap is part of the planned
milestone-gate readiness signal (developer-only: issue #194), which is meant
to assemble exactly that evidence before a human approves a release.

## Token governance

The release workflow runs as some identity, and that identity shapes the
handoff. On the default, implicitly-injected `GITHUB_TOKEN`, two documented
limitations apply: resources the workflow creates don't trigger downstream
workflows, and the release PR's own checks can be held for manual approval —
so a deliberate token identity (a dedicated GitHub App or a least-privilege
fine-grained PAT) is an operator decision every Release Please repo
eventually makes, together with rotation, storage, and what happens when the
token dies (today: the release PR silently stops refreshing — nothing
detects that mechanically).

For this repository the current state, the evidence, and the pending
identity decision are recorded developer-only in
<https://github.com/jwogrady/spark/blob/master/docs/reference/release-token-governance.md>
— they are repo-operations facts, not part of the shipped model.

## Open questions

- Whether `spark doctor --requirements` already satisfies "verify Release
  Please's config and artifacts rather than recreate them," or needs new
  checking logic beyond presence and the guard's block-on-mutation rule.
- The ADR audit (issue #180) is the ADR-visible record of this boundary and
  any superseded decisions; this doc cross-references it, not substitutes.
- The token-identity decision above, this repo's standing release blocker.

## Related docs

- [`skills/ship/SKILL.md`](../../skills/ship/SKILL.md) — the canonical wording this doc explains.
- [`explanation/sdlc-doctrine.md`](sdlc-doctrine.md) — the version ladder Release Please's bump derivation applies to.
- [`reference/engineering-preferences.md`](../reference/engineering-preferences.md) — the same model as a generated project's default.
- [`reference/hooks.md`](../reference/hooks.md) — the guard rule backing this boundary.
- [`explanation/enforcement-model.md`](enforcement-model.md) — why Spark enforces rules like this mechanically.

Developer-only (not shipped with the plugin):

- ADR-0006 — <https://github.com/jwogrady/spark/blob/master/docs/adr/0006-cosmics-use-release-please.md>
- ADR-0009 — <https://github.com/jwogrady/spark/blob/master/docs/adr/0009-spark-release-mechanism.md>
- ADR-0016 — <https://github.com/jwogrady/spark/blob/master/docs/adr/0016-companion-release-path.md>
