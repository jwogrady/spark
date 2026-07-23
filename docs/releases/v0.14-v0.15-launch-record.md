# Spark launch record — v0.14.0 / v0.15.0

> **Status: historical record.** This file was created before the proving
> release was cut and originally read as a pending checklist. Both releases
> have since shipped; it is now the *record* of that launch, not a set of
> current actions. The forward path to a stable v1.0.0 is **not** here — it is
> the [Alpha program](../alpha/alpha-program.md) and its
> [exit criteria](../alpha/exit-criteria.md).

## Actual shipped result (verified)

The v0.15 hardening wave shipped across two releases. Concrete evidence:

| What | Outcome | Evidence |
| --- | --- | --- |
| Hardening PR | **Merged** | PR #314 rebase-merged to `master` |
| Proving release | **`v0.14.0` cut** | release PR #287 squash-merged 2026-07-23; tag `v0.14.0`; GitHub Release published (not draft, not prerelease) |
| Alpha intake + follow-on | **`v0.15.0` cut** | release PR #320 (regenerated after the alpha-intake `feat`, PR #321) squash-merged; tag `v0.15.0`; Release published |
| Release epic | **Closed** | #284 closed 2026-07-23 |
| CEF epic | **Closed (completed)** | #298 closed after its three tracked items were verified shipped |
| Release/validation gates | **All green** on the release PRs | doctor · gate · milestone-gate · platform-compat · release-notes · tests · traceability |
| Published install | **Verified** | `tests/e2e-marketplace-install.sh` — 12/12 from a clean environment against the published marketplace path; all 9 core skills inventoried |
| Repository health at release | **Healthy** | `spark doctor` 0 errors/0 warnings; `doctor --requirements` Ready; `tests/run.sh` all suites |

The proving release therefore did what a proving release must: the pipeline,
changelog, version bumps, tag, and Release all behaved as designed on a real
cut, and the published artifact installs from scratch.

## Current forward path (authoritative)

- **Spark is in Alpha (v0.x).** Engineering is proven; the *product* is being
  validated by real users.
- **Alpha evidence collection is active** — see the
  [Alpha program](../alpha/alpha-program.md), [testing guide](../alpha/testing-guide.md),
  and the `alpha-feedback` issue form.
- **Beta promotion is governed by** [`docs/alpha/exit-criteria.md`](../alpha/exit-criteria.md)
  (evidence thresholds, not dates). Beta then proves durability before v1.0.0.
- **A stable v1.0.0 is not authorized merely because the proving releases
  shipped.** The earlier "proving-release → v1.0.0" path that this document
  originally described is **superseded** by the Alpha → Beta → v1.0.0 gate.

## Outstanding work

Every pre-cut action this file once listed is **complete** (see the shipped
table above): the release PRs are merged, both tags and Releases exist, the
epics are closed, and published-install evidence exists. Nothing here remains
open.

Genuinely outstanding work lives in the Alpha program, not here: gathering
unaided-completion, workflow-friction, discoverability, and value evidence from
real participants, per [`exit-criteria.md`](../alpha/exit-criteria.md). That is
the next gate, and it is deliberately open.

## Rollback guidance

Separated by the state it applies to.

**Current (post-release) — the applicable guidance.** Both tags are published;
prefer rolling *forward*. To correct a defect in a shipped release, ship a
follow-up `fix:` so Release Please cuts a corrected patch; the marketplace
serves whatever the latest tag points to, so a corrected patch is the fastest
clean recovery. Un-publishing a live Release (`gh release delete`) or deleting a
tag is a deliberate maintainer action (the guard blocks hand-cut tags) and is a
last resort, not routine.

**Alpha handling — expected, not a rollback.** During Alpha, breaking changes
and redesigns are *expected* and are shipped as normal minor releases with the
change documented in the changelog and the [stability contract](../../plugins/spark/docs/reference/stability.md);
they are not emergencies to roll back.

**Historical (pre-cut) — no longer applicable.** Before release PR #287 was
merged there was nothing to roll back: no tag or Release existed, so a
correction was just a commit to `master` that regenerated the release PR. This
condition ended when `v0.14.0` was cut; it is retained here only as the record
of the pre-release plan.
