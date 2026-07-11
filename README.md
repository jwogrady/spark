# Spark

> **Your standards, loaded once, carried everywhere.**

![version](https://img.shields.io/badge/version-0.3.1-blue)
![maintained](https://img.shields.io/badge/maintained-yes-brightgreen)
![license](https://img.shields.io/badge/license-MIT-green)

**Spark is the layer between your intent and Claude's tools.** You bring the
judgment — definitions, priorities, standards. Claude brings a growing set of
great tools. Spark owns what sits between: the sequence, the gaps, and your
standards. It behaves like a caddy, not a control panel — it reads the
situation, recommends the club, challenges a questionable choice, and you take
the shot. The canonical statement is
[what Spark is](plugins/spark/docs/explanation/identity.md).

Everything Spark does is one of **three motions**
([glossary](plugins/spark/docs/glossary.md)):

- **Carry-in** — your engineering standards enter every project you open. The
  enforcement hooks and permission baseline install once and travel with the
  plugin; your
  [engineering preferences](plugins/spark/docs/reference/engineering-preferences.md)
  resolve through three tiers — shipped defaults, your overrides, committed
  project facts — and enter a repo through `bootstrap` at generation or
  `spark preferences --apply` on demand. Start at
  [carry your preferences in](plugins/spark/docs/how-to/carry-your-preferences-in.md).
- **Carry-through** — one lifecycle moves work from idea to merged PR:
  **Ideate → Plan → Codify → Validate → Ship**, with the discipline enforced by
  code, not convention. *Shipped and enforced.*
- **Carry-forward** — what a session produces outlives it. `ideate` persists
  the problem statement; issues and ADRs are the durable ledger; the lifecycle
  skills record work state in a committed `.spark/state.json`, a session-start
  brief reads it back, and `spark resume` picks the work up where it stopped.

```mermaid
flowchart LR
    A([Ideate]) --> B([Plan])
    B --> C([Codify])
    C --> D([Validate])
    D --> E([Ship])
    A:::stage
    B:::stage
    C:::stage
    D:::stage
    E:::stage
    classDef stage fill:#1a1a2e,stroke:#e94560,color:#eaeaea,rx:6
```

> Each stage is a skill of the same name: `/spark:ideate`, `/spark:plan`,
> `/spark:codify`, `/spark:validate`, `/spark:ship`.

## What is enforced, mechanically

These are not guidelines. They are code that runs:

- **The PreToolUse guard** (`hooks/guard-bash.sh`) inspects every Bash command
  Claude is about to run and blocks force-pushes and pushes to `master`/`main`
  before they execute.
- **The git hooks** (`commit-msg`, `pre-commit`, installed per repo with
  `spark install-git-hooks`) reject non-conventional commit messages, AI
  attribution, and direct commits to trunk — the human-driven path the plugin
  hook cannot see. Two paths into git, two doors, same rules.
- **`spark doctor`** is the single health gate: manifest and hook JSON, every
  skill's and agent's frontmatter, `bash -n` on every shipped script, a
  broken-link scan across the docs, and an enforcement-parity check proving the
  guard, the git hooks, and the documentation still state the same rules.
- **Validation CI** runs on every PR to this repo — and it is exactly one
  command, `spark doctor`, so the local gate and the CI gate cannot drift.

## Quickstart

**1 — Install once.** In Claude Code:

```text
/plugin marketplace add jwogrady/spark
/plugin install spark
```

This GitHub-shorthand path is the verified install. (A one-click *published*
marketplace listing is still open — tracked in `ROADMAP.md`.) Once installed,
every project you open gets the skills and the `spark` CLI.

**2 — Arm a repo.** The PreToolUse guard is active everywhere automatically.
Everything per-repo — git hooks, permission baseline, resolved standard —
lands in one run:

```bash
spark setup           # idempotent; granular verbs still exist for each step
spark doctor          # ends with: Healthy — 0 errors, N warning(s)
```

**3 — Run the lifecycle.**

1. `/spark:ideate` — frame the problem; the confirmed statement is saved to
   `docs/problem-statement.md`.
2. `/spark:plan` — decide the stack (recorded as ADRs), decompose into
   features, draft GitHub issues, and create them on your approval.
3. `/spark:codify` — implement one issue on a feature branch.
4. `/spark:validate` — run the built-in `/code-review` and `/security-review`,
   then fix to the issue's acceptance criteria.
5. `/spark:ship` — conventional commit, push, one focused PR.

Deeper walkthrough:
[Build your first project](plugins/spark/docs/tutorials/build-your-first-project.md).

**Prerequisites:** a git repo, and the GitHub CLI (`gh`) authenticated for
issue and PR creation.

## The skills, grouped

Spark's 11 skills fall into four categories (canonical list:
[`plugins/spark/docs/reference/skills.md`](plugins/spark/docs/reference/skills.md)):

- **Lifecycle** — `ideate`, `plan`, `codify`, `validate`, `ship` (the five stages above).
- **Setup** — `bootstrap` (scaffold a runtime), `connect` (services + secrets via 1Password).
- **Authorship** — `docit` (public docs), `knowledge` (internal knowledge).
- **Supporting** — `agents-md` (`CLAUDE.md` + `AGENTS.md`), `audit` (whole-project health assessment + evidence-gated purge).

Not sure which one? Follow the
**[skill chooser](plugins/spark/docs/reference/skills.md#which-skill-do-i-use)** — a
flowchart and intent table that pick the right skill in one read.

## Why Spark, not raw Claude Code?

You can use Claude Code directly: it already ships `/code-review`,
`/security-review`, and `verify`, and you can hand-write a `CLAUDE.md`. If that
is your whole situation, Spark adds friction. The honest delta is **portability
and enforcement, not capability**: one install carried into every repo, with a
fixed lifecycle, mechanical guardrails, and a consistent CLI everywhere.

| Alternative | Where Spark wins | Where the alternative is fine |
|---|---|---|
| Raw Claude Code | Adds guardrails + a repeatable lifecycle in every repo | Solo work on one project where you impose your own discipline |
| A project `CLAUDE.md` | Version-controls the *process*, not just instructions; travels with you | When each project's needs differ enough that a shared process fights you |
| Custom hooks per project | Ships tested, composable hook scripts you don't write from scratch | When you already have mature scripts and don't want the plugin layer |
| Convention + team agreement | The `commit-msg` hook *rejects* non-conforming commits; agreement only asks | A disciplined team that never deviates |
| Workflow tools (Linear, Jira bots) | Lives entirely inside Claude Code — no new SaaS seat, no webhooks | When you already have PM tooling and want it separate |

**Use Spark when** you run multiple projects inside Claude Code and want the
same guardrails and lifecycle in every one. **Skip it when** you have a single
project, prefer raw flexibility, or your repos differ enough that a shared
lifecycle adds friction.

## Maturity and trust

Spark is pre-1.0, at `v0.3.1`. That is the honest contract, not a caveat.

- **Architecture v1.0 is complete and ratified** (ADR-0008: three layers, one
  canonical source per information class, the three motions above; audited in
  `docs/architecture/conformance.md`). The core v0.4 carry-in and carry-forward
  features — three-tier preferences, the session brief, resumable work state —
  now ship; the rest of the **v0.4 milestone** (e.g. scoped issue generation)
  is tracked as GitHub issues.

- **Validation CI is live**: every PR to this repo must pass `spark doctor`.
  What is *not* automated is behavioral regression on the skills themselves —
  skills are prompts, and their quality gate is use.
- **Scope: single-developer tool.** No team-coordination layer, shared-state
  sync, or dashboard.
- **License: MIT** (`LICENSE`, Copyright © 2026 `jwogrady`).
- No breaking-change policy is documented yet; treat any `v0.x` release as
  potentially breaking. `SECURITY.md` is present; `connect` keeps secrets in
  1Password and `shred-env` destroys transient credential files.

## How it fits together

Spark is **additive by design**: it sits between your project and Claude Code's
built-ins, reusing the built-in reviewers rather than reinventing them.

```
┌──────────────────────────────────────────────────────────────┐
│                        your project                          │
├──────────────────────────────────────────────────────────────┤
│                Spark plugin (you install once)               │
│  skills/          hooks/               bin/spark             │
│  11 SKILL.md      PreToolUse           doctor  list-skills   │
│  files            guard-bash.sh        new-skill  version    │
│  agents/          SessionStart         install-git-hooks     │
│  docit (13)       spark brief          apply-permissions     │
│  knowledge (6)                         preferences  brief    │
│                   scripts/hooks/       resume  shred-env     │
│  preferences/     commit-msg           help                  │
│  defaults.json    pre-commit           settings/             │
│  templates/                            permission baseline   │
├──────────────────────────────────────────────────────────────┤
│              Claude Code (Anthropic built-ins)               │
│      /code-review   /security-review   verify                │
└──────────────────────────────────────────────────────────────┘
```

`guard-bash.sh` lives under `plugins/spark/hooks/` (a Claude Code PreToolUse
hook); `commit-msg` and `pre-commit` live under `plugins/spark/scripts/hooks/`
(git hooks) — two directories because they are two enforcement doors.

**The `spark` CLI:** `doctor`, `list-skills`, `new-skill`, `setup`,
`install-git-hooks`, `apply-permissions`, `preferences`, `brief`, `resume`,
`shred-env`, `version`, `help`. Pure POSIX-friendly Bash, zero runtime
dependencies, graceful degradation when `jq`/`python3` are absent.

## Contributing

Contributing means adding to the plugin itself — skills, agents, enforcement
scripts, CLI subcommands, or docs — so every downstream project that installs
it gets the improvement.

```bash
spark new-skill <your-skill-name>   # scaffold + lint plugins/spark/skills/<name>/SKILL.md
spark install-git-hooks             # once, to wire commit-msg + pre-commit locally
spark doctor                        # the full local gate — CI runs exactly this
```

Standards: valid skill frontmatter; POSIX-friendly Bash with `set -euo
pipefail`; conventional commits (subject ≤ 72 chars, no trailing period, no
AI-attribution trailers); one concern per branch and per PR; never commit
directly to `master`/`main`. Attribution in every author/credit field is the
literal string `jwogrady`. See `CONTRIBUTING.md` and
[`philosophy.md`](plugins/spark/docs/explanation/philosophy.md) — the *why*
behind the rules.

## Documentation

- **[Documentation index](plugins/spark/docs/README.md)** — the full Diátaxis
  tree: tutorial, how-to guides, reference, and explanation.
- **[What Spark is](plugins/spark/docs/explanation/identity.md)** — the
  canonical identity statement.
- **[Philosophy](plugins/spark/docs/explanation/philosophy.md)** — the nine
  principles behind the rules.
