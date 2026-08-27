---
name: validate
description: Review and harden one change — run the built-in /code-review and /security-review on the branch diff, triage findings, and fix until acceptance criteria hold. Use to harden a single change/branch/PR or resolve review findings after `codify`. For a whole-codebase audit rather than one diff, use `audit`.
---

# validate — Stage 4 of the Spark lifecycle

`Ideate → Plan → Codify → Validate → Ship`

Validate closes the gap between "it compiles" and "it's correct and safe." Spark
does **not** ship its own reviewer — it orchestrates Claude Code's built-in
ones, then drives the fixes.

## Do this

1. **Review with the built-ins** (don't reinvent them):
   - `/code-review` — correctness, reuse, simplification, efficiency.
   - `/security-review` — vulnerabilities, when the change touches auth, input
     handling, secrets, or network surface.
   - The `verify` skill — actually run the app/tests and observe behavior, not
     just read the diff.
   - `spark docs-impact --branch` — prove the issue's declared documentation
     impact matches what the branch changed, here rather than after the PR.
     FAIL is a must-fix; NOT ASSESSED is never a pass.
2. **Triage findings.** Sort into: must-fix (breaks a criterion or is a real
   bug), should-fix (quality), and out-of-scope (file as a new issue, don't fix
   here).
   When validating a **combined state** — an integration branch, or a milestone
   whose issues landed separately — follow
   [references/integration-validation.md](references/integration-validation.md):
   identify the tree by commit, re-verify what the combination could have
   changed, classify blocking findings by provenance, and ask what
   documentation became false.
3. **Fix the must/should items** on the same branch, and **commit each
   coherent fix** as its own Conventional Commit (distinct concerns get
   distinct commits; no per-edit checkpoint noise, no squashing the
   implementation history). Out-of-scope findings become issues, never
   commits here.
4. **Re-verify** against the issue's acceptance criteria. The criteria are the
   definition of done. Report each claim with its evidence class — **CODE
   IMPLEMENTED** (written, nothing observed), **STATICALLY PROVEN**
   (tests/review passed), **LIVE PROVEN** (behavior observed running), **LIVE
   UNPROVEN** (claimed live, not observed live). A claim about live behavior
   requires live observation; never report a stronger class than the evidence
   holds. Vocabulary only — nothing enforces it.
5. **Carry the state forward.** Record the close-out with
   `spark state --set blockers="<what still blocks shipping, empty when nothing>" next_action="<…>"`
   (writes `.spark/state.json`, [schema](../../docs/reference/state.md); `updated` is stamped for you).

## Guardrails

- A finding you decide *not* to fix gets recorded (a new issue or a note), never
  silently dropped.
- Don't expand scope while fixing — new problems become new issues.
- A finding that reveals durable cross-project learning, not just a defect,
  is the same ADR-0028 boundary as codify's: ask the promotion question and
  route a "yes" to [`knowledge`](../knowledge/SKILL.md). Routine findings
  need no ceremony.
- If tests fail, say so plainly with the output. Never report green when it
  isn't.

## Next

When the criteria hold, go to [`ship`](../ship/SKILL.md).
