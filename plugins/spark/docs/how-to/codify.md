# How to implement an issue with codify

> How-to — task-oriented.

Use this to implement one planned issue — the Codify stage.

1. Invoke `/spark:codify` with the issue (number or text) in context.
2. It runs a **preflight**: the implementation approach must be recorded as ADRs
   (from `plan`) and a scaffold must exist (or run `bootstrap`). If the stack is
   undecided, it refuses to start — resolve it in `plan` rather than guessing.
3. The skill creates a focused branch (`feat/<slug>`, etc.) — never work on
   `master`/`main`.
4. It reads neighboring code first and implements to the acceptance criteria,
   matching the surrounding style.
5. It stops at the criteria. Anything extra becomes a new issue, not a freebie.
6. Run the project's quality gates (formatter, linter, types) before handing off.

**Done when** every acceptance criterion is met in code and the quality gates
pass.

**Guardrail:** one issue per branch; no opportunistic refactors; no new
dependencies the issue didn't call for.
