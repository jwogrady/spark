# ADR: `spark setup` is the one-command carry-in, and it composes — never forks — the individual verbs

Date: 2026-07-11
Status: Accepted (amended 2026-07-21 — `setup` now offers named profiles before materializing defaults; see Amendment)
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
- **Exit semantics mirror `preferences --apply`:** for a valid invocation,
  non-zero only outside a git repo — advisory (`!`) items inside a repo are
  decisions for the operator, not failures. Invalid options or excess
  arguments are usage errors and also exit non-zero.

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

## Amendment (2026-07-21)

The Consequences above narrowed the ROADMAP v0.6 `setup` item to its remaining
half — stack-aware baseline curation. That half shipped as **setup profiles**
(#189: `spark profiles`, `spark setup --profile <name>`), a real decision this
record did not capture at merge and which #180's ADR audit flagged.

The decision profiles record:

- **`setup` offers named profiles before it materializes defaults.** Two ship
  today — `python-uv` and `typescript-bun` — each a small flat-JSON file of
  committed project facts under `preferences/profiles/`. `spark profiles`
  inspects them (marking the shipped default, overrides, and unsupported
  combinations) before anything is written; `spark setup --profile <name>`
  selects one.
- **Selection resolves *through* the existing tiers, it does not bypass them.**
  A chosen profile writes its facts to `.spark/preferences.json` — the
  committed-project-facts tier of ADR-0010 — and the carry-in then resolves
  shipped defaults → operator overrides → those facts exactly as before. With
  no profile, `setup` applies the shipped defaults unchanged and invents no
  project facts. This keeps the composition-only discipline of the decision
  above: there is no second application engine, so a profile can never drift
  from `preferences --apply`.
- **Selection is all-or-nothing and runs first.** An unknown profile, a stack
  with no shipped CI template, or a conflict with existing committed facts
  refuses the whole run and materializes nothing — a profile never overwrites
  a project decision.

Verified against the shipped behavior, not the plan, by
`tests/test-setup-profiles.sh`: inspection, selection writing the committed
facts and stack-matched CI, idempotent re-runs, unchanged profile-less
defaults, and the all-or-nothing refusals.

## Related Docs

- [0003-zero-dependency-bash-and-enforcement-hooks.md](0003-zero-dependency-bash-and-enforcement-hooks.md) — the script rules `setup` inherits
- [0008-information-architecture.md](0008-information-architecture.md) — carry-in, the motion this verb completes
- [0010-preferences-source-model.md](0010-preferences-source-model.md) — the resolve `--apply` performs
- [0011-doctor-is-the-validation-gate.md](0011-doctor-is-the-validation-gate.md) — where the new verb's checks belong
