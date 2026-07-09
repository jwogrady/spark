# ADR: Zero-dependency POSIX Bash + enforcement hooks

Date: 2026-05-29
Status: Accepted; superseded in part by
[ADR-0011](0011-doctor-is-the-validation-gate.md) — the "doctor is a human
convention, not a CI gate" and "rule parity is a manual discipline" claims no
longer hold: validation CI now runs doctor on every PR, and doctor checks
two-door parity mechanically (this ADR's Open Question, resolved)
Owner: jwogrady

## Context

Spark's scripts run inside *any* forked project, regardless of stack. They cannot
assume a runtime (Node, Python, etc.) is present, and they enforce git hygiene
that must hold whether an operation is issued by Claude or by a human.

## Decision

- **Implementation:** all scripts are POSIX-friendly Bash with `set -euo pipefail`
  and **zero runtime dependencies**. JSON parsing degrades gracefully: try `jq`,
  then `python3`, then a safe fallback — never hard-fail on a missing parser.
- **Enforcement (two doors, same rules):**
  - **PreToolUse Bash guard** (`hooks/hooks.json` → `hooks/guard-bash.sh`) blocks
    force-push (`--force`/`-f`, allowing `--force-with-lease`) and pushes to
    `master`/`main` on the *Claude-driven* path. Exit `2` blocks and returns the
    reason; it only blocks on a positive match, so it fails safe.
  - **Git hooks** (`scripts/hooks/{commit-msg,pre-commit}`, installed by
    `spark install-git-hooks`) enforce the same intent on the *human-driven* path:
    no commits on trunk, conventional-commit subject rules, and no AI attribution.
- **Scope — git-only by design.** The guard inspects only commands containing
  `git`; every non-`git` command exits `0` (allowed). This is intentional: Spark
  guards *git hygiene*, not arbitrary shell safety. Blocking general destructive
  commands (`rm -rf`, etc.) is **explicitly out of scope** — the guard is not a
  sandbox, and a narrow, predictable matcher is easier to trust than a catch-all.
  Non-git destructive safety is handled by convention (`CLAUDE.md` "Destructive
  Changes" — ask first). The git-hook door is likewise scoped to commit content
  and branch.

Zero dependencies guarantee the toolkit works everywhere it is forked.
`set -euo pipefail` fails loudly on the first error instead of silently
continuing. Graceful degradation means a missing `jq`/`python3` weakens a check
rather than breaking the run. Two enforcement doors are required because a plugin
hook only sees Claude's tool calls — a human running git bypasses it entirely.
Full per-rule detail is in [../reference/hooks.md](../../plugins/spark/docs/reference/hooks.md).

`spark doctor` is the push-readiness preflight, but it is a **human convention**
("run it before pushing"), not a CI gate — there is no `.github/workflows/` that
enforces it.

## Alternatives Considered

- **A richer runtime (Node/Python CLI).** Rejected: imposes a dependency on every
  forked project and breaks the portability guarantee.
- **Hard-fail when `jq`/`python3` is absent.** Rejected: would make a JSON check
  unusable on a bare machine; degrading to skip-with-warning is safer.
- **Rely on the PreToolUse guard alone.** Rejected: leaves the human-driven door
  unguarded. The git hooks close it.

## Consequences

- Scripts stay portable and reviewable; new logic must hold to POSIX Bash and the
  degradation pattern.
- The same rule is expressed in two places (guard script + git hook); a rule
  change must land in both to stay consistent. `spark doctor` checks the layout
  but does not diff the two rule sets — keeping them in sync is a manual
  discipline, reinforced by the convention of running `doctor` before pushing (a
  human habit, not a CI-enforced gate).
- Git hooks are per-repo and require `spark install-git-hooks`; the PreToolUse
  guard travels with the plugin automatically.

## Open Questions

- **Possible future check (not current behavior):** should `spark doctor` assert
  that the PreToolUse guard and the git hooks express equivalent rules, to catch
  drift between the two doors? Ops flagged the same two-door drift risk; this is
  the single home for that proposal. Today `doctor` validates layout only, not
  rule-parity. Owner: jwogrady.
- **`$SPARK_AUDIT_LOG` tooling.** The guard appends each block to
  `$SPARK_AUDIT_LOG` when set and writable, but there is no reader or rotation
  tooling in source — it is purely an opt-in append-only file the operator sets.
  Genuinely open; do not invent a runbook for tooling that isn't there. Owner:
  ops/jwogrady.

## Related Docs

- [../reference/hooks.md](../../plugins/spark/docs/reference/hooks.md)
- [../reference/cli.md](../../plugins/spark/docs/reference/cli.md)
- [../architecture/spark-internals.md](../architecture/spark-internals.md) — the architecture map
