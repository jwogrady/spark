# How to implement an issue with codify

> How-to — task-oriented.

Use this to implement one planned issue — the Codify stage.

1. Invoke `/spark:codify` with the issue (number or text) in context.
2. It runs a **preflight**: the implementation approach must be recorded as ADRs
   (from `plan`) and a scaffold must exist (or run `bootstrap`). If the stack is
   undecided, it refuses to start — resolve it in `plan` rather than guessing.
   It also demands positive proof of the issue's declared prerequisites
   (`check-prereqs.sh`): each blocker's merged result must be an ancestor of
   HEAD and HEAD must sit exactly at the fresh trunk — violations block, and
   unavailable proof reports not-assessed instead of guessing.
3. The skill creates a focused branch with an explicit start point
   (`git checkout -b feat/<slug> origin/<trunk>`) — never from an arbitrary
   HEAD, never on `master`/`main`.
4. It reads neighboring code first and implements to the acceptance criteria,
   matching the surrounding style.
5. It commits each coherent problem → solution step as a focused Conventional
   Commit — the branch history tells the implementation story.
6. It stops at the criteria. Anything extra becomes a new issue, not a freebie.
7. Run the project's quality gates (formatter, linter, types) before handing off.

**Done when** every acceptance criterion is met in committed code and the
quality gates pass.

**Guardrail:** one issue per branch; no opportunistic refactors; no new
dependencies the issue didn't call for.
