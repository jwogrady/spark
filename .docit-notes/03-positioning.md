# 03 — Positioning (Skeptic)

> Author: jwogrady
> Phase: 3 — Revise
> Persona: Skeptic

---

## Persona

I'm the dev who asks "why not just use the raw tool, or what I already have?" I
refuse to be sold to and I respect an honest delta. My job is to name the real
alternatives, compare them on the axes that actually matter, concede where they're
fine, and state the one case where Spark is the right call — plainly.

---

## Neighbors

- Upstream (I read): `00-ground-truth.md`, `01-hero.md`, `02-quickstart.md`
- Downstream (reads me): `04-trust.md`, `05-philosophy.md`

*Note: 01-hero.md and 02-quickstart.md did not exist at Phase 1 draft time — drafted from 00-ground-truth.md alone.*

---

## Draft

### Why not just use Claude Code directly?

You probably can. Claude Code already ships `/code-review`, `/security-review`,
and `verify`. You can write a CLAUDE.md, nudge the model toward conventional
commits, and get reasonable results on a single project. If that's your whole
situation, Spark adds friction.

The honest delta is this: Spark is a plugin — one install, every repo (via Git
URL or local path today; a published marketplace listing is a v0.2 open item,
not yet verified end-to-end). It carries a fixed lifecycle, mechanical
guardrails, and a consistent CLI across all your projects. The value proposition
is *portability and enforcement*, not capability.

### What Spark is actually up against

| Alternative | Honest assessment | Where Spark wins | Where the alternative is fine |
|---|---|---|---|
| **Raw Claude Code** (no plugin) | Full AI capability, zero structure | Spark adds guardrails and a repeatable lifecycle in every repo; raw mode is ungoverned | Fine if you work solo on one project and impose your own discipline |
| **A project-level CLAUDE.md** | Most teams already have one | Spark version-controls the *process*, not just the instructions; the same toolkit travels with you | Fine if each project's needs are different enough that a shared process would fight you |
| **Custom hooks + scripts per project** | Real enforcement, zero overhead from a plugin | Spark ships tested, composable hook scripts you don't write from scratch | Fine if you already have mature scripts and don't want the plugin abstraction |
| **Convention + team agreement** | Zero tooling cost | Spark's `commit-msg` hook *rejects* non-conforming commits; team agreement only asks | Fine for a disciplined team that never deviates |
| **Alternative workflow tools** (Linear, Jira bots, etc.) | Purpose-built for project management | Spark lives entirely inside Claude Code — no new SaaS seat, no webhook plumbing | Fine if you already have PM tooling and want that layer separate |

### What Spark concedes

- **The current release (v0.2.0) is a solo tool.** There is no shared-state
  sync, no team dashboard, no integration with an external issue tracker.
  Multi-user Git workflows work because Git is multi-user; the plugin itself is
  not.
- **Marketplace install is unverified end-to-end.** The ROADMAP explicitly flags
  this: v0.2 open item is "validate install end-to-end from a *published*
  marketplace." You can install from a local path or a Git URL; a one-click
  marketplace install from a public listing is roadmap, not shipped. The install
  commands shown in documentation (`/plugin marketplace add jwogrady/spark`)
  assume the listing is reachable and stable — that has not been verified. If
  the published marketplace is not yet reachable, install via Git URL or local
  path instead.
- **The license is formally unresolved.** `plugin.json` and the README badge
  declare MIT, but the `LICENSE` file reads "License TBD. Copyright belongs to
  the author." Until this is resolved, callers cannot legally redistribute or
  fork. The MIT label in the manifest is aspirational, not granted.
- **Claude Code dependency is total.** Spark does nothing without Claude Code.
  If your team uses a different AI IDE or wants editor-agnostic tooling, Spark is
  the wrong choice.
- **The lifecycle is opinionated.** Ideate → Plan → Generate → Solve → Ship with
  one-concern-per-unit discipline. If your workflow is more freeform or your
  project structure doesn't map to GitHub issues + branches, you'll fight the
  grain rather than ride it.

### When to use Spark

Use Spark when: you run multiple projects inside Claude Code, you want the same
guardrails and lifecycle in every one of them, and you're willing to let a single
opinionated plugin be the enforcer — so you stop re-inventing the process from
scratch on each new repo.

Skip it when: you have one project, you prefer raw Claude Code flexibility, or
your team's context is sufficiently different across repos that a shared lifecycle
would add friction rather than remove it.

---

## Claims & citations

| Claim | Source in 00-ground-truth.md |
|---|---|
| Spark is a Claude Code plugin, git-installable | "Plugin packaging" section — `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` |
| Claude Code ships `/code-review`, `/security-review`, `verify` | "What this is" — "reuses Claude Code's built-in reviewers" |
| PreToolUse hook blocks force-pushes and trunk pushes mechanically | "Enforcement" section — `hooks/hooks.json`, `hooks/guard-bash.sh` lines 47-58 |
| `commit-msg` git hook rejects non-conforming commits | "Enforcement" section — `scripts/hooks/commit-msg` |
| `pre-commit` blocks direct commits on trunk | "Enforcement" section — `scripts/hooks/pre-commit` |
| Marketplace end-to-end install is an open v0.2 item, not shipped | "ROADMAP" section — "validate install end-to-end from a *published* marketplace (unchecked box)" |
| License is formally unresolved; MIT is aspirational, not granted | "Accuracy flags" section — `LICENSE` reads "License TBD"; `plugin.json` declares MIT |
| 16 skills, all with valid frontmatter | "SHIPPED" section — "All 16 skills with valid frontmatter" |
| Additive design — reuses, not reinvents, Claude Code built-ins | "Genuine differentiators" — `docs/explanation/scope-and-upstream.md`, ADR-0002 |
| Zero runtime dependencies, POSIX Bash | "Genuine differentiators" — ADR-0003, `bin/spark` `check_json` |

---

## Cross-eval feedback

### From 00 (Cartographer)

1. **"v0.1 is a solo tool" — wrong version.** RESOLVED — changed to "current
   release (v0.2.0) is a solo tool" throughout. Version verified: `plugin.json`
   `"version": "0.2.0"`.

### From 01 (Skimmer / Hero)

2. **Portability claim is good as-is.** RESOLVED (no action needed, confirmed
   good).
3. **FLAG: Hero assumes marketplace install is public; if not, Quickstart must
   offer a Git URL fallback.** RESOLVED — expanded the marketplace concession
   bullet to explicitly state the fallback (Git URL or local path) and that the
   documented install commands assume reachability. Downstream 04/05 are now
   warned via this note.
4. **"The lifecycle is opinionated" — no contradiction with hero.** RESOLVED
   (confirmed, no change needed).
5. **All five comparison table rows support hero claims.** RESOLVED (confirmed,
   no change needed).

### From 02 (Adopter / Quickstart)

6. **Add prerequisite flag about marketplace assumption.** RESOLVED — the
   marketplace concession bullet now explicitly names the assumption and the
   fallback. This serves readers who encounter the install commands in the
   quickstart without finding them working.
7. **All comparison table claims verified against quickstart.** RESOLVED
   (confirmed, no change needed).

### From 04 (Evaluator)

8. **Add license mismatch concession.** RESOLVED — added a new bullet under
   "What Spark concedes": license is formally unresolved; MIT is aspirational;
   redistribution/forking is legally unclear until resolved. Cites
   `00-ground-truth.md` Accuracy flags.
9. **"v0.1 is a solo tool" — wrong version.** RESOLVED — see item 1 above.

### From 05 (Believer)

10. **Add qualifier on portability claim for marketplace-not-yet-live scenario.**
    RESOLVED — the "honest delta" paragraph now reads "via Git URL or local path
    today; a published marketplace listing is a v0.2 open item, not yet verified
    end-to-end" before asserting portability.
11. **Do not weaken the marketplace-install concession.** RESOLVED — the
    concession was strengthened, not softened. 05 can continue to cite it by
    name.
12. **"v0.1 is a solo tool" — wrong version.** RESOLVED — see item 1 above.
