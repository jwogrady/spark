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
problem statement into scoped work items and a milestone scaffold — it creates
the GitHub issues directly through its deterministic issue-manifest helper
(#214) — or file them by hand with the templates in
`.github/ISSUE_TEMPLATE/`.

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

Commit when one coherent problem → solution step is complete and sensibly
checked — a branch normally carries several focused commits that tell the
implementation story. Avoid per-edit WIP/checkpoint commits, and avoid holding
everything back for one end-of-work commit. Unrelated work becomes another
issue and another branch.

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

One check is deliberately outside the runner:
`bash tests/e2e-marketplace-install.sh` validates the *published* marketplace
install path end to end from a clean environment (marketplace add, core +
companion install, discovery, the `spark` CLI, and a real skill invocation).
It needs network access and the `claude` CLI, so it runs by hand — treat it
as the release-readiness check before merging a Release Please PR. It runs
on every documented platform: the live-invocation step bounds itself with
`timeout`, or `gtimeout` where GNU coreutils is a Homebrew install (macOS),
and otherwise notes the degraded soft bound (`--max-turns` still limits the
run). The selection logic is pinned offline by
`tests/test-e2e-bounded-run.sh`.

## Changelog policy

The changelog has one canonical policy with two modes, keyed on whether the
repo runs Release Please (a `release-please-config.json` at the root):

**Release Please-managed (this repo).** Your **conventional commit types are
the only changelog input**. Release Please maintains every section of
`CHANGELOG.md` from the commits on the trunk, and the open Release Please PR is
the canonical view of unreleased changes — there is no hand-curated
`[Unreleased]` heading to add to. Never hand-edit `CHANGELOG.md`: released
sections are the immutable record of what shipped (correct a factual error only
with clear evidence, never a rewrite). Put the user-facing change in the commit
subject/body — that is what reaches the changelog.

**Manual (scaffolded projects without Release Please).** Curate
`## [Unreleased]` by hand; `ship` rolls it into a dated `vX.Y.Z` section at
release time. This is the fallback the `ship` skill documents.

Either way, run the
[release-docs checklist](plugins/spark/docs/reference/release-docs-checklist.md)
before a release is approved, so README, docs, changelog, roadmap, and release
metadata stay coherent (ADR-0006, ADR-0009).

## Planning & issue metadata

Work is tracked with GitHub-native metadata, one canonical location per fact —
category on a taxonomy label, release target on a milestone, dependencies on
native blocked-by/sub-issue links, priority on `P0`–`P3`. The full model,
category taxonomy, milestone rules, and the metadata-completeness audit live in
[metadata-governance.md](plugins/spark/docs/reference/metadata-governance.md).
The essentials:

- **One category per issue** from `issue.taxonomy` (`feature bug documentation
  chore tech-debt research infrastructure`); never the old `enhancement` alias.
  `spark doctor` checks the issue forms against the taxonomy.
- **A milestone is release scope**, and issue order within it is delivery
  priority. A `vX.Y …` milestone maps to the `X.Y.*` release.
- **No feature starts without a release decision** — milestone, backlog+reason,
  or blocked+decision — and Spark proposes rather than silently assigns.
- **Each milestone has one release-readiness issue** that carries its scope as
  native sub-issues and closes last.

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

## Code of conduct

Participation is governed by the [Contributor Covenant](CODE_OF_CONDUCT.md).
Report unacceptable behavior through the private channel described there.
