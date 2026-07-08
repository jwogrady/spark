# ADR: Generated Cosmics ship CI; Spark itself stays CI-free

Date: 2026-07-08
Status: Accepted
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

## Related Docs

- [0003-zero-dependency-bash-and-enforcement-hooks.md](0003-zero-dependency-bash-and-enforcement-hooks.md) — why Spark's own enforcement is hook-based, not CI
- [../explanation/enforcement-model.md](../../plugins/spark/docs/explanation/enforcement-model.md) — the mechanical-enforcement rationale
