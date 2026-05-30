# 10 — Discoverability (Discoverer / SEO)

> Author: jwogrady
> Phase: 3b — Draft + Reconcile
> Persona: Discoverer

---

## Persona

I'm the dev who hasn't found the repo yet. I'm searching or browsing directories, thinking in the terms I'd actually type. My job is to make sure you show up for those searches — repo description, topics, keywords, awesome-list targets, and social-preview metadata all echoing real capabilities (no keyword-stuffing, no invented terms).

---

## Neighbors

- **Upstream (I read):** `00-ground-truth.md` (verified capabilities), `01-hero.md` (tagline), `03-positioning.md` (honest delta), `05-philosophy.md` (core beliefs).
- **Downstream (read me):** `11-amplifier.md` (hand over hook phrases; keep launch copy consistent).

---

## Draft

### Target Dev Keywords (search terms)

These are real terms a developer would type, all cited to verified capabilities in `00-ground-truth.md`:

1. **"Claude Code plugin"** — Spark is shipped as a Claude Code plugin (manifest `.claude-plugin/plugin.json`; `00-ground-truth.md` "What this is").
2. **"GitHub SDLC"** or **"GitHub workflow"** — Five-stage lifecycle: Ideate → Plan → Generate → Solve → Ship (16 skills; `00-ground-truth.md` "Lifecycle / core workflow enforced").
3. **"AI-assisted development"** — Spark explicitly reuses Claude Code's `/code-review`, `/security-review`, `verify` rather than reinventing (additive design; `00-ground-truth.md` "Additive by design").
4. **"Conventional commits"** — `commit-msg` hook enforces type prefix + 72-char limit + no AI attribution (`00-ground-truth.md` "Enforcement").
5. **"Git hooks"** or **"pre-commit"** — PreToolUse Bash guard blocks force-push + trunk pushes; `commit-msg` + `pre-commit` git hooks (`00-ground-truth.md` "Enforcement").
6. **"CLI for developers"** or **"spark CLI"** — `bin/spark`: `doctor`, `list-skills`, `new-skill`, `install-git-hooks`, `shred-env` (`00-ground-truth.md` "The `spark` CLI").
7. **"Portable developer toolkit"** or **"versioned workflow"** — One installable plugin, carried into every project; marketplace (git-installable) (`00-ground-truth.md` "One installable, versioned lifecycle").
8. **"Multi-agent documentation"** or **"docit"** — 13 author personas as real subagents coordinating through `.docit-notes/` (`00-ground-truth.md` "Multi-persona authorship crews").
9. **"Internal knowledge capture"** or **"codify"** — 6-agent crew (intake → specialist → editor + librarian) for internal docs (`00-ground-truth.md` "Codify crew").
10. **"Zero dependencies"** or **"POSIX Bash"** — Pure shell, no runtime; graceful degradation if `jq`/`python3` absent (`00-ground-truth.md` "Zero runtime dependencies").
11. **"Issue-first development"** or **"GitHub issues"** — Plan skill decomposes into scoped GitHub issues + milestone (Skills table; `00-ground-truth.md`).
12. **"PR discipline"** or **"pull request workflow"** — `ship` skill opens focused PRs; one concern per PR enforced (`00-ground-truth.md` "Lifecycle / core workflow").

---

### Proposed GitHub Repo Description

(≤ 350 chars, keyword-rich, honest)

**Option 1 (concise, search-optimized):**
```
Portable SDLC plugin for Claude Code. Enforces Ideate→Plan→Generate→Solve→Ship 
lifecycle with mechanical guardrails: git hooks block force-push/trunk commits, 
conventional commits enforced, 16 lifecycle skills, multi-agent doc crews (docit, 
codify). Install once, carry into every project. Zero dependencies, MIT license pending.
```
(335 chars)

**Option 2 (voice-forward, brand-aligned):**
```
One opinionated lifecycle for AI-assisted development, portable via Claude Code 
plugin. Mechanical guardrails (git hooks, PreToolUse guard) keep your work clean. 
16 skills orchestrate Ideate→Plan→Generate→Solve→Ship. Multi-persona doc crews 
glow up your public + internal knowledge. Zero deps, POSIX Bash.
```
(325 chars)

**CHOSEN: Option 1** — clearer for search discovery; every term traces to a shipped feature.

---

### GitHub Topics / Tags List

Recommended tags (all verified against `00-ground-truth.md`):

- `claude-code` (plugin platform; `00-ground-truth.md` "What this is")
- `plugin` (marketplace-installable; `.claude-plugin/plugin.json`)
- `sdlc` (five-stage lifecycle; `00-ground-truth.md` "Lifecycle / core workflow")
- `workflow-automation` (enforcement hooks, CLI; `00-ground-truth.md` "Enforcement")
- `github` (issues, PRs, git-level enforcement; multiple skills)
- `git-hooks` (commit-msg, pre-commit, guard-bash.sh; `00-ground-truth.md` "Enforcement")
- `conventional-commits` (enforced by hook; `00-ground-truth.md` "Enforcement")
- `ai-development` (Claude Code integration, reuses built-ins; `00-ground-truth.md` "Additive")
- `developer-tools` (16 lifecycle skills, CLI; `00-ground-truth.md` "Lifecycle skills")
- `multi-agent` (docit 13 agents, codify 6 agents; `00-ground-truth.md`)
- `documentation-automation` (docit crew for public docs; `00-ground-truth.md`)
- `bash` (pure POSIX Bash, zero deps; `00-ground-truth.md` "Zero runtime dependencies")
- `typescript` (optional; some skills use TypeScript, but repo is primarily Bash/Markdown)
- `open-source` (MIT-pending; `00-ground-truth.md` "License TBD" flag)

**Final recommended set (8–10 primary):** `claude-code`, `plugin`, `sdlc`, `github`, `git-hooks`, `conventional-commits`, `ai-development`, `developer-tools`, `multi-agent`, `documentation-automation`.

---

### Awesome-List / Directory Targets

**Fit analysis:**

1. **Awesome Claude / Awesome Claude Code** — ✓ Exact fit. A portable Claude Code plugin for AI-assisted development lifecycle.
   - Entry: "Spark — Portable SDLC plugin: lifecycle (Ideate→Plan→Generate→Solve→Ship) + enforcement hooks (git, conventional commits, PreToolUse guard) + 16 skills + multi-agent doc crews."
   - Source: `01-hero.md` tagline, `00-ground-truth.md` capabilities.

2. **Awesome GitHub Actions / Awesome Git Hooks** — ✓ Partial fit. The repo is not a GitHub Action itself, but the enforcement (PreToolUse guard, `commit-msg`/`pre-commit` hooks) is relevant to teams seeking governance.
   - Entry: "Spark's hook suite — PreToolUse Bash guard (blocks force-push, trunk pushes); `commit-msg` hook (enforces conventional type + 72-char limit + blocks AI attribution)."
   - Source: `00-ground-truth.md` "Enforcement".

3. **Awesome AI-Assisted Development / Awesome AI Code** — ✓ High fit. Explicitly designed for AI-assisted dev, reuses Claude Code's built-in reviewers, enforces workflow discipline.
   - Entry: "Spark — Claude Code plugin for disciplined AI-assisted development: mechanical enforcement (hooks, guard), 5-stage lifecycle (Ideate→Plan→Generate→Solve→Ship), zero runtime deps."
   - Source: `00-ground-truth.md` "What this is", `05-philosophy.md` "Problem Spark refuses to accept".

4. **Awesome Multi-Agent Systems / Awesome Agent Orchestration** — ✓ Moderate fit. docit (13 agents) and codify (6 agents) coordinate through shared `.docit-notes/` — a pattern worth showcasing.
   - Entry: "Spark docit crew — 13 author personas (Cartographer, Skimmer, Adopter, Skeptic, Evaluator, Believer, Coach, Visual Storyteller, Librarian, Discoverer, Amplifier, Issue Council, Editor) orchestrate public-docs review in phases; codify crew (6 agents) handles internal knowledge."
   - Source: `00-ground-truth.md` "Multi-persona authorship crews".

5. **Awesome Conventional Commits** — ✓ Niche fit. Hook-enforced, blocks non-conforming commits; relevant to teams standardizing on conventional commits.
   - Entry: "Spark's `commit-msg` hook enforces conventional-commit type prefix, subject ≤72 chars, no trailing period, blocks AI co-author trailers."
   - Source: `00-ground-truth.md` "Enforcement".

6. **Awesome POSIX Bash / Shell Tools** — ✓ Moderate fit. Pure Bash, zero deps, graceful degradation.
   - Entry: "Spark — POSIX-friendly Bash scripts (CLI, hooks, guard) with graceful degradation when `jq`/`python3` absent. Works in any forked project regardless of stack."
   - Source: `00-ground-truth.md` "Zero runtime dependencies".

---

### Social-Preview Metadata

**Social tagline (from `01-hero.md`, chosen Option 1):**
```
"Turn raw project intent into durable GitHub artifacts — in one portable toolkit."
```

**Social card body (2–3 lines):**
```
Install Spark once, carry the same SDLC into every Claude Code project.
Mechanical guardrails (git hooks, conventional commits). Five-stage lifecycle:
Ideate → Plan → Generate → Solve → Ship. Zero deps, honest attribution.
```

**Image alt text / meta description (search-engine friendly):**
```
Spark — Portable SDLC plugin for Claude Code. Enforces Ideate→Plan→Generate→Solve→Ship 
lifecycle with git hooks, conventional commits, and mechanical guardrails. 16 lifecycle 
skills + multi-agent doc crews. Install once, carry into every project.
```

**OG Image recommendations (if Visual Storyteller asset #1 — Lifecycle flow Mermaid — exists):**
- Use the Lifecycle flow diagram (Ideate → Plan → Generate → Solve → Ship boxes, with icons if possible).
- Subtitle: "Portable SDLC plugin for Claude Code"
- Color: Match Claude Code brand (navy/blue) or Spark brand (if defined).
- Source: `08-visuals.md` asset #1; `01-hero.md` "Place 08-visuals.md asset #1".

---

## Claims & Citations

| Claim | Citation in `00-ground-truth.md` |
|---|---|
| Spark is a Claude Code plugin, marketplace-installable | "What this is (one paragraph)" + "Plugin packaging" section |
| 16 lifecycle skills (ideate, plan, build, fix-issue, commit, ship, bootstrap, connect, fork-init, claude-md, agents-md, write-a-skill, grill-me, review, docit, codify) | "Lifecycle skills (16 total)" + "Setup / inception skills" + "Review / knowledge skills" |
| Five-stage lifecycle: Ideate → Plan → Generate → Solve → Ship | "Lifecycle / core workflow enforced" section |
| PreToolUse Bash guard blocks force-push and trunk commits | "Enforcement" section: `hooks/hooks.json`, `hooks/guard-bash.sh` lines 47–58 |
| `commit-msg` hook enforces conventional type prefix, 72-char limit, no trailing period, blocks AI attribution | "Enforcement" section: `scripts/hooks/commit-msg` |
| `pre-commit` git hook blocks direct commits to `master`/`main` | "Enforcement" section: `scripts/hooks/pre-commit` |
| `spark` CLI: `doctor`, `list-skills`, `new-skill`, `install-git-hooks`, `shred-env`, `help` | "The `spark` CLI" section; verified by `bin/spark` case block |
| 13 docit author personas coordinating through `.docit-notes/` | "`docit` — multi-persona public-docs glow-up; 13 author personas" |
| 6-agent codify crew (intake, specialist, editor + librarian) | "`codify` — internal-knowledge crew (intake → specialist → editor + librarian)" |
| Zero runtime dependencies; pure POSIX Bash; graceful degradation without `jq`/`python3` | "Zero runtime dependencies" section; ADR-0003 |
| Reuses Claude Code's `/code-review`, `/security-review`, `verify` | "Additive by design" section; verified by `skills/fix-issue/SKILL.md` and `skills/review/SKILL.md` |
| License status: MIT declared in `plugin.json`, but `LICENSE` file says "TBD" | "Accuracy flags" section |
| Version: `v0.2.0` | `.claude-plugin/plugin.json` |
| Marketplace install (git URL) verified; one-click marketplace listing a v0.2 open item | "ROADMAP" section: "validate install end-to-end from a *published* marketplace (unchecked box)" |

---

## Cross-eval Feedback

*(None yet — Phase 3b draft. Reconciliation phase feedback welcome from Amplifier (11), Cartographer (00), Hero (01) after publication.)*

### Reconciliation Notes (Post-Draft)

- **Amplifier (11) hand-over:** Keywords 1–5 and awesome-list targets 1, 3 are the strongest hook phrases. Ensure launch copy (`shop.md`, Twitter, newsletter) reinforces these.
- **Hero (01) alignment:** Tagline option 1 ("Turn raw project intent into durable GitHub artifacts") is consistent with chosen social-preview tagline. No conflict.
- **Cartographer (00) honest-hype check:** Every keyword and awesome-list entry cites a verified capability. No invented terms, no keyword-stuffing detected.

---

## Summary for Orchestrator

**Proposed GitHub description** (335 chars, Option 1):
```
Portable SDLC plugin for Claude Code. Enforces Ideate→Plan→Generate→Solve→Ship 
lifecycle with mechanical guardrails: git hooks block force-push/trunk commits, 
conventional commits enforced, 16 lifecycle skills, multi-agent doc crews (docit, 
codify). Install once, carry into every project. Zero dependencies, MIT license pending.
```

**Recommended GitHub topics (8–10 primary):**
`claude-code`, `plugin`, `sdlc`, `github`, `git-hooks`, `conventional-commits`, `ai-development`, `developer-tools`, `multi-agent`, `documentation-automation`

**Top awesome-list targets:**
1. Awesome Claude / Awesome Claude Code (exact fit)
2. Awesome AI-Assisted Development (high fit)
3. Awesome Multi-Agent Systems (moderate fit)

**Social-preview tagline (from 01-hero.md):**
"Turn raw project intent into durable GitHub artifacts — in one portable toolkit."
