# Reference — the `spark` CLI

> Reference — information-oriented.

`bin/spark` is added to `$PATH` while the Spark plugin is active. It resolves its
own location (following symlinks), so subcommands work from any directory.

## `spark doctor`

Validates the Spark layout and reports health. Checks:

- `.claude-plugin/plugin.json` and `marketplace.json` are valid JSON
- `hooks/hooks.json` is valid JSON and `guard-bash.sh` is executable
- every directory under `skills/` has a `SKILL.md` with `name:` and
  `description:` frontmatter
- whether Spark's git hooks are installed in the current repo

Exit code is non-zero if any error is found. JSON validation uses `jq` or
`python3` if present, and is skipped (not failed) if neither is available.

## `spark list-skills`

Lists every available skill with its one-line description, read from each
`skills/<name>/SKILL.md` frontmatter — a quick inventory of what the plugin
provides.

## `spark new-skill <name>`

Scaffolds `skills/<name>/SKILL.md` with a frontmatter stub. Refuses to overwrite
an existing skill.

## `spark setup [--yes]`

The one-command carry-in (ADR-0012): arms the current repo in one run by
composing the three arming steps in order — `install-git-hooks`, then
`apply-permissions`, then the `preferences --apply` engine — and ending with
one aggregate line across all three steps:
`Setup: N created, N kept, N need attention.` (green only when nothing needs
attention). Skipped conflicting hooks, a declined or impossible permission
merge, and every `!` item from the standard all land in the attention count.
Each step is the same function its own verb dispatches to, so `setup` and the
granular commands cannot drift. Re-running is a no-op: hooks report as
already installed, the baseline as already applied, and the standard as kept.

`--yes` forwards to the permission-merge confirmation; without it, merging
into an existing `.claude/settings.json` still prompts. A declined or
unmergeable permission step is reported and the run continues — for a valid
invocation, the exit is non-zero only outside a git repo (invalid options or
excess arguments are usage errors and also exit non-zero). The granular verbs
below remain the supported path for partial application.

## `spark install-git-hooks`

Copies `scripts/hooks/{commit-msg,pre-commit}` into the current repo's
`.git/hooks/` and marks them executable. A hook that is already Spark's and
current is reported and left as-is; if a hook exists and is not a Spark hook,
it is left untouched and a warning is printed — move it aside first if you
want Spark's.

## `spark apply-permissions [--yes]`

Merges `settings/permission-baseline.json` — Spark's conservative
`permissions.allow` list — into the current project's `.claude/settings.json`
(anchored at the git repo root when inside one). Copies the baseline as-is when
no settings file exists; otherwise lists the missing rules and appends them only
after confirmation (`--yes` skips the prompt). Existing entries are never
changed, removed, or reordered, so re-running is a no-op once every rule is
present. Merging into an existing file requires `jq` or `python3`; without
either, it prints the baseline's path for a manual merge.

## `spark preferences [--show | --apply]`

The carry-in verb for the engineering standard. Bare (or with `--show`) it
prints the standard resolved across the three tiers of ADR-0010 — shipped
defaults (`preferences/defaults.json` in the plugin), operator overrides
(`~/.config/spark/preferences.json`, honoring `XDG_CONFIG_HOME`), and project
facts (`<repo>/.spark/preferences.json`) — first a header listing each tier's
path and whether it exists, then one line per key: the key, its resolved
value, and the winning source (`[default]`, `[operator]`, or `[project]`;
later tiers win). It works outside a git repo too: the project tier is
reported as absent and the standard resolves from defaults plus operator
overrides alone.

`--apply` carries the resolved standard into the current repo through the
same create-only engine `bootstrap` uses, reporting each item as `+ created`,
`= exists, kept`, or `! needs a manual decision`, with a summary line. An
existing file is a project choice and is never overwritten, so re-running is
a no-op once everything is in place; attention items are advisory and do not
fail the run — the exit is non-zero only outside a git repo, where there is
no project to carry into.

The machine source carries *what to apply*; the *why* stays in the prose
standard, [engineering-preferences.md](engineering-preferences.md).

## `spark resume`

Rebuilds "where you were / what's next" from the committed work state at
`.spark/state.json` ([schema](state.md)), written by the lifecycle skills at
each stage's close-out. Every recorded fact is cross-checked against the live
repo before it is shown — branch existence and checkout via git, issue and PR
state via `gh` when available, the problem statement's presence on disk — and
whatever drifted is flagged with a `!` line: the repo is the truth, the state
is a claim. With no state file it prints how to get one; a malformed file
degrades to "no facts could be read", never an invented answer. Exits 0 in
both cases; exits 1 only outside a git repo. For the three-line automatic
version at session start, see `spark brief`.

## `spark brief [--short]`

Prints the session brief in three sections. **Orient** — current branch,
uncommitted-file count, ahead/behind the tracked upstream, and (full mode
only) the open PR for the branch via a `gh` fast-path, skipped when `gh` is
absent. **Locate** — the lifecycle position, read from `.spark/state.json`
(see [state.md](state.md)) when a lifecycle skill has written it, otherwise
inferred from repo shape (problem statement present, trunk vs. working branch,
open PR); `spark resume` gives the full cross-checked view. **Load** — the
resolved standard bag summarized: how many preference keys resolved, how many
the operator or project tiers override, plus the `stack.default` and
`release.mechanism` headlines; `spark preferences` prints the complete
resolution table.

`--short` is the SessionStart hook path (see [hooks.md](hooks.md)): at most
three plain-text lines, no color codes, no network calls. Outside a git repo
it prints nothing and exits `0`, so non-project sessions start clean.

## `spark help`

Prints usage.
