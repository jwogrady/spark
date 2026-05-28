# Roadmap

This roadmap reflects current intent, not a commitment or timeline.
Priorities may shift as the project evolves.

---

## v0.1 — Foundation

**Status:** In progress

- [x] Claude Code workspace config (`CLAUDE.md`, `AGENTS.md`, `.vscode/`)
- [x] Core Spark skills: `fork-init`, `claude-md`, `agents-md`
- [x] Productivity skills: `caveman`, `grill-me`, `handoff`, `write-a-skill`
- [x] `.spark/` directory structure: `skills/`, `configs/`, `issues/`
- [x] GitHub templates: PR template, issue templates
- [x] Repo health files: `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `ROADMAP.md`
- [ ] Runtime commands: deferred

---

## v0.2 — iloop

**Status:** Planned

Interactive project inception loop. A skill chain that walks from an idea to a
structured GitHub project plan:

- Debate the idea with the user (grill-me)
- Generate project artifacts: `CLAUDE.md`, `AGENTS.md`, GitHub issue set
- Create a GitHub milestone and project board
- Produce a first PR ready for review

No runtime CLI required for v0.2 — driven by skill invocation.

---

## v0.3 — spark init

**Status:** Planned

First runtime CLI command. `spark init` scaffolds a new project from a Spark
clone using the `fork-init` skill workflow:

- Clone Spark into a new project directory
- Rename `origin` to `upstream`
- Add the new project repo as `origin`
- Run project inception
- Commit and push the inception branch

---

## v0.4 — GitHub-native sync

**Status:** Planned

Skill-driven GitHub project metadata generation:

- Create GitHub issues from `.spark/issues/` drafts
- Create wiki pages from skill documentation
- Create project boards from roadmap milestones
- Keep repo artifacts and GitHub metadata in sync

---

## v0.5 — Stack preset branches

**Status:** Planned

Branch-based project type presets:

- `spark/python-uv` — Python + uv + Black + Ruff defaults
- `spark/typescript` — TypeScript + ESLint + Prettier defaults
- `spark/monorepo` — monorepo layout and tooling preset

Downstream projects fork the branch that matches their stack and pull engine
updates from `upstream/master`.
