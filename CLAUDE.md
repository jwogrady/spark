# Spark — Claude Code Guide

> This file is maintained using the Spark `agents-md` skill.
> See `plugins/spark/skills/agents-md/SKILL.md` for authoring rules.

## Mission

**Spark is the layer between your intent and Claude's tools** — you bring the
judgment (definitions, priorities, preferences), Claude brings the tools, and
Spark owns the sequence, the gaps, and your standards. The full identity lives in
[`plugins/spark/docs/explanation/identity.md`](plugins/spark/docs/explanation/identity.md).

In practice it is a portable project-inception and software-delivery system for
AI-assisted development: it turns raw project intent into durable repo artifacts,
implementation branches, reviews, commits, and pull requests (scoped GitHub
issue generation is a v0.4 goal). The methodology is portable; the current
implementation ships as a Claude Code plugin you install once and carry into
every project. It puts one opinionated lifecycle at your fingertips and enforces
the guardrails that keep work clean:

```
Ideate → Plan → Codify → Validate → Ship
```

You install it (`/plugin marketplace add jwogrady/spark` → `/plugin install spark`)
and every project gets the same versioned toolkit — skills, enforcement hooks,
and the `spark` CLI.

## Repo Purpose

This repo *is* the Spark plugin. Changes here ship to every project that has the
plugin installed. It is additive: it builds on Anthropic's skill/plugin spec and
reuses Claude Code's built-in tools (`/code-review`, `/security-review`,
`verify`) rather than reinventing them.

## Repo Map

```
.claude-plugin/
└── marketplace.json    # marketplace catalog — points at ./plugins/spark
plugins/spark/          # the installable plugin (everything that ships to users)
├── .claude-plugin/plugin.json  # plugin manifest
├── skills/<name>/SKILL.md      # lifecycle + carried-over skills, run as /spark:<name>
├── agents/<crew>/*.md          # real subagents for the docit + knowledge crews
├── hooks/
│   ├── hooks.json              # PreToolUse wiring
│   └── guard-bash.sh           # blocks force-push and pushes to trunk
├── scripts/hooks/              # git hook sources (commit-msg, pre-commit)
├── settings/permission-baseline.json  # recommended permissions.allow, applied by spark apply-permissions
├── bin/spark                   # the CLI (doctor, list-skills, new-skill, install-git-hooks, apply-permissions, shred-env)
└── docs/                       # USER docs (ship with the plugin), organized by Diátaxis
docs/                   # DEV docs (repo root, never shipped): ADRs, architecture, packaging reference
.github/                # PR + issue templates (the plan skill uses these)
CLAUDE.md               # this file (maintained by the agents-md skill)
AGENTS.md               # tool-agnostic agent guide (maintained by agents-md skill)
```

## The Skills

The 12 skills group into four categories. The canonical taxonomy lives in
[`plugins/spark/docs/reference/skills.md`](plugins/spark/docs/reference/skills.md); this list mirrors it.

**Lifecycle** — the five stages:

| Stage | Skill | Job |
|---|---|---|
| Ideate | `ideate` | Frame the problem in writing (uses the native `grill-me`) |
| Plan | `plan` | Decompose into scoped work items + a milestone scaffold (issue generation is a v0.4 goal) |
| Codify | `codify` | Implement one work item on a feature branch |
| Validate | `validate` | Orchestrate built-in reviews, then fix |
| Ship | `ship` | Conventional commit, then a focused PR |

The remaining seven:

- **Setup** — `bootstrap` (scaffold a project runtime), `connect` (services + secrets via 1Password).
- **Authorship** — `docit` (glow up public docs through author personas), `knowledge` (capture internal knowledge through an author crew).
- **Supporting** — `agents-md` (maintains `CLAUDE.md` + `AGENTS.md`), `review` (multi-agent whole-project audit), `cleanup` (purge proven-dead code and false docs; emits an orchestrator prompt).

## Development Workflow

1. Work on a feature branch. Never commit directly to `master`. Name it by
   type: `feat/…`, `fix/…`, `docs/…`, or `chore/…`.
2. Open a PR for every change, even small ones. One concern per PR.
3. Run `spark doctor` before pushing — it validates the plugin layout, the
   manifest/hook JSON, and every skill's frontmatter.
4. Syntax-check shell scripts (`bash -n <file>`) before pushing.
5. Update `CHANGELOG.md` when behavior changes.

There is no test suite, build step, or package manager — this repo is Bash plus
Markdown. `spark doctor` and `bash -n` are the only validation gates.

## Coding Standards

- Scripts are POSIX-friendly Bash, zero runtime dependencies — they must work in
  any forked project regardless of stack. JSON parsing degrades gracefully when
  `jq`/`python3` are absent.
- `set -euo pipefail` in every script.
- No commented-out code. Delete it.
- Comment the *why*, never restate the *what*.

## Skill Authoring

- Skills live in `plugins/spark/skills/<skill-name>/`.
- Scaffold a new skill with `spark new-skill <name>`.
- Each skill needs a `SKILL.md` with `name:` and `description:` frontmatter. The
  `description` is the only thing Claude sees when choosing the skill, so make it
  earn its place: write in the third person, keep it under 1024 characters, lead
  with what the skill does, then name concrete triggers ("Use when …"). A vague
  description ("helps with docs") gives Claude no way to pick it over its peers.
- Keep `SKILL.md` tight — aim for under ~100 lines. When it outgrows that, or has
  distinct domains, or carries rarely-needed depth, split the overflow into
  `references/` (and put real subagents under `agents/`). Both are optional; they
  are the canonical layout — do not invent `REFERENCE.md`/`EXAMPLES.md` files.
- Keep references one level deep; don't make Claude chase a chain of links.
- Add a deterministic helper script only when the operation is mechanical
  (validation, formatting) and would otherwise be regenerated each run.
- Skills must be self-contained. No cross-skill imports at runtime.
- Test a skill in a real project before merging.

## GitHub Integration Guardrails

- Do not push directly to `master` or `main`. (The PreToolUse guard enforces this.)
- Do not force-push to shared branches. (The guard blocks `--force`/`-f`; use
  `--force-with-lease` only with explicit go-ahead.)
- Do not close or comment on issues/PRs without explicit user instruction.
- Do not create releases or tags without explicit user instruction.
- Do not edit CI in `.github/workflows/` without understanding the full pipeline.

## Commit Rules

- Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
- Subject line: imperative mood, under 72 characters, no trailing period.
- Body: explain *why*, not *what*. Reference issues when relevant.
- One logical change per commit.
- The `commit-msg` git hook enforces all of the above.

## Destructive Changes

Always ask before:
- Deleting files or directories.
- Dropping or truncating data.
- Resetting or hard-reverting git history.
- Force-pushing to a shared branch.
- Removing dependencies that other code may rely on.
- Editing CI/CD pipelines.

Force-push and CI specifics live under *GitHub Integration Guardrails* above.
When in doubt, ask.

## Attribution

Credit belongs to the author only. In any author/credit/metadata field, use the
literal string `jwogrady`. Never credit an AI system (Claude, Anthropic, Copilot,
ChatGPT, etc.) in any commit message, PR, file header, comment, doc, or manifest.
