# Spark

Spark is a portable AI skills and agent configuration layer. You bring it to
every project. Skills, prompts, and agent configs travel with you — not locked
to any single repo.

## How it works

**Fork Spark into a new project.** Spark becomes the upstream. Your project is
the downstream. When Spark improves, pull those improvements in.

```
github.com/jwogrady/spark        ← upstream (engine + skills)
         │
         │  git clone → rename remote to upstream
         ▼
my-new-project/                  ← downstream (your project)
  remote: upstream → spark
  remote: origin   → your-org/my-new-project
```

See [fork-init](.spark/skills/fork-init/SKILL.md) for the full workflow.

**Use branches for project-type variants.** A branch can lock in the right
defaults for a given project type — language, toolchain, formatter, CI config —
while staying connected to Spark upstream.

```
spark/master           ← engine, skills, base config
spark/python-uv        ← Python + uv preset
spark/typescript       ← TypeScript + ESLint preset
spark/monorepo         ← monorepo layout preset
```

Downstream projects fork the branch that matches their stack.

**Pull Spark updates when the engine improves.**

```bash
git fetch upstream
git merge upstream/master
```

Project-specific config stays on the downstream branch. Engine improvements
come from upstream. Keep them separate and the model stays clean.

---

## Skills

Skills are reusable agent instruction sets. They travel to every project that
forks Spark.

### Productivity

| Skill | Description | Source |
|---|---|---|
| [caveman](.spark/skills/caveman/SKILL.md) | Ultra-compressed communication mode. Drops filler and pleasantries while keeping full technical accuracy. ~75% fewer tokens. | [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/caveman/SKILL.md) |
| [grill-me](.spark/skills/grill-me/SKILL.md) | Relentlessly interviews you about a plan or design, walking the decision tree branch by branch until reaching shared understanding. | [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/grill-me/SKILL.md) |
| [handoff](.spark/skills/handoff/SKILL.md) | Compacts the current conversation into a handoff document so a fresh agent can continue without losing context. | [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md) |
| [write-a-skill](.spark/skills/write-a-skill/SKILL.md) | Guides creation of new agent skills with proper structure, progressive disclosure, and bundled resources. | [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/write-a-skill/SKILL.md) |

### Spark

| Skill | Description |
|---|---|
| [agents-md](.spark/skills/agents-md/SKILL.md) | Generates and maintains `AGENTS.md` — the tool-agnostic AI agent behavioral contract for any project. |
| [claude-md](.spark/skills/claude-md/SKILL.md) | Generates and maintains `CLAUDE.md` for Spark-managed projects. Defines required sections, attribution rules, and agent safety rules. |
| [fork-init](.spark/skills/fork-init/SKILL.md) | Guides cloning Spark as an upstream seed, wiring a new downstream project repo, and running project inception from a branch. |

---

## Repo structure

```
.spark/
├── skills/      # reusable agent skills — travel to every downstream project
├── configs/     # project-type presets — basis for stack-specific branches
├── templates/   # document templates
├── prompts/     # structured prompts
└── issues/      # GitHub-ready issue drafts
```
