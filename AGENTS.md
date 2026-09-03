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
and mechanically enforced guardrails. The full identity lives in
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
docs/                   # DEV prose + provenance (repo root, NEVER shipped)
├── adr/                # dated decision records
├── ops/                # repo operations (release conventions, manifests, evaluation)
├── architecture/       # the internals map
├── releases/           # per-release records
└── governance|research|alpha/
tests/                  # behavioral tests for shipped scripts (run with tests/run.sh)
.github/                # PR + issue templates (the plan skill uses these)
AGENTS.md               # this file — the canonical agent contract
CLAUDE.md               # imports this file for Claude Code
```

## The Four Tiers

Every artifact belongs to exactly one, and the boundary is mechanically checked
by `spark doctor` (it errors on development-only kinds under `plugins/`):

| Tier | Home | Ships? |
|---|---|---|
| Code | `plugins/*/` — `bin`, `hooks`, `scripts`, `settings`, `skills` | yes |
| Shipped documentation | `plugins/*/docs/` (Diátaxis) | yes |
| Prose + provenance | repo-root `docs/` — ADRs, ops, releases, research | **no** |
| Project management | GitHub issues/milestones/PRs, `.spark/state.json` | n/a |

Repo-root `docs/` sits outside `plugins/`, so it cannot ship. The reverse needs
the check: a decision record filed under `plugins/` would ship this repo's
internal history to anyone who installs the plugin. When a shipped doc must
point at a development-only one, it uses a full GitHub URL labelled
developer-only — a repo-relative path would not resolve after install.

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
  verifiably contain A's merged result. Record true prerequisites with
  GitHub's native `blocked-by` relationship; codify's preflight treats that
  native graph as the executable dependency authority. Prose may explain the
  dependency but does not create one. The preflight demands positive proof
  (merged closing PR an ancestor of HEAD; HEAD exactly at the fresh trunk) and
  blocks — or reports not-assessed — otherwise. Branch from an explicit fresh
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
   One run reports suites, assertion totals and elapsed seconds together, and
   `--json` adds the five slowest suites. **Never run it again to derive another
   summary of the same result** — a second projection must not cost a second
   execution. Use `--only <substring>` for the cheap targeted path while
   repairing, and reserve the full run for an intentional certification
   boundary. `tests/bench.sh` records the hot-path baseline — wall time, external
   processes, parser invocations and remote requests — so an optimization is
   argued from two measurements rather than from an impression.
7. Behavior changes ride your Conventional Commit types — Release Please builds
   `CHANGELOG.md` from them. Never hand-edit the changelog.

There is no build step or package manager — this repo is Bash plus Markdown.
The validation gates are `spark doctor`, `bash -n`, and the behavioral suites
under `tests/`.

The core runtime is `plugins/spark/bin/spark` (the dispatcher and the primitives
every verb needs) plus `plugins/spark/lib/*.sh` (a domain whose helpers no other
verb uses). Executing loads only the selected verb's module; sourcing loads all
of them. `lib/*.sh` is shipped source, not generated — there is still no build
step. Add a new verb to the dispatcher and move it into a module when its
helpers genuinely cluster; never restate a shared primitive to let a module
stand alone. `tests/structure.sh` reports the reference graph these decisions
are made from.

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

Three roles, and they must never be collapsed into one another:

- **Author/owner** — the human/project authority. Credit belongs here, and only
  here. In any author/credit/metadata field, use the literal string `jwogrady`.
- **Worker/provider** — Claude, OpenAI, Copilot, ChatGPT, etc. These are delegated
  execution surfaces; performing implementation work never makes one a project
  author. Never credit an AI system in any commit message, PR, file header,
  comment, doc, or manifest, and never a `Co-Authored-By` trailer for one — the
  commit-msg hook rejects it.
- **Governor** — the installed Spark control plane. Spark may be credited for the
  governance/control-plane role it actually performed, as `Governed by Spark
  vX.Y.Z`. Governed commits carry a mechanical `Spark-Governed-By: vX.Y.Z` trailer,
  and PRs carry the same `Governed by Spark vX.Y.Z` line so a squash/rebase merge
  cannot erase the only durable signal.

Governance provenance is **not authorship**: the `Spark-Governed-By` value is
sourced from the *installed* governor's `spark version` (never the working tree's
unreleased manifest), it never credits an AI worker, and it never changes the Git
author or committer. A supplied trailer that disagrees with the resolved installed
governor fails closed rather than recording false provenance.

## Naming

The organization name is written **`Status26`** — one word, capital S, no
space and no hyphen. In LICENSE files, copyright notices, and filings the legal
form is `Status26, Inc.`; everywhere else the bare `Status26` is correct.

Never write it spaced or hyphenated. The spaced form gets inferred from the
`status26.com` domain at exactly the moment someone has to name a copyright
holder, which is the moment it becomes hard to undo. Genuine identifiers are
not variants and are left alone: `status26.com`, email addresses, and any
handle or package that is legitimately lowercase.

This is a repository-level fact, not a Spark one. **Never hard-code it into a
shipped plugin** — `tests/lib.sh` fails any plugin that names a constellation
(`cosmos`/`status26`), because Spark ships a reusable discipline, not Status26
architecture. A downstream project that needs an org name records it as a
committed project fact, the same as every other preference.
`tests/test-naming.sh` enforces the spelling here.
