---
name: ship
description: Land a reviewed change — write a conventional commit (imperative subject under 72 chars, why-not-what body, no AI attribution), push the branch, and open one focused pull request. Use when the user wants to commit, write a commit message, push, or open a PR for finished work.
---

# ship — Stage 5 of the Spark lifecycle

`Ideate → Plan → Generate → Solve → Ship`

Ship turns a reviewed branch into landed work: one logical commit that explains
*why*, then one focused PR. Spark's `commit-msg` git hook enforces the message
rules mechanically; this skill produces a commit and PR that pass the first time.

## Do this

1. **Confirm the branch.** Never commit or push on `master`/`main` — if you're on
   it, branch first. Confirm the change passed [`fix-issue`](../fix-issue/SKILL.md).
2. **Review what's staged.** `git status`, then `git diff --staged`. Stage only
   what belongs in this one logical change.
3. **Commit** with a conventional message:
   ```
   <type>: <imperative subject, under 72 chars, no trailing period>

   <body: why this change exists, not a restatement of the diff>
   ```
   - Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.
   - Subject in imperative mood (`add`, not `added`/`adds`).
   - Body explains the reason; reference issues (`Refs #12`) when relevant.
   - One logical change per commit — if the diff spans two concerns, make two.
4. **Push** the branch:
   ```bash
   git push -u origin <branch>
   ```
5. **Open the PR** into the default branch. Body should cover:
   - **What** changed and **why** (link the issue: `Closes #12`).
   - How it was verified (tests run, app exercised).
   - Anything reviewers should look at closely.
6. **Report the PR URL** back to the user.

## Hard rules (the hook will reject violations)

- **No AI attribution anywhere** — no `Co-Authored-By` for AI tools, no mention
  of Claude/Anthropic/Copilot/ChatGPT in the commit message, PR title, or body.
  Credit belongs to the author only.
- Conventional type prefix required; subject ≤ 72 characters, no trailing period.

## Guardrails

- **Never force-push** (`--force` / `-f`) to a shared branch. The PreToolUse hook
  blocks it; don't work around it. Use `--force-with-lease` only with explicit
  go-ahead.
- **Never push directly to `master`/`main`.**
- One concern per PR — if the branch grew two concerns, split it.
- Do **not** merge, close, or comment on PRs/issues without explicit instruction.
  Opening the PR is the end of `ship`; the human decides the rest.

## Next

The loop closes here. Merged work that revealed a new problem starts again at
[`ideate`](../ideate/SKILL.md).
