# DRY Auditor — Phase 2 Verdicts

Seat: The DRY Auditor. Law: one job, one place. Evidence over assertion.

---

## Governing Principles Applied

1. **Same job in more than one place is a defect.** Exact overlap = one survivor; the rest DIE or MOVE.
2. **Reference native; never reimplement.** If Claude Code ships the capability, a Spark skill must add Spark-specific value or DIE.
3. **Cluster E (codify-vs-build) resolution.** The author's law is read literally — `codify` = CODING is what the law *says*, but the *actual* codify file is a 6-agent KNOWLEDGE-CAPTURE crew that `build` cannot replace and that has no native equivalent. Reassigning codify to CODING while killing its crew destroys 6 agents of real value and leaves knowledge-capture homeless. The DRY resolution: the law's lane label is wrong, not the file. `build` already owns CODING (Generate). `codify` owns KNOWLEDGE-CAPTURE as a distinct, non-overlapping lane. The two do NOT duplicate each other. **Resolution: both LIVE; the law's lane assignment for codify must be corrected.**

---

## Verdicts by Cluster

### Cluster A — Skill Authoring

**`write-a-skill` → DIE**

The overlap is triple: (1) Anthropic's native skill spec tells Claude how to write skills without any custom skill; (2) `bin/spark new-skill` scaffolds the file tree deterministically; (3) `write-a-skill` adds a requirements-gathering conversation and structure coaching. The claimed distinction — "authoring doctrine" — is real in theory but the actual SKILL.md body is entirely generic Anthropic skill-spec content. There is zero Spark-specific doctrine in it: no reference to Spark's frontmatter rules, the 100-line cap is Anthropic's own guidance, and the description format rules are just the Anthropic spec restated. When someone invokes "write-a-skill" in a Spark context, `spark new-skill <name>` already stamps the scaffold, and the authoring checklist in the file is verbatim Anthropic guidance. The Spark-specific authoring rules that exist (`CLAUDE.md`: "scaffold with `spark new-skill`", "self-contained, no cross-skill imports") belong in CLAUDE.md + `bin/spark new-skill --help`, not in a parallel skill. Covered by: `bin/spark new-skill` + native skill authoring.

**`bin/spark new-skill` → LIVE**

The only non-redundant part of the cluster. Deterministic file scaffold is a real CLI job. Keep it.

---

### Cluster B — Behavioral Contract Files

**`claude-md` → LIVE (narrowed)**

`/init` handles net-new CLAUDE.md creation. Spark's value here is maintenance + Spark-doctrine injection (the 12-section schema, the attribution rule propagation, the scan-before-overwrite behavior). That is genuinely Spark-specific. However, the current SKILL.md still leads with "When to Create CLAUDE.md" as a primary use case, which duplicates `/init`. The duplication is in framing, not in function. The skill LIVES but must narrow its description scope to maintenance/update/audit; creation defers explicitly to `/init`. One job, one place — and this skill's one job is Spark-doctrine stewardship of an existing CLAUDE.md.

**`agents-md` → LIVE**

No native equivalent exists for AGENTS.md. The job (tool-agnostic behavioral contract that stays in sync with CLAUDE.md) is distinct, Spark-specific, and not covered by any Claude Code built-in. The sync-audit capability (compare AGENTS.md against CLAUDE.md, surface drift) is unique. LIVES.

---

### Cluster C — Review / QC

**`review` → LIVE (with internal fix required)**

The 8-agent review is genuinely broader than native `/code-review` + `/security-review`. The architecture, testing, product-readiness, and risk dimensions have no native equivalent. The breadth earns its slot. However, agents 03 (Code Quality) and 05 (Security) partially rerun what native `/code-review` and `/security-review` already do. The DRY fix: those two agent slots must explicitly dispatch the native skills rather than running their own analysis. This is not a kill — it is an internal fix the skill must apply. The overlap map correctly identifies this. LIVES with the fix noted.

**`fix-issue` → LIVE**

The gold-standard pattern for this codebase. Orchestrates native skills (`/code-review`, `/security-review`, `verify`) without reimplementing them. Adds real Spark value: triage discipline (must-fix / should-fix / out-of-scope), AC re-check as definition-of-done, scope guard ("new problems become new issues"). No duplication. LIVES.

---

### Cluster D — Interview / Pressure-Test

**`grill-me` → DIE**

The evidence is conclusive. Spark's `grill-me/SKILL.md` is word-for-word identical to the Claude-native `grill-me` skill in both the `description:` frontmatter field and the body. The native skill is already in the system prompt under available-skills. Spark's copy contributes zero Spark-specific value. `ideate` correctly invokes `grill-me` — it just needs to reference the native skill rather than a local file. The directory should be deleted. Covered by: Claude-native `grill-me` skill.

---

### Cluster E — Implementation / Coding

**`build` → LIVE**

Owns the Generate stage (lifecycle spine). The issue-scoped branch discipline, the AC-as-contract rule, the opportunistic-refactor guard, and the explicit handoff to `fix-issue` are all Spark-specific guardrails that Claude's raw coding ability doesn't enforce. LIVES.

**`codify` + `agents/codify/` crew (6) → LIVE**

The author's law says `codify` = CODING, but the actual file is a 6-agent KNOWLEDGE-CAPTURE crew (ADRs, SOPs, specs, glossary). This crew does NOT overlap with `build` (which writes application code, not internal docs). The law's lane label is a mis-assignment; the file's real job is distinct. Knowledge-capture via a specialist crew has no native Claude equivalent — Claude can write a doc, but the intake→specialist→editor→librarian pipeline with fact/assumption separation and the glossary-preservation rules is Spark-specific infrastructure. Collapsing this into `docit` (inward vs. outward) is tempting but wrong: the audiences, pipelines, and output types are different enough that unification would bloat docit and lose the fact-discipline protocol. The DRY auditor's ruling: no duplication exists between `codify` and `build`. Both LIVE. The council must correct the law's lane label, not kill the skill.

---

### Cluster F — Project Inception

**`fork-init` → DIE**

Three compounding problems:
1. `spark init` (Step 5) is explicitly documented as "not yet implemented." The skill is half-drafted against a CLI command that doesn't exist.
2. The current plugin model (`/plugin install spark`, documented in CLAUDE.md) supersedes the fork-upstream pattern entirely. The mental model "clone Spark, rename remote to upstream" conflicts with how Spark actually distributes itself today.
3. The skill's real job — "set up git remotes for a new project repo" — is a 5-command sequence that Claude Code can execute natively from a README. There is no Spark-specific crew, guardrail logic, or decision protocol here that requires a custom skill slot.

`bootstrap` covers the actual project-setup user journey (run scaffolder, add quality gates, wire Spark lifecycle). `fork-init` is an obsolete inception model for a delivery mechanism that has been superseded. Covered by: native git + `bootstrap` + plugin install model.

**`bootstrap` → LIVE**

The stack-scaffolder profile selection (Bun/uv, framework choice, quality gates) plus Spark wiring is concrete Spark-specific value. No native equivalent enforces the Bun/uv default, the non-interactive scaffolder flags, or the "verify the scaffold runs before moving on" gate. LIVES.

---

### Cluster G — Ship / Git Guardrails

**`commit` → LIVE**

The mechanical enforcement lives in `scripts/hooks/commit-msg` + `hooks/guard-bash.sh`. This skill's value is the doctrine layer: producing a passing message on the first attempt by knowing Spark's rules (conventional type, imperative mood, no AI attribution, why-body). This is non-trivial — without it, Claude would iterate against hook failures. Thin wrapper, but the wrapper carries real Spark-specific rules. LIVES.

**`ship` → LIVE**

Same reasoning. The force-push guard, no-trunk rule, one-concern-per-PR discipline, and no-AI-attribution in PR body are Spark-specific guardrail doctrine. Native `gh pr create` does none of this. The skill earns its slot by ensuring these rules are front-of-mind at push time. LIVES.

---

### Cluster H — Documentation (sub-lanes)

**`docit` + `agents/docit/` crew (13) → LIVE**

Owns the outward-facing documentation lane per author law. The multi-persona crew (ground-truth barrier → parallel drafts → cross-eval → revise → Issue Council → Editor synthesis) is Spark-specific infrastructure with no native equivalent. The persona-differentiation, cross-evaluation protocol, and Issue Council review step are all additive. LIVES.

No overlap with `codify` once the inward/outward split is respected. The lane boundary is: docit makes the world want the project; codify makes the team able to operate it.

---

### CLI (`bin/spark`)

**`doctor` → LIVE.** Plugin validation, manifest/hook JSON check, skill frontmatter linting. Spark-specific; no native equivalent.

**`list-skills` → LIVE.** Enumerates the installed skill set. Spark-specific.

**`new-skill` → LIVE.** Deterministic SKILL.md scaffold. The non-redundant core of Cluster A.

**`install-git-hooks` → LIVE.** Wires Spark's commit-msg and other git hooks. Spark-specific.

**`shred-env` → LIVE.** Secure-delete `.env` files; used by `connect`. Spark-specific.

**`help` → LIVE.** Standard CLI help.

---

## Summary Table

| Artifact | Verdict | Target / Covered By |
|---|---|---|
| `agents-md` | LIVE | — |
| `bootstrap` | LIVE | — |
| `build` | LIVE | — |
| `claude-md` | LIVE | narrow scope: maintenance/update/audit only; creation defers to `/init` |
| `codify` + `agents/codify/` | LIVE | — (law's lane label must be corrected; file is correct) |
| `commit` | LIVE | — |
| `connect` | LIVE | — |
| `docit` + `agents/docit/` | LIVE | — |
| `fix-issue` | LIVE | — |
| `fork-init` | DIE | native git + `bootstrap` + plugin install model |
| `grill-me` | DIE | Claude-native `grill-me` skill |
| `ideate` | LIVE | — |
| `plan` | LIVE | — |
| `review` | LIVE | (internal fix: agents 03+05 must delegate to native `/code-review`/`/security-review`) |
| `ship` | LIVE | — |
| `write-a-skill` | DIE | `bin/spark new-skill` + native skill authoring |
| `bin/spark` CLI | LIVE | all subcommands justified |

## Kill count: 3 (`grill-me`, `fork-init`, `write-a-skill`)
## Fix-in-place: 2 (`claude-md` scope narrowing; `review` agents 03+05 delegate to native)
## Law correction required: 1 (`codify` lane label in author's law; file is correct, law is wrong)
