# Issue & metadata governance

Spark plans work with GitHub's native metadata, one canonical location per
fact, and no ceremony. The goal is that a glance at an issue — its type,
milestone, relationships, and status — tells you everything, without the same
fact copied across labels, prose, and a board.

## Source-of-truth model

Record each fact once, on the surface that owns it:

| Fact | Canonical GitHub surface |
| --- | --- |
| Work category | One `issue.taxonomy` label (see below) |
| Release target | Milestone |
| Priority, effort, risk, lifecycle status | Project fields (or a priority label until a board exists) |
| Dependencies and hierarchy | Native blocked-by/blocking and parent/sub-issue links |
| Ownership | Assignee |
| Implementation linkage | Linked PR + a closing keyword (`Closes #N`) |
| Product-level release intent | The roadmap, linking to milestones/issues — never duplicating their fields |

If a fact already lives on one surface, do not restate it on another. A label
that repeats a milestone, or a prose "depends on" that a native link already
records, is drift waiting to happen.

## Category taxonomy

Category labels are governed by the `issue.taxonomy` preference
(`preferences/defaults.json`):

```
feature  bug  documentation  chore  tech-debt  research  infrastructure
```

Every issue carries exactly one category. `spark doctor` mechanically checks
that each issue form in `.github/ISSUE_TEMPLATE/` uses a taxonomy category and
never the deprecated `enhancement` alias, so the forms and the taxonomy cannot
drift; where a repo has no issue forms, doctor says so rather than passing
silently. Theme labels (area, priority `P0`–`P3`) may accompany a category but
never replace it.

Declaring the taxonomy is not the same as provisioning it. Labels live on
GitHub, and `spark setup` is an offline, create-only pass, so
[`spark labels`](cli.md) is the verb that reconciles the two: it reports the
missing categories by default and creates them with `--apply`, create-only,
leaving theme labels untouched. Run it once per repo after setup, or the
taxonomy this document governs will not exist on the remote it governs.

## The `backlog` disposition label

A feature that is deliberately deferred carries the `backlog` label. It is a
disposition label, not a category — it accompanies the `feature` category, it
does not replace it. The label is the machine-readable record of the backlog
decision: `plan/scripts/roadmap-check.sh` reads it to distinguish a deferred
feature from one with no release decision at all, so a disposition recorded only
in a comment or a linked recommendation stays invisible to the check. Apply the
label and keep the *reason* where it belongs (the roadmap, a recommendation doc,
or the issue body) — the label answers "decided?", the reason answers "why?".

## Milestone rules

- **A milestone represents release scope** — the set of work a release ships.
  A milestone titled `vX.Y …` maps to the release whose version is `X.Y.*`.
- **Issue order within a milestone is delivery priority.** The top issue is
  next.
- **No feature begins without a release decision** — a milestone, an explicit
  backlog with a reason, or blocked on a named decision. This is the
  [`plan` release-assignment rule](../../skills/plan/references/release-assignment.md),
  checked by `plan/scripts/roadmap-check.sh`.
- **Spark recommends; the human approves.** Spark never silently assigns a
  milestone, priority, or owner, and never retargets existing work — it
  proposes and reports the gap.

## The release-readiness convention

The scope rules for sub-issues and parents are doctrine, stated once in
[sdlc-doctrine](../explanation/sdlc-doctrine.md): a sub-issue is an issue (its
own branch, its own PR) and a parent is a container (no branch, closes when its
children close). The release-readiness issue below is the canonical instance of
that parent rule, not an exception to it.

Each milestone has one **release-readiness issue** that doubles as the milestone
epic:

- The release-readiness issue carries the milestone's issues as **native
  sub-issues**, so scope and progress are visible on the gate itself.
- **Blocked-by links encode delivery order** between those sub-issues.
- The readiness issue **closes last**, when the milestone is complete and the
  release evidence is assembled (see the
  [release-docs checklist](release-docs-checklist.md)).

### The milestone gate

A workflow (`.github/workflows/milestone-gate.yml`) turns this convention into a
signal on the Release Please PR. It maps the PR's proposed version `X.Y.*` to
the milestone titled `vX.Y …` and posts a `milestone-gate` commit status:

- **blocked** while the milestone has open issues (it names them) or validation
  is not green;
- **ready** once every mapped issue is closed and validation is green — with a
  summary that says *ready for human approval — merge to release*;
- **neutral** when no milestone maps to the version (release behavior unchanged).

The gate is a **verification surface only**. It never merges the PR, creates a
tag, or publishes a Release — its workflow is granted no write access to
repository contents, so it cannot even in principle. The human merge remains
the release act (ADR-0009, #185); Release Please owns the mechanics. Reopening a
milestone issue withdraws the ready state. The decision logic is offline-tested
via fixtures (`tests/test-milestone-gate.sh`). Its **ready (green)** path needs
validation to actually run on the Release Please PR, which is why release-please
creates that PR under a dedicated token (`RELEASE_PLEASE_TOKEN`, see
release-token-governance.md); the gate re-evaluates when the `validate` workflow
completes so it reads the final result rather than racing it.

## The metadata-completeness audit

Spark runs this audit during Ideate/Plan and before release approval. It is a
report, not an auto-fix: gaps are handed to the human with the smallest
decision that resolves each.

Every **active** issue should have:

- [ ] one `issue.taxonomy` category label;
- [ ] a release disposition — milestone, explicit backlog+reason, or
      blocked+decision (features especially, per the `plan` rule);
- [ ] native dependency/sub-issue links where the relationship affects order;
- [ ] an assignee or an explicit unassigned state;
- [ ] a linked PR + closing keyword once implementation starts.

The roadmap side of the audit — a current release named, a next release named,
unshipped sections linking issues or deferring explicitly, every open feature
decided — is mechanized by `plan/scripts/roadmap-check.sh`.

## Not yet standardized

A live GitHub **Project board** (Status/Priority/Target/Size/Risk fields with
add/status/archive automation) is the intended home for the priority/effort/risk
facts above. Until it exists, priority lives on `P0`–`P3` labels and status on
the milestone/issue state. Standing up the board is tracked as a follow-up
(#223).
