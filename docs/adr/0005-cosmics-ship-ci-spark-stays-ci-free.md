# ADR: Generated Cosmics ship CI; Spark itself stays CI-free

Date: 2026-07-08
Status: Accepted; superseded in part by
[ADR-0011](0011-doctor-is-the-validation-gate.md) — the Spark-repo
validation-CI decision recorded in this file's Amendment section now lives in
its own numbered ADR (the amendment was misfiled per the template's
append-only rule; its text remains below as history); vocabulary superseded by [ADR-0015](0015-generated-projects-without-the-cosmic-model.md) — "Cosmic" is retired from the public docs
Owner: jwogrady

## Context

The operator's preferences require CI: GitHub Actions, validation pipelines, and
continuous validation on every project. Spark the plugin deliberately has **no
CI** — it is Bash and Markdown with nothing to build or test, and `spark doctor`
plus `bash -n` are its only gates (ADR-0003). On its face this looked like a
contradiction between the operator's standard and Spark's own practice.

## Decision

- **Generated Cosmics ship with CI.** `bootstrap` scaffolds a default GitHub
  Actions workflow into every Cosmic it generates.
- **Spark itself stays CI-free.** The two are different subjects: Spark-the-tool
  has no build surface; a Cosmic does.

Why: "no CI" is a fact about *this one repository*, not a universal rule. The
operator's CI preference applies to the projects they build, and a Cosmic must
self-maintain in GitHub. Framing CI as a generation-time default — not a
Spark-self obligation — dissolves the apparent conflict.

## Alternatives Considered

- **Adopt CI for Spark itself, for consistency.** Rejected: there is nothing to
  test; it would be ceremony and contradicts ADR-0003's zero-dependency rationale.
- **Omit CI from generated Cosmics.** Rejected: contradicts the operator's
  standard; a Cosmic that cannot validate itself does not self-maintain.

## Consequences

- `bootstrap` gains a CI-scaffold step, and the workflow becomes a maintained
  template inside the plugin.
- Generated Cosmics validate continuously from the first commit.
- The default workflow must be stack-aware — Python + `uv` first (see ADR-0007).

## Amendment (2026-07-08)

Spark now carries one workflow: `.github/workflows/validate.yml`, added with
the doctor-superset work (#70, #71). This narrows — but does not reverse — the
decision above, and the two kinds of CI must not be conflated:

- **Spark-repo validation CI** is a thin wrapper that checks out the repo and
  runs `./plugins/spark/bin/spark doctor` on pull requests. It contains no
  check logic of its own; the local command and the CI gate are the same
  command, so they cannot drift. New checks belong in doctor, never in YAML.
- **Cosmic-generated build CI** is what `bootstrap` scaffolds into generated
  projects: stack-aware build/test pipelines (Python + `uv` first, ADR-0007).
  That remains a generation-time template, not something Spark runs on itself.

"Spark stays CI-free" therefore now means: Spark has no build/test pipeline,
because there is still nothing to build or test. Mechanically enforcing its
own validation gate is consistent with ADR-0003's discipline rationale, not a
contradiction of it.

## Related Docs

- [0003-zero-dependency-bash-and-enforcement-hooks.md](0003-zero-dependency-bash-and-enforcement-hooks.md) — why Spark's own enforcement is hook-based, not CI
- [../explanation/enforcement-model.md](../../plugins/spark/docs/explanation/enforcement-model.md) — the mechanical-enforcement rationale
