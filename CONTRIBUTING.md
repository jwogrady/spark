# Contributing

## How work is tracked

GitHub issues are the work ledger. Every feature, bug, and skill addition
starts as an issue before any code is written. Issue drafts for planned work
live in `.spark/issues/` until they are opened on GitHub.

## Branches

Work on a feature branch. Never commit directly to `master`.

Branch naming:
- `feat/<short-description>` — new feature or skill
- `fix/<short-description>` — bug fix
- `docs/<short-description>` — documentation only
- `chore/<short-description>` — maintenance, tooling, config

## Pull requests

One concern per PR. Keep PRs small and reviewable.

Use the PR template. Fill in the summary and test plan. Reference the issue.

## Commits

Use [conventional commits](https://www.conventionalcommits.org/):

```
feat: add typescript stack preset
fix: correct remote URL in fork-init step 3
docs: update AGENTS.md skill authoring section
chore: add .editorconfig
```

Subject line: imperative mood, under 72 characters, no trailing period.
Body: explain why, not what. Reference issues when relevant.

Do not rewrite published history. Do not force push to shared branches.

## Proposing a skill

To add a new skill:

1. Open a GitHub issue using the **Skill** issue template.
2. Get feedback before writing anything.
3. Create the skill in `.spark/skills/<name>/`:
   - `SKILL.md` — required
   - `agents/openai.yaml` — required
   - `README.md` — recommended
   - `references/` — optional, for long schemas or prompts
4. Open a PR referencing the issue.

Imported skills must include their source URL in `README.md`.

## Attribution

Do not credit AI systems in any commit message, PR, comment, code, doc,
changelog, or generated file. Do not add `Co-Authored-By` lines for AI tools.
Credit belongs to the human author only.
