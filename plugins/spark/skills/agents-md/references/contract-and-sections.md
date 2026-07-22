# The shared behavioral contract and required sections

> Reference for the `agents-md` skill. Consult it when authoring or auditing
> `CLAUDE.md` / `AGENTS.md` — it holds the doctrine both files must carry and the
> section layout each expects. Not loaded until the skill reaches that step.

## The shared behavioral contract

Both files carry these non-negotiable rules (restated in plain language for
`AGENTS.md`, in fuller context for `CLAUDE.md`):

- **Attribution.** Credit the human author only. No AI tool names, no
  `Co-Authored-By` lines for AI systems, in any commit, file, doc, or changelog.
- **Branch & PR discipline.** Never commit to `master`/`main` directly; feature
  branch → focused PR; one concern per PR.
- **Commits.** Conventional commits; imperative subject under 72 chars, no trailing
  period; body explains *why*.
- **Destructive actions need confirmation.** Deleting files, force-pushing or
  resetting history, removing dependencies, dropping data, editing CI.
- **GitHub boundary.** Read GitHub state freely; never open/close/comment on
  issues or PRs, create tags/releases, or edit workflows without explicit
  instruction.
- **Scope discipline.** Do only what was asked; no opportunistic refactors, no
  invented integrations or commands; mark unknowns with a TODO rather than guessing.

## Required sections

**`CLAUDE.md`** (rich, Claude-facing): Project Mission · Repository Purpose · Repo
Map · Common Commands · Development Workflow · Skill Authoring (Spark repos) ·
GitHub Integration Guardrails · Coding & Documentation Standards · Commit Rules ·
Attribution Rules · Destructive Change Rules · Agent Safety Rules.

**`AGENTS.md`** (scannable, tool-agnostic): What This Repo Is · Core Rules · Branch
and PR Discipline · Code Quality · Documentation · Destructive Actions · Commits ·
GitHub API and Automation · Scope Discipline · Skill Authoring Quick Reference.

Omit a section only when genuinely not applicable, and note why.
