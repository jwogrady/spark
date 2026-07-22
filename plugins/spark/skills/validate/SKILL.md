---
name: validate
description: Review and harden one change — run Claude Code's built-in /code-review and /security-review on the current branch's diff, triage the findings, and fix them until the issue's acceptance criteria hold. Use after codify to harden a single change/branch/PR, resolve review findings, or get a diff ready to ship. For a whole-codebase audit rather than one diff, use audit instead.
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
2. **Triage findings.** Sort into: must-fix (breaks a criterion or is a real
   bug), should-fix (quality), and out-of-scope (file as a new issue, don't fix
   here).
3. **Fix the must/should items** on the same branch.
4. **Re-verify** against the issue's acceptance criteria. The criteria are the
   definition of done.
5. **Carry the state forward.** Record the close-out with
   `spark state --set stage=validate blockers="<what still blocks shipping, empty when nothing>" next_action="<…>"`
   (writes `.spark/state.json`, [schema](../../docs/reference/state.md); `updated` is stamped for you).

## Guardrails

- A finding you decide *not* to fix gets recorded (a new issue or a note), never
  silently dropped.
- Don't expand scope while fixing — new problems become new issues.
- If tests fail, say so plainly with the output. Never report green when it
  isn't.

## Next

When the criteria hold, go to [`ship`](../ship/SKILL.md).
