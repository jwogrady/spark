# Spark — developer documentation

Internal docs for building and understanding Spark itself. These are the
**developer** surface — they do **not** ship with the plugin.

The **user-facing** documentation (tutorial, how-to guides, reference, and the
explanation of why Spark is built this way) ships *with* the plugin and lives
under [`../plugins/spark/docs/`](../plugins/spark/docs/README.md).

## Architecture & decisions

How the layers fit together, and the dated record of why Spark is built this way:

- [architecture/spark-internals.md](architecture/spark-internals.md) — the architecture map: the four-plugin marketplace, the layers, the two-doors enforcement model, the subagent-orchestration pattern, and the conformance test
- [adr/0001-plugin-not-framework.md](adr/0001-plugin-not-framework.md) — Spark is a Claude Code plugin, not a framework
- [adr/0002-additive-to-anthropic-spec.md](adr/0002-additive-to-anthropic-spec.md) — Additive to Anthropic's spec — never reinvent upstream
- [adr/0003-zero-dependency-bash-and-enforcement-hooks.md](adr/0003-zero-dependency-bash-and-enforcement-hooks.md) — Zero-dependency POSIX Bash + enforcement hooks
- [adr/0004-cosmic-is-the-generated-unit.md](adr/0004-cosmic-is-the-generated-unit.md) — the generated project is Spark's unit; the operator's engineering preferences are the standard it conforms to (vocabulary superseded by ADR-0015)
- [adr/0005-cosmics-ship-ci-spark-stays-ci-free.md](adr/0005-cosmics-ship-ci-spark-stays-ci-free.md) — generated projects ship GitHub Actions CI; Spark itself stays CI-free (vocabulary superseded by ADR-0015)
- [adr/0006-cosmics-use-release-please.md](adr/0006-cosmics-use-release-please.md) — generated projects release via Release Please; `ship` defers to it (vocabulary superseded by ADR-0015)
- [adr/0007-default-stack-python-uv.md](adr/0007-default-stack-python-uv.md) — default generated-project stack is Python + `uv`; TypeScript/Bun only for a frontend (vocabulary superseded by ADR-0015)
- [adr/0008-information-architecture.md](adr/0008-information-architecture.md) — three layers (Operator/Project/Session), one canonical source per information class, the three carry motions
- [adr/0009-spark-release-mechanism.md](adr/0009-spark-release-mechanism.md) — Spark releases manually today, adopts Release Please once validation CI lands
- [adr/0010-preferences-source-model.md](adr/0010-preferences-source-model.md) — preferences resolve shipped defaults → operator overrides → committed project facts
- [adr/0011-doctor-is-the-validation-gate.md](adr/0011-doctor-is-the-validation-gate.md) — `spark doctor` is the single validation gate; two-door parity is mechanical
- [adr/0012-setup-is-the-one-command-carry-in.md](adr/0012-setup-is-the-one-command-carry-in.md) — `spark setup` is the one-command carry-in; it composes, never forks, the individual verbs
- [adr/0013-the-plugin-ships-only-carry-surfaces.md](adr/0013-the-plugin-ships-only-carry-surfaces.md) — the plugin ships only carry surfaces; consolidate the audit, extract the rest
- [adr/0014-core-plus-companion-plugins.md](adr/0014-core-plus-companion-plugins.md) — one marketplace, a focused core, and three companion plugins
- [adr/0015-generated-projects-without-the-cosmic-model.md](adr/0015-generated-projects-without-the-cosmic-model.md) — generated projects, without the Cosmic model; private vocabulary leaves the public docs
- [adr/0016-companion-release-path.md](adr/0016-companion-release-path.md) — companions release through Release Please multi-package mode
- [adr/0000-template.md](adr/0000-template.md) — the ADR template

## Packaging reference

Information about how the plugin is packaged and how it relates to Claude Code's
built-ins — contributor concerns, not user concerns:

- [reference/plugin-manifest.md](reference/plugin-manifest.md) — the plugin manifest and marketplace files

The native-overlap audit (no core skill reimplements a Claude Code built-in)
now lives in the shipped taxonomy:
[plugins/spark/docs/reference/skills.md](../plugins/spark/docs/reference/skills.md).
