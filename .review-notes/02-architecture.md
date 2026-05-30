# Architecture Reviewer

**Date:** 2026-05-29
**Reviewer:** jwogrady

## Finding

Spark's architecture is exemplary: clean separation of concerns, self-contained skills, zero cross-skill dependencies at runtime, and decoupled enforcement (PreToolUse hook + git hooks). The design favors composition over inheritance and avoids premature abstraction.

**Layer structure:**
- Plugin layer (`.claude-plugin/`): manifest, marketplace registration
- Skill layer (`skills/*/`): each skill is self-contained YAML + Markdown + optional references/
- Enforcement layer (`hooks/` + `scripts/hooks/`): PreToolUse guard + git hooks (no shared state)
- Tooling layer (`bin/spark`): CLI dispatcher for human-driven commands
- Documentation layer (`docs/` + markdown files): Diátaxis-structured narrative

**Key patterns:**
- **Plugin-based composition:** Skills are discovered and invoked via `/spark:` namespace. No shared runtime state between skills.
- **Graceful degradation:** guard-bash.sh parses JSON with jq, falls back to python3, then degrades to raw text matching. Fails safe (blocks on regex match, never auto-approves).
- **Evidence-first collaboration:** review skill uses shared `.review-notes/` directory as the collaboration mechanism (read/write markdown files).
- **Guardrail-first enforcement:** Pre-commit hooks block mistakes on both agent-driven (PreToolUse) and human-driven (git hooks) paths.

**Testability:**
- Each skill can be tested in isolation (no cross-skill imports).
- Guard-bash.sh can be unit-tested with mock tool calls and JSON variants.
- Git hooks can be tested by attempting commits with various messages/branches.
- CLI commands (doctor, new-skill, install-git-hooks, shred-env) are scriptable and verifiable.

**Scalability:**
- Adding new skills is trivial: mkdir skills/newskill, create SKILL.md, invoke with `/spark:newskill`.
- No central registry needed (discovery is filesystem-based).
- Plugin loads on demand (skills are read from disk when invoked).

**Potential weaknesses:**
1. **Skill discoverability:** No centralized skill registry or help command that lists all skills with descriptions. New users must browse the filesystem or read docs/reference/skills.md.
2. **State sharing:** review skill assumes agents can write to `.review-notes/`. If two reviews run concurrently, there could be race conditions. No locking mechanism.
3. **Error recovery:** guard-bash.sh silently degrades from jq → python3 → regex. If regex wrongly matches (unlikely but possible), a dangerous command could slip through.
4. **Dependency on git hooks:** Git hooks are user-installed via `spark install-git-hooks`. If a user skips this, trunk commits are possible. No enforcement at plugin-load time.

## Evidence

- **Plugin-based design:**
  - `.claude-plugin/plugin.json`: declarative manifest (name, version, author, homepage)
  - `marketplace.json`: makes the repo installable as a marketplace plugin
  - Skills are stateless (no shared global variables across skill invocations)
  - Example: `skills/commit/` and `skills/ship/` are adjacent but independent (no imports)

- **Skill self-containment:**
  - Each skill has SKILL.md with frontmatter (name, description)
  - Optional references/ subdirectory (bootstrap/references/profiles.md, connect/references/recipes.md, review/references/agent-specs.md, etc.)
  - No Python imports, no Ruby requires, no Node require() statements (all self-contained Markdown)

- **Enforcement decoupling:**
  - PreToolUse hook (hooks/hooks.json) wires to hooks/guard-bash.sh for agent-driven Bash
  - Git hooks (scripts/hooks/commit-msg, pre-commit) for human-driven commits
  - Both enforce the same rules (conventional commits, no force-push, no trunk commits) but independently
  - If PreToolUse fails, git hooks still protect; if git hooks fail, PreToolUse still protects

- **Graceful degradation (guard-bash.sh lines 40–75):**
  - Attempts jq: `echo "$tool_call" | jq '.params.command' 2>/dev/null`
  - Falls back to python3: `python3 -c "import json; ..."`
  - Falls back to regex: raw text matching on `--force` and `--force-with-lease`
  - Each tier is conservative (blocks on match, never auto-approves)

- **Review skill collaboration:**
  - Agents write to `.review-notes/00-project-map.md`, `.review-notes/01-documentation.md`, etc.
  - Each agent reads prior files before writing
  - No database, no state file, no shared memory (pure filesystem)
  - Synthesis Lead reads all 7 reports and consolidates

- **Testability:**
  - guard-bash.sh can be tested by calling it directly with mock tool calls (JSON variants)
  - Git hooks can be tested by attempting commits (pre-commit prevents master commits, commit-msg prevents AI attribution)
  - CLI can be tested by running `spark doctor`, `spark new-skill test`, etc.
  - Skills themselves are inert (Markdown); invoking a skill delegates to Claude, which reads the SKILL.md

## Scoring

**Dimension:** Design coherence, modularity, and scalability.

**Score:** 8

**Rationale:** Architecture is clean, well-separated, and appropriately constrained. Plugin-based composition is correct for the problem (portable toolkit). Enforcement is decoupled and defense-in-depth. Graceful degradation is implemented correctly. Deduction from 9 to 8: no centralized skill registry (minor usability gap); review skill has no concurrency protection (low-probability issue for current use case, but worth noting); git hook installation is opt-in rather than enforced.

## Notes to Next Agent

- **Code quality:** Check if all scripts consistently use `set -euo pipefail` and avoid unsafe patterns (unquoted variables, pipe failures, etc.).
- **Guardrail effectiveness:** Has the force-push guard and no-trunk-commit guard actually prevented mistakes in practice? Are there any known bypasses?
- **Review skill:** Verify that the agent handoff protocol (shared `.review-notes/`) is actually usable in practice (file locks, concurrency, cleanup).
- **Documentation:** Consider adding a "how to discover skills" section or a `spark list-skills` command for better discoverability.
