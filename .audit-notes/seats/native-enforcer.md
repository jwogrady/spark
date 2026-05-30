# Native Enforcer — Audit Verdicts

Seat question: Does Claude Code already do this job natively?
Bias: Delete anything that reimplements a built-in unless it adds enforcement of
Spark's own guardrails that native lacks.

---

## Verdicts by artifact

### grill-me — DIE
The Spark SKILL.md body is a single paragraph that is word-for-word identical to
the native `grill-me` skill that ships in the Claude Code available-skills system
prompt. Same description, same trigger language, same single-paragraph body with
the codebase-exploration addendum. Spark adds zero Spark-specific value. `ideate`
already calls it by name; that call works against the native skill without a local
copy. File the directory for deletion; update `ideate` to reference native directly
(the current wording "invoke the grill-me skill" already works natively).

### write-a-skill — DIE
Claude Code can produce a SKILL.md from a description without a skill. `spark
new-skill <name>` already stamps out the correct file skeleton deterministically.
The `write-a-skill` SKILL.md adds a generic requirements-gathering conversation
(no Spark-specific doctrine beyond the file structure the CLI already stamps).
The 100-line guidance and progressive-disclosure rules should live in
`claude-md` doctrine or `bin/spark new-skill` help text, not a separate skill
slot. Triple overlap (native + CLI + skill) with zero Spark-guardrail value.

### claude-md — MOVE → agents-md (unified as a single behavioral-contract skill)
The creation path duplicates native `/init`. Spark's only defensible value here is
maintenance + Spark-doctrine injection. Both `claude-md` and `agents-md` do the
same structural job (generate/maintain a behavioral-contract file) for
sister files that the skill itself says "should stay in sync." Maintaining two
near-identical draft skills with identical status ("runtime not yet implemented")
violates the one-job-one-place rule at the skill level. Consolidate into one
`agent-contracts` skill (or keep `agents-md` as the survivor since it has no
native overlap and let it cover both files). The new unified skill must explicitly
defer to native `/init` for net-new CLAUDE.md creation.

### agents-md — MOVE → same unified behavioral-contract skill
No native equivalent, so it has clean standing. But it is structurally a twin of
`claude-md` and both are draft-only. Under one-job-one-place these belong in a
single slot. Survivor of the merge; bring `claude-md`'s Spark-doctrine injection
in alongside it.

### fork-init — DIE
The plugin model documented in CLAUDE.md makes fork-init architecturally obsolete:
the install path is `/plugin install spark`, not "clone and wire as upstream seed."
The skill is draft-only and runtime-unimplemented. Spark-specific project inception
is handled by `bootstrap` (runtime scaffold) plus the plugin install flow. No
distinct job remains for fork-init. Native git clone covers the mechanical step.

### build — LIVE
Genuine Spark-specific value: scopes implementation to exactly one GitHub issue's
acceptance criteria, enforces branch discipline, and integrates with `plan`'s
issue artifacts. Claude codes natively but does not enforce "one issue per branch,
stop at AC, branch not master" doctrine. This is the Generate spine slot and it
earns its place.

### codify (skill + agents/codify/ crew) — LIVE (as KNOWLEDGE-CAPTURE lane, not CODING)
The author's new law redefines codify=CODING, which collides with `build`. But the
actual file is a well-defined 6-agent crew for internal knowledge capture (ADRs,
SOPs, specs, glossary) that has no native equivalent. Claude can write docs
natively but does not run a fact-vs-assumption-disciplined, crew-orchestrated
knowledge-capture workflow. The law's redefinition creates a collision with `build`
that the council must resolve at the author level; from a native-enforcement lens,
the current codify skill is not a native duplicate and earns its slot as
KNOWLEDGE-CAPTURE. The crew (agents/codify/) is treated as one artifact with the
skill.

### docit (skill + agents/docit/ crew) — LIVE
Claude writes docs natively, but the persona-crew orchestration, cross-evaluation
dependency graph, shared-notes barrier pattern, and editor-synthesizes flow are
not native capabilities. The outward-facing audience (marketing, developer
adoption) is distinct from native doc generation. No native equivalent for the
multi-persona crew pattern. The crew (agents/docit/) is treated as one artifact
with the skill.

### ideate — LIVE
Claude brainstorms natively, but ideate adds: lifecycle-spine position (stage 1),
the structured problem-statement output format (Problem/Outcome/Success
criteria/Constraints/Non-goals), the confirm-before-handing-to-plan discipline,
and the explicit `grill-me` pressure-test gate. These are Spark-workflow-specific
and have no native counterpart.

### plan — LIVE
`gh` issue creation is native. `plan` adds: issue-template discipline (uses
`.github/ISSUE_TEMPLATE/`), confirm-before-create guardrail, milestone
grouping, 3–7 feature scope cap, and explicit handoff to/from `ideate`/`build`.
These are Spark lifecycle guardrails that native `gh` does not provide.

### bootstrap — LIVE
No native Bun/uv opinionated scaffolder with Spark quality gates. `bootstrap`
adds: profile-based framework selection, canonical non-interactive scaffolder
flags, quality-gate wiring (formatter/linter/test runner), and Spark lifecycle
integration. Project-specific value is real.

### connect — LIVE
No native 1Password secret lifecycle. `connect` adds: capture→ingest→shred→inject
workflow, `op item create` confirmation guardrail, `spark shred-env` integration,
and smoke-test before shred discipline. Strong project-specific value.

### commit — LIVE
Native git commit exists. `commit` adds: enforces Spark `commit-msg` hook rules
(no AI attribution, conventional type, imperative subject, why-body, 72-char
limit) so Claude produces a passing message on the first try rather than
iterating against hook failures. The no-AI-attribution rule is Spark-specific and
not a native Claude default. Guardrail doctrine is real.

### ship — LIVE
Native `git push` + `gh pr create` exists. `ship` adds: no-force-push enforcement,
no-trunk-push enforcement, no-AI-attribution in PR body, one-concern-per-PR
discipline, and PreToolUse hook awareness. Guardrail doctrine is real.

### fix-issue — LIVE
This is the exemplary native-reference model. It explicitly orchestrates
`/code-review`, `/security-review`, and `verify` without reimplementing them.
Adds Spark-specific value: triage taxonomy (must/should/out-of-scope), AC
re-check discipline, and the "anything out-of-scope files as a new issue" rule.
Keep as-is and use as the template for how every other skill should treat native
capabilities.

### review — LIVE (with a required fix)
The 8-specialist crew adds genuine breadth (architecture, testing, docs, product
readiness, risk) that native `/code-review` + `/security-review` do not cover.
However, the agents covering security and code-correctness dimensions partially
duplicate what the native passes already do. Those two agent dimensions must be
refactored to explicitly call `/security-review` and `/code-review` as delegates
rather than re-running the same analysis from scratch. The breadth lanes are
irreplaceable; the duplication lanes need fixing. LIVE pending that fix.

### bin/spark (CLI overall) — LIVE
`doctor`, `install-git-hooks`, `shred-env`, and `help` are Spark-specific glue
with no native equivalent. `new-skill` has the overlap with `write-a-skill`
resolved above (CLI wins, skill dies). `list-skills` is a convenience wrapper.
CLI as a whole is justified.

---

## Summary table

| artifact | verdict | covers-it (for DIE) or target (for MOVE) |
|---|---|---|
| grill-me | DIE | native `grill-me` skill |
| write-a-skill | DIE | native skill authoring + `bin/spark new-skill` |
| claude-md | MOVE | agents-md (unified behavioral-contract skill) |
| agents-md | MOVE | claude-md (unified behavioral-contract skill) — agents-md is the survivor |
| fork-init | DIE | `bootstrap` + plugin install model (native git covers mechanics) |
| build | LIVE | — |
| codify + agents/codify/ | LIVE | — |
| docit + agents/docit/ | LIVE | — |
| ideate | LIVE | — |
| plan | LIVE | — |
| bootstrap | LIVE | — |
| connect | LIVE | — |
| commit | LIVE | — |
| ship | LIVE | — |
| fix-issue | LIVE | — |
| review | LIVE | — (with required fix: security/correctness agents must delegate to native) |
| bin/spark CLI | LIVE | — |
