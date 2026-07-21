# ADR: Project-local prose standards, seeded and human-owned

Date: 2026-07-21
Status: Accepted
Owner: jwogrady

## Context

A project should not have to infer its working standards from plugin internals
or a single global prose reference. Spark already resolves machine facts across
three tiers (ADR-0010) and materializes them with `spark setup`, but the
*readable* contract — how this repository branches, commits, reviews, and what
stack and release posture it holds — lived only in the operator's global
`engineering-preferences.md` and in `.spark/preferences.json` keys. Neither is a
document a collaborator opens at the repo root to learn how the project works,
and neither invites a human to adapt it per project.

The risk in closing that gap is treating prose as configuration. If Spark
silently read arbitrary sentences as executable settings, an innocuous edit
could change automation invisibly, and the reviewable text and the machine
behavior would drift with no way to tell. `.spark/preferences.json` is already
the sole machine-resolvable layer (ADR-0010) and must stay so.

## Decision

- **Two repo-root documents, seeded create-only.** `spark setup` (and
  `bootstrap`, which ends by running it) seeds `CONVENTIONS.md` (workflow,
  branching, commits, PR/review, collaboration boundaries) and
  `ENGINEERING-STANDARDS.md` (stack/tooling, quality gates, dependencies,
  security/CI/release posture, deviations) from shipped templates in
  `plugins/spark/preferences/templates/standards/`. Like every other artifact
  the carry-in engine places, an existing doc is a project choice: it is kept
  and reported, never overwritten, so the operation is idempotent.

- **A three-layer source hierarchy.** Shipped defaults and templates
  (`preferences/defaults.json`, the standards templates) provide the starting
  point; the project-local prose docs are the readable, reviewable, human-owned
  contract; `.spark/preferences.json` remains the only machine-resolvable facts
  layer, resolved across ADR-0010's three tiers. The prose sits above the JSON
  in readability and below it in authority over automation.

- **Prose is never silently configuration.** Spark does not read arbitrary doc
  edits as settings. A machine-backed line in a seeded doc carries an explicit
  HTML-comment marker, `<!-- spark:pref key=value -->`, naming the resolved
  preference key and the value the line asserts. Only marked lines are
  machine-backed; unmarked prose is guidance. The marker is a stable, parseable
  seam (`grep`/`sed`) a drift check can use to prove the doc and the resolved
  preference agree, rather than assuming they do.

- **Each doc opens with a legend** distinguishing shipped default guidance,
  project decisions to adapt (`[ADAPT]`), and human placeholders
  (`TODO(decision)`), so a reader knows what is safe to keep, what to change,
  and what still needs a decision.

Why: making the contract a root document a human owns is what turns a standard
from plugin-internal into project-local and reviewable. Marking only explicit
lines — rather than parsing prose — is what keeps "prose is not configuration"
a guarantee instead of a hope, and gives a later drift check a single seam to
read instead of guessing at intent.

## Alternatives Considered

- **Extend `.spark/preferences.json` with prose fields.** Rejected: it
  overloads the machine fact store with human text and blurs the very boundary
  this decision protects.
- **Point projects at the global `engineering-preferences.md`.** Rejected: a
  global operator reference is not this repository's contract, cannot be adapted
  per project, and is not discoverable from the repo root.
- **Parse the prose docs as configuration (sync arbitrary edits into
  preferences).** Rejected: silent, fragile, and exactly the invisible-drift
  failure the explicit marker avoids.

## Consequences

- Every armed repository gains two root docs a collaborator can read and a human
  can adapt; setup and re-runs stay idempotent because they are create-only.
- The `spark:pref` marker format becomes a supported contract other tooling
  depends on (a drift check parses it), so its shape must stay stable.
- Prose and configuration can now diverge if a human edits a marked line without
  changing the preference — surfacing that divergence is deliberately left to a
  separate drift check that reads the marker.
- Spark ships no `CONVENTIONS.md`/`ENGINEERING-STANDARDS.md` of its own from
  these templates; they are target-project artifacts, and their absence in a
  repo is an informational skip, not an error.

## Related Docs

- [../architecture/spark-internals.md](../architecture/spark-internals.md) — the architecture map
- [0010-preferences-source-model.md](0010-preferences-source-model.md) — the three-tier machine-fact resolution this sits atop
- [0022-orient-first-classification.md](0022-orient-first-classification.md) — orientation decides when a new project is scaffolded and these seed
- [../../plugins/spark/docs/reference/project-standards.md](../../plugins/spark/docs/reference/project-standards.md) — the shipped reference for the docs, the boundary, and the marker
