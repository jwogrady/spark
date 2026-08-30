# ADR: The repository owns current state; Git and GitHub own provenance

Date: 2026-08-30
Status: Accepted
Owner: jwogrady

## Alignment

- **Identity / prior decisions served:** ADR-0008 (three information layers, one canonical source per class), ADR-0028 (cross-project memory hubs), ADR-0029 (four-tier artifact separation), ADR-0019 (human-directed product model).
- **Supersedes / Superseded by:** nothing. This names an axis those decisions each assume and none states — it does not replace the Operator / Project / Session layers, the memory-hub relationship, or the artifact tiers.
- **Status tracks evidence:** n/a. This is a human architectural ruling about where information belongs, not a behavior gated on an experiment.

## Context

Spark already had the right pieces and no rule joining them.

ADR-0008 answers **which layer owns a class of artifact** — Operator, Project, or Session — and gives each class one canonical source. ADR-0029 answers **where an artifact may physically live** — code, shipped documentation, prose/provenance, or project management. ADR-0028 answers **which repository owns durable meaning** when several related repositories share it.

None of them answers the question that keeps recurring: for information about *how something came to be*, does it belong in the checked-out tree or in the history?

Without that rule, the same fact gets written twice. A decision's reasoning lands in an ADR *and* the sequence of attempts that produced it lands beside it. A release record accumulates a narrative that GitHub already holds as commits, PRs and tags. Every one of those duplicates then has to be kept in step by hand, and the reconciliation cost is paid forever, in every future edit of both copies.

The failure is asymmetric and that is why it needs a rule rather than judgement. A missing rationale is visible — someone reads the code and cannot tell why. A duplicated chronology is invisible: both copies look correct on the day they are written, and they only disagree later, silently, usually while someone is relying on the wrong one.

## Decision

**Three owners, one axis.**

> **Repository code and docs own current state and durable meaning.
> Git and GitHub own provenance: how that state changed over time.
> Runtime owns observed operational truth.**

### Three axes, and this is the third

An artifact has a **layer**, a **tier**, *and* a kind of truth. Deciding any one
never decides another, and the third had been applied without ever being stated —
which is why it was applied inconsistently.

| Axis | Question it answers | Decided in |
|---|---|---|
| **Layer** | Whose knowledge is this — the ownership scope: operator, project, or session? | ADR-0008 |
| **Tier** | Whether and how the artifact ships | ADR-0029 |
| **Kind of truth** | Is this **current state**, **provenance**, or **observed runtime**? | **this ADR** |

The axis cuts *across* the layers rather than adding a fourth: Project-layer
information has both a current state and a provenance, and so does Operator-layer
information.

### The repository tree — current state and durable meaning

Owns source and tests; configuration and standards; current architecture and the *conclusions* of ADRs; current runbooks and operating instructions; current problem and product documentation; and the durable rationale still required to understand or operate the system as it is now.

### Git and GitHub — provenance

Owns commits and diffs; pull-request discussion and review; issues and their comments; milestone evolution; labels, dependencies and hierarchy over time; tags, releases and CI evidence; and superseded attempts and chronology.

**GitHub remains the authority for backlog, execution history, and engineering evidence.** Nothing here moves that into the tree.

### Runtime — observed operational truth

What is actually running outranks what any document intends or records. A document that disagrees with observed behavior is wrong, not authoritative.

### The boundary test

For any historical statement in a repository document, ask:

> Does this need to remain in the checked-out tree to understand or operate the **current** system?

- **Yes** — keep the durable conclusion or rationale in the repository, and cite the evidence.
- **No** — it is provenance. It belongs in Git and GitHub, and must not be transcribed into a state document.

### Durable rationale is not chronology

The distinction the test turns on, stated plainly because it is the one people get wrong:

- **Durable rationale** is *why the current system is the way it is* — the constraint that forced a shape, the alternative that was rejected and why, the failure mode a design exists to prevent. It survives rebuilding the implementation. **It belongs in the tree.**
- **Chronology** is *the sequence in which we arrived* — what was tried first, which PR changed what, when a decision was revisited, who reviewed it. It is evidence of how the state changed. **It belongs in the history.**

An ADR's *Alternatives Considered* section is durable rationale: it stops the next person re-proposing a known dead end. A narrative of the three commits that produced the ADR is chronology, and GitHub already holds it, more accurately and without maintenance.

### Citing is not copying

Current-state documents **may and should cite** GitHub evidence — an issue, PR, commit or release — as the provenance for a claim. Citing is a pointer that stays true. Transcribing the event history into the document creates a second copy that must be maintained and will eventually disagree with the first.

**A citation is enough for the provenance detail** — how the state came to be. If the reader needs that, the link has it in its original form, with its own history intact.

It is **not** enough for durable rationale. Reasoning a reader needs in order to understand or safely operate the current system stays in the tree, written out. A link is not a substitute for it: an operator reading a runbook, or an engineer changing a design, must not have to leave the checked-out tree to learn why it is shaped as it is. The citation carries the *evidence*; the tree carries the *conclusion*.

### Memory hubs preserve meaning, not history

Promotion to a memory hub (ADR-0028) carries **durable meaning derived from evidence**, citing its GitHub provenance. It does not carry a copy of the event history. A hub that accumulated the spokes' chronology would be the same duplication one layer up, and would be the harder copy to correct.

## Alternatives Considered

- **Leave it implicit.** Rejected: it already was. ADR-0028 states most of this rule inside its responsibilities list, correctly, but scoped to hubs and spokes. A rule that only exists inside a decision about memory hubs cannot be cited when the question is about a release note or an ADR, so the same boundary was being re-derived per document, with different words each time.
- **Extend ADR-0008 with a fourth layer.** Rejected: state-versus-provenance is not a layer, it is an axis that cuts across all three. Project-layer information has both a current state and a history; so does Operator-layer information. Modelling it as a layer would force every class to be classed twice, and ADR-0008's table would stop meaning one thing.
- **Rewrite ADR-0008 and ADR-0028 to state the rule directly.** Rejected: ADRs are append-only by house rule, and both decisions are correct as made. Rewriting them to match today's wording would destroy the provenance of the decisions themselves — the exact failure this ADR exists to prevent, committed in the act of documenting it.
- **A prose style guide instead of an ADR.** Rejected: this constrains where information may live, which is an architectural decision with consequences for tooling. A style guide is advice; the boundary test needs to be citable when refusing a change.

## Consequences

- **A refusal now has a citation.** "This is chronology; GitHub owns it" is a decision someone can point at, rather than a reviewer's preference.
- **Documents get shorter and truer.** Removing narrative that GitHub already holds removes the copy that could drift, and the remaining text is entirely about the system as it now stands.
- **The cost is a judgement call per historical statement.** The boundary test is quick but not free, and the two cases genuinely blur — some rationale only makes sense with a sentence of history around it. When they blur, keep the conclusion and cite the evidence; that resolves the case without inventing a third home.
- **Nothing is deleted from GitHub, ever.** This decision moves nothing out of the history and rewrites no history. It governs what the *tree* carries.
- **Existing documents are not retroactively purged.** This ADR states the rule; it does not authorize a sweep. Documents are reconciled when they are next edited, or by an issue that names them.

## Related Docs

- [0008-information-architecture.md](0008-information-architecture.md) — which layer owns each class; this ADR adds the state/provenance axis across all three
- [0028-cross-project-memory-hubs.md](0028-cross-project-memory-hubs.md) — the hub-scoped instance of this rule, and the promotion chain that applies it
- [0029-four-tier-artifact-separation.md](0029-four-tier-artifact-separation.md) — where an artifact may physically live, which is a separate question from what it may say
- [../architecture/spark-internals.md](../architecture/spark-internals.md) — the architecture map, which links back to this axis
- `plugins/spark/docs/explanation/philosophy.md` — the principles this rests on
