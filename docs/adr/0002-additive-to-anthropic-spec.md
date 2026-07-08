# ADR: Additive to Anthropic's spec — never reinvent upstream

Date: 2026-05-29
Status: Accepted
Owner: jwogrady

## Context

Anthropic owns the Claude Code skill spec, the plugin format, MCP, and the
built-in review tools. A toolkit built on top can either redefine those standards
or build on them. This decision was sharpened by user pushback against imposing a
Spark-specific convention (a required README template per skill) on top of the
upstream skill spec.

## Decision

Spark is **additive**: it references Anthropic's skill/plugin spec rather than
inventing a competing one, and reuses Claude Code's built-in `/code-review`,
`/security-review`, and `verify` rather than shipping its own equivalents. Spark's
contribution is the **human-facing usage/doctrine layer** — when to reach for a
thing, how to use it in a real GitHub workflow, and why.

Reinventing upstream standards creates drift, duplicates maintenance, and fights
the host tool. The durable value Spark adds is judgment and orchestration, not a
second copy of primitives Anthropic already maintains. Narrative in
[../explanation/scope-and-upstream.md](../../plugins/spark/docs/explanation/scope-and-upstream.md).

## Alternatives Considered

- **Ship Spark-native reviewers and a Spark skill spec.** Rejected: duplicates
  upstream, drifts from it, and imposes conventions users pushed back on.
- **Wrap upstream tools in thick Spark abstractions.** Rejected: a wrapper still
  becomes a maintenance surface that diverges; thin reuse is cheaper and clearer.

## Consequences

- The Validate stage's `validate` orchestrates the built-in review tools; it does
  not contain a reviewer.
- When Anthropic's Claude Code docs change, that is the signal to update Spark.
- Spark stays small: it carries doctrine and orchestration, not
  re-implementations.
- Clean split with ADR 0001's *distribution* concern: distribution is the
  plugin's job; *inception* is `/plugin install spark` plus `bootstrap`; neither
  reinvents upstream.

## Open Questions

- None outstanding.

## Related Docs

- [../explanation/scope-and-upstream.md](../../plugins/spark/docs/explanation/scope-and-upstream.md)
- [../explanation/sdlc-doctrine.md](../../plugins/spark/docs/explanation/sdlc-doctrine.md)
- [0001-plugin-not-framework.md](0001-plugin-not-framework.md)
- [../architecture/spark-internals.md](../architecture/spark-internals.md)
