# Release records

A release record is the durable account of **one release**: what it set out to
deliver, what evidence certified it, what was found and repaired along the way,
and what shipped. One file per release, named for the version.

## What these files own

**Release chronology lives here.** When a release is withdrawn, replanned,
blocked, or certified more than once, the account of that belongs in the record
for the release it happened to — not in `ROADMAP.md`, not in `CHANGELOG.md`, and
not in the README.

That is the point of the directory. The same story told in four places becomes
four stories: they are written on different days, corrected at different times,
and the first correction to any one of them creates a contradiction that nobody
notices until someone relies on the stale copy. The withdrawal of the
`v0.17`–`v0.19.1` line was being retold in the roadmap, the changelog, the
problem statement and here, and the copies had already drifted — one of them
still named a published baseline that two releases had superseded.

So a current-state document states the durable conclusion it needs and **cites**
the record. It does not retell it.

## What owns what

| Question | Authority |
|---|---|
| What is Spark now? | `README.md`, and the shipped documentation under `plugins/*/docs/` |
| Where is it going? | `ROADMAP.md` |
| Why is it built this way? | `docs/adr/` |
| What did one release deliver and certify? | **this directory** |
| What changed, commit by commit? | Git and GitHub |
| What did Release Please render for a version? | `CHANGELOG.md` — a generated projection, not an authority |

This is [ADR-0031](../adr/0031-state-provenance-ownership.md) applied to
releases: the repository owns current state and durable meaning, Git and GitHub
own provenance, and a citation carries the evidence while the tree carries the
conclusion.

## Records are provenance, and are not rewritten

A release record is written about a moment and stays written that way. It is not
brought into line with later terminology, later structure, or a later
understanding of what should have happened — a record edited to agree with the
present has stopped being evidence of anything.

That includes the uncomfortable parts. `v0.22.md` keeps the certification run it
failed, and the documentation regression that shipped with it, because a record
that erases the run in which it was blocked is worth less than no record.

Correct a factual error; never tidy the history.

## Adding a record

Name it for the version (`v0.23.md`). State the disposition in the governed
status vocabulary the
[release-docs checklist](../../plugins/spark/docs/reference/release-docs-checklist.md#roadmap-status-vocabulary)
defines, so the roadmap and the record cannot disagree about whether something
shipped. Cite issues and pull requests for the evidence rather than transcribing
them.
