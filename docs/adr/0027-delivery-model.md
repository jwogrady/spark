# ADR: Delivery is issue PRs to trunk; integration branches are the exception

Date: 2026-08-11
Status: Accepted
Owner: jwogrady

> Records the delivery model decided by the #336–#361 reconciliation after the
> zd-dns v0.1.0 field test: canonical GitHub Flow at the issue level with a
> mechanical dependency-order invariant, and the temporary milestone
> integration branch demoted from proposed canonical spine (#339/#358) to a
> documented exception/recovery pattern.

## Context

The zd-dns field test produced evidence on both sides. The failure: two
feature branches with a real semantic dependency were built in parallel off a
stale trunk, and integrating them required a reconstruction exercise — the
plan graph and the Git graph told different stories. The counter-evidence: the
delivery phase that followed landed ~20 sequential, single-concern PRs
straight to `master` — including chains of dependent code fixes — with zero
integration pain, because each branch started from the current trunk after its
prerequisite had merged.

The redesign wave (#337–#358) proposed making a temporary per-milestone
integration branch the canonical topology. Weighing the whole record: the
failure is prevented by an **ordering invariant**, not by a topology — "B
starts from a state containing A" is satisfied by merging A's PR before
branching B, with no standing branch, no larger PRs, and no loss of GitHub's
native issue↔PR traceability. The milestone branch buys one extra property
(trunk never carries partial-milestone work), and the field record shows that
property was never needed: partial milestone work sat on `master` for weeks
while releases stayed gated behind Release Please's PR.

## Decision

**Canonical delivery:**

```
issue → issue branch → focused commits → validation → issue PR → master
```

- **One issue, one short-lived branch, one PR.** Multiple focused Conventional
  Commits per branch (commit ownership: Codify implements, Validate fixes,
  Ship publishes — see the skills).
- **The ordering invariant:** if issue B depends on issue A, the state used to
  Codify B must contain A's accepted, integrated result. Plan records the
  dependency durably in GitHub (native blocked-by links via the issue
  manifest, `Blocked by #N` in the body); Codify demands **positive proof**
  before branching (`check-prereqs.sh`): every blocker's merged closing PR is
  an ancestor of HEAD — a closed issue alone proves nothing — and HEAD sits
  exactly at the fresh remote trunk, neither behind nor diverged, with the
  new branch created from an explicit `origin/<trunk>` start point. Violation
  blocks; unavailable proof is *not assessed*, never guessed; `resume`
  surfaces trunk-ancestry drift on re-entry. Drift is reported, never
  silently repaired.
- **Independent issues may proceed in parallel.** Dependent issues wait for
  their prerequisite to merge, then branch from the fresh trunk. Sequential-
  when-dependent is the norm, and the field record shows it scales to real
  dependent chains.
- **`master` is the development trunk**, always integrated via PR, never
  guaranteed milestone-complete. The *release* is the coherent product state,
  and it is gated separately: milestone completeness by the milestone gate,
  release mechanics by Release Please, authorization by the human merge
  (ADR-0006/0009).
- **One writer per working tree** (from #340): concurrent read-only analysis
  is fine; concurrent *mutation* requires genuinely isolated worktrees or
  clones, which the Claude Code harness provides natively. Spark states the
  invariant and builds no orchestration machinery.

**The exception — a temporary integration branch** is a technique, not a
topology. Reach for it only when:

- parallel work has **already diverged** and must be reconciled (recovery), or
- tightly coupled issues are deliberately integrated for combined review
  before one PR.

Rules when used: integrate in dependency order; validate the combined tree
(the integration-validation reference in the validate skill); one PR to
`master`; delete the branch after merge. It is never a standing `develop`, and
Ship needs no special mode — publishing an integration branch is mechanically
the same motion as publishing an issue branch.

## Consequences

- Cross-issue defects are bounded by ordering: each dependent branch builds on
  its prerequisite's merged reality, so interaction surfaces integrate one PR
  at a time instead of accumulating.
- GitHub's native traceability (`Closes #N` per PR) stays intact; no
  deterministic issue↔commit map has to be reconstructed in PR bodies.
- The enforcement doors are unchanged; server-side trunk protection (the
  third door: PRs required, merges gated on the repo's required CI checks,
  force-push and deletion blocked) composes with PR-based integration
  directly.
- The rejected alternative is recorded: #339/#358's canonical milestone
  integration branch, and #356's milestone-publishing Ship rewrite, do not
  land. Their vocabulary (milestone = shippable state; issue = capability;
  commit = coherent step) survives in the doctrine.

## Alignment

- **Identity / prior decisions served:** ADR-0019 (human-directed roles —
  the human merge stays the integration and release act); ADR-0006/0009
  (Release Please owns release mechanics); ADR-0023 (orchestration stays
  decided-but-gated; this ADR adds the one-writer invariant it assumed).
- **Supersedes / Superseded by:** supersedes the delivery topology proposed
  in issues #339/#353/#356/#358 (closed to this ADR); nothing else.
- **Status tracks evidence:** n/a — adopted from field evidence recorded in
  the issues above and the zd-dns v0.1.0 release record.
