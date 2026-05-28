---
name: claude-md
description: Generate and maintain CLAUDE.md for Spark-managed project repos. Use when user wants to create, update, or audit a CLAUDE.md file.
---

# claude-md

**Feature ID:** FEAT-SPARK-CLAUDE-MD-001
**Namespace:** spark.skills.claude-md
**Bounded Context:** Spark AI agent workspace
**Status:** Draft — documents skill behavior; runtime generation not yet implemented

---

## Purpose

`claude-md` generates and maintains `CLAUDE.md` files for Spark-managed projects.
`CLAUDE.md` is the primary instruction file read by Claude Code when it opens a
repo. A well-structured `CLAUDE.md` reduces repeated corrections and keeps AI
agent behavior consistent across contributors and sessions.

---

## When to Create CLAUDE.md

Create `CLAUDE.md` when:

- Initializing a new project with `spark init`
- Onboarding a repo into Spark for the first time
- A project does not yet have a `CLAUDE.md`

Place `CLAUDE.md` at the repo root. There should be exactly one per repo.

## When to Update CLAUDE.md

Update `CLAUDE.md` when:

- Repo commands change (new tool, changed entrypoint, removed script)
- Workflow conventions change (new branch strategy, PR rules, etc.)
- A new skill is added that agents should know about
- Attribution or safety rules are revised
- A section becomes stale or inaccurate

Do not update `CLAUDE.md` speculatively. Only update when something has
actually changed or is missing.

---

## Required Sections

Every `CLAUDE.md` must include the following sections, in this order:

| Section | Purpose |
|---|---|
| **Project Mission** | One-paragraph description of what the project does and why it exists |
| **Repository Purpose** | What this specific repo is for (may differ from the product mission) |
| **Repo Map** | Directory tree or annotated list of key paths |
| **Common Commands** | Copy-paste commands for the most frequent dev tasks |
| **Development Workflow** | Branch, PR, review, and merge rules |
| **Skill Authoring Rules** | How to add or modify skills (Spark repos only) |
| **GitHub Integration Guardrails** | What agents may and may not do with GitHub |
| **Coding and Documentation Standards** | Language, formatter, linter, type hints, docstrings, comments |
| **Commit Rules** | Conventional commit format, scope, size, and message rules |
| **Attribution Rules** | Who gets credit; no AI credits |
| **Destructive Change Rules** | When to stop and ask before acting |
| **Agent Safety Rules** | Scope discipline, no invented integrations, TODO markers for unknowns |

Sections may be omitted only if they are genuinely not applicable (e.g., a pure
documentation repo with no code may omit Coding Standards). Mark omissions with
a brief note explaining why, so future contributors know it was intentional.

---

## Section Content Rules

### Project Mission
Write in plain English. One paragraph. State what the project does and why it
matters. Do not copy marketing copy. Do not use filler phrases ("cutting-edge",
"best-in-class").

### Repo Map
Show the top two or three levels of the directory structure. Annotate directories
that are not self-explanatory. Update when the structure changes.

```
.
├── .spark/           # Spark skills, templates, prompts, issues
│   ├── skills/       # one directory per skill
│   └── issues/       # GitHub-ready issue drafts
├── .vscode/          # VS Code workspace settings
├── docs/             # Project documentation
└── scripts/          # Dev automation scripts
```

### Common Commands
List actual commands from the repo, not generic placeholders. Use `uv run` for
Python projects managed with uv. If a command is not yet implemented, add a TODO
marker:

```bash
# TODO: implement spark init
uv run spark init
```

Do not invent commands that do not exist. Do not copy commands from other projects
without verifying they apply.

### Development Workflow
Document the actual branch and PR strategy. Include:
- What branch to work from
- Naming convention for branches
- PR requirements (review, CI, labels)
- Merge strategy (squash, merge commit, rebase)

### Skill Authoring Rules
For Spark repos, document:
- Where skills live (`.spark/skills/<name>/`)
- How to scaffold a new skill (`bash scripts/new-skill.sh <name>`)
- Required files per skill
- Testing requirements before merge

### GitHub Integration Guardrails
Specify what agents may and may not do autonomously with GitHub. Be explicit.
Default stance: agents may read but not write to GitHub without instruction.

### Coding and Documentation Standards
Specify:
- Primary language and version
- Package manager and environment tool
- Formatter (Black, Prettier, etc.) and configuration
- Linter (Ruff, ESLint, etc.) and what "passing" means
- Type hint requirements
- Docstring requirements
- Comment policy (explain why, not what)

### Commit Rules
Specify:
- Commit format (conventional commits is the default unless the repo says otherwise)
- Subject line length and mood
- Body requirements
- Scope rules
- History rewrite policy

### Attribution Rules
Apply these in every `CLAUDE.md`:

> Do not credit AI systems in any commit message, file header, comment,
> documentation, changelog, or generated file. Do not add `Co-Authored-By`
> lines for AI tools. Do not mention Claude, ChatGPT, OpenAI, Anthropic,
> Copilot, or any AI system unless the author explicitly requests it.
> Credit belongs to the human author only.

### Destructive Change Rules
Apply these in every `CLAUDE.md`:

Always ask before:
- Deleting files or directories
- Renaming public APIs, exported functions, or CLI commands
- Changing git remotes
- Force-pushing or resetting history
- Replacing useful existing content with generated content

When in doubt, ask.

### Agent Safety Rules
Apply these in every `CLAUDE.md`:

- Do only what was asked. Do not refactor surrounding code opportunistically.
- Do not introduce dependencies not required by the task.
- Do not implement features not in scope.
- Do not invent integrations, commands, or tool names that do not exist in the repo.
- If a command or configuration value is unknown, add a TODO marker instead of
  inventing a plausible-looking value.
- Inspect any existing file before modifying it.
- Preserve useful existing content unless clearly instructed to remove it.

---

## Behavior Rules for the Skill Itself

When the `claude-md` skill runs against a repo:

1. **Inspect first.** Read the existing `CLAUDE.md` if one exists. Do not
   overwrite blindly.
2. **Preserve useful content.** Repo-specific commands, workflow notes, and
   domain context that already exist should be kept unless they are wrong or
   duplicated.
3. **Add missing sections.** If a required section is absent, add it.
4. **Remove vague content carefully.** Only remove a section or instruction if
   it is clearly a placeholder, incorrect, or duplicated. When uncertain, keep it.
5. **Prefer real commands over placeholders.** Read the repo structure to find
   actual scripts, entrypoints, and tools. If a command cannot be verified, add
   a TODO marker.
6. **Do not invent integrations.** If the repo does not use a tool, do not
   document it as if it does.
7. **Keep it concise.** A long `CLAUDE.md` is less useful than a short, accurate
   one. Cut filler. Write directly.

---

## Outputs This Skill Can Produce

| Output Type | When to Use |
|---|---|
| **Full CLAUDE.md** | New repo with no existing `CLAUDE.md` |
| **Section patches** | Existing `CLAUDE.md` missing specific sections |
| **Section audit** | Existing `CLAUDE.md` to evaluate for staleness or gaps |
| **Diff review** | Proposed `CLAUDE.md` changes for human review before applying |

Ask the user which output they want if not specified.

---

## Non-Goals

- This skill does not implement `CLAUDE.md` generation as an automated CLI command.
- This skill does not modify any file without being explicitly invoked.
- This skill does not define project-specific commands — those come from reading
  the actual repo.
- This skill does not apply to `AGENTS.md` (covered by a separate skill).
