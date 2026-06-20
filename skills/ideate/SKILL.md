---
name: ideate
description: Frame a problem before any code is written — turn a vague idea into a sharp, written problem statement with success criteria and constraints. Use when starting something new, when the user says "I want to build X", or when scope is still fuzzy. Not for breaking the problem into issues (that's `plan`) or writing code (`codify`).
---

# ideate — Stage 1 of the Spark lifecycle

`Ideate → Plan → Codify → Validate → Ship`

Ideate is where a fuzzy idea becomes a problem worth solving, written down. No
code, no file layout, no tickets yet. The output is a short problem statement
the `plan` skill can decompose.

## Do this

1. **Restate the idea in one sentence.** If you can't, the idea isn't ready —
   keep asking until you can.
2. **Pressure-test it.** Invoke the **`grill-me`** skill (Claude-native) to
   interview the user down the decision tree. Resolve the load-bearing unknowns
   before writing anything.
3. **Write the problem statement.** Keep it to one screen:
   - **Problem** — what hurts today, for whom.
   - **Outcome** — what "solved" looks like, in observable terms.
   - **Success criteria** — 2–5 checks you could actually verify.
   - **Constraints** — stack, deadline, must-use / must-avoid.
   - **Non-goals** — what this explicitly will not do.
4. **Confirm.** Read it back. Get a yes before handing off to `plan`.

## Output

A markdown problem statement. Offer to save it where the project keeps its
planning docs (e.g. `docs/` or an issue), or to pass it straight to `plan`.

## Guardrails

- Do not jump to a solution, file tree, or tech choice during ideate — that's
  `plan`'s job. Surface the problem, not the implementation.
- Capture *why*, not just *what*.
- One problem per statement. If two problems surface, split them.

## Next

Hand the confirmed problem statement to [`plan`](../plan/SKILL.md).
