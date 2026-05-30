# Contributing

## How work is tracked

GitHub issues are the work ledger. Every feature, bug, and skill addition
starts as an issue before any code is written. Use the `plan` skill to draft
issues from a problem statement, and the templates in `.github/ISSUE_TEMPLATE/`.

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
fix: correct remote URL in connect recipe
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
3. Scaffold the skill with `spark new-skill <name>` (creates `skills/<name>/`):
   - `SKILL.md` — required (`name` + `description` frontmatter)
   - `references/` — optional, for long schemas or prompts
   - `agents/` — optional, for agent definitions
4. Run `spark doctor` to confirm it's well-formed.
5. Open a PR referencing the issue.

Imported skills must include their source URL in a `README.md`.

## Attribution

Do not credit AI systems in any commit message, PR, comment, code, doc,
changelog, or generated file. Do not add `Co-Authored-By` lines for AI tools.
Credit belongs to the human author only.
