# ADR: Spark is a Claude Code plugin, not a framework

Date: 2026-05-29
Status: Accepted
Owner: jwogrady

## Context

Spark began as a document-only `.spark/` folder forked into each project and
wired as a git upstream. Two problems: `.spark/` is not a path Claude Code scans
for skills, and forking-per-project meant the toolkit lived in N places at N
versions. Spark needed one portable, versioned distribution that Claude Code
natively understands.

The user-felt cost of the old approach was concrete: no per-project forks to
maintain, a single version everywhere, namespaced commands that never collide
with a project's own skills, and guardrails that come installed with the toolkit
rather than as a per-project setup chore.

## Decision

Package Spark as a **Claude Code plugin distributed via a marketplace**
(`.claude-plugin/plugin.json` + `marketplace.json` at the repo root). Install
once with `/plugin marketplace add jwogrady/spark` → `/plugin install spark`; the
toolkit is then available in every project under the `/spark:<name>` namespace.

A plugin is Anthropic's *official* mechanism for a portable, opinionated toolkit
carried into every project. It bundles skills, the PreToolUse hook, the `bin/`
CLI, and agent crews, versioned in one place. The narrative reasoning is in
[../explanation/why-a-plugin.md](../../plugins/spark/docs/explanation/additive.md).

## Alternatives Considered

- **Manual fork / symlink `.spark/` per project** (the prior approach). Rejected:
  not a Claude-Code-scanned path, and N forks at N versions drift.
- **A standalone framework / external CLI users install separately.** Rejected:
  reinvents distribution Claude Code already solves and fights the grain of the
  host tool.

## Consequences

- Commands are namespaced `/spark:<name>` — never collides with a project's own
  skills; obvious provenance.
- Install-once, available-everywhere; one version to maintain (`plugin.json`
  v0.2.0).
- Guardrails ship with the toolkit: installing the lifecycle also installs the
  enforcement, so discipline is the default, not a per-project chore.
- **Bundling limits:** a plugin can't carry everything (notably git hooks aren't
  a plugin primitive, and `settings.json` is only partially honored) — see "What
  a plugin can't carry" in
  [../explanation/why-a-plugin.md](../../plugins/spark/docs/explanation/additive.md). Practical
  consequence: git hooks ship via `spark install-git-hooks` and the permission
  baseline is applied separately.
- *Project inception* (scaffold a new repo) is no longer a separate skill — it is
  `/plugin install spark` plus the `bootstrap` skill, not toolkit distribution —
  see ADR 0002 and
  [../explanation/scope-and-upstream.md](../../plugins/spark/docs/explanation/additive.md).

## Open Questions

- The bundling constraints (which `settings.json` keys are honored) are an
  upstream Anthropic fact captured from memory at refactor time; revisit if the
  plugin spec changes.

## Related Docs

- [../explanation/why-a-plugin.md](../../plugins/spark/docs/explanation/additive.md)
- [../reference/plugin-manifest.md](../reference/plugin-manifest.md)
- [0002-additive-to-anthropic-spec.md](0002-additive-to-anthropic-spec.md)
- [../architecture/spark-internals.md](../architecture/spark-internals.md)
