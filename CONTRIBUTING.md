# Contributing

## One-time setup: install the git hooks

Spark's commit rules are enforced mechanically by git hooks (`commit-msg`
checks the message format, `pre-commit` blocks direct commits to trunk).
Hooks live in your local `.git/hooks`, so every contributor installs them
once per clone:

```
./plugins/spark/bin/spark install-git-hooks
```

(`spark setup` runs the same install as part of its one-command carry-in, so if
you have already armed the repo with it, the hooks are in place.)

`spark doctor` fails inside this repo until the hooks are installed, so a
skipped install cannot go unnoticed.

## How work is tracked

GitHub issues are the work ledger. Every feature, bug, and skill addition
starts as an issue before any code is written. Use the `plan` skill to break a
problem statement into scoped work items and a milestone scaffold, and the
templates in `.github/ISSUE_TEMPLATE/` to file the issues (generating the GitHub
issues directly from `plan` is a v0.4 goal; today you create them from its
output).

### Planning fields

The issue templates carry four lightweight planning fields:

- **Priority** — P0 (urgent) to P3 (someday); maps to the repo's `P0`–`P3` labels.
- **Category** — the theme the issue belongs to (DX, UX, Architecture, …); maps
  to the theme labels where one exists.
- **Dependencies** — `Blocked by` / `Blocks` lists. Always use real GitHub issue
  numbers (e.g. `Blocked by #86`), never draft-local numbering.
- **Size** — a rough S/M/L effort estimate.

All four are optional. Fill in what you know; skip what you don't.

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

## Testing

Two gates run on every PR, and both are one local command:

- `./plugins/spark/bin/spark doctor` — the static gate: layout, JSON,
  frontmatter, `bash -n`, doc links, enforcement parity.
- `bash tests/run.sh` — the behavioral gate: every `tests/test-*.sh` suite,
  exercising the CLI flows (`setup`, `apply-permissions`, `preferences`,
  `brief`/`resume`, `new-skill`) and the enforcement hooks (`guard-bash.sh`,
  `commit-msg`, `pre-commit`) against throwaway git repos and a private copy
  of the plugin. Suites never touch the checkout, your `$HOME`, or the
  network, and need nothing beyond bash, git, and jq/python3.

Scope and limits: the suites assert the *contracts* — exit semantics,
artifacts created or refused, allow/block decisions — not every output line.
Skill behavior (the Markdown prompts) has no automated coverage; that gap is
deliberate and documented in the enforcement-model explanation.

When you change a tested script, run `bash tests/run.sh` before pushing and
extend the matching suite; a new tested surface gets a new `tests/test-*.sh`
(the runner picks it up by name).

## Changelog policy

Hand-curated changelog entries go only under the `[Unreleased]` heading in
`CHANGELOG.md`. Release Please owns the released sections: on each release it
moves unreleased entries under a version heading and adds the generated notes.
Never edit a released section by hand — it is the historical record of what
shipped.

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
