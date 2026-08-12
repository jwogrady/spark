---
name: ideate
description: Frame a problem in writing before any code — a sharp problem statement with success criteria, constraints, and a prior-art survey. Use when starting something new, when scope is still fuzzy, or when re-planning a rewrite. Not for breaking work into issues (`plan`) or writing code (`codify`).
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
6. **Persist it.** Write the confirmed statement to `docs/problem-statement.md`
   (create `docs/` if needed) and announce where it was saved — don't ask
   whether to save. If the file already exists, show the diff and confirm
   before overwriting. Only write elsewhere if the user names a different home.
7. **Carry the state forward.** Record the close-out with
   `spark state --set next_action="<the plan handoff>"`
   (writes `.spark/state.json`, [schema](../../docs/reference/state.md); `updated` is stamped for you).

## Output

`docs/problem-statement.md` — the canonical path `plan` reads first. The
statement is the seed of the whole lifecycle; persisting it by default is what
lets a future session resume without re-deriving intent from the conversation.

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
