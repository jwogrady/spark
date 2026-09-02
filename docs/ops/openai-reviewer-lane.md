# The OpenAI reviewer lane

Development-only prose. Not shipped with the plugin.

The lane is the **single production automatic reviewer** for the autonomous
Spark loop (#584). On every pull-request update it reads the change and posts
**one structured verdict per HEAD** — and it can do nothing else. It is
non-coding by construction: `contents: read`, a checkout with no writable
credential, and no publisher. It reports and stops; it is **not** a merge gate.

## How it is invoked

`.github/workflows/openai-review.yml` fires on `pull_request`
(`opened`, `synchronize`, `reopened`, `ready_for_review`). A `concurrency`
group keyed on the PR cancels an in-flight review when a new commit arrives, so
a review of a superseded HEAD never completes or posts — a stale verdict cannot
drive a later repair.

## The verdict

The first line of the posted comment is one of Spark's four:

| Verdict | Meaning | Routing |
|---|---|---|
| `PASS` | nothing blocking | READY FOR HUMAN MERGE (not merge authority) |
| `CHANGES REQUIRED` | a concrete, fixable defect | hands to the `@claude` coding lane |
| `DECISION REQUIRED` | a project judgment only the human may make | stops for `@jwogrady` |
| `NOT ASSESSED` | the reviewer could not read enough to judge | never a pass |

The comment also carries a hidden machine-readable marker binding the verdict to
the exact PR and HEAD SHA:

```
<!-- spark-openai-review pr=<pr> head=<sha> verdict=<verdict> -->
```

This is the evidence #585 consumes without transcribing prose, and the key the
lane itself uses to guarantee **one verdict per HEAD**: before reviewing, it
checks the PR's comments for a marker on the current HEAD and skips if one
exists. Because the marker binds the exact SHA, a `synchronize` push (a new
HEAD) is always reviewed afresh.

## Fail-closed

Every unreadable path becomes `NOT ASSESSED`, never a pass:

- `OPENAI_API_KEY` absent → `NOT ASSESSED` (the lane is **unarmed** until a human
  adds the secret);
- the reviewer API returns non-200 → `NOT ASSESSED` with the HTTP code;
- empty or unrecognized verdict text → `NOT ASSESSED`.

## What it can never do

- Edit code, push, or merge — the job holds `contents: read` and no deploy key.
- Assign a milestone, priority, or backlog disposition — a `DECISION REQUIRED`
  is handed to the human, and no agent choosing one satisfies it.
- Become a second merge gate — the required checks remain `doctor` and `tests`;
  this verdict is advisory.

## Coexistence with the coding lane (#583)

This is the only automatic PR reviewer. The `@claude` coding lane
(`claude.yml`) wakes only on an explicit human `issue_comment` mention, not on
`pull_request`, so the two never both fire on a PR update — exactly one
production reviewer invocation per HEAD.

## Arming it

The lane lands **unarmed**. Add the `OPENAI_API_KEY` Actions secret to arm it;
until then every run fails closed to `NOT ASSESSED`. No other secret is used —
evidence gathering and comment posting use the ambient `GITHUB_TOKEN`.
