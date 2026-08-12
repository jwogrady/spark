# Provenance-promotion proof (#377)

> Evidence for the v0.17 release gate (#373), not shipped capability
> measurement. Unlike `orchestration/` and `skill-routing/`, this suite scores
> no cost or latency metric — the ADR-0028 deletion test is a judgment call an
> agent makes in prose, not a numeric comparison across topologies — so there
> is no `run.sh`/`rates.tsv`/`eval.sh` wiring. What it shares with the sibling
> suites is the shape: fixed fixtures, a recorded answer key, and a written
> proof run against them, kept outside `tests/` because it is not a pass/fail
> unit suite.

## What this proves

Two acceptance criteria from #377:

1. **The classifier separates the two cases correctly.** One positive fixture
   models the Prime/Cosmos class of discovery (an implementation reveals a
   durable boundary whose meaning belongs in the hub); three negative fixtures
   model the routine-engineering cases the release gate names explicitly
   (refactor, dependency bump, expected release work) that must stay local.
2. **The proof records what required human judgment and what was factual
   evidence only** — [`PROOF.md`](PROOF.md) tags every classification move
   `[observed]` (cited GitHub/repo fact), `[reasoned]` (argued from the
   deletion test), or `[human]` (a ruling ADR-0028 reserves for the person),
   the same evidence-class discipline Cosmos's own journal already uses.

## Fixtures

| Fixture | Class | Models |
|---|---|---|
| [`fixtures/positive-boundary-discovery.md`](fixtures/positive-boundary-discovery.md) | promote | A Prime/Cosmos-shaped discovery: an implementation split reveals a durable cross-spoke boundary. |
| [`fixtures/negative-routine-refactor.md`](fixtures/negative-routine-refactor.md) | local | An internal refactor with no external behavior change. |
| [`fixtures/negative-dependency-bump.md`](fixtures/negative-dependency-bump.md) | local | A routine dependency version bump. |
| [`fixtures/negative-release-work.md`](fixtures/negative-release-work.md) | local | Expected release-train mechanics (changelog roll, version bump). |

## The Cosmos dogfood run

[`dogfood-cosmos.md`](dogfood-cosmos.md) records a real run against the actual
`jwogrady/cosmos` repository — its current structure inspected live, not
assumed — through to the point ADR-0028 requires a human ruling. The write
itself is prepared, not executed, pending the explicit go-ahead the mechanism
itself demands; the proof value is that the chain runs correctly and stops
exactly where it must.
