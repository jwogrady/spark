# Feedback from 02-Adopter to 06-Coach

## Verify your audit against actual docs tree and quickstart path

**Status: AUDIT CORRECT — gaps are real and will block a newcomer's first win.**

You identified the docs tree correctly. I verified it against `find docs/ -type f` — all files you cited exist. Your gap assessment is sound, but I can now prioritize them through the Adopter lens: *which gaps block someone going from zero to first value?*

## High-priority gaps that break the quickstart narrative

### Gap 1: No `commit` how-to (MEDIUM → HIGH)

Your note: "commit is a Ship-stage skill but has no standalone guide."

**Quickstart implication:** The quickstart tells users to run `/spark:commit`, but if they land in how-to/ looking for context, there's a blank. Currently they're directed to `solve.md` → `ship.md`, but `commit` is its own skill with its own micro-workflow (stage 5a per ground-truth.md). 

**Action:** Create `docs/how-to/commit.md` before Phase 3, or explicitly note in `ship.md` that `/spark:commit` runs first, then `/spark:ship` — but don't expect a learner to infer this.

### Gap 2: No `docit` or `codify` how-to (MEDIUM)

Your note: "Two of the more complex skills have no how-to at all."

**Quickstart implication:** The quickstart does *not* cover `docit` or `codify` — correctly, because they're advanced authorship crews. **However**, the ground-truth and hero promise "13 agent personas collaborate through shared notes to glow up your public docs." If a newcomer finishes their first Ideate→Ship cycle and asks "how do I actually use this 13-agent thing?", the docs have nothing. This is deferred value, but it should not be invisible.

**Action:** Create stub `docs/how-to/docit.md` and `docs/how-to/codify.md` before Phase 3, even if they say "coming soon" or link to the skill's frontmatter. Otherwise the promise in the hero section has no landing page.

### Gap 3: Tutorial for setup skills (HIGH)

Your note: "No tutorial for setup skills. A reader who wants to run `bootstrap` or `connect` for the first time has no guided lesson."

**Quickstart implication:** My quickstart (02) uses `bootstrap` as a *potential* next step after the first Ideate→Ship cycle. If a user wants to set up a *new* project from scratch (bootstrap + connect), they have no tutorial. The existing `build-your-first-project.md` tutorial assumes they already have a project; `bootstrap` assumes they don't.

**Action:** Create `docs/tutorials/set-up-a-new-project.md` covering `bootstrap` → `connect` → `install-git-hooks` → `doctor` as a prerequisite tutorial, *before* `build-your-first-project.md`. This unblocks the "start from nothing" path.

## Lower-priority gaps (don't block the quickstart)

- **`list-skills` missing from CLI reference:** Minor; the skill is real but underdocumented. Fix in Phase 3, not critical.
- **No agent-frontmatter reference:** Useful for skill authors, not for quickstart-phase users. Medium priority.
- **ADRs not cross-linked:** Discoverability issue only; doesn't block first value.

## Mode-purity note (FYI)

Your audit correctly identifies that `docs/architecture/spark-internals.md` sits outside the four-mode tree. It's explanation-adjacent but living in `docs/architecture/`. **For a newcomer following the quickstart, this is not a blocker** — they won't need internals until they author a skill, which is advanced. But it *is* a catalog debt for Phase 3.

---

## Recommendation for Phase 3

**Must-do before shipping:** Create three docs:
1. `docs/how-to/commit.md` — task guide for `/spark:commit` (one skill, discrete workflow)
2. `docs/how-to/docit.md` — link to SKILL.md + overview of the 13-agent orchestration 
3. `docs/tutorials/set-up-a-new-project.md` — guided lesson for `bootstrap` → `connect` → hooks → doctor

**Nice-to-do:** Reorganize `docs/architecture/spark-internals.md` into `docs/explanation/spark-internals.md` for consistency.

**Current impact:** The quickstart *will work* without these, but it leaves implicit promises (setup tutorial, docit overview, commit guide) that break downstream personas' expectations.
