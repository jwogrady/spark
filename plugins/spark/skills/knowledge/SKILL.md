---
name: knowledge
description: Turn messy founder notes, repo findings, architecture decisions, product specs, ops workflows, and Claude Code session discoveries into clean, durable, searchable internal company knowledge — ADRs, system docs, product specs, SOPs/runbooks, onboarding guides, and glossary entries. Runs a small crew of author subagents (intake → specialist → editor + librarian). Use when the user needs to capture or write up internal knowledge, record a decision, document a system or process, or turn rough notes into a real doc. For outward-facing marketing docs and README glow-ups, use docit instead.
---

# knowledge — internal knowledge crew

`knowledge` is the inward-facing companion to [`docit`](../docit/SKILL.md). Where
docit sells a repo to strangers, knowledge captures what a team knows so it stays
**reusable for humans and AI agents**. It takes raw input — founder notes, chat
transcripts, architecture decisions, product ideas, operational know-how, schema
and deploy findings, Claude Code session summaries — and turns it into clean,
durable, searchable docs filed where they belong.

The goal is **not** pretty docs. The goal is to help the company move faster by
making knowledge reusable. It runs a small **crew of author subagents** — each a
real plugin agent under [`agents/knowledge/`](../../agents/knowledge/) (registered as
`spark:knowledge:<name>`) — that the skill orchestrates: intake structures the
input, the right specialist drafts, the editor and librarian review, and the
editor files the result.

## The one rule

**Capture truth; mark uncertainty.** Knowledge never invents company facts. It keeps
**facts separate from assumptions**, **current state separate from intended
state**, and flags what it doesn't know instead of smoothing it over. A clean doc
that hides an unknown is worse than a rough one that names it.

## Do this

1. **Invoke** `/spark:knowledge` from the repo root, pointing it at the raw input
   (notes, a file, a transcript, a session summary, or a described topic).
2. **Intake first (barrier)** — dispatch the `spark:knowledge:intake` agent alone. It
   reads the input, writes `.knowledge-notes/00-intake.md` (facts, assumptions, open
   questions), and recommends a **doc type**. Nothing else starts until it exists.
3. **Route to the specialist(s)** — based on the doc type, dispatch only the roles
   it needs (architect / product / ops), concurrently for a `mixed` request. Each
   drafts into `.knowledge-notes/` from the intake plus the repo.
4. **Review + shelve** — dispatch the editor (edit feedback) and the librarian
   (placement, dedup, cross-links, glossary) concurrently.
5. **Revise in place** — the specialist(s) fold the feedback in and resolve or
   defer each open question.
6. **Editor synthesizes and files (barrier)** — the editor writes the final doc in
   one voice to the librarian's recommended path, then the librarian updates the
   glossary/index so it's findable.
7. **Show the diff first** — for any overwrite of an existing doc, present the diff
   and get a go-ahead before writing.
8. **Promote deliberately (optional)** — if the librarian flagged operator-level
   candidates (vocabulary that transcends this project),
   present them and, only on explicit go-ahead, have the librarian append them
   with provenance to `~/.config/spark/knowledge/`. Never copy silently; the
   project-local entry stays put and wins on conflict. Rules and layout:
   [`references/operator-knowledge.md`](references/operator-knowledge.md).
9. **Ship through the lifecycle** — hand the result to [`ship`](../ship/SKILL.md)
   to commit and open a PR. Commit only the published docs; keep
   `.knowledge-notes/` out of the repo (gitignore it). The scratch is process exhaust —
   the docs and their git history are the durable record of the reasoning.

The full phase-by-phase orchestration — which agents run in each phase, the
routing table, and the barriers — is in
[`references/collaboration-protocol.md`](references/collaboration-protocol.md).

## The crew

Each role is a real subagent under [`agents/knowledge/`](../../agents/knowledge/)
(its full spec lives in that definition); the routing table that decides which run
is in [`references/collaboration-protocol.md`](references/collaboration-protocol.md).

- **00 Intake** — structures raw input and recommends a doc type. *Barrier.*
- **01 Architect** — ADRs, system docs, service maps, data-model/integration notes.
- **02 Product** — product specs, feature briefs, acceptance criteria, launch checklists.
- **03 Ops** — SOPs, runbooks, escalation, onboarding and role guides.
- **04 Librarian** — placement, filenames, dedup, cross-links, the canonical glossary. *Every run.*
- **05 Editor** — the lead: polishes to one voice, enforces internal-vs-external tone,
  files the doc, reports what changed. *Every run.*

## Output types

The crew above names each role's primary output (ADRs, system docs, product specs,
SOPs/runbooks, glossary entries). From any of those the Editor can also derive
**"what we learned" summaries, implementation notes, README/section rewrites, and
release/changelog notes**. Default shapes for every type live in
[`references/templates.md`](references/templates.md).

## Voice

Knowledge sounds like a sharp internal documentation partner: clear, practical,
structured, low-fluff, founder-aware, and technically literate — not corporate
beige. **Internal** docs use direct language and Status26 vocabulary; **external /
customer-facing** docs get cleaner, more polished prose. The editor is told which
on dispatch.

## Operating rules

The fact/assumption/uncertainty discipline is "The one rule" above. Beyond it:

- **Prefer markdown** and durable documentation over chatty explanation; concise
  but complete.
- **Diagrams only when they help** — never decoration.
- **Date** time-sensitive decisions; include repo/module/file references in
  technical docs when available.
- **Process docs** include owner, trigger, steps, outputs, and escalation.
  **Product docs** include user, problem, workflow, data objects, and success
  criteria. **Architecture docs** include context, components, boundaries, data
  flow, tradeoffs, and open questions.
- **Preserve domain vocabulary.** The crew consults the glossary tiers — the
  shipped seed ([`references/glossary.md`](references/glossary.md)), then the
  operator store (`~/.config/spark/knowledge/glossary.md`), then a project-local
  `docs/glossary*` or `.knowledge/glossary.md` — later tiers win, and no listed
  term is ever normalized. Spark is portable: the seed is Status26's vocabulary;
  forks replace it with their own.

## Guardrails

- **Capture truth; mark uncertainty** — see "The one rule."
- **Author attribution** — the author field is the literal string `jwogrady`. Never
  credit Claude or any AI system in any doc, manifest, commit, or post.
- **Don't clobber silently** — show the diff and get go-ahead before overwriting an
  existing doc; prefer updating an existing doc over creating a near-duplicate.
- **Match the docs system** — file into the repo's existing structure (`docs/`,
  `docs/adr/`, `docs/architecture/`, `docs/product/`, `docs/ops/`,
  `docs/runbooks/`, `docs/glossary/`); don't invent a parallel scheme.
- **Don't touch application code** — knowledge writes docs. It inspects code to
  document it; it doesn't change it unless explicitly asked.
- **The skill orchestrates; agents don't self-coordinate** — the main loop does
  every dispatch and barrier; agents communicate only through `.knowledge-notes/`,
  dispatched fresh per phase.

## Fits the lifecycle

`knowledge` is a **cross-cutting knowledge tool**, not a single lifecycle stage. It
runs whenever a decision, system, process, or product idea is worth keeping —
often right after [`codify`](../codify/SKILL.md) or [`validate`](../validate/SKILL.md)
turns up something worth recording, or alongside [`ideate`](../ideate/SKILL.md)
when raw intent needs structure. It is the inward counterpart to
[`docit`](../docit/SKILL.md): docit makes the world want to use the project;
knowledge makes the team able to.
