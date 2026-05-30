# Code Quality Reviewer

**Date:** 2026-05-29
**Reviewer:** jwogrady

## Finding

Code quality is consistently high across all Bash scripts and Markdown documentation. The codebase demonstrates disciplined use of POSIX Bash, defensive programming, and minimal complexity. No linters are configured (linting is optional given the small footprint), but style is uniform and follows the stated standards (set -euo pipefail, imperative comments only, no dead code).

Script consistency is strong: every script in `bin/spark` and `scripts/hooks/` opens with `#!/usr/bin/env bash` and `set -euo pipefail`. Variable names are clear and consistent (e.g., `plugin_json`, `skill_name`, `error_msg`). Functions are short and focused.

Markdown quality is excellent: consistent formatting, proper use of code blocks, clear section hierarchies, and no orphaned links observed. Frontmatter in SKILL.md files is correctly formatted YAML.

**Complexity:** The most complex script is `guard-bash.sh` (~120 lines). Its logic is straightforward: parse the tool call JSON, extract the bash command, check for dangerous patterns. No nested functions, no global state mutations. Highest cyclomatic complexity appears to be ~5 (a reasonable level for this domain).

**Dead code:** None observed. All functions are used, all comments explain WHY not WHAT.

**Issues found:** Zero critical issues. One minor style inconsistency: some variables are quoted ("$var") while others rely on word splitting (acceptable in these contexts, but could be unified for consistency).

## Evidence

- **Bash scripts (`bin/spark`, `scripts/hooks/*`, `hooks/guard-bash.sh`):**
  - `bin/spark` lines 1–3: `#!/usr/bin/env bash` + `set -euo pipefail`
  - `scripts/hooks/commit-msg` lines 1–3: same pattern
  - `scripts/hooks/pre-commit` lines 1–3: same pattern
  - `scripts/shred-env.sh` lines 1–3: same pattern
  - All scripts validate inputs before using them
  - No pipes without `-o pipefail` consideration (all use `set -euo pipefail`)
  - Variable naming: `skill_name`, `plugin_json`, `hook_file`, `safe_chars` (all clear, no abbreviations)

- **Function design:**
  - `bin/spark`: main dispatcher with subcommands (doctor, new-skill, install-git-hooks, shred-env, help)
    - doctor: reads JSON, validates frontmatter (clean, ~30 lines)
    - new-skill: creates skill directory and stub SKILL.md (clean, ~15 lines)
    - install-git-hooks: copies hook scripts, makes them executable (clean, ~10 lines)
  - `hooks/guard-bash.sh`: most complex (~120 lines), but logic is linear (parse JSON, check patterns, block or allow)

- **Comments (WHY over WHAT):**
  - `guard-bash.sh` line 55: `# jq may not be available in all forks; fall back to python3 then regex`
  - `scripts/shred-env.sh` line 42: `# Refuse to shred template files; they're meant to be committed`
  - `scripts/hooks/commit-msg` line 18: `# No AI attribution (Claude, Anthropic, OpenAI, Copilot, etc.)`
  - All comments explain *why* a decision was made, not what the code does

- **Error handling:**
  - `bin/spark`: uses `[[ -f "$file" ]]` before reading, `[[ -d "$dir" ]]` before entering
  - `hooks/guard-bash.sh`: safely handles missing JSON with `2>/dev/null`, degrades gracefully
  - `scripts/shred-env.sh`: checks file exists before attempting delete, verifies deletion after

- **Markdown style consistency:**
  - All SKILL.md files have consistent frontmatter (name:, description:)
  - All how-to guides follow the same structure (> How-to — task-oriented, numbered steps, Done when...)
  - All reference docs use consistent tables and code blocks
  - Diátaxis structure is applied uniformly

- **Potential style improvements:**
  - Variable quoting: `grep "$pattern" "$file"` is safe, but `"$var"` is inconsistently applied in some contexts
  - One-liner conditionals: `[[ -f "$file" ]] && cat "$file"` appears in a few places (acceptable, but could be more explicit with `if [[ ... ]]`)

## Scoring

**Dimension:** Code clarity, consistency, and maintainability.

**Score:** 9

**Rationale:** Bash and Markdown quality is exemplary. Defensive programming (input validation, error handling, graceful degradation), consistent style, no dead code, and clear comments (WHY over WHAT). Deduction from 10 to 9: minor variable quoting inconsistency; no linter configured (optional, but would enforce uniform style).

## Notes to Next Agent

- **Testing:** No automated tests observed. The scripts are simple enough that manual testing may suffice, but unit tests for guard-bash.sh (testing JSON parsing, dangerous command detection, fallback mechanisms) would be valuable.
- **Error messages:** Error messages are clear and actionable (e.g., "Pre-commit guard: direct commits to 'master' are blocked. Create a feature branch first…"). No improvement needed.
- **Review skill:** The markdown structure for agent reports (.review-notes/ files) is well-defined in collaboration-protocol.md. Scripts should not need to parse these (humans read them).
- **Discoverability:** Consider adding a `spark lint` or `spark check-style` command to catch issues before commit, though this is optional given the small footprint.
