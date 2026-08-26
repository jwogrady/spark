# hub promotion — durable cross-project learning to the configured memory hub

> Reference for the `knowledge` skill and its librarian-editor. Defines how a
> finding is classified as spoke-local versus durable cross-project learning,
> and how a positive candidate is promoted to the configured memory hub. This
> instantiates ADR-0028's Project → related-Project memory-authority motion
> (developer-only:
> [ADR-0028](https://github.com/jwogrady/spark/blob/master/docs/adr/0028-cross-project-memory-hubs.md)).
> It composes with [`operator-knowledge.md`](operator-knowledge.md), which
> stays glossary-only — the two promotion lanes never mix.

## The destination is resolved, never guessed

`spark hub` is the only source of the destination:

| `spark hub` reports | Promotion meaning |
|---|---|
| configured locator | promotion is possible — to exactly that repository |
| `none` (declared standalone) | settled: everything stays local, ask nothing |
| not configured | standalone by default: everything stays local, ask nothing |
| malformed (exit 1) | blocked: report the broken pointer; never guess a sibling |

Never derive a hub from repository naming, org conventions, or history — a
missing pointer means the promotion question is already answered.

## The classification test

For each finding, answer ADR-0028's deletion test:

> Would this still be useful and true if this particular implementation
> disappeared and were rebuilt?

- **No → local.** It stays in the spoke's docs/ADRs and GitHub record. This is
  the common case and it is a complete, successful outcome.
- **Yes → promotion candidate.** Not write authority — a candidate enters the
  protocol below.
- **Unclear → needs ruling.** Record it as an open question for the human;
  never resolve architectural doubt by classifying around it.

**The negative boundary.** Routine refactors, dependency bumps, ordinary bug
fixes, expected release work, implementation-required local ADRs, roadmaps,
and operational docs remain local *unless the work revealed a lesson that
survives the deletion test on its own* — and then it is the lesson, never the
activity log, that is the candidate.

## The evidence bundle

Every candidate carries durable source-repository GitHub links — issue, PR,
merge commit, release, and source/test/proof references as appropriate.
Evidence is **cited, not transcribed**: the hub records adjudicated meaning
and points at the spoke's GitHub objects for the engineering record. Agent
memory and chat are never citable authority — if a claim has no repo/GitHub
evidence, it is an assumption and is marked as one.

## The hub's rules govern the write

Before proposing any placement, inspect the hub as it is today — its README,
docs layout, contribution/governance rules, and where it keeps journal-like
reasoning versus accepted decisions. Then:

- **Adapt; never impose.** File into the hub's existing structure. Spark's own
  docs layout carries no authority in another repository.
- **Update over duplicate.** Prefer amending the hub's existing truth to
  creating a near-duplicate.
- **Preserve supersession.** When new learning replaces old, mark the old
  record superseded per the hub's convention — never rewrite its history.
- **Route by kind.** Reasoning/evolution goes to the hub's journal-like
  authority; accepted decisions/specification land only where the hub's rules
  and an explicit human ruling put them.
- **Write through the hub's own process** — its branch/PR flow or documented
  intake path, under its permissions. One candidate at a time; there is no
  bulk copy of commits, issues, or PRs, ever.

## Human authority

A candidate that would create or change an architectural ruling stops for the
explicit human decision (ADR-0019) — in both repositories' terms: Spark asks
before promoting, and the hub's own review still applies. Factual evidence can
be recorded without inventing a ruling; absence of a ruling is stated, not
filled in.

## No-op is first-class

When nothing durable changed, the run ends with a one-line "no promotion —
nothing crossed the deletion test" note in the editor log. No hub contact, no
issue, no ceremony. Routine engineering must stay exactly as cheap as it was
before hubs existed.

## Where this runs in the crew

- **Phase 2 (shelve):** the librarian-editor answers the deletion test for the
  material and writes a **Hub candidates** section in
  `.knowledge-notes/librarian.md` — each candidate with its classification,
  evidence links, and proposed hub placement (from actual hub inspection) — or
  "none". A malformed or absent hub pointer is reported there truthfully.
- **Between phases:** the orchestrator presents candidates to the human;
  nothing is promoted without explicit approval, per candidate.
- **Phase 4 (file):** for each approved candidate, the librarian-editor
  prepares the promotion package (adjudicated meaning + evidence citations)
  and files it through the hub's own process.
