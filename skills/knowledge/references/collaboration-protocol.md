# knowledge — collaboration protocol

How the crew runs as **real subagents** and how the skill orchestrates them. Each
role is a plugin agent under [`agents/knowledge/`](../../../agents/knowledge/)
(registered as `spark:knowledge:<name>`). It borrows `docit`'s shared-notes mechanism
but is **routed, not fixed**: intake classifies the input, the orchestrator
dispatches only the specialists that doc type needs, and the editor synthesizes.

---

## Who orchestrates

**The skill — the main loop — is the sole orchestrator.** A subagent cannot spawn
another subagent, so every dispatch and every barrier is the main loop's job. The
agents never call each other; they coordinate only through shared notes in
`.knowledge-notes/`. A role is **dispatched fresh once per phase it takes part in** —
the agent definition under `agents/knowledge/` holds the durable identity; the
orchestrator's per-dispatch brief names the phase and (for the editor) whether the
doc is internal or external.

---

## The roles

```
00 intake      → reads raw input, writes the fact base. Barrier. Read by everyone.
01 architect   → ADRs, system docs, service maps, data-model/integration notes.
02 product     → product specs, feature briefs, user stories, acceptance criteria.
03 ops         → SOPs, checklists, runbooks, escalation/onboarding/role guides.
04 librarian   → placement, filenames, dedup, cross-links, glossary upkeep.
05 editor      → polish, internal-vs-external voice, files the doc, reports.   (lead)
```

01/02/03 are the **specialists** — only the ones the intake's doc type calls for
are dispatched. 04 and 05 run on every request.

---

## Request routing

When knowledge receives a request, classify it (this is the intake's job, confirmed
by the orchestrator) as one or more of:

| Doc type           | Specialist(s)        | Template                     |
|--------------------|----------------------|------------------------------|
| `adr`              | architect            | Decision Record              |
| `system-doc`       | architect            | Technical System Doc         |
| `product-spec`     | product              | Product Spec                 |
| `sop` / `runbook`  | ops                  | SOP / Process Doc            |
| `onboarding`/`role`| ops                  | SOP / Process Doc            |
| `glossary`         | librarian            | Glossary entry               |
| `mixed`            | two or more, parallel| one per slice                |

For `mixed`, the intake names each slice and the doc type it maps to; the
orchestrator dispatches those specialists **concurrently** in Phase 1.

---

## The phases — what the orchestrator dispatches

```
Phase 0 — Intake (barrier)
  Dispatch ONE agent: spark:knowledge:intake.
  It writes .knowledge-notes/00-intake.md alone, ending with a Recommended Doc Type.
  Wait for it. Nothing else starts until this exists.
        ↓ .knowledge-notes/00-intake.md

Phase 1 — Draft (route)
  Read the Recommended Doc Type. Dispatch ONLY the specialist(s) it names —
  architect and/or product and/or ops — CONCURRENTLY when more than one. Each
  reads the intake and drafts into .knowledge-notes/ using its template. Wait for all.
        ↓ .knowledge-notes/architecture.md | product.md | ops.md

Phase 2 — Review + shelve (parallel)
  Dispatch spark:knowledge:editor (edit feedback on each draft) and
  spark:knowledge:librarian (placement, dedup, cross-links, glossary) CONCURRENTLY.
  Wait for both.
        ↓ feedback appended to drafts; .knowledge-notes/librarian.md

Phase 3 — Revise in place (parallel)
  Re-dispatch the Phase 1 specialist(s) with a "revise" brief; each folds in the
  editor/librarian feedback and resolves or defers its open questions. Re-dispatch
  intake only if a contradiction with the fact base surfaced. Wait for all.

Phase 4 — Synthesize + file (barrier)
  Dispatch ONE agent: spark:knowledge:editor. It reads every revised note and the
  librarian's recommendation, writes the final doc in one voice to the recommended
  path, and writes .knowledge-notes/editor-log.md. Before any overwrite, the
  orchestrator shows the user a diff and gets go-ahead. Then re-dispatch
  spark:knowledge:librarian to update the glossary / index so the doc is findable.
        ↓ the final doc in docs/…, .knowledge-notes/editor-log.md
```

Small requests collapse cleanly: a one-paragraph SOP is intake → ops → editor,
skipping nothing essential but never spinning up architect or product.

---

## Shared notes structure

Each role writes one markdown file to `.knowledge-notes/`. Use consistent sections so
the editor can cross-reference and specialists can absorb feedback.

- **Source** — what input this note draws on (links/citations).
- **Draft** — the doc content this role owns.
- **Facts vs assumptions** — kept separate, per the one rule.
- **Open questions** — unresolved/contradictory items.
- **Feedback** — left by the editor/librarian in Phase 2; the owner resolves each
  in Phase 3 and marks it done.

`00-intake.md` follows the Intake Summary template instead.

---

## The one rule

**Capture truth; mark uncertainty.** Knowledge never invents company facts. Every
role keeps facts separate from assumptions, separates current state from intended
state, and flags what it doesn't know rather than smoothing it over. A clean doc
that hides an unknown is worse than a slightly rough one that names it.

---

## Output and handoff

- Final docs land in the repo (`docs/…`), not in `.knowledge-notes/`.
- The editor presents a diff and waits for go-ahead before overwriting an existing
  doc.
- Archive `.knowledge-notes/` (commit it) so the reasoning — intake, drafts,
  feedback, the editor log — is recoverable and the next capture builds on it.
- Hand the change to [`commit`](../../commit/SKILL.md) and
  [`ship`](../../ship/SKILL.md) to land it through the lifecycle.
