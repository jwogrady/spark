# Glossary

> Reference — Spark-internal vocabulary. Canonical definitions for the terms that
> recur across Spark's docs, so they don't drift into near-synonyms. Status
> `current`. Attribution `jwogrady`.
>
> Spark is domain- and stack-neutral by design. This glossary holds only
> Spark-internal mechanism terms — not project- or product-specific vocabulary. A
> fork captures its own domain terms in its own project-local glossary, which
> wins over the seed in
> [../skills/knowledge/references/glossary.md](../skills/knowledge/references/glossary.md).
>
> Links below either resolve to a doc that ships with the plugin, or are
> explicitly labeled `(developer-only)` with a full GitHub URL into this repo's
> dev-only `docs/` tree (never shipped, read only if you're working in this repo).

### ADR-NNNN (Architecture Decision Record)

A dated record of one architectural decision — the context, the choice, and
what was rejected. Spark's docs and skills cite them (`ADR-0022`, `ADR-0027`)
to mark a rule as a *recorded decision* rather than a preference, so the
reasoning behind it can be traced rather than re-argued.

**ADRs are developer-only and do not ship with the plugin.** They live in this
repository's dev-only `docs/adr/` tree:
https://github.com/jwogrady/spark/tree/master/docs/adr — read one when you
want the reasoning; you never need one to use the rule the shipped doc states.
A citation is provenance, not a prerequisite.

Always written `ADR-NNNN`, four digits, referenced by number rather than
retitled inline.

### the three layers (Operator / Project / Session)

Every artifact Spark reads or writes belongs to exactly one layer. **Operator**
— travels with the person across all projects (preferences, permission
baseline, portable knowledge); canonical home is the plugin plus operator
overrides. **Project** — belongs to one repo and is committed to it
(config, ADRs, problem statement, backlog, work state). **Session** — belongs
to one working conversation and is ephemeral unless explicitly promoted
(scratch, unpromoted review notes). Promotion between layers is always
explicit: commit/PR/issue moves Session → Project; the `knowledge` skill's
deliberate promotion moves Project → Operator. See (developer-only)
[ADR-0008 — information architecture](https://github.com/jwogrady/spark/blob/master/docs/adr/0008-information-architecture.md).

### memory hub / spoke

An ownership relationship between related projects, not a fourth layer. A
**memory hub** is a Project-layer repository designated as the durable
authority for cross-project meaning within a related set of **spokes**; each
spoke keeps its implementation, tests, and release truth local and may declare
at most one hub via the `project.memory-hub` project fact (`spark hub`). The
pointer identifies the destination — the hub's contents are never mirrored
into the spoke, and a project with no hub (or an explicit `none`) is simply
standalone. See (developer-only)
[ADR-0028 — cross-project memory hubs](https://github.com/jwogrady/spark/blob/master/docs/adr/0028-cross-project-memory-hubs.md).

### carry-in / carry-through / carry-forward

The three motions of information across the layers, and the architecture's
organizing verbs. **Carry-in** — Operator → Project: the standard bag is
applied to a repo (`bootstrap` at generation, `spark preferences` on demand,
the brief's `load` step on entry). **Carry-through** — within the Project
layer: the lifecycle (Ideate → Plan → Codify → Validate → Ship) moves work
between stages. **Carry-forward** — Session → Project (work state survives the
session), Project → Operator (knowledge promotion), and Project → related
Project memory authority (durable cross-project learning promoted to a
configured [memory hub](#memory-hub--spoke), surfaced at natural lifecycle
boundaries — not a sixth stage). Prefer these exact terms; do not coin
near-synonyms. See (developer-only)
[ADR-0008 — information architecture](https://github.com/jwogrady/spark/blob/master/docs/adr/0008-information-architecture.md).

### operator knowledge home (`~/.config/spark/knowledge/`)

The Operator layer's knowledge store: a plain directory holding `glossary.md`
(operator vocabulary), sitting beside the operator preferences file and
honoring `XDG_CONFIG_HOME` the same way. A `decisions.md` half (standing
decisions) is deferred until a shipped surface reads it.
Written only through the `knowledge` skill's explicit, user-approved promotion
step (Project → Operator carry-forward) — never by silent copying — and
created lazily on first promotion. Project-local glossaries win over it on
conflict. See
[skills/knowledge/references/operator-knowledge.md](../skills/knowledge/references/operator-knowledge.md).

### three-doors enforcement model

The name for Spark's enforcement design: the same git-hygiene rules held at
three independent doors, one per path a git operation can take — **Door 1**,
the PreToolUse guard (Claude-driven); **Door 2**, the git hooks (human-driven,
local); **Door 3**, the GitHub ruleset (everything that reaches the remote
without running local tooling). Same intent at every door.

Always "three doors" — never "layers" or "gates". Number the doors in that
order. The doctrine itself is stated once in
[explanation/enforcement-model.md](explanation/enforcement-model.md); per-rule
mechanics are in [reference/hooks.md](reference/hooks.md).

### Ideate → Plan → Codify → Validate → Ship

The Spark lifecycle spine — the single GitHub-native software-development
lifecycle every Spark project runs. Each stage is owned by one skill. Always
written with this exact stage order and these exact words. See
[explanation/sdlc-doctrine.md](explanation/sdlc-doctrine.md).

### PreToolUse guard (`guard-bash.sh`)

Door 1 of the three-doors model: the Claude-driven enforcement path. Wired by
`hooks/hooks.json` to fire on Claude Code's `PreToolUse` event for the `Bash`
tool; runs `hooks/guard-bash.sh`, which blocks force-push and trunk pushes (exit
`2`) and ships with the plugin (no per-repo install). See
[reference/hooks.md](reference/hooks.md).

### subagent crew

A multi-role set of subagents (`agents/<crew>/*.md`) that a Spark skill
dispatches to produce a complex artifact. The core plugin ships one crew:
**knowledge** (3 inward-facing roles — intake, author, librarian-editor — for
internal-knowledge capture). The `spark-docs` companion plugin carries its own
outward-facing author crew behind `docit`. See (developer-only)
[architecture/spark-internals.md](https://github.com/jwogrady/spark/blob/master/docs/architecture/spark-internals.md).

### shared-notes orchestration

How a subagent crew coordinates: the skill in the main conversation is the **sole
orchestrator** and dispatches each role; roles never dispatch each other. Roles
coordinate by reading the prior phase's notes and writing their own (e.g. the
`.knowledge-notes/` files), not by direct messaging. See (developer-only)
[architecture/spark-internals.md](https://github.com/jwogrady/spark/blob/master/docs/architecture/spark-internals.md).

### distribution vs inception

Two cleanly separated needs that the old `.spark/`-folder design tangled together.
**Distribution** — "make my toolkit available in this project" — is the plugin's
job (`/plugin install spark`); it forks nothing. **Inception** — "start a
brand-new project" — is `/plugin install spark` followed by the `bootstrap`
skill; in a repo that already exists, `spark setup` is the one-command
carry-in of the same standard. See
[explanation/additive.md](explanation/additive.md) and (developer-only)
[ADR-0001 — plugin, not framework](https://github.com/jwogrady/spark/blob/master/docs/adr/0001-plugin-not-framework.md).

### generated project

The unit Spark generates: a standardized GitHub repository produced by the
`bootstrap` skill and conforming to the operator's engineering standard as
materialized from `preferences/defaults.json` — how that resolution works is
described in
[engineering-preferences.md](reference/engineering-preferences.md), not
duplicated here. This is what keeps generated projects from drifting from
each other. The containerized per-client
environment (infra, runtime, telemetry) is a planned destination, not the
current rung. See (developer-only)
[ADR-0015 — generated projects, without the Cosmic model](https://github.com/jwogrady/spark/blob/master/docs/adr/0015-generated-projects-without-the-cosmic-model.md)
for the vocabulary, and ADR-0004 through ADR-0007 (developer-only:
[0004](https://github.com/jwogrady/spark/blob/master/docs/adr/0004-cosmic-is-the-generated-unit.md) ·
[0005](https://github.com/jwogrady/spark/blob/master/docs/adr/0005-cosmics-ship-ci-spark-stays-ci-free.md) ·
[0006](https://github.com/jwogrady/spark/blob/master/docs/adr/0006-cosmics-use-release-please.md) ·
[0007](https://github.com/jwogrady/spark/blob/master/docs/adr/0007-default-stack-python-uv.md))
for the CI, release, and stack defaults a generated project carries.

### additive (to Anthropic's spec)

Spark's governing scope rule: it *references* Anthropic's skill/plugin spec and
*reuses* the built-in `/code-review`, `/security-review`, and `verify` rather than
inventing competing versions. Spark adds only the human-facing usage/doctrine
layer. See
[explanation/additive.md](explanation/additive.md) and (developer-only)
[ADR-0002 — additive to Anthropic's spec](https://github.com/jwogrady/spark/blob/master/docs/adr/0002-additive-to-anthropic-spec.md).
