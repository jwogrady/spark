# Changelog

All notable changes to this project will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

### Changed

- **Spark is now a Claude Code plugin.** The document-only `.spark/` layer is
  replaced by a plugin packaged at the repo root (`.claude-plugin/plugin.json` +
  `marketplace.json`). Install via `/plugin marketplace add jwogrady/spark` →
  `/plugin install spark`.
- Skills moved from `.spark/skills/` to `skills/` and are now namespaced
  `/spark:<name>`.
- Documentation reorganized to Diátaxis under `docs/`.
- `CLAUDE.md`, `AGENTS.md`, `README.md`, `ROADMAP.md` rewritten for the plugin +
  lifecycle model (no longer "runtime not implemented").

### Added

- Lifecycle skills organized as `Ideate → Plan → Generate → Solve → Ship`:
  `ideate`, `plan`, `build`, `fix-issue`, `commit`, `ship`.
- Enforcement: `hooks/hooks.json` PreToolUse guard (`hooks/guard-bash.sh`) that
  blocks force-pushes and pushes to trunk; git hooks `scripts/hooks/commit-msg`
  (conventional + no-AI-attribution + subject rules) and `pre-commit`
  (no commit on trunk).
- `bin/spark` CLI: `doctor`, `new-skill`, `install-git-hooks`.
- Skill `bootstrap` — runtime scaffold for new projects via the official
  scaffolder, defaulting to Bun for TypeScript and uv for Python; verifies the
  scaffold runs, then wires it into Spark (CLAUDE.md, git hooks, connect, ideate).
- Skill `connect` — connectivity & secrets bootstrap for GitHub/GCP/Vultr/Linode
  via 1Password (`op`): capture → ingest (propose-confirm `op item create`) →
  verify → shred → `op run` injection. Encourages per-project keys.
- `bin/spark shred-env <file>` + `scripts/shred-env.sh` — secure-delete of
  transient secrets files, with verification; refuses to touch `*.tmpl`.
- Skill `docsmith` — multi-persona docs glow-up. One author writes through a cast
  of author personas (Cartographer, Skimmer, Adopter, Skeptic, Evaluator, Believer,
  Coach, Contributor, Visual Storyteller, Returning User, Discoverer/SEO, Amplifier,
  Editor-in-Chief), each with its own spec under `references/personas/`. Personas
  draft in parallel, cross-evaluate their dependency-graph neighbors, and revise
  before an Editor-in-Chief pass assembles `README.md`, `docs/PHILOSOPHY.md`, the
  [Diátaxis](https://diataxis.fr/) docs tree (tutorials/how-to/reference/
  explanation), `CHANGELOG.md`, and `docs/launch-copy.md`. As team leader, the
  Editor-in-Chief also files the gaps the team found as prioritized, annotated
  `proposed`-labeled GitHub issues (recorded in `13-proposed-issues.md`) for the
  human to triage — kept issues flow to `plan`, closing the loop back to the Plan
  stage. The leader files but never closes or comments. Enforces an honest-hype
  contract: no claim ships without a citation to ground truth. Ship-stage amplifier.

### Removed

- Skills `caveman` and `handoff` — general productivity, outside the SDLC spine.
- `.spark/configs/` and `.spark/issues/` — superseded by the plugin refactor.

### Kept

- Skills `grill-me`, `claude-md`, `agents-md`, `write-a-skill`, `fork-init`.
- `.vscode/`, `.gitignore`, GitHub PR/issue templates, repo health files.
