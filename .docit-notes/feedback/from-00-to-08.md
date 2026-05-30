# Feedback from 00 (Cartographer) to 08 (Visuals / Visual Storyteller)

Reviewer: 00-cartographer (honest-hype enforcement). Every visual must depict
something real and cited.

## Verdict: PASS with two accuracy corrections to the diagrams

The visual plan is grounded and the asset table honestly marks the OG image and
demo GIF as "needs creation/recording." Two diagrams encode small inaccuracies.

### Must fix

1. **Component-map ASCII overstates the CLI surface and may mislead on hooks.**
   The box lists `bin/spark` commands as `doctor / new-skill / install-git-hooks
   / shred-env` and omits `list-skills`, which is a real dispatch case (ground
   truth CLI section; this is the same undercount flagged in the README accuracy
   flags). Either list all six (`doctor, list-skills, new-skill,
   install-git-hooks, shred-env, help`) or label the column "e.g." so it doesn't
   read as exhaustive. Also: the diagram stacks `guard-bash.sh`, `commit-msg`,
   `pre-commit` under one `hooks/` label — but `commit-msg`/`pre-commit` live in
   `scripts/hooks/`, not `hooks/`. Ground truth keeps these distinct
   (`hooks/guard-bash.sh` vs `scripts/hooks/commit-msg`). Fix the grouping so the
   diagram doesn't assert a false file layout.

2. **Docs-tree ASCII (#6) shows `adr/` and `architecture/` nested under
   `explanation/`.** Ground truth has them as siblings: `docs/adr/0001..0003` and
   `docs/architecture/spark-internals.md` are top-level under `docs/`, NOT inside
   `docs/explanation/`. Persona 06 explicitly notes the ADRs sit *outside*
   `docs/explanation/`. Redraw the tree to match the real layout, or the visual
   contradicts both ground truth and 06.

### Verified-good

- Lifecycle Mermaid (Ideate → Plan → Generate → Solve → Ship) — correct.
- "16 skills" label — correct.
- `spark doctor` demo GIF with "do not ship a staged/fake recording" note —
  exactly the right honesty posture. Endorsed.
- OG image marked as not-yet-existing — correct, no overclaim.
- Author string `jwogrady` only, no AI/Anthropic branding — compliant.

Fix the two diagrams' file-layout details and this is clean.
