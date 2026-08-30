# Problem statement — carry durable learning across project boundaries

**Status:** Historical — the v0.17 planning problem, written 2026-08-12.
**Date:** 2026-08-12.
**Owner:** jwogrady.

> **Superseded as a statement of current planning, 2026-08-27 (#441).** This
> document is retained as the framing that produced the provenance-promotion
> work, and it is read here as history, not as present intent.
>
> The capability described below survived on `master` and shipped in `v0.19.0`;
> the v0.17 milestone is recorded as `Complete (no release)`. Why that is so is
> the release record [`docs/releases/v0.19.md`](releases/v0.19.md), which owns
> that account.
>
> Current planning and release truth live in
> [`ROADMAP.md`](../ROADMAP.md) and the v0.20 release gate (#443), never here.
> What Spark *is* today is recorded in
> [the pre-v0.20 IS-state baseline](governance/is-state-baseline-pre-v020.md).

## Problem

Spark can already carry information from a session into a project and deliberately
promote some project knowledge to the operator layer, but it has no first-class path
for a different case: several related repositories share one durable body of
architectural memory while each repository remains the authority for its own code and
release history.

That missing path produces two bad choices. A spoke can restate system-wide history and
reasoning locally, creating duplicate provenance that drifts, or it can leave important
learning in chat and Git history, forcing later sessions to reconstruct what the
engineering evidence meant.

The Prime/Cosmos field case made the gap concrete. Prime began as an identity primitive
inside Cosmos, earned an independent Go service/release boundary, and later shed a
premature Portal/Phoenix commitment. GitHub preserved the commits, issues, PRs, and
ADRs needed to recover that evolution. Cosmos was the right home for the durable
cross-spoke meaning of those events; Prime was the right home for its executable
implementation and local release truth. The reusable missing capability is the process
that recognizes that distinction and carries the learning to the right place.

## Outcome

The v0.17 outcome, as framed at the time: Spark provides a generic,
evidence-backed **provenance promotion** path for a spoke that belongs to a
larger constellation of related projects. That capability shipped to the public
in `v0.19.0`, not under a `v0.17.0` tag.

The ownership model is:

- **GitHub** preserves engineering evidence: commits, issues, pull requests, releases,
  source, tests, and proof references.
- **Spark** owns the process that decides whether discovered learning is merely local or
  a candidate for durable cross-project memory, gathers the evidence, and routes the
  candidate through any required human judgment.
- **A memory hub** is the durable knowledge authority for cross-project meaning within a
  related set of spokes.
- **A spoke** remains the authority for its implementation, tests, local architectural
  choices required to build it, roadmap, releases, and operational documentation.
- **Runtime** remains the source of observed operational truth.

Cosmos is the first dogfood memory hub. It is evidence for the design, not a hard-coded
Spark dependency.

## Core promotion test

At a natural work boundary, ask:

> Did this work teach us something that should remain known even if this
> implementation disappears and is rebuilt?

A **no** ends the check. The evidence remains in the spoke and GitHub.

A **yes** produces a promotion candidate. It does not authorize a write by itself. Spark
collects the engineering evidence, inspects the configured memory hub and its current
rules, and asks for human judgment when the candidate changes architectural meaning or
another decision owned by the human.

## Shippable release shape

The release is intentionally small:

1. **#374 — Architecture.** Define the memory-hub/spoke model and how it extends
   ADR-0008 without creating a second canonical source for any information class.
2. **#375 — Routing.** Give a spoke one explicit project fact that identifies its memory
   hub, with truthful missing/invalid behavior and no naming-convention guesses.
3. **#376 — Promotion.** Extend `knowledge` to classify local implementation truth versus
   durable cross-project learning, preserve GitHub evidence, and use the destination's
   existing knowledge structure and authority rules.
4. **#377 — Lifecycle and proof.** Surface the promotion question at natural lifecycle
   boundaries, prove both promotion and no-promotion cases, and dogfood the flow with
   Cosmos.

Release readiness is tracked by #373 and closes last.

## Success criteria

1. A spoke can name a memory hub without Spark knowing anything about Cosmos, Status26,
   Prime, or a repository naming convention.
2. The knowledge workflow can say **no promotion** and stop cleanly for routine
   implementation work.
3. A real durable lesson carries source GitHub evidence rather than copied history or
   agent recollection.
4. The hub's own document structure, supersession rules, and human authority govern the
   resulting record; Spark does not impose a universal provenance schema.
5. The five public lifecycle stages remain unchanged. Promotion is a carry-forward
   responsibility surfaced at natural boundaries, not a sixth stage or per-commit gate.
6. A positive Prime-like fixture and negative routine-engineering fixtures make the
   classification behavior reviewable.
7. A Cosmos dogfood run proves the complete path while Cosmos remains outside Spark's
   runtime dependencies.

## Prior art and evidence

- ADR-0008 already defines Operator / Project / Session layers, one canonical source per
  class, and explicit promotion. v0.17 extends that model to related projects rather
  than replacing it.
- `knowledge` already separates raw session material from durable project docs and
  requires deliberate promotion to operator vocabulary. v0.17 reuses that discipline.
- Cosmos PR #240 / commit `c79e033b7210975419a267ed668c343af5e19297`
  records the Prime lineage and the hub/spoke provenance lesson that triggered this
  release.
- Spark issues #373–#377 hold the executable release plan and acceptance criteria.

## Constraints

- Preserve one canonical source per information class.
- Never cite agent memory as engineering authority when durable GitHub evidence exists.
- Do not copy whole commit/issue histories into the memory hub.
- Do not silently accept architectural decisions; the human remains the directing
  authority under ADR-0019.
- Do not force cross-repository ceremony on routine engineering.
- Stay provider-neutral at the semantic boundary even when GitHub is the first evidence
  transport.

## Non-goals

- A provenance database, event stream, or synchronization daemon.
- A universal schema for every memory repository.
- Moving spoke code, tests, roadmap, release notes, or local implementation ADRs into a
  hub.
- Making all project knowledge operator-global.
- Replacing GitHub as the engineering record.
- Adding a new public lifecycle stage.
- Automatically writing a hub record after every issue, pull request, commit, or release.
