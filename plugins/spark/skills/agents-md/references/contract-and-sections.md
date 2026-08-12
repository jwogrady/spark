# The behavioral contract and required sections

> Reference for the `agents-md` skill. Consult it when authoring or auditing
> the agent contract — the canonical `AGENTS.md` body and its `CLAUDE.md`
> pointer stub. Not loaded until the skill reaches that step.

## The behavioral contract

The canonical body carries these non-negotiable rules:

- **Attribution.** Credit the human author only. No AI tool names, no
  `Co-Authored-By` lines for AI systems, in any commit, file, doc, or changelog.
- **Branch & PR discipline.** Never commit to `master`/`main` directly; feature
  branch → focused PR; one concern per PR.
- **Commits.** Conventional commits; imperative subject under 72 chars, no trailing
  period; body explains *why*; commit each coherent problem → solution step —
  a branch's history tells the implementation story.
- **Destructive actions need confirmation.** Deleting files, force-pushing or
  resetting history, removing dependencies, dropping data, editing CI.
- **GitHub boundary.** Read GitHub state freely; never open/close/comment on
  issues or PRs, create tags/releases, change repository settings, or edit
  workflows without explicit instruction.
- **Scope discipline.** Do only what was asked; no opportunistic refactors, no
  invented integrations or commands; mark unknowns with a TODO rather than guessing.

## Required sections

**`AGENTS.md`** (the canonical body, tool-agnostic): Mission / What This Repo
Is · Repo Map · Common Commands · Development Workflow · Delivery Model ·
Coding & Documentation Standards · Commit Rules · GitHub Integration
Guardrails · Destructive Changes · Scope Discipline · Attribution — plus
Skill Authoring in Spark-plugin repos.

**`CLAUDE.md`** (the pointer stub): the line `@AGENTS.md`, a note naming
`AGENTS.md` as the canonical body, and — only when genuinely tool-specific —
Claude-only notes below the import.

Omit a section only when genuinely not applicable, and note why.
