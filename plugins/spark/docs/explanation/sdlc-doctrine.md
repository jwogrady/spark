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
| **Codify** | `/spark:codify` | Implement one issue as focused commits on a feature branch | The issue's criteria are met in committed code |
| **Validate** | `/spark:validate` | Review and harden the change | Reviews pass and the app/tests verify |
| **Ship** | `/spark:ship` | Publish the committed branch as one focused PR | PR is open and links the issue |

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

**The milestone is the version authority; Release Please is the release
mechanic.** A version number names a shippable product state — the milestone's
outcome — never the semantic category of whichever commit happened to land.
Conventional Commits classify changes and build the release notes; they do not
get to decide that a milestone was achieved. The zd-dns field test proved both
halves the hard way: default bump rules minted a milestone number from an
ordinary `feat:` commit, and the very first release defaulted toward `1.0.0`
because release-please's `initialReleaseVersion()` is hardcoded to it when no
release exists and no `initial-version` is set.

Spark's seeded Release Please configuration encodes the policy directly:

- **`versioning: always-bump-patch`** — day-to-day merges only ever advance
  the patch line (`0.1.1 → 0.1.2 → …`). No commit type can silently consume a
  milestone number.
- **`initial-version: 0.0.1`** — a repository with no release cannot default
  its first release to `1.0.0`.
- **A milestone boundary is minted deliberately**: when the milestone's
  outcome is real, the landing commit (or the release PR) carries
  `Release-As: X.Y.0` with the version the milestone declared. `0.1.0` means
  the first *usable* product — earned when it's usable, not at the first
  feature. There is no obligation to release anything before a shippable
  milestone exists, and no per-issue release quota.

```
development   0.0.1 -> 0.0.2 -> ...          (patch line, always-bump-patch)
milestone     Release-As: 0.1.0              (the milestone's declared version)
development   0.1.1 -> 0.1.2 -> ...
next          Release-As: 0.2.0
```

Release Please remains the sole owner of version-file updates, CHANGELOG
generation, tags, and GitHub Releases, and merging its release PR remains the
human release act — see [release-ownership.md](release-ownership.md) and the
ship skill's Release Please reference for the operational details, including
the stale-release-PR trap.

This policy governs the project being built. Spark's own version is a separate
line (already past `0.1.0`).

## The loop closes

Shipped work that reveals a new problem doesn't get bolted onto the current PR —
it starts again at Ideate. That's what makes this a lifecycle and not a
checklist.

See also the architecture map (developer-only, in the Spark repo):
https://github.com/jwogrady/spark/blob/master/docs/architecture/spark-internals.md
