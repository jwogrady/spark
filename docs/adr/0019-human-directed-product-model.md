# ADR: The human-directed product model — four parties in fixed roles

Date: 2026-07-21
Status: Accepted
Owner: jwogrady

## Context

Spark's product identity — the human directs, Spark orchestrates, Claude
supplies capability, GitHub is the durable record — is the premise every other
ADR now assumes, but it lived only in the `identity.md` explanation doc, which
frames three parties and folds GitHub in implicitly. The #180 ADR audit tested
all sixteen prior records against this model and found no contradictions in the
decisions themselves; what was missing was a **citable, dated ratification** of
the model that ADRs 0001, 0002, 0008, and 0010 could point to. This ADR is that
record.

## Decision

Spark is a **human-directed software-delivery system with four parties in fixed
roles:**

- **The human is the directing force.** They own intent, judgment, acceptance,
  and the release decision. Nothing ships without their approval.
- **Spark is the orchestration layer.** It owns the sequence (the
  Ideate → Plan → Codify → Validate → Ship lifecycle), the operator's standards,
  and the durable workflow that carries both into every project.
- **Claude supplies the capability.** The tools and the know-how to use them;
  Spark arranges Claude's native tools rather than reinventing them (ADR-0002).
- **GitHub is the system of record.** The review and delivery surface, and the
  durable memory where decisions, issues, branches, pull requests, and releases
  persist across sessions.

Spark's whole value is binding these assets into one disciplined loop under the
human's direction, so standards are stated once and enforced mechanically rather
than re-explained per project.

Why record it now: a foundational model that only lives in an explanation doc
drifts silently and cannot be cited. As a numbered ADR it becomes the fixed
point the audit ratifies against and future decisions defer to — and it makes
GitHub an explicit fourth party rather than an implied backdrop.

## Alternatives Considered

- **Leave it in `identity.md` only.** Rejected: an explanation doc is editable
  prose, not a dated decision; the audit needs a ratification point, and the
  three-party framing understates GitHub's role.
- **Fold it into ADR-0001 or ADR-0008.** Rejected: those record narrower
  decisions (plugin form; information architecture). The product model is the
  premise beneath them and deserves its own record.

## Consequences

- The four-party model is now citable; docs and ADRs asserting roles should
  agree with it, and `identity.md` names GitHub as the explicit fourth party.
- Any future decision that shifts a role (for example, moving the human
  approval point) must supersede this ADR explicitly, not drift past it.
- **Superseded in one narrow respect by ADR-0032** (2026-09-05), which invokes
  the clause above. ADR-0032 moves the *routine trunk-integration* approval
  point: where the owning issue durably authorized a bounded work unit and its
  acceptance in advance, Spark may verify those facts and integrate without a
  further per-merge human approval. The four-party model is unchanged, and the
  human continues to own intent, judgment, **acceptance definition and
  authorization**, and **final release approval** — nothing ships without it.

## Related Docs

- `plugins/spark/docs/explanation/identity.md` — the operator-facing statement of the model
- [0002-additive-to-anthropic-spec.md](0002-additive-to-anthropic-spec.md) — why Spark arranges Claude's native tools rather than reinventing them
- [0008-information-architecture.md](0008-information-architecture.md) — the layers and motions that carry the human's standards
