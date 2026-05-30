# Project Mapper

**Date:** 2026-05-29
**Reviewer:** jwogrady

## Finding

Spark is a Claude Code plugin (v0.2.0) serving as a portable SDLC toolkit. The codebase is well-organized around a 5-stage lifecycle (Ideate → Plan → Generate → Solve → Ship) with 14 skills distributed across language-agnostic POSIX Bash scripts, YAML manifests, and Markdown documentation.

Project structure is clean: 13 skills under `skills/`, enforcement hooks in `hooks/`, CLI dispatcher in `bin/spark`, documentation organized by Diátaxis (tutorial, how-to, reference, explanation). Plugin registration via `.claude-plugin/` manifest and marketplace.json.

Tech stack is intentionally minimal: POSIX Bash (zero runtime dependencies), JSON (for manifests), Markdown (for docs). No external build system, no runtime dependencies. Git hooks enforce conventional commits and no-commit-to-trunk. Approximately 2,500 lines of meaningful code (skills + docs, excluding lock files).

## Evidence

- **Repository structure:**
  - 13 skills in `skills/*/`: ideate, plan, build, fix-issue, review, commit, ship, bootstrap, connect, grill-me, claude-md, agents-md, write-a-skill, fork-init
  - `.claude-plugin/plugin.json`: v0.2.0, authored by jwogrady, installed via marketplace
  - `bin/spark`: CLI dispatcher with subcommands (doctor, new-skill, install-git-hooks, shred-env, help)
  - `hooks/hooks.json`: PreToolUse guard wiring; `hooks/guard-bash.sh`: blocks force-push and trunk pushes
  - `scripts/hooks/commit-msg`, `scripts/hooks/pre-commit`: git hooks (conventional commits, no commit to master)
  - `scripts/shred-env.sh`: secure-delete with fallback
  
- **Documentation (Diátaxis):**
  - `docs/tutorials/build-your-first-project.md`: walk-through all 5 stages
  - `docs/how-to/`: ideate, plan, build, solve, review, ship, install, bootstrap, connect
  - `docs/reference/`: skills, hooks, CLI, plugin-manifest
  - `docs/explanation/`: why-a-plugin, sdlc-doctrine, scope-and-upstream
  - `CLAUDE.md`: project guide (mission, standards, guardrails)
  - `AGENTS.md`: tool-agnostic agent contract
  - `README.md`: plugin overview, install
  - `ROADMAP.md`: v0.2 done, v0.3–v0.5 planned

- **Manifest validation:**
  - `.claude-plugin/plugin.json`: valid JSON, correct schema
  - `.claude-plugin/marketplace.json`: single plugin entry, correct structure
  - `skills/*/SKILL.md`: all have name: and description: frontmatter
  - `hooks/hooks.json`: valid JSON, PreToolUse event wired to guard-bash.sh

- **Entry points:**
  - Skill invocation: `/spark:<skill-name>` (Claude Code plugin namespace)
  - CLI: `bin/spark <command>` (doctor, new-skill, install-git-hooks, shred-env)
  - Git hooks: `scripts/hooks/commit-msg`, `scripts/hooks/pre-commit` (auto-installed via `spark install-git-hooks`)

- **Dependencies:**
  - Runtime: bash, git, standard POSIX utils (find, grep, wc, etc.)
  - Optional: jq, python3 (for JSON parsing fallback in guard-bash.sh; gracefully degrades if absent)
  - Zero external package dependencies; scripts work in any forked project

## Scoring

**Dimension:** Project clarity and structure.

**Score:** 9

**Rationale:** Repository is exceptionally well-organized for its purpose. Clear separation of concerns (skills, hooks, docs, CLI), self-contained design, zero external dependencies, and comprehensive documentation. Minor polish: a few doc links could be validated, and lock files (.git-locks, .github-lock) could be confirmed non-existent.

## Notes to Next Agent

- Review coverage is critical: `skills/review/` was just added (PR #7). Verify that the collaboration protocol and agent specs are clear and implementable.
- Documentation quality is high; check for broken links or outdated references.
- Enforcement hooks (git + PreToolUse) are in place; verify they're effective in preventing mistakes.
- No external package managers to audit (zero npm/pip/go.mod dependencies).
- All scripts are POSIX Bash; check for style consistency and error handling.
