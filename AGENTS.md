# Spark — AI Agent Guide

> This file is maintained using the Spark `agents-md` skill.
> See `.spark/skills/agents-md/SKILL.md` for authoring rules.

This guide applies to any AI coding agent working in this repo, regardless of tool.

## What This Repo Is

Spark is a portable AI skills and agent configuration layer. It provides reusable
skills, documentation templates, structured prompts, and GitHub-ready templates
and issue drafts. It is not a runtime application. Do not treat it as one.
Runtime automation is not yet implemented.

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
- No commented-out code. No debug `print()` statements in library code.
- Type hints are required on public functions. Docstrings are required.
- Before committing, run the project's quality gates. Commands are not yet
  confirmed — check `CLAUDE.md` for the current list, or add a TODO marker:

  ```bash
  # TODO: confirm linter command once pyproject.toml is set up
  # TODO: confirm formatter command once pyproject.toml is set up
  # TODO: confirm test command once test suite exists
  ```

### Documentation
- Update `CHANGELOG.md` when behavior changes.
- Keep skill `README.md` files current with their implementation.
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
- Subject: imperative mood, under 72 characters.
- Do not include AI tool names or self-credits in any commit message or file.
- Credit belongs to the human author only.

### GitHub API and Automation
- Do not call GitHub APIs without explicit user instruction.
- Do not create tags, releases, or deployments autonomously.
- Do not modify workflow files without understanding the full pipeline impact.

### Scope Discipline
- Do only what was asked. Do not refactor surrounding code opportunistically.
- Do not introduce dependencies not required by the task.
- Do not implement features not in scope for the current task.

## Skill Authoring Quick Reference

New skills go in `.spark/skills/<skill-name>/`. Required files:

```
.spark/skills/<name>/
├── SKILL.md              # required — skill instructions and behavior rules
├── agents/openai.yaml    # required — agent definition and schema
├── README.md             # recommended — usage summary and source attribution
└── references/           # optional — long schemas, prompts, or examples
```

Scaffold script: `bash scripts/new-skill.sh <name>`
(TODO: script not yet implemented — create the directory structure manually.)

Skills must not implement runtime automation unless runtime is explicitly in
scope. Document-only skills are the standard at this stage.
