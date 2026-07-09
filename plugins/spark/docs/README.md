# Spark documentation

These docs follow [Diátaxis](https://diataxis.fr/) — four modes of documentation,
each serving a different need. Find what you need by what you're trying to do:

| You want to… | Go to | Mode |
|---|---|---|
| Learn Spark by doing, start to finish | [Tutorial](#tutorial) | Tutorial (learning) |
| Accomplish one specific task | [How-to guides](#how-to-guides) | How-to (task) |
| Look up exactly how something behaves | [Reference](#reference) | Reference (information) |
| Understand why Spark is built this way | [Understanding Spark](#understanding-spark) | Explanation (understanding) |

## One toolkit, three motions

Spark is installed once and carried into every repo. Everything it does is one
of three motions ([glossary](glossary.md)): **carry-in** — your standards enter
the project; **carry-through** — one GitHub-native lifecycle moves the work;
**carry-forward** — what a session produces outlives it. The lifecycle is the
carry-through spine:

```
Ideate → Plan → Codify → Validate → Ship
```

Each stage is a skill (`/spark:ideate`, `/spark:plan`, `/spark:codify`,
`/spark:validate`, `/spark:ship`), backed by enforcement hooks
and a small `spark` CLI. See [explanation/sdlc-doctrine.md](explanation/sdlc-doctrine.md)
for why this is the spine.

## Tutorial

New here? Start with one idea taken through all five stages, end to end:

- [tutorials/build-your-first-project.md](tutorials/build-your-first-project.md) — install Spark and run a single idea from Ideate to an open PR.

## How-to guides

Task-oriented recipes — the lifecycle stages in order, then setup, authorship,
and the supporting skills:

- [how-to/ideate.md](how-to/ideate.md) — `/spark:ideate` · frame a fuzzy idea into a written problem statement.
- [how-to/plan.md](how-to/plan.md) — `/spark:plan` · decompose the problem into scoped work items.
- [how-to/codify.md](how-to/codify.md) — `/spark:codify` · implement one work item on a feature branch.
- [how-to/validate.md](how-to/validate.md) — `/spark:validate` · review and harden the change until it's ready.
- [how-to/ship.md](how-to/ship.md) — `/spark:ship` · commit, push, and open a focused PR.
- [how-to/install.md](how-to/install.md) — install the plugin and apply the permission baseline.
- [how-to/carry-your-preferences-in.md](how-to/carry-your-preferences-in.md) — declare your standard bag once (preferences + permission baseline) and carry it into every project.
- [how-to/bootstrap.md](how-to/bootstrap.md) — `/spark:bootstrap` · scaffold a project runtime (Bun / uv).
- [how-to/connect.md](how-to/connect.md) — `/spark:connect` · wire up services and secrets via 1Password.
- [how-to/docit.md](how-to/docit.md) — `/spark:docit` · glow up the public docs through author personas.
- [how-to/knowledge.md](how-to/knowledge.md) — `/spark:knowledge` · capture internal knowledge as durable docs.
- [how-to/agents-md.md](how-to/agents-md.md) — `/spark:agents-md` · maintain and sync `CLAUDE.md` + `AGENTS.md`.
- [how-to/review.md](how-to/review.md) — `/spark:review` · run the multi-agent project audit.
- [how-to/cleanup.md](how-to/cleanup.md) — `/spark:cleanup` · purge proven-dead code and false docs.
- [how-to/resume.md](how-to/resume.md) — `spark resume` · pick up where a past session left off via the committed work state.

## Reference

Information-oriented — what each piece is and how it behaves:

- [reference/skills.md](reference/skills.md) — every skill, its stage, and what triggers it.
- [reference/codify-readiness.md](reference/codify-readiness.md) — the Plan→Codify readiness gate: the checklist and the health signal.
- [reference/cli.md](reference/cli.md) — the `spark` CLI and its subcommands.
- [reference/hooks.md](reference/hooks.md) — the enforcement hooks and what each blocks.
- [reference/engineering-preferences.md](reference/engineering-preferences.md) — the engineering standard every generated project conforms to.
- [reference/state.md](reference/state.md) — the committed work state (`.spark/state.json`) and its schema.
- [glossary.md](glossary.md) — Spark vocabulary.


## Understanding Spark

The *why* behind the build — read these to grasp the worldview and the design
choices (Explanation mode):

- [explanation/identity.md](explanation/identity.md) — **what Spark is**: the layer between your intent and Claude's tools (start here)
- [explanation/philosophy.md](explanation/philosophy.md) — what Spark stands for and the doctrine behind the rules
- [explanation/enforcement-model.md](explanation/enforcement-model.md) — why enforcement is mechanical, not advisory
- [explanation/sdlc-doctrine.md](explanation/sdlc-doctrine.md) — why the five-stage lifecycle is the spine
- [explanation/scope-and-upstream.md](explanation/scope-and-upstream.md) — what Spark adds and what it leaves to Anthropic's spec
- [explanation/why-a-plugin.md](explanation/why-a-plugin.md) — why Spark ships as a plugin, not a framework

> Building or contributing to Spark itself? The developer docs — architecture,
> ADRs, and packaging reference — live in the repository root under `docs/`, and
> do not ship with the plugin.
