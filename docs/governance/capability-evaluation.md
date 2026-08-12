# Applying the Capability Evaluation Framework

> **Procedure — how to run Spark's capability entry test.** This doc explains
> *how*; it never redefines *what*. The five questions come from
> [ADR-0025](../adr/0025-capability-evaluation-framework.md) (historically via
> Constitution Article VI, now archived).
> A dev-doc — it governs how Spark is built and never ships. Owner: `jwogrady`.
>
> **Status (v0.16):** judgment guidance only. The template fields and CI checks
> that mechanically collected and enforced these answers were retired by the
> #361 governance deletion test — apply the questions when proposing a
> capability; nothing polices the paperwork.

Use this when proposing, reviewing, or re-examining any capability — a skill, a
helper, an enforcement rule, an orchestration slice. It is the standing entry
point for Article VI.

## The five questions, in order

Answer each in the proposing issue's own prose (the dedicated template fields
were retired with the gate machinery — #361). Stop at the first hard No that
the tie-break below does not rescue.

1. **Mission.** Does this materially improve engineering discipline around Claude
   and GitHub — not merely automate GitHub or wrap Claude? Name the workflow
   outcome it improves (engineering discipline, deterministic execution,
   reproducibility, project engineering, context preservation, engineering
   standards, evaluation, release confidence, developer efficiency). Do **not**
   justify a capability by implementation effort or API/round-trip savings alone.
2. **User value.** If it disappeared, would the operator notice?
3. **Constitutional ownership.** Is it inside an owned surface (Constitution
   Article II) and additive to Claude, GitHub, Git, and the OS (Article III)?
   Separate the layers: *workflow policy* (Spark's), *workflow execution* (Spark
   owns the determinism of its own policy), *platform mechanism* (delegated).
4. **Evidence.** Is the claim backed by evidence the Evaluation surface produced?
   See [`../../evaluations/orchestration/README.md`](../../evaluations/orchestration/README.md)
   for the existing harness and its honesty discipline (measured vs. estimate).
5. **Smallest implementation.** What is the least build that satisfies 1–4?
   Extend existing work; a new build must show why extension is impossible.

## The three lenses and the tie-break

Questions 1–3 are probed by three lenses that can disagree:

| Lens | Asks |
|---|---|
| **Mission test** | Would we intentionally build this today because it materially improves the workflow? |
| **User Value test** | If it vanished, would a Spark user notice? |
| **Deletion Test** | Can Claude / GitHub / Git / the OS *technically* replace it? |

A capability may fail one lens and pass another. **When they disagree, Mission
wins** — the governing hierarchy is the arbiter. A Deletion-Test failure alone is
never disqualifying, because nearly everything Spark does is *technically*
replaceable by narrating a platform tool; the Mission and User Value tests are the
corrective that keeps the Deletion Test from gutting the product.

## Worked examples (from the v1 governance review)

- **Deterministic issue wiring — KEEP.** *Deletion Test: fails* (a platform CLI +
  Claude can narrate the calls). *User Value: passes* (without it the operator is
  back to a stochastic, drift-prone, un-resumable narration of the Plan→issues
  seam). *Mission: passes* (converts a lifecycle seam from stochastic to
  deterministic and reproducible — the policy is Spark's, the execution
  determinism is Spark's, only the raw calls are the platform's). Mission-first
  ⇒ **KEEP**. The lesson: do not collapse *workflow execution* into *platform
  mechanism*.
- **A project-management board — not v1.** *Deletion Test: fails* (the platform
  owns boards). *User Value: weak* for a solo operator whose metadata is already
  kept honest by in-repo governance. *Mission: weak* (visualization, not
  discipline). All three weak ⇒ out of scope as project management. The only
  defensible sliver is a **repository-onboarding carry-in** (scaffold a standard
  layout once, never manage it), which passes Mission only for a many-project
  operator — a different, narrower capability.

## Extend, don't rebuild

Question 5 is where duplication is caught. Before proposing new infrastructure,
find the existing work and show why it cannot be extended. The v1 review nearly
filed an "establish the evaluation framework" issue before confirming the harness
already existed — the correct move was to *promote and govern* it, not rebuild it.
Rebuilding what exists violates Constitution Article V.

## Capability Traceability

Every capability stays traceable end-to-end:

```
Mission → Capability → Constitution → ADR → Issue → Pull Request → Evaluation → Release
```

This is the lifecycle spine (`Ideate → Plan → Codify → Validate → Ship`) projected
onto governance, so it adds no new machinery — it makes the existing spine
auditable. Each hop has a home:

| Hop | Carried by (since v0.16: all documentary — the collecting fields and the enforcing gate were retired by #361) |
|---|---|
| Mission → Capability | the CEF five-question answer, written in the proposing issue |
| → ADR → Issue | the ADR Alignment block + the issue's own reasoning |
| → Pull Request | the PR body's what/why (no dedicated traceability section anymore) |
| → Evaluation | the Evaluation surface (the Q4 evidence, when an evaluation is run) |
| → Release | the manual release census in the release-docs checklist |

The CEF governs *admission*; release truth is gated by the milestone gate and
release-notes verification. **No hop is mechanically enforced anymore** — the
Platform Compatibility Review that refused a release over absent evidence was
retired by the #361 deletion test; the questions are applied as judgment.

## See also

- [The archived constitution](../product-constitution.md) — where Article VI originally ratified this procedure (historical)
- [ADR-0025](../adr/0025-capability-evaluation-framework.md) — the decision to adopt it
