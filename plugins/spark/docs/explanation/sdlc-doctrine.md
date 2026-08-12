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

## Delivery

Canonical delivery is GitHub Flow at the issue level:

```
issue → issue branch → focused commits → validation → issue PR → trunk
```

An issue branch carries **multiple focused Conventional Commits** — Codify
commits each coherent implementation step, Validate commits its review fixes,
and Ship publishes what already exists. Two invariants make parallel work
safe: **ordering** — if issue B depends on issue A, B's base must already
contain A's merged result (Plan records the dependency in GitHub, Codify fails
closed when it's missing) — and **one writer per working tree** — concurrent
reading is fine, concurrent mutation needs genuinely isolated worktrees.

The trunk is the development line, integrated only through PRs; the *release*
is the coherent product state, gated separately by Release Please and the
human merge. A temporary integration branch (combine several coupled branches,
validate the combined tree, one PR, delete it) is a recovery/exception
technique — never a standing `develop`, never the default path.

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

After `0.1.0`, this ladder is a project-local release policy — Release
Please reads the conventional-commit types Spark already enforces and
calculates the bump against it: `feat:` → minor,
`fix:`/`docs:`/`chore:`/`refactor:`/`test:` → patch, `!` or
`BREAKING CHANGE` → major. Release Please maintains the resulting release PR; merging it is the
human-approved release act, not something this ladder performs on its own.
See [release-ownership.md](release-ownership.md) for the full boundary.

This ladder governs the project being built. Spark's own version is a separate
line (already past `0.1.0`).

## The loop closes

Shipped work that reveals a new problem doesn't get bolted onto the current PR —
it starts again at Ideate. That's what makes this a lifecycle and not a
checklist.

See also the architecture map: ../architecture/spark-internals.md.
