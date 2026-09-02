# The OpenAI reviewer lane

Development-only prose. Not shipped with the plugin.

The lane is the **single production automatic reviewer** for the autonomous
Spark loop (#584). It posts one structured verdict per exact PR HEAD and can do
nothing else. It is advisory: `PASS` means ready for the next governed boundary,
not merge authority.

## Trusted execution boundary

`.github/workflows/openai-review.yml` uses `pull_request_target` for
`opened`, `synchronize`, `reopened`, and `ready_for_review`.

That choice is deliberate: the privileged runner executes only the trusted
base-branch workflow and helper code. The PR HEAD, diff, title/body, owning issue
text, comments, checks, and other PR-controlled material are treated strictly as
**untrusted data**. The reviewer never checks out or executes PR-controlled code
while `GITHUB_TOKEN` or `OPENAI_API_KEY` is available.

The OpenAI request keeps binding review policy in the Responses API
`instructions` field. Untrusted evidence is supplied separately as `input` and
is explicitly labeled data, so instructions embedded in a PR cannot redefine
the reviewer's role or manufacture a `PASS`.

## One invocation per exact HEAD

Runs are serialized per PR with `cancel-in-progress: false`. Before any model
call, the lane:

1. re-reads the live PR HEAD and stops if the queued event is stale;
2. paginates all PR comments;
3. accepts prior claim markers only when both the comment author is
   `github-actions[bot]` and the producing GitHub App is `github-actions`;
4. requires the marker to bind the exact expected PR number and HEAD SHA;
5. posts a durable reservation comment for that exact PR + HEAD **before** the
   model invocation.

The reservation is the at-most-once control. A duplicate event for the same
HEAD finds the trusted reservation and does not invoke the model again. A new
HEAD is a different work unit and is reviewed separately.

Immediately before the model call, the lane re-checks the live HEAD again. If it
moved after reservation, the run finalizes that reservation as `NOT ASSESSED`
without a model call; stale evidence cannot drive repair.

## Final verdict evidence

The reservation comment is updated in place to the final human-facing verdict
and the machine-readable marker consumed by #585:

```
<!-- spark-openai-review pr=<pr> head=<sha> verdict=<verdict> -->
```

Verdicts are exactly:

| Verdict | Meaning |
|---|---|
| `PASS` | nothing blocking for this exact HEAD; not merge authority |
| `CHANGES REQUIRED` | concrete implementation defect(s) remain |
| `DECISION REQUIRED` | a human-owned project/governance choice is owed |
| `NOT ASSESSED` | evidence or reviewer execution was insufficient; never PASS |

A failure to publish/finalize the verdict is a workflow failure. It is never
swallowed or reported as successful publication.

## Fail closed

- missing `OPENAI_API_KEY` -> `NOT ASSESSED`;
- non-200 reviewer API response -> `NOT ASSESSED`;
- empty or unrecognized verdict text -> `NOT ASSESSED`;
- superseded HEAD before invocation -> `NOT ASSESSED` with no model call;
- malformed/spoofed marker identity -> ignored, never treated as a prior review.

## What it can never do

- edit PR code, push, or merge;
- assign roadmap metadata or satisfy a human decision;
- execute PR-controlled code beside privileged credentials;
- treat PR prose/comments as instructions;
- wake the writer merely by printing `@claude` in reviewer prose.

#585 owns the native reviewer-to-Claude machine handoff. Until #585 is live, any
external relay must independently verify the trusted exact-HEAD verdict and its
own authority before waking a writer.

## Coexistence with #583

The Claude coding lane remains a separate split-authority writer path. Its
deterministic publisher rejects `.github/workflows/**`, its own helper tree, and
`.github/scripts/openai-review/**`. Claude therefore cannot rewrite the reviewer
that judges Claude.

## Arming

`OPENAI_API_KEY` is the only reviewer secret. The job uses the scoped ambient
GitHub token for evidence reads and verdict-comment publication. No deploy key or
repository-content write credential exists in the reviewer lane.
