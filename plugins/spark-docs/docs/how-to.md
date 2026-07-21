# How to glow up a repo's public docs

> How-to — task-oriented.

Use this to write or refresh the outward-facing docs — README, philosophy,
positioning, launch copy — when the README has drifted from reality or a launch
is coming. For internal knowledge (ADRs, specs, runbooks), use the Spark core's
`knowledge` skill instead.

## 1. Invoke the glow-up

```bash
/spark-docs:docit
```

Run it from the repo root. The skill orchestrates a crew of five author
personas — real subagents that coordinate only through shared notes in
`.docit-notes/` (gitignored scratch).

## 2. Ground truth first

The Cartographer runs alone and writes the verified facts (what the project is,
install steps, real differentiators) to `.docit-notes/00-ground-truth.md`.
This is a hard barrier: nothing else starts until it exists, and every persona
cites it. The one rule is **honest hype** — if a feature isn't real, it doesn't
go in the README.

## 3. Personas draft, get checked, revise

The Storyteller (hero, quickstart, positioning), Educator (philosophy, Diátaxis
docs, contributing path), and Promoter (trust signals, `[Unreleased]`
changelog entries, SEO, launch copy) draft in parallel. The Cartographer then fact-checks every draft — an
overclaim flag is a binding veto — and the Editor-in-Chief adds editorial
feedback. The three drafters fold it all back in.

## 4. Editor-in-Chief synthesizes and files

The lead persona fuses every note into one voice, verifies every claim against
ground truth, writes the final artifacts (`README.md`, `docs/PHILOSOPHY.md`,
the Diátaxis docs, the `[Unreleased]` section of `CHANGELOG.md`, launch copy),
and files the run's verified
gaps as `proposed`-labeled GitHub issues for you to triage — kept ones flow on
to the Spark core's `plan` skill.

## 5. Review the diff, then ship

Public docs are outward-facing: review the proposed docs (or the diff against
existing ones) and give an explicit go-ahead before anything is overwritten.
Then hand the result to the Spark core's `ship` skill. Commit only the
published docs — keep `.docit-notes/` gitignored; it's process exhaust.

**Done when** the published docs claim only what the Cartographer verified,
read in one voice, and the verified gaps are filed as `proposed` issues
awaiting your triage.
