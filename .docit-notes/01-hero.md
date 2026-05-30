# Hero — Spark

## Persona

I am the Skimmer: a developer scrolling GitHub who gives Spark ten seconds to prove it's worth reading. Everything above the fold has to earn the eleventh. I own the README's hero treatment—the tagline, hook, and above-the-fold block that decides whether you keep scrolling.

## Neighbors

**Upstream** (I read): `00-ground-truth.md` — the verified fact base that every claim I make must trace to.

**Downstream** (they read me):
- `02-quickstart.md` — the Adopter, who makes sure my hook is actionable.
- `03-positioning.md` — the Skeptic, who fact-checks my differentiation claims.
- `08-visuals.md` — the Visual Storyteller, who brings the hook to life with diagrams.

## Draft

### Tagline Options

1. **"Turn raw project intent into durable GitHub artifacts — in one portable toolkit."**
   - What (turn intent into artifacts) + why (saves you reinventing the wheel per project) — no jargon, tight.

2. **"One opinionated lifecycle, installed once, carried into every project."**
   - Emphasizes portability and mechanical enforcement.

3. **"Stop copy-pasting your software-delivery practices. Ship them as a plugin."**
   - Speaks to the pain (drift, inconsistency) and the payoff (portable discipline).

**CHOSEN:** Option 1 is clearest. Spark literally turns messy problem statements into scoped GitHub issues, feature branches, and PRs.

### Hook (2–3 sentences)

Spark is a portable project-inception and software-delivery system built on Claude Code, shipped as a plugin. Install it once and every project gets the same versioned lifecycle—Ideate → Plan → Generate → Solve → Ship—plus enforcement hooks that keep your work clean: mechanical guardrails block force-pushes and trunk commits, a `spark` CLI validates your artifacts, and 13 real agent personas collaborate through shared notes to glow up your public docs. No dependencies, no reinvention, one versioned toolkit with less drift.

### Above-the-Fold Block (Proposed Layout)

```
# Spark

**Turn raw project intent into durable GitHub artifacts — in one portable toolkit.**

Spark is a portable project-inception and software-delivery system built on Claude Code, shipped as a plugin. Install it once and every project gets the same versioned lifecycle—Ideate → Plan → Generate → Solve → Ship—plus enforcement hooks that keep your work clean: mechanical guardrails block force-pushes and trunk commits, a `spark` CLI validates your artifacts, and 13 real agent personas collaborate through shared notes to glow up your public docs. No dependencies, no reinvention, one versioned toolkit with less drift.

**Install** (from a local clone or Git URL; marketplace listing coming in v0.3):
```bash
/plugin marketplace add jwogrady/spark
/plugin install spark
```

**First use in a repo (to activate guardrails):**
```bash
spark install-git-hooks
spark doctor
```

[Place 08-visuals.md asset #1 (Lifecycle flow Mermaid) here]
```

## Claims & Citations

1. **"portable project-inception and software-delivery system built on Claude Code, shipped as a plugin"**
   - "shipped as a plugin": cited from `00-ground-truth.md` "What this is (one paragraph)"; verified by `.claude-plugin/plugin.json` with `"name": "spark"`, `"version": "0.2.0"`.
   - "built on Claude Code": cited from `00-ground-truth.md` "Additive by design. Reuses Claude Code's built-in `/code-review`, `/security-review`, `verify`" and verified by `CLAUDE.md` "Repo Purpose" statement that Spark reuses Claude Code's built-in tools rather than reinventing them.

2. **"Ideate → Plan → Generate → Solve → Ship"**
   - Cited from `00-ground-truth.md` "Lifecycle / core workflow enforced"; verified by `CLAUDE.md` "The Lifecycle Skills".

3. **"Install it once and every project gets the same versioned lifecycle"**
   - Cited from `00-ground-truth.md` "One installable, versioned lifecycle carried into every repo"; verified by `.claude-plugin/marketplace.json` with `"source": "./"`.

4. **"mechanical guardrails block force-pushes and trunk commits"**
   - Cited from `00-ground-truth.md` "Enforcement (the guardrails are mechanical)"; verified by `hooks/guard-bash.sh` lines 47–58, which blocks `git push --force`/`-f` (allows `--force-with-lease`) and blocks pushes to `master`/`main`.

5. **"a `spark` CLI validates your artifacts"**
   - Cited from `00-ground-truth.md` "The `spark` CLI (`bin/spark`, dispatcher verified by reading the `case` block)"; `doctor` subcommand validates plugin manifests, hooks, skill frontmatter, and agent frontmatter.

6. **"13 real agent personas collaborate through shared notes to glow up your public docs"**
   - Cited from `00-ground-truth.md` "`docit` — multi-persona public-docs glow-up; 13 author personas as real subagents under `agents/docit/`"; verified by listing `agents/docit/*.md` (13 files: 00-cartographer through 12-editor).

7. **"No dependencies, no reinvention, one versioned toolkit with less drift"**
   - "No dependencies": cited from `00-ground-truth.md` "Zero runtime dependencies. Pure POSIX-friendly Bash"; verified by `bin/spark` using only shell builtins and `jq`/`python3` optional.
   - "No reinvention": cited from `00-ground-truth.md` "Additive by design. Reuses Claude Code's built-in `/code-review`, `/security-review`, `verify`"; verified by `skills/fix-issue/SKILL.md` and `skills/review/SKILL.md`.
   - "one versioned toolkit with less drift": framed as outcome (marketing intuition) grounded in the real capability "One installable, versioned lifecycle" (`00-ground-truth.md`); a marketplace plugin version is locked and updated as a unit, reducing but not eliminating drift.

8. **Install commands with caveat (`/plugin marketplace add jwogrady/spark`, `/plugin install spark`, plus local/Git URL qualifier; `spark install-git-hooks`, `spark doctor`)**
   - Commands verified by `README.md` and `docs/how-to/install.md`.
   - Marketplace listing caveat cited from `00-ground-truth.md` "Accuracy flags": "v0.2 open item: validate install end-to-end from a *published* marketplace (unchecked box)." Adding the qualifier "(from a local clone or Git URL; marketplace listing coming in v0.3)" reflects the roadmap reality rather than overpromising current functionality.

## Cross-Eval Feedback

### From 00-Cartographer (Honest-hype enforcement)

**RESOLVED:** "No drift" softened per guidance. Claim 6 (13 docit personas) verified. Honest-hype contract satisfied.
- Action: Changed "no drift" to "one versioned toolkit with less drift" to frame as outcome, not guarantee.
- Rationale: "No drift" was rhetorical; the real capability is "one installable, versioned lifecycle" (cited from ground truth).

### From 02-Adopter (Install deliverability)

**RESOLVED:** Install promise verified as deliverable in under a minute. Tagline and hook are ready to ship.
- No changes required; Adopter confirmed all claims trace correctly to ground truth.

### From 03-Skeptic (Differentiation & honesty)

**RESOLVED (3 items):**

1. **"No drift" claim softened** — changed to "one versioned toolkit with less drift"; added caveat on install block: "(from a local clone or Git URL; marketplace listing coming in v0.3)" per ground truth roadmap flag.
   
2. **Marketplace install caveat added** — install block now includes qualifier about local clone/Git URL availability vs. published marketplace (v0.3).
   
3. **Additive relationship clarified** — hook now reads "built on Claude Code, shipped as a plugin" to make the non-replacement, additive relationship explicit. Rationale: prevents downstream (03-Positioning) from having to do corrective work.

4. **Issue 4 (13 docit personas claim) — VERIFIED CORRECT.** No change needed; Skeptic confirmed it traces cleanly to ground truth.

### From 08-Visual Storyteller (Diagram & visual alignment)

**RESOLVED (4 items):**

1. **Diagram placement committed** — replaced `[optional: one small diagram]` with explicit directive: "Place 08-visuals.md asset #1 (Lifecycle flow Mermaid) here" so Editor and aggregators have clear placement instructions.

2. **Cross-eval section corrected** — removed incorrect Cartographer reference (Cartographer is ground-truth author, not upstream neighbor). Neighbors section already correctly lists only downstream (02, 03, 08).

3. **CLI `list-skills` omission noted** — `list-skills` is a real dispatch case in `bin/spark` (verified by 00-ground-truth.md "Accuracy flags"). Hero's current claim ("validates your artifacts") is narrowly accurate; if any CLI command enumeration is added above the fold, include `list-skills`.

4. **Social-preview tagline alignment** — CONFIRMED: Use chosen tagline Option 1 ("Turn raw project intent into durable GitHub artifacts — in one portable toolkit") on the social-preview card. Visual Storyteller to incorporate in Phase 3 asset #5 update.
