# Spark — AI Agent Guide

> This file is maintained using the Spark `agents-md` skill.
> See `skills/agents-md/SKILL.md` for authoring rules.

This guide applies to any AI coding agent working in this repo, regardless of tool.

## What This Repo Is

Spark is a Claude Code **plugin** — a portable, GitHub-native software-development
toolkit. It bundles lifecycle skills, enforcement hooks, and a `spark` CLI that
ship to every project where the plugin is installed. It is additive: it reuses
Claude Code's built-in tools rather than reinventing them.

## Core Rules

### Before You Start
- Read `CLAUDE.md` for full project context, standards, and guardrails.
- Check `CHANGELOG.md` to understand recent changes.
- Read the task or issue carefully. Clarify ambiguity before acting.

### Branch and PR Discipline
- Work on a feature branch. Never commit to `master` directly.
- Keep PRs focused on one concern.
- Do not open, close, or comment on issues or PRs without explicit instruction.

### Code Quality
- Scripts are POSIX-friendly Bash with `set -euo pipefail` and no runtime
  dependencies; degrade gracefully when `jq`/`python3` are missing.
- No commented-out code. No debug output left in.
- Before pushing: run `spark doctor` and `bash -n` on any changed script.

### Documentation
- Update `CHANGELOG.md` when behavior changes.
- Docs follow Diátaxis (`docs/{tutorials,how-to,reference,explanation}/`). Put
  new docs in the quadrant that matches their purpose.
- Write docs that explain *why*, not just *what*.

### Destructive Actions — Always Ask First
Never perform these without explicit user confirmation:
- Deleting files or directories
- Force-pushing or resetting git history
- Removing dependencies
- Dropping or modifying stored data
- Editing CI/CD pipelines

### Commits
- Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- Subject: imperative mood, under 72 characters, no trailing period.
- Credit belongs to the author only — use the literal string `jwogrady`. Never
  include AI tool names or self-credit in any commit message, PR, or file.
- The `commit-msg` git hook enforces these rules.

### GitHub API and Automation
- Do not call GitHub APIs without explicit user instruction.
- Do not create tags, releases, or deployments autonomously.
- Do not modify workflow files without understanding the full pipeline impact.

### Scope Discipline
- Do only what was asked. Do not refactor surrounding code opportunistically.
- Do not introduce dependencies not required by the task.
- Do not implement features not in scope for the current task.

## Skill Authoring Quick Reference

New skills go in `skills/<skill-name>/`. Scaffold with `spark new-skill <name>`.

```
skills/<name>/
├── SKILL.md       # required — frontmatter (name, description) + instructions
├── references/    # optional — long schemas, prompts, or examples
└── agents/        # optional — agent definitions
```

The `description` frontmatter is the only thing Claude sees when deciding whether
to invoke the skill. Name concrete triggers: "Use when …". Run `spark doctor` to
confirm the skill is well-formed before merging.
