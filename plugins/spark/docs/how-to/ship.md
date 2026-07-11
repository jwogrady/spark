# How to ship a change

> How-to — task-oriented.

Use this to commit a reviewed branch and open a PR. `/spark:ship` owns the whole
Ship stage — commit, push, and PR.

## Commit

1. Invoke `/spark:ship`.
2. Confirm you're on a feature branch (not `master`/`main`).
3. Stage only what belongs in one logical change; review `git diff --staged`.
4. Write the message: conventional type, imperative subject under 72 chars, a
   body that explains *why*. No AI attribution — the `commit-msg` hook rejects it.

## Push + PR

5. It pushes the branch (`git push -u origin <branch>`) and opens a PR into the
   default branch with a body covering what/why, how it was verified, and what to
   review closely. It links the issue (`Closes #N`).
6. It reports the PR URL.

**Releases:** ship's job stops at the open PR. Release Please owns the
version bump, changelog, tag, and GitHub Release from there — see
[explanation/release-ownership.md](../explanation/release-ownership.md).

**Done when** the PR is open and linked to its issue.

**Guardrails:** never force-push (the PreToolUse guard blocks it; use
`--force-with-lease` only with the author's go-ahead), never push to trunk, and
don't merge or comment on the PR without explicit instruction — opening it is
where `ship` ends.
