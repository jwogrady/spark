# Reference — skills

> Reference — information-oriented. What each skill is, not how to use it well
> (that's [how-to/](../how-to/)) or why it exists (that's
> [explanation/](../explanation/)).

All skills are invoked namespaced under the plugin: `/spark:<name>`.

## Lifecycle skills

| Skill | Stage | Triggers on |
|---|---|---|
| `ideate` | Ideate | Starting something new; "I want to build X"; fuzzy scope |
| `plan` | Plan | Breaking work into features/issues; scoping a milestone |
| `build` | Generate | Implementing an issue; writing the code for planned work |
| `fix-issue` | Solve | Reviewing/hardening a change; resolving review findings |
| `commit` | Ship | Committing; writing a commit message |
| `ship` | Ship | Pushing; opening a PR |

## Carried-over skills

| Skill | Purpose |
|---|---|
| `grill-me` | Interview-style stress-testing of a plan/design. Used by `ideate`. |
| `claude-md` | Generate and maintain a project's `CLAUDE.md`. |
| `agents-md` | Generate and maintain a project's `AGENTS.md`. |
| `write-a-skill` | Author a new skill with correct structure. |
| `fork-init` | Scaffold a brand-new project from Spark as a seed. |

## Skill layout

Each skill is a directory under `skills/` containing at minimum a `SKILL.md`
with YAML frontmatter:

```yaml
---
name: <matches the directory name>
description: <what it does>. Use when <specific triggers>.
---
```

The `description` is the only thing Claude sees when deciding whether to invoke
the skill, so it must name concrete triggers. Optional `references/` and
`agents/` subdirectories hold supporting material loaded on demand.
