---
name: docsmith
description: Generate or refresh a repo's public-facing docs (README, philosophy/motivation, positioning, launch copy) by writing through a cast of author personas, then assembling them with an Editor-in-Chief. Use when you want to "glow up" a repo to attract GitHub stars, write or rewrite the README, articulate the project's philosophy, or produce launch/marketing copy aimed at developers.
---

# docsmith — multi-persona docs & glow-up

`docsmith` writes the documents that decide whether a developer stars a repo or
scrolls past. It treats the README and its companion docs as a marketing surface
with a job: turn a curious dev into an adopter. To do that it runs a **team of
author personas** — each persona owns one section through a distinct perspective
(the Skimmer's first impression, the Adopter's zero-to-value run, the Skeptic's
"why not the raw tool") — who draft in parallel, **evaluate each other's related
work**, fold the feedback back in, and hand a single **Editor-in-Chief** the job
of fusing it all into honest, high-energy docs in one voice.

The pattern borrows [`review`](../review/SKILL.md)'s shared-notes mechanism but
is **not strictly sequential**. Only the Cartographer's ground truth is a hard
barrier; after that the team works as a multi-phase process — parallel drafts →
cross-evaluation against each persona's dependency-graph neighbors → revise in
place → synthesis. The dependency graph is what keeps parallel drafts consistent:
each persona reconciles with the personas it reads and the personas that read it.
Each persona's spec lives in its own file under
[`references/personas/`](references/personas/); the full phase-by-phase mechanics
are in [`references/collaboration-protocol.md`](references/collaboration-protocol.md).

## The one rule

**Honest hype.** The Amplifier and every other persona may only claim what the
Cartographer verified from the actual repo. If a feature isn't real, it doesn't
go in the README. Excitement is earned by what the project does, not invented.

## Do this

1. **Trigger the glow-up** — invoke `/spark:docsmith` from the repo root when you
   need to write or refresh public docs.
2. **Ground truth first (barrier)** — the Cartographer (00) reads the repo and
   writes the verified facts (what it is, the lifecycle, install steps, real
   differentiators) to `.docsmith-notes/00-ground-truth.md`. Nothing else starts
   until this exists; every persona cites it.
3. **Personas draft in parallel** — personas 01–09 draft their sections
   concurrently into their own files in `.docsmith-notes/`, each working from
   ground truth plus whatever neighbor drafts already exist. Aggregators 10
   (Discoverer) and 11 (Amplifier) draft once 01–09 are stable.
4. **Cross-evaluate related work** — each persona reviews its dependency-graph
   **neighbors** (the notes it reads and the personas that read it) and leaves
   targeted feedback on each. The Cartographer fact-checks every draft against
   ground truth.
5. **Revise in place** — each persona folds the feedback into its own draft.
   Run another cross-eval/revise round if contradictions surfaced; stop when a
   round produces no new feedback.
6. **The team holds the Issue Council** — every persona nominates the gaps it found,
   argues for them, contests the others', and votes on two ballots: **admission**
   (in or out) and **priority** (P1/P2/P3). The Cartographer can veto anything that
   would overclaim. The Editor-in-Chief chairs and tallies but does **not** break
   ties — deadlocks are surfaced to you with both sides' arguments, and you decide.
   The result is a ranked slate in `.docsmith-notes/issue-council.md`.
7. **Editor-in-Chief synthesizes** — persona 12, the team leader, reads every
   revised note, all feedback, and the council outcome, enforces one voice, removes
   duplication, verifies every claim traces back to ground truth, and writes the
   final artifacts.
8. **The leader files the slate** — the Editor-in-Chief writes the council's ranked
   issues to `13-proposed-issues.md` and files each as a `proposed`-labeled GitHub
   issue (`gh issue create`). You triage them in GitHub — keep the keepers, close
   the rejects; kept issues flow on to [`plan`](../plan/SKILL.md). The leader files
   but never closes or comments.
9. **Review the diff before it lands** — public docs are outward-facing. Show the
   user the proposed `README.md` and companion docs (or a diff against existing
   ones) and get a go-ahead before overwriting anything.
10. **Commit through the lifecycle** — hand the result to [`commit`](../commit/SKILL.md)
    and [`ship`](../ship/SKILL.md). Archive `.docsmith-notes/` so the reasoning is
    recoverable.

## The author personas

The team works each of these perspectives, drafting in parallel and cross-evaluating
neighbors. The full spec for each — mission, tasks, neighbors, outputs — lives in
its own file under [`references/personas/`](references/personas/).

- **00 The Cartographer** — ground truth. Reads the repo (README, CLAUDE.md, skills,
  CLI, manifests) and records *only what is real*: purpose, capabilities, the
  lifecycle, install/usage, genuine differentiators. Foundation for every persona.
- **01 The Skimmer** — gives the repo 10 seconds. Owns the hero: project
  name, one-line tagline, the hook, the "what is this and why care" above the fold.
- **02 The Adopter** — ready to try it. Owns install + quickstart. Can a
  newcomer go from zero to first value in minutes? Every command must be copy-paste
  real.
- **03 The Skeptic** — asks "why not just use the raw tool / something
  I already have?" Owns positioning and comparison. Names the alternative honestly
  and shows the delta.
- **04 The Evaluator** — a senior dev or tech lead deciding whether to bet a team
  on it. Owns trust and maturity signals: license, CI status, release cadence,
  maintenance posture, security — "is this alive and safe to depend on?"
- **05 The Believer** — wants to know what the project *stands for*. Owns
  motivation and philosophy (e.g. `docs/PHILOSOPHY.md`) — the worldview, the
  problem it refuses to accept, the doctrine.
- **06 The Coach** — teaches the tool in depth. Owns the
  [Diátaxis](https://diataxis.fr/) docs: **tutorials** (learning-oriented),
  **how-to guides** (task-oriented), **reference** (information-oriented), and
  **explanation** (understanding-oriented), under `docs/`.
- **07 The Contributor** — wants to extend it. Owns the contributing
  path: how to add to the project, the standards, where to start.
- **08 The Visual Storyteller** — show, don't tell. Owns diagrams, the architecture
  visual, screenshots/GIFs, and the social-preview image — the README's visual layer.
- **09 The Returning User** — an existing user upgrading. Owns the `CHANGELOG.md` /
  release notes: what changed, the upgrade path, what keeps them engaged.
- **10 The Discoverer (SEO)** — a dev who hasn't found the repo yet. Owns
  GitHub topics, the keywords in the repo description, search terms, awesome-list
  fit, and social-preview metadata.
- **11 The Amplifier** — the launch. Owns short-form hype: ready-to-post copy
  (tweet thread, HN/Show HN/Reddit). Constrained by the one rule above.
- **12 The Editor-in-Chief** — the team leader and final pass: reads all the notes,
  enforces a single confident voice, dedupes, verifies every claim against ground
  truth, writes the final `README.md` plus companion docs, and files the team's
  leftover gaps as prioritized, annotated `proposed`-labeled GitHub issues for the
  human to triage.

## Artifacts produced

- `README.md` — hero (Skimmer), quickstart (Adopter), positioning (Skeptic),
  trust badges (Evaluator), visuals (Visual Storyteller), contributing
  (Contributor), with links out to philosophy and the Diátaxis docs.
- `docs/PHILOSOPHY.md` — motivation and doctrine (Believer).
- `docs/tutorials/`, `docs/how-to/`, `docs/reference/`, `docs/explanation/` — the
  four Diátaxis modes (Coach).
- `CHANGELOG.md` / release notes (Returning User).
- `docs/launch-copy.md` — repo description, topics/keywords, social-preview copy,
  and post-ready hype (SEO + Amplifier).
- Visual assets / social-preview image (Visual Storyteller).
- `.docsmith-notes/issue-council.md` — the nominations, debate, and vote tally for
  the next round of work (whole team, Phase 4).
- `.docsmith-notes/13-proposed-issues.md` — the council's ranked, annotated slate
  (Editor-in-Chief), also filed as `proposed`-labeled GitHub issues for the human
  to triage; kept ones flow to [`plan`](../plan/SKILL.md).
- `.docsmith-notes/` — the per-persona working notes (archive, don't ship to users).

## Guardrails

- **Honest hype** — see "The one rule." No claim survives that the Cartographer
  didn't verify. Aspirations go in a clearly-labeled roadmap, never the feature list.
- **Author attribution** — every doc is authored by `jwogrady`. Never credit
  Claude or any AI system in any doc, manifest, commit, or launch post.
- **Don't clobber silently** — show the diff and get explicit go-ahead before
  overwriting existing `README.md` or docs.
- **Match the docs system** — companion docs follow the repo's existing
  organization (here, Diátaxis under `docs/`).
- **One voice** — the personas are a team that gathers and stress-tests the
  material; the Editor-in-Chief makes the result read as written by one confident
  human, not stitched from a dozen drafts.
- **Cross-evaluate, don't just hand off** — every persona reviews its
  dependency-graph neighbors and the feedback is folded back in before synthesis.
  A draft is not done until its neighbors have signed off (no open cross-eval items).
- **Parallel with one barrier** — only ground truth blocks; the rest of the team
  drafts and reviews concurrently, and the cross-evaluation round (not strict
  sequencing) is what keeps parallel drafts consistent.
- **The council decides issues, not the leader** — what gets proposed and how high
  it ranks comes from the personas' debate and vote, not a unilateral call. Two
  things sit above the vote: the Cartographer's honest-hype veto, and the human,
  who breaks every deadlock and makes the final triage. The chair tallies; it does
  not overrule.
- **File proposals, never triage them** — the leader files its prioritized issues
  as `proposed`-labeled GitHub issues (`gh issue create`) so the human can evaluate
  them in GitHub. This is the one place `docsmith` creates issues, and it is its
  documented contract. It never **closes or comments** — keeping, closing, and
  routing rejects is the human's call, per Spark's GitHub guardrails. No GitHub
  remote or `gh`? The issues stay in `13-proposed-issues.md` for manual filing.

## Fits the lifecycle

`docsmith` is a **Ship**-stage amplifier: once something real exists and works,
it makes the world want to use it. It also runs standalone whenever the README has
drifted from reality or a launch is coming. Pair it with [`review`](../review/SKILL.md)
first — audit the substance, then sell it.

It also **closes the loop back to Plan**: the leader files the gaps it found —
missing docs, unbuilt features it couldn't honestly claim, maturity work — as
`proposed`-labeled GitHub issues; the ones you keep flow into
[`plan`](../plan/SKILL.md), so a glow-up seeds the next milestone instead of
dead-ending.
