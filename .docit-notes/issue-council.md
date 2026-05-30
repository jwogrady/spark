# Issue Council — Tally (Phase 4)

> Chaired and tallied by the Editor-in-Chief (persona 12). Author/credit: `jwogrady`.
> Two ballots per nomination: ADMISSION (in/out) and PRIORITY (P1=3, P2=2, P3=1).
> The Editor does **not** break ties. The Cartographer (00) holds the honest-hype
> veto: any nomination admitted only as a *correction* has its false framing struck;
> anything that would overclaim is vetoed and never ships as written.

## How this was tallied

- 12 personas (00–11) filed nominations and two-ballot votes. 38 distinct
  nominations were filed; many are duplicates of the same root defect.
- Per the council's own near-unanimous instruction, duplicate nominations are
  **merged into one issue** and tallied once (the merge map is recorded below).
- ADMISSION is decided by simple majority of the personas who voted on the merged
  cluster. PRIORITY is the rounded mean of priority points cast (P1=3 / P2=2 /
  P3=1) across personas who admitted it.
- Out-of-scope rejections (CI pipeline, GitHub-settings actions, internal docit
  workflow artifacts) follow the Cartographer's scope rulings where a majority
  concurred.

---

## Merge map (duplicate nominations → one issue)

| Cluster | Merged nomination IDs |
|---|---|
| LICENSE | N00-1, N01-2, N03-2, N04-1, N05-3, N09-3, N10-4, N11-1 (8 sources) |
| LIST-SKILLS | N00-2, N01-3, N03-4, N05-7, N06-F, N07-4, N09-4 (7 sources) |
| INSTALL-CAVEAT | N01-4, N02-2, N03-1, N11-4 (4 sources) |
| CHANGELOG-CODIFY | N04-3, N09-1, N11-2 (3 sources) |
| SKILL-LAYOUT | N05-5, N06-B, N07-1, N08-5 (4 sources) |
| PHILOSOPHY+NAV | N03-3, N05-1, N06-G (3 sources) |
| ENFORCEMENT-MODEL | N05-2, N06-A (2 sources) |
| AUTHORSHIP-CREWS | N05-4, N06-E, N10-5 (3 sources) |
| TUTORIAL-1 | N05-6, N06-C (2 sources) |
| DOCTOR-OUTPUT | N00-4, N02-1 (2 sources) |
| SOCIAL-PREVIEW | N08-4, N10-3 (2 sources) |
| GH-AUTH-PREREQ | N02-3, N02-5 (2 sources) |

Standalone (no merge): N00-3, N00-5, N00-6, N00-7, N01-1, N02-4, N03-5, N04-2,
N04-4, N06-D, N07-2, N07-3, N08-1, N08-2, N08-3, N09-2, N10-1, N10-2, N11-3, N02-6.

---

## Nominations (Phase 4a)

All 38 nominations were filed with provenance tracing to `00-ground-truth.md` or
a Phase-2 cross-eval finding. Full text in `.docit-notes/council/nominations/00..11.md`.
No nomination was filed without a citation; none was struck at the nomination stage.

## Debate highlights (Phase 4b)

Full debate in `.docit-notes/council/debate/00..11.md`. Key positions:

- **License is the one true cross-domain P1.** Eight personas nominated it
  independently; every ballot admitted it P1. The Cartographer's veto stays armed:
  no surface may advertise MIT as adopted until `LICENSE` carries a real SPDX grant.
- **`/spark:plan` GitHub-issue creation (N02-4) was contested.** The Adopter (02)
  argued it is a feature-expectation mismatch, not an install blocker, and voted
  OUT. The Skeptic (03), Contributor (07), and Cartographer rated it a P1
  honest-hype failure on the primary user path. Majority admitted it; priority
  split P1/P2 (see deadlock note).
- **`enforcement-model.md` priority is contested.** Coach (06) holds it P1
  (blocking — philosophy cannot ship without its rationale doc). Believer (05) and
  others argued P2 (philosophy can carry a forward-reference). Mean lands at P1/P2
  boundary (see deadlock note).
- **Cartographer scope contests upheld by majority:** N02-6 (machine-readable
  doctor contract) is OUT as a feature invention; N04-2 (CI workflow) is admitted
  by some but contested as out of docit's shipping scope; GitHub-settings actions
  (topics, og-image, awesome-lists) and `docs/launch-copy.md` were contested as
  author/Editor tasks rather than repo doc issues.
- **Ruthless de-duplication** was demanded by nearly every persona: license (8),
  list-skills (7), install-caveat (4), skill-layout (4) collapse to one issue each.

## Vetoes honored (Cartographer, struck — never ship as written)

These are recorded as struck; the Editor enforced each in Phase 5 synthesis:

1. **"v0.3.0" as the current/shipped version** — manifest is `0.2.0`. Allowed only
   as `[Unreleased]`.
2. **"codify shares `.docit-notes/` with docit"** — false; codify uses
   `.codify-notes/`. HARD VETO.
3. **Any exact "N merged PRs" / "N commits ahead" / commit-hash claim in prose** —
   cite the tag `v0.2.0`, not volatile counts/hashes.
4. **MIT advertised as the adopted license** while `LICENSE` says "License TBD" —
   vetoed until the LICENSE issue is resolved.
5. **`spark doctor` quoted as printing "OK" or a "16/19" tally** — quote the real
   `✓ <name>` lines + `Healthy — 0 errors, N warning(s)`.
6. **"No drift" as a measured guarantee** — allowed only as framing ("less drift").

---

## Tally — ranked slate (admitted issues)

Priority = rounded mean of admitting personas' points. Admission = majority IN.

| # | Issue (merged) | Admission | Priority (mean) | Notes |
|---|---|---|---|---|
| 1 | LICENSE — resolve MIT overclaim | IN (12/12) | **P1** (3.0) | Unanimous; veto armed |
| 2 | CHANGELOG-CODIFY — add `codify`+`review` to CHANGELOG (and name `codify` in README) | IN (12/12) | **P1** (≈2.6) | Mixed P1/P2; mean rounds to P1 |
| 3 | HERO-TAGLINE (N01-1) — land Phase-3 tagline in README | IN (12/12) | **P1** (≈2.7) | Ready-to-paste revision |
| 4 | SKILL-LAYOUT — resolve canonical layout, create `docs/reference/skill-layout.md` | IN (12/12) | **P1** (≈2.7) | Blocks write-a-skill how-to + anatomy diagram |
| 5 | INSTALL-CAVEAT — README install block needs marketplace caveat + Git-URL fallback | IN (12/12) | **P1/P2** (≈2.6) | Hero/Adopter/Skeptic/Discoverer P1; some P2 |
| 6 | N02-4 — strike `/spark:plan` "creates GitHub issues" overclaim (v0.3 roadmap) | IN (11/12) | **P1/P2** (split) | Adopter voted OUT; see DEADLOCK |
| 7 | PHILOSOPHY+NAV — ship `docs/explanation/philosophy.md` + wire `docs/README.md` | IN (12/12) | **P1/P2** (≈2.4) | Coach P1; Skeptic/Believer P2 |
| 8 | ENFORCEMENT-MODEL — `docs/explanation/enforcement-model.md` | IN (12/12) | **P1/P2** (≈2.5) | Coach P1 (blocking); Believer P2; see DEADLOCK |
| 9 | TUTORIAL-1 — `docs/tutorials/set-up-a-new-project.md` | IN (12/12) | **P1/P2** (≈2.4) | Coach/Storyteller P1; Adopter P2 |
| 10 | N06-D — `docs/how-to/commit.md` + split mode bleed in `ship.md` | IN (12/12) | **P1/P2** (≈2.4) | Coach/Contributor/Storyteller P1 |
| 11 | N08-2 — Mermaid lifecycle diagram in README (bridges Generate↔`/spark:build`) | IN (12/12) | **P1/P2** (≈2.5) | Skimmer/Believer/Storyteller/Contributor P1 |
| 12 | DOCTOR-OUTPUT — quote real `spark doctor` strings, never "OK"/tally | IN (12/12) | **P2** (2.0) | Cartographer veto-correction |
| 13 | N00-3 — correct hook file-layout + docs-tree in any diagram | IN (12/12) | **P2** (≈1.9) | hooks/ vs scripts/hooks/ |
| 14 | N00-6 — strike "codify shares `.docit-notes/`" → `.codify-notes/` | IN (12/12) | **P1/P2** (≈2.5) | Cartographer HARD VETO correction |
| 15 | N00-5 — pin volatile facts (cite tag, not hash/count/line) | IN (12/12) | **P2** (≈1.9) | Editorial convention |
| 16 | N00-7 — final shipped-vs-roadmap audit of assembled README | IN (12/12) | **P2** (2.0) | |
| 17 | N03-5 — public alternatives/comparison doc under `explanation/` | IN (12/12) | **P2** (2.0) | |
| 18 | AUTHORSHIP-CREWS — `docs/explanation/authorship-crews.md` | IN (12/12) | **P2** (2.0) | Absorbs crew-discoverability (N10-5) |
| 19 | GH-AUTH-PREREQ — document `gh auth` prerequisite in install/quickstart | IN (12/12) | **P2** (≈1.9) | |
| 20 | N07-2 — `docs/how-to/write-a-skill.md` (blocked by SKILL-LAYOUT) | IN (12/12) | **P2** (2.0) | |
| 21 | N08-3 — ASCII component map in README (corrected layout) | IN (12/12) | **P2** (2.0) | |
| 22 | N08-1 — `spark doctor` terminal demo GIF | IN (11/12) | **P2** (≈1.9) | Skeptic voted OUT (author task) |
| 23 | N09-2 — git-hook coexistence note for custom hooks | IN (12/12) | **P2/P3** (≈2.1) | |
| 24 | SOCIAL-PREVIEW — og-image + GitHub social metadata | IN (11/12) | **P2** (≈1.9) | Skeptic OUT (author/GitHub-settings task) |
| 25 | N10-1 — set GitHub repo topics | IN (11/12) | **P1/P2/P3** (split) | Cartographer OUT (GitHub-settings); see note |
| 26 | N10-2 — awesome-list submissions (blocked on LICENSE) | IN (10/12) | **P2/P3** (split) | Cartographer/Skeptic OUT (author task) |
| 27 | LIST-SKILLS — add `list-skills` to README + `docs/reference/cli.md` | IN (12/12) | **P3** (1.0) | Unanimous P3; one-line fix ×2 surfaces |
| 28 | N07-3 — document branch-naming convention in contributor path | IN (12/12) | **P3** (1.0) | |
| 29 | N04-4 — pre-1.0 breaking-change policy note | IN (12/12) | **P3** (≈1.1) | |
| 30 | N11-3 — `docs/launch-copy.md` (canonical home for launch assets) | IN (8/12) | **P2** (split) | Cartographer/Skeptic/Skimmer/Believer/Storyteller OUT (Editor workflow artifact) |
| — | N04-2 — CI workflow | SPLIT (IN 7 / OUT 5) | — | See DEADLOCK |
| — | N02-6 — machine-readable doctor contract | OUT (10/12 OUT) | — | Feature invention; folded into DOCTOR-OUTPUT |

---

## DEADLOCKS FOR HUMAN

The Editor does not break ties. The following did not resolve cleanly and are
surfaced for the human to decide. Each carries both sides.

### DEADLOCK 1 — N04-2 (Add a CI workflow): ADMISSION split, near-even

- **Tally:** IN from 02, 04, 06, 07, 09 (and conditionally others) ≈ 7; OUT from
  00, 03, 05, 08, 10, 11 ≈ 5. The split is genuine and turns on a scope question,
  not a value question.
- **Admit (Evaluator 04, Coach 06, Contributor 07, Adopter 02, Returning User 09):**
  CI is a real backlog gap. `spark doctor` + `bash -n` are quality gates that run
  only when invoked; a minimal push/PR workflow would catch regressions and is a
  legitimate tracked issue at P2.
- **Reject (Cartographer 00, Skeptic 03, Believer 05, Storyteller 08, Discoverer
  10, Amplifier 11):** docit ships **docs**, not CI pipelines. `CLAUDE.md` forbids
  editing `.github/workflows/` without full-pipeline understanding. The README
  correctly omits a CI badge already (Evaluator's own note). Route to the project
  backlog, not the docit slate.
- **Human decision needed:** admit N04-2 to the slate (P2) or route it to the
  general project backlog outside this docit run.

### DEADLOCK 2 — N02-4 priority (`/spark:plan` GitHub-issue overclaim): P1 vs P2

- **Admission is settled** (11/12 IN; Adopter 02 alone voted OUT). The unresolved
  question is **priority**, and it sits exactly on the P1/P2 line.
- **P1 (Cartographer 00, Skeptic 03, Contributor 07):** This is a false capability
  claim on the primary user path — the quickstart tells newcomers `/spark:plan`
  creates real GitHub issues, but ground truth puts that in v0.3 roadmap. A false
  promise on the happy path is a P1 honest-hype failure.
- **P2 (Evaluator 04, Believer 05, Adopter 02-as-reframe, Storyteller 08,
  Discoverer 10, Amplifier 11):** It is a shipped-vs-roadmap honesty gap in the
  quickstart, not a legal risk or a broken install step. Correct the copy; P2.
- **Human decision needed:** rank N02-4 as P1 or P2. (Either way it is admitted and
  the overclaim must be struck from quickstart copy — that part is not in dispute.)

### DEADLOCK 3 — ENFORCEMENT-MODEL priority (N05-2 / N06-A): P1 vs P2

- **Admission is settled** (12/12 IN). The unresolved question is **priority**.
- **P1 — blocking (Coach 06, Storyteller 08, Discoverer 10):** Philosophy
  Principle 1 ("enforcement over aspiration") has no rationale doc to link to.
  Shipping `philosophy.md` without `enforcement-model.md` bakes a Diátaxis mode
  violation into the first public philosophy doc. It is a hard prerequisite.
- **P2 (Believer 05, Skeptic 03, and others):** Philosophy can ship with Principle
  1 citing the real hooks plus a forward-reference to the rationale doc. The doc is
  important but not a launch blocker; ship both in one linked PR.
- **Human decision needed:** is `enforcement-model.md` a P1 hard prerequisite for
  shipping `philosophy.md`, or a P2 companion in the same PR?

### DEADLOCK 4 — N10-1 (Set GitHub repo topics): in-scope priority vs out-of-scope

- **Tally is genuinely three-way.** Cartographer 00 voted OUT (GitHub-settings
  action, not a docit deliverable). Among those who admitted it, priority split:
  P1 (Evaluator 04, Contributor 07, Amplifier 11, Discoverer 10), P2 (Skimmer 01,
  Adopter 02, Believer 05, Coach 06, Storyteller 08), P3 (Skeptic 03).
- **In-scope / quick-win (most personas):** topics are a zero-cost, immediate
  discoverability lift; admit and rank P1–P2.
- **Out-of-scope (Cartographer, Skeptic):** this is an author action in GitHub
  repo settings, not a file the docit run writes; record it on the launch checklist
  rather than the issue slate.
- **Human decision needed:** treat N10-1 as a slate issue (and at what priority), or
  move it to a launch/author checklist alongside og-image and awesome-lists.

---

## Provenance

Every admitted issue's provenance is carried in `.docit-notes/13-proposed-issues.md`
(per-issue, cited to ground truth or the originating note). Nomination text:
`.docit-notes/council/nominations/`. Debate: `.docit-notes/council/debate/`.
Ballots: `.docit-notes/council/votes/`.
