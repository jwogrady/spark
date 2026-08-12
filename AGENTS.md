# Spark — AI Agent Guide

> This file is the **single canonical agent contract** for this repository,
> maintained with the Spark `agents-md` skill (`plugins/spark/skills/agents-md/SKILL.md`).
> `CLAUDE.md` imports it; other tools read it directly. It applies to any AI
> coding agent working here, regardless of tool.

## Mission

**Spark turns an AI coding assistant and a GitHub subscription into a software
delivery system.** The assistant writes and reviews code; GitHub organizes,
preserves, and ships it; Spark supplies the project engineering between them —
your standards loaded once, one traceable lifecycle, durable GitHub artifacts,
and mechanically enforced guardrails. The full identity — including the north
star, the three-column placement rule Spark carries into every repo it arms —
lives in
[`plugins/spark/docs/explanation/identity.md`](plugins/spark/docs/explanation/identity.md).

```
Ideate → Plan → Codify → Validate → Ship
```

## Repo Purpose

This repo is a plugin marketplace: the focused core plugin (`spark`) plus three
companion plugins. Changes here ship to every project that has a plugin
installed. It is additive: it builds on Anthropic's skill/plugin spec and
reuses the host tool's built-in capabilities (`/code-review`,
`/security-review`, `verify`) rather than reinventing them.

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
├── settings/                   # permission presets + the trunk ruleset policy
├── bin/spark                   # the CLI — every verb is documented in docs/reference/cli.md
└── docs/                       # USER docs (ship with the plugin), organized by Diátaxis
plugins/spark-audit/    # companion: whole-project assessment + evidence-backed cleanup
plugins/spark-connect/  # companion: services, credentials, 1Password, shred-env
plugins/spark-docs/     # companion: public docs and positioning via author personas
docs/                   # DEV docs (repo root, never shipped): ADRs, architecture, packaging
tests/                  # behavioral tests for shipped scripts (run with tests/run.sh)
.github/                # PR + issue templates (the plan skill uses these)
AGENTS.md               # this file — the canonical agent contract
CLAUDE.md               # imports this file for Claude Code
```

## The Skills

The core plugin ships 9 skills in three categories. The canonical taxonomy lives in
[`plugins/spark/docs/reference/skills.md`](plugins/spark/docs/reference/skills.md).

**Lifecycle** — the five stages:

| Stage | Skill | Job |
|---|---|---|
| Ideate | `ideate` | Frame the problem in writing |
| Plan | `plan` | Model → shape → design; scoped GitHub issues + a milestone (created on approval) |
| Codify | `codify` | Implement one issue as focused commits on a feature branch |
| Validate | `validate` | Orchestrate built-in reviews, then fix and commit the fixes |
| Ship | `ship` | Verify the commit series, push, open one focused PR |

The remaining four:

- **Setup** — `onboard` (the guided first run: orient → profile → seed → brief,
  sequencing the CLI verbs and stopping at each human decision) and `bootstrap`
  (materialize the accepted design as a runtime scaffold, then run `spark setup`).
- **Supporting** — `knowledge` (capture internal knowledge through an author
  crew), `agents-md` (maintains this contract and its `CLAUDE.md` pointer).

The companion plugins carry everything else, each under its own namespace:
`spark-audit` (whole-project assessment and evidence-backed cleanup),
`spark-connect` (services, secrets, 1Password, shred-env), and `spark-docs`
(public docs through author personas).

## Delivery Model

Canonical delivery is issue → issue branch → focused commits → validation →
issue PR → `master` (ADR-0027, and the delivery section of
[`sdlc-doctrine.md`](plugins/spark/docs/explanation/sdlc-doctrine.md)):

- One issue per branch; multiple focused Conventional Commits per branch.
- **Ordering invariant:** if issue B depends on issue A, B's base must
  verifiably contain A's merged result. Declare dependencies on the issue
  (`Blocked by #N`); codify's preflight demands positive proof (merged
  closing PR an ancestor of HEAD; HEAD exactly at the fresh trunk) and
  blocks — or reports not-assessed — otherwise. Branch with an explicit
  `origin/<trunk>` start point.
- **One writer per working tree:** concurrent mutation needs genuinely
  isolated worktrees; read-only analysis may run concurrently.
- A temporary integration branch is a recovery/exception technique — never a
  standing `develop`, never the default path.

## Development Workflow

1. Work on a feature branch. Never commit directly to `master`. Name it by
   type, with the issue number when practical: `feat/42-…`, `fix/…`, `docs/…`,
   `chore/…`.
2. Open a PR for every change, even small ones. One concern per PR.
3. Commit each coherent problem → solution step as you work — the branch
   history tells the implementation story. No WIP noise; no end-of-work blob.
4. Run `spark doctor` before pushing — it validates the whole marketplace: the
   plugin layouts, the manifest/hook JSON, and every skill's frontmatter,
   companions included.
5. Syntax-check shell scripts (`bash -n <file>`) before pushing.
6. Run `tests/run.sh` when changing enforcement hooks or other tested scripts —
   it executes every `tests/test-*.sh` suite and fails non-zero on any failure.
7. Behavior changes ride your Conventional Commit types — Release Please builds
   `CHANGELOG.md` from them. Never hand-edit the changelog.

There is no build step or package manager — this repo is Bash plus Markdown.
The validation gates are `spark doctor`, `bash -n`, and the behavioral suites
under `tests/`.

## Coding Standards

- Scripts are POSIX-friendly Bash, zero runtime dependencies — they must work in
  any forked project regardless of stack. JSON parsing degrades gracefully when
  `jq`/`python3` are absent.
- `set -euo pipefail` in every script.
- No commented-out code. Delete it. No debug output left in.
- Comment the *why*, never restate the *what*.

## Skill Authoring

- Skills live in `plugins/spark/skills/<skill-name>/`.
- Scaffold a new skill with `spark new-skill <name>`.
- Each skill needs a `SKILL.md` with `name:` and `description:` frontmatter. The
  `description` is the only thing the model sees when choosing the skill, so make
  it earn its place: write in the third person, stay within the **enforced
  1024-character budget**, lead with what the skill does, then name concrete
  triggers ("Use when …").
- Keep `SKILL.md` tight — `spark doctor` enforces a **100-line budget** per
  `SKILL.md` and the description budget; a surface over either fails the gate
  (#209). When a skill outgrows the budget, split the overflow into
  `references/` progressive disclosure (and put real subagents under `agents/`).
- Keep references one level deep; don't make the model chase a chain of links.
- Add a deterministic helper script only when the operation is mechanical
  (validation, formatting) and would otherwise be regenerated each run.
- Skills must be self-contained. No cross-skill imports at runtime.
- Test a skill in a real project before merging.

## GitHub Integration Guardrails

- Do not push directly to `master` or `main`. (The PreToolUse guard enforces
  this locally; a GitHub ruleset is the server-side door — see
  [`enforcement-model.md`](plugins/spark/docs/explanation/enforcement-model.md).)
- Do not force-push to shared branches. (The guard blocks `--force`/`-f`; use
  `--force-with-lease` only with explicit go-ahead.)
- Do not open, close, or comment on issues/PRs without explicit instruction.
- Do not create releases or tags without explicit user instruction. (Where
  Release Please is configured — config file or workflow — the guard blocks
  hand-cut tags and Releases; the release act is a human merging the Release
  Please release PR. The milestone declares the version; `Release-As` mints it.)
- Do not call GitHub APIs beyond the task's needs, and never change repository
  settings (protection, rulesets) — surfacing drift is Spark's job, applying
  policy is the human's.
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

## Scope Discipline

- Do only what was asked. Do not refactor surrounding code opportunistically.
- Do not introduce dependencies not required by the task.
- Do not implement features not in scope for the current task.

## Attribution

Credit belongs to the author only. In any author/credit/metadata field, use the
literal string `jwogrady`. Never credit an AI system (Claude, Anthropic, Copilot,
ChatGPT, etc.) in any commit message, PR, file header, comment, doc, or manifest.
