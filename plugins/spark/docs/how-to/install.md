# How to install Spark

> How-to — task-oriented.

## Install from the Git repo or a local clone (the verified path)

This is the install path verified today: point `/plugin marketplace add` at the
Spark repo itself — the repo carries its own `marketplace.json` — then install
the plugin from it.

From GitHub, in Claude Code:

```text
/plugin marketplace add jwogrady/spark
/plugin install spark
```

The shorthand resolves to the repo's Git URL; the explicit equivalent is
`/plugin marketplace add https://github.com/jwogrady/spark.git`.

Or from a local clone:

```bash
git clone https://github.com/jwogrady/spark.git ~/src/spark
```

then, in Claude Code:

```text
/plugin marketplace add ~/src/spark
/plugin install spark
```

After install, the lifecycle skills are available everywhere as `/spark:ideate`,
`/spark:plan`, `/spark:codify`, `/spark:validate`, `/spark:ship`,
and the `spark` CLI is on your `$PATH`.

Verify:

```bash
spark doctor
```

## One-click published-marketplace install (open item)

Installing Spark from a *published* marketplace listing — one click, no Git URL
or clone — has not been validated end-to-end yet. It is tracked as an open item
in [`ROADMAP.md`](https://github.com/jwogrady/spark/blob/master/ROADMAP.md).
Until it lands, use the Git URL or local-clone path above.

## Install the git hooks (per repo)

The plugin's PreToolUse guard covers commands Claude runs. To also enforce the
commit rules when *you* commit by hand, install the git hooks in a repo:

```bash
spark install-git-hooks
```

This copies `commit-msg` and `pre-commit` into the repo's `.git/hooks/`. Existing
non-Spark hooks are left untouched.

## Apply the permission baseline (optional)

A plugin can't bundle a full `settings.json`. To reduce permission prompts with a
curated, reusable allowlist, merge Spark's recommended permissions into your own
`~/.claude/settings.json` or the project's `.claude/settings.json`. Keep the
allowlist general (read-only inspection commands) — avoid pasting one-off,
session-specific commands, which is how a settings file rots.

## Local development of Spark itself

Test changes without publishing:

```bash
claude --plugin-dir /path/to/spark
```

Then `/reload-plugins` to pick up edits.
