---
name: audit
description: Audit a whole project directly in-session with a small dispatched crew, in one of two modes — assess produces an evidence-cited health report across documentation, architecture, code quality, testing/reliability, security/config, and product readiness; purge removes what is proven dead or false (stale code, untrue docs, stale branches, unused dependencies) behind a human approval gate. Use when preparing for a release or external review, assessing overall project health, or purging dead code, doc drift, and stale branches. Not for a single diff or PR — use the native /code-review and /security-review, or `validate` to orchestrate them on one branch.
---

# audit — whole-project assessment and purge

`audit` inspects the **whole project** — never a single diff — and acts
directly in this session. No copy-paste prompts, no external orchestrator: the
skill dispatches its own subagent roles and delivers the result here.

Two modes:

- **assess** — an evidence-based health report across six dimensions
  (documentation, architecture, code quality, testing/reliability,
  security/config, product readiness), scored 1–10, harsh but fair.
- **purge** — remove what is proven dead or false: dead code, misleading docs,
  stale branches, unused dependencies, old TODOs, architecture fiction. Every
  removal is evidence-backed, categorized for safety, and gated on human
  approval before anything risky happens.

If the user's intent is ambiguous, ask which mode they want. "How healthy is
this?" is assess; "get rid of what's dead/false" is purge.

## Do this

1. **Pick the mode** from the user's request (or ask).
2. **Create the scratch dir** — `mkdir -p .audit-notes/` at the repo root. It
   is gitignored process exhaust: never committed, regenerated per run.
3. **Dispatch the Mapper first (barrier)** — one subagent maps structure,
   toolchain, entry points, generated/vendor paths, and the branch inventory
   into `.audit-notes/00-map.md`. Nothing else starts until it exists.
4. **Dispatch the mode's roles** (briefs below and in `references/`), each
   reading the prior notes and writing its own file in `.audit-notes/`.
5. **Dispatch the Synthesis Lead (barrier)** — it reads every note and writes
   the deliverable: the consolidated report (assess) or the categorized
   deletion slate (purge).
6. **Assess ends here** — present the report; file the critical risks and top
   actions as GitHub issues (paste the evidence in — paths, line numbers;
   links into `.audit-notes/` won't survive).
7. **Purge ends at the approval gate** — present the slate, get explicit
   approval, then apply only the approved removals in small isolated commits,
   validating (tests/build/doctor when available) after each group. Land the
   result through `validate` and `ship`.

## The roles (at most 5 per run)

- **00 Mapper** — repo intake. Structure, stack, entry points,
  generated/vendor/build paths, branch inventory. *Barrier; both modes.*
- **01 Health Assessor** — documentation, architecture, code quality. *Assess.*
- **02 Reliability Assessor** — testing/reliability, security/config, product
  readiness. *Assess.*
- **03 Evidence Gatherer** — dead code, doc truth, branches, dependencies;
  every finding is one evidence-table row. *Purge.*
- **04 Synthesis Lead** — consolidates the notes into the final report or the
  categorized deletion slate. *Barrier; both modes.*

Full briefs: [`references/assess-brief.md`](references/assess-brief.md) (the
six dimensions, scoring, report format) and
[`references/purge-protocol.md`](references/purge-protocol.md) (evidence
table, deletion-safety categories, branch and docs-truth protocols).

## The evidence contract

Every claim — in either mode — cites a file path, a command with its output,
or git evidence. Purge findings go in one table:

`Area | Claim | Evidence (command or path) | Confidence | Action | Risk | Validation`

Confidence is **High** (proven by code references, command output, or git
evidence), **Medium** (static analysis, not runtime-proven), or **Low**
(hypothesis needing human review). Every deletion candidate is forced into
**safe delete**, **needs review**, or **do not delete** — the categories are
defined in [`references/purge-protocol.md`](references/purge-protocol.md).

## Guardrails

- **Evidence required** — no vague claims; distinguish facts from hypotheses.
- **Human approval gate** — nothing risky is removed, and no remote branch is
  deleted, without explicit user approval. Protected, default, and release
  branches are never deleted automatically.
- **Risky removals are isolated** — each in its own commit, independently
  revertible.
- **Secrets are never printed.** Generated/vendor artifacts are identified
  before any cleanup.
- **The skill orchestrates; roles don't self-coordinate** — the main loop does
  every dispatch and barrier; roles communicate only through `.audit-notes/`.
- **No AI attribution** — all notes and reports are authored by `jwogrady`.
  Never credit Claude or any AI system.

## Fits the lifecycle

`audit` is a cross-cutting supporting skill. Assess runs as a pre-release
quality gate or milestone checkpoint; purge runs when a repo has accumulated
drift. Both hand durable outcomes to the lifecycle: issues for findings,
`validate` + `ship` for removals.
