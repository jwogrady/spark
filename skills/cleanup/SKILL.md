---
name: cleanup
description: >-
  Use when the user asks for /spark:cleanup or describes a repo cleanup,
  stale-code purge, stale-branch review, documentation truth audit, dependency
  cleanup, or full-codebase hygiene pass. Produces one copy-paste-ready
  orchestrator prompt that spins up a coordinated team of cleanup agents which
  prioritize evidence, safety, reversibility, and truthful documentation.
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
- **Docs Auditor** — verifies README/docs/comments against actual behavior; fixes or deletes misleading documentation.
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

Emit a prompt of this shape, adapting specifics to the user's repo and any team customization. This is the contract for what good output looks like.

```markdown
# Repository Cleanup — Orchestrator Brief

You are the **cleanup lead**. Coordinate a team of specialist agents to remove dead code, false documentation, stale branches, and unused dependencies from this repository. Evidence first, force second. Inspect the real repo before any claim. Cite paths and commands. Never delete without supporting evidence.

## Mission
Remove what is false or dead — not what is merely ugly. Leave the repo provably smaller, truer, and safe to ship.

## Operating rules
- No unsupported claims. Cite a path, command, or git fact for everything.
- Mark each finding as Fact or Hypothesis.
- Run tests/builds when available; if not, give a manual validation plan.
- Never print secrets. Identify generated/vendor/build artifacts first.
- Isolate risky changes in their own commit/patch group.
- Adapt all package-manager/build commands to this repo's real toolchain.

## Agent roster
Orchestrator, Cartographer, Historian, Static Analyst, Test Sentinel, Docs Auditor, Dead Code Reaper, Branch Janitor, Dependency Medic, Release Steward. See per-agent charters below.

## Repository intake checklist
- [ ] Detect languages, package manager, build/test commands
- [ ] Map entrypoints, services, packages, deploy surfaces
- [ ] Identify generated/vendor/build/artifact paths and exclude from deletion
- [ ] Inventory branches: local vs remote, merged vs unmerged, protected/default
- [ ] Locate docs and the code each claims to describe

## Evidence map
Build one table — every row is a finding:
| Area | Claim | Evidence (command/path) | Confidence | Action | Risk | Validation |
Confidence: High proven / Medium static-only / Low hypothesis.

## Cleanup workstreams
1. Dead code  2. Documentation truth  3. Branches  4. Dependencies  5. Scripts/build config  6. Tests/coverage drift
Each workstream outputs evidence-table rows, never bare assertions.

## Branch cleanup protocol
- Classify each branch: merged | unmerged | stale | protected/default/release.
- Provide exact commands, separating local (`git branch -d/-D`) from remote (`git push origin --delete`). Never auto-delete remote or protected branches.

## Documentation truth protocol
- For each doc claim, find the code that proves or disproves it.
- Fix it to match reality or delete it. State the proving code for every change.

## Deletion safety protocol
Every candidate -> Safe delete | Needs review | Do not delete.
Risky deletes isolated per commit. Human approval gate before remote-branch deletion or any risky-code deletion.

## Execution phases
1. Map & intake read-only   2. Evidence gathering read-only   3. Proposals & categorization   4. Human approval gate   5. Apply safe deletes in small patches   6. Validate tests/build   7. Truth report

## Required deliverables
- Completed evidence table
- Categorized deletion list
- Branch action list local/remote, merged/unmerged
- Patch/PR plan grouped by category
- Truth report

## Final report format
List: docs changed, docs deleted, code deleted, branches recommended for deletion, risks, validation status.

Do not credit yourself. Credit the author/operator of the repository cleanup.
```
