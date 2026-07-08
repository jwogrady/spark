# agents-md — Examples

## New Spark repo, no existing AGENTS.md, CLAUDE.md provided

Input:
- repo_name: acme-platform
- repo_description: Internal developer platform for Acme Corp.
- existing_claude_md: (full text of CLAUDE.md)
- primary_language: Python
- package_manager: uv
- formatter: Black
- linter: Ruff
- test_command: uv run pytest
- is_spark_repo: true
- output_mode: full_generation

Expected: a complete AGENTS.md with all 10 required sections, derived from
the provided CLAUDE.md rules and restated in tool-agnostic language.

## Sync audit — compare AGENTS.md against CLAUDE.md

Input:
- repo_name: acme-platform
- existing_agents_md: (full text of current AGENTS.md)
- existing_claude_md: (full text of CLAUDE.md)
- output_mode: sync_audit

Expected: an audit report identifying drift between the two files.
Example drift: "Attribution Rules present in CLAUDE.md but absent from AGENTS.md."

## No inputs provided

Input: (none)

Expected: the skill asks for repo_name, repo_description, existing_claude_md,
primary_language, package_manager, formatter, linter, test_command, and
is_spark_repo before generating output.
