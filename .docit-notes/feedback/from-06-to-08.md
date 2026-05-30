# Feedback from 06 (Coach) to 08 (Visual Storyteller)

## Summary

The Visual Storyteller draft is focused, honest about what is not yet real (the social
preview image, the GIF), and well-cited. Two targeted issues need resolution before
the Coach can rely on the visual layer for the Diátaxis section.

---

## Issue 1 — Docs-tree visual (asset 6) is conditional on the wrong trigger

**Finding:** Asset 6 (the Diátaxis docs-tree ASCII diagram) is marked "optional — only
if the Diátaxis section is long." The condition is:

> "If persona 06's section enumerates the full docs tree, an ASCII tree makes it
> scannable without prose overhead."

**Problem:** The Coach's Diátaxis plan does not just enumerate the tree — it explains
the *why* behind four distinct modes and their gaps. The tree visual is useful
regardless of length because it gives readers a structural anchor before the prose
explains each mode. Conditioning it on length creates a fragile dependency: if the
published Diátaxis section is judged "short enough," the visual may be dropped, leaving
readers without a map.

More importantly, the ASCII tree in the draft omits the ADR directory correctly
placed under `docs/explanation/adr/` — the current tree shows `explanation/` → `adr/`
which matches the `00-ground-truth.md` §Docs entry for `docs/adr/0001..0003`. However,
the actual path in ground truth is `docs/adr/` (not `docs/explanation/adr/`). The
visual currently shows the ADRs nested inside explanation, which is the Coach's
*recommendation*, not the current reality.

**Recommendation:** (a) Make asset 6 a firm inclusion for any README or docs/index
that contains the Diátaxis section, not optional. (b) Correct the tree to show
`docs/adr/` at the top-level `docs/` directory (matching ground truth), with an inline
note that the Coach recommends cross-linking it from `explanation/`. Ship reality;
annotate the aspiration separately.

**Citation:** `00-ground-truth.md` §Docs — `docs/adr/0001..0003` listed at `docs/adr/`,
not inside `docs/explanation/`; `06-diataxis.md` §Mode 4 gap — "ADRs not cross-linked
from explanation" (a recommendation, not a current fact).

---

## Issue 2 — Lifecycle flow diagram (asset 1) uses stage labels that diverge from the canonical names

**Finding:** The Mermaid lifecycle diagram uses:

```
A([Ideate]) --> B([Plan]) --> C([Generate]) --> D([Solve]) --> E([Ship])
```

The `00-ground-truth.md` §Lifecycle table and `CLAUDE.md` §"The Lifecycle Skills"
consistently use: **Ideate → Plan → Generate → Solve → Ship** — these match exactly.
No issue there.

However, the Coach's plan and the ground truth both map the Generate stage to the
`build` skill, not a skill named "Generate". The Quickstart (02) and the ground truth
use `build` as the skill name and "Generate" as the stage name. The diagram is correct
as a stage-level visual. But the visual layer should make this distinction explicit
somewhere in its surrounding alt text or caption, because users will run
`/spark:build`, not `/spark:generate`, and the mismatch can confuse first-timers
scanning the README flow.

**Recommendation:** Add a brief caption beneath the diagram: "Stage names map to
skills: Ideate→`/spark:ideate`, Plan→`/spark:plan`, Generate→`/spark:build`,
Solve→`/spark:fix-issue`, Ship→`/spark:commit`+`/spark:ship`." This resolves the
stage-vs-skill naming gap for readers who move from the diagram to the Quickstart.

**Citation:** `00-ground-truth.md` §Lifecycle table — stage names and skill command
mapping; `00-ground-truth.md` §Lifecycle skills — `build` skill described as "Generate"
stage; `02-quickstart.md` — uses `build` as the skill at the Generate stage.
