# docit — collaboration protocol

How the five personas run as **real subagents** and how the skill orchestrates
them. Each persona is a plugin agent under
[`agents/docit/`](../../../agents/docit/) (registered as
`spark-docs:docit:<name>`).

## Who orchestrates

The skill — the main loop — is the sole orchestrator: a subagent cannot spawn
another, so every dispatch and barrier is the main loop's job, and the agents
coordinate only through shared notes on disk, never by calling each other.

A persona is **dispatched fresh once per phase it takes part in** — there is no
long-lived agent that drafts, waits, then revises. The agent *definition* under
`agents/docit/` carries the durable identity; the orchestrator's per-dispatch
brief names the phase. Launch the agents of one phase together in a single turn
(multiple Agent calls) so they run concurrently.

## The phases

```
Phase 0 — Ground truth (barrier)
  Dispatch ONE agent: the cartographer. It writes
  .docit-notes/00-ground-truth.md alone. Nothing else starts until it exists.

Phase 1 — Parallel drafts
  Dispatch storyteller (01), educator (02), promoter (03) CONCURRENTLY, each
  with a "Phase 1 — Draft" brief. Each reads ground truth and writes its note.
        ↓ 01-story.md, 02-education.md, 03-promotion.md

Phase 2 — Fact-check + editorial feedback
  Dispatch the cartographer (fact-checks every draft against ground truth,
  flagging uncited claims; overclaims are marked as vetoes) and the
  editor-in-chief (editorial feedback: voice, duplication, gaps) CONCURRENTLY.
  Both append to each note's "Fact-check feedback" section.

Phase 3 — Revise
  Re-dispatch 01–03 CONCURRENTLY with a "Phase 3 — Revise" brief. Each folds
  the feedback into its draft and marks it resolved; vetoed claims are cut or
  cited, never argued past. Repeat Phase 2–3 once if contradictions surfaced.

Phase 4 — Synthesis + file the gaps (barrier)
  Dispatch ONE agent: the editor-in-chief. It reads every revised note,
  verifies each claim against ground truth, enforces one voice, presents a
  diff and waits for the human's go-ahead, writes the final artifacts
  (README.md, docs/PHILOSOPHY.md, the docs/ Diátaxis tree, the `[Unreleased]`
  section of CHANGELOG.md, examples/launch-copy.md), logs cuts to
  04-editor-log.md, and files the
  run's verified gaps as `proposed`-labeled GitHub issues via
  .docit-notes/05-proposed-issues.md.
```

## Shared notes structure

Each persona writes one markdown file to `.docit-notes/` (gitignored scratch,
never committed). Consistent sections let the reviewers append feedback and the
Editor-in-Chief cross-reference:

- **Persona** — the perspective this note is written from.
- **Draft** — the prose/sections this persona owns.
- **Claims & citations** — each concrete claim with a pointer into
  `00-ground-truth.md` (or the file/command that proves it).
- **Fact-check feedback** — appended by the Cartographer and Editor-in-Chief in
  Phase 2; the owner addresses each item in Phase 3 and marks it resolved.

`00-ground-truth.md` is the exception: it is the verified fact base every other
note cites, with no Persona or feedback sections.

## The honest-hype contract

The single mechanism that keeps the docs truthful:

1. The Cartographer writes only verified facts and splits shipped from roadmap.
2. Every later persona must cite ground truth for any concrete claim.
3. In Phase 2 the Cartographer flags uncited claims; any flag that asserts an
   unbuilt feature as real is an **overclaim veto**.
4. The Editor-in-Chief is bound by the veto and refuses any claim still without
   a citation — cut or soften it, and log the decision in `04-editor-log.md`.

Energy and confidence are encouraged; fabrication is not. A bold tagline is
fine; a feature that doesn't exist is not.

## Output and handoff

- Final artifacts land in the repo (`README.md`, `docs/`), not in
  `.docit-notes/`. The Editor-in-Chief presents a diff and waits for go-ahead
  before overwriting existing public docs.
- **The editor files, the human triages.** Verified gaps become
  `proposed`-labeled GitHub issues (`gh issue create`); the human keeps the
  keepers and closes the rejects on GitHub. The editor never closes or
  comments, per Spark's GitHub guardrails. If `gh`/remote is unavailable, the
  issues stay in `05-proposed-issues.md` for manual filing. Accepted issues
  flow on to the Spark core's `plan` skill.
- Hand the docs change to the Spark core's `ship` skill to commit and open a PR.
