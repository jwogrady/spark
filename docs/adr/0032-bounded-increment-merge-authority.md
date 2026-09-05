# ADR: Bounded increments may merge to trunk under durable advance authorization

Date: 2026-09-05
Status: Accepted
Owner: jwogrady

> Moves the **routine trunk-integration approval point** for bounded work units
> beneath a broader owning issue. It supersedes ADR-0019 and ADR-0027 in that
> one respect only, and deliberately leaves the human-owned release act, the
> four-party model, and the delivery topology exactly where they are.

## Alignment

- **Identity / prior decisions served:** ADR-0019 (four parties in fixed roles), ADR-0027 (issue PRs to trunk; dependency-order invariant; one writer per working tree), ADR-0026 (evidence declaration and the release gate), ADR-0006 / ADR-0009 (Release Please; the release mechanism), ADR-0023 (lifecycle orchestration topology), ADR-0030 (governance model representation).
- **Supersedes:**
  - **ADR-0019, in the per-merge approval-point respect only.** The four-party model stands unchanged, and the human continues to own intent, judgment, **acceptance definition and authorization**, and final release approval. What moves is the requirement that a human personally approve *each* routine trunk integration.
  - **ADR-0027, only where it makes the human merge the act that authorizes integration to trunk.** Its canonical `issue → branch → focused commits → PR → master` topology, its dependency-order invariant, its "one writer per working tree" rule, and its treatment of integration branches as an exception all stand unchanged.
  - Neither supersession touches the **release** act. ADR-0026, ADR-0006 and ADR-0009 keep their release semantics in full.
- **Superseded by:** nothing.
- **Status tracks evidence:** Accepted on implementation. Shipped as `xr_merge_check` / `spark merge-authority` in `plugins/spark/lib/execution.sh`; covered by `tests/test-merge-authority.sh`, whose fixtures are each verified to fail against a deliberately regressed implementation.

## Context

The standing autonomous-delivery contract granted routine merge authority only when, on the exact current HEAD, *the owning issue's acceptance is true for the merge being performed* and *the merge makes the owning issue true on `master` rather than merely moving evidence*.

Both conditions are correct and load-bearing. Read literally, they are also unsatisfiable for a large and legitimate class of work.

PR #724 is the concrete case. It was a bounded memoization optimization, authorized by #722, independently reviewed at exact HEAD with a `PASS`, green checks, and a full behavioral suite passing on the candidate HEAD, with no reserved boundary in sight. It still could not merge — because #722 is *"prove the v0.23 performance gate with equal-workload benchmarks,"* and #724 does not prove that. #722 was correctly open and correctly red; the conditions were correctly false.

The result is a structural stall: **every** routine increment beneath a deliberately-incomplete outcome demands a human decision, on work the human already authorized, with nothing left for them to decide. That is ceremony wearing governance's clothes, and it spends the operator's attention where no judgment is required.

The naive fix — relax the conditions, or let any green PR attached to a broad issue merge — trades a stall for a far worse defect. If a child merge can imply parent acceptance, a broad outcome is silently closed by a small increment and the evidence discipline the whole model rests on collapses.

## Decision

**A broad owning issue may durably authorize bounded work units that carry their own acceptance, and Spark may integrate such a unit to trunk without a further per-merge human approval.**

A bounded unit is eligible for routine merge when all of the following are positively affirmed on the exact current HEAD:

1. the broader issue durably authorizes **this** subordinate work unit;
2. the work unit has **its own** explicit acceptance, sufficient for the merge being performed;
3. that bounded acceptance is **true** on the exact current HEAD;
4. independent exact-HEAD review and required checks are **current and green**;
5. the mutation is **routine and reversible** repository work;
6. **stale-head protection** holds;
7. **no reserved human boundary** remains.

Merging the child **advances** the broader outcome. It never closes, satisfies, or implies it. The parent remains open until its own acceptance is independently true.

### What moves, and what does not

This is a genuine movement of the approval point, and it is recorded as one rather than presented as a clarification.

| | Before | After |
| --- | --- | --- |
| Who defines acceptance | the human | **the human, unchanged** |
| Who authorizes a work unit | the human | **the human, unchanged** — but durably and in advance |
| Who approves each trunk integration | the human, per merge | Spark, when it can positively verify the human's advance authorization is satisfied |
| Who performs the release act | the human | **the human, unchanged** |

The human's authority is exercised **earlier and durably** instead of repeatedly and interactively. Spark gains no power to decide *what counts as done*; it gains only the ability to act on a decision the human already made and wrote down.

### Spark verifies acceptance; it never invents it

Spark does not author acceptance, does not infer it, and does not treat the absence of a blocker as permission. Every condition must be affirmed with its exact expected token: absence, emptiness, whitespace, an unrecognised value, an unknown field name, `UNKNOWN` and `NOT ASSESSED` all decline.

The safety default therefore inverts relative to Crossroad classification (#690). `crossroad` fails toward `CONTINUE`, because its defect was a *false stop*. Merge eligibility fails toward `NOT ELIGIBLE`, because its defect would be *manufactured authority* — the failure that silently closes a broad outcome on the strength of one small child.

This is the same proof discipline that #724's own syscall counters arrived at by a different road: a counter that recognised failure by excluding `= -1` reported `= ? ERESTARTNOINTR` as a success, because it inferred success from the absence of one known failure spelling. Authority reasoning has the identical shape and a far higher cost when it is wrong.

### Three things create no authority

- **Reference.** Attaching a PR to a broad issue, or citing it, is not being authorized by it.
- **Evidence movement.** A PR that advances evidence without satisfying its own bounded acceptance has not earned a merge.
- **Coordination.** `#585` stops at governed close-out and says so; relay and orchestrator handoffs sequence work without granting anything; a reviewer `PASS` is evidence, not permission. These are refused by name, because they are the plausible-sounding citations most likely to be offered.

### The release boundary is untouched

A merge to trunk is **integration, not a release**. The release act remains exactly what ADR-0026, ADR-0006 and ADR-0009 make it: the human merging the Release Please release PR, with the milestone declaring the version. No bounded increment reaches that boundary, and a `scope` that is anything other than routine and reversible — a release act, a destructive or irreversible external action, a new authority grant — is refused. A named and cited reserved human boundary routes to `DECISION REQUIRED` however green the evidence is.

## Consequences

- Broad epics and outcome issues can own several mergeable implementation increments without an operator approval for each.
- The merge question becomes **derivable before implementation** from durable facts, rather than discovered after a PR reaches `PASS`. `spark merge-authority` is meant to be consulted at planning time.
- A bounded unit without its own written acceptance cannot merge routinely. This is a real cost and an intended one: it pushes acceptance into the plan, where it belongs, instead of leaving it to be improvised at merge time.
- ADR-0019 and ADR-0027 keep their historical decision text intact; only their status/alignment blocks gain a pointer to this record, per the append-only ADR convention.
- `plugins/spark/skills/ship/SKILL.md` still instructs the agent never to merge without explicit instruction. That predates this decision and does not yet reflect it. Reconciling that shipped instruction would widen an agent's standing latitude, so it is **deliberately left unchanged here** and raised for a separate human decision rather than folded into this record.

## Related Docs

- `plugins/spark/docs/explanation/sdlc-doctrine.md` — "A broad outcome may own many mergeable increments".
- `plugins/spark/docs/reference/cli.md` — `spark merge-authority`.
- ADR-0019, ADR-0027 — superseded in the narrow respects named above.
- ADR-0026, ADR-0006, ADR-0009 — the release act this record leaves fully intact.
