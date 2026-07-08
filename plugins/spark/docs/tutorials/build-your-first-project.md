# Tutorial: build your first feature with Spark

> Tutorial — learning-oriented. Follow every step in order; you'll touch all
> five stages once. We optimize for learning the loop, not for the fastest path.

By the end you'll have taken one idea from a sentence to an open pull request,
using each Spark stage exactly once.

## Before you start

- Spark installed (`/plugin install spark`) — see [../how-to/install.md](../how-to/install.md).
- A git repository you can open a branch and PR in.
- `spark install-git-hooks` run once in that repo.

Confirm: `spark doctor` reports healthy.

## 1. Ideate

Type `/spark:ideate` and say what you want to build, e.g. *"a command that
exports a client's listings as CSV."* Answer the interview. You'll end with a
one-screen problem statement. Save it.

> You learned: the problem comes before the solution. Notice the skill refused to
> talk about *how* to build it.

## 2. Plan

Type `/spark:plan`. It breaks the problem into a few features and drafts a GitHub
issue for each, with acceptance criteria. Approve, and let it create one issue.

> You learned: features map to issues, and acceptance criteria are the contract.

## 3. Codify

Type `/spark:codify` and point it at the issue. It opens a `feat/…` branch and
writes code to the criteria — and stops there.

> You learned: one issue, one branch, no scope creep.

## 4. Validate

Type `/spark:validate`. It runs `/code-review` (and `/security-review` if
relevant), then `verify` to actually run the thing. Fix what it finds.

> You learned: Spark orchestrates Claude's built-in reviewers rather than
> replacing them.

## 5. Ship

Type `/spark:ship` — write a conventional message (no AI attribution; the hook
enforces it), then push and open the PR linking your issue.

> You learned: the guardrails are mechanical. Try `git push --force` and watch
> the guard stop you.

## You're done

One idea → one open PR, through all five stages. Next time you don't need to use
every stage in order — reach for the one that fits where you are. For focused
tasks, see the [how-to guides](../how-to/).
