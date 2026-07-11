# ADR: Generated projects, without the Cosmic model

Date: 2026-07-11
Status: Accepted; supersedes the vocabulary (not the decisions) of ADR-0004
through ADR-0007
Owner: jwogrady

## Context

ADR-0004 through ADR-0007 are written in the vocabulary of the **Cosmic** —
the operator's internal product model for a per-client instance container.
The decisions those ADRs record are sound and shipped: the operator's
engineering preferences live inside the plugin as the single standard
(ADR-0004), generated projects ship GitHub Actions CI while Spark itself
stays CI-free (ADR-0005), generated projects release via Release Please
(ADR-0006), and the default stack is Python + `uv` with TypeScript/Bun for
frontends (ADR-0007).

But the vocabulary overreaches. Spark's public docs describe a portable,
domain-neutral delivery system for any solo developer; "Cosmic" is one
operator's private product model for what *their* generated projects grow
into. Carrying it in the public docs makes a neutral mechanism read as a
proprietary one, forces every reader through a definition that buys them
nothing, and couples the plugin's documentation to a product roadmap that
lives outside this repository.

## Decision

- **The unit Spark generates is "a generated project"** — a standardized
  GitHub repository produced by `bootstrap` and conforming to the operator's
  engineering standard. That is the term the public docs use.
- **The decisions of ADR-0004 through ADR-0007 stand unchanged**: the
  in-plugin standard, CI in generated projects, Release Please releases,
  and the Python + `uv` default all apply to generated projects exactly as
  they applied to Cosmics. Only the noun is superseded.
- **"Cosmic" is retired from the public docs.** Private product vocabulary
  — what a given operator's generated projects are for, what they grow into,
  how they are branded — belongs in that operator's own configuration and
  project-local glossaries, not in Spark's shipped defaults. The glossary's
  seed stays neutral; a fork's project-local glossary wins over it.
- **The per-client-environment ambition survives as a neutral statement**:
  a generated project may grow from a standardized repository into a full
  per-client environment (infra, runtime, telemetry). The docs may say that;
  they no longer name it.

Why: Spark is domain- and stack-neutral by design, and the glossary already
promises that it holds only Spark-internal mechanism terms. "Cosmic" was the
one term that broke that promise. Retiring it makes the public docs true to
the design without reopening any decided question.

## Alternatives Considered

- **Keep "Cosmic" and define it prominently.** Rejected: the definition
  costs every reader and buys only the originating operator; it is exactly
  the project-specific vocabulary the glossary tells forks to keep local.
- **Rewrite ADR-0004 through ADR-0007 in the new vocabulary.** Rejected:
  ADR bodies are append-only history. A Status-line pointer on each is
  enough; the record of what was decided, in the words it was decided in,
  stays intact.
- **Supersede the four ADRs entirely.** Rejected: their decisions are
  shipped and correct. Superseding them would falsely signal that the CI,
  release, and stack defaults are open again.

## Consequences

- ADR-0004 through ADR-0007 carry a Status-line pointer to this ADR; their
  bodies are untouched.
- Live docs (glossary, identity, architecture map) say "generated project";
  only immutable ADR bodies still contain the word "Cosmic".
- Operator-private vocabulary has a stated home: operator config and
  project-local glossaries, never the shipped defaults.

## Open Questions

- None outstanding.

## Related Docs

- [0004-cosmic-is-the-generated-unit.md](0004-cosmic-is-the-generated-unit.md) — the generated-unit decision this renames
- [0005-cosmics-ship-ci-spark-stays-ci-free.md](0005-cosmics-ship-ci-spark-stays-ci-free.md), [0006-cosmics-use-release-please.md](0006-cosmics-use-release-please.md), [0007-default-stack-python-uv.md](0007-default-stack-python-uv.md) — the defaults that now read "generated project"
- [../../plugins/spark/docs/glossary.md](../../plugins/spark/docs/glossary.md) — the neutral seed vocabulary
