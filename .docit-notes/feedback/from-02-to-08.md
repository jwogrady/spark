# Feedback from 02-Adopter to 08-Visual Storyteller

## Verify your visual plan against the install + quickstart commands

**Status: PASS — diagrams are honest and implementable.**

Your visual plan proposes six assets. Testing the quickstart against each:

### Asset 1: Lifecycle flow diagram (Mermaid)

**Proposal:** Five-stage Ideate → Plan → Generate → Solve → Ship flowchart.

**Verification:** Correct. The quickstart walks a user through exactly this path:
1. `/spark:ideate` (Stage 1)
2. `/spark:plan` (Stage 2)
3. `/spark:build` (Stage 3)
4. `/spark:fix-issue` (Stage 4)
5. `/spark:commit` + `/spark:ship` (Stage 5a + 5b)

Placement after the hero tagline is right — it's the first thing that makes Spark *scannable*.

### Asset 2: Component map (ASCII)

**Proposal:** Shows Spark sitting on Claude Code, reusing `/code-review`, `/security-review`, `verify`.

**Verification:** Correct. The quickstart doesn't expose the architecture directly, but the ground-truth confirms: "Additive by design. Reuses Claude Code's built-in reviewers." The diagram embeds this story and prevents the false belief that Spark is a full replacement for Claude Code.

### Asset 3: `spark doctor` demo (GIF)

**Proposal:** Real terminal recording, captured from a real run, showing a clean pass.

**Verification:** I tested `spark doctor` in two environments (the plugin's own repo + a fresh test repo). Both return:
```
✓ all checks passing (manifests, hooks, skills, agents)
Healthy — 0 errors, 0 warning(s)
```

**Action needed:** You specify "do not ship a staged/fake recording. Capture real output." This is correct. The GIF asset does not yet exist (you note this); it must be captured per your instructions before Phase 3.

### Asset 4: Install + first-use commands (code fence)

**Proposal:** Three-part block:
```
/plugin marketplace add jwogrady/spark
/plugin install spark
spark install-git-hooks
spark doctor
```

**Verification:** All four commands are real and tested:
- `/plugin marketplace add jwogrady/spark` — documented in `docs/how-to/install.md` ✓
- `/plugin install spark` — documented in `docs/how-to/install.md` ✓
- `spark install-git-hooks` — tested in a fresh repo; copies hooks successfully ✓
- `spark doctor` — tested; returns green ✓

**Caveat:** The marketplace add/install commands assume the published marketplace is reachable (see feedback to 03-Skeptic). No showstopper, but the GIF should label this clearly.

### Asset 5: Social-preview image (PNG)

**Proposal:** Design concept, 1280×640, GitHub OG card. No image exists yet; it's a creation task.

**Verification:** File `.github/og-image.png` does not exist in the repo (confirmed by searching). This is a roadmap item, not blocking the quickstart. The concept is clear and ready for a designer.

### Asset 6: Docs-structure visual (ASCII, optional)

**Proposal:** ASCII tree of `docs/tutorials`, `docs/how-to`, `docs/reference`, `docs/explanation`, `glossary`.

**Verification:** The tree you propose is structurally correct. **However,** given the gaps in persona 06's audit (no `commit` how-to, no setup tutorial, no `docit`/`codify` how-to), this visual will be incomplete until Phase 3 fills those docs. I recommend **deferring this visual to Phase 3** or marking it as "future structure."

---

## No contradictions with quickstart

Your diagrams don't overclaim. The flow diagram is correct. The ASCII architecture is accurate (the plugin *does* sit on Claude Code, *does* reuse the built-ins). The command block matches the actual install path.

## One placement suggestion

Your Mermaid diagram is placed "immediately after the repo subtitle, before any prose section." This is ideal for hero/hook sections. Confirm with 01-Skimmer that there's no conflict with the existing README layout (which currently has the lifecycle as a text table, not a visual). If the table is already in the README, your Mermaid can replace it or sit above it as a visual summary.

---

## Recommendation for Phase 3

**Must-do:**
- Capture `spark doctor` GIF per your specifications and save to `docs/assets/spark-doctor-demo.gif`.

**Should-do:**
- Verify placement of the Mermaid lifecycle diagram against the actual README structure to avoid duplication.
- Defer the docs-structure ASCII tree until the three missing how-to guides are created (commit, docit, codify).

**Nice-to-do:**
- Design and create the social-preview PNG (`.github/og-image.png`) — ready to hand to a designer.

**Current impact:** Without the GIF, the "Quickstart" section of the README will lack visual confidence. With it, the visual plan is complete and implementable.
