---
name: codify
description: Implement one planned GitHub issue on a feature branch, scoped tightly to that issue's acceptance criteria. Use when the user wants to start coding an issue, implement a feature, or generate the code for planned work. Not for reviewing/hardening the result (`fix-issue`) or committing and opening the PR (`ship`).
---

# codify — Stage 3 of the Spark lifecycle

`Ideate → Plan → Generate → Solve → Ship`

The `codify` skill implements exactly one issue. Its job is to turn acceptance
criteria into working code on a branch — nothing wider. It owns the **coding**
lane (Generate, stage 3).

## Do this

1. **Read the issue.** The acceptance criteria are the contract. If they're
   missing or vague, go back to [`plan`](../plan/SKILL.md) — don't guess.
2. **Branch.** Never work on `master`/`main`. Create a focused branch:
   ```bash
   git checkout -b feat/<short-slug>      # or fix/, refactor/, docs/
   ```
3. **Match the surrounding code.** Read neighboring files first; mirror their
   naming, structure, and idioms. Write code that reads like it was already
   there.
4. **Implement to the criteria, then stop.** Resist scope creep — anything not
   in the issue is a new issue, not a freebie.
5. **Self-check** against each acceptance criterion before declaring done.

## Guardrails

- One issue per branch, one concern per branch.
- No commented-out code. No debug prints in library code.
- Don't add dependencies the issue doesn't require.
- Don't refactor surrounding code opportunistically — open a separate issue.
- Follow the project's `CLAUDE.md` standards (types, docstrings, formatter,
  linter) — run them before handing off.
- Don't write documentation — that's `docit` (outward) or `knowledge` (internal).
  `codify` writes code.

## Next

Send the change to [`fix-issue`](../fix-issue/SKILL.md) to review and harden,
then to [`ship`](../ship/SKILL.md) to commit and open a PR.
