# knowledge — collaboration protocol

How the three-role crew runs. Each role is a real plugin agent under
[`agents/knowledge/`](../../../agents/knowledge/) (registered as
`spark:knowledge:<name>`). The skill — the main loop — is the sole orchestrator:
a subagent cannot spawn another, so every dispatch and barrier is the main
loop's job. Agents coordinate only through shared notes in `.knowledge-notes/`
(gitignored scratch, never committed), each dispatched fresh per phase with a
brief naming the phase and, for the librarian-editor, whether the doc is
internal or external.

## The roles

```
00 intake            → reads raw input, writes the fact base, names the doc type. Barrier.
01 author            → drafts per doc type: ADR / system doc / product spec / SOP-runbook.
02 librarian-editor  → placement, dedup, cross-links, glossary; final synthesis + filing. (lead)
```

The doc type (`adr | system-doc | product-spec | sop | runbook | onboarding |
glossary | mixed`) selects the author's template from
[`templates.md`](templates.md). There is no routing table anymore — one author
handles every type; a `mixed` request means the author drafts each slice under
its own template.

## The phases

```
Phase 0 — Intake (barrier)
  Dispatch spark:knowledge:intake alone. It writes .knowledge-notes/00-intake.md,
  ending with a Recommended Doc Type. Nothing else starts until it exists.

Phase 1 — Draft
  Dispatch spark:knowledge:author. It reads the intake and drafts into
  .knowledge-notes/ with the template its doc type calls for — one note per
  slice when the type is mixed.

Phase 2 — Review + shelve
  Dispatch spark:knowledge:librarian-editor. It appends feedback to each draft
  and writes .knowledge-notes/librarian.md: placement, filename, duplicates,
  cross-links, glossary changes, and promotion candidates (or "none").

Phase 3 — Revise
  Re-dispatch spark:knowledge:author with a "revise" brief; it folds the
  feedback in and resolves or defers each open question. Re-dispatch intake
  only if a draft contradicted the fact base.

Phase 4 — Synthesize + file (barrier)
  Dispatch spark:knowledge:librarian-editor. It writes the final doc in one
  voice to the recommended path — the orchestrator shows the user a diff and
  gets go-ahead before any overwrite — updates the glossary/index so the doc
  is findable, appends any explicitly user-approved promotion candidates to
  the operator store with provenance (operator-knowledge.md), and writes
  .knowledge-notes/editor-log.md.
```

## Shared notes

Each note in `.knowledge-notes/` uses consistent sections — **Source**,
**Draft**, **Facts vs assumptions**, **Open questions**, **Feedback** (left in
Phase 2, resolved in Phase 3) — except `00-intake.md`, which follows the Intake
Summary template. Final docs land in the repo (`docs/…`); the scratch holds the
run's reasoning, and the published docs plus git history are the durable record.
Hand the change to [`ship`](../../ship/SKILL.md) to commit and open a PR.
