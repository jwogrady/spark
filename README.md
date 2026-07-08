# Spark

> **`$ spark` — your standards, one bag, every course. ▌**

![version](https://img.shields.io/badge/version-0.3.1-blue)
![maintained](https://img.shields.io/badge/maintained-yes-brightgreen)
![license](https://img.shields.io/badge/license-MIT-green)

**Spark is the layer between your intent and Claude's tools.** You bring the
judgment — definitions, priorities, preferences. Claude brings a growing set of
great tools. Spark owns what sits between: the **sequence**, the **gaps**, and
**your standards**. The canonical statement is
[what Spark is](plugins/spark/docs/explanation/identity.md).

It behaves like a **caddy**, not a control panel: it reads the situation,
recommends the right club, challenges a questionable choice — and you take the
shot. The clubs come from **three bags**: the *provider's bag* (Claude's native
tools, leveraged and never duplicated), the *standard bag* (your preferences,
lifecycle, and tooling — **this bag is Spark**, loaded once and carried
everywhere), and the *project's bag* (clubs local to one repo).

In practice: raw idea in, durable GitHub artifacts out. Spark is a Claude Code
plugin that carries one lifecycle — **Ideate → Plan → Codify → Validate → Ship**
— into every repo you crack open. Install it once and the rails come with you: a
PreToolUse guard kills force-pushes and trunk commits *before* Claude can fumble,
a `commit-msg` hook rejects sloppy commits, and `spark doctor` audits the whole
rig. Twelve skills, two agent crews, zero runtime deps. No reinvention, no drift.

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

## Quickstart

**1 — Install once.** Open Claude Code and run:

```text
/plugin marketplace add jwogrady/spark
/plugin install spark
```

> **Install path:** The verified path today is a local clone or Git URL. The
> one-click published-marketplace listing is still an open item (see `ROADMAP.md`);
> if the marketplace command is not yet reachable, install from a Git URL or local
> path. Spark is then available globally — every project you open gets the
> lifecycle skills (`/spark:ideate`, `/spark:plan`, …) and the `spark` CLI.

**2 — Wire the git guardrails into a repo.** The PreToolUse guard (force-push and
trunk-push block) works automatically once the plugin is installed. The git-level
hooks (conventional commits, block direct trunk commits) activate per repo:

```bash
spark install-git-hooks
spark doctor
```

`spark doctor` validates manifests, hooks, every skill's frontmatter, and every
agent file. It prints a `✓ <name>` line per item and ends with
`Healthy — 0 errors, N warning(s)`, exiting non-zero if any error is found.

**3 — Run the lifecycle.**

1. `/spark:ideate` — frame the problem into a written problem statement.
2. `/spark:plan` — decompose it into scoped work items with acceptance criteria.*
3. `/spark:codify` — implement one item on a feature branch.
4. `/spark:validate` — invoke `/code-review` and `/security-review`, then fix to
   acceptance criteria.
5. `/spark:ship` — write a conventional commit, then open a focused PR.

> *GitHub-issue creation from a problem statement is planned for v0.4; the current
> version generates scoped work items and milestone scaffolds.

Ready for a deeper walkthrough? See
[Build your first project](plugins/spark/docs/tutorials/build-your-first-project.md).

**Prerequisites:** a git repo (`git init` first); for PR creation, the GitHub CLI
(`gh`) installed and authenticated (`gh auth login`) — without it, `/spark:ship`
fails at the push step.

## The skills, grouped

Spark's 12 skills fall into four categories (canonical list:
[`plugins/spark/docs/reference/skills.md`](plugins/spark/docs/reference/skills.md)):

- **Lifecycle** — `ideate`, `plan`, `codify`, `validate`, `ship` (the five steps above).
- **Setup** — `bootstrap` (scaffold a runtime), `connect` (services + secrets via 1Password).
- **Authorship** — `docit` (public docs), `knowledge` (internal knowledge).
- **Supporting** — `agents-md` (`CLAUDE.md` + `AGENTS.md`), `review` (whole-project audit), `cleanup` (stale-code + doc-truth hygiene).

Not sure which one? Follow the
**[skill chooser](plugins/spark/docs/reference/skills.md#which-skill-do-i-use)** — a flowchart
and intent table that pick the right skill in one read.

## Why Spark, not raw Claude Code?

You can use Claude Code directly: it already ships `/code-review`,
`/security-review`, and `verify`, and you can hand-write a `CLAUDE.md`. If that is
your whole situation, Spark adds friction. The honest delta is **portability and
enforcement, not capability**: Spark is one install carried into every repo, with a
fixed lifecycle, mechanical guardrails, and a consistent CLI everywhere.

| Alternative | Where Spark wins | Where the alternative is fine |
|---|---|---|
| Raw Claude Code | Adds guardrails + a repeatable lifecycle in every repo | Solo work on one project where you impose your own discipline |
| A project `CLAUDE.md` | Version-controls the *process*, not just instructions; travels with you | When each project's needs differ enough that a shared process fights you |
| Custom hooks per project | Ships tested, composable hook scripts you don't write from scratch | When you already have mature scripts and don't want the plugin layer |
| Convention + team agreement | The `commit-msg` hook *rejects* non-conforming commits; agreement only asks | A disciplined team that never deviates |
| Workflow tools (Linear, Jira bots) | Lives entirely inside Claude Code — no new SaaS seat, no webhooks | When you already have PM tooling and want it separate |

**Use Spark when** you run multiple projects inside Claude Code and want the same
guardrails and lifecycle in every one. **Skip it when** you have a single project,
prefer raw flexibility, or your repos differ enough that a shared lifecycle adds
friction.

## Maturity and trust

Spark is pre-1.0, at `v0.3.1`. That is the honest contract, not a caveat. Plugin
packaging, the lifecycle skills, enforcement hooks, and the Diátaxis docs tree are
in place; one item is still open — end-to-end install validation from a published
marketplace (tracked in `ROADMAP.md`). No breaking-change policy is documented yet;
treat any `v0.x` release as potentially breaking.

- **Scope: single-developer tool.** Git handles repository concurrency; the plugin
  itself has no team-coordination layer, shared-state sync, or dashboard.
- **License: MIT.** Spark is released under the MIT License (`LICENSE`,
  Copyright © 2026 `jwogrady`), matching the `plugin.json` manifest. You are free
  to use, fork, and redistribute it under those terms.
- **CI / automated tests:** none yet. For a project whose risk surface is malformed
  Markdown frontmatter and mis-wired hooks, the mechanical enforcement model
  (`spark doctor`, the PreToolUse guard, the git hooks) is the intentional quality
  mechanism — but there is no automated regression on skill behavior. A
  `SECURITY.md` is present; the `connect` skill handles secrets via 1Password and
  `shred-env` destroys transient credential files.

## How it fits together

Spark is **additive by design**: it sits between your project and Claude Code's
built-ins, reusing the built-in reviewers rather than reinventing them.

```
┌──────────────────────────────────────────────────────────────┐
│                        your project                          │
├──────────────────────────────────────────────────────────────┤
│                Spark plugin (you install once)               │
│  skills/            hooks/              bin/spark            │
│  12 SKILL.md        PreToolUse          doctor               │
│  files              guard-bash.sh       list-skills          │
│                                         new-skill            │
│  scripts/hooks/                         install-git-hooks    │
│  commit-msg                             shred-env            │
│  pre-commit                             help                 │
├──────────────────────────────────────────────────────────────┤
│              Claude Code (Anthropic built-ins)               │
│      /code-review   /security-review   verify                │
└──────────────────────────────────────────────────────────────┘
```

`guard-bash.sh` lives under `plugins/spark/hooks/`; `commit-msg` and `pre-commit`
live under `plugins/spark/scripts/hooks/` — two distinct directories, two distinct
enforcement mechanisms (a PreToolUse hook vs. git hooks).

**The `spark` CLI:** `doctor`, `list-skills`, `new-skill`, `install-git-hooks`,
`shred-env`, `help`. Pure POSIX-friendly Bash, zero runtime dependencies, graceful
degradation when `jq`/`python3` are absent.

## Contributing

Contributing means adding to the plugin itself — skills, agents, enforcement
scripts, CLI subcommands, or docs — so every downstream project that installs it
gets the improvement. The path has four legs: scaffold, implement, validate, open a
PR on a feature branch.

```bash
spark new-skill <your-skill-name>   # scaffold plugins/spark/skills/<name>/SKILL.md
# implement: SKILL.md needs name: + description: frontmatter; keep it focused
spark doctor                        # validate manifests, hooks, skill + agent frontmatter
bash -n <any-script-you-touched>    # syntax-check shell
spark install-git-hooks             # once, to wire commit-msg + pre-commit locally
```

Standards: valid skill frontmatter; POSIX-friendly Bash with `set -euo pipefail`;
conventional commits (subject ≤ 72 chars, no trailing period, no AI-attribution
trailers); one concern per branch and per PR; never commit directly to
`master`/`main`. Attribution in every author/credit field is the literal string
`jwogrady`. See `CONTRIBUTING.md` and [`docs/explanation/philosophy.md`](plugins/spark/docs/explanation/philosophy.md) (the *why* behind the
rules).

## Documentation

- **[Philosophy](plugins/spark/docs/explanation/philosophy.md)** — what Spark stands for and the
  doctrine behind the rules.
- **[Documentation index](docs/README.md)** — the full Diátaxis tree: tutorials,
  how-to guides, reference, and explanation, plus ADRs and architecture notes.
