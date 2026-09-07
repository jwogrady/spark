# ADR: One operative fact model, separate from provenance and from state

Date: 2026-09-06
Status: Accepted
Owner: jwogrady

## Alignment

- **Identity / prior decisions served:** ADR-0008 (GitHub owns the backlog and
  execution history), ADR-0010 (three-tier preferences: shipped machine-readable
  authority rendered by reference prose), ADR-0030 (a governance model is data,
  with one machine-readable authority and a page checked against it), ADR-0031
  (the repository owns current state and durable meaning, Git/GitHub own
  provenance, runtime owns observed truth).
- **Supersedes / Superseded by:** nothing. ADR-0032 is reserved by the
  bounded-increment merge-authority decision still in review on its own branch.
- **Status tracks evidence:** n/a — this ADR records a schema contract; the
  behavior that consumes it (snapshots, freshness) lands under its own issues
  and is measured against the frozen v0.23 baseline before adoption.

## Context

The v0.23 baseline (`docs/research/v0.23-optimization-baseline/`) established
that an agent executing a governed work unit spends most of its context
re-deriving facts that did not change between rounds — repository identity,
milestone and gate placement, the parent, the standing authority, the acceptance
contract — and that the reviewer's dominant complaint about the merge-authority
work was how those facts were represented, parsed, bound and re-read rather than
what the code intended (54 % of findings were representation, stale-state or
duplicate-semantics defects). The repository also carries the same governed
concept in many hand-written shapes: eight independent definitions of repository
identity, seven of work-unit identity, three verdict vocabularies, and no shared
notion of "this fact is bound to that HEAD".

There was no contract naming what an operative fact *is*: which classes an agent
needs, how a fact is carried, how it says "I could not read the source" without
that reading as "nothing is wrong", and which identifier spelling is the one
consumers compare on. Without it, every consumer would keep inventing its own,
and a snapshot compiler would have nothing stable to compile into.

## Decision

**Spark defines one machine-readable operative fact model, versioned, carried in
`plugins/spark/preferences/fact-model.tsv` and rendered by
`plugins/spark/docs/reference/fact-model.md`, whose examples are executable
fixtures once the behavioral suite lands (it is delivered by a pull request
stacked on the schema, because the independent review lane reads at most
200,000 bytes of diff and the two together exceed it).**

- Ten fact classes cover what a governed work unit needs: work unit,
  repository, placement, graph, authority, acceptance, head, review, checks, and
  a derived next action. Provenance, freshness and certainty are facets of the
  envelope every fact carries, not further facts.
- A fact carries a value only when its status is ESTABLISHED. UNKNOWN,
  CONFLICT and NOT_APPLICABLE are explicit statuses with a machine-shaped
  `detail`; they carry no value, so absence can never be read as an affirmative
  empty answer.
- Canonical identifiers have one form each — fully qualified work units
  (`host/owner/name#n`), full 40-hex commits, `login:` actors, the reviewer's
  closed verdict vocabulary — and everything else is a projection.
- HEAD-bound classes list the HEAD among their invalidators; derived facts list
  the keys that decided them. That is the minimum the freshness contract needs
  to invalidate mechanically rather than by age or judgment.
- Authority is a `human-decision` source with a durable record identity, never
  an inference from capability, role or prose. Facts are never written to
  `.spark/state.json`; the state file keeps its two judgment values.
- Everything a consumer must act on is a closed token, not prose: authority
  scopes and human boundaries, check states, relationship states, verdicts and
  next actions. Every value has an exact shape, recursively; a source's
  identity follows the grammar of its type (a human decision is a comment or
  commit locator, never a role or summary); a grant names the repository or
  work unit it applies to. A snapshot is the complete set of required classes
  exactly once; anything smaller is a fragment and is never consumed as a
  snapshot.
- The model is classified Experimental. Its `version` is the schema version
  every fact carries; a consumer that meets an unknown version treats the fact
  as UNKNOWN and never reinterprets fields. Nothing is added or changed under an
  existing version — any new field, class or vocabulary member is a new version
  — so a consumer rejects what it does not know and an older consumer can never
  accept a snapshot it cannot judge complete. A derived fact's version records
  every input's version, so a derivation over different inputs is a different
  fact.

Why this shape: the baseline showed the cost is in *re-establishing* facts, so
the contract must make a fact self-describing enough to be reused safely — what
was read, at which version, what invalidates it — and strict enough that the
failure modes the reviewer kept finding (bare numbers as identities, permissive
defaults, verdicts read from untrusted shapes, prose used as authority) are not
representable. Putting the authority in a TSV rendered by a checked page is the
pattern the governance model already proved, and the test that validates the
page's examples against the TSV is what keeps prose from becoming the schema.

## Alternatives Considered

- **JSON Schema as the authority.** More expressive, but it would introduce a
  validator dependency into shipped code and break the house pattern of
  zero-dependency, line-oriented authorities that `awk` can read. The reference
  page and behavioral suite give the same discrimination without the
  dependency.
- **Storing facts in `.spark/state.json`.** Rejected by ADR-0031 and by the
  v0.16 field failure the state reference records: a stored copy of a derivable
  fact is a staleness generator. Facts live in snapshots keyed by source
  version, never in committed state.
- **Letting each consumer keep its own representation and reconciling later.**
  That is the current state the baseline measured; it is the problem, not an
  alternative.
- **Modeling GitHub broadly (bodies, timelines, all metadata).** Rejected as a
  non-goal: the model must stay the smallest set an agent needs, or it becomes
  a second copy of GitHub that has to be maintained and will disagree with the
  first.

## Consequences

- Consumers gain one vocabulary to speak; the freshness, invalidation and
  conflict contract can be written against this envelope rather than against
  each consumer's shape.
- The doc↔TSV parity and the executable examples add a suite,
  `tests/test-fact-model.sh`, delivered by the stacked pull request — until it
  lands, what the page and the TSV say the suite checks is prospective; the shipped
  reference page must not use issue-number references (the tier boundary), so
  its examples use an invented repository.
- Until the snapshot work lands, nothing reads this model at runtime. That is
  deliberate: the measured system stays frozen until the AFTER side can be
  compared against the baseline.

## Related Docs

- `plugins/spark/docs/reference/fact-model.md`, `plugins/spark/preferences/fact-model.tsv`, `tests/test-fact-model.sh`
- `docs/research/v0.23-optimization-baseline/README.md` (the BEFORE evidence)
- ADR-0030, ADR-0031
