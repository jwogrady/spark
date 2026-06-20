---
name: ideate
description: Frame a problem before any code is written — turn a vague idea into a sharp, written problem statement with success criteria, constraints, and a survey of prior art / existing assets. Use when starting something new, when the user says "I want to build X", when scope is still fuzzy, or when re-planning a rewrite. Not for breaking the problem into issues (that's `plan`) or writing code (`codify`).
---

# ideate — Stage 1 of the Spark lifecycle

`Ideate → Plan → Codify → Validate → Ship`

Ideate is where a fuzzy idea becomes a problem worth solving, written down. No
code, no file layout, no tickets yet. The output is a short problem statement
the `plan` skill can decompose.

## Do this

1. **Restate the idea in one sentence.** If you can't, the idea isn't ready —
   keep asking until you can.
2. **Survey prior art and existing assets.** Before framing the problem as new,
   check for a predecessor repo, a prototype, captured data, or an abandoned
   branch. Record what exists, what's reusable, and how it relates to this
   effort. For a rewrite, this is the highest-leverage question you can ask.
3. **Pressure-test it.** Invoke the **`grill-me`** skill (Claude-native) to
   interview the user down the decision tree. Resolve the load-bearing unknowns
   before writing anything.
4. **Write the problem statement.** Keep it to one screen:
   - **Problem** — what hurts today, for whom.
   - **Outcome** — what "solved" looks like, in observable terms.
   - **Success criteria** — 2–5 checks you could actually verify.
   - **Prior art & reusable assets** — what already exists, what carries over,
     what's deliberately left behind.
   - **Constraints** — stack, deadline, must-use / must-avoid.
   - **Non-goals** — what this explicitly will not do.
5. **Confirm.** Read it back. Get a yes before handing off to `plan`.

## Output

A markdown problem statement. Offer to save it where the project keeps its
planning docs (e.g. `docs/` or an issue), or to pass it straight to `plan`.

## Guardrails

- Do not jump to a solution, file tree, or tech choice during ideate — that's
  **decided in `plan`** (its "Decide the implementation approach" step records
  the stack as ADRs). Surface the problem, not the implementation.
- Capture *why*, not just *what*.
- One problem per statement. If two problems surface, split them.
- Do not write project-local copies of the Spark methodology. Link Spark's
  doctrine; the repo holds product, not process.
- Do not stamp the problem statement with Spark-internal process framing —
  no `Phase N` / `Prompt NNN` status headers, no `/spark:` stage references,
  no "deferred to later Spark stages." A status line describes the doc's own
  authority and scope ("Authoritative — the problem this project solves"), never
  the lifecycle stage that produced it. The framing leaks the build process into
  a product artifact; strip it.

## Next

Hand the confirmed problem statement to [`plan`](../plan/SKILL.md).
