# Reference — the `spark` CLI

> Reference — information-oriented.

`bin/spark` is added to `$PATH` while the Spark plugin is active. It resolves its
own location (following symlinks), so subcommands work from any directory.

## `spark doctor`

Validates the whole marketplace and reports health. Checks:

- `.claude-plugin/plugin.json` and `marketplace.json` are valid JSON
- `hooks/hooks.json` is valid JSON and `guard-bash.sh` is executable
- `preferences/defaults.json` is valid JSON and the templates carry the full
  standard set
- every directory under `skills/` has a `SKILL.md` with `name:` and
  `description:` frontmatter, and every agent file carries frontmatter too
- taxonomy parity: every shipped skill appears in the canonical
  [skills.md](skills.md) tables
- every companion plugin listed in the marketplace catalog passes the same
  manifest and skill checks as the core
- shell syntax: `bash -n` over `bin/spark`, the guard, and both git hooks
- doc links: every relative Markdown link in the shipped docs resolves
- enforcement parity: the commit types, AI-attribution ban, trunk protection,
  and force-push rules agree across the hooks and the contract files
  (CLAUDE.md, AGENTS.md)
- whether Spark's git hooks are installed in the current repo

Exit code is non-zero if any error is found. JSON validation uses `jq` or
`python3` if present, and is skipped (not failed) if neither is available.

### `spark doctor --requirements [--json]`

Environment readiness, grouped by the capability each dependency serves —
the structural checks above prove the plugin is intact; this answers whether
the *environment* can perform each Spark capability:

| Group | Dependencies | When it matters |
| --- | --- | --- |
| Core local workflow | `bash`, `git` | Everything — required |
| GitHub delivery | `gh`, authenticated | `plan`/`ship`/`validate` create issues and PRs |
| JSON tooling | `jq` or `python3` | Merging the permission baseline into an existing `.claude/settings.json`; everything else degrades gracefully |
| Release pipeline | repo wiring | `release-please-config.json` + workflow present when the resolved `release.mechanism` is `release-please`; other mechanisms are the operator's own |

Each missing or unauthenticated dependency prints one remediation line
(`gh auth login`, `spark preferences --apply`, …). The exit code is non-zero
only when a *core* tool is missing: optional integrations never fail the run,
so a conservative local-only environment stays healthy. `--json` emits the
same facts as one machine-readable object (built without any JSON parser)
for CI gates and troubleshooting. The human-readable contract behind this
check is the [supported-environment matrix](compatibility.md).

## `spark list-skills`

Lists every available skill with its one-line description, read from each
`skills/<name>/SKILL.md` frontmatter — a quick inventory of what the plugin
provides.

## `spark new-skill <name>`

Scaffolds `skills/<name>/SKILL.md` with a frontmatter stub. Refuses to overwrite
an existing skill. The name must be a plain slug — lowercase letters, digits,
and hyphens, not leading with a hyphen; anything else (path separators, `..`,
whitespace) is rejected with no filesystem change, since the name becomes a
path segment under `skills/`.

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
into an existing `.claude/settings.json` still prompts. The exit code
distinguishes decisions from failures: operator decisions — a declined merge,
a pending LICENSE choice, a merge no available tool can perform — are
reported, counted as attention, and exit `0`; **mechanical failures** — a
file that could not be written, an uncreatable hooks directory, broken
tooling — are counted separately, the summary says the repo is not fully
armed, and the exit is non-zero. Outside a git repo, and for invalid options
or excess arguments, the exit is also non-zero. The granular verbs below
remain the supported path for partial application.

## `spark install-git-hooks`

Copies `scripts/hooks/{commit-msg,pre-commit}` into the current repo's
`.git/hooks/` and marks them executable. A hook that is already Spark's and
current is reported and left as-is; if a hook exists and is not a Spark hook,
it is left untouched and a warning is printed — move it aside first if you
want Spark's (a decision, exit `0`). The exit is non-zero on a mechanical
failure: a hook source missing from the plugin, an uncreatable hooks
directory, or a copy that could not be written.

## `spark apply-permissions [--yes] [--preset delivery|conservative]`

Merges the selected permission baseline into the current project's
`.claude/settings.json` (anchored at the git repo root when inside one).
Copies the baseline as-is when no settings file exists; otherwise lists the
missing rules and appends them only after confirmation (`--yes` skips the
prompt). Existing entries are never changed, removed, or reordered, so
re-running is a no-op once every rule is present — and switching presets never
narrows an armed repo; removing rules is always a manual act. Merging into an
existing file requires `jq` or `python3`; without either, it prints the
baseline's path for a manual merge.

Two trust tiers ship as presets:

| Preset | Baseline | Grants |
| --- | --- | --- |
| `delivery` (default) | `settings/permission-baseline.json` | The full shipping loop: read commands plus `git add`/`commit`/`push`, `gh pr create`, `spark setup`. Push access is deliberately broad because the `PreToolUse` guard blocks the disallowed subset — force-pushes and pushes to trunk — including option, refspec, and compound-command forms (see [hooks.md](hooks.md#the-permission--guard-trust-boundary)). |
| `conservative` | `settings/permission-baseline-conservative.json` | Read-only inspection: `git status`/`log`/`diff`/`show`/`rev-parse`/`fetch`, `gh` views and lists, `spark doctor`, `bash -n`. Nothing that writes the repo or GitHub runs without a per-command prompt. |

The tier resolves like every other standard — an explicit `--preset` wins,
then the three-tier `permissions.preset` preference, then the shipped default
(`delivery`). Committing `{"permissions.preset": "conservative"}` to
`.spark/preferences.json` makes a project's posture a durable, reviewable
fact; the applied `.claude/settings.json` is itself the reviewable artifact.

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
fail the run. The exit is non-zero outside a git repo (no project to carry
into) and on a mechanical failure — an artifact that could not be written or
a template missing from the plugin.

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

## `spark version`

Prints the Spark plugin version, read from `.claude-plugin/plugin.json`.

## `spark help`

Prints usage.
