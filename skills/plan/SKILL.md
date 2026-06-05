---
name: plan
description: Turn a framed problem into a feature breakdown and a set of GitHub-ready issues plus a milestone. Use after ideate, when the user wants to plan features, break work into issues, or scope a milestone. Not for framing the problem first (`ideate`) or implementing the work (`codify`).
---

# plan — Stage 2 of the Spark lifecycle

`Ideate → Plan → Generate → Solve → Ship`

Plan converts a confirmed problem statement into a small set of features, each
expressed as a GitHub issue that `codify` can pick up. The unit of work is a
feature, not a task list.

## Do this

1. **Read the problem statement.** If there isn't one, run
   [`ideate`](../ideate/SKILL.md) first.
2. **Decompose into features.** Each feature is independently shippable and maps
   to one issue. Prefer 3–7 features for a first milestone; if you have more,
   the milestone is too big — cut scope.
3. **Draft each issue** using the repo's templates in
   `.github/ISSUE_TEMPLATE/` (`feature.yml`, `bug.yml`). For each:
   - Title: imperative, specific (`Add NAP export endpoint`, not `NAP stuff`).
   - Body: the user-facing outcome, acceptance criteria, and any constraints
     inherited from the problem statement.
   - Labels that already exist in the repo — do not invent label taxonomies.
4. **Propose a milestone** that groups the issues and names the outcome.
5. **Confirm before creating anything on GitHub.**

## Creating the issues

- Only call the GitHub API / `gh` after explicit user confirmation (per
  `AGENTS.md`). Default to producing the drafts first; create on approval.
- Use `gh issue create` with the template body, and `gh api` for the milestone
  if the user wants it.
- If the user prefers, output the issues as markdown drafts they create
  themselves.

## Guardrails

- Acceptance criteria must be verifiable — they become the `Solve` stage's
  definition of done.
- Do not create issues, milestones, labels, or projects without explicit
  instruction.
- Keep the milestone honest: if a feature can't be described in a paragraph,
  it's not understood well enough to plan.

## Next

Pick an issue and hand it to [`codify`](../codify/SKILL.md).
