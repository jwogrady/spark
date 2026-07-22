---
name: knowledge
description: Turn messy notes, findings, and decisions into clean, durable internal docs — ADRs, system docs, product specs, SOPs/runbooks, glossary entries — via a three-role crew (intake → author → librarian-editor). Use to record a decision or document a system or process. Not for outward-facing marketing or README glow-ups — that's `docit` (public docs).
---

# knowledge — minimal decision documentation

`knowledge` captures what a team knows so it stays reusable for humans and AI
agents. It takes raw input — notes, transcripts, architecture decisions, repo
findings, Claude Code session summaries — and files it as clean, durable,
searchable docs. It is a cross-cutting tool, not a lifecycle stage: it runs
whenever [`codify`](../codify/SKILL.md), [`validate`](../validate/SKILL.md), or
[`ship`](../ship/SKILL.md) turn up a decision, system, or process worth keeping,
or alongside [`ideate`](../ideate/SKILL.md) when raw intent needs structure.
(Public docs and positioning are the spark-docs companion plugin's job.)

## The one rule

**Capture truth; mark uncertainty.** Knowledge never invents company facts. It
keeps **facts separate from assumptions**, **current state separate from
intended state**, and flags what it doesn't know instead of smoothing it over. A
clean doc that hides an unknown is worse than a rough one that names it.

## The crew

Three real subagents under [`agents/knowledge/`](../../agents/knowledge/)
(registered as `spark:knowledge:<name>`), orchestrated by this skill:

- **00 Intake** — structures raw input into a fact base and recommends a doc
  type. *Barrier.*
- **01 Author** — the one specialist: drafts with the template the doc type
  calls for (ADR, system doc, product spec, SOP/runbook) from
  [`references/templates.md`](references/templates.md).
- **02 Librarian-Editor** — the lead: placement, dedup, cross-links, glossary
  upkeep, then final one-voice synthesis and filing.

## Do this

1. **Invoke** `/spark:knowledge` from the repo root, pointing it at the raw
   input (notes, a file, a transcript, a session summary, or a described topic).
2. **Intake first (barrier)** — dispatch `spark:knowledge:intake` alone. It
   writes `.knowledge-notes/00-intake.md` and names the doc type.
3. **Author drafts** — dispatch `spark:knowledge:author`; it picks the template
   the doc type calls for. A `mixed` request means it drafts each slice.
4. **Review + shelve** — dispatch `spark:knowledge:librarian-editor` for draft
   feedback plus placement, dedup, cross-links, and glossary changes.
5. **Author revises** — folds the feedback in; resolves or defers each open
   question.
6. **Synthesize + file (barrier)** — the librarian-editor writes the final doc
   in one voice to the recommended path and updates the glossary/index. For any
   overwrite, **show the diff first** and get a go-ahead before writing.
7. **Promote deliberately (optional)** — glossary-only: if operator-level
   vocabulary candidates were flagged, present them and promote only on explicit
   go-ahead (never copy silently; project-local wins on conflict), per
   [`references/operator-knowledge.md`](references/operator-knowledge.md).
8. **Ship through the lifecycle** — hand the result to
   [`ship`](../ship/SKILL.md). Commit only the published docs; keep
   `.knowledge-notes/` gitignored — the docs and their git history are the
   durable record.

Phase-by-phase orchestration and barriers:
[`references/collaboration-protocol.md`](references/collaboration-protocol.md).

## Guardrails

- **Capture truth; mark uncertainty** — see "The one rule."
- **Author attribution** — the author field is the literal string `jwogrady`.
  Never credit Claude or any AI system in any doc, manifest, commit, or post.
- **Don't clobber silently** — show the diff and get go-ahead before overwriting
  an existing doc; prefer updating an existing doc over a near-duplicate.
- **Match the docs system** — file into the repo's existing structure (`docs/`,
  `docs/adr/`, `docs/architecture/`, `docs/product/`, `docs/ops/`,
  `docs/runbooks/`, `docs/glossary/`); don't invent a parallel scheme.
- **Preserve domain vocabulary** — the crew consults the glossary tiers and never
  normalizes the operator's domain vocabulary; the tiers and the shipped seed are
  in [`references/glossary.md`](references/glossary.md).
- **Don't touch application code** — knowledge writes docs; it inspects code to
  document it, never to change it.
- **The skill orchestrates; agents don't self-coordinate** — the main loop does
  every dispatch and barrier; agents communicate only through
  `.knowledge-notes/`, dispatched fresh per phase.
