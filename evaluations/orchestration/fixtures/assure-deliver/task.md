# Assure & Deliver fixture — seeded-defect review task

**Group:** Assure & Deliver (Validate → Ship)
**What a candidate is given:** the diff in [`seeded.diff`](seeded.diff), presented
as a change proposed on a feature branch, ready for review.
**What a candidate must produce:** a review that surfaces the defects — the
normal output of `validate` orchestrating `/code-review` and `/security-review`.

The diff contains four deliberately seeded defects. The answer key
([`answer-key.tsv`](answer-key.tsv)) enumerates them. A run's `findings.tsv`
records, per defect, whether the review surfaced it.

**correctness = defects caught / defects seeded (4).**

The defects are representative of what Spark's own guardrails and coding
standards target (POSIX-friendly bash, `set -euo pipefail`, no commented-out
code, safe destructive operations) — not synthetic puzzles.

> This fixture measures *detection*, not repair. Whether the reviewer also
> proposes a correct fix is captured separately in the quality rubric.
