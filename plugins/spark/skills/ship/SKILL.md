---
name: ship
description: Publish reviewed work — verify the branch's commit series, push it, and open one focused pull request. Use to push, open a PR, or land finished work. Not for writing the code or its commits (`codify`), or running the reviews (`validate`); it assumes an already-reviewed, already-committed branch.
---

# ship — Stage 5 of the Spark lifecycle

`Ideate → Plan → Codify → Validate → Ship`

Ship publishes work that already exists: the implementation commits belong to
[`codify`](../codify/SKILL.md) and the review-fix commits to
[`validate`](../validate/SKILL.md), so by Ship the branch tells its story
already. Ship verifies that series, pushes, and opens one focused PR. The
motion is the same whatever the branch is — an issue branch or a temporary
integration branch (the delivery ADR's exception pattern) publishes
identically.

## Do this

1. **Confirm the branch.** Never commit or push on `master`/`main` — if you're on
   it, branch first. Confirm the change passed [`validate`](../validate/SKILL.md).
2. **Review the commit series.** `git log --oneline <trunk>..HEAD` — each
   commit a coherent Conventional Commit, the series scoped to this one issue.
   Two concerns in the series means the branch should split before it ships.
3. **Sweep the tail.** `git status` — a clean tree ships as-is. A small
   coherent remainder (close-out edits, a final doc touch) becomes one last
   focused commit:
   ```
   <type>: <imperative subject, under 72 chars, no trailing period>

   <body: why this change exists, not a restatement of the diff>
   ```
   A large uncommitted tail means Codify/Validate skipped their commit steps —
   commit it as the focused series it should have been, not one blob.
4. **Push** the branch:
   ```bash
   git push -u origin <branch>
   ```
5. **Open the PR** into the default branch. **Title it to match how PRs land
   here** — plainly for merge commits, conventionally for squash merges; the
   wrong one doubles or drops the entry ([release-please.md](references/release-please.md)). Body should cover:
   - **What** changed and **why** (link the issue: `Closes #12`), plus a durable **`Governed by Spark vX.Y.Z`** line whose version is the branch commits' own `Spark-Governed-By` trailer (the pinned installed governor — `"$(git config --local spark.governorBin)" version`, the SAME repository-local resolver the commit-msg hook uses), so the PR and commit provenance cannot disagree and a squash/rebase merge cannot erase the signal. (A richer, mechanically-projected GitHub provenance check is #711's facility, not this primitive.)
   - How it was verified (tests run, app exercised) — use the evidence classes
     from [`validate`](../validate/SKILL.md) where the distinction matters.
   - Anything reviewers should look at closely.
6. **Report the PR URL** back to the user.
7. **Ask the promotion question once.** Issue completion is a natural
   provenance boundary (ADR-0028): would this work still be true and useful if
   the implementation disappeared and were rebuilt? A "no" needs no ceremony —
   the common case. A "yes" hands the evidence to
   [`knowledge`](../knowledge/SKILL.md), which classifies and promotes; ship
   never classifies or writes to a hub itself. (A milestone/release completing
   is the other natural boundary —
   [references/release-please.md](references/release-please.md).)
8. **Carry the state forward.** Record the close-out with
   `spark state --set blockers="" next_action="<normally merging the PR>"`
   (writes `.spark/state.json`, [schema](../../docs/reference/state.md); `updated` is stamped for you).

## Releases: defer to Release Please

**Ship owns the push and the PR; Release Please owns the release** —
versioning, changelog, tag, and the GitHub Release (ADR-0006, ADR-0009). If the
repo has a `release-please-config.json` (or a `release-please` workflow), never
bump a version, roll the changelog, tag, or create a Release from this skill.
The milestone is the version authority — its boundary is minted with
`Release-As`, never computed from commit types — and merging the release PR
Release Please maintains is the release act, a human decision. The
milestone-completion motion, the first-release guard, and the stale-release-PR
trap: [references/release-please.md](references/release-please.md).

**Fallback — repos without Release Please only,** and only with explicit user
go-ahead (never cut a tag or Release unprompted): derive the bump from the commit
types (a declared milestone's version wins), roll `[Unreleased]` into a dated `vX.Y.Z` section,
bump the version file, tag, and `gh release create`. The full steps and the
changelog-records-product-not-process rule are in
[references/release-fallback.md](references/release-fallback.md).

## Hard rules (the hook will reject violations)

- **No AI attribution anywhere** — no `Co-Authored-By` for AI tools, no mention
  of Claude/Anthropic/Copilot/ChatGPT in the commit message, PR title, or body.
  Credit belongs to the author only; `Governed by Spark vX.Y.Z` is governance
  provenance (the control plane's role), not an AI/worker credit, and belongs in the PR body.
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
