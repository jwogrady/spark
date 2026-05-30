# Phase 0 — Inventory (barrier)

Council Cartographer. Source of truth: the actual `skills/*/SKILL.md`, `agents/*`, and `bin/spark`.
"Real job" is read from the file body, not inferred from the name.

## Skills (16) + agent crews (2) + CLI

| artifact | real job | current lane | Claude-native overlap | notes |
|---|---|---|---|---|
| `agents-md` | Generate/maintain a repo's tool-agnostic `AGENTS.md` behavioral contract | DOCUMENTATION (agent-config) | `/init` writes CLAUDE.md only; no native AGENTS.md generator | Marked "runtime not yet implemented." Project-specific value (Spark contract). Twin of `claude-md`. |
| `bootstrap` | Run a stack's official scaffolder (Bun/uv) non-interactively + wire Spark on top | IMPLEMENTATION (project scaffold) | Native git + Bash run scaffolders; no native opinionated Bun/uv profile chooser | Adds Spark-specific defaults/quality gates. Orchestrates claude-md/agents-md/connect. |
| `build` | Implement exactly one planned GitHub issue on a feature branch, scoped to its AC | IMPLEMENTATION / Generate stage | Claude codes natively; no native "one-issue-scoped branch" discipline | **COLLIDES with redefined `codify`=CODING.** Core lifecycle spine (Generate). |
| `claude-md` | Generate/maintain a repo's `CLAUDE.md` instruction file | DOCUMENTATION (agent-config) | **`/init` is the native CLAUDE.md initializer** — direct overlap on create | Native `/init` does creation; Spark adds maintenance/Spark-doctrine. Marked "not yet implemented." Twin of `agents-md`. |
| `codify` | Crew that turns messy notes/findings into durable INTERNAL knowledge (ADRs, SOPs, specs, glossary) | KNOWLEDGE-CAPTURE (internal docs) | No direct native equivalent; it IS documentation though | **CONFLICT: author's new law redefines codify=CODING/impl, which contradicts this file AND collides with `build`. Council must resolve codify-vs-build and fate of knowledge-capture.** Lane overlaps `docit` (both produce docs; codify=inward, docit=outward). |
| `commit` | Stage + write a conventional commit passing Spark's commit-msg hook | SHIP (5a) | Native git commit; Claude writes commit msgs natively | Value = enforces Spark hook rules (no AI attribution, conventional type). Thin wrapper over native git. |
| `connect` | Capture API keys → load into 1Password (`op`) → verify → shred plaintext | IMPLEMENTATION (secrets/connectivity) | No native 1Password/secret-lifecycle skill | Strong project-specific value. Uses `spark shred-env`. |
| `docit` (+ `agents/docit/` crew, 13) | Multi-persona crew producing PUBLIC-facing docs (README, positioning, launch copy) | DOCUMENTATION (outward/marketing) | Claude writes docs natively; no native persona-crew orchestration | Owns OUTWARD docs per author law. Lane-adjacent to `codify` (inward docs). Reuses `review`'s shared-notes mechanism. |
| `fix-issue` | Drive the solve loop: run built-in reviews, triage, fix until AC hold | SOLVE stage (4) | **Explicitly wraps `/code-review`, `/security-review`, `verify`** — by design references, does not reimplement | Good native-reference model. Project value = triage/scope discipline + AC re-check. |
| `fork-init` | Guide cloning Spark as upstream seed + wire downstream project repo | IMPLEMENTATION (project inception) | Native git clone/remote; no native upstream-seed flow | Marked "runtime not yet implemented." Spark-specific. Possible overlap w/ `bootstrap` (both = project start). |
| `grill-me` | Interview the user relentlessly to stress-test a plan/design | EXPLORATION | **`grill-me` is a Claude-native/listed skill** (appears in available-skills) — likely duplicates a shipped skill | Ideate calls it. Check whether Spark's copy duplicates the native one verbatim. |
| `ideate` | Turn a vague idea into a sharp written problem statement (no code) | EXPLORATION (owns idea-generation per law) | Claude brainstorms natively; calls `grill-me` | Lifecycle spine (stage 1). Author law assigns EXPLORATION lane here. |
| `plan` | Decompose a problem statement into GitHub issues + a milestone | PLAN stage (2) | Native `gh` CLI; Claude drafts issues natively | Value = issue-template discipline + confirm-before-create guardrail. Lifecycle spine. |
| `review` | 8-specialist sequential multi-agent codebase audit via shared `.review-notes/` | SOLVE/QC (audit) | **Overlaps `/code-review` + `/security-review`** (subset dimensions); adds arch/test/docs/product/risk breadth | Broader than native single-pass reviews; uses shared-notes pattern docit borrows. Potential overlap with `fix-issue` (which already calls native reviews). |
| `ship` | Push feature branch + open one focused PR honoring git guardrails | SHIP (5b) | Native git push + `gh pr create` | Value = enforces no-force-push/no-trunk/no-AI-attribution + one-concern-per-PR. Thin wrapper over native gh. |
| `write-a-skill` | Create a new skill (structure, progressive disclosure, bundled resources) | IMPLEMENTATION (skill authoring) | **Native skill creation exists; `spark new-skill <name>` CLI already scaffolds** — double overlap (native + CLI) | Likely DIES or merges into `spark new-skill`. Generic, not Spark-specific. |
| `agents/codify/` crew (6) | intake→architect/product/ops→editor+librarian subagents for codify | KNOWLEDGE-CAPTURE | (see codify) | Treated as single artifact w/ codify. |
| `agents/docit/` crew (13) | persona authors + Editor-in-Chief subagents for docit | DOCUMENTATION (outward) | (see docit) | Treated as single artifact w/ docit. |
| `bin/spark` (CLI) | Dispatcher: doctor, list-skills, new-skill, install-git-hooks, shred-env, help | TOOLING | Native skill creation overlaps `new-skill`; native git overlaps hook install | `new-skill` overlaps `write-a-skill` skill. `doctor`/`shred-env`/`install-git-hooks` are Spark-specific glue. |

## Obvious native duplications spotted (for the council)

1. **`write-a-skill` skill ↔ native skill creation ↔ `spark new-skill` CLI** — triple overlap. Generic skill authoring; no Spark-specific value beyond what the CLI scaffolder already does.
2. **`claude-md` ↔ native `/init`** — `/init` is the native CLAUDE.md initializer. Spark's value is only maintenance + Spark-doctrine injection, not creation.
3. **`grill-me`** — appears in the Claude-native available-skills list; Spark may be shipping a verbatim duplicate of a native skill.
4. **`review` ↔ `/code-review` + `/security-review`** — partial overlap; review adds breadth (arch/test/docs/product/risk) the native passes don't cover, but the security/correctness dimensions duplicate native.
5. **`commit` / `ship` ↔ native git + `gh`** — thin wrappers; justified ONLY by enforcing Spark guardrails (no-AI-attribution, conventional commits, no force-push/trunk). Council should confirm the guardrail value is real, else they reference native.
6. **`fix-issue`** — the GOOD pattern: explicitly references `/code-review`, `/security-review`, `verify` instead of reimplementing. Use as the template for how every skill should treat native capabilities.

## Two unresolved conflicts the author's new law forces (flagged, not resolved here)

- **codify-vs-build:** new law says `codify` = CODING/IMPLEMENTATION, but the actual `codify` file is INTERNAL-KNOWLEDGE-CAPTURE, and CODING/IMPLEMENTATION is already owned by `build` (Generate stage). Council must pick: keep codify=knowledge-capture (and find it a lane name other than CODING), or repurpose codify=coding (and kill/merge `build`), plus decide the fate of knowledge-capture.
- **lane assignment:** law assigns three lanes (docit=DOCS, codify=CODING, ideate=EXPLORATION) but the repo has many skills outside those three lanes (build, plan, commit, ship, connect, bootstrap, fork-init, claude-md, agents-md, review, fix-issue, grill-me, write-a-skill). Council must decide which survive as project-specific guardrail layers and which collapse into native references.

## Status flags found in files
- "Draft — runtime not yet implemented": `agents-md`, `claude-md`, `fork-init` (documents behavior only).
