# Routine bounded merge at governed close-out

Opening the PR used to be the end of `ship`. For **one narrow case** it is not:
a bounded work unit that the owning issue durably authorized *in advance*, whose
own acceptance is now proven true, may be integrated to trunk without a further
per-merge human approval.

ADR-0032 records that decision and its exact scope. It supersedes ADR-0019 only
in the per-merge approval-point respect, and ADR-0027 only where the human merge
is the act authorizing trunk integration. **Everything else is unchanged.**

## The gate

Never merge on your own reading of the situation, and never tell the gate what
it should conclude. Name the pull request; it reads the rest.

```sh
spark merge-authority --pr <number>
```

| Verdict | Exit | Then |
| --- | --- | --- |
| `ROUTINE MERGE` | `0` | the merge is authorized; proceed |
| `DECISION REQUIRED` | `3` | stop — a reserved human boundary is named and cited |
| `NOT ELIGIBLE` | `4` | stop — eligibility was not established |

**Fail closed.** Anything that is not `ROUTINE MERGE` on exit `0` means do not
merge. A non-zero exit, an unreadable verdict, a missing verb, an older
installed governor that does not carry it — every one of those is a stop, not a
reason to fall back on judgment. A bare invocation exits `4`, not `0`.

You cannot help it along. There is no flag for the review result, the check
state, the head freshness, the acceptance result, the parent relationship or the
scope: those are read from GitHub, and supplying them is an unrecognised
argument. If the answer is `NOT ELIGIBLE`, the fix is to make the missing fact
*true and durable*, never to phrase the call differently.

## What must already exist

**On the owning issue — the grant**, written by someone holding `write`,
`maintain` or `admin` permission in the pull request's repository, saying what
was authorized:

```
spark-authorizes child=#124 acceptance=<canonical-acceptance-id>
```

**On the pull request — the proof**, likewise from someone who can govern the
repository, saying that the authorized acceptance is true *at this exact
commit*:

```
<!-- spark-acceptance pr=<n> child=#124 head=<40-hex> contract=<id> verdict=MET -->
```

Only `MET` affirms. The grant never proves satisfaction and the proof never
defines acceptance. The PR must also **close exactly one issue** — that is how
the bounded work unit is identified — and that issue must have a **native
parent**, which is how the owning issue is identified. Two of either is
ambiguous, and ambiguity declines.

The grant must be its own line, and prose around it is fine — a comment does not
have to end at the marker. Two grant lines, two granting comments, or a
malformed authorization line for the same work unit beside a valid grant are all
ambiguous and decline.

"Green" means the **whole applicable requirement model** passed on that exact
commit: branch protection's app-bound checks, plus every check and workflow an
applicable repository or organization ruleset requires. A same-named check from
a different app is a different check. Every observation counts, so a failing or
still-running re-run behind a success declines, and **both** observation
surfaces — check runs and commit statuses — must be readable. Requirement state
that cannot be read is not absent requirement state — and where nothing is
required anywhere, nothing was proven, so there is still no merge.

The bounded work unit's identity comes from the **pull request's** repository.
The owning issue may live in another one, so where it does, name the work unit
in full (`owner/repo#124`) in the grant and the attestation: a bare `#124`
written on a parent elsewhere is ambiguous and declines. The grant's author must
also hold authority **where the merge happens**: an association is not a
permission, so every grant and every attestation is checked against the
author's `admin`/`maintain`/`write` permission in the pull request's own
repository.

The grant must also be **older than the review** of the commit being merged.
Authorization is given in advance, so a grant posted — or edited — after the
independent review is not advance authorization, and declines. Editing the
grant comment after the review requires a fresh review.

Everything unproven declines: missing, malformed, duplicate, unreadable, stale,
wrong-repository, wrong-child, wrong-acceptance or wrong-HEAD records; a PASS
for a different commit; a check that has not finished; a required check that
never ran or that skipped; conflicting evidence of any kind. Every marker
occurrence is read, so a contradicting record later in the same comment counts
exactly as much as the first. When the HEAD moves, every fact gathered describes
a commit that is no longer the candidate, so the answer becomes `NOT ELIGIBLE`
and the evaluation must be redone.

## What this never does

- It **never closes, satisfies or implies the parent outcome.** The parent stays
  open until its own acceptance is independently true. Do not close it, and do
  not describe the merge as completing it.
- It **never authorizes a release.** A trunk merge is integration. Release PRs,
  tags and GitHub Releases stay human-owned (ADR-0026, ADR-0006, ADR-0009), and
  a release PR is refused outright — identified by what it *is*, not what it is
  called: a `release`/`autorelease` label, or a changelog, release manifest or
  plugin manifest among its changed files, not merely a `release/*` branch.
- It **never covers** CI or enforcement-settings changes, drafts, non-trunk
  bases, destructive or irreversible actions, a genuine Crossroad, or any
  authority not already encoded in the model.

## What cannot create the authority

- **Reference** — citing a broad issue is not being authorized by it.
- **Evidence movement** — advancing evidence without a proof bound to this
  commit has not earned a merge.
- **Coordination** — `#585`, relay/orchestrator handoffs, a reviewer `PASS`, and
  comment consensus are evidence and sequencing, never permission.

Acceptance is the human's to define and authorize. Spark verifies that what they
already accepted is now true; it never invents it, and it never reads the
absence of a blocker as permission.
