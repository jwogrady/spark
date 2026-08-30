# ADR: State, provenance, and runtime — one ownership contract

Date: 2026-08-30
Status: Accepted
Owner: jwogrady

## Alignment

- **Identity / prior decisions served:** ADR-0008 (three information layers, one canonical source per class), ADR-0028 (cross-project memory hubs), ADR-0029 (four artifact tiers), ADR-0019 (human-directed product model).
- **Supersedes / Superseded by:** nothing. This refines ADR-0008 and ADR-0028 by naming an axis both already relied on without stating; it introduces no competing information model and changes no layer, tier, class, or motion.
- **Status tracks evidence:** n/a. This is a human architectural ruling. The mechanical checks that enforce it are separate work and are named in Consequences; this ADR's status does not wait on them.

## Context

Spark had the right pieces and no explicit rule separating **what is true now** from **how it came to be true**. Three axes were in play and only two were written down:

| Axis | Question it answers | Where it was decided |
|---|---|---|
| Layer | *Whose* knowledge is this — operator, project, session? | ADR-0008 |
| Tier | Does this artifact *ship*? | ADR-0029 |
| **Kind of truth** | Is this **current state**, **provenance**, or **observed runtime**? | **nowhere** |

The third axis was being applied without being stated, so it was applied inconsistently.

ADR-0028 already ruled that GitHub evidence is "cited rather than transcribed into a second history" and that "runtime owns observed operational truth" — but scoped those rulings to memory hubs and their spokes. Any surface outside that relationship had no rule to appeal to. ADR-0029 named a "prose and provenance" tier and proved provenance leaks across boundaries, but it governs *whether an artifact ships*, not *what kind of truth it carries*.

The cost was not theoretical. `v0.22.0` shipped `triage`, `reconcile` and `course` with correct reference and operator documentation and every declared `docs-impact` satisfied, while `README.md` still described the previous product, the ROADMAP headline still named `v0.21.0` as the published baseline, and the v0.22 release record still read "no version has been cut". Three current-state surfaces were false at the moment of release. The regression and its fixture are kept in [../releases/v0.22.md](../releases/v0.22.md).

The opposite failure has the same root. Repository documents accumulate chronology — what was attempted, corrected, superseded — which Git and GitHub already hold in full. Every such copy is a second history that must be reconciled with the first, forever, and drifts the moment it is not.

Both failures are one missing rule: nobody had said which surface owns which kind of truth.

## Decision

**The canonical ownership rule:**

> **Repository code and docs own current state and durable meaning. Git/GitHub own provenance: how that state changed over time. Runtime owns observed operational truth.**

This is a third axis, orthogonal to layer (ADR-0008) and tier (ADR-0029). An artifact has a layer, a tier, *and* a kind of truth; deciding one never decides another.

### Repository tree — current state and durable meaning

Owns source and tests; configuration and standards; the current architecture and the *conclusions* of ADRs; current runbooks and operational instructions; current problem and product documentation; and the durable rationale still required to understand or operate the system as it exists now.

Current-state documentation describes **what exists now**. It is evidence only within the authority of the surface it represents: a README is authoritative for what the product is, not for what a test proves or what a run observed.

### Git / GitHub — provenance

Owns commits and diffs; pull-request discussion and review; issues and comments; milestone evolution; labels, dependencies and hierarchy over time; tags, releases and CI evidence; and superseded attempts and their chronology.

**GitHub remains the authority for backlog, execution history, reviews, milestones, and engineering evidence.** Nothing here moves any of that into the tree, and nothing here licenses deleting or rewriting it.

### Runtime — observed operational truth

Owns what the system is actually doing. **Observed behavior outranks intended and documented state.** A document that disagrees with a live observation is wrong; the observation is not wrong for disagreeing with the document.

### Citation, not transcription

**Current-state documents may cite GitHub evidence without copying event history into the repository.** A citation — an issue, a PR, a commit, a release — resolves to the authority that owns the fact and stays correct as that authority evolves. A transcription is a copy that begins drifting immediately and must be reconciled forever.

So a repository document may say *what is true now* and point at the evidence for it. It may not restate the sequence of events that produced it.

### Durable rationale is not chronology

The distinction that makes the rule usable:

| | Belongs in the tree | Belongs in Git/GitHub |
|---|---|---|
| **Durable rationale** — the *why* still needed to understand or safely change the current system, including important rejected alternatives | yes | cited |
| **Chronology** — the order events happened in, what was tried first, which attempt was corrected, when a decision moved | no | yes |

An ADR keeps its reasoning because a reader changing that code needs it. It does not keep a narrative of the pull requests that produced it.

### Memory and knowledge promotion

**Promotion preserves durable meaning derived from evidence — never duplicated Git history.** A promoted record carries the adjudicated conclusion and cites the provenance that established it. ADR-0028's promotion chain and its hub/spoke ownership split are unchanged; this ADR states generally what that ADR ruled for hubs.

### The boundary test

For any historical statement in a repository document, ask:

> **Does this information need to remain in the checked-out tree to understand or operate the current system?**

- **yes** → retain the durable conclusion or rationale, and cite the evidence;
- **no** → leave the chronology and provenance in Git/GitHub.

*Why this rule and not a looser one:* the alternative in practice is "write down whatever seems useful", which is how a repository acquires a second, worse copy of its own history. The test is deliberately about the *reader of the current system*, not about whether the information is interesting or hard-won — interesting history is exactly what Git already keeps, in more detail and without drift.

### Reconciliation with ADR-0008 and ADR-0028

Neither is rewritten; ADRs are append-only, so both keep their decisions and gain a pointer here.

- **ADR-0008** decides layer, class, canonical source and the carry motions. It is untouched and remains authoritative for all of them. This ADR adds the axis it did not name: within the Project layer, the repository and GitHub hold *different kinds of truth about the same project*, and "one canonical source per class" now resolves that split explicitly rather than by convention.
- **ADR-0028** ruled, for memory hubs, that GitHub evidence is cited rather than transcribed and that runtime outranks documented state. **Those two rulings are general and are now owned here**, so they are stated once rather than in every context that needs them. Everything specific to hubs — the hub/spoke relationship, the "would this still be true if the implementation were rebuilt" classification test, the promotion chain, at most one hub per spoke — remains ADR-0028's and is unchanged.

The terminology audit that makes every surface use `provenance` in this ADR's sense is **not** part of this decision; it is tracked separately, and this ADR is the definition that audit resolves against.

## Alternatives Considered

- **Amend ADR-0008 in place.** Rejected: the template makes ADRs append-only precisely so a past decision cannot be quietly restated. ADR-0008 was correct for what it decided; it simply did not decide this.
- **State the rule in `philosophy.md`.** Rejected: that document ships (ADR-0029's shipped tier) and is a principles essay for operators. This is an internal architectural ruling with named consequences and mechanical follow-through, which is what an ADR is for. A shipped principles page would also put this repository's internal governance in front of every installer.
- **Extend ADR-0028 to cover every surface.** Rejected: ADR-0028 is *about* the hub/spoke relationship. Generalizing it there would make every non-hub consumer read a cross-project memory decision to learn a repository-wide rule, and would leave the general rule discoverable only through the specific one.
- **State the rule in each document that needs it.** Rejected outright: duplicate authority is the defect this ADR exists to end. A rule copied into README, the roadmap, the audit skill and the release checklist has four spellings and no owner, and the first correction to any one of them creates a contradiction.
- **Add a mechanical check in this decision.** Rejected as scope: a rule and its enforcement are separable, and the enforcement work has its own issues, evidence and acceptance criteria. Deciding the boundary first is what lets those checks be written against something stable.

## Consequences

**What becomes possible.** Four pieces of work now have one definition to resolve against instead of four opinions: removing duplicated chronology from state documents, teaching `audit` to detect provenance leakage as a first-class finding, the terminology split that reserves `provenance` for change history, and the release-level `docs-truth` check. Each consumes this contract; none is part of it.

**What it commits us to.** Every new information kind must be classed on a third axis before it ships, not only layered and tiered. Reviews acquire a question they did not have — *is this current state, or is it chronology that Git already owns?* — and the honest answer will sometimes be that a well-written paragraph should be deleted because the tree is not where it belongs.

**What it does not do.** It deletes no historical GitHub evidence, removes no legitimate current-state rationale, rewrites no Git history, and redesigns no layer. Historical records — release records, dogfood evaluations, superseded ADRs — are **provenance and are preserved as written**. Bringing an old record's wording into line with current terminology would erase evidence to make history agree with the present, which is the failure mode this ADR names.

**The cost.** The boundary test is a judgment, not a lint rule. It will be applied by people and agents who disagree at the margin, and a check can only ever catch the clear cases. That is accepted: an unstated rule applied inconsistently is strictly worse than a stated rule applied imperfectly.

## Related Docs

- [../architecture/spark-internals.md](../architecture/spark-internals.md) — the architecture map
- [0008-information-architecture.md](0008-information-architecture.md) — layer, class, canonical source, and the carry motions this axis is orthogonal to
- [0028-cross-project-memory-hubs.md](0028-cross-project-memory-hubs.md) — hub/spoke ownership and the promotion chain; its general citation and runtime rulings are stated here
- [0029-four-tier-artifact-separation.md](0029-four-tier-artifact-separation.md) — whether an artifact ships, and the provenance-leak evidence that motivated this axis
- [0019-human-directed-product-model.md](0019-human-directed-product-model.md) — the human judgment boundary this rule does not displace
- [../releases/v0.22.md](../releases/v0.22.md) — the current-state documentation regression this contract exists to prevent
