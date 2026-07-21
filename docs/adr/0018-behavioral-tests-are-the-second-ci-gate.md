# ADR: The behavioral test suite is the second CI validation gate

Date: 2026-07-21
Status: Accepted
Owner: jwogrady

## Context

ADR-0011 (2026-07-09) declared `spark doctor` "the single validation gate" and
said CI "runs exactly `./plugins/spark/bin/spark doctor` … and contains no check
logic of its own." That was true when written. It is no longer literally true:
#165 and #172 added a behavioral test suite — `tests/run.sh` driving a dozen
`tests/test-*.sh` suites — and `.github/workflows/validate.yml` now runs it as a
second job (`tests`) alongside the `doctor` job.

Doctor is a *static* validator: it inspects layout, JSON, frontmatter, shell
syntax, doc links, and enforcement parity without executing the shipped flows.
It cannot prove that `spark setup` actually arms a repo, that the guard blocks a
force-push, or that `commit-msg` rejects an AI trailer. Those need behavior
exercised against throwaway repos. README, `AGENTS.md`, and
`engineering-preferences.md` already treat the behavioral suite as a first-class
guardrail, but no ADR recorded the decision — the #180 audit flagged it as
missing.

## Decision

- **CI has two gates, not one.** `validate.yml` runs a `doctor` job (the static
  superset gate, ADR-0011) **and** a `tests` job (`bash tests/run.sh`, the
  behavioral gate). Both must pass.
- **The behavioral gate owns what doctor cannot see:** the CLI flows and both
  enforcement doors, exercised against temporary git repos and a sandboxed
  HOME so the checkout is never mutated (`tests/lib.sh`).
- **Check logic still never lives in the workflow YAML.** Doctor holds the
  static checks; `tests/test-*.sh` hold the behavioral ones. The workflow stays
  a thin wrapper, so local and CI results cannot drift — the ADR-0011 principle
  is preserved, only widened to two wrappers.
- **This ADR supersedes in part ADR-0011's "single gate" framing.** Doctor is
  the static gate; this is the behavioral gate; together they are the validation
  gate.

Why: a static validator and a behavioral suite catch different classes of
regression, and the enforcement doors are exactly the surfaces most worth
proving by execution rather than inspection. Recording the second gate keeps the
ADR layer honest with what the pipeline already does.

## Alternatives Considered

- **Fold behavioral checks into doctor.** Rejected: doctor must stay runnable as
  a fast, dependency-light static check on any repo; spinning up temp git repos
  and sandboxes belongs in a separate suite, not in every `spark doctor` run.
- **Leave it undocumented (docs already mention it).** Rejected: ADR-0011's
  "single gate / runs exactly doctor" wording actively contradicts the shipped
  pipeline; an unrecorded second gate is the drift #180 exists to close.

## Consequences

- A new behavioral guarantee lands as a `tests/test-*.sh` suite picked up by
  `tests/run.sh`; the workflow needs no edit.
- CI failure now has two possible sources (static vs behavioral); the job name
  says which.
- ADR-0011 carries an amendment pointing here; its body stays as history.

## Related Docs

- [0011-doctor-is-the-validation-gate.md](0011-doctor-is-the-validation-gate.md) — the static gate this amends and complements
- [0003-zero-dependency-bash-and-enforcement-hooks.md](0003-zero-dependency-bash-and-enforcement-hooks.md) — the two enforcement doors the behavioral suite exercises
- `plugins/spark/docs/explanation/enforcement-model.md` — why enforcement is mechanical
