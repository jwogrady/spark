# How-to — pick up where you left off

> How-to — task-oriented.

Spark's carry-forward motion ([glossary](../glossary.md)) means what a session
produces outlives it. For work in flight, the carrier is `.spark/state.json` —
a small committed file each lifecycle stage updates at its close-out
([schema](../reference/state.md)). This guide is the read side: how a new
session — after `/clear`, a new terminal, or a fresh clone — gets back to work
without re-deriving where it was.

## Automatically, at session start

The Spark plugin wires a SessionStart hook that runs `spark brief --short`
([hooks](../reference/hooks.md)): up to three `[spark]` lines land in Claude's
context — the current branch facts, the recorded stage and issue, and the
resolved standard. You do nothing; if the state file exists, Claude already
knows where you were.

## On demand: `spark resume`

For the full picture, run:

```bash
spark resume
```

It prints "Where you were" — stage, problem statement, issue, branch, PR,
blockers, all read from the state — and "What's next", the recorded
`next_action`. Every fact is cross-checked against the live repo first:

- the branch — does it still exist, and are you on it;
- the issue and PR — open, closed, or merged, via `gh` when available;
- the problem statement — still on disk where the state says.

Anything that drifted is flagged with a `!` line. The repo is the truth and
the state is a claim — resume reports the mismatch and tells you what to
check; it never invents an answer.

## When there is no state

A repo the lifecycle skills have not written to yet has no
`.spark/state.json`. `spark resume` says so and exits cleanly — orient from
GitHub instead (`gh issue list`, `gh pr list`) and start the loop with
`/spark:ideate`. The first close-out creates the file.

## Keeping the state trustworthy

- Commit `.spark/state.json` like any other project fact — carry-forward
  means surviving a fresh clone.
- Let the close-outs write it. Each of the five lifecycle skills ends with a
  "Carry the state forward" step; hand-editing is fine (it is plain flat
  JSON) but rarely needed.
- When resume flags drift, fix the world, not the file: check out the branch,
  or start the next stage — its close-out rewrites the state.
