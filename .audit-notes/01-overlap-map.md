# Phase 1 — Overlap Map

DRY Cartographer. Every cluster where two or more artifacts (or an artifact + a
Claude-native capability) do the SAME job. Evidence sourced from actual SKILL.md
files and bin/spark.

---

## Cluster A — Skill Authoring (triple overlap)

**The job:** Create a new Spark skill (stub SKILL.md, correct structure/frontmatter).

**Overlapping artifacts:**
- `skills/write-a-skill/SKILL.md` — AI-guided skill authoring; gathers requirements,
  drafts SKILL.md + optional reference files, reviews with user.
- `bin/spark new-skill <name>` — CLI scaffold; stamps out a minimal, correctly-formed
  `skills/<name>/SKILL.md` in one command.
- Claude-native skill authoring — Anthropic's plugin spec already describes how to
  write skills; Claude Code can produce a SKILL.md from scratch without either of
  the above.

**Key distinction:** `bin/spark new-skill` creates the file tree (deterministic,
fast). `write-a-skill` AI-guides a *design conversation* (requirements, structure
coaching, description quality, when-to-split, review checklist). They are adjacent
but not identical: CLI = file creation, skill = authoring doctrine.

**Natural home:** The deterministic creation step stays in `bin/spark new-skill`
(already correct). The authoring doctrine layer (`write-a-skill`) adds Spark-specific
guidance (description format rules, 100-line limit, progressive disclosure, when-to-split)
that neither the CLI stub nor raw Claude-native capability enforces. However, because
`write-a-skill` is generic (it doesn't reference Spark conventions beyond what
`new-skill` already stamps), it should be evaluated for collapse into `bin/spark
new-skill` help text + a short "Spark skill authoring" section inside `claude-md`
doctrine, or consolidated as a thin Spark-doctrine layer that explicitly wraps
`spark new-skill`. **Verdict: candidate for death or radical thinning.**

---

## Cluster B — CLAUDE.md / AGENTS.md Authoring (twin skills + native /init)

**The job:** Produce (or maintain) the CLAUDE.md and AGENTS.md behavioral contract
files for a project repo.

**Overlapping artifacts:**
- `skills/claude-md/SKILL.md` — generates and maintains CLAUDE.md; injects Spark
  doctrine. Status: Draft — runtime not yet implemented.
- `skills/agents-md/SKILL.md` — generates and maintains AGENTS.md. Status: Draft
  — runtime not yet implemented.
- Claude-native `/init` — the native CLAUDE.md initializer; creates CLAUDE.md on
  demand.

**Key distinction:** `/init` handles creation; `claude-md` adds Spark-doctrine
maintenance (keeping Spark conventions baked in). `agents-md` has no native
equivalent at all. The twins share the "behavioral contract maintenance" job and
reference each other explicitly ("both files should stay in sync").

**Natural home:** `claude-md` can stay but must shrink its creation scope to
"maintenance + Spark doctrine injection" and explicitly defer to `/init` for net-new
creation. `agents-md` is justified (no native equivalent). Both are DOCUMENTATION
(agent-config) lane. However they are so structurally identical in job (one file per
skill, both draft-only) that a unified `agent-contracts` skill that owns *both*
CLAUDE.md and AGENTS.md as a single authoring surface is worth considering. **Verdict:
`claude-md` must narrow scope; `agents-md` justified; unification optional but clean.**

---

## Cluster C — Review / QC (partial overlap with native)

**The job:** Assess code quality, correctness, security, and broader project health.

**Overlapping artifacts:**
- `skills/review/SKILL.md` — 8 sequential specialist agents (00–07 + Synthesis Lead
  08) covering architecture, code quality, testing, security, docs, product readiness,
  risk. Shares `.review-notes/` pattern with docit. Harsh-but-fair 1–10 scoring.
- `skills/fix-issue/SKILL.md` — Stage 4 solve loop; explicitly orchestrates
  `/code-review`, `/security-review`, and `verify`; triages findings; fixes until AC
  hold. The *good pattern*: references native, doesn't reimplement.
- Claude-native `/code-review` — single-pass correctness/reuse/simplification/efficiency.
- Claude-native `/security-review` — single-pass vulnerability assessment.

**Key distinction by axis:**
- Security + correctness axes: native `/code-review` + `/security-review` cover these.
  `review` runs the same axes as *two of its eight agents* (agents overlap native).
- Architecture, testing, docs, product, risk axes: no native equivalent; `review`
  genuinely adds breadth.
- `fix-issue` uses native correctly and adds triage/scope discipline + AC re-check;
  no overlap problem.

**Natural home:** `fix-issue` is clean — keep as-is (it IS the reference model).
`review` partially duplicates native on the security/correctness dimensions; its
specialist agents for those two dimensions should explicitly delegate to `/code-review`
and `/security-review` rather than re-run the same analysis. The breadth (arch/test/docs/
product/risk) is irreplaceable. **Verdict: `review` keeps its lane; the 2 overlapping
agent dimensions must reference native. `fix-issue` is correct as-is.**

---

## Cluster D — Interview / Pressure-Test (near-verbatim duplication)

**The job:** Interview the user relentlessly to stress-test a plan, design, or idea.

**Overlapping artifacts:**
- `skills/grill-me/SKILL.md` — body is a single paragraph: "Interview me relentlessly
  about every aspect of this plan… Ask the questions one at a time… If a question can
  be answered by exploring the codebase, explore it instead."
- Claude-native `grill-me` skill — appears verbatim in the available-skills system
  prompt with the identical description and identical trigger language ("Use when user
  wants to stress-test a plan, get grilled on their design, or mentions 'grill me'").

**Key distinction:** There is none. Spark's `grill-me` SKILL.md body is the *source*
of the native skill (or a duplicate of it). The description field is word-for-word
identical to the native available-skill entry. Spark adds zero Spark-specific value
here.

**Natural home:** `ideate` correctly *calls* grill-me. The native skill handles the
interview. Spark's copy of grill-me is dead weight. **Verdict: KILL Spark's
`grill-me` skill. Reference native. `ideate` continues to invoke it.**

---

## Cluster E — Implementation / Coding (the author-law collision)

**The job:** Implement planned work as code on a feature branch.

**Overlapping artifacts:**
- `skills/build/SKILL.md` — Stage 3 (Generate) of the lifecycle spine. Implements
  exactly one GitHub issue, scoped to AC, on a feature branch.
- `skills/codify/SKILL.md` — *Current actual job:* INTERNAL KNOWLEDGE CAPTURE (ADRs,
  SOPs, specs, glossary entries) via a 6-agent crew. Not coding.
- `agents/codify/` crew (6 agents) — intake → architect/product/ops → editor + librarian
  for knowledge-capture.
- Author's new law — redefines `codify` = CODING/IMPLEMENTATION lane, which directly
  collides with `build`.

**The conflict, stated plainly:** The author's law says `codify` should own CODING,
but:
  1. The actual `codify` file owns KNOWLEDGE-CAPTURE, not coding.
  2. CODING is already owned by `build` (lifecycle stage 3).
  3. The law cannot be satisfied by reassigning `codify` = CODING without either
     (a) killing `build` and migrating its job to `codify`, or
     (b) killing `codify`'s current knowledge-capture job and finding it a new home.

**The unresolved fork (council must choose one):**
- **Option A — Keep codify = knowledge-capture, rename its lane.** Build owns CODING.
  Codify's lane is KNOWLEDGE (not CODING). Law is amended. 6-agent crew survives.
- **Option B — Repurpose codify = CODING, kill build.** Codify takes over Generate
  stage. Knowledge-capture crew is disbanded or migrated (to docit as an inward-docs
  subdomain, or killed). Lifecycle spine now reads Ideate→Plan→Codify→Solve→Ship.
- **Option C — Kill both codify and build, reference Claude-native coding.** Claude
  codes natively; neither custom skill adds enough Spark-specific value to justify the
  slot. Lifecycle becomes: Ideate→Plan→[native code]→Solve→Ship.

**Natural home under current files:** `build` already owns CODING per the lifecycle
spine. `codify` already owns KNOWLEDGE-CAPTURE with a distinct crew. Neither is
redundant with the other today. The author's law creates a collision that does not
currently exist in the files. **Verdict: BLOCKED — council must resolve the law
vs. current files before any verdict on this cluster.**

---

## Cluster F — Project Inception (partial overlap)

**The job:** Start a brand-new project repo wired into Spark.

**Overlapping artifacts:**
- `skills/fork-init/SKILL.md` — clone Spark as upstream seed, wire downstream repo.
  Draft — runtime not yet implemented.
- `skills/bootstrap/SKILL.md` — run the stack scaffolder (Bun/uv), add quality gates,
  wire Spark lifecycle. Fully specified (not draft).
- These are sequential, not competing: `fork-init` first (git topology), then
  `bootstrap` (runtime scaffold). But both answer "how do I start a new project."

**Natural home:** SETUP/INCEPTION lane. They are complementary phases of the same
user journey (inception → scaffold), not overlapping. However, `fork-init` is
draft/unimplemented and its premise (forking Spark as upstream seed) conflicts with
the current "plugin install" model documented in CLAUDE.md ("install it with
`/plugin install spark`"). **Verdict: no functional overlap today; `fork-init` may
be architecturally obsolete given the plugin model — flag for council.**

---

## Cluster G — Ship / Git Guardrails (thin wrappers over native)

**The job:** Commit changes and push/PR them safely.

**Overlapping artifacts:**
- `skills/commit/SKILL.md` — stage + write a conventional commit obeying the
  commit-msg hook (no AI attribution, imperative subject, why-body).
- `skills/ship/SKILL.md` — push branch + open one focused PR, enforcing no-force-push
  / no-trunk / no-AI-attribution.
- Claude-native git + gh — Claude can run `git commit` and `gh pr create` natively.
- `hooks/guard-bash.sh` + `scripts/hooks/commit-msg` — the *mechanical* enforcement
  layer.

**Key distinction:** The hooks enforce the rules mechanically. `commit` and `ship`
are the *doctrine* layer: they tell Claude *why* the guardrails exist and how to
produce a passing message the first time rather than iterating against hook failures.
The value is not replicating native git — it is Spark-specific guardrail doctrine
(no-AI-attribution, conventional type enforcement, no-force-push, no-trunk push).

**Natural home:** SHIP lane. Both justified. Neither duplicates native beyond
what the guardrail doctrine requires. **Verdict: keep both; confirm no AI-attribution
wording is Spark-specific and not a native Claude default.**

---

## Cluster H — Writing / Documentation (inward vs outward, with lane bleeding)

**The job:** Write documentation for the project.

**Overlapping artifacts:**
- `skills/docit/SKILL.md` + `agents/docit/` crew (13) — outward-facing public docs
  (README, positioning, launch copy). DOCUMENTATION lane per law.
- `skills/codify/SKILL.md` + `agents/codify/` crew (6) — inward-facing knowledge docs
  (ADRs, SOPs, specs). Also DOCUMENTATION, but internal.
- `skills/claude-md/SKILL.md` — CLAUDE.md = behavioral contract doc. Agent-config
  documentation.
- `skills/agents-md/SKILL.md` — AGENTS.md = behavioral contract doc. Agent-config
  documentation.
- Claude-native doc writing — Claude writes any document natively without a skill.

**Key distinction:** docit = outward (marketing, developer adoption), codify =
inward (team knowledge, decisions), claude-md/agents-md = agent-behavioral contracts.
All three sub-lanes are genuinely distinct audiences. The overlap is not in the output
type but in the raw operation ("produce a document"). Each adds Spark-specific value:
docit adds persona crew + cross-evaluation; codify adds specialist crew + fact/assumption
discipline; claude-md/agents-md add Spark doctrine injection.

**Natural home:** Three distinct sub-lanes within DOCUMENTATION. No kill candidates
here, but the law's instruction to assign `codify` = CODING would collapse the inward-docs
lane with no replacement — another consequence of the Cluster E conflict. **Verdict:
all four justified in their sub-lanes IF codify stays = KNOWLEDGE-CAPTURE.**

---

## Summary Table

| Cluster | Job | Artifacts in conflict | Verdict |
|---|---|---|---|
| A | Skill authoring | `write-a-skill` ↔ `spark new-skill` ↔ native | `write-a-skill` candidate for death/radical thinning |
| B | Behavioral-contract files | `claude-md` ↔ native `/init` | `claude-md` must narrow to maintenance only; `agents-md` justified |
| C | Code/project QC | `review` ↔ native `/code-review` + `/security-review` | `review` keeps breadth; 2 overlapping agent dimensions must delegate to native |
| D | Interview / pressure-test | `grill-me` (Spark) ↔ native `grill-me` | **KILL** Spark's `grill-me`; reference native |
| E | Implementation | `build` ↔ `codify` (via law) | **BLOCKED** — council must resolve law vs files before verdict |
| F | Project inception | `fork-init` ↔ `bootstrap` | Complementary, not overlapping; `fork-init` may be architecturally obsolete |
| G | Commit + push safely | `commit` + `ship` ↔ native git/gh | Both justified by Spark guardrail doctrine |
| H | Documentation (all sub-lanes) | `docit` / `codify` / `claude-md` / `agents-md` | All four justified IF codify stays = KNOWLEDGE-CAPTURE |

---

## The One Unambiguous Kill

**`skills/grill-me/`** — Spark's copy is a verbatim duplicate of the Claude-native
`grill-me` skill (identical description, identical trigger, body is a single generic
paragraph). Zero Spark-specific value. `ideate` should reference native `grill-me`
directly. File the directory for deletion.

## The One Unambiguous Fix

**`skills/claude-md/`** — must explicitly defer to `/init` for net-new CLAUDE.md
creation. Its scope is maintenance + Spark-doctrine injection only. The description
should be updated to say so.

## The Blocking Decision

**Cluster E (codify-vs-build)** cannot be resolved by the Cartographer. The author's
law creates a collision with the actual file content that forces a binary choice about
the lifecycle spine itself. This must go to the council as the first order of business
in Phase 2.
