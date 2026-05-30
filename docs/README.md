# Spark documentation

These docs follow [Diátaxis](https://diataxis.fr/) — four modes of documentation,
each serving a different need. Find what you need by what you're trying to do:

| You want to… | Go to | Mode |
|---|---|---|
| Learn Spark by doing, start to finish | [tutorials/](tutorials/) | Tutorial (learning) |
| Accomplish one specific task | [how-to/](how-to/) | How-to (task) |
| Look up exactly how something behaves | [reference/](reference/) | Reference (information) |
| Understand why Spark is built this way | [explanation/](explanation/) | Explanation (understanding) |
| See how the pieces fit together, or trace a past decision | [architecture/](architecture/) + [adr/](adr/) | Architecture & decisions |

## The shape of Spark

Spark is a Claude Code **plugin**: one portable, opinionated toolkit you install
once and carry into every project. It organizes work around a single GitHub-native
software-development lifecycle:

```
Ideate → Plan → Generate → Solve → Ship
```

Each stage is a skill (`/spark:ideate`, `/spark:plan`, `/spark:codify`,
`/spark:fix-issue`, `/spark:commit`, `/spark:ship`), backed by enforcement hooks
and a small `spark` CLI. See [explanation/sdlc-doctrine.md](explanation/sdlc-doctrine.md)
for why this is the spine.

## Understanding Spark

The *why* behind the build — read these to grasp the worldview and the design
choices (Explanation mode):

- [explanation/philosophy.md](explanation/philosophy.md) — what Spark stands for and the doctrine behind the rules
- [explanation/enforcement-model.md](explanation/enforcement-model.md) — why enforcement is mechanical, not advisory
- [explanation/sdlc-doctrine.md](explanation/sdlc-doctrine.md) — why the five-stage lifecycle is the spine
- [explanation/scope-and-upstream.md](explanation/scope-and-upstream.md) — what Spark adds and what it leaves to Anthropic's spec
- [explanation/why-a-plugin.md](explanation/why-a-plugin.md) — why Spark ships as a plugin, not a framework

## Architecture & decisions

How the layers fit together, and the dated record of why Spark is built this way:

- [architecture/spark-internals.md](architecture/spark-internals.md) — the architecture map: layers, the two-doors enforcement model, the subagent-orchestration pattern
- [adr/0001-plugin-not-framework.md](adr/0001-plugin-not-framework.md) — Spark is a Claude Code plugin, not a framework
- [adr/0002-additive-to-anthropic-spec.md](adr/0002-additive-to-anthropic-spec.md) — Additive to Anthropic's spec — never reinvent upstream
- [adr/0003-zero-dependency-bash-and-enforcement-hooks.md](adr/0003-zero-dependency-bash-and-enforcement-hooks.md) — Zero-dependency POSIX Bash + enforcement hooks
- [glossary.md](glossary.md) — Spark-internal vocabulary
