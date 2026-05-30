# Lane Warden — Phase 2 Verdicts

Seat: The Lane Warden. Enforce one lane per artifact, explicit non-goals.
Law: docit=DOCUMENTATION, build=CODING/IMPLEMENTATION, ideate=EXPLORATION.
Rule: one job, one place; reference native, never reimplement.

---

## The Blocking Decision First: codify-vs-build

The author's governing law assigns:
- docit = DOCUMENTATION lane
- codify = CODING/IMPLEMENTATION lane
- ideate = EXPLORATION lane

The actual `codify` file is an internal-knowledge-capture crew (ADRs, SOPs,
specs, glossary). It does NOT code. CODING is already owned by `build` (Generate
stage). The author's law as stated creates a direct collision: two artifacts
cannot share the CODING lane (codify + build) without one dying.

My ruling as Lane Warden: the law's lane label for `codify` is wrong relative to
what `codify` actually does, and the council must not kill a working artifact to
satisfy a mislabeled lane. The resolution is:

  - `build` owns CODING/IMPLEMENTATION. Full stop.
  - `codify` owns KNOWLEDGE-CAPTURE (internal documentation). This is a
    legitimate distinct lane — it is not CODING and it is not OUTWARD DOCS.
  - The three named lanes expand to four: docit=OUTWARD-DOCS,
    codify=KNOWLEDGE-CAPTURE, build=CODING, ideate=EXPLORATION.

This is not a law amendment; it is a precision fix. The author's intent was clearly
to name three pillars, not to collapse knowledge-capture into nothing.

---

## Verdict Table

### grill-me — DIE

Lane: exploration (but belongs to native, not Spark).

The SKILL.md body is identical in substance and description to the Claude-native
`grill-me` skill listed in the system prompt. Description field matches verbatim.
Body is three generic sentences that add nothing Spark-specific. `ideate` calls it
correctly by name — that invocation should reference the NATIVE skill, not a Spark
copy. Zero project-specific value. Zero Spark guardrails added.

Covered by: Claude-native `grill-me`.

---

### write-a-skill — DIE

Lane: setup/tooling (but completely duplicates native + CLI).

The skill teaches generic Anthropic skill authoring format (SKILL.md structure,
description rules, when-to-split). Every rule in this file is either:
  (a) already enforced by `spark new-skill` (which stamps a correctly-formed stub),
  (b) already covered by Anthropic's published plugin spec (which Claude knows), or
  (c) generic advice (100-line limit, progressive disclosure) with no Spark-specific
      guardrail.

This skill has no lane-exclusive value. It neither enforces Spark doctrine not
captured elsewhere, nor does it own a lifecycle stage. `spark new-skill` is the
right home for the scaffolding operation; Anthropic's spec is the right home for
authoring doctrine. Keeping this creates a third place where the same authoring
rules live (skill file, CLI help, Anthropic spec) — a direct violation of "one
job, one place."

Covered by: `spark new-skill` CLI + Claude-native skill authoring knowledge.

---

### claude-md — LIVE (with lane correction)

Lane: documentation (agent-config sub-lane).

`claude-md` owns one specific job native `/init` does NOT: maintain and inject
Spark doctrine into an existing CLAUDE.md. `/init` creates; this skill audits,
patches, and enforces Spark-specific section requirements (attribution rules,
GitHub guardrails, agent safety rules). Those sections are Spark-specific, not
part of any native capability.

Lane assignment: DOCUMENTATION, agent-config sub-lane. Non-goals must be made
explicit: this skill does NOT create CLAUDE.md from scratch (that is `/init`'s
job). The description must be updated to say "maintain and audit" not "generate."

Status is Draft/not-yet-implemented — that is a build concern, not a lane
concern. Lane is correct.

---

### agents-md — LIVE

Lane: documentation (agent-config sub-lane, tool-agnostic).

No native equivalent exists for AGENTS.md generation or maintenance. The skill's
job — produce and keep in sync the tool-agnostic behavioral contract — is a
distinct output from CLAUDE.md (different audience: all agents, not just Claude
Code). The sync-audit capability (compare AGENTS.md vs CLAUDE.md to find drift) is
unique.

Twin of `claude-md` and complementary, not redundant. Different lane sub-slot
(tool-agnostic vs Claude-specific). Both justified.

---

### bootstrap — LIVE

Lane: setup (project inception, runtime scaffold).

Single job: run the official scaffolder (Bun/uv) non-interactively with
Spark-opinionated defaults and wire the Spark lifecycle on top. No native
equivalent does this with Spark's specific framework matrix and quality-gate
wiring. The profiles.md reference file captures per-framework commands that would
otherwise be re-derived on every use.

Clear non-goals: does not implement features (that is `build`), does not manage
secrets (that is `connect`). Lane is clean.

---

### connect — LIVE

Lane: setup (secrets/connectivity sub-lane).

Unique job: 1Password op-CLI secret lifecycle (capture → ingest → shred → inject).
No native Claude capability covers the `op item create` / `spark shred-env` /
smoke-test-before-shred flow. Strong Spark-specific value (the shred-env CLI
integration alone justifies it). Clean single lane.

---

### fork-init — DIE

Lane: setup (project inception) — but architecturally obsolete.

The skill's premise is "clone Spark as upstream seed and wire a downstream project."
CLAUDE.md explicitly documents that the current install model is `/plugin install
spark` — not forking the repo. `fork-init` documents a workflow that predates the
plugin model and whose central command (`spark init`) is explicitly "not yet
implemented." It overlaps `bootstrap` in the "how do I start a project" user
journey without adding anything `bootstrap` + the plugin install path does not
already cover.

This is not a lane-bleed kill; it is an architectural-obsolescence kill. The lane
(setup) is correct; the artifact is a dead-end path to the same destination.

Covered by: plugin install model + `bootstrap`.

---

### ideate — LIVE

Lane: exploration (owns ideate stage of lifecycle spine).

Sole owner of Stage 1: turn fuzzy idea into a written problem statement with
success criteria, non-goals, and constraints. No native capability enforces the
"no code, no file layout, no tickets yet" discipline or the problem-statement
format. Correctly delegates to native `grill-me` for pressure-testing (once the
Spark copy dies).

Non-goals explicit in the file: no code, no solution, no tech choice. Lane is
clean.

---

### plan — LIVE

Lane: planning (owns plan stage of lifecycle spine).

Sole owner of Stage 2: decompose problem statement into GitHub-ready issues using
Spark's issue templates, scoped to AC, confirm-before-create guardrail. The
guardrail (no GitHub writes without explicit user instruction) is Spark-specific
doctrine not enforced by native `gh` or Claude's default behavior. Issue-template
discipline adds real value.

Lane: planning. Non-goal: does not implement (that is `build`). Clean.

---

### build — LIVE

Lane: coding/implementation (owns Generate stage of lifecycle spine).

Sole owner of Stage 3: implement exactly one issue, scoped to its AC, on a feature
branch. The one-issue-per-branch, no-opportunistic-refactor, and self-check-against-
criteria disciplines are Spark-specific guardrails not enforced natively. Claude
can code without this skill but will not apply Spark's branch and scope discipline.

Lane: coding/implementation. No collision with codify (which writes docs, not code).
Clean.

---

### fix-issue — LIVE

Lane: solve (owns Solve stage of lifecycle spine).

This skill is the GOOD PATTERN the whole repo should emulate. It explicitly
orchestrates `/code-review`, `/security-review`, and `verify` — it does NOT
reimplement them. Its project-specific value is the triage discipline (must-fix /
should-fix / out-of-scope) and the AC re-verification loop. That discipline is
Spark-specific and not covered by any native pass.

Lane: solve. Non-goal: does not run its own reviewer (explicitly delegates to
native). Clean.

---

### review — LIVE (with partial lane fix required)

Lane: solve/QC (broad multi-dimensional audit, distinct from fix-issue's per-issue
scope).

`review` spans 8 dimensions: architecture, code quality, testing, security,
documentation, product readiness, risk. Native `/code-review` and `/security-review`
cover correctness+security — two of the eight. The other six (architecture, testing
quality, docs coverage, product readiness, risk assessment) have no native
equivalent.

Lane bleed: agents 03 (Code Quality) and 05 (Security) overlap native passes.
These two agents must explicitly reference `/code-review` and `/security-review`
rather than duplicating the analysis. The breadth agents (00, 01, 02, 04, 06, 07,
08) are unjustifiable anywhere else.

Lane: solve/QC. Requires narrowing: agents 03 and 05 must delegate to native,
not re-run independently.

---

### commit — LIVE

Lane: ship (conventional commit with Spark guardrails).

The value is not git itself — it is enforcing Spark's commit-msg hook rules the
FIRST time (no AI attribution, conventional type, imperative subject, why-body).
This prevents the friction loop of committing → hook rejection → re-commit. The
no-AI-attribution rule is a Spark-specific departure from Claude's default
`Co-Authored-By` behavior.

Lane: ship (5a). Thin but justified. Non-goal: does not push (that is `ship`).
Clean.

---

### ship — LIVE

Lane: ship (push + PR with Spark guardrails).

Value: no-force-push, no-trunk-push, no-AI-attribution-in-PR, one-concern-per-PR
discipline. The PreToolUse hook blocks force-push mechanically; this skill teaches
Claude WHY and produces a passing PR body the first time. No native `gh` invocation
enforces Spark's PR attribution rules.

Lane: ship (5b). Non-goal: does not merge, close, or triage (that is the human's
call). Clean.

---

### codify — LIVE (with lane label correction)

Lane: knowledge-capture (internal documentation, inward-facing).

`codify` owns the job of turning raw founder notes, session discoveries,
architecture decisions, and operational knowledge into durable internal docs (ADRs,
SOPs, specs, glossary). No native equivalent orchestrates a six-specialist crew
with fact/assumption discipline and a configurable glossary. The separation between
current-state and intended-state, the uncertainty-marking rule, and the status26
vocabulary preservation are all Spark/Status26-specific value.

This is NOT CODING. The lane name in the author's law must be corrected:
codify = KNOWLEDGE-CAPTURE, not CODING. Build = CODING.

The codify crew (6 agents) is treated as one artifact with the skill. Both LIVE.

Non-goals explicit in the skill: "Don't touch application code — codify writes
docs." Clean lane boundary with `build`.

---

### docit + agents/docit/ crew (13 agents) — LIVE

Lane: documentation (outward-facing public docs).

Sole owner of the outward-facing documentation job: README, positioning, launch
copy, philosophy, Diátaxis docs. The multi-persona crew with cross-evaluation,
honest-hype enforcement, and Issue Council produces output quality that raw Claude
doc-writing cannot replicate without this orchestration. 13 agents is justified by
the 13 distinct reader-perspective jobs they each own exclusively.

Lane: documentation. Non-goal: does not write internal docs (that is `codify`),
does not write agent-behavioral contracts (that is `claude-md`/`agents-md`). Clean.

---

### bin/spark (CLI) — LIVE

The CLI subcommands each have a distinct job:
- `doctor` — validates plugin layout, manifest, hook JSON, skill frontmatter.
  No native equivalent. LIVE.
- `list-skills` — lists installed skills. LIVE (tooling convenience).
- `new-skill` — scaffolds a new skill stub. LIVE. This is the ONLY place that does
  mechanical skill creation. `write-a-skill` skill must die to give this sole
  ownership.
- `install-git-hooks` — wires Spark's commit-msg + pre-commit hooks. LIVE
  (Spark-specific).
- `shred-env` — secure-deletes a plaintext .env after 1Password ingestion. LIVE
  (used by `connect`; no native equivalent).
- `help` — LIVE.

No CLI subcommand is duplicated by a surviving skill after this audit. Clean after
`write-a-skill` dies.

---

## Summary

| artifact | verdict | reason |
|---|---|---|
| grill-me | DIE | verbatim native duplicate; zero Spark-specific value |
| write-a-skill | DIE | triple duplication (native + CLI + Anthropic spec); no Spark-specific value |
| fork-init | DIE | architecturally obsolete (plugin model replaced it); central command unimplemented |
| claude-md | LIVE | Spark-doctrine maintenance lane; must narrow description to "maintain/audit", not "generate" |
| agents-md | LIVE | no native equivalent; distinct tool-agnostic sub-lane |
| bootstrap | LIVE | Spark-opinionated scaffold + lifecycle wiring; no native equivalent |
| connect | LIVE | 1Password secret lifecycle + shred-env; no native equivalent |
| ideate | LIVE | sole owner of EXPLORATION stage; clean lane |
| plan | LIVE | sole owner of PLAN stage + confirm-before-create guardrail; clean lane |
| build | LIVE | sole owner of CODING lane + scope discipline; clean lane |
| fix-issue | LIVE | good-pattern native-reference model; triage + AC discipline |
| review | LIVE | breadth agents unjustifiable elsewhere; agents 03+05 must delegate to native |
| commit | LIVE | Spark guardrail doctrine (no-AI-attribution); justified thin wrapper |
| ship | LIVE | Spark guardrail doctrine (no-force-push, no-trunk, no-AI-attribution in PR) |
| codify | LIVE | KNOWLEDGE-CAPTURE lane (not CODING); crew justified; build = CODING |
| docit + crew | LIVE | sole OUTWARD-DOCS owner; crew depth justified by 13 reader perspectives |
| bin/spark | LIVE | all subcommands justified; `new-skill` gains sole ownership after write-a-skill dies |
