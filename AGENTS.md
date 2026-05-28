# Spark — AI Agent Guide

This guide applies to any AI coding agent working in this repo, regardless of tool.

## What This Repo Is

Spark is an AI-native project operations framework. It provides reusable skills,
documentation templates, structured prompts, and GitHub automation. It is not a
runtime application. Do not treat it as one.

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
- All Python must pass `ruff` (no warnings) and `black --check` before commit.
- All tests must pass (`pytest`) before commit.
- Type hints are required on public functions. Docstrings are required.
- No commented-out code. No debug `print()` statements.

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

New skills go in `.spark/skills/<skill-name>/`. Scaffold with:

```
bash scripts/new-skill.sh <name>
```

Required files per skill: `skill.md`, `README.md`.
Skills must be self-contained and tested against a real project before merge.
