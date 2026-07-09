# Spark — developer documentation

Internal docs for building and understanding Spark itself. These are the
**developer** surface — they do **not** ship with the plugin.

The **user-facing** documentation (tutorial, how-to guides, reference, and the
explanation of why Spark is built this way) ships *with* the plugin and lives
under [`../plugins/spark/docs/`](../plugins/spark/docs/README.md).

## Architecture & decisions

How the layers fit together, and the dated record of why Spark is built this way:

- [architecture/spark-internals.md](architecture/spark-internals.md) — the architecture map: layers, the two-doors enforcement model, the subagent-orchestration pattern
- [adr/0001-plugin-not-framework.md](adr/0001-plugin-not-framework.md) — Spark is a Claude Code plugin, not a framework
- [adr/0002-additive-to-anthropic-spec.md](adr/0002-additive-to-anthropic-spec.md) — Additive to Anthropic's spec — never reinvent upstream
- [adr/0003-zero-dependency-bash-and-enforcement-hooks.md](adr/0003-zero-dependency-bash-and-enforcement-hooks.md) — Zero-dependency POSIX Bash + enforcement hooks
- [adr/0004-cosmic-is-the-generated-unit.md](adr/0004-cosmic-is-the-generated-unit.md) — the Cosmic is Spark's generated unit; the operator's engineering preferences are the standard it conforms to
- [adr/0005-cosmics-ship-ci-spark-stays-ci-free.md](adr/0005-cosmics-ship-ci-spark-stays-ci-free.md) — generated Cosmics ship GitHub Actions CI; Spark itself stays CI-free
- [adr/0006-cosmics-use-release-please.md](adr/0006-cosmics-use-release-please.md) — generated Cosmics release via Release Please; `ship` defers to it
- [adr/0007-default-stack-python-uv.md](adr/0007-default-stack-python-uv.md) — default Cosmic stack is Python + `uv`; TypeScript/Bun only for a frontend
- [adr/0008-information-architecture.md](adr/0008-information-architecture.md) — three layers (Operator/Project/Session), one canonical source per information class, the three carry motions
- [adr/0009-spark-release-mechanism.md](adr/0009-spark-release-mechanism.md) — Spark releases manually today, adopts Release Please once validation CI lands
- [adr/0010-preferences-source-model.md](adr/0010-preferences-source-model.md) — preferences resolve shipped defaults → operator overrides → committed project facts
- [adr/0011-doctor-is-the-validation-gate.md](adr/0011-doctor-is-the-validation-gate.md) — `spark doctor` is the single validation gate; two-door parity is mechanical
- [adr/0000-template.md](adr/0000-template.md) — the ADR template

## Packaging reference

Information about how the plugin is packaged and how it relates to Claude Code's
built-ins — contributor concerns, not user concerns:

- [reference/plugin-manifest.md](reference/plugin-manifest.md) — the plugin manifest and marketplace files
- [reference/native-overlap.md](reference/native-overlap.md) — proof that no Spark skill reimplements a Claude Code built-in
