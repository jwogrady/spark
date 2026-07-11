---
name: docit
description: Generate or refresh a repo's public-facing docs (README, philosophy/motivation, positioning, launch copy) by writing through a small crew of author personas, then assembling them with an Editor-in-Chief. Use when the user wants to "glow up" a repo to attract GitHub stars, write or rewrite the README, articulate the project's philosophy, or produce launch/marketing copy aimed at developers. Not for internal knowledge — the Spark core's knowledge skill owns that.
---

# docit — persona-crew docs & glow-up

`docit` writes the documents that decide whether a developer stars a repo or
scrolls past. It treats the README and its companion docs as a marketing surface
with a job: turn a curious dev into an adopter. It runs a **crew of five author
personas** — each a **real subagent** under
[`agents/docit/`](../../agents/docit/) (registered as `spark-docs:docit:<name>`):

- **00 Cartographer** — ground truth: *only what is real* in the repo, verified
  with citations. Foundation for all; fact-checks every draft. *Barrier.*
- **01 Storyteller** — the reader-winning arc: hero (tagline + hook), quickstart
  (every command copy-paste real), and honest positioning vs the alternatives.
- **02 Educator** — philosophy (`docs/PHILOSOPHY.md`), the four
  [Diátaxis](https://diataxis.fr/) docs under `docs/`, and the contributing path.
- **03 Promoter** — trust signals, `[Unreleased]` changelog entries and the
  upgrade story, SEO/topics/description, and launch copy — all
  citation-bound.
- **04 Editor-in-Chief** — the lead: fuses every note into one voice, verifies
  every claim against ground truth, and files verified gaps as
  `proposed`-labeled GitHub issues for the human to triage.

**This skill is their orchestrator:** because a subagent can't spawn another
subagent, the main loop does every dispatch and enforces every barrier, while
the agents coordinate only through shared notes in `.docit-notes/` (gitignored
scratch). The phase-by-phase orchestration is in
[`references/collaboration-protocol.md`](references/collaboration-protocol.md).

## The one rule

**Honest hype.** Every persona may only claim what the Cartographer verified
from the actual repo. If a feature isn't real, it doesn't go in the README.
Excitement is earned by what the project does, not invented.

## Do this

1. **Trigger the glow-up** — invoke `/spark-docs:docit` from the repo root when
   you need to write or refresh public docs.
2. **Ground truth first (barrier)** — dispatch the cartographer alone. It writes
   the verified facts to `.docit-notes/00-ground-truth.md`. Nothing else starts
   until this exists; every persona cites it.
3. **Drafts in parallel** — dispatch storyteller, educator, and promoter
   concurrently (three Agent calls in one turn) with a "Phase 1 — Draft" brief;
   each writes its note to `.docit-notes/`.
4. **Fact-check and feedback** — re-dispatch the cartographer to fact-check
   every draft against ground truth, and the editor-in-chief to leave editorial
   feedback (voice, duplication, gaps). Both append to each note.
5. **Revise** — re-dispatch 01–03 to fold the feedback into their drafts and
   mark it resolved. A flag the cartographer marked as an **overclaim veto** is
   not negotiable: cut or cite.
6. **Editor-in-Chief synthesizes and files** — dispatch the editor-in-chief. It
   assembles the final artifacts in one voice, **presents a diff and waits for
   your go-ahead** before overwriting existing docs, then files the run's
   verified gaps as `proposed`-labeled GitHub issues (`gh issue create`). You
   triage them on GitHub — keep the keepers, close the rejects; kept issues
   flow on to the Spark core's `plan` skill. The editor files but never closes
   or comments.
7. **Ship through the lifecycle** — hand the result to the Spark core's `ship`
   skill to commit and open a PR. Commit only the published docs; keep
   `.docit-notes/` gitignored — the docs and their git history are the durable
   record.

## Guardrails

- **Honest hype** — no claim survives without a Cartographer citation;
  aspirations go in a clearly-labeled roadmap, never the feature list. The
  Cartographer's overclaim veto binds the Editor-in-Chief.
- **Author attribution** — the author field is the literal string `jwogrady`.
  Never credit Claude or any AI system in any doc, manifest, commit, or post.
- **Don't clobber silently** — show the diff and get explicit go-ahead before
  overwriting existing `README.md` or docs.
- **One voice** — the personas gather and stress-test the material; the
  Editor-in-Chief makes it read as written by one confident human.
- **The skill orchestrates; agents don't self-coordinate** — the main loop does
  every dispatch and barrier; personas communicate only through `.docit-notes/`.
- **File proposals, never triage them** — issue triage on GitHub is the human's.
  No `gh`/remote? Proposals stay in `.docit-notes/05-proposed-issues.md`.
