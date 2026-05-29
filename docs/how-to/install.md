# How to install Spark

> How-to — task-oriented.

## Install the plugin (carry it into every project)

```text
/plugin marketplace add jwogrady/spark
/plugin install spark
```

After install, the lifecycle skills are available everywhere as `/spark:ideate`,
`/spark:plan`, `/spark:build`, `/spark:fix-issue`, `/spark:commit`, `/spark:ship`,
and the `spark` CLI is on your `$PATH`.

Verify:

```bash
spark doctor
```

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
