# How to implement an issue with codify

> How-to — task-oriented.

Use this to implement one planned issue — the Codify stage.

1. Invoke `/spark:codify` with the issue (number or text) in context.
2. The skill creates a focused branch (`feat/<slug>`, etc.) — never work on
   `master`/`main`.
3. It reads neighboring code first and implements to the acceptance criteria,
   matching the surrounding style.
4. It stops at the criteria. Anything extra becomes a new issue, not a freebie.
5. Run the project's quality gates (formatter, linter, types) before handing off.

**Done when** every acceptance criterion is met in code and the quality gates
pass.

**Guardrail:** one issue per branch; no opportunistic refactors; no new
dependencies the issue didn't call for.
