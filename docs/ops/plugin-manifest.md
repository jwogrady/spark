# Reference — plugin manifest and layout

> Reference — information-oriented.

## Repository layout

The repo is a four-plugin marketplace: a catalog at the repo root lists the
focused core plus three companions, each under `plugins/<name>/` (ADR-0014).

```
.claude-plugin/
  marketplace.json              # marketplace catalog — lists all four plugins
plugins/spark/                  # the core plugin (the shipping loop)
  .claude-plugin/plugin.json    # plugin manifest
  skills/<name>/SKILL.md        # the core skills (/spark:<name>)
  agents/knowledge/*.md         # the knowledge crew subagents
  hooks/
    hooks.json                  # PreToolUse wiring
    guard-bash.sh               # the guard the hook runs
  scripts/hooks/                # git hook sources (commit-msg, pre-commit)
  bin/spark                     # the CLI, added to $PATH when active
  docs/                         # USER docs (ship with the plugin), Diátaxis
plugins/spark-audit/            # companion: assessment + evidence-backed cleanup
plugins/spark-connect/          # companion: services, secrets, shred-env
plugins/spark-docs/             # companion: public docs via author personas
docs/                           # DEV docs (repo root, never shipped): ADRs,
                                # architecture, packaging reference (this file)
.github/ISSUE_TEMPLATE/         # issue templates the plan skill uses
```

Each companion mirrors the core's shape at its own root: a
`.claude-plugin/plugin.json` manifest, `skills/` (namespaced under the plugin
name, e.g. `/spark-audit:audit`), and `agents/` where the plugin carries a
crew.

## `plugins/<name>/.claude-plugin/plugin.json`

Each plugin's manifest: name, description, `version` (maintained by Release
Please on that plugin's own release train — never hand-bump it; ADR-0016),
author (`jwogrady`), homepage/repository, and the MIT license field. The
files themselves are the single source of truth; this page deliberately
embeds no copy of them, because an embedded copy goes stale on every release.

Every companion additionally declares `"dependencies": ["spark"]` — the
plugin-spec field for cross-plugin edges. The companions hand work to the
core's skills and call the `spark` CLI, so the dependency is real: declaring
it lets Claude Code enable the core transitively when a companion is enabled
(and fail loudly when it can't) instead of leaving a standalone companion
install with dangling handoffs. `spark doctor` errors on a companion manifest
that loses the declaration. No semver constraint is pinned while the
companions are prerelease and the core moves fast (Alpha holds backwards
compatibility as a non-goal); revisit constraints at v1.

Each companion also carries its own `CHANGELOG.md` at the plugin root,
written by Release Please, so the release history ships to consumers with
the plugin. The core's changelog stays at the repo root.

## `.claude-plugin/marketplace.json`

The marketplace catalog: the marketplace `name` and owner, and a `plugins`
array with one entry per plugin, each pointing at `./plugins/<name>`. Read
the file for the current values.

`source: "./plugins/spark"` means that plugin's root is the `plugins/spark/`
directory, not the repo root. Adding the repo as a marketplace exposes all
four plugins; installing is per-plugin (`/plugin install spark`,
`/plugin install spark-audit`, …). Only what lives under `plugins/` ships to
users. The root `docs/` tree (ADRs, architecture, this reference) is
developer documentation and never ships.

The catalog references directories, not versions — a Claude Code marketplace
serves the repository's current state, so each `plugin.json` is the version
of record and the tags/changelogs are the durable history (ADR-0016).

## What the core plugin bundles

Skills, the knowledge crew, the PreToolUse hook, the `bin/spark` executable,
and the user docs under `plugins/spark/docs/`. It does **not** bundle a full
`settings.json` (only `agent` / `subagentStatusLine` are honored by plugin
settings) or git hooks — those are applied via `spark setup` or
`spark install-git-hooks`, which copies them from
`plugins/spark/scripts/hooks/`.

See also why a plugin: [../adr/0001-plugin-not-framework.md](../adr/0001-plugin-not-framework.md),
and the core/companion boundary: [../adr/0014-core-plus-companion-plugins.md](../adr/0014-core-plus-companion-plugins.md).
