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
drift. Theme labels (area, priority `P0`–`P3`) may accompany a category but
never replace it.

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

Each milestone has one **release-readiness issue** that doubles as the milestone
epic:

- The release-readiness issue carries the milestone's issues as **native
  sub-issues**, so scope and progress are visible on the gate itself.
- **Blocked-by links encode delivery order** between those sub-issues.
- The readiness issue **closes last**, when the milestone is complete and the
  release evidence is assembled (see the
  [release-docs checklist](release-docs-checklist.md)).

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
