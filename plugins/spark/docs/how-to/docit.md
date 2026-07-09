# How to glow up a repo's public docs

> How-to — task-oriented.

Use this to write or refresh the outward-facing docs — README, philosophy,
positioning, launch copy — when the README has drifted from reality or a launch
is coming. For internal knowledge (ADRs, specs, runbooks), use
[`knowledge`](knowledge.md) instead.

## 1. Invoke the glow-up

```bash
/spark:docit
```

Run it from the repo root. The skill orchestrates a team of author personas —
real subagents that coordinate only through shared notes in `.docit-notes/`.

## 2. Ground truth first

The Cartographer runs alone and writes the verified facts (what the project is,
install steps, real differentiators) to `.docit-notes/00-ground-truth.md`.
This is a hard barrier: nothing else starts until it exists, and every persona
cites it. The one rule is **honest hype** — if a feature isn't real, it doesn't
go in the README.

## 3. Personas draft, cross-evaluate, revise

The personas (Skimmer, Adopter, Skeptic, Evaluator, Believer, Coach,
Contributor, Visual Storyteller, Returning User, then Discoverer and Amplifier)
draft their sections in parallel, review their neighbors' drafts, and fold the
feedback back in. Rounds repeat until one produces no new feedback.

## 4. The Issue Council votes

Every persona nominates the gaps it found and votes on admission and priority
(P1/P2/P3). The Cartographer can veto anything that would overclaim; deadlocks
are surfaced to **you** to break.

## 5. Editor-in-Chief synthesizes

The lead persona fuses every note into one voice, verifies every claim against
ground truth, writes the final artifacts (`README.md`, `docs/PHILOSOPHY.md`,
the Diátaxis docs, launch copy), and files the council's ranked slate as
`proposed`-labeled GitHub issues for you to triage — kept ones flow on to
`/spark:plan`.

## 6. Review the diff, then ship

Public docs are outward-facing: review the proposed docs (or the diff against
existing ones) and give an explicit go-ahead before anything is overwritten.
Then hand the result to `/spark:ship`. Commit only the published docs — keep
`.docit-notes/` gitignored; it's process exhaust.

**Done when** the published docs claim only what the Cartographer verified,
read in one voice, and the council's leftover gaps are filed as `proposed`
issues awaiting your triage.
