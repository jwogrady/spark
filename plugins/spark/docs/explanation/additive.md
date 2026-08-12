# Why Spark is additive

> Explanation — understanding-oriented. The reasoning behind Spark's scope
> boundary and its delivery vehicle, in one place.

## The upstream principle

Spark does not redefine standards that Anthropic owns. The Claude Code skill
spec, the plugin format, MCP, the built-in review tools — those are upstream.
Spark's job is the **human-facing layer on top**: when do I reach for this, how
do I use it in a real GitHub workflow, what problem does it solve.

Practically, that means:

- Spark **references** the skill/plugin spec; it does not invent a competing one.
- The Validate stage **uses** `/code-review` and `/security-review`; it does not
  ship its own.
- When Anthropic's Claude Code docs change, that's the signal to update Spark.

The per-skill proof — which built-in each core skill delegates to or stays out
of the lane of — is the overlap section of
[reference/skills.md](../reference/skills.md).

## Why a plugin

Spark used to be a document-only `.spark/` folder that you forked into each
project and connected as a git upstream. That worked, but it fought the grain of
Claude Code in two ways: `.spark/` is not a path Claude Code scans for skills,
and forking-per-project meant the toolkit lived in N places at N versions.

Anthropic's official mechanism for a portable, opinionated toolkit you carry
into every project is a **Claude Code plugin distributed via a marketplace** —
which is also why the additive stance and the delivery vehicle are one
decision, not two. A single plugin can bundle nearly the whole toolkit:

- **skills** (`skills/`) — the lifecycle stages
- **hooks** (`hooks/hooks.json`) — enforcement that fires on Claude's tool use
- **executables** (`bin/`) — the `spark` CLI, on `$PATH` when the plugin is active
- **subagents** (`agents/`) and **MCP servers** (`.mcp.json`) — when needed

You install once (`/plugin marketplace add jwogrady/spark` → `/plugin install spark`)
and every project gets the same versioned toolkit. Commands are namespaced
(`/spark:ship`), which is a feature: it never collides with a project's own
skills and it's obvious where the command came from. The same marketplace
carries the companion plugins (`spark-audit`, `spark-connect`, `spark-docs`),
each installable and namespaced the same way.

## Distribution vs. inception

Two different needs that used to be tangled together:

- **Distribution** — "I want my toolkit available in this project." This is the
  plugin's job: install once, available everywhere.
- **Inception** — "I want to start a brand-new project." This is
  `/plugin install spark` followed by the `bootstrap` skill, which scaffolds the
  project runtime and wires it into Spark.

They no longer compete. You use the plugin in any existing project without
forking anything; and you start a fresh project the same way — install the
plugin, then run `bootstrap`.

## What a plugin can't carry — and how Spark handles it

A plugin cannot bundle a full `settings.json` (only `agent` and
`subagentStatusLine` keys are honored), and git hooks are not a plugin primitive.
So two pieces ship differently — through the CLI, in one command:
`spark setup` arms the current repo with the git hooks, the permission
baseline, and the resolved engineering standard (see
[the get-started guide](../how-to/get-started.md)). The pieces remain individually
addressable:

- **Permission baseline** → `settings/permission-baseline.json`, applied by
  `spark apply-permissions`.
- **Git hooks** (`commit-msg`, `pre-commit`) → installed by
  `spark install-git-hooks`.

This split is deliberate: the plugin enforces the *Claude-driven* path
(PreToolUse guard), git hooks enforce the *human-driven* local path, and the
shipped trunk-ruleset policy (`settings/github-ruleset-trunk.json`, applied
only by the operator) covers the remote. Same rules at every door.

## See also

The dated decision records (developer-only, in the Spark repo):
[ADR-0001](https://github.com/jwogrady/spark/blob/master/docs/adr/0001-plugin-not-framework.md)
(the plugin decision) and
[ADR-0002](https://github.com/jwogrady/spark/blob/master/docs/adr/0002-additive-to-anthropic-spec.md)
(the additive stance).
