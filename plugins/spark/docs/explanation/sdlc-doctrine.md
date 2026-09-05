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

**A sub-issue is an issue.** Hierarchy is a relation between issues, not a
different unit, so every rung above applies to a sub-issue unchanged: it gets
its own branch, its own focused commits, and its own PR. `plan` creates
sub-issue hierarchies and `metadata-governance` makes them the canonical shape
of a milestone, so operators reach this question by following the lifecycle as
designed — the answer is that nothing special happens.

**A parent issue is a container, not a unit of work.** An issue with children
has no branch and no PR of its own; it closes when its children close. This
generalizes what [metadata-governance](../reference/metadata-governance.md)
already says of the release-readiness issue. If a parent carries work that no
child covers, that work becomes another child — it does not become a quiet
commit on a parent branch.

**The over-splitting test.** The doctrine's loud failure mode is scope
collapse, so it is worth naming the opposite one: if a candidate sub-issue
cannot carry its own acceptance criteria and justify its own PR, it is an
acceptance criterion on the parent, not a sub-issue. Splitting until every leaf
is a checklist item buys ceremony, not traceability.

## Delivery

Canonical delivery is GitHub Flow at the issue level:

```
issue → issue branch → focused commits → validation → issue PR → trunk
```

An issue branch carries **multiple focused Conventional Commits** — Codify
commits each coherent implementation step, Validate commits its review fixes,
and Ship publishes what already exists. Two invariants make parallel work
safe: **ordering** — if issue B depends on issue A, B's base must verifiably
contain A's merged result (Plan records the dependency in GitHub; Codify
demands the proof — merged result an ancestor of HEAD, HEAD exactly at the
fresh trunk — and blocks or reports not-assessed otherwise) — and **one
writer per working tree** — concurrent
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

## A Crossroad is a missing authority, not a feeling

The autonomous loop's costliest stop is not running past a real human boundary —
it is inventing one. A genuine Crossroad exists only when the next motion needs
an authority a durable surface reserves to the human: a **new authority grant**,
a **materially different product/governance semantic**, an **unresolved
human-owned release policy**, a **destructive or irreversible external action**,
or another **durable `DECISION REQUIRED`**. Before emitting `DECISION REQUIRED`,
an agent must be able to name the exact missing authority and cite the durable
surface that reserves it.

Everything else continues. Activating an implementation the owning issue already
authorized is not a new grant merely because it goes live on merge. Substituting
one form of evidence for another — an independent exact-HEAD review standing in
for a bootstrap that cannot review itself — is a verification question, not a
governance decision. Co-authorship, operator courtesy, perceived
presumptuousness, and general "this feels consequential" are never authority. If
no reserved authority is actually missing and acceptance is true, the agent
continues the already-authorized close-out — a routine merge under standing
authority, with exact-head protection — and a completed PR does not end the
session: it flows into owning-issue reconciliation and the next executable work.

This governs only the human-handoff decision. It changes nothing about `UNKNOWN`
/ `NOT ASSESSED` never being a pass, stale-head protection, independent review,
or CI — those stop work on their own evidence. `spark crossroad` encodes the
distinction mechanically.

### A broad outcome may own many mergeable increments

"Acceptance is true" needs one more distinction, because the obvious reading
stalls real work. A broad outcome issue — *prove the performance gate with
equal-workload benchmarks* — is deliberately not true for a long time. If every
increment beneath it waits for the parent, each otherwise-routine merge needs a
human, and the operator becomes a rubber stamp on work they already authorized.

So a broad issue may durably authorize **bounded work units** that carry their
own acceptance. A bounded unit may merge routinely when its **own** acceptance —
not the parent's — is true on the exact current HEAD, independent exact-HEAD
review and required checks are green, exact-head protection holds, the mutation
is routine and reversible, and no reserved human boundary remains.

Merging the child **advances** the broader outcome. It never closes, satisfies
or implies it. The parent stays open until its own acceptance is independently
true, and the release decision remains human-owned exactly as before.

The safety default inverts here, and the inversion is the whole design.
`crossroad` fails toward `CONTINUE` because its defect was a false stop. Merge
eligibility fails toward `NOT ELIGIBLE` because its defect would be manufactured
authority — the failure that silently closes a broad outcome on the strength of
one small child. **Eligibility is affirmed positively or not at all; the absence
of a known disqualifier is not proof of permission.** Three things therefore
create nothing on their own: referencing a broad issue, moving evidence without
satisfying the bounded acceptance, and coordination — `#585`, relay handoffs and
a reviewer `PASS` are evidence and sequencing, never permission.

`spark merge-authority` encodes this mechanically, and it is meant to be
consulted *before* implementation, so the merge question is derivable from
durable facts rather than discovered after a PR reaches `PASS`.

This does not move the human approval point that ADR-0019 fixes. The human still
owns intent, judgment, **acceptance** and the release decision: they author the
bounded acceptance durably and in advance, and the agent only verifies that what
the human already accepted is now true. Nothing ships without human approval —
a merge to the trunk is not a release, and the release act stays exactly where
ADR-0027 and ADR-0026 put it.

## The loop closes

Shipped work that reveals a new problem doesn't get bolted onto the current PR —
it starts again at Ideate. That's what makes this a lifecycle and not a
checklist.

See also the architecture map (developer-only, in the Spark repo):
https://github.com/jwogrady/spark/blob/master/docs/architecture/spark-internals.md
