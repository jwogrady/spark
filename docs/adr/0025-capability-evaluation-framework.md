# ADR: Adopt the Capability Evaluation Framework as Spark's capability entry point

Date: 2026-07-22
Status: Accepted (gate machinery retired 2026-08-11: the five questions remain
the recorded method for judging what belongs in Spark, applied as judgment at
proposal time. The mechanical collection and enforcement seams — the
capability-traceability template fields, the PR traceability CI check, and the
platform-compat review — were removed by the #361 governance deletion test:
none prevented a concrete failure that judgment plus the behavioral tests did
not already prevent.)
Owner: jwogrady

> This ADR records a **permanent architectural decision**: how Spark decides what
> belongs in it. It adopts a *governance model*, not a runtime feature — it builds
> no code and ships nothing into a user project. The five questions it adopts are
> defined canonically in the Constitution (Article VI); this ADR records the
> decision to make them binding, and points there rather than restating them.

## Alignment

- **Mission / Constitution / Identity served:** the Mission (engineering
  discipline around Claude and GitHub); Constitution Article VI (the CEF) and
  Article II.4 (Evaluation); the four-party model of
  [ADR-0019](0019-human-directed-product-model.md).
- **Supersedes:** nothing. **Superseded by:** nothing.
- **Status tracks evidence:** not applicable — this ADR adopts a decision
  procedure, not an experiment-gated implementation.

## Context

Across a multi-pass governance review of the v1 backlog, the same decision
procedure recurred and repeatedly *changed outcomes* — it reversed two issue
dispositions, withdrew a duplicate-infrastructure proposal, and split an issue
that bundled an urgent honesty fix with a large feature. A procedure that
consistently alters conclusions is a reusable instrument, not ceremony.

Before this ADR, the entry test for a capability lived implicitly in the identity
and philosophy docs and had to be re-derived each time. Article VI of the
Constitution now names it — the **Capability Evaluation Framework (CEF)** — and
states its five questions and the Mission-first tie-break as invariants. What was
missing was a citable, dated ratification that makes the CEF *binding* and gives
future work a fixed point to defer to. This ADR is that record.

The CEF stands on facts already in the repo: the Evaluation surface it depends on
for its evidence question is not hypothetical — a deterministic, zero-dependency
evaluation harness already exists under
[`evaluations/orchestration/`](../../evaluations/orchestration/README.md),
currently labeled research evidence. The CEF consumes and governs that surface;
it does not invent one.

## Decision

- **The CEF is Spark's permanent capability entry point.** Every proposed
  capability — new or existing — is admitted only by passing all five questions
  defined in [Constitution Article VI](../product-constitution.md): Mission, User
  Value, Constitutional ownership, Evidence, and Smallest implementation.
- **The three lenses (Mission, User Value, Deletion) may disagree, and Mission
  wins.** A Deletion-Test failure alone never disqualifies a capability the
  Mission and User Value tests endorse. This tie-break is a decision rule, fixed
  here.
- **Capability Traceability is the audit spine:** `Mission → Capability →
  Constitution → ADR → Issue → Pull Request → Evaluation → Release`. The CEF
  governs admission; Evaluation governs release; the `Evaluation → Release` hop is
  enforced by the Platform Compatibility Review gate (Constitution Article VII).
- **Homes are fixed by the canonical-source principle:** the *invariant* lives in
  the Constitution; the *decision* here; the *procedure* in
  [`../governance/capability-evaluation.md`](../governance/capability-evaluation.md);
  the *per-capability answers* in the issue / PR / ADR templates. No layer
  restates another.

*Why record it as an ADR.* A governing procedure that only lives in an explanation
doc drifts silently and cannot be cited. As a numbered, dated decision it becomes
the fixed point future proposals defer to, and it makes the CEF amendable only the
same way it was adopted — by a successor ADR, never by ad-hoc edit.

## Alternatives Considered

- **Leave the CEF as prose in the Constitution only.** Rejected: the Constitution
  states invariants but is not itself a dated, supersedable decision record; a
  binding governance procedure needs an ADR so amendments are tracked and citable.
- **Encode the whole framework — questions, procedure, examples — in one
  document.** Rejected: it violates the canonical-source principle (Article IV.7).
  Invariant, decision, and procedure are three classes of information with three
  homes; collapsing them guarantees drift.
- **Put the procedure in the ADR.** Rejected: an ADR records *what was decided and
  why*, not *how to perform it*. Operational guidance belongs in governance docs,
  which can be revised as we learn without cutting a new decision.

## Consequences

- **Commits us to** running every future capability through the CEF, recording an
  Alignment block in every new ADR, and refusing to release a capability whose
  evidence (Q4) is absent.
- **New constraint:** proposals must answer the five questions in-issue (via the
  template), and the "smallest implementation" question makes *extend, don't
  rebuild* the default — a new build must show why existing work cannot be
  extended.
- **Becomes easier:** capability decisions are now reproducible and auditable
  end-to-end; the backlog has one explicit test instead of a re-derived instinct.
- **Maintenance burden:** the governance procedure doc needs an owner as lenses
  are refined; the Platform Compatibility Review gate must be implemented for the
  `Evaluation → Release` hop to be enforced rather than documentary.

## Open Questions

- **Retroactive traceability.** Whether and when the retained backlog issues are
  back-filled with a traceability section is left flexible; it is not a release
  gate. Owner: `jwogrady`.

## Related Docs

- [../product-constitution.md](../product-constitution.md) — the CEF invariant (Article VI) and the ownership boundaries
- [../governance/capability-evaluation.md](../governance/capability-evaluation.md) — the procedure for applying the CEF
- [0019-human-directed-product-model.md](0019-human-directed-product-model.md) — the four-party model the CEF sits beneath
- [0023-lifecycle-orchestration-topology.md](0023-lifecycle-orchestration-topology.md) and [0024-capability-based-model-selection.md](0024-capability-based-model-selection.md) — accepted, implementation-gated decisions whose status the Platform Compatibility Review keeps honest
- [../../evaluations/orchestration/README.md](../../evaluations/orchestration/README.md) — the existing evaluation harness the Evidence question consumes
