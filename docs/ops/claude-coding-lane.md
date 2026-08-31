# The Claude coding lane

Development-only prose. Not shipped with the plugin.

## How it is invoked

A **trusted human** mentions `@claude` — in an issue comment, a PR review
comment, a PR review body, or a new issue. Nothing else wakes it.

Both conditions are required. A trusted human who did not ask for Claude does
not get it, and a mention from an untrusted account never reaches the job.

## What it may write

Commits pushed to **the pull request's own feature branch**, plus comments on
the pull request or issue. That is the whole surface.

## What it can never do

It can never merge, never change the workflows that govern it, and never touch
rulesets, secrets or repository administration.

| | Why it is structural |
|---|---|
| **Never merge** | No permission grants it. Merging is the owner's act |
| **Never change workflows** | `workflows: write` is not granted, so GitHub itself rejects a push touching `.github/workflows/**`. A lane that could edit its own guardrails would have none |
| **Never change rulesets, secrets or administration** | `administration` and `secrets` are not granted |
| **Never review automatically** | It wakes on a mention, never on every pull request. Automatic independent review belongs to #584 — two automatic reviewers would duplicate cost, context and findings without a governed reason |

These are absences of capability, not promises of good behaviour. The
distinction matters: a promise is only as good as the prompt, and prompts can be
argued with.

## The association gate is the security boundary

`issue_comment` fires for anyone who can type a comment, and this job holds
`contents: write`. Without a gate, any account able to comment could reach a
write-capable path — the classic escalation shape.

So the job runs only for `OWNER`, `MEMBER` or `COLLABORATOR`, and that check
lives in the job's `if:` condition, where GitHub evaluates it **before any step
runs and before credentials exist in the runner**. A step-level check would run
after the runner already held a token.

Fork pull requests are refused as the first step, before checkout. Untrusted
head code must never execute where a write token is available.

## What is deliberately not here

There is **no `workflow_run` trigger**. Waking this lane from a reviewer's
verdict is the reviewer → writer handoff, and #585 owns it. Landing it here
would enable an automation path this issue is not authorised to turn on.

## Arming it

The workflow requires the `CLAUDE_CODE_OAUTH_TOKEN` secret. Until the repository
owner adds it, the surface exists and the job cannot run. That ordering is
deliberate: the boundary lands and is reviewed first, and arming it is a separate
human act.
