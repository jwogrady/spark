# The enforcement model

*Why Spark enforces its rules mechanically instead of writing them down and hoping.*

This is the rationale behind [Principle 1 of the philosophy](philosophy.md) —
"enforcement over aspiration." It explains a design choice, not a procedure; for
the exact hook wiring and exit codes, see the
[hooks reference](../reference/hooks.md) and
ADR 0003.

## The problem with advisory rules

Every team already knows the rules: write conventional commits, don't push to
trunk, don't force-push a shared branch, keep AI ghostwriting out of the
attribution. These live in a `CONTRIBUTING.md` or a wiki page, and they are
*advisory* — they describe what you should do and rely on memory, discipline, and
review to make it happen.

Advisory rules fail in a predictable way: they are easy to state and easy to skip,
and they get skipped exactly when it matters most — late at night, mid-incident,
or when an AI agent is moving faster than the human reviewing it. A rule that is
only written down is a rule that is optional under pressure. The cost of breaking
it is paid later, by someone else, in a messy history or a license violation that
nobody chose on purpose.

AI-assisted development makes this worse, not better. The model will happily
force-push, commit to `main`, or sign a commit "Co-Authored-By: an AI" if asked —
it has no standing intent to uphold your conventions. The faster the loop, the more
a purely advisory rule leaks.

## The choice: make the wrong thing hard

Spark's answer is to move the rules from prose into code that runs at the moment
the rule would be broken, and refuses. The rule is no longer a thing you remember;
it is a thing the system enforces. Two distinct mechanisms cover two distinct
surfaces:

**1. A PreToolUse guard, for AI-mediated git actions.** `hooks/guard-bash.sh` runs
*before* Claude Code executes a Bash command. It inspects the command and exits
non-zero — blocking the action before it happens — for two cases: a force-push
without `--force-with-lease`, and a push to `master`/`main`. The safer
`--force-with-lease` is deliberately allowed. This catches the agent before it
acts, not after.

**2. Git hooks, for every commit regardless of who makes it.** Installed per repo
via `spark install-git-hooks`:
- `commit-msg` rejects a message that isn't a conventional commit, violates the
  subject rules, or carries an AI co-author trailer — before the commit lands in
  history.
- `pre-commit` blocks a direct commit to `master`/`main`.

These run for *any* commit in the repo — human, agent, or script — because they
live in git itself, below the level of whoever invoked the commit.

**3. GitHub itself, for everything the local doors cannot see.** Both doors
above are *local*: a `gh api` call, a clone on another machine, or any client
that never runs the hooks walks straight past them — the zd-dns field test
deleted a published tag through the API on the same afternoon the guard
correctly blocked a push. The backstop is server-side: a GitHub ruleset on the
trunk that requires pull requests and blocks force-pushes and deletion, so the
policy holds no matter which path reaches the remote. Spark ships the policy
as data (`settings/github-ruleset-trunk.json`, solo-operator defaults: PRs
required, zero mandatory approvals) and **inspects, never applies**:
`spark doctor --requirements` reports whether the remote matches the policy
when authenticated GitHub access exists, degrades to "not assessed" when it
doesn't, and applying or changing remote protection is always an explicit
human action.

```
Claude-driven git   → PreToolUse guard
human local git     → git hooks
the remote itself   → GitHub ruleset / branch protection
```

A note on the guard's precision: it deliberately tokenizes the whole command —
including quoted strings and heredoc bodies — because content stripping would
open real bypasses (`git push origin "master"` must stay caught; a heredoc can
be piped into `bash`). The price is a rare false positive when *prose about*
a push appears in a command (a PR body mentioning `git push origin master`).
That trade is by design: a local door may over-block and never under-block,
and the precise expression of the trunk policy lives at this third door, where
GitHub evaluates structure instead of parsing shell.

**4. `spark doctor`, for the artifacts themselves.** Where the hooks gate actions,
`spark doctor` validates state on demand: plugin layout, manifest and hook JSON,
and every skill's and agent's frontmatter. It is the check you can run before you
push to know the plugin is well-formed.

## Form vs. readiness

The hooks above all verify *form* — the shape of a commit, the branch it lands
on, the trailer it carries. Form is necessary but not sufficient: a plan can
satisfy every form check and still be unbuildable, with crisp acceptance criteria
but no stack decided. That is a failure of *readiness*, not form.

Spark verifies readiness with the [Codify-readiness gate](../reference/codify-readiness.md)
— a checklist `plan` produces and `codify` preflights against at the Plan→Codify
boundary. It is enforced by skill behavior (`codify` refuses to start an unready
plan) rather than a git hook, because readiness is about the substance of the
plan, not the syntax of a commit. Form lives in `hooks/`; readiness lives in the
lifecycle skills.

## Why this is the right trade, and where it stops

Mechanical enforcement costs more up front — you write and test a hook instead of a
bullet point — and it buys something prose cannot: the guarantee holds even when
discipline doesn't. "Aspiration lives in READMEs; enforcement lives in `hooks/` and
`scripts/hooks/`."

Two honest boundaries:

- **Enforcement is not the same as quality assurance.** The hooks cover commit
  conventions, trunk discipline, force-push safety, attribution honesty, and
  artifact well-formedness. They do **not** test that a skill behaves correctly.
  CI and automated regression on skill behavior are a standing known gap; the
  mechanical model is the intentional quality mechanism for a Bash/Markdown
  project, not a complete one.
- **The git hooks are opt-in per repo.** The PreToolUse guard works as soon as the
  plugin is installed, but the `commit-msg`/`pre-commit` hooks only protect a repo
  after `spark install-git-hooks` has run there. Enforcement you didn't install is
  back to being advisory.

## See also

- [Philosophy](philosophy.md) — the values layer this rationale supports.
- [Hooks reference](../reference/hooks.md) — exact wiring, exit codes, and behavior.
- ADR 0003 — the
  decision to implement enforcement as zero-dependency Bash hooks.
