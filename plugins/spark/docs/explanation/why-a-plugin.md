# Why Spark is a plugin

> Explanation — understanding-oriented. The reasoning, not the steps.

Spark used to be a document-only `.spark/` folder that you forked into each
project and connected as a git upstream. That worked, but it fought the grain of
Claude Code in two ways: `.spark/` is not a path Claude Code scans for skills,
and forking-per-project meant the toolkit lived in N places at N versions.

## The decision

Anthropic's official mechanism for a portable, opinionated toolkit you carry
into every project is a **Claude Code plugin distributed via a marketplace**. A
single plugin can bundle nearly the whole toolkit:

- **skills** (`skills/`) — the lifecycle stages
- **hooks** (`hooks/hooks.json`) — enforcement that fires on Claude's tool use
- **executables** (`bin/`) — the `spark` CLI, on `$PATH` when the plugin is active
- **subagents** (`agents/`) and **MCP servers** (`.mcp.json`) — when needed

You install once (`/plugin marketplace add jwogrady/spark` → `/plugin install spark`)
and every project gets the same versioned toolkit. Commands are namespaced
(`/spark:ship`), which is a feature: it never collides with a project's own
skills and it's obvious where the command came from.

## What a plugin can't carry — and how Spark handles it

A plugin cannot bundle a full `settings.json` (only `agent` and
`subagentStatusLine` keys are honored), and git hooks are not a plugin primitive.
So two pieces ship differently:

- **Permission baseline** → ships as `settings/permission-baseline.json`, applied
  by `spark apply-permissions` (see [the install how-to](../how-to/install.md)).
- **Git hooks** (`commit-msg`, `pre-commit`) → installed by `spark install-git-hooks`.

This split is deliberate: the plugin enforces the *Claude-driven* path
(PreToolUse guard), while git hooks enforce the *human-driven* path. Same rules,
both doors covered.

## What this replaced

Project inception is no longer a separate skill: scaffolding a brand-new project
is just `/plugin install spark` followed by the `bootstrap` skill. Distribution
is the plugin's job. See [scope-and-upstream.md](scope-and-upstream.md).

See also the dated decision record: ../adr/0001-plugin-not-framework.md.
