# ADR: Permission baselines are selectable trust tiers, default `delivery`

Date: 2026-07-21
Status: Accepted
Owner: jwogrady

## Context

ADR-0008 named a single "permission baseline artifact" (#64) as the Operator-layer
carry surface. What shipped since (#178, #187) is richer: `spark apply-permissions`
resolves a **named preset** and merges the matching baseline into a repo's
`.claude/settings.json`. Two presets exist as versioned artifacts —
`plugins/spark/settings/permission-baseline.json` and
`permission-baseline-conservative.json` — and the CLI selects between them
(`plugins/spark/bin/spark`, the `apply-permissions`/`cmd_apply_permissions`
path). That decision was implemented and documented in
`engineering-preferences.md` and `cli.md` but never recorded as an ADR, so the
audit of #180 flagged it as a missing decision.

## Decision

- **Permission baselines are trust tiers, chosen by preset.** `delivery` grants
  the full lifecycle (the working default); `conservative` is the reduced,
  read-leaning surface for lower-trust contexts.
- **`delivery` is the shipped default.** With no explicit choice, `spark
  apply-permissions` and `spark setup` resolve `delivery`.
- **The preset resolves through the ADR-0010 tiers** via the
  `permissions.preset` preference key: shipped default → operator override →
  committed project fact.
- **Merges are additive only.** Applying a preset adds its rules to an existing
  `.claude/settings.json`; it never removes rules the operator already granted.
- **`spark setup` forwards the resolved preset** as part of the one-command
  carry-in (ADR-0012).

Why: a single baseline could not serve both a trusted delivery repo and a
guarded one without either over-granting or under-granting. Naming the tiers and
defaulting to `delivery` keeps the common case one command while making the
safer surface an explicit, versioned choice rather than a hand-edited settings
file.

## Alternatives Considered

- **Keep one baseline (ADR-0008 as written).** Rejected: forces every repo onto
  the same grant set; no room for a lower-trust surface.
- **Subtractive presets (start broad, remove).** Rejected: a merge that removes
  operator-granted rules is surprising and hard to reason about; additive-only
  keeps `apply-permissions` safe to re-run.

## Consequences

- ADR-0008's "permission baseline" is now a two-tier, preset-selected artifact
  class; this ADR is its numbered home.
- Adding a tier means shipping a new baseline file and wiring its preset name —
  no change to the resolution or merge logic.
- Because merges only add, downgrading trust requires editing settings by hand;
  a preset switch alone will not tighten an already-broad file.

## Related Docs

- [0008-information-architecture.md](0008-information-architecture.md) — the Operator layer and the permission-baseline class this refines
- [0010-preferences-source-model.md](0010-preferences-source-model.md) — how `permissions.preset` resolves across tiers
- [0012-setup-is-the-one-command-carry-in.md](0012-setup-is-the-one-command-carry-in.md) — setup forwards the resolved preset
- `plugins/spark/docs/reference/engineering-preferences.md` — the operator-facing preset documentation
- `plugins/spark/docs/reference/cli.md` — `apply-permissions` usage
