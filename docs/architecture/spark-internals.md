# Spark: architecture & internals

> Architecture map — how the layers fit together. The *why* lives in the linked
> ADRs and explanation docs; this doc ties the layers together and shows how they
> interact. For the reasoning behind individual decisions, follow the cross-links
> to [plugins/spark/docs/explanation/](../../plugins/spark/docs/explanation/) and [../adr/](../adr/).

## Purpose

Spark turns a Claude and a GitHub subscription into a software delivery system
for one operator running many projects: it loads the operator's engineering
standard into every repo, moves work through one traceable lifecycle from
intent to pull request, and enforces the git hygiene mechanically. The
methodology is portable; the current implementation ships as a **Claude Code
plugin marketplace** (author `jwogrady`, MIT) you add once and carry into every
project.

Who it is for: the solo operator directing an increasingly agent-run,
human-supervised workflow. The portable core is domain- and stack-neutral *as a
fact of the design*, not a market being pitched; outward positioning is the
`spark-docs` companion's job, not this map's.

For *why* a plugin rather than a framework, see
[../adr/0001-plugin-not-framework.md](../adr/0001-plugin-not-framework.md) and
[explanation/additive.md](../../plugins/spark/docs/explanation/additive.md). This doc is the
*map*; those are the *narrative*.

## Current State

Spark is a **four-plugin marketplace** (ADR-0014): the repo-root
`.claude-plugin/marketplace.json` catalog lists a focused core plus three
companions, each under `plugins/<name>/`:

- **`spark`** — the core: the shipping loop. `setup` (one-command carry-in),
  `bootstrap` (inception), the five lifecycle skills, preferences and project
  overrides, `brief`/`resume` and the durable work state, the two enforcement
  doors, `doctor`, Release Please scaffolding, `agents-md`, and `knowledge`.
- **`spark-audit`** — whole-project assessment and evidence-backed cleanup
  (`/spark-audit:audit`).
- **`spark-connect`** — service connectivity + secrets via 1Password
  (`/spark-connect:connect`), plus the `shred-env` helper.
- **`spark-docs`** — public docs and positioning through author personas
  (`/spark-docs:docit`).

Adding the marketplace
(`/plugin marketplace add jwogrady/spark`) makes all four installable;
`/plugin install spark` installs the core, and each companion installs by its
own name with skills namespaced under it. Only what lives under `plugins/`
ships to users; the repo-root `docs/` tree (ADRs, this map, packaging
reference) is developer documentation and never ships.

## Intended State

Two things are documented as intended/future, **not** current:

- **Per-stack scaffold branches.** Stack defaults (Bun for TS/JS, uv for
  Python) are shipped via `bootstrap`'s use of the official scaffolders, but
  there are **no** per-stack branches in this repo — that mechanism is planned,
  not implemented. The portable core is stack-neutral today.
- **A bundled `.mcp.json`** is a capability a plugin *can* carry when needed (see
  [explanation/additive.md](../../plugins/spark/docs/explanation/additive.md)), but Spark
  ships **no** `.mcp.json` at present.

## Components

The core plugin is layered:

| Layer | Lives in | Job | Reference |
|---|---|---|---|
| Marketplace catalog | `.claude-plugin/marketplace.json` (repo root) | Make the repo git-installable; lists the core + the three companions | [../reference/plugin-manifest.md](../reference/plugin-manifest.md) |
| Plugin manifests | `plugins/<name>/.claude-plugin/plugin.json` | Name and version each plugin (author `jwogrady`, MIT); companions version independently of the core | [../reference/plugin-manifest.md](../reference/plugin-manifest.md) |
| Skills | `plugins/spark/skills/<name>/SKILL.md` | The five lifecycle stages + `bootstrap`, `knowledge`, `agents-md`, exposed as `/spark:<name>` | [reference/skills.md](../../plugins/spark/docs/reference/skills.md) |
| Agent crew | `plugins/spark/agents/knowledge/*.md` | The knowledge crew (3 roles) the `knowledge` skill dispatches; companions carry their own crews | — |
| PreToolUse hook | `plugins/spark/hooks/hooks.json`, `plugins/spark/hooks/guard-bash.sh` | Enforce git hygiene on the **Claude-driven** path | [reference/hooks.md](../../plugins/spark/docs/reference/hooks.md) |
| CLI | `plugins/spark/bin/spark` | Validate the marketplace, carry the standard in, rebuild session context, scaffold skills | [reference/cli.md](../../plugins/spark/docs/reference/cli.md) |
| Git hooks | `plugins/spark/scripts/hooks/{commit-msg,pre-commit}` | Enforce the **same** rules on the **human-driven** path | [reference/hooks.md](../../plugins/spark/docs/reference/hooks.md) |
| User docs | `plugins/spark/docs/` | Ship with the plugin; Diátaxis-organized: tutorials / how-to / reference / explanation | — |
| Dev docs | `docs/` (repo root) | Never shipped: ADRs, this architecture map, packaging reference | — |

The CLI verbs: `doctor`, `list-skills`, `new-skill`, `setup`,
`install-git-hooks`, `apply-permissions`, `preferences`, `resume`, `version`,
`brief`, `help`. (`shred-env` moved to `spark-connect` with the connect skill —
it has no independent core purpose.)

```mermaid
flowchart TB
  subgraph Install["One marketplace, four plugins"]
    MP[".claude-plugin/marketplace.json<br/>(repo root)"]
    M["plugins/spark/<br/>(core: the shipping loop)"]
    CA["plugins/spark-audit/<br/>(/spark-audit:audit)"]
    CC["plugins/spark-connect/<br/>(/spark-connect:connect + shred-env)"]
    CD["plugins/spark-docs/<br/>(/spark-docs:docit)"]
    MP --> M
    MP --> CA
    MP --> CC
    MP --> CD
  end
  M --> S["plugins/spark/skills/&lt;name&gt;/SKILL.md<br/>(/spark:&lt;name&gt;)"]
  M --> H["plugins/spark/hooks/hooks.json → guard-bash.sh<br/>(PreToolUse: Claude door)"]
  M --> C["plugins/spark/bin/spark CLI<br/>(on $PATH)"]
  S --> A["plugins/spark/agents/knowledge/*.md<br/>knowledge crew (3 roles)"]
  C -->|setup / install-git-hooks| G["plugins/spark/scripts/hooks/<br/>commit-msg + pre-commit<br/>(human door)"]
  H -. same rules .- G
```

## Data Flow

Two flows run through Spark:

1. **Lifecycle flow** (`Ideate → Plan → Codify → Validate → Ship`). A skill is
   invoked as a `/spark:` command; its output is the next stage's input — a
   written problem statement feeds issue decomposition, which feeds a branch,
   which feeds review, which feeds a commit and PR. See
   [explanation/sdlc-doctrine.md](../../plugins/spark/docs/explanation/sdlc-doctrine.md) for the
   doctrine and the per-stage "done when". The `knowledge` skill hangs off the
   Ship+ end of the loop, capturing what the work taught.

2. **Enforcement flow** (the two doors — see below). Every git operation passes
   through one of two guards depending on who issued it.

## The two-doors enforcement model

Spark enforces the same git-hygiene rules through **two independent doors**,
because a git operation can arrive by two paths and a plugin hook only sees one
of them:

- **Claude-driven door** — the `PreToolUse` guard (`plugins/spark/hooks/hooks.json`
  → `plugins/spark/hooks/guard-bash.sh`) inspects each `Bash` git command before
  it runs.
- **Human-driven door** — the `commit-msg` and `pre-commit` git hooks (installed
  by `spark setup` or `spark install-git-hooks`) catch git run directly in a
  shell, where the plugin hook never fires.

Both doors enforce the same intent — blocks force-push and trunk pushes/commits;
allows `--force-with-lease`. The per-rule detail (what each blocks, exit codes,
fail-safe behavior) lives in [reference/hooks.md](../../plugins/spark/docs/reference/hooks.md), and
the decision and its scope in
[../adr/0003-zero-dependency-bash-and-enforcement-hooks.md](../adr/0003-zero-dependency-bash-and-enforcement-hooks.md).

## The subagent-orchestration pattern

The `knowledge` skill (and the companion crews behind `spark-docs` and
`spark-audit`) are multi-agent. They share one pattern:

- **The main loop is the sole orchestrator.** Subagents do not dispatch each
  other; the skill running in the main conversation dispatches each role and
  decides the phase sequence.
- **Roles coordinate through shared notes**, not direct messaging. Each role
  reads the prior phase's notes (e.g. `.knowledge-notes/00-intake.md`) and writes
  its own; the next role reads those.
- **The core crew is knowledge: 3 inward-facing roles** — intake, author,
  librarian-editor — for internal-knowledge capture. The `spark-docs` companion
  carries its own outward-facing author crew: knowledge documents *for the
  team*, docit documents *for the world*.

## Conformance

The information architecture (ADR-0008) comes with a standing test: every
shipped component must name its **layer** (Operator / Project / Session) and
its **motion** — carry-in, carry-through, or carry-forward — or be explicit
*support* with a stated rationale. "Neither, with no disposition" is a failing
verdict. The shipped inventory passes cleanly: the lifecycle skills are
carry-through, `bootstrap` and `setup` are carry-in, `knowledge` and the work
state are carry-forward, and the enforcement doors, `doctor`, and the
scaffolding verbs are explicit support for those motions.

The test lives on for every future addition — anything new must name its
layer, class, and motion before it ships. The static audit table that once
recorded the verdicts is retired: doctor now enforces taxonomy parity
mechanically (every shipped skill must appear in the canonical taxonomy), so
the inventory and its documentation cannot drift silently. The ADR-0013/0014
extractions applied the same test at product scale: surface that serves no
motion left the core for a companion.

## External Dependencies

- **Claude Code** — Spark is additive to Anthropic's skill/plugin spec and reuses
  built-in `/code-review`, `/security-review`, and `verify` rather than shipping
  its own. See
  [../adr/0002-additive-to-anthropic-spec.md](../adr/0002-additive-to-anthropic-spec.md)
  and [explanation/additive.md](../../plugins/spark/docs/explanation/additive.md).
- **Git / GitHub** — the lifecycle is GitHub-native (issues, branches, PRs).
- **No runtime dependencies in scripts.** `jq`/`python3` are used opportunistically
  for JSON parsing and degrade gracefully when absent.

## Operational Notes

- `spark doctor` validates the whole marketplace (every listed plugin's
  manifest and skill frontmatter, hook JSON, executable guard, taxonomy parity,
  doc links, enforcement parity, git-hook install state). Run it before pushing;
  validation CI runs the same command on every PR, so the local and CI gates
  cannot drift (ADR-0011). See [reference/cli.md](../../plugins/spark/docs/reference/cli.md).
- Git hooks are per-repo and must be installed with `spark setup` (or
  `spark install-git-hooks` alone); the plugin's PreToolUse guard travels with
  the plugin automatically.

## Risks / Unknowns

- **Two enforcement layers, one intent.** The two-doors model expresses the same
  rule twice (hook script + git hook). Deliberate redundancy for coverage, but a
  maintenance point: a rule change must land in both places — doctor's
  enforcement-parity check watches it. See ADR 0003 and ADR 0011.
- **Zero-dependency Bash tradeoff.** Portability buys reach into any forked project
  at the cost of richer tooling; JSON handling degrades gracefully. See ADR 0003.
- **Per-companion releases are deferred.** Release Please versions the core;
  companion release automation waits until a companion needs a release. See
  ADR 0014.

## Related Docs

- [explanation/sdlc-doctrine.md](../../plugins/spark/docs/explanation/sdlc-doctrine.md) — the lifecycle doctrine
- [explanation/additive.md](../../plugins/spark/docs/explanation/additive.md) — why Spark is additive, and why a plugin
- [../adr/0001-plugin-not-framework.md](../adr/0001-plugin-not-framework.md)
- [../adr/0002-additive-to-anthropic-spec.md](../adr/0002-additive-to-anthropic-spec.md)
- [../adr/0003-zero-dependency-bash-and-enforcement-hooks.md](../adr/0003-zero-dependency-bash-and-enforcement-hooks.md)
- [../adr/0008-information-architecture.md](../adr/0008-information-architecture.md) — the layers, classes, and motions
- [../adr/0014-core-plus-companion-plugins.md](../adr/0014-core-plus-companion-plugins.md) — the core/companion boundary
- [glossary.md](../../plugins/spark/docs/glossary.md) — Spark-internal vocabulary
