# ADR: A broad outcome may own bounded increments that merge on their own acceptance

Date: 2026-09-05
Status: Accepted
Owner: jwogrady

## Alignment

- **Identity / prior decisions served:** ADR-0019 (human-directed product model — the human owns intent, judgment, acceptance and the release decision), ADR-0027 (delivery model — issue → branch → focused commits → PR → trunk; the human merge is the integration and release act), ADR-0026 (evidence declaration and the release gate), ADR-0023 (lifecycle orchestration topology).
- **Supersedes / Superseded by:** nothing. It **refines** ADR-0019's acceptance role rather than shifting it, and ADR-0019 requires that distinction be made explicitly rather than drifted past — this record is that explicit statement. The release act and the human approval point are unchanged.
- **Status tracks evidence:** Accepted on implementation. Shipped as `xr_merge_check` / `spark merge-authority` in `plugins/spark/lib/execution.sh`; covered by `tests/test-merge-authority.sh`, whose fixtures are each verified to fail against a deliberately regressed implementation.

## Context

The standing autonomous-delivery contract granted routine merge authority only when, on the exact current HEAD, *the owning issue's acceptance is true for the merge being performed* and *the merge makes the owning issue true on `master` rather than merely moving evidence*.

Those two conditions are correct and load-bearing. They are also, read literally, unsatisfiable for a large class of legitimate work.

PR #724 is the concrete case. It was a bounded memoization optimization, authorized by #722, independently reviewed at exact HEAD with a `PASS`, green checks, a full behavioral suite passing on the candidate HEAD, and no reserved boundary in sight. It still could not merge — because #722 is *"prove the v0.23 performance gate with equal-workload benchmarks,"* and #724 does not prove that. #722 was correctly open and correctly red. The conditions were correctly false.

The result is a structural stall: **every** routine increment beneath a deliberately-incomplete outcome requires a human decision, on work the human already authorized, with nothing for them to decide. That is ceremony wearing governance's clothes, and it degrades the operator's attention for the decisions that genuinely need it.

The naive fix — relax the conditions, or let a green PR attached to a broad issue merge — trades a stall for a much worse defect. If a child merge can imply parent acceptance, a broad outcome gets silently closed by a small increment, and the evidence discipline the whole model rests on collapses.

## Decision

**A broad owning issue may durably authorize bounded work units that carry their own acceptance.** A bounded unit is eligible for routine merge when all of the following are affirmed on the exact current HEAD:

1. the broader issue durably authorizes **this** subordinate work unit;
2. the work unit has **its own** explicit acceptance, sufficient for the merge being performed;
3. that bounded acceptance is **true** on the exact current HEAD;
4. independent exact-HEAD review and required checks are **current and green**;
5. the mutation is **routine and reversible** repository work;
6. **stale-head protection** holds;
7. **no reserved human boundary** remains.

Merging the child **advances** the broader outcome. It never closes, satisfies, or implies it. The parent remains open until its own acceptance is independently true.

### Eligibility is affirmed positively, never inferred

The safety default inverts relative to Crossroad classification (ADR-0023, #690), and the inversion is the substance of this decision rather than an implementation detail.

`crossroad` fails toward `CONTINUE`, because its defect was a *false stop* — an agent inventing a human boundary that no durable surface reserved. Merge eligibility fails toward `NOT ELIGIBLE`, because its defect is *manufactured authority* — the failure that silently closes a broad outcome on the strength of one small child.

So every condition must be affirmed with its exact expected token. Absence, emptiness, whitespace, an unrecognised value, an unknown field name, `UNKNOWN` and `NOT ASSESSED` all decline. **The absence of a known disqualifier is not proof of permission.**

This is the same proof discipline that #724's own syscall counters arrived at by a different road: a counter that recognised failure by excluding `= -1` reported `= ? ERESTARTNOINTR` as a success, because it inferred success from the absence of one known failure spelling. Authority reasoning has the identical shape and a far higher cost when it is wrong.

### Three things create no authority

- **Reference.** Attaching a PR to a broad issue, or citing it, is not being authorized by it.
- **Evidence movement.** A PR that advances evidence without satisfying its own bounded acceptance has not earned a merge.
- **Coordination.** `#585` stops at governed close-out and says so; relay and orchestrator handoffs sequence work without granting anything; a reviewer `PASS` is evidence, not permission. These are refused by name, because they are the plausible-sounding citations most likely to be offered.

## This does not move the human approval point

ADR-0019 fixes the human as the directing force, owning intent, judgment, **acceptance**, and the release decision, and requires that any decision shifting a role supersede it explicitly. This ADR does not shift that role, and the distinction is worth stating precisely:

- **The human still authors acceptance.** Both the parent's and the bounded unit's acceptance are written by the human, durably, *in advance*. The agent authors neither.
- **The agent only verifies.** It checks whether what the human already accepted is now true on an exact HEAD, and declines whenever it cannot prove that.
- **The release decision is untouched.** A merge to the trunk is not a release. The release act remains the human merging the Release Please PR (ADR-0027, ADR-0026), and no bounded increment reaches it.
- **Reserved boundaries are untouched.** A named and cited human boundary routes to `DECISION REQUIRED` however green the evidence is.

What changes is narrower than it first appears: *which* acceptance a routine merge is measured against. Previously only the owning issue's. Now, additionally, a bounded unit's own — when the owning issue durably authorized that unit.

## Consequences

- Broad epics and outcome issues can own several mergeable implementation increments without an operator approval for each.
- The merge question becomes **derivable before implementation** from durable facts, rather than discovered after a PR reaches `PASS`. `spark merge-authority` is meant to be consulted at planning time.
- A bounded unit without its own written acceptance cannot merge routinely. This is a real cost and an intended one: it pushes acceptance into the plan, where it belongs, instead of leaving it to be improvised at merge time.
- `plugins/spark/skills/ship/SKILL.md` still instructs the agent never to merge without explicit instruction, which predates this model and does not yet reflect it. Reconciling that shipped instruction would widen an agent's standing latitude, so it is **deliberately left unchanged here** and raised for a separate human decision rather than folded into this record.

## Related Docs

- `plugins/spark/docs/explanation/sdlc-doctrine.md` — "A broad outcome may own many mergeable increments".
- `plugins/spark/docs/reference/cli.md` — `spark merge-authority`.
- ADR-0019, ADR-0026, ADR-0027 — the human-owned roles and the release act this record leaves intact.
