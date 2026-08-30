# Operations — marking a milestone's release gate

Every milestone that runs the release-readiness convention has one issue that
carries the milestone's scope as sub-issues and closes last. Spark reads that
issue's sub-issue order as the delivery-order authority, and reports the
milestone as certifiable only when that issue is the one thing left.

Since v0.22, **which issue that is is a governed fact and has to be recorded.**
It is not inferred, and there is one operator step that follows.

## The step

When the milestone is planned, assign the **`release-gate`** label to its
release-readiness issue. One per milestone, and only that issue.

```sh
gh issue edit <gate> --add-label release-gate
```

The label is declared in the governance model, so it is provisioned by the
ordinary path rather than created by hand:

```sh
spark governance validate      # +  release-gate    role: missing; would be created
spark governance apply --yes
```

## Why it is not inferred

Before v0.22 the gate was recognised by its shape — the open issue carrying
sub-issues. A milestone may hold ordinary parents, so that rule named whichever
container GitHub happened to return first as the release boundary, and the
delivery order followed it. A milestone whose ordinary parent's children had all
closed was reported as finished and awaiting certification when it declared no
boundary at all.

The model now declares the role and binds the aspect to it:

```
family     role          at-most-one        optional
member     role          release-gate       6f42c1
structure  release-gate  role:release-gate  authoritative
```

`spark governance`, `spark course` and `spark next` all resolve the locator from
that binding, so a project that governs the role under another name is followed
rather than second-guessed. Nothing spells the label a second time.

## What Spark checks, and what it does about it

| State | Result |
| --- | --- |
| no issue carries the role | **known**: this milestone has no release gate |
| one does | that issue is the gate |
| more than one does | fails: a milestone has at most one |
| the marked issue is in no milestone | fails: it gates no release |
| the marked issue is itself a sub-issue | fails: a gate is a container, not a child |
| an open issue in the milestone sits outside the gate's hierarchy | fails: the gate does not carry the milestone's scope |
| the gate is closed while the milestone still holds open work | fails: the gate closes last |
| the evidence could not be read | **not assessed** |

Scope is **ancestry**, not direct parenthood: the gate may carry the milestone
through ordinary parents of its own, and an issue two levels down is inside it.

A failure here is mechanical — no decision resolves it — and it stops both
consumers. `spark next` refuses to select against an order that does not
resolve, and `spark course` derives `REPAIR CURRENT COURSE` rather than a
closure: nothing is certifiable across a boundary that does not hold.

**A milestone with no gate is a valid state**, not a gap. Selection ranks by
priority and says so. Absence is known; only a surface Spark tried to read and
could not is *not assessed*.

## When it matters

- **Planning a milestone** — assign the role with the gate issue, or the
  milestone will correctly report that it declares no release boundary.
- **Certifying a release** — `spark course` names the gate as what remains only
  when the role is recorded and the gate carries every open issue in the
  milestone.
- **Adding work late** — an issue added to the milestone but not placed under
  the gate is reported as outside its hierarchy, because closing the gate would
  declare a release across work the boundary never covered.

## Related docs

- [`plugins/spark/docs/reference/metadata-governance.md`](../../plugins/spark/docs/reference/metadata-governance.md)
  — the release-readiness convention and the full state table.
- [`release-merge-convention.md`](release-merge-convention.md) — how the release
  PR itself is merged.
