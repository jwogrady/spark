# The Spark lifecycle

> Explanation — understanding-oriented.

Spark has one organizing spine: a software-development lifecycle for building
projects on GitHub. Every skill maps to exactly one stage.

```
Ideate → Plan → Generate → Solve → Ship
```

| Stage | Skill | The job | Done when |
|---|---|---|---|
| **Ideate** | `/spark:ideate` | Turn a fuzzy idea into a written problem statement | You can state the problem and success criteria in one screen |
| **Plan** | `/spark:plan` | Decompose the problem into features as GitHub issues | Each issue has verifiable acceptance criteria |
| **Generate** | `/spark:build` | Implement one issue on a feature branch | The issue's criteria are met in code |
| **Solve** | `/spark:fix-issue` | Review and harden the change | Reviews pass and the app/tests verify |
| **Ship** | `/spark:commit` + `/spark:ship` | Commit cleanly and open a focused PR | PR is open and links the issue |

## Why these five, in this order

Each stage produces the input the next one needs, and each has a crisp
definition of done. The ordering kills the two most common failure modes:
building before the problem is understood, and shipping before it's verified.

## Two principles the lifecycle enforces

**Don't reinvent Anthropic's tools.** The Solve stage deliberately leans on
Claude Code's built-in `/code-review`, `/security-review`, and the `verify`
skill rather than shipping a Spark reviewer. Spark adds the *orchestration and
the when/why*, not a competing reviewer.

**One concern per unit.** One problem per ideate, one feature per issue, one
issue per branch, one concern per PR. Scope creep becomes a new issue, never a
silent addition.

## The loop closes

Shipped work that reveals a new problem doesn't get bolted onto the current PR —
it starts again at Ideate. That's what makes this a lifecycle and not a
checklist.

See also the architecture map: [../architecture/spark-internals.md](../architecture/spark-internals.md).
