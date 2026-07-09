# How to ideate a problem

> How-to — task-oriented.

Use this when you have an idea but the scope is still fuzzy.

1. Invoke `/spark:ideate`.
2. State the idea in one sentence. If you can't, let the skill pull you through
   the native `grill-me` skill until you can.
3. Surface prior art — a predecessor repo, prototype, captured data, or
   abandoned branch. For a rewrite this is the most expensive thing to miss.
4. Answer the interview honestly — the goal is to surface the *problem*, not to
   defend a solution.
5. Review the generated problem statement. Check it has: problem, outcome, 2–5
   verifiable success criteria, prior art / reusable assets, constraints, and
   non-goals.
6. Confirm it — the skill saves it to `docs/problem-statement.md`, where
   `/spark:plan` looks for it.

**Done when** you can state the problem and what "solved" looks like on one
screen. If you're still arguing about *how* to build it, you've drifted into
Plan — pull back.
