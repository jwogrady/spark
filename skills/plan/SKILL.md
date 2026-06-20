---
name: plan
description: Turn a framed problem into an implementation approach (stack/architecture recorded as ADRs), a feature breakdown, and a set of GitHub-ready issues plus a milestone. Use after ideate, when the user wants to decide the stack, plan features, break work into issues, or scope a milestone. Not for framing the problem first (`ideate`) or implementing the work (`codify`).
---

# plan — Stage 2 of the Spark lifecycle

`Ideate → Plan → Codify → Validate → Ship`

Plan converts a confirmed problem statement into a small set of features, each
expressed as a GitHub issue that `codify` can pick up. The unit of work is a
feature, not a task list.

## Do this

1. **Read the problem statement.** If there isn't one, run
   [`ideate`](../ideate/SKILL.md) first.
2. **Decide the implementation approach.** Pick up the tech choice `ideate`
   deferred: language/runtime, top-level layout, and key dependencies. Record
   each decision as an ADR under `docs/adr/` (use the `0000-template.md`
   format). A plan with no stack is not a plan `codify` can execute.
3. **Decompose into features.** Each feature is independently shippable and maps
   to one issue. Prefer 3–7 features for a first milestone; if you have more,
   the milestone is too big — cut scope.
4. **Draft each issue** using the repo's templates in
   `.github/ISSUE_TEMPLATE/` (`feature.yml`, `bug.yml`). For each:
   - Title: imperative, specific (`Add NAP export endpoint`, not `NAP stuff`).
   - Body: the user-facing outcome, acceptance criteria, and any constraints
     inherited from the problem statement.
   - Labels that already exist in the repo — do not invent label taxonomies.
5. **Propose a milestone** that groups the issues and names the outcome. Name
   its target version with the [version ladder](../../docs/explanation/sdlc-doctrine.md):
   a first usable-product milestone targets `0.1.0`; the contributions under it
   ship as `0.0.x`.
6. **Confirm before creating anything on GitHub.**

## Creating the issues

- Only call the GitHub API / `gh` after explicit user confirmation (per
  `AGENTS.md`). Default to producing the drafts first; create on approval.
- Use `gh issue create` with the template body, and `gh api` for the milestone
  if the user wants it.
- If the user prefers, output the issues as markdown drafts they create
  themselves.

## Guardrails

- Acceptance criteria must be verifiable — they become the `Validate` stage's
  definition of done.
- The implementation approach must be decided and recorded as ADRs — an issue
  with crisp acceptance criteria but no stack is not
  [Codify-ready](../../docs/reference/codify-readiness.md).
- Do not create issues, milestones, labels, or projects without explicit
  instruction.
- Keep the milestone honest: if a feature can't be described in a paragraph,
  it's not understood well enough to plan.

## Next

Pick an issue and hand it to [`codify`](../codify/SKILL.md).
