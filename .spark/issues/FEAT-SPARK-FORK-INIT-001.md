# [FEAT-SPARK-FORK-INIT-001] add fork-init skill for downstream project initialization

**Feature ID:** FEAT-SPARK-FORK-INIT-001
**Namespace:** spark.skills.fork-init
**Bounded Context:** Spark project inception workflow

---

## Problem

When a team wants to use Spark to bootstrap a new project, there is no documented
workflow for converting a Spark clone into a properly wired downstream project repo.
Users have to figure out remote configuration, branch naming, and upstream tracking
on their own. This leads to inconsistent setups and risks like overwriting remotes,
force-pushing, or losing the connection to Spark upstream.

---

## Proposed Behavior

Add a `fork-init` skill that guides users through:

1. Cloning Spark into a new project directory
2. Renaming the Spark remote to `upstream`
3. Adding the new project repo as `origin`
4. Creating an inception branch
5. Running `spark init` (placeholder until implemented)
6. Committing the generated project foundation
7. Pushing the inception branch and opening a PR

The skill documents the workflow and can produce multiple output formats
(shell sequence, checklist, GitHub issue, Claude Code prompt, troubleshooting
guide). It does not automate git commands or call GitHub APIs.

The skill also explains the mental model — Spark as upstream engine, the new
project as downstream consumer — and how downstream projects can pull Spark
updates later.

---

## Acceptance Criteria

- [ ] Add `.spark/skills/fork-init/SKILL.md`
- [ ] Add `.spark/skills/fork-init/agents/openai.yaml`
- [ ] Add `.spark/skills/fork-init/README.md` (recommended)
- [ ] Add `.spark/issues/FEAT-SPARK-FORK-INIT-001.md`
- [ ] Skill explains the upstream/downstream remote model clearly
- [ ] Skill provides a safe, manual, step-by-step git workflow
- [ ] Skill includes guardrails against destructive git commands (no force push,
      no silent remote overwrite, no automatic remote deletion)
- [ ] Skill asks for missing repo details before generating final commands
- [ ] Skill documents how downstream projects can later pull Spark updates
- [ ] Skill does not implement runtime automation
- [ ] Long schemas or prompts moved to `references/` if `SKILL.md` exceeds ~100 lines
- [ ] No AI system is credited anywhere in generated artifacts or commit messages

---

## Non-Goals

- Implementing `spark init` as a CLI command (separate feature)
- Calling GitHub APIs to create repos, open PRs, or manage labels
- Automating git remote configuration on behalf of the user
- Enforcing a specific downstream project directory structure beyond Spark templates
- Supporting non-GitHub remotes in v1

---

## Documentation Impact

- `CHANGELOG.md` — add entry under the next release
- `README.md` — mention `fork-init` in the skill index once a skill index section exists
- `.spark/skills/fork-init/SKILL.md` — primary documentation (created by this feature)

---

## Suggested Labels

- `enhancement`
- `skill`
- `documentation`
- `good first issue`

## Suggested Milestone

`v0.1 — Foundation`
