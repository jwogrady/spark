---
name: ship
description: Push a feature branch and open a focused pull request with a proper body, honoring Spark's git guardrails. Use when the user wants to push, open a PR, or ship a finished change.
---

# ship — Stage 5b of the Spark lifecycle

`Ideate → Plan → Generate → Solve → Ship`

Ship gets a reviewed, committed branch onto GitHub as one focused PR.

## Do this

1. **Pre-flight.** Confirm you're on a feature branch (not `master`/`main`), the
   tree is clean, and the change passed [`fix-issue`](../fix-issue/SKILL.md).
2. **Push** the branch:
   ```bash
   git push -u origin <branch>
   ```
3. **Open the PR** into the default branch. Body should cover:
   - **What** changed and **why** (link the issue: `Closes #12`).
   - How it was verified (tests run, app exercised).
   - Anything reviewers should look at closely.
4. **Report the PR URL** back to the user.

## Guardrails

- **Never force-push** (`--force` / `-f`) to a shared branch. The PreToolUse
  hook blocks it; don't work around it.
- **Never push directly to `master`/`main`.**
- One concern per PR — if the branch grew two concerns, split it.
- Do **not** merge, close, or comment on PRs/issues without explicit
  instruction. Opening the PR is the end of `ship`; the human decides the rest.
- No AI attribution in the PR title or body.

## Next

The loop closes here. Merged work that revealed a new problem starts again at
[`ideate`](../ideate/SKILL.md).
