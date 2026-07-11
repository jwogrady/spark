# ADR: `spark setup` is the one-command carry-in, and it composes — never forks — the individual verbs

Date: 2026-07-11
Status: Accepted
Owner: jwogrady

## Context

Arming a repo with the operator's standard takes three commands run in
sequence: `spark install-git-hooks` (the human-driven enforcement door),
`spark apply-permissions` (the Claude permission baseline), and
`spark preferences --apply` (the resolved engineering standard, ADR-0010).
Each is individually idempotent, but nothing runs them together — the sequence
lives only in documentation (the install how-to, the preferences on-ramp, the
bootstrap flow), so a repo is easy to leave half-armed. `ROADMAP.md` v0.6
already names a `spark setup` flow; the stack-aware curation half of that item
remains future work, but the mechanical composition is buildable now.

## Decision

- **Add a `setup` verb to `bin/spark`** that performs the whole carry-in in
  one run: install the git hooks, apply the permission baseline, apply the
  resolved standard — in that order — and print one consolidated summary.
- **Composition only.** `setup` calls the same functions the individual verbs
  dispatch to (`cmd_install_git_hooks`, `cmd_apply_permissions`,
  `apply_standard`). It contains no step logic of its own, so the individual
  verbs remain the single implementation of each step and cannot drift from
  `setup`.
- **The individual verbs stay.** `setup` is a convenience surface over them,
  not a replacement; partial application remains a supported choice.
- **Prompting is preserved, `--yes` passes through.** The permission-merge
  confirmation is the one interactive moment; `setup --yes` forwards the
  existing flag rather than inventing a second consent model.
- **Exit semantics mirror `preferences --apply`:** non-zero only outside a
  git repo; advisory (`!`) items are decisions for the operator, not
  failures.

Why: the three steps are one motion — carry-in (ADR-0008) — and a motion
deserves one verb. Composing the existing functions honors the additive
principle (ADR-0002) applied internally: no second implementation of anything
that already works.

## Alternatives Considered

- **Documentation only (status quo, better how-tos).** Rejected: the
  sequence stays a human memory burden — the exact re-loading cost Spark
  exists to remove (ADR-0004).
- **Fold the steps into `bootstrap`.** Rejected: `bootstrap` is generation
  (a skill, new projects); carry-in must also work in any existing repo from
  the CLI.
- **A new orchestration script beside the verbs.** Rejected: forks the step
  logic; two implementations of one rule is the drift ADR-0011 exists to
  prevent.

## Consequences

- The docs' primary on-ramp shrinks to one command; the three-command
  sequence remains documented as the granular path.
- `cmd_apply_permissions` and the hook/standard functions become internal
  composition points — signature changes to them now affect two call sites.
- The ROADMAP v0.6 `setup` item narrows to its remaining half (stack-aware
  baseline curation).

## Related Docs

- [0003-zero-dependency-bash-and-enforcement-hooks.md](0003-zero-dependency-bash-and-enforcement-hooks.md) — the script rules `setup` inherits
- [0008-information-architecture.md](0008-information-architecture.md) — carry-in, the motion this verb completes
- [0010-preferences-source-model.md](0010-preferences-source-model.md) — the resolve `--apply` performs
- [0011-doctor-is-the-validation-gate.md](0011-doctor-is-the-validation-gate.md) — where the new verb's checks belong
