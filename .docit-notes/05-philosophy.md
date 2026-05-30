# 05-Philosophy — The Believer

## Persona

The Believer asks: *What does this project stand for, and what future does it argue for?*

I write as the dev who wants to know why this thing exists — not a buzzword-padded mission
statement, but the specific problem Spark refuses to accept and the concrete principles
that follow. Every principle I state must tie back to a shipped feature. No untethered
manifesto.

---

## Neighbors

- **Upstream (I read):** `00-ground-truth.md`, `03-positioning.md`, `04-trust.md`.
- **Downstream (read me):** `06-diataxis.md`, `07-contributing.md`.

---

## Draft — `docs/explanation/philosophy.md`

> Target path: `docs/explanation/philosophy.md` — sits alongside `sdlc-doctrine.md`,
> `scope-and-upstream.md`, and `why-a-plugin.md` in the Diátaxis explanation tree.
> The ADRs (`docs/adr/0001..0003`) are the *decisions* layer; this doc is the *values*
> layer — complementary, not redundant. Must be cross-linked from any `docs/explanation/`
> index.

### The Problem Spark Refuses to Accept

AI-assisted development is powerful, fast, and loose by default. The default mode is:
a developer types a prompt, the model does something, the developer reviews (maybe),
ships (maybe), and the whole exchange evaporates. No lifecycle, no guardrails, no
durable artifact trail. The conventions that would make a team coherent — conventional
commits, trunk discipline, scoped issues, focused PRs — are easy to state and easy to
skip when you're moving fast with an AI in the loop.

Spark refuses to accept that productivity and discipline are in tension.

The assumption Spark contests is that "moving fast" and "staying clean" are a trade-off.
They are not. They require the same thing: *a mechanical system that makes the
right thing easy and the wrong thing hard.* Spark is that system for AI-assisted
development.

---

### The Doctrine

**1. Enforcement over aspiration.**

A convention you can skip is not a guardrail — it is a suggestion. Spark's rules are
enforced by code that runs before Claude acts or before a commit lands. The PreToolUse
Bash guard blocks force-pushes and trunk pushes before they execute — covering
AI-mediated git actions through Claude Code. The `commit-msg` hook rejects
non-conforming messages before they land in history — covering all git commits, once
the hooks are installed via `spark install-git-hooks`. Aspiration lives in READMEs;
enforcement lives in `hooks/` and `scripts/hooks/`. CI and automated testing are a
known gap at v0.2.0; the mechanical enforcement today covers commit conventions, trunk
discipline, and docs honesty — not the full quality surface.

**2. One lifecycle, portable.**

Every project a developer works in deserves the same discipline — not a copy-paste of
conventions that drift per repo, but one versioned toolkit installed once and carried
everywhere. At v0.2.0, install via git URL is verified; one-click public marketplace
install is an open v0.2 item. The portability principle is architecturally realized;
the marketplace listing is in progress. Today this is a single-developer toolkit;
team coordination tooling is on the roadmap.

**3. Additive by design.**

Spark does not reinvent what already exists. Claude Code ships `/code-review`,
`/security-review`, and `verify`; Spark routes to them. Anthropic owns the skill/plugin
spec; Spark builds on it. This is not modesty — it is the correct architectural choice.
Adding your own review engine when a good one already exists is waste, not capability.
The same logic governs contributions: a new skill is additive, not a patch to the core
lifecycle. Skills are self-contained by design, with no cross-skill imports at runtime.

**4. Scoped work as the unit of discipline.**

The lifecycle's constraint — one problem per ideate, one feature per issue, one issue per
branch, one concern per PR — is not bureaucracy. It is the mechanism by which large
ambitions become shippable increments. Scope collapse is the most common cause of AI
work going sideways; Spark makes scope a first-class enforced concept rather than an
afterthought. This operates on a single developer's context today; the scope doctrine
is valid and enforced within that boundary.

**5. Zero external dependencies.**

A developer tool that requires a bespoke runtime to work is a tool that fails when the
runtime breaks. Spark's CLI and hooks are pure POSIX-friendly Bash with graceful
degradation when optional tools (`jq`, `python3`) are absent. Any forked project,
any stack, any machine — the guardrails still hold.

**6. Honest attribution, honest hype.**

The commit-msg hook blocks AI co-author trailers — mechanically, with exit code 2. The
docit crew's phase protocol requires every claim to trace to a verified ground-truth
note before it ships; the author reviews and rejects any note that cannot cite its
evidence. This is a rigorous process with author review as the final gate, not a
deterministic code check. Both mechanisms reflect the same belief: the author of the
work is the author of the work, and claims travel only as far as the evidence beneath
them. An issue-first gate reinforces this at the contribution level: new skills require
a GitHub issue (using the Skill template) and community feedback before any code is
written — preventing unvetted features from landing in the first place.

---

### The Future Spark Argues For

The future Spark is building toward is one where AI-assisted development is
*indistinguishable from disciplined development* — where the speed and the rigor are
the same thing, not alternatives. The lifecycle does not slow you down; it is the
track that makes the speed safe.

That future is not guaranteed by capability alone. It requires tooling that encodes
the right habits mechanically. Spark is a bet that the right encoding exists and is
worth carrying into every project. The v0.2 release is the first proof of concept;
the architecture is set, the gaps are documented.

---

## Claims & Citations

| Claim | Citation in `00-ground-truth.md` |
|---|---|
| PreToolUse guard blocks force-push and trunk push before Claude acts (AI-mediated only) | "Enforcement" section → `hooks/guard-bash.sh` lines 47-58; `hooks/hooks.json` |
| `commit-msg` hook enforces conventional prefix, length, no trailing period, blocks AI attribution | "Enforcement" section → `scripts/hooks/commit-msg` |
| `pre-commit` hook blocks direct commits to trunk | "Enforcement" section → `scripts/hooks/pre-commit` |
| Git hooks require explicit install via `spark install-git-hooks` | CLI section → `bin/spark` `cmd_install_git_hooks` |
| No CI / automated test suite at v0.2.0 | "Accuracy flags" — no `.github/workflows/` (04-trust.md); "SHIPPED" section |
| Marketplace plugin — installable via git URL; one-click marketplace install is v0.2 open item | "Plugin packaging" section → `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`; "ROADMAP" section |
| Spark reuses `/code-review`, `/security-review`, `verify` rather than reinventing | "Genuine differentiators" section; `docs/explanation/scope-and-upstream.md`, ADR-0002 |
| Skills are self-contained, no cross-skill imports at runtime | `CLAUDE.md` "Skill Authoring"; `skills/write-a-skill/SKILL.md` |
| One lifecycle: Ideate → Plan → Generate → Solve → Ship | "Lifecycle / core workflow enforced" section → `README.md`, `CLAUDE.md` |
| Zero runtime dependencies; pure POSIX Bash with graceful degradation | "Genuine differentiators" section; ADR-0003, `bin/spark` `check_json` |
| commit-msg hook blocks AI co-author trailers (exit code 2, mechanical) | "Enforcement" section → `scripts/hooks/commit-msg` |
| docit honest-hype contract — process-enforced, author-reviewed; no claim ships without ground-truth trace | "Genuine differentiators" section → `00-ground-truth.md` as enforcement substrate |
| One concern per unit (problem/issue/branch/PR) | "Lifecycle / core workflow enforced" section → `README.md` Design principles |
| Issue-first gate: new skills require GitHub issue + feedback before code | `CONTRIBUTING.md` §"Proposing a skill" |
| Target file path: `docs/explanation/philosophy.md` | `00-ground-truth.md` §Docs — `docs/explanation/` tree; `06-diataxis.md` |

---

## Cross-eval Feedback

### from-00-to-05 (Cartographer — honest-hype enforcement)

**VERDICT: PASS — no required changes.**

- Watch-item 1 (aspirational future-tense section): RESOLVED — the closing paragraph
  now ends with "The v0.2 release is the first proof of concept; the architecture is
  set, the gaps are documented." This grounds the vision without cutting it.
- Watch-item 2 (present-tense claims only for shipped mechanisms): RESOLVED — all
  principles now qualify their claims accurately; see revisions to P1, P2, P4, P6.

---

### from-03-to-05 (Skeptic / Positioning)

- Issue 1 (enforcement gaps — PreToolUse only covers AI-mediated actions): RESOLVED —
  Principle 1 now explicitly states the PreToolUse guard covers AI-mediated git actions
  and the git hooks cover commits once installed, and names `spark install-git-hooks`
  as the required setup step.
- Issue 2 (marketplace portability — unverified end-to-end): RESOLVED — Principle 2
  now states "At v0.2.0, install via git URL is verified; one-click public marketplace
  install is an open v0.2 item."
- Issue 3 (scoped-work doctrine — solo-developer scope): RESOLVED — Principle 4 now
  adds "This operates on a single developer's context today; the scope doctrine is
  valid and enforced within that boundary."
- Issue 4 (honest attribution/hype is cleanest point): NOTED — no change requested;
  acknowledged.
- Issue 5 (future-vision paragraph could feel jarring after license/CI disclosures):
  RESOLVED — closing paragraph now ends with the grounding sentence recommended.

---

### from-04-to-05 (Evaluator / Trust)

- Issue 1 (Principle 6 enforcement claim too broad — no CI): RESOLVED — Principle 1
  now explicitly calls out "CI and automated testing are a known gap at v0.2.0";
  Principle 6 separates hook-based (mechanical, exit code 2) from docit-process
  (rigorous process, author-reviewed). Claims table adds the no-CI row.
- Issue 2 (Principle 2 install maturity caveat missing): RESOLVED — same fix as
  from-03 Issue 2; qualified with git-URL vs. marketplace-listing distinction.

---

### from-06-to-05 (Coach / Diátaxis)

- Issue 1 (Principle 6 conflates hook enforcement with docit process): RESOLVED —
  Principle 6 now separates the two explicitly: hook = mechanical/deterministic (exit
  code 2); docit contract = rigorous process with author review as the final gate.
- Issue 2 (target file path and link into explanation tree): RESOLVED — added a
  preamble note to the Draft section declaring target path
  `docs/explanation/philosophy.md`, the ADR/philosophy distinction, and cross-link
  requirement.

---

### from-07-to-05 (Contributor)

- Issue 1 (Principle 3 misses contributor extension path): RESOLVED — added one
  sentence to Principle 3: "The same logic governs contributions: a new skill is
  additive, not a patch to the core lifecycle. Skills are self-contained by design,
  with no cross-skill imports at runtime."
- Issue 2 (Principle 6 omits issue-first gate): RESOLVED — Principle 6 now includes
  the issue-first gate: new skills require a GitHub issue + community feedback before
  any code is written. Added to Claims table citing `CONTRIBUTING.md`.
- Issue 3 (terminology gap on branch naming — flagged for 07's own revision): NOTED —
  no action on 05; logged for persona 07.
