# Phase 3 — Decision Slate (Council Synthesis)

Council Synthesis Lead. Six seats tallied per artifact. Majority rules; even/fundamental
splits are DEADLOCK (human breaks ties). Every DIE/MOVE is destructive=true — this is a
PLAN, not an execution. Law: one job one place; single lane; reference native, don't reimplement.

Seats: Native Enforcer (NE), Lane-Warden (LW), DRY Auditor (DRY), Lifecycle Architect (LA),
Minimalist (MIN), Preservationist (PRES).

---

## Tally matrix

| artifact | NE | LW | DRY | LA | MIN | PRES | tally | final |
|---|---|---|---|---|---|---|---|---|
| grill-me | DIE | DIE | DIE | DIE | DIE | DIE | DIE x6 | **DIE** |
| write-a-skill | DIE | DIE | DIE | DIE | DIE | DIE | DIE x6 | **DIE** |
| fork-init | DIE | DIE | DIE | DIE | DIE | DIE | DIE x6 | **DIE** |
| claude-md | MOVE | LIVE | LIVE | MOVE | MOVE | LIVE | LIVE x3 / MOVE x3 | **DEADLOCK** |
| agents-md | MOVE | LIVE | LIVE | LIVE | MOVE | LIVE | LIVE x4 / MOVE x2 | **LIVE** |
| build | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| codify | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| docit | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| ideate | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| plan | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| bootstrap | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| connect | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| commit | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| ship | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| fix-issue | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| review | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE | LIVE x6 | **LIVE** |
| agents/codify crew | LIVE | (w/codify) | LIVE | LIVE | LIVE | LIVE | LIVE | **LIVE** |
| agents/docit crew | LIVE | (w/docit) | LIVE | LIVE | LIVE | LIVE | LIVE | **LIVE** |
| bin/spark CLI | LIVE | LIVE | LIVE | (implied) | LIVE | (implied) | LIVE | **LIVE** |

---

## LIVE (keep — earns its slot)

### build — coding (Generate, stage 3)
Vote: LIVE x6. Enforces one-issue-per-branch, stop-at-AC, never-work-on-master, no
opportunistic refactor. Native Claude codes but enforces none of this. Thinnest LIVE
but unanimous. Required clarity: explicit non-goals (does not write docs — that is
codify/docit).

### fix-issue — coding (Solve, stage 4)
Vote: LIVE x6. The reference model for the whole repo: explicitly orchestrates
/code-review, /security-review, verify without reimplementing. Adds triage taxonomy
(must/should/out-of-scope), out-of-scope-as-new-issue rule, AC re-check. Keep as-is;
template for every other native-touching skill.

### review — quality/audit
Vote: LIVE x6. 8-specialist breadth (architecture, testing, docs, product readiness,
risk) has no native equivalent. REQUIRED FIX (unanimous across seats): agents 03
(Code Quality) and 05 (Security) must explicitly delegate to native /code-review and
/security-review rather than re-run the same analysis — mirror the fix-issue pattern.
Breadth lanes are irreplaceable; the two overlapping dimensions are a calibration fix,
not a kill.

### ideate — exploration (stage 1)
Vote: LIVE x6. Sole owner of EXPLORATION per author law. Structured problem-statement
contract (Problem/Outcome/Success criteria/Constraints/Non-goals), no-code/no-tickets
guardrail, confirm-before-handoff-to-plan. After grill-me dies, ideate references the
NATIVE grill-me skill by name (the call already works).

### plan — planning (stage 2)
Vote: LIVE x6. Decomposes problem statement into GitHub issues using .github/ISSUE_TEMPLATE/,
confirm-before-create guardrail, 3-7 feature scope cap, AC-as-verifiable-contract. Native
gh creates issues but enforces none of these.

### commit — git-guardrails (Ship 5a)
Vote: LIVE x6. Produces a commit-msg-hook-passing message on the first try: no-AI-attribution
(NOT a native Claude default — native adds Co-Authored-By), conventional type, imperative
subject, why-body, 72-char. Non-goal: does not push.

### ship — git-guardrails (Ship 5b)
Vote: LIVE x6. Enforces no-force-push, no-trunk-push, no-AI-attribution-in-PR, one-concern-per-PR.
PreToolUse hook blocks force-push mechanically; ship is the doctrine layer. Non-goal: does
not merge/close/triage.

### bootstrap — setup/scaffold
Vote: LIVE x6. Bun-for-TS / uv-for-Python opinionated defaults, non-interactive scaffolder
flags, quality-gate wiring, Spark lifecycle wiring. Without it Claude drifts to npm/pip.
Non-goals: does not implement features (build), does not manage secrets (connect).

### connect — setup/secrets
Vote: LIVE x6. Highest-specificity skill: 1Password op secret lifecycle
(capture -> ingest -> shred -> inject), propose-before-vault-write guardrail, spark
shred-env integration, smoke-test-before-shred. No native equivalent.

### codify — knowledge-capture (documentation: inward)
Vote: LIVE x6. 6-agent internal-knowledge crew (ADRs, SOPs, specs, glossary) with
intake barrier, specialist routing (architect/product/ops), facts-vs-assumptions discipline,
librarian dedup, Status26 glossary. No native equivalent. LANE LABEL CORRECTED to
KNOWLEDGE-CAPTURE, NOT CODING — see codifyVsBuild resolution. Explicit non-goal in file:
"don't touch application code."

### docit — documentation (outward)
Vote: LIVE x6. 13-persona outward-facing doc crew: ground-truth barrier, parallel drafts,
cross-eval dependency graph, Issue Council, Editor synthesis. No native equivalent.
Non-goals: does not write internal docs (codify), does not write agent contracts
(agents-md).

### agents-md — documentation (agent-behavioral contract)
Vote: LIVE x4 / MOVE x2. No native AGENTS.md equivalent (/init only writes CLAUDE.md).
Tool-agnostic behavioral contract; unique sync-audit (AGENTS.md vs CLAUDE.md drift).
The two MOVE votes (NE, MIN) want it merged WITH claude-md into a unified agent-contracts
skill — but they vote agents-md as the SURVIVOR of that merge, so agents-md LIVES either
way. It is the natural home for the consolidated behavioral-contract job if claude-md
is folded in (see DEADLOCK).

### agents/codify crew (6) — knowledge-capture
Vote: LIVE. Single artifact with codify. intake/architect/product/ops/editor/librarian
implement the knowledge-capture pipeline. Survives with codify.

### agents/docit crew (13) — documentation (outward)
Vote: LIVE. Single artifact with docit. Persona authors + Editor-in-Chief implement the
cross-eval/synthesis protocol. Survives with docit.

### bin/spark CLI — tooling
Vote: LIVE. All subcommands (doctor, list-skills, new-skill, install-git-hooks, shred-env,
help) are Spark-specific glue with no native equivalent. new-skill ABSORBS the authoring
checklist from the dying write-a-skill skill.

---

## MOVE (relocate job — destructive, needs human confirmation)

*(none reach a MOVE majority — claude-md is the only MOVE-leaning artifact and it tied; see DEADLOCK)*

---

## DIE (kill — reference native instead; destructive, needs human confirmation)

### grill-me — DIE x6 (unanimous)
Target: native grill-me skill. The Spark SKILL.md body and description are word-for-word
identical to the Claude-native grill-me skill already in the available-skills system prompt.
Zero Spark-specific value. ideate already invokes grill-me by name; that call resolves to
the native skill without a local copy. Migration: delete skills/grill-me/; ideate's
reference is unchanged (it names the skill, native provides it).

### write-a-skill — DIE x6 (unanimous)
Target: bin/spark new-skill + native skill authoring. Triple overlap: native skill authoring,
bin/spark new-skill (deterministic stub), and this skill's generic Anthropic-spec doctrine.
No Spark-specific authoring rule that cannot live in two sentences. Migration: fold the
authoring checklist (description-format rules, 100-line cap, progressive disclosure,
when-to-split) into bin/spark new-skill help text and/or a "Skill Authoring" section in
CLAUDE.md (which already exists). Delete skills/write-a-skill/.

### fork-init — DIE x6 (unanimous)
Target: plugin install model (/plugin install spark) + bootstrap (native git covers clone
mechanics). Architecturally obsolete: CLAUDE.md documents the install path as
/plugin install spark, not fork-as-upstream-seed. Draft/unimplemented (spark init does not
exist). Migration: document the plugin install path in bootstrap or docs/; delete
skills/fork-init/.

---

## DEADLOCK (human breaks the tie)

### claude-md — LIVE x3 (LW, DRY, PRES) / MOVE x3 (NE, LA, MIN)
Sides:
- LIVE (narrow-scope-in-place): claude-md owns a real Spark-doctrine MAINTENANCE job that
  native /init does not cover (/init creates; claude-md audits/patches/injects Spark required
  sections — attribution rules, GitHub guardrails, agent safety). Keep it as its own skill
  but NARROW the description from "generate and maintain" to "maintain and audit," explicitly
  deferring net-new creation to /init. Distinct file/audience from agents-md (Claude Code vs
  all agents).
- MOVE (consolidate into agents-md): claude-md and agents-md do the structurally identical
  job (maintain an AI-agent behavioral-contract file), share identical guardrail content,
  reference each other, and are both draft-only. One job, one place -> fold into a single
  unified behavioral-contract skill, agents-md as survivor, carrying claude-md's
  Spark-doctrine injection and the explicit /init deferral rule.

Both sides AGREE on two things regardless of the tie: (1) claude-md must NOT duplicate /init's
creation path — it defers creation to native /init; (2) agents-md LIVES. The only open
question is whether CLAUDE.md-maintenance is its own skill slot or a sub-capability of a
unified agent-contracts skill. Human call: keep two narrow skills, or merge into one.

---

## codify-vs-build resolution (Cluster E)

RESOLVED unanimously across all six seats in favor of **Option A** (Overlap Map's framing):

- **build owns CODING** (Generate, lifecycle stage 3). Unchanged.
- **codify owns KNOWLEDGE-CAPTURE** (internal docs: ADRs, SOPs, specs, glossary), lane label
  KNOWLEDGE/inward-documentation. Knowledge-capture STAYS with codify and its 6-agent crew.
- The author's law statement "codify = CODING" is a NAMING ERROR, not a functional directive.
  No file change supports codify=CODING; the files control. Acting on the literal law would
  destroy the knowledge-capture function with no replacement and create a true duplicate of
  build. Every seat declined to do this.
- ACTION FOR THE AUTHOR (non-destructive): amend the law's lane label so codify reads
  KNOWLEDGE-CAPTURE, not CODING. This is the only edit needed to make law and files agree.
  Surfaced to the human; the council does not rewrite the law itself.

Net: knowledge-capture lives in codify (inward docs). build is the sole CODING lane. No
collision remains once the label is corrected.

---

## Clean lane map (post-plan single-lane ownership)

- EXPLORATION (stage 1): ideate (references native grill-me)
- PLANNING (stage 2): plan
- CODING (Generate, stage 3): build
- SOLVE (stage 4): fix-issue (orchestrates native /code-review, /security-review, verify)
- SHIP (stage 5a commit): commit
- SHIP (stage 5b PR): ship
- QUALITY/AUDIT (breadth beyond native): review (security/correctness dims delegate to native)
- SETUP / SCAFFOLD: bootstrap
- SETUP / SECRETS: connect
- DOCUMENTATION / OUTWARD: docit (+13 agents)
- KNOWLEDGE-CAPTURE / INWARD DOCS: codify (+6 agents)
- DOCUMENTATION / AGENT-BEHAVIORAL CONTRACT: agents-md (AGENTS.md) [+ claude-md for CLAUDE.md
  pending DEADLOCK resolution; if merged, agents-md owns both]
- TOOLING: bin/spark CLI (new-skill absorbs skill-authoring doctrine)
- Skill authoring: bin/spark new-skill + native (no standalone skill)
- Interview/pressure-test: native grill-me (no Spark copy)
- Project inception: plugin install + bootstrap (no fork-init)

One job, one place achieved. Native referenced not reimplemented in: ideate (grill-me),
fix-issue (reviews/verify), review (delegating dims), commit/ship (git/gh), claude-md (/init),
skill authoring (new-skill + native).
