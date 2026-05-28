# Spark — Claude Code Guide

> This file is maintained using the Spark `claude-md` skill.
> See `.spark/skills/claude-md/SKILL.md` for authoring rules.

## Mission

Spark is a portable AI skills and agent configuration layer. Skills, prompts,
and agent configs travel from project to project. You fork Spark into a new
project, Spark becomes the upstream, and your project is the downstream. When
the Spark engine improves, downstream projects pull those improvements in.

Branches are a first-class mechanism: a `spark/python-uv` branch carries Python
defaults, a `spark/typescript` branch carries TypeScript defaults. Downstream
projects fork the branch that matches their stack.

## Repo Purpose

This repo is the Spark engine — the skills, configs, templates, and tooling that
downstream projects pull in. It is not a runtime application. Changes here
propagate to every project that has Spark as an upstream.

## Repo Map

```
.spark/
├── skills/      # reusable agent skills — travel to every downstream project
├── configs/     # project-type presets — basis for stack-specific branches
├── templates/   # document templates
├── prompts/     # structured prompts
└── issues/      # GitHub-ready issue drafts
.vscode/         # VS Code workspace settings (tracked as a downstream template)
CLAUDE.md        # Claude Code instruction file (maintained by claude-md skill)
AGENTS.md        # tool-agnostic agent guide (maintained by agents-md skill)
```

## Development Workflow

1. Work on a feature branch. Never commit directly to `master`.
2. Open a PR for every change, even small ones.
3. Keep PRs focused. One concern per PR.
4. Run `ruff` and `black --check` before pushing. (TODO: no pyproject.toml yet)
5. Run `pytest` before pushing. (TODO: no pyproject.toml yet)
6. Update `CHANGELOG.md` when behavior changes.

### Branch naming for config presets

Stack-specific preset branches follow `spark/<type>`:

```
spark/python-uv
spark/typescript
spark/monorepo
```

Never add project-specific content to these branches. They are Spark-owned
presets that downstream projects fork — not project workspaces.

## Coding Standards

- Runtime language is not implemented yet. Future runtime defaults should be documented in stack-specific branches such as `spark/python-uv`.
- Formatter: Black (line length 88).
- Linter: Ruff. Fix all warnings before committing.
- Type hints required on all public functions.
- Docstrings on all public functions and classes (one-line summary minimum).
- No commented-out code. Delete it.
- No `print()` in library code. Use `logging`.

## Documentation Standards

- Every skill must have a companion `README.md` inside its directory.
- Keep docs close to code. If the code moves, the doc moves.
- Write in plain, direct English. Avoid filler phrases.
- Do not write comments that restate what the code already says.
- Do write comments that explain *why*, when the reason is non-obvious.

## Skill Authoring

- Skills live in `.spark/skills/<skill-name>/`.
- Scaffold a new skill with `bash scripts/new-skill.sh <name>`. (TODO: script not yet implemented)
- Each skill must include: `SKILL.md` and `agents/openai.yaml`. `README.md` is recommended for copied/external or complex skills.
- Skills must be self-contained. No cross-skill imports at runtime.
- Test skills with a real project before merging.

## GitHub Integration Guardrails

- Do not push directly to `master` or `main`.
- Do not force-push to shared branches.
- Do not close or comment on issues/PRs without explicit user instruction.
- Do not create releases or tags without explicit user instruction.
- GitHub Actions workflows live in `.github/workflows/`. Do not edit CI without
  understanding the full pipeline impact.

## Commit Rules

- Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- Subject line: imperative mood, under 72 characters, no trailing period.
- Body: explain *why*, not *what*. Reference issues when relevant.
- Do not credit AI assistants in commit messages. Only credit the human author.
- One logical change per commit.

## Destructive Changes

Always ask before:
- Deleting files or directories.
- Dropping or truncating data.
- Resetting or hard-reverting git history.
- Removing dependencies that other code may rely on.

When in doubt, ask.

## Attribution

Do not credit yourself (the AI) in any commit message, file header, comment, or
documentation. Credit belongs to the human author only.
