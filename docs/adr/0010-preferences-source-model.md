# ADR: The preferences source — shipped defaults, operator overrides, project facts

Date: 2026-07-08
Status: Proposed
Owner: jwogrady

## Context

ADR-0004 placed the engineering-preferences standard inside the plugin and named
`bootstrap` as its applicator, but left open where the *canonical, resolvable*
source lives and how overrides work. ADR-0008 assigned the preferences class to
the Operator layer and required one canonical source per class. Three features
block on this decision: `bootstrap` application (#61), the brief's `load` step
(#62), and the `spark preferences` verb (#63).

Constraints: Spark is zero-dependency Bash (ADR-0003) — the source must be
readable without `jq`/`python3`, degrading gracefully. The standard must remain
human-legible (the prose reference exists and is good) while becoming
machine-resolvable (skills and verbs must read it deterministically).

## Decision

Preferences resolve through three tiers, later tiers overriding earlier:

1. **Shipped defaults** — in-plugin, versioned with Spark:
   `plugins/spark/preferences/defaults.json`. Flat JSON, one key per
   convention (stack, release mechanism, CI template, issue taxonomy, doc
   set). This is the machine form of the standard.
2. **Operator overrides** — `~/.config/spark/preferences.json`. Optional; same
   flat schema; only the keys the operator changes. This file is the "standard
   bag" the operator edits once and carries everywhere.
3. **Project facts** — `.spark/preferences.json`, committed in the target repo.
   Records only per-project exceptions (e.g. "this Cosmic is TypeScript because
   it is a frontend") so the exception is visible and reviewable, not tribal.

Supporting decisions:

- **The prose reference stays canonical for the *why*.**
  `plugins/spark/docs/reference/engineering-preferences.md` remains the
  human-readable standard and gains a pointer to the machine source. The JSON
  carries *what to apply*; the prose carries *why it is the standard*. One
  class, one source per representation, no duplication of values in prose.
- **Flat JSON, no nesting beyond one level.** So a zero-dependency Bash reader
  (grep/sed with a documented key format) resolves it; `jq` is an optimization,
  never a requirement.
- **Resolution is read-time, not copy-time.** `bootstrap`/`preferences` resolve
  the three tiers at the moment of application; nothing silently copies the
  operator file into repos (Operator-layer material enters a Project only
  through the explicit carry-in motion, per ADR-0008).

Why: the plugin-shipped default keeps "install once, carry everywhere" true
with zero setup; the operator file makes the standard *yours* without forking
the plugin; the committed project-facts file makes every deviation from your
own standard visible in review — which is the honesty principle applied to
configuration.

## Alternatives Considered

- **Prose file as the only source (status quo).** Rejected: skills would parse
  Markdown prose — brittle, and every consumer reinvents the parse.
- **YAML.** Rejected: unreadable without a parser; violates zero-dependency.
- **Single operator file, no shipped defaults.** Rejected: breaks on a fresh
  machine; the plugin must be useful with zero setup.
- **Env vars.** Rejected: not durable, not reviewable, invisible to a session
  brief.

## Consequences

- #61, #62, #63 implement against a decided contract: three paths, one
  resolution order, flat-JSON schema.
- The `defaults.json` content must be derived from (and stay consistent with)
  the prose reference — the parity check pattern (#72) extends naturally to
  preference drift later.
- New cost: adding a convention now means adding a key + a prose section, not
  just prose. That is the one-canonical-source principle paid forward.

## Open Questions

- Exact key schema (namespacing, value types) — settled in #61's
  implementation PR, where the first real consumer forces the format.

## Related Docs

- [0004-cosmic-is-the-generated-unit.md](0004-cosmic-is-the-generated-unit.md) — preferences live in-plugin
- [0008-information-architecture.md](0008-information-architecture.md) — the layer/class model this instantiates
- `plugins/spark/docs/reference/engineering-preferences.md` — the prose standard
