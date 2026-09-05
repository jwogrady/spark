# Routine bounded merge at governed close-out

Opening the PR used to be the end of `ship`. For **one narrow case** it is not:
a bounded work unit that the owning issue durably authorized *in advance*, whose
own acceptance is now true, may be integrated to trunk without a further
per-merge human approval.

ADR-0032 records that decision and its exact scope. It supersedes ADR-0019 only
in the per-merge approval-point respect, and ADR-0027 only where the human merge
is the act authorizing trunk integration. **Everything else is unchanged.**

## The gate

Never merge on your own reading of the situation. Ask the classifier, on the
**exact current HEAD**:

```sh
spark merge-authority \
  parent-authorizes="<durable record authorizing THIS work unit>" \
  child-acceptance="<the unit's OWN acceptance>" \
  acceptance-true=yes review=pass checks=green \
  stale-head=protected scope=routine-reversible
```

| Verdict | Exit | Then |
| --- | --- | --- |
| `ROUTINE MERGE` | `0` | the merge is authorized; proceed |
| `DECISION REQUIRED` | `3` | stop — a reserved human boundary is named and cited |
| `NOT ELIGIBLE` | `4` | stop — eligibility was not established |

**Fail closed.** Anything that is not `ROUTINE MERGE` on exit `0` means do not
merge. A non-zero exit, an unreadable verdict, a missing verb, an older
installed governor that does not carry it — every one of those is a stop, not a
reason to fall back on judgment.

If the HEAD moves after the check, the answer is stale. Re-run it.

## What this never does

- It **never closes, satisfies or implies the parent outcome.** The parent stays
  open until its own acceptance is independently true. Do not close it, and do
  not describe the merge as completing it.
- It **never authorizes a release.** A trunk merge is integration. Release PRs,
  tags and GitHub Releases stay human-owned (ADR-0026, ADR-0006, ADR-0009).
- It **never covers** destructive or irreversible actions, a genuine Crossroad,
  or any authority not already encoded in the model.

## What cannot create the authority

Three plausible-sounding citations grant nothing, and the classifier refuses
them by name:

- **Reference** — attaching a PR to a broad issue, or citing it, is not being
  authorized by it.
- **Evidence movement** — advancing evidence without satisfying the bounded
  acceptance has not earned a merge.
- **Coordination** — `#585`, relay/orchestrator handoffs, a reviewer `PASS`, and
  comment consensus are evidence and sequencing, never permission.

Acceptance is the human's to define and authorize. You verify that what they
already accepted is now true; you never invent it, and you never read the
absence of a blocker as permission.
