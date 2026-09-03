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
it is a thing the system enforces. Three doors cover the three paths a git
operation can take, and a fourth check validates the artifacts themselves:

**1. A PreToolUse guard, for AI-mediated git actions.** `hooks/guard-bash.sh` runs
*before* Claude Code executes a Bash command. It inspects the command and exits
non-zero — blocking the action before it happens — for a force-push without
`--force-with-lease`, a push to `master`/`main`, and (where Release Please is
configured) hand-cut tags and Releases. The safer
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
trunk that requires pull requests, gates merges on the repo's required CI
checks, and blocks force-pushes and deletion, so the policy holds no matter
which path reaches the remote. Spark ships the policy
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

## Documentation as a gate, not a checkbox

Spark's release gates were `doctor`, `tests`, and `milestone-gate`. Documentation
was not among them — it was a checklist a human ticked. So a release could go
green while the docs described a version that no longer existed. Nothing lied;
nothing checked.

`docs-truth` closes that. It is a **binding** release-readiness check of the same
kind as the others: `milestone-gate` reads its result alongside `doctor` and
`tests`, and reports not-ready while it fails. It answers one question — *does
the repository describe the state that will exist after this release?* — never
"what happened, in what order", which GitHub already holds.

It works in three layers, and each is enforced where it can actually be proven:

- **Structural** truth composes `doctor`, which already owns every list-vs-list
  parity check. Nothing is reimplemented.
- **Interface** truth requires every shipped CLI verb to carry exactly one
  machine-readable compatibility classification. An unclassified verb *fails*;
  it is never defaulted to Stable to go green, because a gate that promotes a
  surface to make itself pass is manufacturing a promise nobody made.
- **Semantic** truth cannot honestly be reduced to a script, so it is *narrowed*
  instead: the check derives a bounded per-issue claim list from declared
  documentation impact — "these behaviours changed, verify these documents" —
  rather than instructing anyone to review the docs.

Two properties keep it honest. **NOT ASSESSED is never green**, and the report
names which layer could not be assessed; a gate that cannot tell "passed" from
"could not look" is not a gate. And the semantic verdict lives in **GitHub
evidence on the release PR, never in the tree** — committing it would write
change-over-time evidence into a current-state surface, the exact thing the
ownership contract forbids. A gate that forced its own violation would be worse
than no gate. A verdict is bound to an exact HEAD SHA, so when the release PR
moves, the previous verdict is stale by arithmetic rather than by judgement.

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

## Author, worker, governor — three roles, never collapsed

Enforcement also keeps three kinds of provenance distinct, because conflating them
is how false credit and false history get recorded:

- **Author/owner** — the human or project authority. Credit belongs here, and the
  commit-msg hook keeps it here: ordinary Git author/committer identity is never
  changed by anything below.
- **Worker/provider** — Claude, OpenAI, Copilot, and other models. They are
  delegated execution surfaces; doing the implementation work does **not** make one
  a project author. The hook rejects any AI `Co-Authored-By` or "generated by AI"
  line outright.
- **Governor** — the installed Spark control plane. Spark performed a real
  role — it governed the work — so it may be credited for exactly that, as
  `Governed by Spark vX.Y.Z`. Governed commits carry a mechanical
  `Spark-Governed-By: vX.Y.Z` trailer, and PRs carry the same line so a squash or
  rebase merge cannot erase the only durable signal.

Governance provenance is **measurement, not authorship**. The version is resolved
from the *installed* governor (`spark version`), never the working tree's
unreleased manifest — so once a version ships, it can be proven mechanically which
governor produced later work, rather than reconstructed after the fact from issues
and conversations. A supplied governor value that disagrees with the installed one
fails closed; an ungoverned repository is never stamped. Crediting the control
plane for governing is not the same as crediting a worker for authoring, and the
model refuses to let the second masquerade as the first.

This primitive records **only the governor identity**. Execution provenance — the
worker/model, provider, and surface that performed each governed role, and its
human-visible GitHub projection — is a **separate facility** (issue #711) with its
own durable, multi-actor representation. `Spark-Governed-By` answers *which
released Spark governed the work*, never *who executed it*, and this feature is
deliberately not widened into that scope.

## See also

- [Philosophy](philosophy.md) — the values layer this rationale supports.
- [Hooks reference](../reference/hooks.md) — exact wiring, exit codes, and behavior.
- ADR 0003 — the
  decision to implement enforcement as zero-dependency Bash hooks.
