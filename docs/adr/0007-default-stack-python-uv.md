# ADR: Default Cosmic stack is Python + `uv`; TypeScript/Bun only for a frontend

Date: 2026-07-08
Status: Accepted
Owner: jwogrady

## Context

Spark is stack-neutral by design — `bootstrap` supports both `uv`/Python and
Bun/TypeScript. The operator's preferences name a default: **Python + `uv`**. The
operator has also mentioned a TypeScript frontend for projects that need one. A
generated Cosmic needs a defined default so generation is not a cold choice each
time, without abandoning Spark's neutrality.

## Decision

- **The default stack for a generated Cosmic is Python + `uv`** (runtime,
  dependency, and project manager).
- **TypeScript / Bun is used only when a Cosmic needs a frontend.**
- **Spark-the-tool remains stack-neutral.** This default lives in the operator's
  preference layer, not in Spark's core.

Why: the written preference names Python + `uv`; treating it as the default — not
the only option — removes the per-project stack decision while keeping Spark
neutral. TypeScript stays available for frontends through existing `bootstrap`
profiles.

## Alternatives Considered

- **Bake Python + `uv` into Spark's core as the only stack.** Rejected: breaks
  Spark's stack-neutrality; a fork on another stack loses value.
- **Ask the stack on every generation.** Rejected: that is the re-loading cost
  this whole effort exists to remove.

## Consequences

- The CI template (ADR-0005) and the documentation/scaffold defaults assume
  Python + `uv` unless a frontend is requested.
- The preference layer, not Spark, carries the choice — a fork can set a
  different default without touching Spark's core.

## Related Docs

- [0002-additive-to-anthropic-spec.md](0002-additive-to-anthropic-spec.md) — Spark's stack-neutral, additive stance
- [../../skills/bootstrap/references/profiles.md](../../skills/bootstrap/references/profiles.md) — the per-stack scaffold profiles
