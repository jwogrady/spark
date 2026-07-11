# Changelog

All notable changes to this project will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [0.8.0](https://github.com/jwogrady/spark/compare/v0.7.0...v0.8.0) (2026-07-11)


### Features

* wire per-companion release trains through Release Please ([#154](https://github.com/jwogrady/spark/issues/154)) ([6f34f9c](https://github.com/jwogrady/spark/commit/6f34f9c86f96e38b9f62394f715f323372d96495)), closes [#150](https://github.com/jwogrady/spark/issues/150)


### Bug Fixes

* exempt git-generated messages from commit-msg style rules ([#151](https://github.com/jwogrady/spark/issues/151)) ([dc9f8df](https://github.com/jwogrady/spark/commit/dc9f8df262c1fd4d1812e0cd54aba9cf8378df23)), closes [#148](https://github.com/jwogrady/spark/issues/148)

## [0.7.0](https://github.com/jwogrady/spark/compare/v0.6.0...v0.7.0) (2026-07-11)


### Features

* consolidate review and cleanup into one audit skill ([#144](https://github.com/jwogrady/spark/issues/144)) ([d793cc6](https://github.com/jwogrady/spark/commit/d793cc68c0a26eb8b92cb0adcf0c1d76fe3b5a69))
* consolidation hygiene — defer decisions, drop relics, close loop ([#143](https://github.com/jwogrady/spark/issues/143)) ([bf7398c](https://github.com/jwogrady/spark/commit/bf7398ced2c94044bcfb8f879cb61a835bacf469))
* reshape the marketplace into a focused core and companions ([#146](https://github.com/jwogrady/spark/issues/146)) ([b1a73ea](https://github.com/jwogrady/spark/commit/b1a73ea5aa2d4c2c9842383be046ea3cf0c7c474))


### Bug Fixes

* make spark setup reliable ([#137](https://github.com/jwogrady/spark/issues/137)) ([79a42a4](https://github.com/jwogrady/spark/commit/79a42a4bc8fd83d7ecb050de8a4c98a6820ea7c8))

## [Unreleased]

### Changed

- **The marketplace reshaped into a focused core and companion plugins**
  (#140, ADR-0014, ADR-0015). The core plugin now ships only the shipping
  loop — `setup`, `bootstrap`, the five lifecycle skills, three-tier
  preferences, `brief`/`resume` with a new `idle` work-state stage, the two
  enforcement doors, `doctor`, and Release Please scaffolding — plus a
  slimmed `knowledge` crew (three roles) and `agents-md`. Three companion
  plugins are installable from the same marketplace: `spark-audit` (the
  audit skill moves there), `spark-connect` (the connect skill and
  `shred-env`, which leaves the core CLI), and `spark-docs` (the public-docs
  crew, slimmed to five personas with the Issue Council removed). All moves
  are history-preserving; `doctor` now validates every listed plugin and
  enforces taxonomy parity, and the docs — README, taxonomy, identity,
  glossary, onboarding — describe the new shape. The internal "Cosmic"
  product vocabulary is retired from public docs.
- **`review` + `cleanup` consolidated into one `audit` skill** (#139). Both
  skills are removed; `/spark:audit` runs the whole-project audit directly
  in-session with at most five dispatched roles — **assess** keeps review's
  six health dimensions and produces an evidence-cited report; **purge**
  keeps cleanup's evidence table, deletion-safety categories, and human
  approval gate, and acts instead of emitting a copy-paste orchestrator
  prompt. Skill count drops from 12 to 11 and the native `/review` name
  collision (finding F1) is resolved.
- **Consolidation hygiene** (#141): the operator knowledge store is
  `glossary.md` only — the `decisions.md` half is deferred until a shipped
  surface reads it (existing stores untouched on disk); the `agents-md`
  pre-plugin relics (`references/system-prompt.md`, `references/io-schema.yaml`,
  `references/examples.md`, `agents/openai.yaml`) are deleted and the PR
  template now asks for a `SKILL.md` with valid frontmatter instead of
  `agents/openai.yaml`; and the work-state loop now closes — when the recorded
  PR is merged, `spark resume` presents the loop restart instead of the stale
  `next_action` (documented in `docs/reference/state.md`).

### Fixed

- **`spark setup` distinguishes decisions from failures** (#137). Mechanical
  failures — a file that could not be written, an uncreatable hooks
  directory, broken tooling — are now caught at every step, reported, and
  drive a non-zero exit with a "repo not fully armed" summary; operator
  decisions (a declined merge, the LICENSE choice) still exit 0. The granular
  verbs gain the same failure handling, and the permission baseline now
  allows the `spark setup` carry-in path itself.

## [0.6.0](https://github.com/jwogrady/spark/compare/v0.5.0...v0.6.0) (2026-07-11)


### Features

* add a spark setup verb that runs the whole carry-in ([#132](https://github.com/jwogrady/spark/issues/132)) ([e2b61db](https://github.com/jwogrady/spark/commit/e2b61db71ae3f72d831f80c1d46fd37f87ef03b5))

## [0.5.0](https://github.com/jwogrady/spark/compare/v0.4.0...v0.5.0) (2026-07-09)


### Features

* carry-in and carry-forward — the v0.4 milestone five ([#129](https://github.com/jwogrady/spark/issues/129)) ([d9ff8fe](https://github.com/jwogrady/spark/commit/d9ff8feca87ce23ed90408b71d924b3138ef1c66))

### Added

- **Carry-in shipped** (#61, #63): `preferences/defaults.json` is the machine
  form of the engineering standard; `spark preferences` shows the resolved
  three-tier standard (defaults → operator → project, ADR-0010) and `--apply`
  materializes it — doc set, Release Please wiring, stack-aware validation
  CI — create-only and idempotent. `bootstrap` applies the standard at
  generation with Python+uv as the resolved default (ADR-0007).
- **Carry-forward shipped** (#66, #68, #62): lifecycle skills record work
  state in `.spark/state.json`; `spark resume` rebuilds where you were and
  flags drift against the live repo; a SessionStart hook runs
  `spark brief --short` so every session opens oriented (orient/locate/load).
- **Portable operator knowledge** (#67): `~/.config/spark/knowledge/` home,
  written only through the librarian's explicit promotion step.
- **On-ramp** (#80): `how-to/carry-your-preferences-in.md`.

### Fixed

- Restored the `spark apply-permissions` verb lost in a merge-conflict
  resolution; docs and CLI agree again.

## [0.4.0](https://github.com/jwogrady/spark/compare/v0.3.1...v0.4.0) (2026-07-09)

### Added

- **Architecture v1.0.** ADR-0008 (information architecture: Operator/Project/
  Session layers, one canonical source per information class, the carry-in /
  carry-through / carry-forward motions), ADR-0009 (Spark's own release
  mechanism), ADR-0010 (three-tier preferences source), and the conformance
  audit (`docs/architecture/conformance.md`) mapping every shipped component to
  the model — clean pass, architecture declared complete.
- **`spark doctor` is the superset gate.** Doctor now runs `bash -n` on every
  shipped script, scans docs for broken relative links, checks git-hook install
  state inside the Spark repo, and verifies enforcement parity (commit types,
  attribution, trunk and force-push rules) across guard, git hooks, and docs.
- **Validation CI.** `.github/workflows/validate.yml` gates PRs by running
  `spark doctor` — no duplicated check logic in the workflow.
- **`spark version`** verb; `usage()` now generated from a verb table.
  `new-skill` lints its scaffold's description at creation time.
- **Permission baseline** shipped as a versioned artifact with a documented
  apply step.
- **Issue-template planning fields** (priority, category, dependencies with
  real issue numbers, size).
- **Four how-to guides** (cleanup, docit, knowledge, agents-md); onboarding
  and tutorial now open with the identity mental model.
- **`ideate` persists the problem statement** to `docs/problem-statement.md`
  by default.

### Changed

- **Spark releases via Release Please** (ADR-0009): a workflow maintains the
  release PR from conventional commits; merging it produces the version bump,
  CHANGELOG entry, tag, and GitHub Release. The `ship` skill now defers to it
  wherever a Release Please config exists (discharging ADR-0006's consequence)
  and keeps the manual ladder only as the explicit-approval fallback for repos
  without it.

- Knowledge-crew agent models tiered by role instead of all-Opus.
- Install how-to leads with the verified Git/local-clone path; the
  published-marketplace one-click flow is marked as the open item it is.
- Dev docs (`spark-internals`, `plugin-manifest`) refreshed to the
  `plugins/spark/` layout; ADRs 0004–0007 indexed; "Cosmic" defined in the
  glossary.
- Skill scratch directories settled as gitignored; durable findings promote to
  PRs and issues.

### Fixed

- **Documentation truth audit.** Corrected docs to match the code as it ships:
  the skill count is now 12 (the `cleanup` skill, added in `0.3.1`, was missing
  from the README, `CLAUDE.md`, and the canonical taxonomy in
  `docs/reference/skills.md`); refreshed stale `0.2.0` version references to
  `0.3.1` across the README and docs; and reworded claims that presented
  v0.4-planned GitHub-issue generation as shipped. No behavior changed.

### Features

* add an enforcement-parity check to spark doctor ([#121](https://github.com/jwogrady/spark/issues/121)) ([498dd2f](https://github.com/jwogrady/spark/commit/498dd2f9f97f1c8d067c47d7b480a559d667fef9)), closes [#72](https://github.com/jwogrady/spark/issues/72)
* add planning fields to issue templates ([#101](https://github.com/jwogrady/spark/issues/101)) ([de6f4d6](https://github.com/jwogrady/spark/commit/de6f4d6f89fab1718525ee19867504d476f7a077)), closes [#87](https://github.com/jwogrady/spark/issues/87)
* adopt Release Please for Spark's own releases ([#127](https://github.com/jwogrady/spark/issues/127)) ([9f3bd1b](https://github.com/jwogrady/spark/commit/9f3bd1bff446a3ed5374297d06c67e0317828aef))
* drive usage from a verb table and add spark version ([#119](https://github.com/jwogrady/spark/issues/119)) ([9d2249d](https://github.com/jwogrady/spark/commit/9d2249daaf794686a13dd616432f1b8e025cd943)), closes [#75](https://github.com/jwogrady/spark/issues/75)
* fail doctor on missing git hooks inside the Spark repo ([#110](https://github.com/jwogrady/spark/issues/110)) ([4939f26](https://github.com/jwogrady/spark/commit/4939f26071f5dad116f8c1654bb7e59649168c93)), closes [#73](https://github.com/jwogrady/spark/issues/73)
* fold bash -n and a relative-link scan into spark doctor ([#109](https://github.com/jwogrady/spark/issues/109)) ([254a796](https://github.com/jwogrady/spark/commit/254a796832a36f312a4a2be5141c99f218f828ca)), closes [#71](https://github.com/jwogrady/spark/issues/71)
* gate PRs with a validation workflow that wraps spark doctor ([#122](https://github.com/jwogrady/spark/issues/122)) ([cb8de5a](https://github.com/jwogrady/spark/commit/cb8de5a25ea7f47672d66c085529b04a593a97e6)), closes [#70](https://github.com/jwogrady/spark/issues/70)
* lint new-skill scaffolds with doctor's description linter ([#120](https://github.com/jwogrady/spark/issues/120)) ([c08a3b1](https://github.com/jwogrady/spark/commit/c08a3b17f2f567df87337a8fe21b5bbf962e2b58)), closes [#76](https://github.com/jwogrady/spark/issues/76)
* persist the ideate problem statement to a canonical path ([#99](https://github.com/jwogrady/spark/issues/99)) ([fd46a66](https://github.com/jwogrady/spark/commit/fd46a662d891e28ac9ef175965ebb0c7d144ec26)), closes [#68](https://github.com/jwogrady/spark/issues/68)
* ship a versioned permission baseline and an apply verb ([#112](https://github.com/jwogrady/spark/issues/112)) ([958adf4](https://github.com/jwogrady/spark/commit/958adf41778b7ed02c27e608987dec988e114469)), closes [#64](https://github.com/jwogrady/spark/issues/64)
* tier knowledge crew models by role instead of all-Opus ([#102](https://github.com/jwogrady/spark/issues/102)) ([e9f15b4](https://github.com/jwogrady/spark/commit/e9f15b48f218a7005ac39bc52cf91edeac3adc14)), closes [#74](https://github.com/jwogrady/spark/issues/74)


### Bug Fixes

* remove committed worktree gitlinks and ignore .claude ([#124](https://github.com/jwogrady/spark/issues/124)) ([9faa761](https://github.com/jwogrady/spark/commit/9faa761f1d9f17b4a2edf812842277d8b597c932))

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
