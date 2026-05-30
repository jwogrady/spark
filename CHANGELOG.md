# Changelog

All notable changes to this project will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

> Plugin version remains `0.2.0`; these changes are unreleased on the current
> branch. No version bump has been made.

### Added

- **`knowledge` crew — internal-knowledge capture.** New skill `skills/knowledge/SKILL.md`
  runs 6 specialist agents (`agents/knowledge/00-intake` through `05-editor`) to
  capture architectural decisions, processes, and a glossary. It is the inward-facing
  counterpart to `docit`: real plugin subagents with tiered models and scoped tools,
  coordinating through a dedicated `.knowledge-notes/` scratch directory (separate from
  `docit`'s `.docit-notes/`, and kept out of the repo). `knowledge` runs alongside
  `docit`; it does not replace it.
- **`review` skill — multi-agent project audit.** `skills/review/SKILL.md` runs 8
  specialist agents plus a Synthesis Lead to audit a project, for use in the Solve
  stage.
- **MIT license adopted.** `LICENSE` now carries the full MIT License text
  (Copyright © 2026 `jwogrady`), matching the `plugin.json` manifest. Resolves the
  prior `LICENSE` ↔ manifest mismatch.

### Changed

- **Spark is now a Claude Code plugin.** The document-only `.spark/` layer is
  replaced by a plugin packaged at the repo root (`.claude-plugin/plugin.json` +
  `marketplace.json`). Install via `/plugin marketplace add jwogrady/spark` →
  `/plugin install spark` (verified today from a local clone or Git URL; the
  published-marketplace listing is a v0.2 open item — see `ROADMAP.md`).
- Skills moved from `.spark/skills/` to `skills/` and are now namespaced
  `/spark:<name>`.
- Documentation reorganized to Diátaxis under `docs/`.
- `CLAUDE.md`, `AGENTS.md`, `README.md`, `ROADMAP.md` rewritten for the plugin +
  lifecycle model.
- Skill `docit` — multi-persona public-docs glow-up. The author personas run as
  **real plugin subagents** under `agents/docit/` with tiered models and scoped
  tools. Because a subagent cannot spawn another, the skill orchestrates every
  dispatch and barrier, and the agents coordinate only through `.docit-notes/`.
  Personas draft in parallel, cross-evaluate their dependency-graph neighbors, and
  revise before an Editor-in-Chief assembles the docs. In a Phase-4 Issue Council
  the personas nominate, debate, and vote on the gaps they found; the Cartographer
  can veto anything that would overclaim and the human breaks every deadlock. The
  Editor-in-Chief tallies the ranked slate and files it for the human to triage,
  but never closes or comments. Enforces an honest-hype contract: no claim ships
  without a citation to ground truth.
- **De-duplicated the multi-agent orchestration pattern.** The "main loop is the
  sole orchestrator; agents coordinate only through shared notes" mechanics were
  stated in three places (`docit` + `knowledge` collaboration protocols and the
  architecture map). The architecture map is now the single source; the protocol
  files keep a brief self-contained summary and point to it. Fixed the protocols'
  stale "archive (commit it)" guidance for `.docit-notes/` / `.knowledge-notes/`,
  which contradicted the new gitignore.
- **Sharpened `review` and `fix-issue` descriptions** so they disambiguate by
  scope — `fix-issue` reviews one change/branch, `review` audits a whole project —
  and cross-reference each other.

### Added (earlier in the unreleased window)

- Lifecycle skills organized as `Ideate → Plan → Generate → Solve → Ship`:
  `ideate`, `plan`, `codify`, `fix-issue`, `commit`, `ship`.
- Enforcement: `hooks/hooks.json` PreToolUse guard (`hooks/guard-bash.sh`) that
  blocks force-pushes and pushes to trunk; git hooks `scripts/hooks/commit-msg`
  (conventional + no-AI-attribution + subject rules) and `pre-commit`
  (no commit on trunk).
- `bin/spark` CLI: `doctor`, `list-skills`, `new-skill`, `install-git-hooks`,
  `shred-env`, `help`. `doctor` validates plugin layout, skill frontmatter, and
  every agent definition under `agents/`.
- Skill `bootstrap` — runtime scaffold for new projects, defaulting to Bun for
  TypeScript and uv for Python; verifies the scaffold runs, then wires it into Spark.
- Skill `connect` — connectivity & secrets bootstrap via 1Password (`op`):
  capture → ingest → verify → shred → `op run` injection.
- `bin/spark shred-env <file>` + `scripts/shred-env.sh` — secure-delete of
  transient secrets files, with verification; refuses to touch `*.tmpl`.

### Removed

- Skills `caveman` and `handoff` — general productivity, outside the SDLC spine.
- `.spark/configs/` and `.spark/issues/` — superseded by the plugin refactor.
- **Committed skill scratch directories.** Untracked the 108 process-exhaust
  files under `.audit-notes/`, `.docit-notes/`, and `.review-notes/`, and added
  all skill scratch dirs (incl. `.knowledge-notes/`) to `.gitignore` alongside
  `.codify-notes/`. Skills recreate these dirs at runtime; they no longer ship
  with the plugin.
- **`commit` skill — folded into `ship`.** The Ship stage was split across two
  tiny skills (`commit` = 5a, `ship` = 5b); they are now one `ship` skill that
  owns commit + push + PR. Removes a selection ambiguity and drops the lifecycle
  skill count from 12 to 11. All references updated across skills and docs.

### Kept

- Skill `agents-md` (now owns both `CLAUDE.md` and `AGENTS.md`).
- `.vscode/`, `.gitignore`, GitHub PR/issue templates, repo health files.
