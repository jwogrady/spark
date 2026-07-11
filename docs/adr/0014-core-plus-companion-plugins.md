# ADR: One marketplace, a focused core, and companion plugins

Date: 2026-07-11
Status: Accepted; answers ADR-0013's open question and supersedes its
extraction-as-removal disposition — extractions are moves into companion
plugins in this repository; its own open question (per-companion release
automation) is answered by ADR-0016
Owner: jwogrady

## Context

ADR-0013 decided what leaves the core plugin but left its open question
unanswered: where the extracted products live. Meanwhile the audit
consolidation landed the new `audit` skill inside the core, and the operator
reviewed a full artifact-by-artifact verdict sheet that draws the product
boundary tighter still: the core is the shipping loop (setup, bootstrap, the
five lifecycle stages, preferences, brief/resume/state, the two enforcement
doors, doctor and CI, Release Please scaffolding) plus minimal
agent-contract and decision-documentation support — and everything else is a
companion product, including the audit capability itself.

The repository is already a marketplace: `.claude-plugin/marketplace.json`
carries a `plugins` array. A marketplace can list more than one plugin.

## Decision

- **This repository stays one marketplace and gains companion plugins.**
  The catalog lists four installable plugins:
  - `spark` — the core: `setup`, `bootstrap`, `ideate → plan → codify →
    validate → ship`, preferences and project overrides, `brief`/`resume`
    and the work state, the two enforcement doors, `doctor` + CI, Release
    Please scaffolding, `agents-md`, and a slimmed `knowledge`.
  - `spark-audit` — whole-project assessment and evidence-backed cleanup
    (the audit skill moves out of the core).
  - `spark-connect` — providers, credentials, 1Password, smoke tests — and
    `shred-env`, which moves with it (no independent core purpose).
  - `spark-docs` — public docs, positioning, visuals, launch copy, with a
    dramatically reduced author crew.
- **Extractions are `git mv`, not deletion.** History is preserved in
  place; each companion is installable immediately
  (`/plugin install spark-audit`, skills namespaced `/spark-audit:<name>`).
- **Doctor validates the whole marketplace.** Inside this repository it
  checks every listed plugin's manifest and skill frontmatter, not only the
  core's — the validation gate follows the product boundary.
- **Companions version independently**, starting at `0.1.0`; Release Please
  continues to version the core. Wiring per-companion release automation is
  deferred until a companion actually needs a release.

Why: the core's promise is the shipping loop, and every co-resident skill
competes for the operator's attention, doctor's coverage, and the docs'
clarity. Same-repo companions keep distribution one `marketplace add` while
letting each product carry its own weight — and `git mv` keeps every line of
history reviewable.

## Alternatives Considered

- **Separate repositories per companion.** Rejected for now: three new
  repos to bootstrap, three marketplaces to add, and cross-repo moves lose
  in-place history. Revisit if a companion grows its own contributors or
  cadence.
- **Keep audit in the core.** Rejected: assessment/cleanup is periodic
  maintenance, not the shipping loop; the verdict sheet places it with the
  companions.
- **Delete instead of move (ADR-0013's original disposition).** Rejected:
  the capabilities are wanted, just not in the core; moves ship them the
  same day.

## Consequences

- The core drops to nine skills (five lifecycle, `setup`-fronted carry-in
  via `bootstrap`, `knowledge`, `agents-md`) — the taxonomy, README,
  CLAUDE.md, and doctor all reflect it.
- The core CLI loses `shred-env`; SECURITY.md describes the smaller
  surface.
- `plugins/<name>/` becomes the layout contract; the packaging reference
  documents the multi-plugin shape.
- Companion quality now gates the same CI run as the core.

## Open Questions

- Per-companion release automation (Release Please multi-package or tags)
  — deferred until a companion needs a release. Owner: jwogrady.

## Related Docs

- [0013-the-plugin-ships-only-carry-surfaces.md](0013-the-plugin-ships-only-carry-surfaces.md) — the portfolio decision this homes
- [0001-plugin-not-framework.md](0001-plugin-not-framework.md) — the marketplace mechanism this reuses
- `docs/reference/plugin-manifest.md` — the packaging layout
