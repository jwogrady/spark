# Reference — plugin manifest and layout

> Reference — information-oriented.

## Repository layout

The repo is a one-plugin marketplace: a catalog at the repo root points at the
installable plugin under `plugins/spark/`.

```
.claude-plugin/
  marketplace.json              # marketplace catalog — points at ./plugins/spark
plugins/spark/                  # the installable plugin (everything that ships)
  .claude-plugin/plugin.json    # plugin manifest
  skills/<name>/SKILL.md        # lifecycle + carried-over skills (/spark:<name>)
  agents/<crew>/*.md            # subagent crews (docit, knowledge)
  hooks/
    hooks.json                  # PreToolUse wiring
    guard-bash.sh               # the guard the hook runs
  scripts/
    hooks/                      # git hook sources (commit-msg, pre-commit)
    shred-env.sh                # helper the connect skill uses
  bin/spark                     # the CLI, added to $PATH when active
  docs/                         # USER docs (ship with the plugin), Diátaxis
docs/                           # DEV docs (repo root, never shipped): ADRs,
                                # architecture, packaging reference (this file)
.github/ISSUE_TEMPLATE/         # issue templates the plan skill uses
```

## `plugins/spark/.claude-plugin/plugin.json`

The plugin manifest: name, description, `version` (maintained by Release
Please — never hand-bump it), author (`jwogrady`), homepage/repository, and
the MIT license field. The file itself is the single source of truth; this
page deliberately embeds no copy of it, because an embedded copy goes stale
on every release.

## `.claude-plugin/marketplace.json`

The marketplace catalog: the marketplace `name` and owner, and a `plugins`
array whose single entry points at `./plugins/spark`. Read the file for the
current values.

`source: "./plugins/spark"` means the plugin root is the `plugins/spark/`
directory, not the repo root. Adding the repo as a marketplace exposes a single
plugin named `spark`; only what lives under `plugins/spark/` ships to users.
The root `docs/` tree (ADRs, architecture, this reference) is developer
documentation and never ships.

## What the plugin bundles

Skills, the agent crews, the PreToolUse hook, the `bin/spark` executable, and
the user docs under `plugins/spark/docs/`. It does **not** bundle a full
`settings.json` (only `agent` / `subagentStatusLine` are honored by plugin
settings) or git hooks — those are applied via the install how-to and
`spark install-git-hooks`, which copies them from
`plugins/spark/scripts/hooks/`.

See also why a plugin: [../adr/0001-plugin-not-framework.md](../adr/0001-plugin-not-framework.md).
