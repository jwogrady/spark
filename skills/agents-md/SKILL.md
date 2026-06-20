---
name: agents-md
description: Create, maintain, audit, and sync a repo's AI-agent behavioral-contract files — AGENTS.md (any agent) and CLAUDE.md (Claude Code). Use when the user wants to write, update, audit, or drift-check AGENTS.md or CLAUDE.md. Defers net-new CLAUDE.md creation to native /init. Not for prose docs — use `docit` (public) or `knowledge` (internal); this owns the agent-contract files only.
---

# agents-md — the agent behavioral-contract skill

A repo speaks to its AI contributors through two files:

- **`CLAUDE.md`** — read by Claude Code specifically. Full project context: repo
  map, commands, workflow, and the doctrine Claude must follow.
- **`AGENTS.md`** — the tool-agnostic companion. The same behavioral contract,
  restated so *any* AI coding agent absorbs it regardless of vendor.

This skill owns **both**. They share one behavioral contract and must stay in
sync; when a rule changes in one, it is reviewed in the other.

## Division with native `/init`

Claude Code's native `/init` already *creates* a first `CLAUDE.md` by scanning a
repo. **Do not reimplement that.** This skill's jobs are the ones `/init` does not
do:

- **Author `AGENTS.md`** — `/init` only writes `CLAUDE.md`; the tool-agnostic file
  has no native generator.
- **Maintain & audit** both files — patch missing sections, refresh stale content,
  inject Spark's required doctrine (attribution, GitHub guardrails, agent safety).
- **Sync-check** the two for drift.

For a brand-new `CLAUDE.md`, run `/init` first, then this skill to enforce the
Spark sections and generate the matching `AGENTS.md`.

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

## Link the methodology, don't paste it

The Spark methodology — the lifecycle, the one-issue-per-branch rule, the
loop-closes principle — lives in Spark and is edited once. A project repo carries
only its own product: problem statement, decisions, glossary, plan. When a
contract file needs to say *how* the project is built, **link Spark's doctrine
instead of restating it.** Never generate a project-local copy of the process
(no `*-workflow.md`, `planning-overview.md`, or constitution restatement in the
project's `docs/`); that creates a second source of truth to maintain.

The leak runs deeper than whole files: even after the methodology files are
gone, Spark's process vocabulary survives in the *framing* of the docs that
remain. When maintaining or auditing a contract file, strip Spark-internal
process framing — `Phase N` / `Prompt NNN` status headers, `/spark:` stage
references, "deferred to later Spark stages." A status or scope line describes
the file's own authority, not the lifecycle stage that produced it.

The canonical pointer for a project's `CLAUDE.md` / `AGENTS.md`:

```markdown
## How this project is built

Built with the [Spark lifecycle](https://github.com/jwogrady/spark)
(`Ideate → Plan → Codify → Validate → Ship`). The process and standards live in
Spark; this repo carries only <project>'s problem, decisions, and plan.
```

## How the skill behaves

1. **Read both files first.** Never overwrite blindly.
2. **Defer creation of `CLAUDE.md` to `/init`;** this skill maintains and audits it.
3. **Derive `AGENTS.md` from `CLAUDE.md`** — restate, don't duplicate verbatim; it
   must read as a standalone document.
4. **Prefer real commands over placeholders.** Read the repo for actual scripts and
   entrypoints; add a TODO marker when a value can't be verified.
5. **Add missing sections; remove vague content carefully.** When uncertain, keep it.
6. **Flag drift, don't silently resolve it.** If the two files contradict, surface
   the conflict. `CLAUDE.md` is authoritative for Claude Code; `AGENTS.md` for all
   other agents; update them together.
7. **Keep both tight.** A short accurate contract beats a long one. Present a diff
   and get a go-ahead before overwriting an existing file.

## Outputs

Full file (new `AGENTS.md`, or a `/init`-seeded `CLAUDE.md` brought up to standard);
section patches; a sync audit (drift between the two); or a diff review for human
approval. Ask which is wanted if unspecified.

## Non-goals

- Does **not** reimplement `/init`'s `CLAUDE.md` creation — it defers to it.
- Does **not** run as an automated CLI command, or modify any file unless invoked.
- Does **not** define project-specific commands — those come from reading the repo.
