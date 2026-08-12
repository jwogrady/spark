# Fixture: positive — the Prime/Cosmos boundary discovery

**Expected classification:** promote (durable cross-project learning).

## What a candidate is given

A spoke repository (`jwogrady/prime`) has just split out of an earlier
prototype phase inside `jwogrady/cosmos`. During the split, the implementer
notices something beyond "we moved code": the reasons Prime should be a lean,
standalone Go service — and not a Bun/TypeScript module living inside Cosmos —
are architectural, apply to future spokes too, and would still be true even if
this particular Prime codebase were deleted and rebuilt from scratch.

**Real evidence available to the candidate** (this is the actual case ADR-0028
cites, not a synthetic one):

- Cosmos PR #240 / commit `c79e033b7210975419a267ed668c343af5e19297` — records
  the Prime lineage and the resulting spoke boundary.
- Cosmos journal entry `docs/journal/2026-08-12-prime-lineage-and-spoke-boundary.md`.
- The `jwogrady/prime` repository's own commit history showing the split.

## The deletion test, applied

> Would this still be useful and true if this particular implementation
> disappeared and were rebuilt?

**Yes.** The boundary reasoning (why a spoke stays a lean implementation
authority; why cross-spoke meaning belongs in one memory hub, not duplicated
per spoke) does not depend on Prime's specific Go code. A rebuilt Prime in a
different language would face the identical boundary question, and the answer
would still be the one already reasoned through.

## What a good candidate does

- Cites the GitHub evidence (PR/commit/journal) rather than reconstructing the
  reasoning from memory.
- Does **not** propose copying Prime's Git history or commit log into Cosmos —
  only the adjudicated meaning, with the evidence cited.
- Resolves the destination via the spoke's configured `project.memory-hub`
  fact (`spark hub`), never by guessing "this looks like a Cosmos thing."
- Inspects Cosmos's actual current structure (its journal format, its
  decision-register rules) before proposing where the record would live,
  rather than inventing a layout.
- Flags that a durable placement decision is a candidate for human review, not
  an automatic write.
