# The Minimalist — Phase 2 Verdicts

Lens: smallest possible surface. Default is DIE or MOVE. LIVE requires a
concrete justification that Claude-native capabilities cannot provide.

---

## The governing tests I apply to every artifact

1. Does a Claude-native capability already do this job? If yes: DIE or MOVE
   unless Spark adds a *mandatory* guardrail the native tool omits.
2. Do two Spark artifacts do the same job? One must die.
3. Is it draft/unimplemented and the model it describes is already obsolete?
   Die now rather than maintain a ghost.
4. Does it enforce a Spark-specific rule that, without the skill, Claude would
   routinely violate? If yes: LIVE (thin wrapper over native is acceptable
   *only* for guardrail doctrine).

---

## Verdicts and reasoning

### `grill-me` — DIE
The file is word-for-word the native skill. Description is identical. Body is
one generic paragraph. There is zero Spark-specific content. The native skill
is already loaded and callable from `ideate`. Shipping a verbatim copy creates
maintenance debt and a confusing double-registration with no upside. `ideate`
references it by name; that reference routes to the native skill automatically
after deletion. Unambiguous kill.

### `write-a-skill` — DIE
Three things do this job: the native Anthropic skill-authoring spec, `bin/spark
new-skill` (deterministic file creation), and this skill. The skill's value
claim is "authoring doctrine" — but that doctrine (description format, 100-line
limit, when-to-split, progressive disclosure) belongs in `CLAUDE.md` or the
`spark new-skill` help text, not a fourth artifact. It is also fully generic:
there is nothing Spark-specific in the body beyond pointing at `spark new-skill`.
The `bin/spark new-skill` CLI is the canonical entry point for skill creation;
the doctrine can live in two sentences of CLAUDE.md. Kill the skill; migrate the
checklist into `bin/spark new-skill --help` or CLAUDE.md.

### `grill-me` — DIE (covered above)

### `fork-init` — DIE
This skill is draft/unimplemented, describes a workflow that is now explicitly
obsolete (plugin model replaced fork-as-seed), and calls a `spark init` CLI
command that does not exist and is not planned. The current installation path
documented in CLAUDE.md is `/plugin install spark`, which makes fork-init
architecturally incoherent. An unimplemented skill for a deprecated model is
pure dead weight. If the upstream-sync pattern ever becomes real again, write it
then.

### `claude-md` — MOVE → consolidate into `agents-md` as a single `agent-contracts` skill
Both skills have the same job (maintain behavioral contract files for AI agents
in a project repo), are both draft/unimplemented, both reference each other,
and both share identical section content (attribution rules, destructive-action
rules, scope discipline, commit rules). The only distinction is the target file.
That distinction is not large enough to justify two skills. A single
`agent-contracts` skill that owns both CLAUDE.md and AGENTS.md reduces the
surface by one slot. Additionally: for net-new creation, the skill must
explicitly defer to `/init` (native). The maintenance + Spark-doctrine-injection
job is the real value, and it fits in one skill.

### `agents-md` — MOVE → consolidate into `agent-contracts` (same as claude-md)
See above. `agents-md` has no native equivalent (justified) but its job is
inseparable from `claude-md`. One skill, one place.

### `codify` (+ `agents/codify/` crew) — LIVE
Resolving the author-law collision in favor of keeping codify = KNOWLEDGE-CAPTURE.
Rationale: (a) `build` already owns CODING/IMPLEMENTATION and is a named spine
stage — renaming it `codify` gains nothing and loses the lifecycle legibility;
(b) the actual codify file is a mature, well-specified knowledge-capture crew
with genuine specialist value (intake→architect/product/ops→editor+librarian);
(c) Claude writes docs natively but does not enforce the facts-vs-assumptions
separation, the multi-specialist routing, or the glossary-preservation rules
that make codify useful for a multi-project agency like Status26; (d) the law
collision is a naming error, not a functional one — the correct fix is to label
codify's lane KNOWLEDGE-CAPTURE, not CODING. The 6-agent crew LIVES as part of
this artifact.

### `build` — LIVE
Core lifecycle spine, stage 3. The value is not "Claude codes natively" — it is
the one-issue/one-branch/scoped-to-AC discipline that without the skill Claude
routinely violates (scope creep, multi-concern branches, implementing things not
in the issue). This is Spark-specific guardrail doctrine. It is also the
lightest skill in the repo (40 lines). Keep it.

### `ideate` — LIVE
Stage 1 of the spine. Its job is not "Claude brainstorms" — it is enforcing the
no-code/no-tickets/one-problem-statement discipline that prevents premature
decomposition. The output format (Problem / Outcome / Success criteria /
Constraints / Non-goals) is a Spark-specific contract that `plan` depends on.
Native brainstorming has no such contract. Keep it.

### `plan` — LIVE
Stage 2. Value is the confirm-before-create GitHub guardrail (agents may not
create issues/milestones without explicit approval) plus the issue-template
discipline. Without this skill, Claude would call `gh issue create` immediately
on instruction; the skill enforces the draft-then-confirm pattern. Keep it.

### `fix-issue` — LIVE
The reference model for how every skill should treat native capabilities. It
explicitly orchestrates `/code-review`, `/security-review`, and `verify` rather
than reimplementing them, then adds triage discipline and AC re-check. The
triage layer (must-fix / should-fix / out-of-scope with explicit new-issue
filing) has no native equivalent. Keep it.

### `review` — LIVE (with a required internal fix)
This is the one skill that adds genuine breadth the native passes lack:
architecture, testing, product readiness, and risk dimensions. The
`/code-review` + `/security-review` native passes cover two of the eight
dimensions; the other six are irreplaceable. However, the two overlapping
dimensions (03 Code Quality, 05 Security) must explicitly delegate to native
`/code-review` and `/security-review` rather than re-running the same analysis.
That is a required fix, not a kill trigger. The multi-agent shared-notes
pattern is genuinely novel (no native equivalent). Keep it; fix the delegation.

### `commit` — LIVE
The value is narrow but real: Spark's commit-msg hook rejects AI attribution
and requires conventional type prefixes. Without this skill, Claude would
routinely add `Co-Authored-By: Claude` and write non-conventional messages.
The skill teaches Claude to produce a passing message on the first attempt
rather than iterate against hook failures. Thin wrapper, but the guardrail is
Spark-specific and non-trivial. Keep it.

### `ship` — LIVE
Same pattern as `commit`. The PreToolUse hook blocks force-push; the skill
explains why and enforces no-trunk/no-force/one-concern/no-AI-attribution
doctrine. Without it, Claude would push directly to master and add AI PR body
credits. Keep it.

### `connect` — LIVE
No native equivalent for the 1Password `op` secret lifecycle (capture → ingest
→ shred → inject). The `spark shred-env` integration and the propose-before-write
guardrail (never auto-write to a developer's vault) are Spark-specific and
project-specific (Status26 uses 1Password as the secrets store). Keep it.

### `bootstrap` — LIVE
The Bun-for-TS / uv-for-Python opinionated defaults are Spark-specific. Without
this skill Claude would default to npm/pip and produce a scaffold that violates
the stack tooling rule. The per-framework profile routing and quality-gate wiring
are also Spark-specific. Keep it.

### `docit` (+ `agents/docit/` crew, 13) — LIVE
Multi-persona outward-facing doc crew. No native equivalent for the persona
cross-evaluation mechanism or the ground-truth barrier. Claude writes docs
natively but does not enforce the author-ground-truth-first → parallel-drafts →
cross-eval → Issue-Council pipeline. The 13-agent crew LIVES as part of this
artifact. Keep it.

### `bin/spark` CLI — LIVE (with `new-skill` subcommand restructured)
`doctor`, `shred-env`, `install-git-hooks`, and `help` are Spark-specific glue
with no native equivalent. Keep them. The `new-skill` subcommand stays as the
deterministic file-creation step; `write-a-skill` skill's doctrine checklist
should migrate here (help text or brief inline comments). The `list-skills`
subcommand is Spark-specific discovery with no native equivalent. Keep the CLI
as-is after the `write-a-skill` skill dies and its doctrine is absorbed into
`new-skill` help text.

---

## Net result

- **DIE (3):** `grill-me`, `write-a-skill`, `fork-init`
- **MOVE (2):** `claude-md` → `agent-contracts`, `agents-md` → `agent-contracts`
- **LIVE (13):** `ideate`, `plan`, `build`, `codify` (+crew), `fix-issue`,
  `review`, `commit`, `ship`, `connect`, `bootstrap`, `docit` (+crew),
  `agent-contracts` (consolidated), `bin/spark` CLI

From 16 skills to 13 (net after consolidation). Three dead skills. Two merged.
The spine is intact. No native capability reimplemented.

### Blocking decision resolved

`codify` stays = KNOWLEDGE-CAPTURE. `build` stays = CODING/IMPLEMENTATION.
The author's law lane label for `codify` should read KNOWLEDGE-CAPTURE, not
CODING. No collision.
