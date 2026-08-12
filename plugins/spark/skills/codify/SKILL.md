---
name: codify
description: Implement one planned GitHub issue on a feature branch as focused conventional commits, scoped to that issue's acceptance criteria. Use to start coding an issue or a planned feature. Not for reviewing/hardening the result (`validate`) or publishing the branch as a PR (`ship`).
---

# codify — Stage 3 of the Spark lifecycle

`Ideate → Plan → Codify → Validate → Ship`

The `codify` skill implements exactly one issue. Its job is to turn acceptance
criteria into working code on a branch — nothing wider. It owns the **coding**
lane (Codify, stage 3).

## Do this

1. **Preflight: confirm Codify-readiness.** Before touching code, verify the
   implementation approach is recorded (stack/runtime, layout, key deps — the
   ADRs [`plan`](../plan/SKILL.md) produced) and that a scaffold exists (or run
   [`bootstrap`](../bootstrap/SKILL.md)). If the stack is undecided, the plan is
   not [Codify-ready](../../docs/reference/codify-readiness.md) — resolve it in
   `plan`, don't guess a stack mid-implementation.
2. **Read the issue.** The acceptance criteria are the contract. If they're
   missing or vague, go back to [`plan`](../plan/SKILL.md) — don't guess.
3. **Check prerequisites — fail closed.** From the **project root** (the
   script reads the *current* repo's issues and trunk — running it from the
   skill's own directory would assess the wrong repository), run the script by
   its path in this skill: `bash <path-to-this-skill>/scripts/check-prereqs.sh <issue>`.
   It reads the issue's declared dependencies (GitHub blocked-by links and
   `Blocked by #N` body lines) and blocks when a prerequisite is still open
   or the base is behind the remote trunk — the ordering invariant: dependent
   work starts from a state that already contains its prerequisites. Blocked →
   stop and name the missing prerequisite; `not assessed` → verify by hand
   before branching. Never repair drift silently.
4. **Branch from a fresh trunk.** Never work on `master`/`main`. Create a
   focused branch off the current remote trunk:
   ```bash
   git checkout -b feat/<short-slug>      # or fix/, refactor/, docs/
   ```
5. **Match the surrounding code.** Read neighboring files first; mirror their
   naming, structure, and idioms. Write code that reads like it was already
   there.
6. **Implement to the criteria, then stop.** Resist scope creep — anything not
   in the issue is a new issue, not a freebie.
7. **Commit each coherent step.** When one problem → solution step is complete
   and sensibly checked, commit it as a Conventional Commit (the `commit-msg`
   hook enforces the format; body says *why*). Multiple focused commits per
   issue branch are the norm — the branch's history should tell the
   implementation story. Never per-edit WIP/checkpoint noise, and never one
   end-of-issue blob held back for Ship.
8. **Self-check** against each acceptance criterion before declaring done.
9. **Carry the state forward.** Record the close-out with
   `spark state --set next_action="<normally the validate run>"`
   (writes `.spark/state.json`, [schema](../../docs/reference/state.md); `updated` is stamped for you).

## Guardrails

- One issue per branch, one concern per branch.
- Never guess a stack mid-implementation. If the approach isn't recorded as
  ADRs, the plan isn't Codify-ready — stop and resolve it in `plan`.
- No commented-out code. No debug prints in library code.
- Don't add dependencies the issue doesn't require.
- Don't refactor surrounding code opportunistically — open a separate issue.
- Follow the project's `CLAUDE.md` standards (types, docstrings, formatter,
  linter) — run them before handing off. `CONVENTIONS.md` and
  `ENGINEERING-STANDARDS.md` at the repo root hold the project's branching,
  commit, and stack/quality contract — follow them too.
- Don't write documentation — that's `docit` (outward) or `knowledge` (internal).
  `codify` writes code.

## Next

Send the branch — implementation commits included — to
[`validate`](../validate/SKILL.md) to review and harden, then to
[`ship`](../ship/SKILL.md) to push and open the PR.
