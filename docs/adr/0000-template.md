# ADR: <short decision title>

Date: YYYY-MM-DD
Status: Proposed | Accepted | Superseded by ADR-NNNN
Owner: jwogrady

> Copy this file to `NNNN-slug.md` (zero-padded number, kebab-case slug) for each
> new decision. Keep ADRs append-only: don't rewrite a past decision — supersede
> it with a new one and update this one's Status. Capture facts separate from
> assumptions, and current state separate from intended state.

## Alignment

Trace this decision to the governance layers above it (see
[../product-constitution.md](../product-constitution.md)). Reference, don't restate.

- **Mission / Constitution / Identity served:** which article(s) and owned surface.
- **Supersedes / Superseded by:** ADR numbers, or "nothing".
- **Status tracks evidence:** if this decision's implementation is gated on an
  experiment, name the experiment and state that this ADR's Status must follow its
  verdict (re-status; never implement around a killed experiment). Else "n/a".

## Context

What forced the decision: the problem, the constraints, the relevant prior state.
What's true today, and what was unknown at the time.

## Decision

What was decided, stated plainly. Bullet the moving parts when there are several.
Follow with the *why* — the reasoning that makes this the right call, not a
restatement of the bullets.

## Alternatives Considered

- **<alternative>.** Why it was rejected.
- **<alternative>.** Why it was rejected.

## Consequences

What this commits us to: the costs, the new constraints, the maintenance burden,
and what becomes easier. Both the good and the bad.

## Open Questions

Anything genuinely unresolved. Name it rather than smoothing it over; assign an
owner. Delete this section if there are none.

## Related Docs

- [../architecture/spark-internals.md](../architecture/spark-internals.md) — the architecture map
- Link the explanation/reference docs this decision touches; link, don't restate.
