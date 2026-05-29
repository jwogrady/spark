---
name: agents-md
description: Generate and maintain AGENTS.md for Spark-managed project repos. Use when user wants to create, update, audit, or sync-check an AGENTS.md file.
---

# agents-md

**Feature ID:** FEAT-SPARK-AGENTS-MD-001
**Namespace:** spark.skills.agents-md
**Bounded Context:** Spark AI agent workspace
**Status:** Draft — documents skill behavior; runtime generation not yet implemented

---

## Purpose

`agents-md` generates and maintains `AGENTS.md` files for Spark-managed projects.
`AGENTS.md` is the tool-agnostic companion to `CLAUDE.md`. Where `CLAUDE.md` is
read by Claude Code specifically, `AGENTS.md` targets any AI coding agent —
regardless of vendor or tool — and establishes the same behavioral contract in a
format no tool can ignore.

Both files should stay in sync. When the rules change in one, they should be
reviewed in the other.

See also: [`claude-md`](../claude-md/SKILL.md)

---

## When to Create AGENTS.md

Create `AGENTS.md` when:

- Initializing a new project with `spark init`
- Onboarding a repo where AI agents from multiple tools may contribute
- A repo already has `CLAUDE.md` and needs a tool-agnostic counterpart

Place `AGENTS.md` at the repo root alongside `CLAUDE.md`. There should be
exactly one per repo.

## When to Update AGENTS.md

Update `AGENTS.md` when:

- `CLAUDE.md` is updated and the change applies to all agents
- New behavioral rules are established for AI contributors
- Workflow, branch, or commit conventions change
- A rule is added or removed from attribution, safety, or GitHub guardrails

Keep `AGENTS.md` and `CLAUDE.md` in sync. If a rule appears in one and not
the other, it will be inconsistently enforced depending on which tool is
running.

---

## Required Sections

Every `AGENTS.md` must include the following sections, in this order:

| Section | Purpose |
|---|---|
| **What This Repo Is** | One-paragraph description of the project and repo purpose |
| **Core Rules** | The non-negotiable behavioral rules every agent must follow |
| **Branch and PR Discipline** | Branch strategy, PR rules, GitHub write boundaries |
| **Code Quality** | Formatter, linter, test requirements before commit |
| **Documentation** | How to keep docs current; when to update `CHANGELOG.md` |
| **Destructive Actions** | What always requires explicit user confirmation |
| **Commits** | Format, size, mood, and attribution rules |
| **GitHub API and Automation** | What agents may not do autonomously |
| **Scope Discipline** | Stay in scope; no opportunistic refactors or extras |
| **Skill Authoring Quick Reference** | Spark repos only; how to scaffold a new skill |

Sections may be omitted only when genuinely not applicable. Mark intentional
omissions with a brief note.

---

## Section Content Rules

### What This Repo Is
One paragraph. Plain English. State what the project is and what this specific
repo does. Do not use marketing language. Do not duplicate the mission statement
from `CLAUDE.md` word for word — restate it more briefly for a reader who may
be skimming.

### Core Rules
A short, scannable list of the rules that govern all AI agent behavior in the
repo. These are the rules an agent must apply even if it reads nothing else.
Include:
- Branch discipline (never commit to master directly)
- PR requirements
- Quality gates (formatter, linter, tests) before committing
- Documentation update requirements

### Branch and PR Discipline
State the branch naming convention, PR flow, and what agents may and may not do
with GitHub. Be explicit about the write boundary: agents may read GitHub state
but not write to it without explicit instruction.

### Code Quality
State the actual commands. Use the repo's package manager. If commands are
unknown, add a TODO marker:

```bash
# TODO: verify test command before using
uv run pytest
```

Do not invent commands. Do not copy commands from other projects without
verifying they apply here.

### Documentation
State when `CHANGELOG.md` must be updated. State how skill `README.md` files
should be kept current. Direct the agent to keep documentation close to the
code it describes.

### Destructive Actions
Apply this in every `AGENTS.md`:

> Never perform these without explicit user confirmation:
> - Deleting files or directories
> - Force-pushing or resetting git history
> - Removing dependencies
> - Dropping or modifying stored data
> - Editing CI/CD pipelines

### Commits
Apply these in every `AGENTS.md`:

- Commit format: conventional commits (`feat:`, `fix:`, `docs:`, `chore:`,
  `refactor:`, `test:`) unless the repo explicitly says otherwise
- Subject line: imperative mood, under 72 characters, no trailing period
- Do not include AI tool names or self-credits in any commit message or file
- Do not add `Co-Authored-By` lines for AI systems
- Credit belongs to the human author only

### GitHub API and Automation
Apply these in every `AGENTS.md`:

- Do not call GitHub APIs without explicit user instruction
- Do not create tags, releases, or deployments autonomously
- Do not modify workflow files without understanding the full pipeline impact
- Do not open, close, or comment on issues or PRs without explicit instruction

### Scope Discipline
Apply these in every `AGENTS.md`:

- Do only what was asked
- Do not refactor surrounding code opportunistically
- Do not introduce dependencies not required by the task
- Do not implement features not in scope
- Do not invent integrations, commands, or tool names that do not exist in the repo
- If a command or value is unknown, add a TODO marker

### Skill Authoring Quick Reference
For Spark repos, include the scaffold command and the required files per skill.
Keep this brief — the full rules live in `CLAUDE.md` and the `claude-md` skill.

---

## Behavior Rules for the Skill Itself

When the `agents-md` skill runs against a repo:

1. **Read both files first.** Read the existing `AGENTS.md` and `CLAUDE.md`
   before generating or modifying anything.
2. **Derive from CLAUDE.md.** Most rules in `AGENTS.md` should mirror
   `CLAUDE.md`. Pull the current rules from there rather than inventing them.
3. **Restate, don't duplicate verbatim.** `AGENTS.md` should be readable as a
   standalone document. Restate rules in plain language suitable for any agent.
4. **Preserve useful content.** Repo-specific guidance already in `AGENTS.md`
   should be kept unless it is wrong or duplicated.
5. **Add missing sections.** If a required section is absent, add it.
6. **Flag drift.** If `AGENTS.md` and `CLAUDE.md` contradict each other, surface
   the conflict rather than silently resolving it.
7. **Keep it short.** `AGENTS.md` should be scannable. An agent skimming it in
   seconds should still absorb the core rules. Cut filler.

---

## Relationship to claude-md

| | `CLAUDE.md` | `AGENTS.md` |
|---|---|---|
| **Primary reader** | Claude Code | Any AI agent |
| **Format** | Rich markdown, Claude-specific guidance | Plain markdown, tool-agnostic |
| **Depth** | Full project context, repo map, commands | Core rules, behavioral contract |
| **Maintained by** | `claude-md` skill | `agents-md` skill |
| **Sync requirement** | — | Must stay in sync with `CLAUDE.md` |

When rules diverge between the two files, `CLAUDE.md` is authoritative for
Claude Code behavior. `AGENTS.md` is authoritative for all other agents. Both
should be updated together.

---

## Outputs This Skill Can Produce

| Output Type | When to Use |
|---|---|
| **Full AGENTS.md** | New repo with no existing `AGENTS.md` |
| **Section patches** | Existing `AGENTS.md` missing specific sections |
| **Sync audit** | Compare `AGENTS.md` against `CLAUDE.md` to find drift |
| **Diff review** | Proposed `AGENTS.md` changes for human review before applying |

Ask the user which output they want if not specified.

---

## Non-Goals

- This skill does not implement `AGENTS.md` generation as an automated CLI command.
- This skill does not modify any file without being explicitly invoked.
- This skill does not manage `CLAUDE.md` (covered by the `claude-md` skill).
- This skill does not enforce tool-specific agent settings beyond `AGENTS.md` content.
