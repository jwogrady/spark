# How to get started with Spark

> How-to — task-oriented.

Do this once. Spark's promise is your standards **loaded once, carried
everywhere** — this is the loading. Four steps: install the plugin, make the
shipped standard yours, arm a repo, run the lifecycle.

Before starting, check the machine meets the
[supported-environment contract](../reference/compatibility.md) — or just run
`spark doctor --requirements` after step 1 and follow its remediation lines.
And before arming a repo, `spark profiles` shows the available setup profiles
— pick one with `spark setup --profile <name>` when the shipped Python + uv
default isn't the project's stack.

## 1. Install the plugin

Point `/plugin marketplace add` at the Spark repo — the repo carries its own
`marketplace.json` — then install the core plugin from it. In Claude Code:

```text
/plugin marketplace add jwogrady/spark
/plugin install spark
```

The shorthand resolves to the repo's Git URL; the explicit equivalent is
`/plugin marketplace add https://github.com/jwogrady/spark.git`. A local clone
works the same way: `/plugin marketplace add ~/src/spark`.

After install, the eight core skills are available everywhere
(`/spark:ideate` … `/spark:ship`, `/spark:bootstrap`, `/spark:knowledge`,
`/spark:agents-md`) and the `spark` CLI is on your `$PATH`. Verify:

```bash
spark doctor
```

The same marketplace also carries the companion plugins — `spark-audit`,
`spark-connect`, and `spark-docs` — each installable with
`/plugin install <name>` when you need it.

## 2. Review the defaults, override what isn't yours

Spark works with zero setup because a full set of defaults ships inside the
plugin — [`preferences/defaults.json`](../../preferences/defaults.json), the
machine form of the
[engineering-preferences standard](../reference/engineering-preferences.md).
See what you would get as-is:

```bash
spark preferences
```

Each row shows a key, its resolved value, and the tier it came from:
`default` (shipped), `operator` (yours), or `project` (a committed per-repo
exception). Where Spark's opinions (Python + `uv`, Release Please, GitHub
Actions) differ from yours, say so once — in your operator override file,
which lives with you, not with any repo:

```bash
mkdir -p ~/.config/spark
$EDITOR ~/.config/spark/preferences.json
```

Flat JSON, string values, only the keys you are changing — key names are
exactly those in `defaults.json`:

```json
{
  "stack.default": "typescript-bun"
}
```

Run `spark preferences` again: overridden keys now show `operator`, and every
key you left out keeps its shipped default. You never fork the whole bag.
(Spark honors `$XDG_CONFIG_HOME` if you point your config elsewhere.)

## 3. Arm a repo: `spark setup`

Carrying your standard into a repo is always an explicit motion — nothing
copies itself silently. From inside the repo:

```bash
spark setup
```

One idempotent run does the whole carry-in:

- **Git hooks** — `commit-msg` and `pre-commit` enforce the commit rules and
  block direct commits to trunk. Existing non-Spark hooks are left untouched.
- **Permission baseline** — Spark's conservative allowlist
  ([`settings/permission-baseline.json`](../../settings/permission-baseline.json))
  is merged into `.claude/settings.json` after you confirm; `--yes` skips the
  prompt.
- **Resolved standard** — your three-tier preferences materialize as project
  files, create-only: what the repo already has is kept and reported
  (`+ created`, `= exists, kept`, `! needs a manual decision`), never
  overwritten.

A second run reports everything as already present. Starting a brand-new
project instead? `/spark:bootstrap` scaffolds the runtime and ends by running
`spark setup` for you — see [bootstrap.md](bootstrap.md).

When one project must deviate ("this one is TypeScript because it is a
frontend"), record only the exception in that repo's committed
`.spark/preferences.json` — the deviation stays visible and reviewable instead
of tribal.

## 4. Run the lifecycle

The repo is armed. Take an idea through the five stages:

```text
/spark:ideate → /spark:plan → /spark:codify → /spark:validate → /spark:ship
```

**Done when** `spark preferences` shows your values sourced from `operator`,
`spark setup` reports the repo armed, and `spark doctor` is healthy. Start with
the [tutorial](../tutorials/build-your-first-project.md) or go straight to
[ideate](ideate.md).

---

## Afterward: the granular verbs

`spark setup` fronts three verbs you can also run on their own:

- `spark install-git-hooks` — just the git hooks.
- `spark apply-permissions` — just the permission baseline. If the project has
  no `.claude/settings.json`, the baseline is copied in as-is; if one exists,
  missing rules are appended to `permissions.allow` only after you confirm
  (`--yes` skips the prompt) — nothing already in the file is changed or
  removed. Merging needs `jq` or `python3`; without either, the command prints
  the baseline's path so you can merge by hand. To carry the allowlist across
  every project, merge the same file into `~/.claude/settings.json` instead.
- `spark preferences --apply` — just the resolved standard.

The baseline is deliberately conservative: read-only git inspection, commits
and branch pushes (the PreToolUse guard still blocks force-pushes and pushes to
trunk), read-only `gh` queries plus `gh pr create`, and the `spark` setup
verbs. Nothing destructive — no `rm`, no `git reset`, no `gh pr merge`, no
releases.

Two housekeeping notes:

- **Published-marketplace install** — a one-click install from a published
  marketplace listing has not been validated end-to-end yet; it is tracked in
  [`ROADMAP.md`](https://github.com/jwogrady/spark/blob/master/ROADMAP.md).
  Until it lands, use the Git URL or local-clone path above.
- **Developing Spark itself** — test changes without publishing:
  `claude --plugin-dir /path/to/spark`, then `/reload-plugins` to pick up
  edits.
