# Cross-eval feedback: from 07 (Contributor) to 06 (Coach/Diátaxis)

**Reviewer:** Persona 07 — Contributor
**Reviewed:** `06-diataxis.md`

---

## Overall assessment

06 is thorough and well-cited. The gap analysis is honest and maps cleanly to
the verified docs tree. Two issues below require correction or clarification
before the Diátaxis plan is used as input by the aggregators.

---

## Specific issues

### 1. BLOCKING — skill directory structure mismatch (optional subdirs)

**Location:** "No `write-a-skill` how-to" gap entry and, by implication, any
place the Coach describes the contribution/extension surface.

**Issue:** The Coach's gap note correctly identifies that `docs/how-to/write-a-skill.md`
does not exist. However, the optional skill layout documented in 07-contributing.md
(`REFERENCE.md`, `EXAMPLES.md`, `scripts/`) does NOT match what `CONTRIBUTING.md`
actually specifies. The `CONTRIBUTING.md` §"Proposing a skill" lists the optional
subdirectories as `references/` and `agents/` — not `REFERENCE.md`/`EXAMPLES.md`.
The `skills/write-a-skill/SKILL.md` uses yet a third convention (`REFERENCE.md`,
`EXAMPLES.md`, `scripts/`).

These are two different optional-structure specs in the same repo. The Diátaxis
plan calls for a `write-a-skill` how-to — that how-to cannot be written until the
canonical layout is decided. The Coach's gap analysis should flag this
inconsistency explicitly so the Issue Council can resolve it.

**Ground-truth anchor:** `CONTRIBUTING.md` §"Proposing a skill" (`references/`,
`agents/`) vs. `skills/write-a-skill/SKILL.md` §"Skill Structure"
(`REFERENCE.md`, `EXAMPLES.md`, `scripts/`). The `00-ground-truth.md` does not
resolve this — it only cites `skills/write-a-skill/SKILL.md` for "When to Split".

**Recommended action:** Add this inconsistency to the Coach's priority gaps table
under Reference, severity High. Tag it: "canonical skill layout spec needed before
`write-a-skill` how-to can be written."

---

### 2. The existing `CONTRIBUTING.md` is not acknowledged — gap overstated

**Location:** "No `commit` how-to" gap and the overall how-to gap analysis.

**Issue:** The Coach identifies missing how-to guides for `commit`, `write-a-skill`,
`fork-init`, `docit`, and `codify`. These gaps are real. However, the Coach does
not note that `CONTRIBUTING.md` already exists at the repo root and covers:
branch naming, conventional commits, PR rules, the skill-proposal process, and
attribution rules. This file partially fills the `write-a-skill` and `commit`
how-to gaps for contributors, even if it is not formally in the Diátaxis tree.

This matters because the how-to gap analysis implies these topics have zero
coverage, which is not accurate. A reader pointed to `CONTRIBUTING.md` can
already learn the contribution workflow. The gaps are real but narrower than the
Coach's current framing suggests.

**Recommended action:** Add a note to the how-to gaps section: "A `CONTRIBUTING.md`
exists at the repo root covering branch naming, commit rules, and skill proposal.
Gaps are partially filled for contributors but not surfaced in the Diátaxis tree."
Lower the severity of "No `write-a-skill` how-to" from High to Medium (given the
partial coverage from `CONTRIBUTING.md`); keep High only for the canonical skill
layout inconsistency identified in issue 1 above.

**Ground-truth anchor:** `CONTRIBUTING.md` — present at repo root (verified via
`ls /`). `00-ground-truth.md` does not mention `CONTRIBUTING.md` — this is itself
an accuracy flag worth adding to ground truth.

---

### 3. No action needed — `docs/README.md` verification deferred correctly

**Location:** "Cross-mode navigation" section.

**Status:** The Coach correctly defers verification of `docs/README.md` content
to Phase 2. No issue. Confirming that `docs/README.md` exists (from the ground
truth `find docs/ -type f` listing it is inferred; 06 should verify in Phase 3).

---

### 4. Minor — `write-a-skill` how-to cross-reference gap in 07

**Location:** "No `write-a-skill` how-to" gap.

**Note for 06's own revision:** The Coach flags the missing `docs/how-to/write-a-skill.md`,
and 07's draft tells contributors to "follow the write-a-skill how-to
(`skills/write-a-skill/SKILL.md`)". The 07 draft currently points to the
*skill file*, not a *docs how-to*, because no docs how-to exists. This is
consistent — 07 cites what exists — but it means the Contributor note and the
Coach's gap analysis are aligned: the how-to is missing and `SKILL.md` is a
partial substitute. No contradiction; both notes should continue to flag this gap
for Issue Council.

---

## Summary of blocking issues

| # | Issue | Severity | Action required |
|---|---|---|---|
| 1 | Two conflicting optional skill layout specs (`CONTRIBUTING.md` vs. `write-a-skill/SKILL.md`) | High — blocks writing the how-to | Add to priority gaps table; flag for Issue Council |
| 2 | `CONTRIBUTING.md` existence unacknowledged — gaps overstated | Medium | Add note; revise severity of write-a-skill gap |
