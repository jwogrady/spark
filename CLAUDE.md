# Spark — Claude Code Guide

> This file is maintained using the Spark `agents-md` skill.
> See `plugins/spark/skills/agents-md/SKILL.md` for authoring rules.

## Mission

**Spark turns a Claude subscription and a GitHub subscription into a software
delivery system.** Claude can write and review code; GitHub can organize,
preserve, and ship it; Spark supplies the project engineering between them —
your standards loaded once, one traceable lifecycle, durable GitHub artifacts,
and mechanically enforced guardrails. The full identity lives in
[`plugins/spark/docs/explanation/identity.md`](plugins/spark/docs/explanation/identity.md).

```
Ideate → Plan → Codify → Validate → Ship
```

You install it (`/plugin marketplace add jwogrady/spark` → `/plugin install spark`),
run `spark setup` in a repo, and every project gets the same versioned toolkit —
skills, enforcement hooks, and the `spark` CLI.

## Repo Purpose

This repo is a plugin marketplace: the focused core plugin (`spark`) plus three
companion plugins. Changes here ship to every project that has a plugin
installed. It is additive: it builds on Anthropic's skill/plugin spec and
reuses Claude Code's built-in tools (`/code-review`, `/security-review`,
`verify`) rather than reinventing them.

## Repo Map

```
.claude-plugin/
└── marketplace.json    # marketplace catalog — lists the core + three companions
plugins/spark/          # the core plugin (the shipping loop)
├── .claude-plugin/plugin.json  # plugin manifest
├── skills/<name>/SKILL.md      # the nine core skills, run as /spark:<name>
├── agents/knowledge/           # real subagents for the knowledge crew
├── hooks/
│   ├── hooks.json              # PreToolUse wiring
│   └── guard-bash.sh           # blocks force-push and pushes to trunk
├── scripts/hooks/              # git hook sources (commit-msg, pre-commit)
├── bin/spark                   # the CLI (doctor, list-skills, new-skill, setup, install-git-hooks, apply-permissions, preferences, resume, version, brief, help)
└── docs/                       # USER docs (ship with the plugin), organized by Diátaxis
plugins/spark-audit/    # companion: whole-project assessment + evidence-backed cleanup
plugins/spark-connect/  # companion: services, credentials, 1Password, shred-env
plugins/spark-docs/     # companion: public docs and positioning via author personas
docs/                   # DEV docs (repo root, never shipped): ADRs, architecture, packaging reference
tests/                  # behavioral tests for shipped scripts (run with tests/run.sh)
.github/                # PR + issue templates (the plan skill uses these)
CLAUDE.md               # this file (maintained by the agents-md skill)
AGENTS.md               # tool-agnostic agent guide (maintained by agents-md skill)
```

## The Skills

The core plugin ships 9 skills in three categories. The canonical taxonomy lives in
[`plugins/spark/docs/reference/skills.md`](plugins/spark/docs/reference/skills.md); this list mirrors it.

**Lifecycle** — the five stages:

| Stage | Skill | Job |
|---|---|---|
| Ideate | `ideate` | Frame the problem in writing (uses the native `grill-me`) |
| Plan | `plan` | Decompose into scoped GitHub issues + a milestone (created on approval) |
| Codify | `codify` | Implement one work item on a feature branch |
| Validate | `validate` | Orchestrate built-in reviews, then fix |
| Ship | `ship` | Conventional commit, then a focused PR |

The remaining four:

- **Setup** — `onboard` (the guided first run: orient → profile → seed → brief, sequencing the CLI verbs and stopping at each human decision) and `bootstrap` (scaffold a new project's runtime, then run `spark setup` to wire it into the lifecycle).
- **Supporting** — `knowledge` (capture internal knowledge through an author crew), `agents-md` (maintains `CLAUDE.md` + `AGENTS.md`).

The companion plugins carry everything else, each under its own namespace:
`spark-audit` (`/spark-audit:audit` — whole-project assessment and
evidence-backed cleanup), `spark-connect` (`/spark-connect:connect` — services,
secrets, 1Password, shred-env), and `spark-docs` (`/spark-docs:docit` — public
docs through author personas).

## Development Workflow

1. Work on a feature branch. Never commit directly to `master`. Name it by
   type: `feat/…`, `fix/…`, `docs/…`, or `chore/…`.
2. Open a PR for every change, even small ones. One concern per PR.
3. Run `spark doctor` before pushing — it validates the whole marketplace: the
   plugin layouts, the manifest/hook JSON, and every skill's frontmatter,
   companions included.
4. Syntax-check shell scripts (`bash -n <file>`) before pushing.
5. Run `tests/run.sh` when changing enforcement hooks or other tested scripts —
   it executes every `tests/test-*.sh` suite and fails non-zero on any failure.
6. Update `CHANGELOG.md` when behavior changes.

There is no build step or package manager — this repo is Bash plus Markdown.
The validation gates are `spark doctor`, `bash -n`, and the behavioral suites
under `tests/`.

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
- Do not create releases or tags without explicit user instruction. (Where
  Release Please is configured — config file or workflow — the guard blocks
  hand-cut tags and Releases; Release Please cuts them after a human merges
  its release PR.)
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
