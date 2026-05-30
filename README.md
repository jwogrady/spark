![status](https://img.shields.io/badge/status-plugin-purple)
![type](https://img.shields.io/badge/type-claude%20code%20plugin-black)
![lifecycle](https://img.shields.io/badge/lifecycle-ideate→plan→build→solve→ship-blue)
![license](https://img.shields.io/badge/license-MIT-green)

# Spark

**A portable project-inception and software-delivery toolkit for Claude Code.**

Spark started as a standard skills library for turning raw project intent into the
working artifacts every serious repo needs: charter, README, changelog,
requirements, features, milestones, GitHub issues, and agent guidance.

Spark now ships that foundation as a Claude Code **plugin** you install once and
carry into every project. It gives Claude Code one opinionated lifecycle and the
mechanical guardrails that keep repo work clean:

```text
Ideate → Plan → Generate → Solve → Ship
```

The project-inception layer is still the root idea. The Claude Code plugin is the
current delivery vehicle.

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

## What Spark does

Spark helps a repo move from vague intent to shippable work without losing the
thread:

1. Capture the project idea and operating doctrine.
2. Turn that intent into durable project artifacts.
3. Break the work into milestones and GitHub issues.
4. Build one focused feature branch at a time.
5. Review, harden, commit, and open a focused PR.

That means Spark is both:

- **A project-inception toolkit** — for creating the docs, issues, and repo
  conventions that make a project legible.
- **A Claude Code SDLC plugin** — for running the day-to-day loop once the repo
  exists.

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
- **Setup skills** — `bootstrap` for runtime scaffolding and `connect` for
  service connectivity + secrets setup.
- **Project-inception skills** — `fork-init`, `claude-md`, `agents-md`, and
  `write-a-skill` for making a repo understandable to humans and agents.
- **Review pressure** — `grill-me` for stress-testing ideas before they become
  expensive.
- **Enforcement** — a PreToolUse guard that blocks force-pushes and pushes to
  trunk, plus `commit-msg`/`pre-commit` git hooks that enforce conventional
  commits, no-AI-attribution, and no-commit-to-trunk.
- **A `spark` CLI** — `doctor`, `new-skill`, `install-git-hooks`, and
  `shred-env` — on `$PATH` whenever the plugin is active.

---

## Design principles

- **Project intent comes first.** Spark exists to preserve the why before it
  generates the what.
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
  marketplace.json       # makes this repo git-installable
skills/<name>/SKILL.md   # lifecycle, setup, and project-inception skills
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
