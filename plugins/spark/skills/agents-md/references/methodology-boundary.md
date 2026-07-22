# Keep the methodology in Spark; keep product in the project

When maintaining a project's `CLAUDE.md` / `AGENTS.md`, hold this boundary: the
Spark methodology lives in Spark and is edited once; the project repo carries
only its own product.

## Link the methodology, don't paste it

The Spark methodology — the lifecycle, the one-issue-per-branch rule, the
loop-closes principle — lives in Spark and is edited once. A project repo carries
only its own product: problem statement, decisions, glossary, plan. When a
contract file needs to say *how* the project is built, **link Spark's doctrine
instead of restating it.** Never generate a project-local copy of the process
(no `*-workflow.md`, `planning-overview.md`, or constitution restatement in the
project's `docs/`); that creates a second source of truth to maintain.

The leak runs deeper than whole files: even after the methodology files are
gone, Spark's process vocabulary survives in the *framing* of the docs that
remain. When maintaining or auditing a contract file, strip Spark-internal
process framing — `Phase N` / `Prompt NNN` status headers, `/spark:` stage
references, "deferred to later Spark stages." A status or scope line describes
the file's own authority, not the lifecycle stage that produced it.

## The canonical pointer

For a project's `CLAUDE.md` / `AGENTS.md`:

```markdown
## How this project is built

Built with the [Spark lifecycle](https://github.com/jwogrady/spark)
(`Ideate → Plan → Codify → Validate → Ship`). The process and standards live in
Spark; this repo carries only <project>'s problem, decisions, and plan.
```
