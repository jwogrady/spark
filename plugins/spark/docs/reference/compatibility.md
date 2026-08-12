# Reference — supported environments

> Reference — information-oriented.

The one canonical compatibility contract for Spark: what the core plugin and
each companion need from the operating environment, what is required versus
optional, and what degrades gracefully when an optional tool is absent.

`spark doctor --requirements` ([CLI reference](cli.md#spark-doctor---requirements---json))
is the executable form of this contract — it probes the live environment and
reports the same groups this page documents. If the command and this page
disagree, one of them has drifted; treat that as a bug.

## Operating environment

| Surface | Supported | Notes |
| --- | --- | --- |
| Operating system | Linux, macOS, Windows via WSL2 | CI runs `ubuntu-latest`; macOS and WSL2 use the same POSIX-friendly scripts. Native Windows (PowerShell/cmd) is not supported. |
| Shell | Bash | Every shipped script declares `#!/usr/bin/env bash` with `set -euo pipefail` and avoids Bash-4-only features (no `mapfile`, associative arrays, or case conversion) — so the macOS system Bash 3.2 works. Exercised in CI on Bash 5. |
| Git | 2.x | Hooks are installed via `git rev-parse --git-path` (Git ≥ 2.5). Tested on current releases. |
| Claude Code | A version with plugin-marketplace support | Spark installs via `/plugin marketplace add jwogrady/spark` and relies on skills, `PreToolUse` hooks, and `SessionStart` hooks — the standard plugin spec, nothing undocumented. |

## Core plugin dependencies

The same five groups `spark doctor --requirements` reports (the fifth — the
remote-enforcement door — reuses the GitHub delivery row's dependency: an
authenticated `gh`, degrading to "not assessed" without it):

| Tool | Tier | Serves | Without it |
| --- | --- | --- | --- |
| `bash`, `git` | **Required** | Everything — the CLI, both local enforcement doors, the whole local loop | Spark does not run. This is the only group whose absence fails `doctor --requirements`. |
| `gh`, authenticated | Capability: GitHub delivery | `plan`, `ship`, and `validate` create and read issues and PRs; `brief`/`resume` verify recorded state against live GitHub | The local loop still works. Issue/PR steps are unavailable, and `brief`/`resume` report GitHub-backed facts as unverified instead of inventing them. Remediation: install <https://cli.github.com>, then `gh auth login`. |
| `jq` (preferred) or `python3` | Capability: safe JSON merges | Merging the permission baseline into an *existing* `.claude/settings.json`; JSON validation in `doctor` | With neither: preference reading degrades to a line-based parser for the documented flat schema, `doctor`'s JSON checks are skipped (not failed), and `apply-permissions` refuses the merge with hand-merge instructions rather than risking the file. Creating a fresh `settings.json` needs no parser. |
| Release-pipeline wiring | Capability: versioned releases | Release Please turns merged conventional commits into versions, changelogs, tags, and releases | Assessed only when the resolved `release.mechanism` is `release-please`; the wiring (`release-please-config.json` + workflow) is created by `spark preferences --apply` or `spark setup`. Any other mechanism is the operator's own machinery. |

One platform note beyond the groups: GNU `timeout` is not part of stock
macOS. No shipped Spark surface requires it — the Spark repo's own manual
release-readiness check selects `timeout` → `gtimeout` (Homebrew coreutils)
→ a documented soft bound, so macOS remains fully supported.

## Stack defaults

The shipped preferences name default stacks; the tools only matter in projects
that keep those defaults, and only when the matching work happens:

| Tool | Preference | Used when |
| --- | --- | --- |
| `uv` | `stack.default: python-uv` | `bootstrap` scaffolds a Python runtime; the shipped CI template runs uv-based checks in the *project's* CI (not required on the operator's machine by Spark itself) |
| `bun` | `stack.frontend: typescript-bun` | `bootstrap` scaffolds a TypeScript/JavaScript runtime |
| OpenTofu | `stack.infra: opentofu` | Recorded as the infrastructure preference for planning; Spark ships no infra templates yet, so nothing materializes and no local binary is required |

Override any of these per operator (`~/.config/spark/preferences.json`) or per
project (`.spark/preferences.json`) — see
[engineering preferences](engineering-preferences.md).

## Companion plugins

Each companion adds at most its own tools on top of the core contract:

| Plugin | Additional tools | Degradation |
| --- | --- | --- |
| `spark-audit` | None beyond the core (uses `gh` for evidence and filing, same tier as core's GitHub delivery) | Without `gh`, assessment still reads the repo; filing findings as issues is unavailable |
| `spark-connect` | 1Password CLI (`op`), authenticated — every credential lives in 1Password and the repo holds only `op://` references | Hard requirement for its job; there is no degraded mode for secrets. `shred-env` prefers `shred`/`gshred` and falls back to overwrite-then-remove where neither exists (macOS) |
| `spark-docs` | None beyond the core | — |

## Checking a machine

```bash
spark doctor --requirements          # human-readable, grouped by capability
spark doctor --requirements --json   # machine-readable, for CI gates
```

Exit code is non-zero only when a required core tool is missing — a
conservative, local-only environment is a supported configuration, not an
error.
