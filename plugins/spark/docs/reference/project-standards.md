# Reference — project standards documents

> Reference — information-oriented. What Spark seeds into a repository as its
> readable working contract, where it lives, and the boundary between prose you
> own and configuration Spark resolves.

`spark setup` (and `bootstrap`, which ends by running it) seeds two documents at
the **repository root**, create-only:

| Document | Owns |
|---|---|
| `CONVENTIONS.md` | Workflow, branching, commits, PR/review expectations, issue tracking, collaboration boundaries. |
| `ENGINEERING-STANDARDS.md` | Stack and tooling, quality gates, dependencies, security/configuration posture, CI and release posture, and deviations from Spark defaults. |

Both are seeded from shipped templates — `preferences/templates/standards/` in
the plugin — and are **create-only and idempotent**: an existing document is a
project choice, so it is kept and reported (`= exists — kept`), never
overwritten. A fresh run reports them created (`+`); every later run reports
them kept. They live at the root so they are the first thing a collaborator
finds.

## The prose / configuration boundary

Spark keeps two layers deliberately separate:

- **Project-local prose** — `CONVENTIONS.md` and `ENGINEERING-STANDARDS.md` are
  the human-readable, reviewable contract. A human edits them freely.
- **Machine-resolvable facts** — `.spark/preferences.json` is the only layer
  Spark's automation reads, resolved across the three tiers of ADR-0010
  (shipped defaults → operator overrides → committed project facts).

Spark never treats arbitrary prose edits as executable configuration. Editing a
sentence changes what humans read; it does not change what automation does. When
a written standard must affect automation, change the matching preference too.
The rationale and source hierarchy are recorded in ADR-0020.

## The `spark:pref` marker

Lines in the seeded docs whose fact is also a resolved preference carry an
HTML-comment marker naming the key and the value the line asserts:

```
<!-- spark:pref key=value -->
```

For example, the branching line in `CONVENTIONS.md`:

```
- GitHub Flow: short-lived feature branches off the trunk; never commit to the
  trunk directly. <!-- spark:pref branch.model=github-flow -->
```

Only explicitly marked lines are machine-backed; unmarked prose is guidance,
never silently configuration. The marker is the seam a drift check can parse
(`grep`/`sed`) to compare what the doc asserts against the resolved preference,
so prose and configuration can be proven to agree rather than assumed to.

The keys the shipped templates mark:

- `CONVENTIONS.md` — `branch.model`, `commit.convention`, `commit.subject-max`,
  `issue.taxonomy`, `permissions.preset`.
- `ENGINEERING-STANDARDS.md` — `stack.default`, `stack.frontend`, `stack.infra`,
  `ci.provider`, `release.mechanism`.

Every marked key exists in [`preferences/defaults.json`](../../preferences/defaults.json);
its resolved value and source tier are shown by `spark preferences`.

## Related docs

- [engineering-preferences.md](engineering-preferences.md) — the operator's
  prose standard behind the shipped defaults.
- [cli.md](cli.md) — `spark setup` and `spark preferences`, which seed and
  resolve these.
- [glossary.md](../glossary.md) — Spark vocabulary.
