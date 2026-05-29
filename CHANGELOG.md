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
- Skill `connect` — connectivity & secrets bootstrap for GitHub/GCP/Vultr/Linode
  via 1Password (`op`): capture → ingest (propose-confirm `op item create`) →
  verify → shred → `op run` injection. Encourages per-project keys.
- `bin/spark shred-env <file>` + `scripts/shred-env.sh` — secure-delete of
  transient secrets files, with verification; refuses to touch `*.tmpl`.

### Removed

- Skills `caveman` and `handoff` — general productivity, outside the SDLC spine.
- `.spark/configs/` and `.spark/issues/` — superseded by the plugin refactor.

### Kept

- Skills `grill-me`, `claude-md`, `agents-md`, `write-a-skill`, `fork-init`.
- `.vscode/`, `.gitignore`, GitHub PR/issue templates, repo health files.
