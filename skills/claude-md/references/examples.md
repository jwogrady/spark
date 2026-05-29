# claude-md — Examples

## New Spark repo, no existing CLAUDE.md

Input:
- repo_name: acme-platform
- repo_description: Internal developer platform for Acme Corp.
- primary_language: Python
- package_manager: uv
- formatter: Black
- linter: Ruff
- test_command: uv run pytest
- branch_strategy: feature branches off master, squash merge via PR
- is_spark_repo: true
- output_mode: full_generation

Expected: a complete CLAUDE.md with all 12 required sections, using the
provided inputs for commands and standards.

## Existing CLAUDE.md missing required sections

Input:
- repo_name: acme-platform
- existing_claude_md: (full text of existing CLAUDE.md)
- output_mode: section_patch

Expected: only the missing sections are generated; existing content is preserved.

## Audit for staleness

Input:
- repo_name: acme-platform
- existing_claude_md: (full text of existing CLAUDE.md)
- output_mode: section_audit

Expected: a report identifying which sections are present, missing, or
potentially stale.

## No inputs provided

Input: (none)

Expected: the skill asks for repo_name, repo_description, primary_language,
package_manager, formatter, linter, test_command, and branch_strategy before
generating output.
