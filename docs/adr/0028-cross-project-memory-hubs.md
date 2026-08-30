# ADR: Cross-project memory hubs carry durable shared meaning

Date: 2026-08-12
Status: Accepted
Owner: jwogrady

## Alignment

- **Identity / prior decisions served:** ADR-0008 (three information layers and one canonical source per class), ADR-0019 (human-directed product model), ADR-0027 (current delivery model).
- **Supersedes / Superseded by:** nothing. This extends ADR-0008 for related-project memory; it does not replace the Operator / Project / Session layers.
- **Generalised by:** ADR-0031. The responsibilities below — GitHub as engineering evidence cited rather than transcribed, runtime as observed truth, meaning promoted without copied history — are this decision applied to hubs and spokes. ADR-0031 states the same boundary as a general rule for every repository document, so it can be cited where no hub is involved. The ruling here is unchanged; only its scope was narrower than the rule it was using.
- **Status tracks evidence:** n/a. The boundary is a human architectural ruling; v0.17 implementation and dogfood evidence must still prove the proposed workflow.

## Context

ADR-0008 gives every Spark artifact one Operator, Project, or Session home and requires explicit promotion between layers. That model works when durable project knowledge belongs to the same repository that implements the project, and when genuinely operator-wide knowledge should travel to every project.

A fourth ownership situation has now been demonstrated by the Prime/Cosmos work. Several related repositories can share durable architectural meaning that is broader than one spoke but narrower than the operator's universal knowledge. Prime's implementation and release truth belong in `jwogrady/prime`; the reasons Prime exists, how it emerged from the Cosmos prototype, and what its boundary means across the constellation belong in Cosmos. GitHub supplied the underlying engineering evidence needed to reconstruct that story.

Putting that meaning in every spoke would create duplicate provenance. Putting it in operator-global knowledge would make Status26-specific architecture travel into unrelated projects. Leaving it only in chat or raw Git history would preserve evidence without preserving the adjudicated meaning.

Cosmos records the worked example in PR #240 / commit `c79e033b7210975419a267ed668c343af5e19297`. The human ruling from that work is that Spark, not each spoke, should own the reusable promotion process.

## Decision

Spark recognizes a **memory hub** as a Project-layer repository that is the designated durable knowledge authority for cross-project meaning within a related set of **spokes**.

This is an ownership relationship between projects, not a new global information layer.

The responsibilities are:

- **GitHub is engineering evidence.** Issues, PRs, commits, releases, source, tests, and proof references establish what changed and what was observed. They are cited rather than transcribed into a second history.
- **Spark owns provenance promotion.** Spark surfaces the classification question, gathers evidence, and routes a durable-learning candidate to the configured hub. Spark does not become the knowledge store.
- **The memory hub owns shared meaning.** It preserves the why, cross-spoke boundaries, durable conceptual meaning, important rejected alternatives, and supersession history for its constellation.
- **Each spoke owns its implementation truth.** Source, tests, implementation-required local ADRs, roadmap, releases, and operational documentation remain local.
- **Runtime owns observed operational truth.** Documents and release intent cannot overrule what is actually running.
- **The human owns architectural judgment.** A candidate that would create or change an architectural decision stops for the human ruling required by ADR-0019 and by the destination repository's own governance.

A spoke may identify at most one canonical memory hub for this class of cross-project provenance. The pointer is a project fact; the hub's contents are not mirrored into the spoke.

The default classification test is:

> Would this still be useful and true if this particular implementation disappeared and were rebuilt?

If **no**, the knowledge remains local to the spoke/GitHub record.

If **yes**, it may be proposed for promotion. A positive classification is not automatic write authority. Spark must inspect the current hub and follow its existing placement, supersession, review, and human-decision rules.

Promotion therefore follows this chain:

    working discovery / conversation
            -> spoke GitHub evidence
            -> Spark classification
            -> human judgment when required
            -> memory-hub durable record

This extends ADR-0008's carry-forward motion from `Session -> Project` and `Project -> Operator` with an explicit **Project -> related Project memory authority** case. It does not make the memory hub an Operator-layer store and does not change the rule that one canonical source owns each information class.

## Alternatives Considered

- **Repeat the provenance policy and history in every spoke.** Rejected because it recreates the synchronization burden the hub exists to remove and makes cross-project meaning diverge.
- **Promote all shared learning to the Operator layer.** Rejected because architecture for one constellation is not automatically useful or appropriate in unrelated repositories.
- **Make Cosmos a Spark-specific special case.** Rejected because Spark owns a reusable discipline, not Status26 architecture. Cosmos is dogfood evidence and the first configured hub, not a product dependency.
- **Copy every GitHub event into the hub.** Rejected because GitHub already preserves the evidence. The hub exists for adjudicated durable meaning, not event duplication.
- **Leave provenance in chat and reconstruct it on demand.** Rejected because conversations are working memory, not a stable, citable, supersedable engineering record.

## Consequences

- v0.17 must provide a minimal project fact for identifying a memory hub (#375).
- `knowledge` becomes the single reusable classifier/promotion path rather than duplicating provenance logic across lifecycle skills (#376).
- Lifecycle skills only surface the question at natural boundaries and hand positive candidates to `knowledge` (#377).
- A project with no configured hub behaves exactly as a normal standalone Spark project; no cross-project write is implied.
- Memory hubs remain ordinary repositories with their own structure and governance. Spark must adapt to their current rules instead of imposing a universal document layout.
- The model adds one relationship to Spark's information architecture, but avoids a fourth global layer and keeps Project/Operator scoping intact.
- Cosmos can dogfood the capability while Prime and other spokes stay lean.

## Open Questions

Resolved by implementation (#375/#376/#377, closed):

- The project key is `project.memory-hub`, resolved through the standard
  preference tiers; `spark hub` reports the value and its source. The locator
  is a provider-neutral string (`owner/repo`, a URL, or an scp-style git
  address) — GitHub-backed today without GitHub-specific transport as the
  semantic model.
- The evidence bundle and classification contract live in `knowledge`'s
  `hub-promotion.md`: the ADR-0028 deletion test classifies local versus
  durable versus needs-ruling, candidates carry source-repo GitHub evidence
  cited rather than transcribed, and any write goes through the hub's own
  inspected structure and rules.
- The lifecycle surfaces are `codify` (falsified-assumption discovery,
  triggered immediately rather than deferred), `validate` (a finding that
  reveals durable learning), and `ship` (issue completion, plus milestone
  completion via the release motion) — three boundaries, no sixth stage.

## Related Docs

- [0031-state-provenance-ownership.md](0031-state-provenance-ownership.md) — the general state/provenance rule these responsibilities apply to hubs
- [0008-information-architecture.md](0008-information-architecture.md) — canonical Operator / Project / Session model and explicit promotion rule
- [0019-human-directed-product-model.md](0019-human-directed-product-model.md) — human judgment and approval boundary
- [../problem-statement.md](../problem-statement.md) — v0.17 problem and shippable outcome
- GitHub #373 — v0.17 release gate
- GitHub #374 — architecture issue this ADR resolves
