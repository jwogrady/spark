# ADR: A Cosmic is Spark's generated unit; engineering preferences are its standard

Date: 2026-07-08
Status: Accepted
Owner: jwogrady

## Context

The operator runs many projects and re-supplies the same engineering conventions
(git workflow, stack, standards, documentation set) to each one by hand. Those
conventions have no durable home, so every new project re-derives them and drifts
from the last.

Separately, Spark is building toward generating **Cosmics**: per-client,
containerized environments, each maintained as a GitHub repository. A Cosmic is
the unit of delivery. Current state: Spark can scaffold a repository but not a
full running environment — infra, runtime, and telemetry are later rungs.

~Half of the operator's conventions already live in Spark — some enforced by
hooks (GitHub Flow, Conventional Commits, no-AI-attribution, no-trunk-commit),
some as doctrine (design-before-code, ADRs, SemVer, docs-describe-reality). The
rest (stack defaults, CI, release automation, issue taxonomy) live only in the
operator's head and get re-loaded per project.

## Decision

- The **Cosmic** is the unit Spark generates: a standardized GitHub repository
  that later grows into a per-client environment. This ADR covers the
  repo-standard rung only; infra/runtime/telemetry are deferred.
- The operator's engineering preferences are the **standard every Cosmic
  conforms to**.
- Those preferences live **inside the Spark plugin** as a single canonical
  reference — edited once, carried into every Cosmic by the plugin.
- They are **applied at generation by `bootstrap`**, the existing inception skill.

Why: this matches Spark's identity — the layer that holds the operator's intent
and applies it through Claude's tools. A single in-plugin source of truth removes
per-project drift and the re-loading cost. Reusing `bootstrap` avoids inventing a
new surface, consistent with the additive principle (ADR-0002).

## Alternatives Considered

- **A preference file copied into each repository.** Rejected: N copies drift;
  breaks the single source of truth.
- **Per-user config outside the repo (a dotfile / `~/.claude`).** Rejected: not
  carried by the plugin, not portable into the generated Cosmic, harder for an
  agent to read at generation time.
- **A brand-new `cosmic` generation skill.** Rejected for now: `bootstrap`
  already owns inception; a distinct surface is not justified until the later
  rungs give it a separate job (see Open Questions).

## Consequences

- One place to edit the standard; every future Cosmic inherits it.
- `bootstrap` grows from "scaffold a runtime" to "generate a Cosmic to standard"
  — more responsibility concentrated in one skill.
- The in-plugin reference must stay honest and must not duplicate what the
  doctrine already states (link, don't paste).
- The enforcement level of each convention still has to be decided (see ADR-0005,
  ADR-0006, ADR-0007 and the Codify-readiness reference).

## Open Questions

- The generation entry point long-term: stays `bootstrap`, or becomes a dedicated
  `cosmic` command once the infra/runtime/telemetry rungs exist. Owner: jwogrady.

## Related Docs

- [../architecture/spark-internals.md](../architecture/spark-internals.md) — the architecture map
- [0002-additive-to-anthropic-spec.md](0002-additive-to-anthropic-spec.md) — the additive principle this reuses
- [../reference/skills.md](../reference/skills.md) — where `bootstrap` sits in the skill taxonomy
