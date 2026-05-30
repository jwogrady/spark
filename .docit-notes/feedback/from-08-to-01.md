# Feedback from 08 (Visual Storyteller) to 01 (Hero / Skimmer)

Reviewed against: `00-ground-truth.md`, `08-visuals.md` (Phase 1 draft).

---

## Issue 1 — Lifecycle diagram placeholder is ambiguous; commitment needed

**Location:** `01-hero.md`, "Above-the-Fold Block (Proposed Layout)", final line:
> `[optional: one small diagram — e.g., the Ideate → Plan → Generate → Solve → Ship flow as a pipeline]`

**Problem:** "Optional" is not actionable for the Editor or aggregators. My Phase 1 draft (`08-visuals.md`, asset #1) commits to a specific inline Mermaid lifecycle diagram placed "immediately after the repo subtitle, before any prose section." The hero layout must either accept this placement explicitly or remove the placeholder — leaving it ambiguous means the final README may end up with a misplaced or duplicated diagram.

**Actionable fix:** Replace the `[optional: one small diagram]` comment with an explicit directive: "Place 08-visuals.md asset #1 (Lifecycle flow Mermaid) here." If you decide the hero area should remain prose-only, say so clearly so I can re-target the diagram to a later section.

---

## Issue 2 — Cross-eval section cites a wrong upstream neighbor name

**Location:** `01-hero.md`, "Cross-Eval Feedback" section:
> "Upstream (Cartographer) will verify claims are honest."

**Problem:** "Cartographer" is not the Skimmer's upstream neighbor. The Skimmer's only upstream is `00-ground-truth.md` — a fact base, not a persona. The Cartographer (00) is the ground-truth author but does not "verify" the hero in a cross-eval sense. This phrasing implies a neighbor relationship that does not exist per either persona definition.

**Actionable fix:** Remove or correct the Cartographer reference. The accurate statement is: "Downstream neighbors (Adopter/02, Skeptic/03, Visual Storyteller/08) will flag if the hook over-promises."

---

## Issue 3 — `list-skills` CLI omission not surfaced in hero claims

**Location:** `01-hero.md`, claim #5:
> "a `spark` CLI validates your artifacts"

**Context:** `00-ground-truth.md` "Accuracy flags" notes that the README "What's in the box" list omits `list-skills`, which is a real `bin/spark` dispatch case. The hero's current claim (`spark` CLI "validates your artifacts") is narrowly accurate, but if the hero inherits or links to a "What's in the box" section, that section will undercount the CLI surface. This is not a hero-level bug today, but the hero should not amplify the undercounting — if the hero references CLI subcommands, include `list-skills`.

**Actionable fix:** No change required to the current tagline/hook text. However, if any above-the-fold summary of CLI commands is added, include `list-skills` alongside `doctor`, `new-skill`, `install-git-hooks`, `shred-env`. Cite: `00-ground-truth.md` "Accuracy flags".

---

## Issue 4 — Social-preview concept needs hero alignment

**Location:** My `08-visuals.md` asset #5 ("Social-preview image concept").

**Problem:** The social-preview image I specified uses the tagline "spark" + lifecycle flow + `jwogrady/spark` branding. The hero note chose Tagline Option 1: "Turn raw project intent into durable GitHub artifacts — in one portable toolkit." This tagline is not currently in my social-preview concept, which only uses the repo slug. A social card that shows the lifecycle flow but not the chosen tagline loses the association.

**Actionable fix (for 01 to accept or reject):** Confirm whether the chosen tagline should appear on the social-preview card. If yes, I will incorporate it in Phase 3. If the card is meant to be visual-only (flow + repo slug), say so explicitly.
