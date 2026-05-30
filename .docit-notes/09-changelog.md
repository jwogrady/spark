# Changelog & Upgrade — Returning User Persona

## Persona

**The Returning User.** You have Spark installed. You want to know what changed in the next release, whether it breaks your workflow, and how to move forward cleanly.

**The question I ask:** *Does this version strengthen Spark or churn it? Are there breaking changes I need to handle?*

## Neighbors

**Upstream (I read):**
- `00-ground-truth.md` — verified capabilities, shipped vs. roadmap, accuracy flags.
- `04-trust.md` — (not yet present in Phase 1; Phase 2 will repair drift).

**Downstream (read me):**
- Aggregators (10-discoverer, 11-amplifier) — I surface the headline change worth promoting.
- Editor-in-Chief (12) — reconciles all notes into final `CHANGELOG.md`.

## Draft

### Release Notes — Next Version

**Headline:** Spark now ships with an internal-knowledge crew. Codify captures decisions and processes alongside the public-docs glow-up.

#### What Changed

1. **Plugin version remains 0.2.0; 15 commits unreleased.**
   - Current: v0.2.0 (commit `e4082cb`, tagged).
   - HEAD: unreleased (15 commits ahead since tag, most recent `3cd7d74`).

2. **Added: `codify` crew — internal knowledge capture.**
   - New skill `skills/codify/SKILL.md`: runs 6 specialist agents (`agents/codify/00-intake` through `05-editor`) to capture architectural decisions, processes, and glossary.
   - Parallels `docit` (public docs) but inward-facing. Coordinates through dedicated `.codify-notes/` (separate from `docit`'s `.docit-notes/`; kept out of repo per line 50 of SKILL.md).
   - Real subagents under `agents/codify/` with tiered models and scoped tools — same pattern as `docit`.
   - Verified: `git log v0.2.0..HEAD --oneline` commit `6ea36a7 feat: add codify internal-knowledge crew`. Source: `00-ground-truth.md` § "Review / knowledge skills" line 44.

3. **No removal of lifecycle skills — all 6 Ideate→Ship stages intact.**
   - `ideate`, `plan`, `build`, `fix-issue`, `commit`, `ship` remain unchanged.
   - Ground truth: `00-ground-truth.md` § "Lifecycle skills (16 total)" lines 24–30.

4. **`docit` crew refined but API stable.**
   - 13 personas (was 13 in v0.2.0, remains 13; no add/remove/rename).
   - Personas draft and cross-evaluate per dependency graph; Issue Council votes on proposed gaps.
   - Ground truth: `00-ground-truth.md` line 43. Note: `CHANGELOG.md` does not yet list `codify` — gap for Issue Council.

#### Breaking Changes

**None.** This is an additive release.

- All existing skills continue to work as before.
- No CLI subcommands removed or renamed.
- The `docit` workflow is unchanged; `codify` is opt-in (new crew runs alongside, shares notes).
- Git hooks (`commit-msg`, `pre-commit`) unchanged.
- Plugin manifests backward compatible (version bump pending in `.claude-plugin/plugin.json`).
- Ground truth: "Removed" section in CHANGELOG.md applies only to v0.2.0 (removed `caveman`, `handoff`, `.spark/` layer from prior version).

#### Migration Notes

**For existing Spark users:** No action required to adopt this release.

- Reinstall the plugin: `/plugin marketplace add jwogrady/spark` (marketplace updates automatically) → optionally `/plugin install spark` to refresh.
- To run `codify` in your project, invoke `/spark:codify` (new slash command; optional).
- All prior workflows (`/spark:ideate`, `/spark:plan`, etc.) remain stable.
- Git hooks installed via `spark install-git-hooks` need not be reinstalled (no changes to hook logic).

**For projects heavy on public docs:** The `docit` crew now includes an internal-knowledge counterpart via `codify`. You can run both (they coordinate through separate scratch dirs: `docit` uses `.docit-notes/`, `codify` uses `.codify-notes/`).

#### Upgrade Path

1. **Update the plugin:**
   ```
   /plugin marketplace add jwogrady/spark
   /plugin install spark
   ```
   No repo changes needed. The plugin updates in place.

2. **Optionally validate the installation:**
   ```bash
   spark doctor   # validates plugin layout, skills, hooks, and agents; exits non-zero if any error found
   ```

3. **Resume your workflow.** All existing `/spark:*` commands work as before.

## Claims & Citations

| Claim | Citation | Verification |
|-------|----------|---------------|
| Plugin version is 0.2.0 (shipped); HEAD is 15 commits unreleased. | `git rev-list v0.2.0..HEAD --count` = 15; `git rev-list -n1 v0.2.0` = `e4082cb`; HEAD = `3cd7d74`. | `.claude-plugin/plugin.json` version field remains `"0.2.0"`. |
| `codify` crew added: 6 agents under `agents/codify/`. | `00-ground-truth.md` line 44. | `ls agents/codify/` lists `00-intake.md`, `01-architect.md`, `02-product.md`, `03-ops.md`, `04-librarian.md`, `05-editor.md`. |
| `codify` is a real skill; uses dedicated `.codify-notes/` scratch. | `skills/codify/SKILL.md` line 50: "keep `.codify-notes/` out of the repo"; separate from `docit`'s `.docit-notes/`. | `git log v0.2.0..HEAD --oneline` shows commit `6ea36a7 feat: add codify internal-knowledge crew`. |
| All 6 lifecycle skills (Ideate→Ship) remain unchanged. | `00-ground-truth.md` lines 25–30. | `git diff v0.2.0..HEAD -- skills/ideate/ skills/plan/ skills/build/ skills/fix-issue/ skills/commit/ skills/ship/` shows no removals or renames. |
| No breaking changes; this is additive. | CHANGELOG.md § Removed (prior version only); no Removed entries in Unreleased. | `git show HEAD:CHANGELOG.md` Unreleased section lists only Changed/Added, no Removed. |
| Migration: no repo changes required. | Inference from "additive" + "no hook logic changes". | `scripts/hooks/commit-msg` and `scripts/hooks/pre-commit` have zero diffs since v0.2.0. |
| **Gap flagged:** `CHANGELOG.md` does not yet list `codify` entry. | `00-ground-truth.md` § "Review / knowledge skills" confirms crew exists (shipped); CHANGELOG.md Unreleased § Added contains no `codify` mention. | Grep `CHANGELOG.md` for "codify" returns no match. This is a documentation gap for Issue Council. |

## Cross-eval Feedback

### From 00-Cartographer (Honest-Hype Enforcement)

1. **RESOLVED: `.docify-notes` vs `.docit-notes` separation.** The original draft falsely claimed codify shares `.docit-notes/` with docit. Corrected per line 50 of `skills/codify/SKILL.md`: codify uses dedicated `.codify-notes/` (kept out of repo), separate from docit's `.docit-notes/`. Both claims in "What Changed" (item 2) and "For projects heavy on public docs" migration note now cite this.

2. **RESOLVED: Commit count corrected to 15.** Was stated as "13 commits unreleased"; verified via `git rev-list v0.2.0..HEAD --count` = **15**. Updated in "What Changed" item 1. (Distinction: 14 commits + 1 merge commit in history; 15 is the correct rev-list count.)

3. **RESOLVED: v0.2.0 commit hash corrected to `e4082cb`.** Was incorrectly cited as `e013d6b`; verified via `git rev-list -n1 v0.2.0` = `e4082cb`. Updated in "What Changed" item 1.

4. **RESOLVED: `spark doctor` output corrected.** Removed false claim that doctor "prints OK". Changed to: "`spark doctor` validates plugin layout, skills, hooks, and agents; exits non-zero if any error found" (per `00-ground-truth.md` line 102, verified). Updated in Upgrade Path step 2.

### From 04-Evaluator (Maturity & Stability Cross-Check)

1. **RESOLVED: `codify` citation gap.** Original draft cited "CHANGELOG.md § Added" for codify claim, but `codify` does not appear in CHANGELOG.md. Corrected to cite `00-ground-truth.md` § "Review / knowledge skills" (line 44) + git log commit `6ea36a7 feat: add codify internal-knowledge crew`. Added explicit flag in Claims table: "Gap flagged: `CHANGELOG.md` does not yet list `codify` entry" — surfaces this as an Issue Council agenda item.

2. **RESOLVED: Version bump claim removed.** Original draft said "bumped to next (0.3.0)". Verified `.claude-plugin/plugin.json` still reads `"version": "0.2.0"` (no bump yet). Reworded to: "Plugin version remains 0.2.0; 15 commits unreleased." Avoids self-contradiction and matches actual state.

3. **RESOLVED: `spark doctor` output verification.** Same as feedback item #4 from Cartographer; addressed above.

---

**Summary for Orchestrator:**

Phase 3 revision complete. All six feedback items from upstream neighbors (00-Cartographer, 04-Evaluator) addressed: codify's separate `.codify-notes/` scratch clarified, commit count and hash corrected to git-verified values, `spark doctor` output aligned to actual behavior, and CHANGELOG.md's missing `codify` entry flagged as an Issue Council gap. Every claim in this note traces to `00-ground-truth.md`, git history, or repo files. Ready for Phase 4 (Issue Council debate) and aggregation by 10/11.
