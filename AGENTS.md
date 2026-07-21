# Spark — AI Agent Guide

> This file is maintained using the Spark `agents-md` skill.
> See `plugins/spark/skills/agents-md/SKILL.md` for authoring rules.

This guide applies to any AI coding agent working in this repo, regardless of tool.

## What This Repo Is

Spark turns an AI coding assistant and GitHub into a software delivery system:
your engineering standards loaded once, one traceable lifecycle
(Ideate → Plan → Codify → Validate → Ship), durable GitHub artifacts, and
mechanically enforced guardrails. This repo is a plugin marketplace: a focused
core plugin (`plugins/spark/` — 8 skills, enforcement hooks, and a `spark` CLI)
plus three companion plugins (`plugins/spark-audit/` for whole-project
assessment and cleanup, `plugins/spark-connect/` for services and secrets,
`plugins/spark-docs/` for public docs and positioning). It is additive: it
reuses the host tool's built-in capabilities rather than reinventing them.

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
- Before pushing: run `spark doctor`, `bash -n` on any changed script, and
  `tests/run.sh` when enforcement hooks or other tested scripts changed.

### Documentation
- Update `CHANGELOG.md` when behavior changes.
- Docs follow Diátaxis. User-facing docs ship with the core plugin under
  `plugins/spark/docs/{tutorials,how-to,reference,explanation}/`; each companion
  plugin ships its own docs under `plugins/<name>/docs/`; developer docs
  (ADRs, architecture, packaging) stay in the root `docs/`. Put new docs in the
  surface and quadrant that match their purpose.
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
- Do not create tags, releases, or deployments autonomously. (Where Release
  Please is configured — config file or workflow — the PreToolUse guard
  blocks hand-cut tags and Releases; the release act is a human merging the
  Release Please release PR.)
- Workflows exist under `.github/workflows/` (`validate.yml` runs the health
  gate; `release-please.yml` manages releases). Do not modify them without
  understanding the full pipeline impact.

### Scope Discipline
- Do only what was asked. Do not refactor surrounding code opportunistically.
- Do not introduce dependencies not required by the task.
- Do not implement features not in scope for the current task.

## Skill Authoring Quick Reference

New skills go in `plugins/spark/skills/<skill-name>/`. Scaffold with `spark new-skill <name>`.

```
plugins/spark/skills/<name>/
├── SKILL.md       # required — frontmatter (name, description) + instructions
├── references/    # optional — long schemas, prompts, or examples
└── agents/        # optional — agent definitions
```

The `description` frontmatter is the only thing Claude sees when deciding whether
to invoke the skill. Name concrete triggers: "Use when …". Run `spark doctor` to
confirm the skill is well-formed before merging.
