![status](https://img.shields.io/badge/status-foundation-blue)
![runtime](https://img.shields.io/badge/runtime-not%20implemented%20yet-lightgrey)
![skills](https://img.shields.io/badge/skills-enabled-purple)
![github--native](https://img.shields.io/badge/github--native-project%20inception-black)
![license](https://img.shields.io/badge/license-TBD-lightgrey)

# Spark

**A GitHub-native project inceptor for AI-assisted software development.**

Spark gives AI agents a portable, reusable skill layer — skills, prompts, agent
configs, and project templates that travel from repo to repo. Fork Spark into a
new project, wire up GitHub, and let the skill chain do the scaffolding.

> **Current status:** Foundation only. Skills and documentation are implemented.
> Runtime commands (`spark init`, `spark new`, etc.) are not yet implemented.
> Do not expect CLI tooling to work yet.

---

## Why Spark exists

Every AI-assisted project starts the same way: bootstrap a repo, write a
`CLAUDE.md`, figure out the branch strategy, set up the issue tracker, scaffold
the directory structure. Then do it all again for the next project.

Spark makes that work reusable. Build a skill once, carry it everywhere.

---

## What Spark does

- **Portable skills** — agent instruction sets that live in `.spark/skills/` and
  travel to every downstream project via the upstream/downstream git model.
- **Stack preset branches** — a `spark/python-uv` branch, a `spark/typescript`
  branch, each carrying the right defaults for that project type. Fork the branch
  that matches your stack.
- **GitHub-native project metadata** — issue templates and PR templates are
  included today. Milestone and wiki generation are planned for v0.4. GitHub is
  the public operating surface; the repo is the source of truth.
- **AI workspace config** — `CLAUDE.md` and `AGENTS.md` generated from skills,
  not written from scratch. Agent behavior is consistent across projects.

---

## How Spark works

### The skill chain

```
debate idea
    ↓
run skill chain
    ↓
generate project artifacts
    ↓
create GitHub issues / wiki / project plan
    ↓
Claude implements
    ↓
review + iterate
```

### The upstream/downstream model

Fork Spark into a new project. Spark becomes the upstream. Your project is the
downstream. When the Spark engine improves, pull those improvements in.

```
github.com/jwogrady/spark        ← upstream (engine + skills)
         │
         │  git clone → rename remote to upstream
         ▼
my-new-project/                  ← downstream (your project)
  remote: upstream → spark
  remote: origin   → your-org/my-new-project
```

See [fork-init](.spark/skills/fork-init/SKILL.md) for the step-by-step workflow.

### Stack preset branches

Branches carry project-type defaults. Fork the branch that matches your stack.

```
spark/master        ← engine, skills, base config
spark/python-uv     ← Python + uv + Black + Ruff preset
spark/typescript    ← TypeScript + ESLint + Prettier preset
spark/monorepo      ← monorepo layout preset
```

---

## What's included today

| Category | What's here |
|---|---|
| Skills | 7 skills (see index below) |
| Workspace config | `CLAUDE.md`, `AGENTS.md`, `.vscode/` |
| GitHub templates | PR template, issue templates |
| Configs | `configs/` directory established (no presets yet) |
| Runtime | Not implemented |

---

## Skills

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
│   └── <name>/
│       ├── SKILL.md              # required
│       ├── agents/openai.yaml    # required
│       ├── README.md             # recommended
│       └── references/           # optional — long schemas, prompts, examples
├── configs/     # project-type presets — basis for stack-specific branches
├── templates/   # document templates
├── prompts/     # structured prompts
└── issues/      # GitHub-ready issue drafts
.github/
├── PULL_REQUEST_TEMPLATE.md
└── ISSUE_TEMPLATE/
.vscode/         # VS Code workspace settings (tracked as a downstream template)
CLAUDE.md        # Claude Code instruction file (maintained by claude-md skill)
AGENTS.md        # tool-agnostic agent guide (maintained by agents-md skill)
```

---

## Roadmap

| Version | Theme | Status |
|---|---|---|
| v0.1 | Foundation — skills, workspace config, GitHub templates | In progress |
| v0.2 | iloop — interactive project inception loop | Planned |
| v0.3 | spark init — runtime CLI command | Planned |
| v0.4 | GitHub-native sync — issue/wiki/project plan generation | Planned |
| v0.5 | Stack preset branches — python-uv, typescript, monorepo | Planned |

See [ROADMAP.md](ROADMAP.md) for detail.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: feature branch → PR → review.
One concern per PR. Conventional commits. No AI attribution.

---

## Attribution

Do not credit AI systems in any commit, PR, comment, doc, or generated file.
Credit belongs to the author.
