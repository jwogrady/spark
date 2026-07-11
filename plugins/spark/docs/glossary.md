# Glossary

> Reference — Spark-internal vocabulary. Canonical definitions for the terms that
> recur across Spark's docs, so they don't drift into near-synonyms. Status
> `current`. Attribution `jwogrady`.
>
> Spark is domain- and stack-neutral by design. This glossary holds only
> Spark-internal mechanism terms — not project- or product-specific vocabulary. A
> fork captures its own domain terms in its own project-local glossary, which
> wins over the seed in `skills/knowledge/references/glossary.md`.

### the three layers (Operator / Project / Session)

Every artifact Spark reads or writes belongs to exactly one layer. **Operator**
— travels with the person across all projects (preferences, permission
baseline, portable knowledge); canonical home is the plugin plus operator
overrides. **Project** — belongs to one repo and is committed to it
(config, ADRs, problem statement, backlog, work state). **Session** — belongs
to one working conversation and is ephemeral unless explicitly promoted
(scratch, unpromoted review notes). Promotion between layers is always
explicit: commit/PR/issue moves Session → Project; the `knowledge` skill's
deliberate promotion moves Project → Operator. See
adr/0008-information-architecture.md.

### carry-in / carry-through / carry-forward

The three motions of information across the layers, and the architecture's
organizing verbs. **Carry-in** — Operator → Project: the standard bag is
applied to a repo (`bootstrap` at generation, `spark preferences` on demand,
the brief's `load` step on entry). **Carry-through** — within the Project
layer: the lifecycle (Ideate → Plan → Codify → Validate → Ship) moves work
between stages. **Carry-forward** — Session → Project (work state survives the
session) and Project → Operator (knowledge promotion). Prefer these exact
terms; do not coin near-synonyms. See adr/0008-information-architecture.md.

### operator knowledge home (`~/.config/spark/knowledge/`)

The Operator layer's knowledge store: a plain directory holding `glossary.md`
(operator vocabulary), sitting beside the operator preferences file and
honoring `XDG_CONFIG_HOME` the same way. A `decisions.md` half (standing
decisions) is deferred until a shipped surface reads it.
Written only through the `knowledge` skill's explicit, user-approved promotion
step (Project → Operator carry-forward) — never by silent copying — and
created lazily on first promotion. Project-local glossaries win over it on
conflict. See skills/knowledge/references/operator-knowledge.md.

### two-doors enforcement model

Spark enforces the same git-hygiene rules through two independent doors, because
a git operation reaches git by two paths and a plugin hook only sees one of them.
**Door 1 — the PreToolUse guard** (`hooks/guard-bash.sh`) covers the
Claude-driven path. **Door 2 — the git hooks** (`commit-msg`, `pre-commit`,
installed via `spark install-git-hooks`) cover the human-driven path. Both doors,
same intent. Prefer "two doors" over "two layers" / "two gates". See
[reference/hooks.md](reference/hooks.md) and
adr/0003-zero-dependency-bash-and-enforcement-hooks.md.

### Ideate → Plan → Codify → Validate → Ship

The Spark lifecycle spine — the single GitHub-native software-development
lifecycle every Spark project runs. Each stage is owned by one skill. Always
written with this exact stage order and these exact words. See
[explanation/sdlc-doctrine.md](explanation/sdlc-doctrine.md).

### PreToolUse guard (`guard-bash.sh`)

Door 1 of the two-doors model: the Claude-driven enforcement path. Wired by
`hooks/hooks.json` to fire on Claude Code's `PreToolUse` event for the `Bash`
tool; runs `hooks/guard-bash.sh`, which blocks force-push and trunk pushes (exit
`2`) and ships with the plugin (no per-repo install). See
[reference/hooks.md](reference/hooks.md).

### subagent crew

A multi-role set of subagents (`agents/<crew>/*.md`) that a Spark skill
dispatches to produce a complex artifact. The core plugin ships one crew:
**knowledge** (3 inward-facing roles — intake, author, librarian-editor — for
internal-knowledge capture). The `spark-docs` companion plugin carries its own
outward-facing author crew behind `docit`. See
architecture/spark-internals.md.

### shared-notes orchestration

How a subagent crew coordinates: the skill in the main conversation is the **sole
orchestrator** and dispatches each role; roles never dispatch each other. Roles
coordinate by reading the prior phase's notes and writing their own (e.g. the
`.knowledge-notes/` files), not by direct messaging. See
architecture/spark-internals.md.

### distribution vs inception

Two cleanly separated needs that the old `.spark/`-folder design tangled together.
**Distribution** — "make my toolkit available in this project" — is the plugin's
job (`/plugin install spark`); it forks nothing. **Inception** — "start a
brand-new project" — is `/plugin install spark` followed by the `bootstrap`
skill; in a repo that already exists, `spark setup` is the one-command
carry-in of the same standard. See
[explanation/additive.md](explanation/additive.md) and
adr/0001-plugin-not-framework.md.

### generated project

The unit Spark generates: a standardized GitHub repository produced by the
`bootstrap` skill and conforming to the operator's engineering-preferences
standard. Every generated project inherits the standard from the single
in-plugin source of truth, so projects stop drifting from each other. The
containerized per-client environment (infra, runtime, telemetry) is a planned
destination, not the current rung. See
adr/0015-generated-projects-without-the-cosmic-model.md for the vocabulary and
ADR-0004 through ADR-0007 for the CI, release, and stack defaults a generated
project carries.

### additive (to Anthropic's spec)

Spark's governing scope rule: it *references* Anthropic's skill/plugin spec and
*reuses* the built-in `/code-review`, `/security-review`, and `verify` rather than
inventing competing versions. Spark adds only the human-facing usage/doctrine
layer. See
[explanation/additive.md](explanation/additive.md) and
adr/0002-additive-to-anthropic-spec.md.
