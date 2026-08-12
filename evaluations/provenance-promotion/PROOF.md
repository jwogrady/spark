# Proof run — applying the ADR-0028 classifier to the fixtures

> Evidence for #377 / the #373 release gate. Tags follow Cosmos's own journal
> discipline (`[observed]` seen in running code/repo state, `[reasoned]`
> argued from the deletion test, `[human]` a ruling ADR-0028 reserves for the
> person) so the record itself demonstrates the evidence/judgment separation
> the mechanism requires.

## Positive: `fixtures/positive-boundary-discovery.md`

- `[observed]` Cosmos PR #240 (commit `c79e033b7210975419a267ed668c343af5e19297`)
  and the Cosmos journal entry `2026-08-12-prime-lineage-and-spoke-boundary.md`
  exist and record the Prime/Cosmos split as a real, already-adjudicated case.
- `[reasoned]` Applying the deletion test: the boundary reasoning (spoke stays
  a lean implementation authority; cross-spoke meaning lives in one hub) does
  not depend on Prime's specific code — a rebuilt Prime meets the identical
  question. **Verdict: promote.**
- `[reasoned]` The evidence bundle cites GitHub objects; it does not propose
  transcribing Prime's commit history into Cosmos (ADR-0028's "cited rather
  than transcribed" rule).
- `[human]` Where the record should land inside Cosmos (which document, what
  supersedes what) is a placement decision under Cosmos's own governance —
  the dogfood run below shows this stopping for that ruling rather than
  guessing it.
- **Result: matches the fixture's expected classification (promote).**

## Negative: `fixtures/negative-routine-refactor.md`

- `[observed]` The described change (extracting a repeated `awk` filter into
  one helper) is the same shape as real Spark commits, e.g. the
  `read_flat_json` extraction — a mechanical implementation choice with no
  external contract change.
- `[reasoned]` Applying the deletion test: a rebuild would very likely
  re-derive this refactor on its own; it carries no boundary or cross-project
  meaning. **Verdict: local.**
- **Result: matches (local, zero ceremony).**

## Negative: `fixtures/negative-dependency-bump.md`

- `[reasoned]` A version pin is a fact about this repo's dependency graph at
  this moment; nothing survives a rebuild that a fresh build wouldn't
  re-derive from the current registry state. **Verdict: local.**
- **Result: matches (local, zero ceremony).**

## Negative: `fixtures/negative-release-work.md`

- `[observed]` CHANGELOG.md and GitHub Releases already preserve release
  mechanics durably, in the spoke — the exact ownership ADR-0028 assigns.
- `[reasoned]` The release act itself carries no meaning distinct from what
  shipped; only the shipped *content* (if it were a boundary discovery) could
  be a candidate, and this fixture's content is ordinary. **Verdict: local.**
- **Result: matches (local, zero ceremony).**

## Summary

| Fixture | Expected | Classified | Evidence-only moves | Human-judgment moves |
|---|---|---|---|---|
| positive-boundary-discovery | promote | promote | 2 `[observed]`, 2 `[reasoned]` | 1 `[human]` (placement) |
| negative-routine-refactor | local | local | 1 `[observed]`, 1 `[reasoned]` | 0 |
| negative-dependency-bump | local | local | 1 `[reasoned]` | 0 |
| negative-release-work | local | local | 1 `[observed]`, 1 `[reasoned]` | 0 |

All four fixtures classify correctly. The one candidate that reaches
"promote" still stops at a `[human]` placement ruling before any write — see
[`dogfood-cosmos.md`](dogfood-cosmos.md) for that stop demonstrated against
the real Cosmos repository rather than a described one.
