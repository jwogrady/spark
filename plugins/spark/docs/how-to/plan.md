# How to plan features into issues

> How-to — task-oriented.

Use this after `ideate`, when you have a confirmed problem statement.

1. Invoke `/spark:plan` — it reads `docs/problem-statement.md` (where `ideate`
   saved the statement) without being told where to look.
2. Review the **implementation approach** — language/runtime, top-level layout,
   and key dependencies — recorded as ADRs under `docs/adr/`. A plan with no
   stack is not one `codify` can start from.
3. Review the proposed feature breakdown. Aim for 3–7 features in a first
   milestone; if there are more, cut scope.
4. Check each drafted issue: imperative title, user-facing outcome, and
   **verifiable acceptance criteria** (these become the Validate stage's definition
   of done).
5. Confirm before anything is created on GitHub.
6. On approval, let the skill create the issues (`gh issue create` using
   `.github/ISSUE_TEMPLATE/`) and, if you want, a milestone.

**Done when** the stack is recorded as ADRs and every issue has acceptance
criteria you could actually test.

**Guardrail:** nothing is created on GitHub without your explicit go-ahead, and
existing labels are reused rather than inventing new ones.
