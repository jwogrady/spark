# [FEAT-SPARK-AGENTS-MD-001] add agents-md skill for tool-agnostic AI agent guidance

**Feature ID:** FEAT-SPARK-AGENTS-MD-001
**Namespace:** spark.skills.agents-md
**Bounded Context:** Spark AI agent workspace

---

## Problem

`AGENTS.md` is the tool-agnostic companion to `CLAUDE.md`, but there is no
shared definition of what it must contain, no enforcement of attribution or
safety rules, and no mechanism to detect when it has drifted from `CLAUDE.md`.
Each project either omits `AGENTS.md` entirely or writes it once and lets it
rot. AI agents from non-Claude tools then operate without a behavioral contract,
leading to inconsistent behavior across contributors and tools.

---

## Proposed Behavior

Add an `agents-md` skill that defines how to generate and maintain `AGENTS.md`
files for Spark-managed projects. The skill:

- Defines the required sections and their purpose
- Derives rules from `CLAUDE.md` rather than inventing them independently
- Flags drift between `AGENTS.md` and `CLAUDE.md` rather than silently resolving it
- Specifies attribution, commit, destructive action, scope, and GitHub guardrails
  that must appear in every `AGENTS.md`
- Documents how to preserve useful existing content
- Forbids invented integrations and fake commands
- Requires TODO markers when commands or values are unknown
- Supports multiple output modes: full generation, section patch, sync audit,
  diff review

The skill does not implement runtime generation. It documents the workflow for
a human or AI agent to follow.

---

## Acceptance Criteria

- [ ] Add `.spark/skills/agents-md/SKILL.md`
- [ ] Add `.spark/skills/agents-md/agents/openai.yaml`
- [ ] Add `.spark/skills/agents-md/README.md` (recommended)
- [ ] Add `.spark/issues/FEAT-SPARK-AGENTS-MD-001.md`
- [ ] Skill defines all required `AGENTS.md` sections
- [ ] Skill specifies that `CLAUDE.md` should be read before generating `AGENTS.md`
- [ ] Skill specifies that rules should be derived from `CLAUDE.md`, not invented
- [ ] Skill includes a sync audit output mode that detects drift between the two files
- [ ] Skill includes attribution rules (no AI credits, author only)
- [ ] Skill includes commit rules (conventional commits, no force push, no history rewrite)
- [ ] Skill includes destructive action rules (ask before deleting, force ops, etc.)
- [ ] Skill includes GitHub integration guardrails (no autonomous API calls)
- [ ] Skill includes scope discipline rules (no opportunistic refactors or extras)
- [ ] Skill forbids invented integrations and fake commands
- [ ] Skill requires TODO markers instead of invented commands
- [ ] Long schemas or prompts moved to `references/` if `agents/openai.yaml` grows unwieldy
- [ ] Skill documents the relationship between `agents-md` and `claude-md` skills
- [ ] Skill does not implement runtime CLI automation

---

## Non-Goals

- Implementing `AGENTS.md` generation as an automated CLI command (separate feature)
- Managing `CLAUDE.md` (covered by the `claude-md` skill)
- Enforcing tool-specific agent settings beyond `AGENTS.md` content
- Calling GitHub APIs to validate repo state

---

## Documentation Impact

- `CHANGELOG.md` — add entry under the next release
- `AGENTS.md` — add note that it is maintained using the Spark `agents-md` skill
- `.spark/skills/agents-md/SKILL.md` — primary documentation (created by this feature)

---

## Suggested Labels

- `enhancement`
- `skill`
- `documentation`
- `dx`

## Suggested Milestone

`v0.1 — Foundation`
