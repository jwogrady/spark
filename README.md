![status](https://img.shields.io/badge/status-active-purple)
![type](https://img.shields.io/badge/type-project%20delivery%20system-black)
![lifecycle](https://img.shields.io/badge/lifecycle-ideate→plan→generate→solve→ship-blue)
![runtime](https://img.shields.io/badge/runtime-claude%20code%20plugin-lightgrey)
![license](https://img.shields.io/badge/license-MIT-green)

# Spark

Spark is a portable project-inception and software-delivery system for AI-assisted development.

It turns raw project intent into durable repo artifacts, scoped GitHub issues, implementation branches, reviews, commits, and pull requests. The methodology is portable; the current implementation ships as a Claude Code plugin.

Spark's loop is:

```text
Ideate → Plan → Generate → Solve → Ship
```

Use Spark when you want every repo to start with clear intent, keep its doctrine
close to the code, and move work through the same disciplined path from idea to PR.

---

## How Spark is built

The product is the methodology. The plugin is how it's delivered today.

```text
Spark
  └─ Methodology   Ideate → Plan → Generate → Solve → Ship
  └─ Product       a project-inception and software-delivery system
  └─ Runtime       a Claude Code plugin
  └─ Interface     /spark:* commands + the `spark` CLI
  └─ Enforcement   hooks, templates, docs, and git guardrails
```

The methodology outlives any one runtime. Claude Code is the surface it runs on
now, and the plugin is the package that installs it — not the whole identity.

---

## The lifecycle

| Stage | Command | What it does |
|---|---|---|
| **Ideate** | `/spark:ideate` | Turn a fuzzy idea into a written problem statement |
| **Plan** | `/spark:plan` | Decompose the problem into GitHub issues + a milestone |
| **Generate** | `/spark:build` | Implement one issue on a feature branch |
| **Solve** | `/spark:fix-issue` · `/spark:review` | Run `/code-review`, `/security-review`, `verify`, then fix |
| **Ship** | `/spark:commit` · `/spark:ship` | Conventional commit, then a focused PR |

Each stage hands its output to the next, and each has a crisp definition of done.
See [docs/explanation/sdlc-doctrine.md](docs/explanation/sdlc-doctrine.md).

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

## What's in the box

- **Lifecycle skills** — `ideate`, `plan`, `build`, `fix-issue`, `commit`, `ship`.
- **Setup skills** — `bootstrap` for runtime scaffolding (Bun / uv) and `connect`
  for service connectivity + secrets setup.
- **Project-inception skills** — `fork-init`, `claude-md`, `agents-md`, and
  `write-a-skill` for making a repo legible to humans and agents.
- **Review pressure** — `review` for a multi-agent project audit and `grill-me`
  for stress-testing ideas before they become expensive.
- **Enforcement** — a PreToolUse guard that blocks force-pushes and pushes to
  trunk, plus `commit-msg`/`pre-commit` git hooks that enforce conventional
  commits, no-AI-attribution, and no-commit-to-trunk.
- **A `spark` CLI** — `doctor`, `new-skill`, `install-git-hooks`, `shred-env`,
  and `help` — on `$PATH` whenever the plugin is active.

---

## Design principles

- **Project intent comes first.** Spark exists to preserve the *why* before it
  generates the *what*.
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

```text
.claude-plugin/
  plugin.json            # plugin manifest
  marketplace.json       # makes this repo git-installable as a marketplace
skills/<name>/SKILL.md   # lifecycle, setup, inception, and review skills
hooks/
  hooks.json             # PreToolUse wiring
  guard-bash.sh          # the guard it runs
scripts/hooks/           # git hook sources (commit-msg, pre-commit)
bin/spark                # the CLI
docs/                    # documentation, organized by Diátaxis
.github/ISSUE_TEMPLATE/  # templates the plan skill uses
CLAUDE.md                # in-repo doctrine for Claude Code
AGENTS.md                # tool-agnostic guide for any coding agent
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
