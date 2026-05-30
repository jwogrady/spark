# Glossary

> Reference — Spark-internal vocabulary. Canonical definitions for the terms that
> recur across Spark's docs, so they don't drift into near-synonyms. Status
> `current`. Attribution `jwogrady` / Status26.
>
> Spark is domain- and stack-neutral by design. This glossary holds only
> Spark-internal mechanism terms — not project- or product-specific vocabulary. A
> fork captures its own domain terms in its own project-local glossary, which
> wins over the seed in `skills/knowledge/references/glossary.md`.

### two-doors enforcement model

Spark enforces the same git-hygiene rules through two independent doors, because
a git operation reaches git by two paths and a plugin hook only sees one of them.
**Door 1 — the PreToolUse guard** (`hooks/guard-bash.sh`) covers the
Claude-driven path. **Door 2 — the git hooks** (`commit-msg`, `pre-commit`,
installed via `spark install-git-hooks`) cover the human-driven path. Both doors,
same intent. Prefer "two doors" over "two layers" / "two gates". See
[reference/hooks.md](reference/hooks.md) and
[adr/0003-zero-dependency-bash-and-enforcement-hooks.md](adr/0003-zero-dependency-bash-and-enforcement-hooks.md).

### Ideate → Plan → Generate → Solve → Ship

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
dispatches to produce a complex artifact. Spark ships two mirror crews: **knowledge**
(6 inward-facing roles — internal-knowledge capture) and **docit** (13
outward-facing roles — public docs). See
[architecture/spark-internals.md](architecture/spark-internals.md).

### shared-notes orchestration

How a subagent crew coordinates: the skill in the main conversation is the **sole
orchestrator** and dispatches each role; roles never dispatch each other. Roles
coordinate by reading the prior phase's notes and writing their own (e.g. the
`.knowledge-notes/` files), not by direct messaging. See
[architecture/spark-internals.md](architecture/spark-internals.md).

### distribution vs inception

Two cleanly separated needs that the old `.spark/`-folder design tangled together.
**Distribution** — "make my toolkit available in this project" — is the plugin's
job (`/plugin install spark`); it forks nothing. **Inception** — "start a
brand-new project" — is `/plugin install spark` followed by the `bootstrap`
skill. See
[explanation/scope-and-upstream.md](explanation/scope-and-upstream.md) and
[adr/0001-plugin-not-framework.md](adr/0001-plugin-not-framework.md).

### additive (to Anthropic's spec)

Spark's governing scope rule: it *references* Anthropic's skill/plugin spec and
*reuses* the built-in `/code-review`, `/security-review`, and `verify` rather than
inventing competing versions. Spark adds only the human-facing usage/doctrine
layer. See
[explanation/scope-and-upstream.md](explanation/scope-and-upstream.md) and
[adr/0002-additive-to-anthropic-spec.md](adr/0002-additive-to-anthropic-spec.md).
