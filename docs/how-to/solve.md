# How to solve (review and harden) a change

> How-to — task-oriented.

Use this after `codify`, before committing.

1. Invoke `/spark:fix-issue`.
2. Run the built-in reviews — Spark orchestrates them, it doesn't replace them:
   - `/code-review` for correctness and quality.
   - `/security-review` if the change touches auth, input handling, secrets, or
     the network surface.
   - the `verify` skill to actually run the app/tests and observe behavior.
3. Triage findings into must-fix, should-fix, and out-of-scope.
4. Fix the must/should items on the same branch.
5. File out-of-scope findings as new issues — never drop them silently.
6. Re-verify against the issue's acceptance criteria.

**Done when** the criteria hold and the reviews are clean (or remaining items are
tracked as issues). If tests fail, report it plainly — never report green when
it isn't.
