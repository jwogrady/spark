# Lifecycle Architect — Phase 2 Vote

**Seat:** Lifecycle Architect  
**Lens:** Protect the Ideate→Plan→Generate→Solve→Ship spine. Skills are justified
only when they enforce Spark-specific guardrails or discipline the lifecycle in a
way Claude-native cannot. One job, one place. Reference native; do not reimplement.

---

## Governing Law Applied

1. **One job, one place.** Any skill whose job is already fully covered by another
   skill or a Claude-native capability dies or moves.
2. **Reference native, do not reimplement.** Claude already ships /code-review,
   /security-review, verify, git, gh, /init, grill-me. Custom skills that redo
   those jobs die.
3. **Lifecycle spine is load-bearing.** ideate, plan, build, fix-issue, commit,
   ship survive unless a specific violation of rule 1 or 2 forces a move.
4. **The codify-vs-build conflict.** The author's law assigns codify = CODING, but
   the actual codify file is KNOWLEDGE-CAPTURE and build already owns CODING
   (Generate stage). I resolve this as: the law statement is aspirational naming,
   not a directive to destroy the actual skill. The actual file evidence controls.
   codify = KNOWLEDGE-CAPTURE (LIVE, distinct lane). build = CODING (LIVE, Generate
   stage). They do not overlap today; the council must not manufacture a conflict
   where none exists in the code.

---

## Verdicts by artifact

### Lifecycle Spine (all LIVE — load-bearing)

**ideate** — LIVE. Stage 1. Turns fuzzy intent into a written problem statement.
Claude can brainstorm natively, but the Spark-specific discipline (one-screen
problem statement, success criteria, explicit non-goals, confirm before handoff to
plan) is not a Claude default. This constraint is the value.

**plan** — LIVE. Stage 2. Decomposes into GitHub issues using repo templates,
proposes a milestone, and enforces "confirm before creating." Native gh + Claude
can create issues, but the confirm-before-create guardrail and issue-template
discipline are Spark-specific. Without this skill, an agent would happily create
a dozen issues against wrong templates.

**build** — LIVE. Stage 3 (Generate). One-issue-per-branch discipline and
scope-to-AC enforcement are not native Claude defaults. Claude codes natively but
will happily wander into adjacent files and adjacent concerns. This skill holds
the fence.

**fix-issue** — LIVE. Stage 4 (Solve). This is the reference model for how every
skill should treat native capabilities: it explicitly orchestrates /code-review,
/security-review, and verify without reimplementing them, then adds triage
discipline + AC re-check. Perfect pattern. Keep as-is.

**commit** — LIVE. Stage 5a. The Spark commit-msg hook is Spark-specific
(no-AI-attribution, conventional type, imperative subject). This skill produces a
message that passes the hook on the first try. Without it, an agent's default
commit message will fail the hook and loop. The guardrail doctrine is the value.

**ship** — LIVE. Stage 5b. Enforces no-force-push, no-trunk, no-AI-attribution in
the PR body. Native gh pr create does none of that. Thin wrapper, real value.

---

### Knowledge and Documentation Skills

**codify** (+ agents/codify/ crew) — LIVE. KNOWLEDGE-CAPTURE lane. Distinct from
build (CODING) and docit (outward docs). Turns raw notes/decisions into ADRs,
SOPs, specs, glossary. The 6-agent crew (intake→specialist→editor+librarian) adds
structure and discipline Claude alone does not enforce. No native equivalent.
The "law redefines codify=CODING" instruction is irreconcilable with keeping build;
I read it as a naming error in the law, not an execution directive. The actual
file is clear. LIVE.

**docit** (+ agents/docit/ crew) — LIVE. DOCUMENTATION (outward). Multi-persona
public docs crew. Claude writes docs natively, but the persona orchestration,
parallel-draft/cross-evaluation/dependency-graph pattern, and barrier discipline
are not native. Outward lane is distinct from codify (inward). LIVE.

**claude-md** — MOVE into agents-md (or a unified agent-contracts skill). It is
draft-only and its creation scope directly duplicates native /init. The only
justified value is Spark-doctrine maintenance for an existing CLAUDE.md. That job
is structurally identical to what agents-md does for AGENTS.md. Two draft skills
doing adjacent "maintain a behavioral contract file" jobs should be one. If
unification is not done, claude-md must at minimum explicitly defer to /init for
creation and narrow its description to "maintenance only." Either way: one place.

**agents-md** — LIVE (as the receiver of the MOVE above, or standalone). No native
equivalent for AGENTS.md. Tool-agnostic behavioral contract is a real Spark value.
Draft status is not a kill reason — it documents behavior that will be implemented.

---

### Setup / Inception Skills

**bootstrap** — LIVE. SETUP lane. Bun/uv profile defaults, non-interactive
scaffolder flags, quality gate wiring — none of this is a Claude default. Real
project-specific value. Not duplicated elsewhere.

**connect** — LIVE. SETUP lane. 1Password secret lifecycle (capture → ingest via
op → shred plaintext via spark shred-env → inject at runtime) is entirely
Spark-specific. No native equivalent. The shred-env integration is a hard
dependency that makes this irreplaceable.

**fork-init** — DIE. Architecturally obsolete. CLAUDE.md documents the install
model as "/plugin install spark," not "fork Spark as upstream seed." This skill
describes a workflow that conflicts with the plugin model. It is draft/unimplemented
and has never shipped. Its documented job (clone Spark, wire upstream remote) is
covered by standard git commands any developer runs once. No Spark-specific
guardrail value. Kill it; document the plugin install path in bootstrap or docs/.

---

### Quality and Review Skills

**review** — LIVE. The 8-agent multi-dimension audit (architecture, testing, docs,
product readiness, risk) genuinely extends beyond what native /code-review and
/security-review cover. Those native skills handle correctness and security; review
adds the breadth dimensions they do not touch. One fix required: the security and
code-quality agent dimensions must explicitly delegate to native /code-review and
/security-review rather than re-running the same analysis. That edit keeps review
clean. LIVE with that constraint.

---

### Utilities and Overlapping Skills

**grill-me** — DIE. Verbatim duplicate of the Claude-native grill-me skill.
Identical description, identical trigger language, identical body. Zero Spark-specific
value. ideate correctly calls grill-me; after this skill dies, ideate references
the native skill directly. The skills directory in Spark should not carry a copy
of something the platform ships natively.

**write-a-skill** — DIE. Triple overlap: Claude-native skill authoring, bin/spark
new-skill CLI (deterministic stub), and this skill. The CLI handles file creation.
The authoring doctrine (description format rules, 100-line limit, progressive
disclosure) should live as a section in CLAUDE.md (or an update to bin/spark
new-skill help text), not as a standalone skill. write-a-skill is generic —
it adds no Spark-specific value beyond what the CLI scaffolder already provides
plus what Claude can do natively. Kill it; fold the doctrine into CLAUDE.md's
Skill Authoring section.

---

### CLI (bin/spark)

**bin/spark as a whole** — LIVE. doctor, list-skills, install-git-hooks, shred-env
are Spark-specific glue that have no native equivalent. LIVE.

**bin/spark new-skill** — LIVE. Deterministic file scaffolding. No skill should
replace it; write-a-skill should die and defer here. Complement with brief
authoring doctrine in CLAUDE.md, not a separate skill.

---

## Resolution of the Cluster E (codify-vs-build) Blocking Decision

I resolve by evidence over law:

- The actual codify SKILL.md is unambiguously KNOWLEDGE-CAPTURE. It has a 6-agent
  crew purpose-built for that job. It is not, and has never been, a coding tool.
- The actual build SKILL.md is unambiguously CODING (Generate stage). It is a
  load-bearing spine element.
- The author's law statement ("codify = CODING") is not backed by any file change.
  The files have not been updated to reflect this intent.
- Reassigning codify = CODING without killing build violates "one job, one place."
  Killing build to give codify the CODING job would destroy a spine element with
  no gain. Killing codify's knowledge-capture function leaves a real capability
  (internal docs) with no home.
- **Verdict:** Keep codify = KNOWLEDGE-CAPTURE. Keep build = CODING. The law as
  stated re: codify is a naming conflict, not an implementation directive. Council
  should surface this to the author for clarification rather than acting on it
  destructively.

---

## Summary Table

| artifact | verdict | reason |
|---|---|---|
| ideate | LIVE | Stage 1 spine; problem-statement discipline is Spark-specific |
| plan | LIVE | Stage 2 spine; confirm-before-create + template discipline |
| build | LIVE | Stage 3 spine; one-issue/one-branch discipline |
| fix-issue | LIVE | Stage 4 spine; reference model for native orchestration |
| commit | LIVE | Stage 5a; Spark commit-msg hook doctrine |
| ship | LIVE | Stage 5b; no-force/no-trunk/no-AI guardrail doctrine |
| codify + crew | LIVE | KNOWLEDGE-CAPTURE lane; no native equivalent |
| docit + crew | LIVE | OUTWARD DOCS lane; persona crew not native |
| claude-md | MOVE → agents-md | Draft-only; creation duplicates /init; job is identical to agents-md |
| agents-md | LIVE | No native AGENTS.md equivalent; receives claude-md |
| bootstrap | LIVE | Bun/uv profile defaults; Spark-specific quality gates |
| connect | LIVE | 1Password secret lifecycle; spark shred-env integration |
| fork-init | DIE | Obsolete under plugin model; draft/unimplemented; standard git covers it |
| review | LIVE | Breadth (arch/test/docs/product/risk) beyond native reviews |
| grill-me | DIE | Verbatim duplicate of Claude-native grill-me |
| write-a-skill | DIE | Triple overlap: native + CLI + this; no Spark-specific value |
| bin/spark CLI | LIVE | doctor/shred-env/install-git-hooks are Spark-specific glue |
