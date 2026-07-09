# ADR: Information architecture — three layers, one canonical source per class

Date: 2026-07-08
Status: Accepted
Owner: jwogrady

## Context

Spark manages many kinds of information — operator preferences, project
configuration, captured knowledge, glossaries, architecture decisions, problem
statements, backlog, session state, review notes, scratch — but no single
decision defines the complete class list, which layer owns each class, or where
each class's canonical source lives.

Three open decisions were about to define storage and scoping models
independently: the preferences source (#65), the resume-state artifact (#66),
and the portable knowledge layer (#67). A fourth issue (#69) exists precisely
because one artifact (`.review-notes`) has no decided persistence class. Without
a shared model, each feature re-decides ownership locally and the north star —
carry context in, carry work forward — fragments into inconsistent designs.

What's true today: ADR-0004 placed the engineering-preferences standard inside
the plugin and named `bootstrap` as its applicator, but left the override model
open. The lifecycle (Ideate → Plan → Codify → Validate → Ship) is shipped.
GitHub is already the system of record for the backlog.

## Decision

**Three layers.** Every artifact Spark reads or writes belongs to exactly one:

- **Operator** — travels with the person across all projects (the "standard
  bag"). Canonical home: the Spark plugin, plus an optional operator-level
  override (format decided in ADR-0010 / #65).
- **Project** — belongs to one repo/Cosmic; committed to that repo; the repo is
  its system of record (GitHub for backlog state).
- **Session** — belongs to one working conversation; ephemeral unless
  explicitly promoted.

**One canonical source per class.** The classes, their owning layer, canonical
source, and persistence:

| Class | Layer | Canonical source | Persistence |
|---|---|---|---|
| Engineering preferences | Operator | in-plugin standard (ADR-0004) + operator override (#65) | durable, versioned with the plugin |
| Permission baseline | Operator | shipped baseline artifact (#64) | durable, versioned with the plugin |
| Operator knowledge / vocabulary | Operator | portable knowledge home (#67) | durable, portable |
| Project configuration | Project | repo files written by `bootstrap`/`connect` | durable, committed |
| Architecture decisions | Project | `docs/adr/` | durable, committed, append-only |
| Problem statement | Project | `docs/problem-statement.md` (#68) | durable, committed |
| Backlog / roadmap | Project | GitHub issues, labels, milestones, epics | durable, GitHub |
| Project knowledge / glossary | Project | repo docs curated by `knowledge` | durable, committed |
| Work / resume state | Project | state artifact (#66), written by lifecycle skills | durable, small |
| Review findings | Session | promoted into PR bodies and issues; working notes are scratch (#69) | ephemeral until promoted |
| Scratch | Session | gitignored scratch dirs | ephemeral, disposable |

**Three motions across the layers** (glossary-defined):

- **Carry-in** — Operator → Project: `bootstrap` applies the standard at
  generation (#61), `spark preferences` applies it on demand (#63), the brief's
  `load` step reads it (#62).
- **Carry-through** — within the Project layer: the lifecycle moves work
  between stages. This is the shipped five-stage spine, renamed as a motion,
  unchanged in behavior.
- **Carry-forward** — Session → Project (state survives the session: #66, #68)
  and Project → Operator (knowledge promotion: #67).

**Promotion is explicit.** Session-layer material becomes Project-layer by
commit/PR/issue; Project-layer material becomes Operator-layer only through the
`knowledge` skill's deliberate promotion — never by silent copying.

Why: every carry feature is "move information of class X, owned by layer Y, to
place Z." Deciding the classes and layers once means #65, #66, and #67
instantiate cells of this matrix instead of inventing three scoping models that
must be reconciled after the fact.

## Alternatives Considered

- **Let each feature define its own scoping (status quo).** Rejected: three
  in-flight designs were already diverging; reconciliation cost only grows.
- **Two layers (operator/project), session folded into project.** Rejected:
  the distinction between "durable in the repo" and "dies with the
  conversation" is precisely the carry-forward problem; collapsing it hides
  the class (#69) that caused this ADR.
- **A separate principles document for the model.** Rejected: `philosophy.md`
  is the canon; a second principles doc forks it. The model's principles are
  folded into `philosophy.md` instead.

## Consequences

- #65, #66, #67 implement against this matrix; their ADRs cite this one.
- Every future "does this belong in Spark?" starts with "which layer, which
  class, which motion?" — the conformance audit (#93) applies that test to the
  shipped inventory.
- New vocabulary (carry-in / carry-through / carry-forward, the three layers)
  is canonical in the glossary; docs adopt it instead of near-synonyms.
- Cost: one more indirection when adding an information kind — it must be
  classed and homed before it ships. That is the point.

## Open Questions

- Operator-override format and location — owner: #65 (ADR-0010).
- Portable knowledge home and sync model — owner: #67.
- State-artifact schema — owner: #66.

## Related Docs

- [../adr/0004-cosmic-is-the-generated-unit.md](0004-cosmic-is-the-generated-unit.md) — placed preferences in-plugin
- `plugins/spark/docs/glossary.md` — carry-in / carry-through / carry-forward, the three layers
- `plugins/spark/docs/explanation/philosophy.md` — the principles this model rests on
- `plugins/spark/docs/explanation/identity.md` — the three bags this model formalizes
