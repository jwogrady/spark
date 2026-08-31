# Existing implementation before new implementation

Development-only prose. Not shipped with the plugin.

## The failure

v0.23 produced the same failure twice. An issue was known, an open pull request
already implemented it, and nothing surfaced that before a second branch was
cut — #620 duplicated #611 after #619 already existed, and a later #474 motion
independently implemented #474 before discovering draft PR #621.

The pull request was mechanically discoverable the entire time. Nobody was asked
to look. That is a tooling gap, not an attention failure, and it is fixed by
looking automatically rather than by asking people to remember.

## What `spark next` now reports

Before the handoff says "start coding", it says whether someone already did:

```
existing implementation: 1 open PR(s) declare they close #500
  PR #700  Implement the thing
           feat/500-thing
           abc123…
  Inspect before starting: an open PR is evidence, never approval,
  correctness, merge readiness, or a claim on ownership.
```

The exact PR number, branch and HEAD SHA are carried, because "there is a PR"
is not actionable and "PR #700 at `abc123`" is.

## Two strengths of evidence, deliberately kept apart

| | What it means |
|---|---|
| **direct** | The PR *declares* a closing reference — `Closes` / `Fixes` / `Resolves #N`. This is the same mechanism GitHub uses to link a PR to an issue |
| **heuristic** | The issue number merely *appears* — in a branch name, a title, or a body with no closing keyword. Reported, never trusted |

Conflating them would be actively harmful here. The Release Please PR lists
every issue in the milestone in its changelog, so promoting mentions would
report implementation in flight for the whole release — noise that trains an
operator to ignore the signal entirely. The issue-number match also has to end
at a non-digit, or `#50` matches `#500`.

## Evidence, not authority

An open PR is **evidence to inspect, not merge authority**. It does not imply
approval, correctness, merge readiness, or a claim on ownership. It changes the
next action from *start coding* to *inspect and reconcile* — and that is all it
does.

When two PRs both declare they close the issue, both are reported and **neither
is chosen**. Competing implementations are a decision for a person; selecting
one silently would be the tool exercising authority it does not have.

## Absence is a claim, and claims need evidence

"No existing implementation" is only stated after a complete bounded read. If
the API call fails, or the list reaches its scan bound so the answer could lie
past the boundary, the result is **NOT ASSESSED** — never "none found". An
unreadable list that renders as absence is precisely how the original duplicate
work happened.

## It reads, and only reads

Discovery creates no branch, opens no pull request, and issues no mutating API
call. The suite asserts the tree and branch list are unchanged afterwards, and
fails if any write verb appears in what was asked of GitHub.

Discovering a PR in another repository never transfers write authority there;
that boundary is owned separately.
