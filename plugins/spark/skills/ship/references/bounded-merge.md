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
  parent-authorizes="#722" \
  authorization-record="#722#issuecomment-456" \
  child="#724" \
  acceptance-id="<canonical acceptance identifier>" \
  review=pass checks=green \
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
reason to fall back on judgment. A bare invocation exits `4`, not `0`; only
`--help` succeeds without a verdict.

## What the parent must have written

The gate is not satisfied by citing the parent. The cited **comment on the
parent issue** is read back from GitHub and must carry exactly one record:

```
spark-authorizes child=#724 acceptance=<canonical-acceptance-id>
```

So the authorization is something the human wrote durably, in advance, naming
the work unit and the acceptance by machine identity. Your job is to cite it,
not to describe it. Prose that mentions the child does not count, two records
are ambiguous, and a comment carrying a reviewer or relay marker is coordination
rather than a grant.

Everything here declines: unreadable or missing records, a comment belonging to
another issue, a record naming a different child, a record binding a different
acceptance, a bare issue reference or bare issue URL, and any hierarchy claim
such as `sub-issue:#724` — that asserts a relationship this gate cannot verify.

Supply each field exactly once; a repeated field is refused, so you cannot
correct a value by appending a better one. Identities are canonical: `#0585` is
refused as an alias of `#585`. Values must be one line of printable text.

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

- **Reference** — citing a broad issue is not being authorized by it.
- **Evidence movement** — advancing evidence without satisfying the bounded
  acceptance has not earned a merge.
- **Coordination** — `#585`, relay/orchestrator handoffs, a reviewer `PASS`, and
  comment consensus are evidence and sequencing, never permission.

Acceptance is the human's to define and authorize. You verify that what they
already accepted is now true; you never invent it, and you never read the
absence of a blocker as permission.
