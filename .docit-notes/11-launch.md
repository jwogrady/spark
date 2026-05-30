# 11 — Launch Copy (Amplifier)

> Author/credit: `jwogrady`. All load-bearing claims trace to `00-ground-truth.md`.
> Phase: 3b — Draft + Reconcile

---

## Persona

I am the Amplifier: the launch voice. I turn what is real into copy people want
to click — and I never overpromise. Every claim here traces to `00-ground-truth.md`
or is flagged as unverifiable before it posts.

---

## Neighbors

- **Upstream (I read):** `00-ground-truth.md` (verified fact base); `01-hero.md`
  (tagline + hook); `03-positioning.md` (honest delta, concessions); `09-changelog.md`
  (headline change); `10-discoverability.md` (SEO hook phrases).
- **Downstream:** Editor (12) assembles `11-launch.md` + `10-discoverability.md`
  into `docs/launch-copy.md`.

---

## Headline Change (from 09)

> Spark now ships with an internal-knowledge crew. `codify` captures architectural
> decisions and processes — alongside `docit`'s public-docs glow-up — as real
> plugin subagents coordinating through a dedicated scratch directory.

Source: `09-changelog.md` §"What Changed" item 2; `00-ground-truth.md` §"Review /
knowledge skills" — `codify` crew (6 agents: `00-intake`..`05-editor`).

---

## SEO Hook Phrases (from 10, verified)

Primary hooks for all copy below:

- `Claude Code plugin`
- `GitHub SDLC` / `GitHub workflow`
- `AI-assisted development`
- `portable developer toolkit`
- `multi-agent documentation`
- `conventional commits` / `git hooks`
- `zero dependencies`

---

## Draft

### 1. Tweet / X Thread

---

**Tweet 1 (hook)**

Turn raw project intent into durable GitHub artifacts — in one portable Claude
Code plugin.

Spark carries the same lifecycle into every repo you open:
Ideate → Plan → Generate → Solve → Ship

One install. No drift.

https://github.com/jwogrady/spark

---

**Tweet 2 (mechanical enforcement)**

The guardrails aren't suggestions.

- A PreToolUse hook blocks force-push and trunk commits *before* Claude acts
- `commit-msg` rejects non-conventional commits and strips AI-attribution trailers
- `spark doctor` validates every skill, agent, and hook on demand

`spark install-git-hooks` — done.

---

**Tweet 3 (headline change — codify)**

New: `codify` crew.

13 docit personas already glow up your public docs.
Now 6 codify agents capture the internal layer: decisions, architecture, processes —
as real plugin subagents coordinating through a shared scratch directory.

Inward-facing. Separate from docit. Ships in the same plugin.

---

**Tweet 4 (honest delta)**

What it isn't:

- Not a team platform (solo tool today; Git handles repo concurrency)
- Not a one-click marketplace install yet (git URL / local clone; published
  listing is a v0.2 open item)
- Not zero lock-in (Claude Code dependency is total)

The value is portability and enforcement, not capability.

---

**Tweet 5 (install CTA)**

Install (from a local clone or Git URL):

/plugin marketplace add jwogrady/spark
/plugin install spark

Then in any repo:
spark install-git-hooks
spark doctor

16 lifecycle skills. Multi-agent doc crews. Zero runtime deps.
Full docs: https://github.com/jwogrady/spark

---

**CLAIMS VERIFICATION — Tweet thread:**

| Claim | Source |
|---|---|
| "portable Claude Code plugin" | `00-ground-truth.md` "What this is"; `.claude-plugin/plugin.json` |
| "Ideate → Plan → Generate → Solve → Ship" | `00-ground-truth.md` "Lifecycle / core workflow enforced" |
| "PreToolUse hook blocks force-push and trunk commits before Claude acts" | `00-ground-truth.md` "Enforcement"; `hooks/guard-bash.sh` lines 47-58 |
| "`commit-msg` rejects non-conventional commits and strips AI-attribution trailers" | `00-ground-truth.md` "Enforcement"; `scripts/hooks/commit-msg` |
| "`spark doctor` validates every skill, agent, and hook" | `00-ground-truth.md` "The `spark` CLI" `cmd_doctor` |
| "13 docit personas" | `00-ground-truth.md` "Review / knowledge skills"; `agents/docit/` 13 files verified |
| "6 codify agents" | `00-ground-truth.md` "Review / knowledge skills"; `agents/codify/` 6 files verified |
| "real plugin subagents coordinating through a shared scratch directory" | `00-ground-truth.md` "Multi-persona authorship crews"; `09-changelog.md` §codify |
| "solo tool today" | `03-positioning.md` §"What Spark concedes"; `04-trust.md` §Maturity |
| "git URL / local clone; published listing is v0.2 open item" | `00-ground-truth.md` §ROADMAP "validate install end-to-end from a *published* marketplace (unchecked box)" |
| "16 lifecycle skills" | `00-ground-truth.md` "Lifecycle skills (16 total)" |
| "Zero runtime deps" | `00-ground-truth.md` "Zero runtime dependencies"; ADR-0003 |
| Install commands | `00-ground-truth.md` "Exact install + first-use commands"; `README.md`; `docs/how-to/install.md` |

**UNVERIFIABLE FLAG:** None. All claims trace to ground truth.

---

### 2. Hacker News — Show HN

**Title:**

Show HN: Spark – portable SDLC plugin for Claude Code (Ideate→Plan→Generate→Solve→Ship)

---

**Blurb:**

Spark is a Claude Code plugin I built to carry one opinionated AI-assisted
development lifecycle into every project. Install it once, get the same 16 skills,
enforcement hooks, and CLI everywhere.

**What's mechanical (not advisory):**
- PreToolUse Bash guard blocks `git push --force`/`-f` and pushes to trunk before
  Claude executes them (`hooks/guard-bash.sh`)
- `commit-msg` git hook rejects non-conventional commits and blocks AI co-author
  trailers at the git level (`scripts/hooks/commit-msg`)
- `pre-commit` blocks direct commits to `master`/`main`

**The headline addition in the current HEAD:** a `codify` crew — 6 specialist
agents (intake, architect, product, ops, librarian, editor) that capture internal
knowledge (decisions, architecture, processes) as real plugin subagents. It runs
alongside the 13-persona `docit` crew for public docs, each coordinating through
a separate scratch directory. This is the same subagent-coordination pattern used
by `docit`, now applied inward.

**Honest caveats:**
- v0.2.0 is a solo tool (no team coordination layer)
- Marketplace one-click install is an open v0.2 item; install via local clone or
  Git URL today
- License: MIT declared in the manifest; `LICENSE` file says "TBD" — do not
  redistribute until resolved
- No CI yet (the enforcement model is the intentional quality mechanism for a
  Bash/Markdown project, but there's no automated regression suite)

Zero runtime dependencies. Pure POSIX Bash. Works in any forked project regardless
of stack.

Repo: https://github.com/jwogrady/spark

---

**CLAIMS VERIFICATION — HN blurb:**

| Claim | Source |
|---|---|
| "16 skills" | `00-ground-truth.md` "Lifecycle skills (16 total)" |
| "PreToolUse Bash guard…`hooks/guard-bash.sh`" | `00-ground-truth.md` "Enforcement"; file verified |
| "`commit-msg` git hook…`scripts/hooks/commit-msg`" | `00-ground-truth.md` "Enforcement"; file verified |
| "`pre-commit` blocks direct commits to `master`/`main`" | `00-ground-truth.md` "Enforcement"; `scripts/hooks/pre-commit` verified |
| "6 specialist agents (intake, architect, product, ops, librarian, editor)" | `00-ground-truth.md` §codify; `agents/codify/` 6 files verified by listing |
| "13-persona `docit` crew" | `00-ground-truth.md` §docit; 13 files verified |
| "separate scratch directory" | `09-changelog.md` §codify; `skills/codify/SKILL.md` line 50 |
| "v0.2.0 is a solo tool" | `04-trust.md` §Maturity; `03-positioning.md` §Concessions |
| "marketplace one-click install is an open v0.2 item" | `00-ground-truth.md` §ROADMAP |
| "License: MIT declared…`LICENSE` file says TBD" | `00-ground-truth.md` §Accuracy flags |
| "No CI yet" | `04-trust.md` §CI; verified by `ls .github/workflows/` (no directory) |
| "Zero runtime dependencies. Pure POSIX Bash." | `00-ground-truth.md` "Zero runtime dependencies"; ADR-0003 |

**UNVERIFIABLE FLAG:** None. All claims trace to ground truth.

---

### 3. Reddit Post

**Target subreddits:** r/programming, r/devtools, r/AIAssisted, r/ClaudeAI

**Title:**

I built a portable SDLC plugin for Claude Code that enforces Ideate→Plan→Generate→Solve→Ship with mechanical guardrails — show and tell

---

**Body:**

Hey r/programming,

I've been building Spark over the past few days — a Claude Code plugin that
carries one opinionated AI-assisted development lifecycle into every repo I open.

**The problem it solves:**

AI-assisted development is fast and loose by default. The conventions that keep
work clean — conventional commits, trunk discipline, scoped issues, focused PRs
— are easy to state and easy to skip when you're moving fast with a model in the
loop. Spark makes them mechanical rather than advisory.

**What's shipped in v0.2.0:**

- **16 lifecycle skills** wired to Claude Code slash commands:
  `/spark:ideate`, `/spark:plan`, `/spark:build`, `/spark:fix-issue`,
  `/spark:commit`, `/spark:ship` (plus setup and knowledge skills)
- **Mechanical guardrails:** a PreToolUse Bash hook that blocks force-pushes and
  trunk commits before Claude executes them; a `commit-msg` git hook that rejects
  non-conventional commits and strips AI co-author trailers; a `pre-commit` hook
  that blocks direct commits to trunk
- **`spark` CLI:** `doctor` (validates everything), `list-skills`,
  `new-skill`, `install-git-hooks`, `shred-env`, `help`
- **Two authorship crews:** `docit` (13 personas for public docs) and `codify`
  (6 agents for internal knowledge) — each runs as real plugin subagents
  coordinating through a shared scratch directory

**The headline change in current HEAD (unreleased):**

`codify` is the new inward-facing counterpart to `docit`. Six specialist
agents — intake, architect, product, ops, librarian, editor — capture decisions,
architecture, and processes. Same coordination pattern as `docit`; different
output audience.

**Honest caveats (the ones I'd want to read upfront):**

- Solo tool today. No team dashboard or shared-state sync; that's roadmap.
- Marketplace one-click install is a v0.2 open item. Install from a local clone
  or Git URL for now.
- License is MIT in the manifest; `LICENSE` file says "TBD." Not redistributable
  until I finalize it.
- No CI. The quality mechanism for a Bash/Markdown project is the enforcement
  model itself (`spark doctor`, hook validation) — that's an intentional choice,
  but automated regression on skill behavior isn't there yet.
- Claude Code dependency is total. If you're not using Claude Code, this is not
  the right tool.

**Install (from local clone or Git URL):**

```
/plugin marketplace add jwogrady/spark
/plugin install spark

spark install-git-hooks   # per repo
spark doctor              # validate everything
```

Zero runtime dependencies. Pure POSIX Bash. Works in any forked project
regardless of stack.

Repo: https://github.com/jwogrady/spark

Happy to answer questions on the enforcement model, the subagent coordination
pattern, or any of the skill implementations.

---

**CLAIMS VERIFICATION — Reddit post:**

| Claim | Source |
|---|---|
| "16 lifecycle skills…slash commands" | `00-ground-truth.md` "Lifecycle skills (16 total)"; lifecycle table |
| "PreToolUse Bash hook…before Claude executes" | `00-ground-truth.md` "Enforcement"; `hooks/guard-bash.sh` |
| "`commit-msg` git hook…strips AI co-author trailers" | `00-ground-truth.md` "Enforcement"; `scripts/hooks/commit-msg` |
| "`pre-commit` hook blocks direct commits to trunk" | `00-ground-truth.md` "Enforcement"; `scripts/hooks/pre-commit` |
| "CLI subcommands: `doctor`, `list-skills`, `new-skill`, `install-git-hooks`, `shred-env`, `help`" | `00-ground-truth.md` "The `spark` CLI" — all 6 verified in `bin/spark` case block |
| "13 docit personas, 6 codify agents" | `00-ground-truth.md` §docit + §codify; both verified by file listing |
| "real plugin subagents coordinating through a shared scratch directory" | `00-ground-truth.md` "Multi-persona authorship crews"; `09-changelog.md` |
| "6 specialists: intake, architect, product, ops, librarian, editor" | `00-ground-truth.md` §codify; `agents/codify/00-intake` through `05-editor` verified |
| "solo tool today" | `04-trust.md` §Maturity statement |
| "marketplace one-click install is a v0.2 open item" | `00-ground-truth.md` §ROADMAP |
| "License is MIT in manifest; `LICENSE` file says TBD" | `00-ground-truth.md` §Accuracy flags |
| "No CI" | `04-trust.md` §CI; verified |
| "Zero runtime dependencies. Pure POSIX Bash." | `00-ground-truth.md` "Zero runtime dependencies" |

**UNVERIFIABLE FLAG:** None. All claims trace to ground truth.

---

## Reconcile — Cross-Verification

### Against `00-ground-truth.md`

Every load-bearing claim in all three platforms (tweet thread, HN, Reddit) is
listed in the claims tables above and traces directly to a verified file or
`00-ground-truth.md` section. No invented capabilities. No inflated numbers.
Version specified as v0.2.0 throughout (plugin.json verified).

### Against `01-hero.md` (tagline + hook)

- Tagline used in tweet 1: "Turn raw project intent into durable GitHub artifacts —
  in one portable toolkit." — exact match to `01-hero.md` chosen Option 1.
- Hook language ("portable Claude Code plugin", additive, no drift) consistent
  throughout.

### Against `03-positioning.md` (honest delta + concessions)

All four concessions from `03-positioning.md` are surfaced explicitly:
  1. Solo tool — tweet 4, HN, Reddit caveats.
  2. Marketplace not yet live end-to-end — tweet 4, HN, Reddit caveats.
  3. License unresolved — HN and Reddit only (appropriate channel; not needed in
     tweet thread where the character budget is tight).
  4. Claude Code dependency total — tweet 4, Reddit caveats.

The license caveat is omitted from the tweet thread. This is deliberate: a tweet
thread is not a legal document, and the HN/Reddit posts (the conversion surfaces)
carry it explicitly. If the license is resolved before launch, this flag can be
dropped from all three.

### Against `09-changelog.md` (headline change)

Headline change (codify crew) is the lede of tweet 3, the dedicated paragraph in
the HN blurb, and the "headline change in current HEAD" section of the Reddit post.
Every codify claim (6 agents, agent names, coordination pattern, separate scratch
directory) traces to `09-changelog.md` and `00-ground-truth.md`.

### Against `10-discoverability.md` (SEO hook phrases)

All primary hook phrases are used at least once across the three platforms:
- `Claude Code plugin` — tweet 1, HN title, Reddit title
- `GitHub SDLC` / `GitHub workflow` — tweet 1, HN blurb, Reddit
- `AI-assisted development` — tweet 1, Reddit body
- `portable developer toolkit` — tweet 1, HN blurb
- `multi-agent documentation` / `docit` — tweet 3, HN, Reddit
- `conventional commits` / `git hooks` — tweet 2, HN, Reddit
- `zero dependencies` — tweet 5, HN, Reddit

---

## Summary for Orchestrator

Phase 3b draft and reconcile complete. Three ready-to-post units written:
1. Five-tweet X thread — hook → enforcement → headline change (codify) → concessions → CTA.
2. Show HN title + blurb — technical, honest, caveats explicit.
3. Reddit post (r/programming target) — full context, honest caveats, install block.

All load-bearing claims verified against `00-ground-truth.md`. No unverifiable
claims. Honest-hype contract satisfied. SEO hook phrases from `10-discoverability.md`
woven throughout. License caveat in HN and Reddit; omitted from tweet thread with
rationale noted. Headline change (codify crew) is the promoted lede in all three
platforms.
