# Reference — plugin manifest and layout

> Reference — information-oriented.

## Repository layout

```
.claude-plugin/
  plugin.json          # plugin manifest
  marketplace.json     # makes the repo git-installable as a marketplace
skills/<name>/SKILL.md  # lifecycle + carried-over skills
hooks/
  hooks.json           # PreToolUse wiring
  guard-bash.sh        # the guard the hook runs
scripts/hooks/         # git hook sources (commit-msg, pre-commit)
bin/spark              # the CLI, added to $PATH when active
docs/                  # this documentation (Diátaxis)
.github/ISSUE_TEMPLATE/ # issue templates the plan skill uses
```

## `plugin.json`

```json
{
  "name": "spark",
  "description": "…",
  "version": "0.2.0",
  "author": { "name": "jwogrady" },
  "homepage": "https://github.com/jwogrady/spark",
  "repository": "https://github.com/jwogrady/spark",
  "license": "MIT"
}
```

## `marketplace.json`

```json
{
  "name": "spark",
  "owner": { "name": "jwogrady" },
  "plugins": [
    { "name": "spark", "source": "./", "description": "…" }
  ]
}
```

`source: "./"` means the plugin is the repository root, so adding the repo as a
marketplace exposes a single plugin named `spark`.

## What the plugin bundles

Skills, the PreToolUse hook, and the `bin/spark` executable. It does **not**
bundle a full `settings.json` (only `agent` / `subagentStatusLine` are honored
by plugin settings) or git hooks — those are applied via the install how-to and
`spark install-git-hooks`.

See also why a plugin: [../adr/0001-plugin-not-framework.md](../adr/0001-plugin-not-framework.md).
