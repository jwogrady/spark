# Launch Copy — Spark

> Generated marketing copy (a `docit` output artifact), kept here as an example —
> not part of the published docs. Regenerate it with the `docit` skill rather than
> hand-maintaining it; verify every count against the repo before posting.

## Repo description (≤ 350 chars, search-optimized)

```
Portable SDLC plugin for Claude Code. Enforces Ideate→Plan→Generate→Solve→Ship
lifecycle with mechanical guardrails: git hooks block force-push/trunk commits,
conventional commits enforced, 11 skills, multi-agent doc crews (docit,
knowledge). Install once, carry into every project. Zero dependencies, MIT licensed.
```

## GitHub topics (8–10 primary)

`claude-code`, `plugin`, `sdlc`, `github`, `git-hooks`, `conventional-commits`,
`ai-development`, `developer-tools`, `multi-agent`, `documentation-automation`

## Social-preview metadata

**Tagline:** "one rig. every repo. zero drift."

**Card body:**
```
$ /plugin install spark
> one lifecycle, carried into every Claude Code repo:
>   Ideate → Plan → Generate → Solve → Ship
> the guardrails aren't suggestions — they run before you can fumble.
> 11 skills. two agent crews. zero deps. honest attribution. ▌
```

**OG image:** use the five-stage lifecycle flow on a deep-navy background with the
Spark accent color; `jwogrady/spark` in small monospace; no AI attribution;
1280×640 px at `.github/og-image.png`.

## Awesome-list targets

1. Awesome Claude Code — exact fit.
2. Awesome AI-Assisted Development — high fit.
3. Awesome Multi-Agent Systems — moderate fit (docit 13 agents, knowledge 6 agents).

---

## Tweet / X thread

**1 (hook)**
> Turn raw project intent into durable GitHub artifacts — in one portable Claude
> Code plugin.
>
> Spark carries the same lifecycle into every repo you open:
> Ideate → Plan → Generate → Solve → Ship
>
> One install, less drift.
> https://github.com/jwogrady/spark

**2 (mechanical enforcement)**
> The guardrails aren't suggestions.
> - A PreToolUse hook blocks force-push and trunk commits *before* Claude acts
> - `commit-msg` rejects non-conventional commits and strips AI-attribution trailers
> - `spark doctor` validates every skill, agent, and hook on demand
>
> `spark install-git-hooks` — done.

**3 (headline change — knowledge)**
> New: `knowledge` crew.
>
> 13 docit personas already glow up your public docs.
> Now 6 knowledge agents capture the internal layer: decisions, architecture, processes
> — as real plugin subagents coordinating through a dedicated scratch directory.
>
> Inward-facing. Separate from docit. Same plugin.

**4 (honest delta)**
> What it isn't:
> - Not a team platform (solo tool today; Git handles repo concurrency)
> - Not a one-click marketplace install yet (Git URL / local clone; published
>   listing is a v0.2 open item)
> - Not zero lock-in (Claude Code dependency is total)
>
> The value is portability and enforcement, not capability.

**5 (install CTA)**
> Install (from a local clone or Git URL):
> /plugin marketplace add jwogrady/spark
> /plugin install spark
>
> Then in any repo:
> spark install-git-hooks
> spark doctor
>
> 11 skills. Multi-agent doc crews. Zero runtime deps.
> https://github.com/jwogrady/spark

---

## Show HN

**Title:** Show HN: Spark – portable SDLC plugin for Claude Code (Ideate→Plan→Generate→Solve→Ship)

**Blurb:**

Spark is a Claude Code plugin I built to carry one opinionated AI-assisted
development lifecycle into every project. Install it once, get the same 11 skills,
enforcement hooks, and CLI everywhere.

What's mechanical (not advisory):
- PreToolUse Bash guard blocks `git push --force`/`-f` and pushes to trunk before
  Claude executes them (`hooks/guard-bash.sh`)
- `commit-msg` git hook rejects non-conventional commits and blocks AI co-author
  trailers (`scripts/hooks/commit-msg`)
- `pre-commit` blocks direct commits to `master`/`main`

The headline addition in the current HEAD: a `knowledge` crew — 6 specialist agents
(intake, architect, product, ops, librarian, editor) that capture internal
knowledge as real plugin subagents. It runs alongside the 13-persona `docit` crew
for public docs, each coordinating through a separate scratch directory.

Honest caveats:
- v0.2.0 is a solo tool (no team-coordination layer)
- Marketplace one-click install is an open v0.2 item; install via local clone or
  Git URL today
- No CI yet (the enforcement model is the intentional quality mechanism for a
  Bash/Markdown project, but there's no automated regression suite)

Zero runtime dependencies. Pure POSIX Bash. Works in any forked project regardless
of stack. MIT licensed.

Repo: https://github.com/jwogrady/spark

---

## Reddit post

**Target subreddits:** r/programming, r/devtools, r/AIAssisted, r/ClaudeAI

**Title:** I built a portable SDLC plugin for Claude Code that enforces Ideate→Plan→Generate→Solve→Ship with mechanical guardrails — show and tell

**Body:**

I've been building Spark — a Claude Code plugin that carries one opinionated
AI-assisted development lifecycle into every repo I open.

**The problem it solves:** AI-assisted development is fast and loose by default.
The conventions that keep work clean — conventional commits, trunk discipline,
scoped issues, focused PRs — are easy to state and easy to skip. Spark makes them
mechanical rather than advisory.

**What's shipped in v0.2.0:**
- 11 skills wired to slash commands: `/spark:ideate`, `/spark:plan`,
  `/spark:codify`, `/spark:fix-issue`, `/spark:ship` (plus setup and knowledge
  skills)
- Mechanical guardrails: a PreToolUse Bash hook that blocks force-pushes and trunk
  commits before Claude executes them; a `commit-msg` git hook that rejects
  non-conventional commits and strips AI co-author trailers; a `pre-commit` hook
  that blocks direct commits to trunk
- `spark` CLI: `doctor`, `list-skills`, `new-skill`, `install-git-hooks`,
  `shred-env`, `help`
- Two authorship crews: `docit` (13 personas, public docs) and `knowledge` (6 agents,
  internal knowledge) — real plugin subagents, each coordinating through its own
  scratch directory

**Headline change in the unreleased v0.2 window:** `knowledge`, the inward-facing
counterpart to `docit`. Six specialists — intake, architect, product, ops,
librarian, editor — capture decisions, architecture, and processes.

**Honest caveats:**
- Solo tool today. No team dashboard or shared-state sync; that's roadmap.
- Marketplace one-click install is a v0.2 open item. Install from a local clone or
  Git URL for now.
- No CI. The quality mechanism is the enforcement model itself; automated
  regression on skill behavior isn't there yet.
- Claude Code dependency is total.

**Install (from local clone or Git URL):**
```
/plugin marketplace add jwogrady/spark
/plugin install spark

spark install-git-hooks   # per repo
spark doctor              # validate everything
```

Zero runtime dependencies. Pure POSIX Bash. MIT licensed.
Repo: https://github.com/jwogrady/spark
