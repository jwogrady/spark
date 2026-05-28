# Changelog

All notable changes to this project will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

### Added

- `CLAUDE.md` — Claude Code instruction file, maintained by the `claude-md` skill
- `AGENTS.md` — tool-agnostic AI agent behavioral contract, maintained by the `agents-md` skill
- `.vscode/` — VS Code workspace settings, extensions, and tasks (tracked as a downstream template)
- `.claude/settings.local.json` — conservative Claude Code permission allowlist (not committed)
- `.gitignore` — standard Python ignores; re-includes `.vscode/` against global gitignore
- Skill: `fork-init` — upstream/downstream repo initialization workflow
- Skill: `claude-md` — CLAUDE.md generation and maintenance rules
- Skill: `agents-md` — AGENTS.md generation and maintenance rules
- Skill: `caveman` — ultra-compressed communication mode (imported from mattpocock/skills)
- Skill: `grill-me` — design interview skill (imported from mattpocock/skills)
- Skill: `handoff` — conversation handoff document skill (imported from mattpocock/skills)
- Skill: `write-a-skill` — skill authoring guide (imported from mattpocock/skills)
- `.spark/configs/` — directory for stack-specific branch presets (no presets yet)
- `.spark/issues/` — GitHub-ready issue drafts for all foundation features
- `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `ROADMAP.md`
- `.github/PULL_REQUEST_TEMPLATE.md` and issue templates

### Notes

- Runtime commands (`spark init`, etc.) are not yet implemented
- No CI, build system, or package is configured yet
- Skill runtime (automated invocation) is deferred to v0.3+
