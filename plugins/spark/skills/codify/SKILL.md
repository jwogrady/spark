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
3. **Check prerequisites — positive proof, fail closed.** From the **project
   root** (it reads the *current* repo's issues and trunk), run this skill's
   script: `bash <path-to-this-skill>/scripts/check-prereqs.sh <issue>`. It
   demands proof of the ordering invariant on two axes: every declared
   blocker's **merged result is an ancestor of HEAD** (a closed issue alone
   proves nothing), and **HEAD sits exactly at the fresh remote trunk**
   (neither behind nor diverged). `ready` = proven; `blocked` = the invariant
   is positively violated — stop and fix the base; `not assessed` = the proof
   is unavailable — verify by hand before branching. Never repair drift
   silently, and never treat "no problem detected" as ready.
4. **Branch from the fresh trunk — explicitly.** Never work on
   `master`/`main`, and never branch from whatever HEAD happens to be:
   ```bash
   git fetch origin
   git checkout -b feat/<short-slug> origin/<trunk>   # or fix/, refactor/, docs/
   ```
   The explicit start point is what makes the new branch demonstrably
   originate at the accepted base.
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

- One issue per branch, one concern per branch. **A sub-issue is an issue** —
  it gets its own branch and its own PR. A parent issue is a container: it
  has no branch of its own and closes when its children close
  ([sdlc-doctrine](../../docs/explanation/sdlc-doctrine.md)).
- Never guess a stack mid-implementation. If the approach isn't recorded as
  ADRs, the plan isn't Codify-ready — stop and resolve it in `plan`.
- No commented-out code. No debug prints in library code.
- Don't add dependencies the issue doesn't require.
- Don't refactor surrounding code opportunistically — open a separate issue.
- **Surface a falsified assumption immediately, don't wait for ship.** If
  implementation disproves a design assumption or reveals a boundary whose
  meaning would survive this code disappearing, ask the ADR-0028 promotion
  question now — delaying loses the context. Route a "yes" to
  [`knowledge`](../knowledge/SKILL.md); routine implementation needs no
  ceremony and is the common case.
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
