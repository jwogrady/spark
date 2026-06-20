# Changelog

All notable changes to this project will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

Nothing yet.

## [0.3.1] - 2026-06-20

### Changed

- **Strip residual process framing from generated project docs.** Doc-writing
  skills (`ideate`, `plan`, `agents-md`) now forbid stamping product docs with
  Spark-internal process framing — `Phase N` / `Prompt NNN` status headers,
  `/spark:` stage references, "later Spark stages" phrasing; a status line
  describes a doc's own authority, not the stage that produced it. `ship` now
  enforces CHANGELOG discipline: entries record product changes, never phase
  transitions or planning bookkeeping. `cleanup`'s Docs Auditor flags the
  residue mechanically (`rg 'Phase [0-9]|Prompt 0|/spark:|later Spark stage'`).
  Extends the #38 rule from whole files to the framing inside the files that
  remain. (#55)

## [0.3.0] - 2026-06-19

### Added

- **`knowledge` crew — internal-knowledge capture.** New skill `skills/knowledge/SKILL.md`
  runs 6 specialist agents (`agents/knowledge/00-intake` through `05-editor`) to
  capture architectural decisions, processes, and a glossary. It is the inward-facing
  counterpart to `docit`: real plugin subagents with tiered models and scoped tools,
  coordinating through a dedicated `.knowledge-notes/` scratch directory (separate from
  `docit`'s `.docit-notes/`, and kept out of the repo). `knowledge` runs alongside
  `docit`; it does not replace it.
- **`review` skill — multi-agent project audit.** `skills/review/SKILL.md` runs 8
  specialist agents plus a Synthesis Lead to audit a project, for use in the Validate
  stage.
- **MIT license adopted.** `LICENSE` now carries the full MIT License text
  (Copyright © 2026 `jwogrady`), matching the `plugin.json` manifest. Resolves the
  prior `LICENSE` ↔ manifest mismatch.
- **Skill clarity & native delegation (v0.2.1 milestone).** New
  `docs/reference/native-overlap.md` audits every skill against the Claude Code
  built-ins it touches (delegates-to / stays-out-of-lane / none), proving none are
  reimplemented. `docs/reference/skills.md` gains a "Which skill do I use?" chooser
  (decision flowchart + intent table), linked one hop from the README. `spark
  doctor` now lints each skill description — warning (never erroring) when it lacks
  a trigger or boundary clause, or exceeds the 1024-char cap.

### Changed

- **`ship` release flow — mechanical commit-type → bump mapping (#43).** The
  release section now derives the post-`0.1.0` bump from the commit types in the
  range (`feat:` → minor; `fix:`/`docs:`/`chore:`/`refactor:`/`test:` → patch;
  `!` or `BREAKING CHANGE:` → major, highest wins), completing the release step
  added in #46 so versioning is mechanical rather than a judgment call.
- **Methodology stays in Spark — skills link it, don't paste it (#38).**
  `ideate` and `plan` gain a guardrail against writing project-local copies of
  the Spark process, and `agents-md` now carries a "Link the methodology, don't
  paste it" section with the canonical "How this project is built" pointer for a
  project's `CLAUDE.md` / `AGENTS.md`. One source of truth for the process,
  edited once; the project repo holds product, not process.
- **`ideate` now surveys prior art and existing assets (#37).** Before framing a
  problem as new, `ideate` checks for a predecessor repo, prototype, captured
  data, or abandoned branch, and the problem statement gains a "Prior art &
  reusable assets" section. Turns "greenfield by default" into "greenfield only
  when it's actually green," and satisfies the prior-art line of the
  Codify-readiness checklist (#39).
- **Codify-readiness gate — verify substance, not just form (#39).** New
  `docs/reference/codify-readiness.md` defines the Plan→Codify gate: a checklist
  (problem statement, prior art, stack-as-ADRs, verifiable criteria, scaffold)
  and an optional health signal (commits-to-first-code, doc:code ratio, deferral
  density). `plan` and `codify` now link "Codify-ready" to this single source of
  truth, and `explanation/enforcement-model.md` draws the form-vs-readiness line —
  form lives in `hooks/`, readiness lives in the lifecycle skills.
- **`codify` now preflights for Codify-readiness (#36).** Before touching code,
  `codify` confirms the implementation approach is recorded as ADRs (from `plan`)
  and that a scaffold exists (or runs `bootstrap`). If the stack is undecided it
  refuses to start and sends you back to `plan`, rather than silently inventing a
  stack mid-implementation. Mirrors the existing "missing criteria → go back to
  plan" reflex for the other precondition `codify` had been assuming.
- **`plan` now decides the implementation approach (#35).** Plan picks up the
  tech choice `ideate` defers — language/runtime, top-level layout, key
  dependencies — and records it as ADRs under `docs/adr/`. A new guardrail makes
  it explicit: an issue with crisp acceptance criteria but no stack is not
  Codify-ready. `ideate` now states the tech choice is *decided in* `plan`, so
  the baton is caught rather than dropped. Closes the ideate→plan tech-choice gap
  that produced all-docs, zero-code plans.
- **Aligned lifecycle phase names with skill names (#41).** The two mismatched
  stages were renamed so every phase equals its like-named skill/command:
  `Generate → Codify` and `Solve → Validate`. The `fix-issue` skill is now
  `validate` (`skills/fix-issue/` → `skills/validate/`, invoked as
  `/spark:validate`). The lifecycle slogan is now
  `Ideate → Plan → Codify → Validate → Ship`, removing the
  Generate↔codify / Solve↔fix-issue translation step.
- **Spark is now a Claude Code plugin.** The document-only `.spark/` layer is
  replaced by a plugin packaged at the repo root (`.claude-plugin/plugin.json` +
  `marketplace.json`). Install via `/plugin marketplace add jwogrady/spark` →
  `/plugin install spark` (verified today from a local clone or Git URL; the
  published-marketplace listing is a v0.2 open item — see `ROADMAP.md`).
- Skills moved from `.spark/skills/` to `skills/` and are now namespaced
  `/spark:<name>`.
- Documentation reorganized to Diátaxis under `docs/`.
- Skill taxonomy unified across `CLAUDE.md`, `README.md`, and
  `docs/reference/skills.md` into four categories (Lifecycle / Setup / Authorship /
  Supporting), with the reference page as the canonical source. All 11 skill
  descriptions gained a "not for X — use Y" boundary clause; the `review` vs native
  `/code-review` collision is resolved by sending single-diff users to the built-ins.
- `CLAUDE.md`, `AGENTS.md`, `README.md`, `ROADMAP.md` rewritten for the plugin +
  lifecycle model.
- Skill `docit` — multi-persona public-docs glow-up. The author personas run as
  **real plugin subagents** under `agents/docit/` with tiered models and scoped
  tools. Because a subagent cannot spawn another, the skill orchestrates every
  dispatch and barrier, and the agents coordinate only through `.docit-notes/`.
  Personas draft in parallel, cross-evaluate their dependency-graph neighbors, and
  revise before an Editor-in-Chief assembles the docs. In a Phase-4 Issue Council
  the personas nominate, debate, and vote on the gaps they found; the Cartographer
  can veto anything that would overclaim and the human breaks every deadlock. The
  Editor-in-Chief tallies the ranked slate and files it for the human to triage,
  but never closes or comments. Enforces an honest-hype contract: no claim ships
  without a citation to ground truth.
- **De-duplicated the multi-agent orchestration pattern.** The "main loop is the
  sole orchestrator; agents coordinate only through shared notes" mechanics were
  stated in three places (`docit` + `knowledge` collaboration protocols and the
  architecture map). The architecture map is now the single source; the protocol
  files keep a brief self-contained summary and point to it. Fixed the protocols'
  stale "archive (commit it)" guidance for `.docit-notes/` / `.knowledge-notes/`,
  which contradicted the new gitignore.
- **Sharpened `review` and `validate` descriptions** so they disambiguate by
  scope — `validate` reviews one change/branch, `review` audits a whole project —
  and cross-reference each other.
- **Fixed factual drift across docs/meta.** `SECURITY.md` no longer claims a
  zero attack surface (it ships a Bash CLI + a 1Password secrets path); the
  `review` how-to no longer tells you to commit the gitignored `.review-notes/`;
  `reference/cli.md` now documents `list-skills`; and the CLI subcommand list,
  skill inventory, repo map, and Plan/Codify capability claims are reconciled
  across `CLAUDE.md`, `ROADMAP.md`, and `CHANGELOG.md`.

### Added (earlier in the unreleased window)

- Lifecycle skills organized as `Ideate → Plan → Codify → Validate → Ship`:
  `ideate`, `plan`, `codify`, `validate`, `ship`.
- Enforcement: `hooks/hooks.json` PreToolUse guard (`hooks/guard-bash.sh`) that
  blocks force-pushes and pushes to trunk; git hooks `scripts/hooks/commit-msg`
  (conventional + no-AI-attribution + subject rules) and `pre-commit`
  (no commit on trunk).
- `bin/spark` CLI: `doctor`, `list-skills`, `new-skill`, `install-git-hooks`,
  `shred-env`, `help`. `doctor` validates plugin layout, skill frontmatter, and
  every agent definition under `agents/`.
- Skill `bootstrap` — runtime scaffold for new projects, defaulting to Bun for
  TypeScript and uv for Python; verifies the scaffold runs, then wires it into Spark.
- Skill `connect` — connectivity & secrets bootstrap via 1Password (`op`):
  capture → ingest → verify → shred → `op run` injection.
- `bin/spark shred-env <file>` + `scripts/shred-env.sh` — secure-delete of
  transient secrets files, with verification; refuses to touch `*.tmpl`.

### Removed

- Skills `caveman` and `handoff` — general productivity, outside the SDLC spine.
- `.spark/configs/` and `.spark/issues/` — superseded by the plugin refactor.
- **Committed skill scratch directories.** Untracked the 108 process-exhaust
  files under `.audit-notes/`, `.docit-notes/`, and `.review-notes/`, and added
  all skill scratch dirs (incl. `.knowledge-notes/`) to `.gitignore` alongside
  `.codify-notes/`. Skills recreate these dirs at runtime; they no longer ship
  with the plugin.
- **`commit` skill — folded into `ship`.** The Ship stage was split across two
  tiny skills (`commit` = 5a, `ship` = 5b); they are now one `ship` skill that
  owns commit + push + PR. Removes a selection ambiguity and drops the lifecycle
  skill count from 12 to 11. All references updated across skills and docs.

### Kept

- Skill `agents-md` (now owns both `CLAUDE.md` and `AGENTS.md`).
- `.vscode/`, `.gitignore`, GitHub PR/issue templates, repo health files.
