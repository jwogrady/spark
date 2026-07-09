---
name: ship
description: Land a reviewed change — write a conventional commit (imperative subject under 72 chars, why-not-what body, no AI attribution), push the branch, and open one focused pull request. Use when the user wants to commit, write a commit message, push, or open a PR for finished work. Not for writing the code (`codify`) or running the reviews (`validate`) — it assumes an already-reviewed change.
---

# ship — Stage 5 of the Spark lifecycle

`Ideate → Plan → Codify → Validate → Ship`

Ship turns a reviewed branch into landed work: one logical commit that explains
*why*, then one focused PR. Spark's `commit-msg` git hook enforces the message
rules mechanically; this skill produces a commit and PR that pass the first time.

## Do this

1. **Confirm the branch.** Never commit or push on `master`/`main` — if you're on
   it, branch first. Confirm the change passed [`validate`](../validate/SKILL.md).
2. **Review what's staged.** `git status`, then `git diff --staged`. Stage only
   what belongs in this one logical change.
3. **Commit** with a conventional message:
   ```
   <type>: <imperative subject, under 72 chars, no trailing period>

   <body: why this change exists, not a restatement of the diff>
   ```
   - Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.
   - Subject in imperative mood (`add`, not `added`/`adds`).
   - Body explains the reason; reference issues (`Refs #12`) when relevant.
   - One logical change per commit — if the diff spans two concerns, make two.
4. **Push** the branch:
   ```bash
   git push -u origin <branch>
   ```
5. **Open the PR** into the default branch. Body should cover:
   - **What** changed and **why** (link the issue: `Closes #12`).
   - How it was verified (tests run, app exercised).
   - Anything reviewers should look at closely.
6. **Report the PR URL** back to the user.
7. **Carry the state forward.** Update `.spark/state.json`
   ([schema](../../docs/reference/state.md)): `stage` `ship`, `pr` the number
   (digits only), `blockers` `""`, `next_action` (normally merging the PR),
   `updated`.

## Releases: defer to Release Please

**Ship owns the commit and the PR; Release Please owns the release** —
versioning, changelog, tag, and the GitHub Release (ADR-0006, ADR-0009). If the
repo has a `release-please-config.json` (or a `release-please` workflow), never
bump a version, roll the changelog, tag, or create a Release from this skill:
your conventional commit types are the release input, and merging the
release-PR that Release Please maintains is the release act — a human decision.

**Fallback — repos without Release Please only,** and only with explicit user
go-ahead (never cut a tag or Release unprompted): derive the bump from the
commit types in the range per the version ladder in
[`docs/explanation/sdlc-doctrine.md`](../../docs/explanation/sdlc-doctrine.md)
(`feat:` → minor; `fix:`/`docs:`/`chore:`/`refactor:`/`test:` → patch; `!` or
`BREAKING CHANGE:` → major; take the highest), then in order: roll
`[Unreleased]` into a dated `vX.Y.Z` section, bump the version file, annotated
tag, `gh release create` with the CHANGELOG section as notes, fresh
`[Unreleased]`.

Non-version-bumping ships still update `[Unreleased]` when behavior changed.

**A changelog records what changed in the product, not how it was built.** Every
`[Unreleased]` entry describes a user-facing change — a feature, fix, or
behavior. It is not a process journal: never log phase transitions ("Completed
Phase 1 — Plan"), grill reviews, QC passes, planning bookkeeping, or `/spark:`
stage activity. If an entry only makes sense to someone running the Spark
lifecycle, it does not belong in the changelog.

## Hard rules (the hook will reject violations)

- **No AI attribution anywhere** — no `Co-Authored-By` for AI tools, no mention
  of Claude/Anthropic/Copilot/ChatGPT in the commit message, PR title, or body.
  Credit belongs to the author only.
- Conventional type prefix required; subject ≤ 72 characters, no trailing period.

## Guardrails

- **Never force-push** (`--force` / `-f`) to a shared branch. The PreToolUse hook
  blocks it; don't work around it. Use `--force-with-lease` only with explicit
  go-ahead.
- **Never push directly to `master`/`main`.**
- One concern per PR — if the branch grew two concerns, split it.
- **Never cut a tag or GitHub Release without explicit user go-ahead.**
- Do **not** merge, close, or comment on PRs/issues without explicit instruction.
  Opening the PR is the end of `ship`; the human decides the rest.

## Next

The loop closes here. Merged work that revealed a new problem starts again at
[`ideate`](../ideate/SKILL.md).
