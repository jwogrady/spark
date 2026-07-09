# How to run a repo cleanup

> How-to — task-oriented.

Use this to purge what is proven dead or false: dead code, misleading docs,
stale branches, unused dependencies, old TODOs, and architecture fiction. For
assessing overall project health instead, use [`review`](review.md) — cleanup
removes, it doesn't grade.

## 1. Invoke the skill

```bash
/spark:cleanup
```

Describe what you want cleaned (stale branches, a docs truth audit, a full
hygiene pass, …). The skill does **not** run the cleanup itself — it produces
**one copy-paste-ready orchestrator prompt** in a single code block.

## 2. Run the orchestrator prompt

Paste the generated prompt into a fresh Claude (or other agentic) session. It
spins up a coordinated team — Orchestrator, Cartographer, Historian, Static
Analyst, Test Sentinel, Docs Auditor, Dead Code Reaper, Branch Janitor,
Dependency Medic, Release Steward — that inspects the actual repository before
asserting anything.

## 3. Review the evidence table

Every finding lands in a table:
`Area | Claim | Evidence | Confidence | Action | Risk | Validation`.
Each deletion proposal carries evidence and a confidence level (High / Medium /
Low), and every candidate is forced into a category:

- **Safe delete** — generated artifacts, merged branches, docs proven false.
- **Needs review** — old feature code, ambiguous branches, migrations, public APIs.
- **Do not delete** — default/protected/release branches, production config, secrets.

## 4. Approve the risky removals

A human approval gate precedes any remote-branch deletion or risky-code
deletion — nothing protected, default, or release-tagged is deleted
automatically. Risky removals are isolated in their own commits so each is
independently revertible.

## 5. Validate and land

Tests and builds run when available; the final report lists docs changed and
deleted, code deleted, branches recommended for deletion, risks, and validation
status. Land the result through the normal lifecycle (`validate`, then `ship`).

**Done when** every removal is backed by cited evidence, the docs claim no more
than the code proves, and the final report's validation status is green (or the
gaps are explained with a manual validation plan).
