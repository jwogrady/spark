# Tutorial: build your first feature with Spark

> Tutorial — learning-oriented. Follow every step in order; you'll touch all
> five stages once. We optimize for learning the loop, not for the fastest path.

By the end you'll have taken one idea from a sentence to an open pull request,
using each Spark stage exactly once.

## The mental model, in one minute

Spark is **the layer between your intent and Claude's tools**. You bring the
judgment — what to build, in what order, to what standard. Claude brings the
tools. Spark is the **caddy** in between: it reads the situation, recommends
the club, challenges a questionable choice — and you take the shot. Everything
it does is one of three motions ([glossary](../glossary.md)): **carry-in** —
your standards enter this repo (the hooks you install below); **carry-through**
— the five stages you are about to run; **carry-forward** — what this session
produces (the problem statement, the issue, the PR) outlives it. The canonical
statement is [What Spark is](../explanation/identity.md).

## Before you start

- Spark installed (`/plugin install spark`) and your preferences accepted or
  overridden — see [../how-to/get-started.md](../how-to/get-started.md).
- A git repository you can open a branch and PR in.
- `spark setup` run once in that repo (hooks, permission baseline, resolved
  standard).

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

Type `/spark:codify` and point it at the issue. It checks the issue's
prerequisites, opens a `feat/…` branch off the fresh trunk, writes code to the
criteria, and commits each coherent step as it lands — then stops at the
criteria.

> You learned: one issue, one branch, focused commits, no scope creep.

## 4. Validate

Type `/spark:validate`. It runs `/code-review` (and `/security-review` if
relevant), then `verify` to actually run the thing. Fix what it finds.

> You learned: Spark orchestrates Claude's built-in reviewers rather than
> replacing them.

## 5. Ship

Type `/spark:ship` — it reviews the branch's commit series (sweeping any small
remainder into one last conventional commit — no AI attribution; the hook
enforces it), then pushes and opens the PR linking your issue.

> You learned: the guardrails are mechanical. Try `git push --force` and watch
> the guard stop you.

## You're done

One idea → one open PR, through all five stages. Next time you don't need to use
every stage in order — reach for the one that fits where you are. For focused
tasks, see the [how-to guides](../how-to/).
