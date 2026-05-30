# Feedback from 08 (Visual Storyteller) to 06 (Coach / Diátaxis)

Reviewed against: `00-ground-truth.md`, `08-visuals.md` (Phase 1 draft).

---

## Issue 1 — Docs-tree ASCII in my note misrepresents the actual layout; 06 must flag this

**Location:** `08-visuals.md`, asset #6 ("Docs-structure visual"), and `06-diataxis.md`, "Mode 3 — Reference" and "Mode 4 — Explanation" sections.

**Problem:** My Phase 1 docs-tree ASCII shows:
```
docs/
├── explanation/
│   ├── adr/            # ADR-0001..0003
│   └── architecture/
```
But `00-ground-truth.md` "Docs (Diátaxis)" section lists the actual paths as:
- ADRs: `docs/adr/0001..0003` (a sibling of `explanation/`, not nested inside it)
- Architecture: `docs/architecture/spark-internals.md` (a sibling, not nested under `explanation/`)

Your note (06) correctly identifies both as misplaced ("sits outside `docs/explanation/`", "`docs/architecture/` is outside the four-mode tree"), but does not produce a corrected tree. My asset #6 diagram is wrong as drawn and will mislead readers if published without correction.

**Actionable fix (for 06):** In Phase 3, produce or confirm the corrected docs tree. I will update asset #6 in Phase 3 to reflect the actual layout, with a comment noting which items are outside the mode tree. The corrected structure should read:
```
docs/
├── tutorials/
├── how-to/
├── reference/
├── explanation/
├── adr/                # outside mode tree — recommend moving to explanation/
├── architecture/       # outside mode tree — recommend moving to explanation/
└── glossary.md         # outside mode tree — recommend cross-linking from reference/
```

---

## Issue 2 — The note does not distinguish current-state from recommendations

**Location:** `06-diataxis.md`, "Mode 3 — Reference" gaps section and "Mode 4 — Explanation" gaps section.

**Problem:** The Coach's note lists gaps (missing tutorials, how-tos, explanation docs) without a consistent "CURRENT STATE vs. RECOMMENDED" separator. For a reader of the note (aggregator 10/11 or Editor), it is ambiguous whether items like "No `commit` how-to" describe the current repo state or a recommended addition. My visual plan depends on the docs tree reflecting what exists today — I cannot draw an accurate tree from a list that mixes as-is with to-do.

**Actionable fix:** Add a clear two-part structure to each mode section: "What exists (verified)" and "Gaps (recommended additions)." This does not require new research — the ground truth already separates shipped from roadmap. Verified items come from `00-ground-truth.md` "Docs (Diátaxis)" section; gap items are your analysis. Without this separation, downstream personas (including me) cannot safely distinguish fact from recommendation.

---

## Issue 3 — No visual placement guidance for the Diátaxis section of the README

**Location:** `06-diataxis.md` entire draft; `08-visuals.md` asset #6.

**Problem:** My asset #6 (docs-tree ASCII) is marked "optional — only if the Diátaxis section is long." Your note does not indicate whether a Diátaxis / Documentation section will exist in the README, how long it will be, or whether it expects a visual. If this section is not recommended for the README (e.g., docs live at `docs/` and are linked), the diagram is unnecessary. If it is recommended, the placement and scope should be explicit.

**Actionable fix:** State in your note whether you recommend a "Documentation" section in the README. If yes, provide the approximate prose length so I can determine whether asset #6 is warranted. If the docs tree is better served by a `docs/README.md` index (which your note recommends), say so explicitly and I will drop asset #6 from the README visual plan.

---

## Issue 4 — `docs/README.md` existence is deferred; this blocks my visual plan

**Location:** `06-diataxis.md`, "Cross-mode navigation" section:
> "`docs/README.md` exists (`find` output). It should anchor all four mode directories... If it already does this, the requirement is met; if not, it is a gap. (Verification of `docs/README.md` content is deferred to Phase 2.)"

**Problem:** You deferred verification of `docs/README.md` content to Phase 2 but left no finding. My visual plan assumes the docs tree appears somewhere — either in the README or in `docs/README.md`. Without knowing the content of `docs/README.md`, I cannot confirm whether asset #6 (the docs-tree ASCII) is redundant or necessary.

**Actionable fix:** In Phase 2 (this phase), read `docs/README.md` and record what it contains. If it already has a mode-organized index, note that and I will drop asset #6. If it does not, flag it as a gap and I will keep asset #6 for the main README. This verification is concrete: `Read docs/README.md`.
