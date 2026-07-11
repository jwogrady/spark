# How to capture internal knowledge

> How-to — task-oriented.

Use this to turn raw input — founder notes, architecture decisions, ops
know-how, Claude Code session discoveries — into clean, durable, searchable
internal docs: ADRs, system docs, product specs, SOPs/runbooks, onboarding
guides, glossary entries. For outward-facing docs and README glow-ups, use the
`docit` skill from the `spark-docs` companion plugin instead.

1. Invoke `/spark:knowledge` from the repo root, pointing it at the raw input
   (notes, a file, a transcript, a session summary, or a described topic).
2. The Intake agent runs alone first: it separates facts, assumptions, and open
   questions into `.knowledge-notes/00-intake.md` and recommends a doc type.
   The one rule is **capture truth; mark uncertainty** — unknowns are named,
   never smoothed over.
3. The Author drafts with the template the doc type calls for — ADR, system
   doc, product spec, or SOP/runbook. A mixed request means it drafts each
   slice.
4. The Librarian-Editor reviews: draft feedback plus placement, dedup,
   cross-links, and glossary changes. The Author folds the feedback in and
   resolves or defers each open question.
5. The Librarian-Editor writes the final doc in one voice to the recommended
   path — inside the repo's existing docs structure (`docs/adr/`, `docs/ops/`,
   …), never a parallel scheme — and updates the glossary/index.
6. For any overwrite of an existing doc, review the diff and give a go-ahead
   before it's written.
7. If operator-level vocabulary candidates were flagged, they are presented
   for promotion to `~/.config/spark/knowledge/` — nothing is copied without
   your explicit go-ahead, and the project-local entry stays put.
8. Hand the result to `/spark:ship` to commit and open a PR. Commit only the
   published docs; keep `.knowledge-notes/` gitignored — it's process exhaust.

**Done when** the doc is filed where the team will find it, every fact is
separated from assumption, and remaining unknowns are flagged in the doc rather
than hidden.
