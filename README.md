![status](https://img.shields.io/badge/status-plugin-purple)
![type](https://img.shields.io/badge/type-claude%20code%20plugin-black)
![lifecycle](https://img.shields.io/badge/lifecycle-ideate→plan→build→solve→ship-blue)
![license](https://img.shields.io/badge/license-MIT-green)

# Spark

**A portable, GitHub-native software-development toolkit for Claude Code.**

Spark is a Claude Code **plugin** you install once and carry into every project.
It puts one opinionated lifecycle at your fingertips — and enforces the
guardrails that keep work clean — so every repo you touch follows the same loop:

```
Ideate → Plan → Generate → Solve → Ship
```

---

## Install

```text
/plugin marketplace add jwogrady/spark
/plugin install spark
```

Then, in any repo where you want the git-level guardrails:

```bash
spark install-git-hooks
```

Verify everything: `spark doctor`. Full steps: [docs/how-to/install.md](docs/how-to/install.md).

---

## The lifecycle

| Stage | Command | What it does |
|---|---|---|
| **Ideate** | `/spark:ideate` | Turn a fuzzy idea into a written problem statement |
| **Plan** | `/spark:plan` | Decompose the problem into GitHub issues + a milestone |
| **Generate** | `/spark:build` | Implement one issue on a feature branch |
| **Solve** | `/spark:fix-issue` | Orchestrate `/code-review`, `/security-review`, `verify` and fix |
| **Ship** | `/spark:commit` · `/spark:ship` | Conventional commit, then a focused PR |

Each stage hands its output to the next, and each has a crisp definition of done.
See [docs/explanation/sdlc-doctrine.md](docs/explanation/sdlc-doctrine.md).

---

## What's in the box

- **Lifecycle skills** — `ideate`, `plan`, `build`, `fix-issue`, `commit`, `ship`.
- **Carried-over skills** — `grill-me` (used by ideate), `claude-md`, `agents-md`,
  `write-a-skill`, `fork-init` (scaffold a brand-new project).
- **Enforcement** — a PreToolUse guard that blocks force-pushes and pushes to
  trunk, plus `commit-msg`/`pre-commit` git hooks that enforce conventional
  commits, no-AI-attribution, and no-commit-to-trunk.
- **A `spark` CLI** — `doctor`, `new-skill`, `install-git-hooks` — on `$PATH`
  whenever the plugin is active.

---

## Design principles

- **Additive, not competing.** Spark builds on Anthropic's skill/plugin spec and
  reuses Claude Code's built-in reviewers. It documents *when and why* you reach
  for a tool — it doesn't reinvent the tools. See
  [docs/explanation/scope-and-upstream.md](docs/explanation/scope-and-upstream.md).
- **One concern per unit.** One problem per ideate, one feature per issue, one
  issue per branch, one concern per PR.
- **Guardrails are mechanical.** Doctrine you can't enforce is just a brochure.
  The hooks make the rules real.

---

## Repository layout

```
.claude-plugin/
  plugin.json            # plugin manifest
  marketplace.json       # makes this repo git-installable
skills/<name>/SKILL.md   # lifecycle + carried-over skills
hooks/
  hooks.json             # PreToolUse wiring
  guard-bash.sh          # the guard it runs
scripts/hooks/           # git hook sources (commit-msg, pre-commit)
bin/spark                # the CLI
docs/                    # documentation, organized by Diátaxis
.github/ISSUE_TEMPLATE/  # templates the plan skill uses
```

---

## Documentation

Organized by [Diátaxis](https://diataxis.fr/):

- **[Tutorial](docs/tutorials/build-your-first-project.md)** — build your first feature, all five stages.
- **[How-to guides](docs/how-to/)** — install, and one guide per stage.
- **[Reference](docs/reference/)** — skills, hooks, CLI, plugin manifest.
- **[Explanation](docs/explanation/)** — why a plugin, the lifecycle doctrine, scope.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Feature branch → focused PR → review.
Conventional commits. No AI attribution — credit belongs to the author.
