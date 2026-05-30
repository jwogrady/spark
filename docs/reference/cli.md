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

## `spark install-git-hooks`

Copies `scripts/hooks/{commit-msg,pre-commit}` into the current repo's
`.git/hooks/` and marks them executable. If a hook already exists and is not a
Spark hook, it is left untouched and a warning is printed — move it aside first
if you want Spark's.

## `spark shred-env <file>`

Securely deletes a transient secrets file (e.g. `.env`) once its keys are stored
in 1Password: overwrites the bytes (via `shred`/`gshred`, or an overwrite-then-
remove fallback), then verifies the file is gone. Refuses to touch `*.tmpl` files
(those hold only `op://` references and are meant to be kept). Used by the
`connect` skill at the shred step. Never prints file contents.

## `spark help`

Prints usage.
