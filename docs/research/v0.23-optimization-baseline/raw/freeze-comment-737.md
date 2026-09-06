## Baseline freeze — #737 (pre-cleanup)

This comment establishes the freeze only. No measurements are claimed complete here.

| Fact | Value |
|---|---|
| Frozen remote `master` SHA (measured system) | `921c9820b92e99ef3620f4f46a0a8a6d7bb0c8b5` |
| Released governor at freeze | Spark v0.22.0 |
| Release / milestone / gate | v0.23 — Never automate inefficiency / milestone 20 / #480 (RED) |
| UTC observation timestamp | 2026-09-06T16:24:54Z |

- The #728/#729 native sub-issue hierarchy normalization occurred **before** this freeze and is GitHub metadata only; it changed nothing in the repository tree.
- At this freeze, **no** repository cleanup, dead-code removal, semantic canonicalization, test consolidation, docs canonicalization or dispatcher reduction (#738–#745) has begun.
- All later #729 measurements (#745 in particular) compare against this exact frozen SHA. Measurement scripts, if created, are run against it in a detached worktree, with the instrumentation version reported separately from the measured-system version.
