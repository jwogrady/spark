---
name: docsmith
description: Generate or refresh a repo's public-facing docs (README, philosophy/motivation, positioning, launch copy) through multiple audience lenses, then assemble them with an Editor-in-Chief. Use when you want to "glow up" a repo to attract GitHub stars, write or rewrite the README, articulate the project's philosophy, or produce launch/marketing copy aimed at developers.
---

# docsmith — multi-lens docs & glow-up

`docsmith` writes the documents that decide whether a developer stars a repo or
scrolls past. It treats the README and its companion docs as a marketing surface
with a job: turn a curious dev into an adopter. To do that it looks at the repo
through several **audience lenses** — each lens is a different reader with a
different question — then an **Editor-in-Chief** assembles their findings into
honest, high-energy docs.

The pattern mirrors [`review`](../review/SKILL.md): specialist agents write to a
shared notes directory, read each other's work, and a synthesis lead produces the
final artifacts. The difference is the goal — `review` audits, `docsmith` sells
(truthfully).

## The one rule

**Honest hype.** The Amplifier and every other lens may only claim what the
Cartographer verified from the actual repo. If a feature isn't real, it doesn't
go in the README. Excitement is earned by what the project does, not invented.

## Do this

1. **Trigger the glow-up** — invoke `/spark:docsmith` from the repo root when you
   need to write or refresh public docs.
2. **Cartographer establishes ground truth first** — agent 00 reads the repo and
   writes the verified facts (what it is, the lifecycle, install steps, real
   differentiators) to `.docsmith-notes/00-ground-truth.md`. Every later lens
   cites this file. Nothing is claimed that isn't here.
3. **Audience lenses run in order** — agents 01–11 each write their section to
   their own file in `.docsmith-notes/`, reading the ground truth and all prior
   lenses so the docs stay consistent and non-repetitive.
4. **Editor-in-Chief assembles** — agent 12 reads every lens, enforces one voice,
   removes duplication, verifies every claim traces back to ground truth, and
   writes the final artifacts.
5. **Review the diff before it lands** — public docs are outward-facing. Show the
   user the proposed `README.md` and companion docs (or a diff against existing
   ones) and get a go-ahead before overwriting anything.
6. **Commit through the lifecycle** — hand the result to [`commit`](../commit/SKILL.md)
   and [`ship`](../ship/SKILL.md). Archive `.docsmith-notes/` so the reasoning is
   recoverable.

## The audience lenses

- **00 Cartographer** — ground truth. Reads the repo (README, CLAUDE.md, skills,
  CLI, manifests) and records *only what is real*: purpose, capabilities, the
  lifecycle, install/usage, genuine differentiators. Foundation for all lenses.
- **01 The Skimmer** — a dev who gives the repo 10 seconds. Owns the hero: project
  name, one-line tagline, the hook, the "what is this and why care" above the fold.
- **02 The Adopter** — a dev ready to try it. Owns install + quickstart. Can a
  newcomer go from zero to first value in minutes? Every command must be copy-paste
  real.
- **03 The Skeptic** — a dev who asks "why not just use the raw tool / something
  I already have?" Owns positioning and comparison. Names the alternative honestly
  and shows the delta.
- **04 The Evaluator** — a senior dev or tech lead deciding whether to bet a team
  on it. Owns trust and maturity signals: license, CI status, release cadence,
  maintenance posture, security — "is this alive and safe to depend on?"
- **05 The Believer** — a dev who wants to know what the project *stands for*. Owns
  motivation and philosophy (e.g. `docs/PHILOSOPHY.md`) — the worldview, the
  problem it refuses to accept, the doctrine.
- **06 The Coach** — a dev learning the tool in depth. Owns the
  [Diátaxis](https://diataxis.fr/) docs: **tutorials** (learning-oriented),
  **how-to guides** (task-oriented), **reference** (information-oriented), and
  **explanation** (understanding-oriented), under `docs/`.
- **07 The Contributor** — a dev who wants to extend it. Owns the contributing
  path: how to add to the project, the standards, where to start.
- **08 The Visual Storyteller** — show, don't tell. Owns diagrams, the architecture
  visual, screenshots/GIFs, and the social-preview image — the README's visual layer.
- **09 The Returning User** — an existing user upgrading. Owns the `CHANGELOG.md` /
  release notes: what changed, the upgrade path, what keeps them engaged.
- **10 The SEO / Discoverability** — a dev who hasn't found the repo yet. Owns
  GitHub topics, the keywords in the repo description, search terms, awesome-list
  fit, and social-preview metadata.
- **11 The Amplifier** — the launch. Owns short-form hype: ready-to-post copy
  (tweet thread, HN/Show HN/Reddit). Constrained by the one rule above.
- **12 Editor-in-Chief** — reads all lenses, enforces a single confident voice,
  dedupes, verifies every claim against ground truth, and writes the final
  `README.md` plus companion docs.

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
- `.docsmith-notes/` — the per-lens working notes (archive, don't ship to users).

## Guardrails

- **Honest hype** — see "The one rule." No claim survives that the Cartographer
  didn't verify. Aspirations go in a clearly-labeled roadmap, never the feature list.
- **Author attribution** — every doc is authored by `jwogrady`. Never credit
  Claude or any AI system in any doc, manifest, commit, or launch post.
- **Don't clobber silently** — show the diff and get explicit go-ahead before
  overwriting existing `README.md` or docs.
- **Match the docs system** — companion docs follow the repo's existing
  organization (here, Diátaxis under `docs/`).
- **One voice** — the Editor-in-Chief makes it read as written by one confident
  human, not stitched from seven drafts.
- **Sequential, not parallel** — lenses run one at a time so each reads current
  notes (same mechanism as `review`).

## Fits the lifecycle

`docsmith` is a **Ship**-stage amplifier: once something real exists and works,
it makes the world want to use it. It also runs standalone whenever the README has
drifted from reality or a launch is coming. Pair it with [`review`](../review/SKILL.md)
first — audit the substance, then sell it.
