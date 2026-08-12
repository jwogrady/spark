# How-to — pick up where you left off

> How-to — task-oriented.

Spark's carry-forward motion ([glossary](../glossary.md)) means what a session
produces outlives it. Since v0.16 the carrier is **derive-first**: everything
git and GitHub can answer — branch, PR, issue, lifecycle position — is read
live when a session starts, and `.spark/state.json` carries only the judgment
no repo can answer: the recorded next action and blockers
([schema](../reference/state.md)). This guide is the read side: how a new
session — after `/clear`, a new terminal, or a fresh clone — gets back to work
without trusting anything stale.

## Automatically, at session start

The Spark plugin wires a SessionStart hook that runs `spark brief --short`
([hooks](../reference/hooks.md)): up to three `[spark]` lines land in Claude's
context — the current branch facts, the lifecycle position derived from the
repo's shape, the recorded next action with its date, and the resolved
standard. You do nothing; the lines describe the repo as it is right now.

## On demand: `spark resume`

For the full picture, run:

```bash
spark resume
```

It prints three sections:

- **Current reality (derived)** — the branch and tree from git, the branch's
  pull request and its state via `gh` when available, whether a problem
  statement exists, and a warning when commits on the remote trunk are missing
  from this branch (a merged prerequisite may be among them — verify the base
  before building on it).
- **Recorded intent** — what the state file claims: `next_action` and
  `blockers`, with the date they were recorded.
- **What's next** — the recorded intent to verify against the reality above.
  When the branch's PR reports merged, resume declares the loop closed instead
  of replaying a pre-merge next action.

The repo is the truth and the state is a dated claim — resume never presents a
recorded fact as current reality.

## When there is no state

`spark resume` still derives the current reality; it simply reports that no
intent is recorded. Orient from GitHub (`gh issue list`, `gh pr list`) and
start the loop with `/spark:ideate` — the first close-out creates the file.

## Keeping the state trustworthy

- Commit `.spark/state.json` like any other project fact — carry-forward
  means surviving a fresh clone. It holds only two slow-moving judgment
  values, so it no longer churns on every stage transition.
- Let the close-outs write it. Each of the five lifecycle skills ends with a
  "Carry the state forward" step; hand-editing is fine (it is plain flat
  JSON) but rarely needed.
- A file written by an older Spark still works: legacy keys are ignored and
  flagged, and the next close-out migrates it.
