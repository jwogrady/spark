---
name: cleanup
description: Use when the user asks for /spark:cleanup or describes a repo cleanup, stale-code purge, stale-branch review, documentation truth audit, dependency cleanup, or full-codebase hygiene pass. Produces one copy-paste-ready orchestrator prompt that spins up a coordinated team of cleanup agents which prioritize evidence, safety, reversibility, and truthful documentation. Not for assessing project health or producing a review report — use `review`; cleanup removes what's proven dead or false and emits an orchestrator prompt rather than running the audit itself.
---

# Spark Cleanup

Command syntax: `/spark:cleanup`.

In Spark, the folder name is the command segment after `/spark:`. This skill lives in `skills/cleanup/` so the user can invoke it as `/spark:cleanup`. Keep the packaged skill name valid as `cleanup`; do not use `spark:cleanup` as YAML `name` because colon syntax is command routing, not a valid skill identifier.

## What this skill does

Given a cleanup request, output **one copy-pasteable orchestrator prompt** in a single markdown code block that directs Claude or another agentic coding system to run a coordinated cleanup team. The goal is not cosmetic refactoring. The goal is to remove what is false or dead: dead code, misleading docs, stale branches, obsolete assumptions, unused dependencies, duplicate patterns, broken scripts, outdated comments, old TODOs, test drift, and architecture fiction.

Return the prompt only. Do not wrap it in commentary unless the user asks for explanation or a different format.

## Non-negotiables

Carry these into every generated prompt. Evidence beats force; force beats nothing.

1. **No unsupported claims.** Every claim cites a file path, a command, or git evidence. Distinguish facts from hypotheses explicitly.
2. **Inspect before asserting.** Agents read the actual repository before making any claim or proposal.
3. **Every deletion proposal includes evidence** and a confidence level.
4. **Every doc change states what code proves it.** Make docs truthful, not flattering.
5. **Risky removals are isolated** — each in its own commit or patch group.
6. **Branch deletions distinguish** local vs remote and merged vs unmerged. Protected, default, and release branches are never deleted automatically.
7. **Generated, vendor, and build artifacts are identified before** any cleanup.
8. **Secrets are never printed.**
9. **Tests and builds are run when available.** If they cannot run, explain why and provide a manual validation plan.
10. **A human approval gate precedes** any remote-branch deletion or risky-code deletion.
11. **Adapt commands to the repo.** Package-manager and build commands are examples; detect the real toolchain first.
12. **Voice:** direct and forceful — but never at the expense of rules 1–4.

## Default agent roster

Include these unless the user customizes the team:

- **Orchestrator** — coordinates scope, dependencies, merge order, final judgment.
- **Cartographer** — maps structure, services, packages, entrypoints, generated code, deploy surfaces, ownership boundaries.
- **Historian** — git history, branch age, merge status, release tags, TODO age, old migration/context clues.
- **Static Analyst** — imports, exports, type errors, unused symbols, dependency graph, scripts, build config, lint failures.
- **Test Sentinel** — runs tests/builds, finds coverage gaps and broken/untested paths, validates cleanup changes.
- **Docs Auditor** — verifies README/docs/comments against actual behavior; fixes or deletes misleading documentation. In a project built with Spark, also flags **residual process framing** in product docs — phase/prompt status headers, `/spark:` stage references, and "later Spark stages" phrasing — caught mechanically with `rg -n 'Phase [0-9]|Prompt 0|/spark:|later Spark stage'` across docs and CHANGELOG. The build process belongs in Spark, not in the project's product docs.
- **Dead Code Reaper** — proposes removals with evidence, separates safe from risky, prepares small reversible patches.
- **Branch Janitor** — identifies stale/merged/abandoned/protected branches and the exact cleanup commands.
- **Dependency Medic** — finds unused, duplicated, vulnerable, deprecated, or mis-pinned dependencies.
- **Release Steward** — changelog/release notes, migration risks, rollback notes, PR summary.

## Required sections in the generated prompt

Mission · Operating rules · Agent roster · Repository intake checklist · Evidence map · Cleanup workstreams · Branch cleanup protocol · Documentation truth protocol · Deletion safety protocol · Execution phases · Required deliverables · Final report format.

## Evidence table

Every finding goes in a table with these columns:

`Area | Claim | Evidence (command or path) | Confidence | Action | Risk | Validation`

Confidence levels:
- **High** — proven by code references, successful command output, or git evidence.
- **Medium** — likely from static/graph analysis but not runtime-proven.
- **Low** — hypothesis needing human review.

Example row:

`Deps | "lodash unused" | rg "lodash" src/ -> no hits; not in package.json scripts | High | Remove from package.json | Low | Build + test pass after removal`

`Docs | "process framing in product docs" | rg "Phase [0-9]|Prompt 0|/spark:|later Spark stage" docs/ CHANGELOG.md -> 6 hits | High | Strip framing; keep content | Low | Links still resolve; content unchanged`

## Deletion categories

Force every candidate into one:

- **Safe delete** — generated artifacts, merged branches, files proven unreachable, docs proven false.
- **Needs review** — old feature code, ambiguous branches, unreferenced assets, migrations, fixtures, scripts, public APIs.
- **Do not delete** — default/protected/release branches, active migrations, audit/compliance artifacts, owner-less backups, customer data, secrets, production config, and anything referenced by deploy/runtime even when static analysis misses it.

## Final report

The generated prompt must end by requiring a report listing: docs changed, docs deleted, code deleted, branches recommended for deletion, risks, and validation status — followed by the literal line:

> Do not credit yourself. Credit the author/operator of the repository cleanup.

---

## Reference template

The exact orchestrator-brief shape to emit lives in
[`references/orchestrator-template.md`](references/orchestrator-template.md).
Load it when generating the prompt and adapt the specifics to the user's repo
and any team customization.
