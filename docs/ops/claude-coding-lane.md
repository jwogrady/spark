# The Claude coding lane

Development-only prose. Not shipped with the plugin.

The lane lets a trusted human ask Claude, by an `@claude` mention, to propose a
code change on a pull request — and it publishes that change to the PR's own
feature branch **without ever giving Claude a credential that can push or
merge.** It is built as three jobs with separated authority so that "cannot
merge" is a mechanical fact, not a promise in a prompt.

## How it is invoked

A **trusted human** — `OWNER`, `MEMBER`, or `COLLABORATOR` — writes a comment
containing `@claude` on an issue or a pull request. Both conditions are
required, and both are checked on the **actual commenter** (not the issue or PR
author) in the resolver job's `if:`, which GitHub evaluates before any runner
starts. A comment from anyone else, or a comment without the mention, reaches
nothing.

## The three jobs

1. **resolve** — read-only. Admits only the trusted commenter, then derives the
   immutable identity of the work: repository, PR number, head repository, head
   ref, and the exact head SHA, fetched from GitHub rather than guessed from the
   comment payload. A fork head, a missing identity, or a head that is the
   default branch refuses publication here.
2. **claude** — reasons and proposes. It holds **no `contents: write` and no
   deploy key**, so it physically cannot push and cannot merge. It reads the
   exact resolved head, edits its checkout, and emits the change as a patch — a
   data artifact, nothing more.
3. **publish** — the only writer. It validates the patch against the resolved
   identity and a forbidden-path/mode gate, then fast-forwards the exact feature
   branch using a Git-only SSH **deploy key**.

## What Claude can do

- Wake on a trusted `@claude` mention.
- Read the repository and the pull request.
- Reason about the request and propose the smallest correct change.
- Converse and report on the issue or pull request.
- Cause a validated change to reach the PR's feature branch **through the
  isolated publisher, once the lane is armed.**

## What Claude can never do

These are absences of capability, not promises of good behaviour.

| | Why it is mechanical |
|---|---|
| **Hold the deploy key** | The key is referenced only in the publisher job; Claude's job never receives it. |
| **Push directly** | Claude's job has `contents: read` and checks out with `persist-credentials: false` — there is no write credential in the runner. |
| **Mint a second write token** | `anthropics/claude-code-action@v1`, given no `github_token`, requests an OIDC token and exchanges it with Anthropic for a GitHub App token that defaults to `contents`/`pull_requests` **write**. The workflow forecloses this: it passes the restricted `${{ github.token }}` explicitly, so the action uses that read-only token, and the job drops `id-token: write` so the OIDC exchange cannot run at all. Anthropic auth still uses `CLAUDE_CODE_OAUTH_TOKEN`, not workload identity. |
| **Cannot merge** | The only write credential in the whole lane is an SSH deploy key. A deploy key authenticates Git transport only; it cannot authenticate to GitHub's REST or GraphQL API, and the merge endpoints live only there. No job holds a token that can merge. |
| **Publish to `master`** | The publisher pushes only the resolved feature ref, and the `spark-trunk` ruleset independently protects the default branch. The default branch can never be the publication target. |
| **Change workflow or guardrail files** | The publisher rejects any patch that touches `.github/workflows/**` or the lane's own `.github/scripts/claude-lane/**` helpers, by the resulting Git tree's paths and modes — before it pushes. |
| **Change rulesets, secrets, or administration** | No job holds `administration` or secrets access, and the deploy key has no API surface to reach them. |

The publisher also refuses a **stale head**: if the branch moved while Claude
was working, it refuses rather than silently rebasing onto new work.

## Ordinary issue

A trusted `@claude` mention on a normal issue (one with no pull request) wakes
Claude for **conversation only**. There is no feature branch, none is invented,
the publisher job is not authorized, and no code is pushed.

## Arming it

The lane lands **unarmed**: the boundary exists, and nothing publishes until a
human completes these steps after review and merge.

1. Create a **repository-scoped SSH deploy key** for `jwogrady/spark` with
   **write access enabled**.
2. Store **only the private key** in the Actions secret
   `CLAUDE_PUBLISH_DEPLOY_KEY`. Put it nowhere else — never in Claude's job or
   environment.
3. Add the `CLAUDE_CODE_OAUTH_TOKEN` secret the Claude job needs to run.
4. **Do not** substitute a bearer token with `Contents: write` for the deploy
   key. A bearer token would restore the merge capability the deploy key exists
   to withhold.

Until the deploy key is present, the publisher cannot authenticate and nothing
is published. Until `CLAUDE_CODE_OAUTH_TOKEN` is present, Claude does not run at
all. The lane is not live before both arming steps succeed, and a live end-to-end
test (a real `@claude` comment on a test PR) should follow arming.
