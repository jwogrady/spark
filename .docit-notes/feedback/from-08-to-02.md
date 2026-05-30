# Feedback from 08 (Visual Storyteller) to 02 (Quickstart / Adopter)

Reviewed against: `00-ground-truth.md`, `08-visuals.md` (Phase 1 draft).

---

## Issue 1 — `spark doctor` output claim over-promises a specific count display

**Location:** `02-quickstart.md`, "Install the plugin" section:
> "You should see all 16 skills listed as ✓ and all docit/codify agents verified (13 + 6 = 19 agents)."

**Problem:** `00-ground-truth.md` describes `spark doctor` as: "validates plugin manifests are JSON, hooks JSON + guard executable, every skill's `name:`/`description:` frontmatter, every `agents/**/*.md` frontmatter, and whether git hooks are installed." It does not confirm the output format. The claim "see all 16 skills listed as ✓" and "(13 + 6 = 19 agents)" asserts specific output text that has not been verified in the ground truth. A prospective user following this guide who gets different output formatting will lose trust immediately.

**Actionable fix:** Remove the specific "✓" and count format. Replace with: "You should see the doctor complete with no errors — it validates manifests, hooks, skill frontmatter, and agent files." If you have verified the exact output format (e.g., by running `spark doctor` and reading the output), add that verification to `00-ground-truth.md` first, then cite it here.

---

## Issue 2 — `/spark:plan` claim about issue count is unverified

**Location:** `02-quickstart.md`, "Stage 2: Plan" walkthrough:
> "Spark will decompose it into 2–5 GitHub issues with acceptance criteria and create a milestone."

**Problem:** `00-ground-truth.md` confirms `plan` is a skill that "decompose[s] into GitHub issues + a milestone" (cited to `skills/plan/SKILL.md`, "Stage 2"). However, the "2–5 GitHub issues" range and "acceptance criteria" detail are not present in the ground truth — they may be implementation details from the skill's prompt, but they have not been verified as a ground-truth claim. Additionally, `00-ground-truth.md` ROADMAP section shows "v0.3: Plan ↔ GitHub — generate issues/milestone from a problem statement" as a ROADMAP item, suggesting direct GitHub issue creation may not be fully shipped. This is a potential over-promise.

**Actionable fix:** Verify whether `/spark:plan` creates actual GitHub issues in the current version (v0.2) or generates issue drafts/templates. If GitHub issue creation is not yet mechanical (v0.3 ROADMAP), revise to: "Spark will decompose it into a set of scoped work items with acceptance criteria." Remove "2–5" unless verified. Cite the ground truth ROADMAP section: `00-ground-truth.md` "ROADMAP".

---

## Issue 3 — Screenshot reference from me (08) is undeliverable as promised

**Location:** `02-quickstart.md`, "Neighbors" section:
> "08-visuals.md — may show walkthrough screenshots."

**Context:** My Phase 1 draft (`08-visuals.md`) specifies a `spark doctor` GIF (asset #3) and code-fence blocks — not a walkthrough screenshot of the full Ideate → Ship cycle. The walkthrough in the quickstart involves multiple Claude Code interactions inside a project session; capturing those as a GIF or screenshot is not practically automatable and was not included in my asset plan.

**Actionable fix (for 02 to revise):** Update the neighbor note from "may show walkthrough screenshots" to "provides a `spark doctor` terminal GIF and lifecycle flow diagram." If you want a screenshot of a specific stage (e.g., `/spark:plan` output), flag it explicitly as a capture request so I can add it to my asset list in Phase 3.

---

## Issue 4 — GitHub token prerequisite understates complexity

**Location:** `02-quickstart.md`, "Prerequisites and gotchas", item 2:
> "When you run `/spark:ship`, Claude will ask for `gh` permissions to create the PR. You need a GitHub CLI token configured (`gh auth login` if not already done)."

**Problem:** This is accurate as stated, but `00-ground-truth.md` does not verify `gh` CLI integration as a verified capability of the plugin — it is a system-level prerequisite. The framing "Claude will ask for `gh` permissions" conflates Claude Code's permission model with the `gh` CLI auth requirement. A user without `gh` installed at all will fail before the auth step.

**Actionable fix:** Restate as: "PR creation requires the GitHub CLI (`gh`) installed and authenticated (`gh auth login`). If `gh` is not installed, `spark ship` will fail at the push step." This is not a visual issue but it directly precedes where a `spark doctor` screenshot (my asset #3) would appear — an honest prerequisite check protects the credibility of the demo.
