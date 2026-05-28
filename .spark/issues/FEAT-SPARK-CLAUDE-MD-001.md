# [FEAT-SPARK-CLAUDE-MD-001] add claude-md skill for Claude Code project guidance

**Feature ID:** FEAT-SPARK-CLAUDE-MD-001
**Namespace:** spark.skills.claude-md
**Bounded Context:** Spark AI agent workspace

---

## Problem

`CLAUDE.md` files in Spark-managed projects are written once by hand and then
drift. There is no shared definition of what a `CLAUDE.md` must contain, no
enforcement of attribution or safety rules, and no way to audit or update one
consistently. Each project invents its own format, leading to inconsistent AI
agent behavior across repos.

---

## Proposed Behavior

Add a `claude-md` skill that defines how to generate and maintain `CLAUDE.md`
files for Spark-managed projects. The skill:

- Defines the required sections and their purpose
- Specifies attribution, commit, destructive change, and agent safety rules
  that must appear in every `CLAUDE.md`
- Documents how the skill should inspect existing content before modifying it
- Documents how to preserve useful repo-specific guidance
- Forbids invented integrations and fake commands
- Requires TODO markers when commands or values are unknown
- Supports multiple output modes: full generation, section patch, section
  audit, diff review

The skill does not implement runtime generation. It documents the workflow for
a human or AI agent to follow.

---

## Acceptance Criteria

- [ ] Add `.spark/skills/claude-md/SKILL.md`
- [ ] Add `.spark/skills/claude-md/agents/openai.yaml`
- [ ] Add `.spark/issues/FEAT-SPARK-CLAUDE-MD-001.md`
- [ ] Skill defines all required `CLAUDE.md` sections
- [ ] Skill specifies that existing `CLAUDE.md` content must be inspected before
      modification
- [ ] Skill specifies that useful existing content must be preserved
- [ ] Skill includes attribution rules (no AI credits, author only)
- [ ] Skill includes commit rules (conventional commits, small commits, no
      force push, no history rewrite)
- [ ] Skill includes destructive change rules (ask before deleting, renaming,
      changing remotes, force operations, replacing content)
- [ ] Skill includes GitHub integration guardrails (no autonomous API calls,
      drafts before automation)
- [ ] Skill forbids invented integrations and fake commands
- [ ] Skill requires TODO markers instead of invented commands
- [ ] Skill does not implement runtime CLI automation

---

## Non-Goals

- Implementing `CLAUDE.md` generation as an automated CLI command (separate feature)
- Managing `AGENTS.md` (covered by a separate skill)
- Enforcing a specific project directory structure
- Calling GitHub APIs to validate repo state

---

## Documentation Impact

- `CHANGELOG.md` — add entry under the next release
- `CLAUDE.md` — add note that it is maintained using the Spark `claude-md` skill
- `.spark/skills/claude-md/SKILL.md` — primary documentation (created by this feature)

---

## Suggested Labels

- `enhancement`
- `skill`
- `documentation`
- `dx`

## Suggested Milestone

`v0.1 — Foundation`
