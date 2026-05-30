# Proposed Issues — Ranked Slate (filed locally only)

> Chaired and tallied by the Editor-in-Chief (12). Author/credit: `jwogrady`.
> **Filed-locally-only is in effect** — no `gh` issues were created. The human
> triages this slate; accepted issues flow to the `plan` skill. Deadlocks
> (priorities/admission the council could not settle) are listed at the end and
> in `.docit-notes/issue-council.md`; the human breaks those ties.

Labels: `docs`, `feat`, `bug`, `roadmap`. Priority: P1 (blocker) / P2 / P3.

---

## Resolution log — 2026-05-30 (glow-up PR `docs/docit-glowup`)

Human decisions and what landed in the glow-up PR itself:

- **P1-1 (license) — RESOLVED.** Human chose *adopt MIT for real*. `LICENSE` now
  carries full MIT text (© 2026 `jwogrady`); README badge + trust line and CHANGELOG
  updated to MIT; launch-copy license caveats dropped.
- **P1-2 (codify/review in CHANGELOG + README) — DONE** in this PR.
- **P1-3 (hero tagline) — DONE** (staged README landed).
- **P1-5 (marketplace caveat in install block) — DONE** (staged README landed).
- **P1-4 (canonical skill layout) — DECIDED, impl pending.** Human chose
  `references/` + `agents/` as canonical (matches the shipped skills + `CLAUDE.md`).
  Remaining actionable work: write `docs/reference/skill-layout.md`, reconcile
  `skills/write-a-skill/SKILL.md`, and record an ADR. Stays on the slate as the
  decided-but-unbuilt item; unblocks P2-15.
- **P2-2 (philosophy doc) — DONE** (`docs/explanation/philosophy.md` + nav).
- **P2-3 (enforcement-model doc) — DONE.** Deadlock 3 resolved P1/blocking;
  `docs/explanation/enforcement-model.md` written and linked from philosophy.
- **Deadlock 1 (CI workflow, X-1) — ROUTED OFF SLATE** to the project backlog
  (not a docs deliverable).
- **Deadlock 2 (`/spark:plan` overclaim, P2-1) — PRIORITY P2.** Wording already
  softened in the landed README/CHANGELOG.
- **Deadlock 4 (GitHub topics, X-2) — LAUNCH CHECKLIST**, off the slate.

> **Open architectural question raised by the human (2026-05-30):** `docit`,
> `codify`, and `ideate` appear to overlap. A council-style **merge-or-separate
> proposal** is requested — see `.docit-notes/overlap-proposal.md`. Guiding model:
> humans ideate + own + prioritize; bots validate ideas & propose issues; bots help
> the human verify fixes.

Everything below is the original Editor-tallied slate, retained for provenance.

---

## P1 — blockers

### P1-1 — fix: resolve the MIT license overclaim (LICENSE vs manifests)
- **Labels:** bug, docs
- **Problem:** `.claude-plugin/plugin.json` declares `"license": "MIT"` and earlier
  README badges said MIT, but `LICENSE` reads "License TBD. Copyright belongs to the
  author." No enforceable license is in place.
- **Why it matters:** The single highest-trust risk in the repo and the only item
  with a legal dimension. Anyone reading the manifest acts on a false grant; nobody
  can legally redistribute or fork. It blocks awesome-list submission and enterprise
  adoption, and it contradicts the project's own honest-hype doctrine.
- **Acceptance criteria:** Either add a real SPDX license text to `LICENSE` (and
  keep the manifest MIT), or drop the MIT claim from `plugin.json` and all docs
  until a license is chosen. No surface advertises MIT as adopted while `LICENSE`
  says TBD.
- **Provenance:** 8 nominations (N00-1, N01-2, N03-2, N04-1, N05-3, N09-3, N10-4,
  N11-1); unanimous P1; Cartographer veto armed. Ground truth "Accuracy flags";
  `04-trust.md` "License status".

### P1-2 — docs: record `codify` and `review` in CHANGELOG `[Unreleased]` and name `codify` in README
- **Labels:** docs
- **Problem:** `codify` (6-agent crew, commit `6ea36a7`) and `review` (8-agent
  audit, commit `de7b9f9`) shipped in the unreleased window but appear in neither
  `CHANGELOG.md` nor the README.
- **Why it matters:** The changelog is the front-door record an upgrader reads;
  `codify` is the promoted headline of the launch copy. Omitting them makes launch
  copy point at features the repo's own docs never confirm.
- **Acceptance criteria:** `CHANGELOG.md` `[Unreleased]` lists `codify` and
  `review` under Added; README names `codify`. Both cite `.codify-notes/` (NOT
  `.docit-notes/`).
- **Provenance:** N04-3, N09-1, N11-2; mean ≈ P1. Ground truth "Review/knowledge
  skills"; `09-changelog.md`.

### P1-3 — docs: land the Phase-3 hero tagline in the README
- **Labels:** docs
- **Problem:** The README leads with the old description; the chosen tagline
  ("Turn raw project intent into durable GitHub artifacts — in one portable
  toolkit") was finalized in cross-eval but never landed.
- **Why it matters:** First-ten-seconds promise; the revised tagline won the review
  for honesty and specificity and is ready to paste.
- **Acceptance criteria:** README hero opens with the chosen tagline; install block
  carries the marketplace caveat (see P1-5).
- **Provenance:** N01-1; mean ≈ P1. `01-hero.md`.

### P1-4 — feat: resolve the canonical optional skill-layout spec; create `docs/reference/skill-layout.md`
- **Labels:** docs, feat
- **Problem:** `CONTRIBUTING.md` names optional subdirs `references/` + `agents/`;
  `skills/write-a-skill/SKILL.md` names `REFERENCE.md` + `EXAMPLES.md` + `scripts/`.
  Two conflicting specs for the same surface.
- **Why it matters:** Blocks the `write-a-skill` how-to (P2-6), the skill-anatomy
  diagram, and contributor onboarding. A decision + ADR is required, not three
  parallel issues.
- **Acceptance criteria:** One canonical layout decided (ADR recommended);
  `docs/reference/skill-layout.md` is the single authoritative spec; the losing
  source is updated; both `CONTRIBUTING.md` and `write-a-skill/SKILL.md` cross-link
  it.
- **Provenance:** N05-5, N06-B, N07-1, N08-5; mean ≈ P1. `06-diataxis.md`,
  `07-contributing.md`.

### P1-5 — docs: add marketplace caveat + Git-URL fallback to the README install block
- **Labels:** docs
- **Problem:** The README install block shows `/plugin marketplace add` with no
  qualifier; every other surface (hero, quickstart, positioning, launch copy)
  already carries the v0.2 caveat.
- **Why it matters:** Largest blast radius — the README is the surface most readers
  see first. A reader following it hits a dead end if the listing is unreachable.
- **Acceptance criteria:** Install block states the verified path is a local clone
  or Git URL and that the published listing is a v0.2 open item.
- **Provenance:** N01-4, N02-2, N03-1, N11-4; P1/P2 mean ≈ 2.6. Ground truth ROADMAP.
- **Note:** Priority leans P1; some personas P2. Treated as P1 here per the higher
  weight of cross-domain nominators.

---

## P2 — important

### P2-1 — docs: strike the `/spark:plan` "creates GitHub issues" overclaim *(priority DEADLOCKED — see below)*
- **Labels:** docs, roadmap
- **Problem:** Quickstart copy implies `/spark:plan` creates real GitHub issues;
  ground truth puts mechanical issue creation in v0.3.
- **Why it matters:** A false capability claim on the primary user path.
- **Acceptance criteria:** Quickstart describes scoped work-item/milestone
  scaffolding in v0.2 and flags GitHub-issue creation as v0.3 roadmap.
- **Provenance:** N02-4; admitted 11/12 (Adopter OUT). Priority split P1/P2 →
  **DEADLOCK 2**.

### P2-2 — docs: ship `docs/explanation/philosophy.md` and wire it into `docs/README.md`
- **Labels:** docs
- **Problem:** The philosophy doc is drafted (staged at `final/docs/PHILOSOPHY.md`)
  but does not exist in the tree and has no navigation entry.
- **Why it matters:** The values layer for the whole project; orphaned without nav
  wiring.
- **Acceptance criteria:** File lands at `docs/explanation/philosophy.md`; added to
  the `docs/README.md` navigation table under Explanation.
- **Provenance:** N03-3, N05-1, N06-G; mean ≈ P2 (Coach P1). `05-philosophy.md`.

### P2-3 — docs: write `docs/explanation/enforcement-model.md` *(priority DEADLOCKED — see below)*
- **Labels:** docs
- **Problem:** No doc explains *why* mechanical enforcement was chosen over advisory
  rules; philosophy Principle 1 has no rationale doc to link to.
- **Why it matters:** Without it, the philosophy doc links to nothing for its first
  principle (Diátaxis mode violation).
- **Acceptance criteria:** Explanation-mode doc covering the enforcement-as-policy
  decision; linked from philosophy Principle 1.
- **Provenance:** N05-2, N06-A; admitted 12/12. Priority P1 (Coach) vs P2
  (Believer) → **DEADLOCK 3**.

### P2-4 — docs: create `docs/tutorials/set-up-a-new-project.md` (Tutorial 1)
- **Labels:** docs
- **Problem:** The only tutorial assumes a configured project; there is no guided
  setup path (bootstrap → connect → install-git-hooks → doctor).
- **Why it matters:** The entry ramp for every new user; current Tutorial 2
  presupposes setup.
- **Acceptance criteria:** Tutorial 1 walks bootstrap → connect → install-git-hooks
  → doctor to a verified clean state; existing tutorial becomes Tutorial 2.
- **Provenance:** N05-6, N06-C; mean ≈ P2. `06-diataxis.md`.

### P2-5 — docs: create `docs/how-to/commit.md` and split mode bleed out of `ship.md`
- **Labels:** docs
- **Problem:** `docs/how-to/ship.md` covers both `/spark:commit` (Stage 5a) and
  `/spark:ship` (Stage 5b) in one guide.
- **Why it matters:** Quickstart sends users to `/spark:commit` with no task guide;
  blending two stages violates the one-goal how-to rule.
- **Acceptance criteria:** `commit.md` covers Stage 5a alone; `ship.md` covers Stage
  5b and links to `commit.md`.
- **Provenance:** N06-D; mean ≈ P2 (several P1). `06-diataxis.md`.

### P2-6 — docs: add Mermaid lifecycle diagram to the README hero
- **Labels:** docs
- **Problem:** The lifecycle is prose/table only; no scannable diagram.
- **Why it matters:** Bridges the "Generate" stage vs. `/spark:build` command naming
  gap; ready to paste.
- **Acceptance criteria:** Mermaid flow + stage-to-skill caption in the hero area.
- **Provenance:** N08-2; mean ≈ P2 (several P1). `08-visuals.md`.

### P2-7 — docs: quote the real `spark doctor` output; never "OK" or a "16/19" tally
- **Labels:** docs, bug
- **Problem:** Drafts/screenshots quoted output that does not exist.
- **Acceptance criteria:** Any doc quoting doctor uses `✓ <name>` lines + final
  `Healthy — 0 errors, N warning(s)`; notes non-zero exit on error.
- **Provenance:** N00-4, N02-1; P2. Cartographer veto-correction.

### P2-8 — docs: correct the "codify shares `.docit-notes/`" claim everywhere → `.codify-notes/`
- **Labels:** docs, bug
- **Problem:** A draft claimed codify shares docit's scratch dir; it uses
  `.codify-notes/` (separate, kept out of the repo).
- **Acceptance criteria:** No surface says codify uses `.docit-notes/`.
- **Provenance:** N00-6; HARD VETO; mean ≈ P1/P2.

### P2-9 — docs: correct hook file-layout and docs-tree in any architecture diagram
- **Labels:** docs, bug
- **Problem:** Diagrams collapse `hooks/guard-bash.sh` and
  `scripts/hooks/commit-msg`/`pre-commit` into one label; docs-tree drafts nest
  `adr/`/`architecture/` under `explanation/`.
- **Acceptance criteria:** Diagrams show the two hook directories separately and
  `adr/`/`architecture/` as top-level siblings.
- **Provenance:** N00-3; P2. Ground truth Enforcement + Docs.

### P2-10 — docs: pin volatile facts to durable references (tag, not hash/count/line)
- **Labels:** docs
- **Problem:** Drafts cited exact commit counts, hashes, PR counts, and line numbers
  that rot.
- **Acceptance criteria:** Editorial convention adopted — cite the tag `v0.2.0` and
  function names, not hashes/line numbers; current instances corrected.
- **Provenance:** N00-5; P2.

### P2-11 — docs: final shipped-vs-roadmap audit of the assembled README before launch
- **Labels:** docs
- **Acceptance criteria:** README asserts only the SHIPPED set; roadmap items live
  in a clearly labeled section.
- **Provenance:** N00-7; P2.

### P2-12 — docs: publish a comparison / "alternatives" doc under `docs/explanation/`
- **Labels:** docs
- **Problem:** The honest comparison (5 alternatives + "skip it when") lives only in
  scratch notes.
- **Acceptance criteria:** An explanation-tier "Spark vs. the alternatives / when to
  use Spark" doc, linked from the docs index.
- **Provenance:** N03-5; P2. `03-positioning.md`.

### P2-13 — docs: write `docs/explanation/authorship-crews.md`
- **Labels:** docs
- **Problem:** No explanation doc covers the multi-persona `docit`/`codify` design;
  philosophy Principle 6 has nowhere mode-correct to link.
- **Acceptance criteria:** Explanation doc on crew architecture + shared-notes
  coordination; absorbs the crew-discoverability request (N10-5).
- **Provenance:** N05-4, N06-E, N10-5; P2.

### P2-14 — docs: document the `gh auth` prerequisite in install/quickstart
- **Labels:** docs
- **Problem:** `/spark:ship` requires `gh` installed + authenticated; not flagged
  upfront.
- **Acceptance criteria:** Install/quickstart name the `gh auth login` prerequisite
  before the Ship step.
- **Provenance:** N02-3, N02-5; P2.

### P2-15 — docs: write `docs/how-to/write-a-skill.md` (blocked by P1-4)
- **Labels:** docs
- **Acceptance criteria:** Human-targeted task guide for skill authorship, accurate
  to the canonical layout from P1-4.
- **Provenance:** N07-2; P2. Blocked until P1-4 resolves.

### P2-16 — docs: add the ASCII component map to the README
- **Labels:** docs
- **Acceptance criteria:** Corrected three-layer component map (your project → Spark
  → Claude Code built-ins) with accurate hook paths.
- **Provenance:** N08-3; P2.

### P2-17 — docs: capture and publish a `spark doctor` terminal demo GIF
- **Labels:** docs
- **Problem:** No captured proof-of-life for the CLI.
- **Acceptance criteria:** Real (not staged) recording at
  `docs/assets/spark-doctor-demo.gif`, embedded in the Quickstart, caption quotes
  real output (see P2-7).
- **Provenance:** N08-1; admitted 11/12 (Skeptic OUT — author task); P2.

### P2-18 — docs: add a git-hook coexistence note for users with custom hooks
- **Labels:** docs
- **Acceptance criteria:** Note explaining `install-git-hooks` refuses to overwrite
  non-Spark hooks and how to coexist (hook chaining).
- **Provenance:** N09-2; P2/P3.

### P2-19 — docs: create OG social-preview image + configure GitHub social metadata
- **Labels:** docs
- **Acceptance criteria:** `.github/og-image.png` (1280×640, no AI attribution) and
  the repo social-preview configured.
- **Provenance:** N08-4, N10-3; admitted 11/12 (Skeptic OUT — author/settings task);
  P2.

---

## P3 — polish

### P3-1 — docs: add `spark list-skills` to README "What's in the box" and `docs/reference/cli.md`
- **Labels:** docs
- **Problem:** A verified real subcommand (`cmd_list_skills`) is omitted from both
  surfaces.
- **Acceptance criteria:** `list-skills` listed in the README CLI inventory and the
  CLI reference.
- **Provenance:** N00-2, N01-3, N03-4, N05-7, N06-F, N07-4, N09-4 (7 sources);
  unanimous P3.

### P3-2 — docs: document the branch-naming convention in the contributor path
- **Labels:** docs
- **Acceptance criteria:** `feat/`, `fix/`, `docs/`, `chore/` patterns surfaced in
  the contribution guidance.
- **Provenance:** N07-3; P3. `CONTRIBUTING.md`.

### P3-3 — docs: document a pre-1.0 breaking-change policy
- **Labels:** docs
- **Acceptance criteria:** A short statement ("treat any v0.x release as potentially
  breaking") in README/trust copy.
- **Provenance:** N04-4; P3. `04-trust.md`.

---

## Filed but contested / out of the docit shipping scope

These were admitted by some personas but the council did not settle them as docit
deliverables. Recorded for the human; not ranked into the slate above.

### X-1 — feat: add a CI workflow (`spark doctor` + `bash -n`) on push/PR
- **Status:** ADMISSION DEADLOCKED (≈7 IN / ≈5 OUT) → **DEADLOCK 1**.
- **Provenance:** N04-2. If admitted, P2; otherwise route to the project backlog
  (docit ships docs, not CI; `CLAUDE.md` gates `.github/workflows/`).

### X-2 — set GitHub repo topics
- **Status:** Priority/scope DEADLOCKED → **DEADLOCK 4** (Cartographer OUT as a
  GitHub-settings action; others P1–P3). Likely a launch-checklist item.
- **Provenance:** N10-1.

### X-3 — submit Spark to awesome-lists (blocked on P1-1 license)
- **Status:** Author action, gated on license. Launch-checklist, not a doc issue.
- **Provenance:** N10-2.

### X-4 — `docs/launch-copy.md` canonical home
- **Status:** Already produced by this run (staged at `final/docs/launch-copy.md`).
  Majority view: an Editor workflow artifact, not a tracked issue. Coach/Adopter/
  Discoverer/Evaluator would file it P2.
- **Provenance:** N11-3.

### X-5 — `spark doctor` machine-readable output contract for CI
- **Status:** REJECTED (10/12 OUT). A feature invention with no evidence it was ever
  promised; the legitimate kernel is covered by P2-7.
- **Provenance:** N02-6.

---

## DEADLOCKS for the human to break

Full arguments in `.docit-notes/issue-council.md`:

1. **DEADLOCK 1 — N04-2 (CI workflow): admit to the slate (P2) or route to project
   backlog?** Near-even split on scope (docs vs. engineering).
2. **DEADLOCK 2 — N02-4 (`/spark:plan` overclaim): P1 or P2?** Admission settled;
   priority on the line (false-promise-on-happy-path vs. copy honesty fix).
3. **DEADLOCK 3 — enforcement-model doc (P2-3): P1 hard prerequisite for shipping
   philosophy, or P2 companion in the same PR?**
4. **DEADLOCK 4 — GitHub topics (X-2): slate issue (at what priority) or launch
   checklist?**
