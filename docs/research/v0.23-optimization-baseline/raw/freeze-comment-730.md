## Baseline freeze — #730 (pre-optimization)

This comment establishes the freeze only. No measurements are claimed complete here.

| Fact | Value |
|---|---|
| Frozen remote `master` SHA (measured system) | `921c9820b92e99ef3620f4f46a0a8a6d7bb0c8b5` |
| Preserved PR #727 HEAD (real-world specimen) | `e3ced28f6a469b09990dfd96b3435bfb5b2b342a` (open, base `master`) |
| Released governor at freeze | Spark v0.22.0 |
| Standing orchestration | #677 |
| Release / milestone / gate | v0.23 — Never automate inefficiency / milestone 20 / #480 (RED) |
| UTC observation timestamp | 2026-09-06T16:24:54Z |

- PR #727 is retained, unmodified, as a real-world **pre-optimization review/repair specimen**. It is read as evidence only; it is not commented on, re-reviewed, repaired, pushed, rebased or merged as part of this baseline.
- The #728/#729 native sub-issue hierarchy normalization (17 attachments via `POST /repos/jwogrady/spark/issues/{728,729}/sub_issues`) occurred **before** this freeze and is metadata only; it changed no measured behavior.
- At this freeze, **no** snapshot-first, fact-compiler or review-packet optimization (#731–#736, #746) has begun. `master` has not moved past the #722 memoization merge.
- Any measurement tooling created later for this baseline will be run against this exact frozen SHA in a detached worktree, and the instrumentation version will be reported separately from the measured-system version.
