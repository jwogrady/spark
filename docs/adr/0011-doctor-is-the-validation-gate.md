# ADR: `spark doctor` is the single validation gate, and two-door parity is mechanical

Date: 2026-07-09
Status: Accepted (amended 2026-07-21 — the "single gate / CI runs exactly doctor" framing is superseded in part by ADR-0018; see Amendment. Note 2026-08-11: the two-door prose-parity checks this ADR made mechanical were narrowed to enumerable lockstep checks, and a third, server-side enforcement door was added — see ADR-0027 and the #361 deletion test)
Owner: jwogrady

## Context

ADR-0003 (2026-05-29) recorded two facts that were true then and are false now:
that `spark doctor` was "a human convention, not a CI gate — there is no
`.github/workflows/` that enforces it," and that keeping the two enforcement
doors in sync was "a manual discipline" because doctor "does not diff the two
rule sets." Its Open Questions section proposed a future parity check.

Issues #70, #71, and #72 changed that state: doctor grew into a superset
validator (`bash -n` on every shipped script, a broken-relative-link scan,
git-hook install checks), gained an enforcement-parity check, and a GitHub
Actions workflow now runs it on every pull request.

The decision behind that change was recorded in the wrong place: an
"Amendment (2026-07-08)" section appended inside ADR-0005. Per the template's
append-only rule — a past decision is never grown or rewritten; it is
superseded by a new numbered ADR with a Status pointer — that content belongs
in its own record. This ADR is that record.

## Decision

- **`spark doctor` is the single validation gate.** Every check — layout,
  manifest/hook JSON, skill and agent frontmatter (including the description
  lint), shell syntax, doc links, git-hook install state, enforcement parity —
  lives in doctor. New checks are added to doctor, never anywhere else.
- **CI is a thin wrapper around it.** `.github/workflows/validate.yml` runs
  exactly `./plugins/spark/bin/spark doctor` on pull requests and contains no
  check logic of its own, so the local gate and the CI gate cannot drift.
- **Two-door parity is mechanical, not manual.** Doctor verifies that the
  PreToolUse guard, the git hooks, and the docs (`CLAUDE.md`, `AGENTS.md`)
  state the same rules: the conventional-commit type set, the AI-attribution
  ban, trunk-commit/push protection, and the force-push /
  `--force-with-lease` split. This resolves ADR-0003's open question.
- **This ADR subsumes ADR-0005's in-file amendment** as the numbered home of
  the Spark-repo-validation-CI decision. The distinction it drew stands:
  Spark-repo validation CI (this gate) and Cosmic-generated build CI
  (a `bootstrap` generation-time template, ADR-0005/0007) are different
  subjects and must not be conflated. "Spark stays CI-free" continues to mean
  Spark has no build/test pipeline — there is still nothing to build.

Why: one command that is the whole gate is the discipline principle of
ADR-0003 completed, not contradicted — the rules did not change, their
enforcement graduated from convention to mechanism.

## Alternatives Considered

- **Leave the decision recorded as ADR-0005's amendment.** Rejected: the
  template's rule is append-only ADRs — new decisions get new numbers; growing
  a closed record blurs what was decided when.
- **Separate CI checks from doctor checks.** Rejected: two check surfaces
  drift; the wrapper-only workflow makes drift structurally impossible.
- **Keep parity as a documented manual discipline.** Rejected: ADR-0003 itself
  flagged silent two-door drift as the risk; a check that runs is worth more
  than a habit that might.

## Consequences

- ADR-0003 and ADR-0005 carry Status pointers to this ADR; their bodies stay
  untouched, including 0005's amendment text, which remains as history.
- Any future enforcement rule must land in three places to pass doctor: the
  guard or git hook, the docs, and — if it is a new rule class — the parity
  check itself. Doctor makes forgetting any one of them a red build.
- The workflow file is deliberately boring; if it ever accumulates logic,
  that is the regression to catch in review.

## Amendment (2026-07-21)

The behavioral test suite (`tests/run.sh`) shipped as a second CI job in
`.github/workflows/validate.yml` (#165, #172), so two of this record's claims
no longer hold literally:

- CI no longer runs *exactly* `spark doctor`: `validate.yml` runs a `doctor`
  job **and** a `tests` job.
- Doctor is no longer the *single* gate; it is the **static** superset gate,
  and `tests/run.sh` is the **behavioral** gate.

The spirit is intact: no check logic lives in the workflow YAML — doctor and
the `tests/test-*.sh` suites hold it, so the local and CI gates still cannot
drift. **ADR-0018** records the behavioral gate and supersedes the "single
gate / runs exactly doctor" framing above; the parity discipline is unchanged.

## Related Docs

- [0003-zero-dependency-bash-and-enforcement-hooks.md](0003-zero-dependency-bash-and-enforcement-hooks.md) — the enforcement model this updates
- [0005-cosmics-ship-ci-spark-stays-ci-free.md](0005-cosmics-ship-ci-spark-stays-ci-free.md) — the Cosmic-CI distinction this subsumes and preserves
- [0018-behavioral-tests-are-the-second-ci-gate.md](0018-behavioral-tests-are-the-second-ci-gate.md) — the behavioral gate that amends this record
- `plugins/spark/docs/explanation/enforcement-model.md` — the mechanical-enforcement rationale
