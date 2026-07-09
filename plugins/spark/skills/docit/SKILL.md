---
name: docit
description: Generate or refresh a repo's public-facing docs (README, philosophy/motivation, positioning, launch copy) by writing through a cast of author personas, then assembling them with an Editor-in-Chief. Use when the user wants to "glow up" a repo to attract GitHub stars, write or rewrite the README, articulate the project's philosophy, or produce launch/marketing copy aimed at developers. Not for internal/company knowledge like ADRs, specs, or runbooks — use `knowledge` for that.
---

# docit — multi-persona docs & glow-up

`docit` writes the documents that decide whether a developer stars a repo or
scrolls past. It treats the README and its companion docs as a marketing surface
with a job: turn a curious dev into an adopter. To do that it runs a **team of
author personas** — each a **real subagent** that owns one section through a
distinct perspective (the Skimmer's first impression, the Adopter's zero-to-value
run, the Skeptic's "why not the raw tool") — who draft in parallel, **evaluate
each other's related work**, fold the feedback back in, and hand a single
**Editor-in-Chief** the job of fusing it all into honest, high-energy docs in one
voice.

The personas are plugin agents under
[`agents/docit/`](../../agents/docit/) (registered as
`spark:docit:<name>`). **This skill is their orchestrator:** because a subagent
can't spawn another subagent, the main loop does every dispatch and enforces every
barrier, while the agents coordinate only through shared notes in `.docit-notes/`.
A persona is dispatched **fresh once per phase** it takes part in — its agent
definition holds the durable identity, the orchestrator's brief names the phase.

The pattern borrows [`review`](../review/SKILL.md)'s shared-notes mechanism but
is **not strictly sequential**. Only the Cartographer's ground truth is a hard
barrier; after that the team works as a multi-phase process — parallel drafts →
cross-evaluation against each persona's dependency-graph neighbors → revise in
place → synthesis. The dependency graph is what keeps parallel drafts consistent:
each persona reconciles with the personas it reads and the personas that read it.
The full phase-by-phase orchestration — which agents to dispatch in each phase, in
parallel, with barriers between — is in
[`references/collaboration-protocol.md`](references/collaboration-protocol.md).

## The one rule

**Honest hype.** The Amplifier and every other persona may only claim what the
Cartographer verified from the actual repo. If a feature isn't real, it doesn't
go in the README. Excitement is earned by what the project does, not invented.

## Do this

1. **Trigger the glow-up** — invoke `/spark:docit` from the repo root when you
   need to write or refresh public docs.
2. **Ground truth first (barrier)** — dispatch the `spark:docit:cartographer`
   agent alone. It reads the repo and writes the verified facts (what it is, the
   lifecycle, install steps, real differentiators) to
   `.docit-notes/00-ground-truth.md`. Nothing else starts until this exists;
   every persona cites it.
3. **Personas draft in parallel** — dispatch agents 01–09 concurrently (multiple
   Agent calls in one turn) with a "Phase 1 — Draft" brief; each writes its section
   to `.docit-notes/`, working from ground truth plus whatever neighbor drafts
   already exist. Then dispatch the aggregators 10 (Discoverer) and 11 (Amplifier)
   once 01–09 are stable.
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
   The result is a ranked slate in `.docit-notes/issue-council.md`.
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
10. **Ship through the lifecycle** — hand the result to [`ship`](../ship/SKILL.md)
    to commit and open a PR. Commit only the published docs; keep `.docit-notes/`
    out of the repo (gitignore it). The scratch is process exhaust — the docs and
    their git history are the durable record of the reasoning.

## The author personas

Each persona is a real subagent under [`agents/docit/`](../../agents/docit/)
(registered as `spark:docit:<name>`); its full spec — mission, domain, neighbors,
per-phase behavior, model, and tools — lives in that definition, and the dependency
graph that pairs them for cross-eval is in
[`references/collaboration-protocol.md`](references/collaboration-protocol.md).
Each owns one section through a distinct perspective:

- **00 Cartographer** — ground truth: *only what is real* in the repo. Foundation for all. *Barrier.*
- **01 Skimmer** — the hero: name, tagline, hook, the above-the-fold "why care."
- **02 Adopter** — install + quickstart; zero to first value, every command copy-paste real.
- **03 Skeptic** — positioning vs the raw tool / alternatives; names them honestly, shows the delta.
- **04 Evaluator** — trust/maturity signals: license, CI, release cadence, security.
- **05 Believer** — motivation and philosophy (`docs/PHILOSOPHY.md`): the worldview and doctrine.
- **06 Coach** — the [Diátaxis](https://diataxis.fr/) docs under `docs/` (tutorials, how-to, reference, explanation).
- **07 Contributor** — the contributing path: standards, where to start.
- **08 Visual Storyteller** — diagrams, screenshots/GIFs, social-preview image.
- **09 Returning User** — `CHANGELOG.md` / release notes and the upgrade path.
- **10 Discoverer (SEO)** — GitHub topics, description keywords, awesome-list fit, preview metadata.
- **11 Amplifier** — launch copy (tweet thread, HN/Reddit), constrained by the one rule.
- **12 Editor-in-Chief** — the lead: fuses every note into one voice, verifies every claim
  against ground truth, writes the final artifacts, files the council's leftover gaps as issues.

## Artifacts produced

- `README.md` — hero (Skimmer), quickstart (Adopter), positioning (Skeptic),
  trust badges (Evaluator), visuals (Visual Storyteller), contributing
  (Contributor), with links out to philosophy and the Diátaxis docs.
- `docs/PHILOSOPHY.md` — motivation and doctrine (Believer).
- `docs/tutorials/`, `docs/how-to/`, `docs/reference/`, `docs/explanation/` — the
  four Diátaxis modes (Coach).
- `CHANGELOG.md` / release notes (Returning User).
- `examples/launch-copy.md` — repo description, topics/keywords, social-preview
  copy, and post-ready hype (SEO + Amplifier). Lives in `examples/`, not the
  published docs tree.
- Visual assets / social-preview image (Visual Storyteller).
- `.docit-notes/issue-council.md` — the nominations, debate, and vote tally for
  the next round of work (whole team, Phase 4).
- `.docit-notes/13-proposed-issues.md` — the council's ranked, annotated slate
  (Editor-in-Chief), also filed as `proposed`-labeled GitHub issues for the human
  to triage; kept ones flow to [`plan`](../plan/SKILL.md).
- `.docit-notes/` — the per-persona working notes (archive, don't ship to users).

## Guardrails

- **Honest hype** — see "The one rule." No claim survives that the Cartographer
  didn't verify; aspirations go in a clearly-labeled roadmap, never the feature list.
- **Author attribution** — the author field is the literal string `jwogrady`. Never
  credit Claude or any AI system in any doc, manifest, commit, or launch post.
- **Don't clobber silently** — show the diff and get explicit go-ahead before
  overwriting existing `README.md` or docs.
- **Match the docs system** — companion docs follow the repo's existing organization
  (here, Diátaxis under `docs/`).
- **One voice** — the personas gather and stress-test the material; the
  Editor-in-Chief makes the result read as written by one confident human.
- **A draft isn't done until its neighbors sign off** — no open cross-eval items
  survive into synthesis (the cross-evaluation round, not strict sequencing, is what
  keeps parallel drafts consistent).
- **The skill orchestrates; agents don't self-coordinate** — the main loop does every
  dispatch and barrier; personas communicate only through `.docit-notes/`, dispatched
  fresh per phase. Never expect one agent to wait on or call another.
- **The council decides issues, not the leader** — proposals and ranking come from the
  personas' vote. Above it sit two things only: the Cartographer's honest-hype veto and
  the human, who breaks every deadlock and makes the final triage. The chair tallies; it
  does not overrule.
- **File proposals, never triage them** — the leader files `proposed`-labeled issues
  (`gh issue create`) and never closes or comments; keeping/closing rejects is the
  human's call. No `gh`/remote? They stay in `13-proposed-issues.md` for manual filing.

## Fits the lifecycle

`docit` is a **Ship**-stage amplifier: once something real exists and works,
it makes the world want to use it. It also runs standalone whenever the README has
drifted from reality or a launch is coming. Pair it with [`review`](../review/SKILL.md)
first — audit the substance, then sell it. And it **closes the loop back to Plan**:
the gaps it files as `proposed` issues (step 8) flow into [`plan`](../plan/SKILL.md),
so a glow-up seeds the next milestone instead of dead-ending.
