# The Spark lifecycle

> Explanation — understanding-oriented.

Spark has one organizing spine: a software-development lifecycle for building
projects on GitHub. The five lifecycle skills each map to exactly one stage; the
other three skills (setup, supporting) serve that spine without being
stages of it — see [`../reference/skills.md`](../reference/skills.md).

```
Ideate → Plan → Codify → Validate → Ship
```

| Stage | Skill | The job | Done when |
|---|---|---|---|
| **Ideate** | `/spark:ideate` | Turn a fuzzy idea into a written problem statement | You can state the problem and success criteria in one screen |
| **Plan** | `/spark:plan` | Decompose the problem into features as GitHub issues | Each issue has verifiable acceptance criteria |
| **Codify** | `/spark:codify` | Implement one issue on a feature branch | The issue's criteria are met in code |
| **Validate** | `/spark:validate` | Review and harden the change | Reviews pass and the app/tests verify |
| **Ship** | `/spark:ship` | Commit cleanly and open a focused PR | PR is open and links the issue |

## Why these five, in this order

Each stage produces the input the next one needs, and each has a crisp
definition of done. The ordering kills the two most common failure modes:
building before the problem is understood, and shipping before it's verified.

## Two principles the lifecycle enforces

**Don't reinvent Anthropic's tools.** The Validate stage deliberately leans on
Claude Code's built-in `/code-review`, `/security-review`, and the `verify`
skill rather than shipping a Spark reviewer. Spark adds the *orchestration and
the when/why*, not a competing reviewer.

**One concern per unit.** One problem per ideate, one feature per issue, one
issue per branch, one concern per PR. Scope creep becomes a new issue, never a
silent addition.

## Versioning

Projects built with Spark follow one version ladder. It is a Spark
**convention**, not stock SemVer — whose own guidance for early development is
"start at `0.1.0`, bump minor each release." The ladder layers on top of
SemVer's "anything MAY change in `0.y.z`" allowance:

| Version | Meaning |
|---|---|
| `0.0.0` | Ideate + Plan complete — formation, no code. A *phase marker*, not a released artifact. |
| `0.0.1 → 0.0.x` | Each discrete coding contribution (one issue / one PR = one patch bump). The first Release lands at the first `0.0.x` with code. |
| `0.1.0` | First **usable** product — earned when it's usable, not at the first feature. |

After `0.1.0`, the bump is derived from the conventional-commit types Spark
already enforces: `feat:` → minor, `fix:`/`docs:`/`chore:`/`refactor:` → patch,
`!` or `BREAKING CHANGE` → major.

This ladder governs the project being built. Spark's own version is a separate
line (already past `0.1.0`).

## The loop closes

Shipped work that reveals a new problem doesn't get bolted onto the current PR —
it starts again at Ideate. That's what makes this a lifecycle and not a
checklist.

See also the architecture map: ../architecture/spark-internals.md.
