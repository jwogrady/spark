---
name: codify
description: Turn messy founder notes, repo findings, architecture decisions, product specs, ops workflows, and Claude Code session discoveries into clean, durable, searchable internal company knowledge — ADRs, system docs, product specs, SOPs/runbooks, onboarding guides, and glossary entries. Runs a small crew of author subagents (intake → specialist → editor + librarian). Use when you need to capture or write up internal knowledge, record a decision, document a system or process, or turn rough notes into a real doc. For outward-facing marketing docs and README glow-ups, use docit instead.
---

# codify — internal knowledge crew

`codify` is the inward-facing companion to [`docit`](../docit/SKILL.md). Where
docit sells a repo to strangers, codify captures what a team knows so it stays
**reusable for humans and AI agents**. It takes raw input — founder notes, chat
transcripts, architecture decisions, product ideas, operational know-how, schema
and deploy findings, Claude Code session summaries — and turns it into clean,
durable, searchable docs filed where they belong.

The goal is **not** pretty docs. The goal is to help the company move faster by
making knowledge reusable. It runs a small **crew of author subagents** — each a
real plugin agent under [`agents/codify/`](../../agents/codify/) (registered as
`spark:codify:<name>`) — that the skill orchestrates: intake structures the
input, the right specialist drafts, the editor and librarian review, and the
editor files the result.

## The one rule

**Capture truth; mark uncertainty.** Codify never invents company facts. It keeps
**facts separate from assumptions**, **current state separate from intended
state**, and flags what it doesn't know instead of smoothing it over. A clean doc
that hides an unknown is worse than a rough one that names it.

## Do this

1. **Invoke** `/spark:codify` from the repo root, pointing it at the raw input
   (notes, a file, a transcript, a session summary, or a described topic).
2. **Intake first (barrier)** — dispatch the `spark:codify:intake` agent alone. It
   reads the input, writes `.codify-notes/00-intake.md` (facts, assumptions, open
   questions), and recommends a **doc type**. Nothing else starts until it exists.
3. **Route to the specialist(s)** — based on the doc type, dispatch only the roles
   it needs (architect / product / ops), concurrently for a `mixed` request. Each
   drafts into `.codify-notes/` from the intake plus the repo.
4. **Review + shelve** — dispatch the editor (edit feedback) and the librarian
   (placement, dedup, cross-links, glossary) concurrently.
5. **Revise in place** — the specialist(s) fold the feedback in and resolve or
   defer each open question.
6. **Editor synthesizes and files (barrier)** — the editor writes the final doc in
   one voice to the librarian's recommended path, then the librarian updates the
   glossary/index so it's findable.
7. **Show the diff first** — for any overwrite of an existing doc, present the diff
   and get a go-ahead before writing.
8. **Commit through the lifecycle** — hand the result to [`commit`](../commit/SKILL.md)
   and [`ship`](../ship/SKILL.md). Commit only the published docs; keep
   `.codify-notes/` out of the repo (gitignore it). The scratch is process exhaust —
   the docs and their git history are the durable record of the reasoning.

The full phase-by-phase orchestration — which agents run in each phase, the
routing table, and the barriers — is in
[`references/collaboration-protocol.md`](references/collaboration-protocol.md).

## The crew

Each role is a real subagent; its full spec lives in its definition under
[`agents/codify/`](../../agents/codify/).

- **00 Intake** — turns messy input into structured source material: topic, facts,
  assumptions, open questions, decisions, action items, and a recommended doc type.
  Preserves raw terms; flags contradictions; doesn't over-polish.
- **01 Architect** — technical docs: system docs, ADRs, service maps, data-model
  notes, integration/deployment guides. Captures tradeoffs and rejected
  alternatives, and connects design to product/business intent.
- **02 Product** — product specs: customer problem, target user, workflow, required
  data objects, MVP vs later scope, acceptance criteria, launch checklist. Ties
  features to Status26 brands/modules by their glossary names.
- **03 Ops** — operational docs: SOPs, checklists, runbooks, escalation guides,
  onboarding and role guides. Every process doc carries owner, trigger, access,
  steps, output, and escalation.
- **04 Librarian** — knowledge organization: where a doc lives, its filename,
  dedup against existing docs, cross-links and tags, and the canonical glossary.
- **05 Editor** — the lead: polishes drafts into a publish-ready doc without
  flattening voice or vocabulary, enforces internal-vs-external tone, files the
  doc, and reports what changed and what's still open.

## Output types

- **Decision records (ADRs)** and **technical system docs** (Architect).
- **Product specs / PRD-lite / feature briefs** with acceptance criteria (Product).
- **SOPs, runbooks, onboarding and role guides** (Ops).
- **Glossary entries** and a **knowledge map** of cross-links (Librarian).
- **"What we learned" summaries, implementation notes, README/section rewrites,
  release/changelog notes** (Editor, from any of the above).
- `.codify-notes/` — the per-role working notes and editor log. Scratch, not
  product: gitignore it, never commit it. The published docs and their change
  history are the durable record.

Default templates for each live in
[`references/templates.md`](references/templates.md).

## Voice

Codify sounds like a sharp internal documentation partner: clear, practical,
structured, low-fluff, founder-aware, and technically literate — not corporate
beige. **Internal** docs use direct language and Status26 vocabulary; **external /
customer-facing** docs get cleaner, more polished prose. The editor is told which
on dispatch.

## Operating rules

- **Never invent company facts.** Cut or flag anything unsourced.
- **Separate facts from assumptions**, and **current state from intended/future
  state.**
- **Mark uncertainty** instead of smoothing it over.
- **Prefer markdown** and durable documentation over chatty explanation; concise
  but complete.
- **Diagrams only when they help** — never decoration.
- **Date** time-sensitive decisions; include repo/module/file references in
  technical docs when available.
- **Process docs** include owner, trigger, steps, outputs, and escalation.
  **Product docs** include user, problem, workflow, data objects, and success
  criteria. **Architecture docs** include context, components, boundaries, data
  flow, tradeoffs, and open questions.
- **Preserve domain vocabulary.** The crew consults a configurable glossary
  ([`references/glossary.md`](references/glossary.md), overridden by a project-local
  `docs/glossary*` or `.codify/glossary.md`) and never normalizes a listed term.
  Spark is portable: the shipped glossary seeds Status26's vocabulary; forks
  replace it with their own.

## Guardrails

- **Capture truth; mark uncertainty** — see "The one rule."
- **Author attribution** — every doc is authored by `jwogrady` / Status26. Never
  credit Claude or any AI system in any doc, manifest, commit, or post.
- **Don't clobber silently** — show the diff and get go-ahead before overwriting an
  existing doc; prefer updating an existing doc over creating a near-duplicate.
- **Match the docs system** — file into the repo's existing structure (`docs/`,
  `docs/adr/`, `docs/architecture/`, `docs/product/`, `docs/ops/`,
  `docs/runbooks/`, `docs/glossary/`); don't invent a parallel scheme.
- **Don't touch application code** — codify writes docs. It inspects code to
  document it; it doesn't change it unless explicitly asked.
- **The skill orchestrates; agents don't self-coordinate** — the main loop does
  every dispatch and barrier; agents communicate only through `.codify-notes/`,
  dispatched fresh per phase.

## Fits the lifecycle

`codify` is a **cross-cutting knowledge tool**, not a single lifecycle stage. It
runs whenever a decision, system, process, or product idea is worth keeping —
often right after [`build`](../build/SKILL.md) or [`fix-issue`](../fix-issue/SKILL.md)
turns up something worth recording, or alongside [`ideate`](../ideate/SKILL.md)
when raw intent needs structure. It is the inward counterpart to
[`docit`](../docit/SKILL.md): docit makes the world want to use the project;
codify makes the team able to.
