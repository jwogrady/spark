# How to ship a change

> How-to — task-oriented.

Use this to publish a reviewed branch as a PR. `/spark:ship` owns the Ship
stage — verify the commit series, push, and PR. The implementation commits were
made during `codify` and the review-fix commits during `validate`; ship
publishes what already exists.

## Verify the series

1. Invoke `/spark:ship`.
2. Confirm you're on a feature branch (not `master`/`main`) and the change
   passed `validate`.
3. Review `git log <trunk>..HEAD`: focused Conventional Commits, one issue's
   story. A small coherent remainder in the tree becomes one last focused
   commit (imperative subject under 72 chars, body says *why*, no AI
   attribution — the `commit-msg` hook rejects violations).

## Push + PR

4. It pushes the branch (`git push -u origin <branch>`) and opens a PR into the
   default branch with a body covering what/why, how it was verified, and what to
   review closely. It links the issue (`Closes #N`).
5. It reports the PR URL.

**Releases:** ship's job stops at the open PR. Release Please owns the
version bump, changelog, tag, and GitHub Release from there — see
[explanation/release-ownership.md](../explanation/release-ownership.md). Before
a release PR is approved, run the
[release-docs checklist](../reference/release-docs-checklist.md) so the public
record stays coherent.

**Done when** the PR is open and linked to its issue.

**Guardrails:** never force-push (the PreToolUse guard blocks it; use
`--force-with-lease` only with the author's go-ahead), never push to trunk, and
don't merge or comment on the PR without explicit instruction — opening it is
where `ship` ends.
