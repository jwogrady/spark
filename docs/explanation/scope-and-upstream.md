# Spark's scope, and the role of fork-init

> Explanation — understanding-oriented.

## Spark is additive

Spark does not redefine standards that Anthropic owns. The Claude Code skill
spec, the plugin format, MCP, the built-in review tools — those are upstream.
Spark's job is the **human-facing layer on top**: when do I reach for this, how
do I use it in a real GitHub workflow, what problem does it solve.

Practically, that means:

- Spark **references** the skill/plugin spec; it does not invent a competing one.
- The Solve stage **uses** `/code-review` and `/security-review`; it does not
  ship its own.
- When Anthropic's Claude Code docs change, that's the signal to update Spark.

## Distribution vs. inception

Two different needs that used to be tangled together:

- **Distribution** — "I want my toolkit available in this project." This is now
  the plugin's job: install once, available everywhere.
- **Inception** — "I want to scaffold a brand-new project." This is `fork-init`'s
  job: clone Spark as a seed, wire the new repo, run project setup.

They no longer compete. You can use the plugin in any existing project without
forking anything; you use `fork-init` only when you're starting a project from
scratch and want Spark's templates as the seed.

See also the dated decision record: [../adr/0002-additive-to-anthropic-spec.md](../adr/0002-additive-to-anthropic-spec.md).
