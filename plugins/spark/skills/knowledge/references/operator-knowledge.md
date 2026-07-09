# operator knowledge — the portable store and the promotion rule

> Reference for the `knowledge` skill and its librarian. Defines the operator
> knowledge home, the test for what belongs there, and the explicit promotion
> step that is the only way anything gets in. This instantiates the
> Operator-layer knowledge class (ADR-0008) and the Project → Operator
> carry-forward motion; the scoping mirrors the preferences tiers (ADR-0010).

## The home

Operator knowledge lives at `~/.config/spark/knowledge/` — beside the operator
preferences file `~/.config/spark/preferences.json`, and like it, optional.
Both honor `XDG_CONFIG_HOME` the same way
(`${XDG_CONFIG_HOME:-$HOME/.config}/spark/`), so the knowledge home always
sits beside the preferences file. Two files, nothing else:

| File | Holds |
|---|---|
| `glossary.md` | Operator vocabulary — terms used in every project, in the entry format of [`glossary.md`](glossary.md) |
| `decisions.md` | Standing decisions that transcend any one project |

The librarian creates the directory and files on first promotion; their absence
is normal, and everything degrades to the shipped seed plus project-local
behavior. Nothing reads `decisions.md` yet — it accumulates until a reader
earns its place. There is no sync or merge tooling across machines — the store
is a plain directory on one machine until it proves itself.

## Operator-level or project-level?

Two questions decide the layer:

1. **Would this still be true and useful in a repo that doesn't exist yet?**
   Yes → operator candidate.
2. **Does it name this project's code, product, domain, or people?**
   Yes → project-level; it stays in the repo.

| Operator-level | Project-level |
|---|---|
| Vocabulary you would re-explain in every new repo | Terms defined by this repo's domain or product |
| Standing decisions about how you work ("squash-merge always") | Decisions about this codebase — those are ADRs in `docs/adr/` |
| Conventions no single preferences key captures | Facts a teammate on this project needs but a stranger project doesn't |

When in doubt, it is project-level. Promoting later is cheap; un-promoting a
project fact from the shared store is not.

## Resolution order

Same shape as the preferences tiers, later tiers winning:

1. shipped seed — [`glossary.md`](glossary.md)
2. operator store — `~/.config/spark/knowledge/glossary.md`
3. project-local — `docs/glossary*` or `.knowledge/glossary.md`

**Project-local wins on conflict** — the same rule the glossary already states
for forks. Promotion never edits or deletes the project-local entry; the repo
copy stays canonical for that repo.

## The promotion protocol

Promotion is deliberate and logged — never silent copying (ADR-0008):

1. **Recommend.** In its shelve pass the librarian lists operator-level
   candidates in `.knowledge-notes/librarian.md` under **Promotion
   candidates**, each with a one-line why — or states there are none.
2. **Approve.** The orchestrator presents the candidates to the user; nothing
   is written without an explicit go-ahead, per candidate or as a batch.
3. **Append and log.** In its maintain pass the librarian appends each
   approved entry to `glossary.md` or `decisions.md`, carrying a provenance
   line — that line *is* the log, durable and traveling with the entry.

### Entry formats

Glossary entries use the format in [`glossary.md`](glossary.md) plus the
provenance line. Decisions:

```
### <decision title>

**Decision:** <one sentence, imperative>
**Why:** <the reason it transcends a project>
**Status:** current | superseded
**Promoted:** YYYY-MM-DD from <repo>
```

## Relationship to the neighbors

- **Preferences** — the tiers `preferences/defaults.json` →
  `~/.config/spark/preferences.json` → `<repo>/.spark/preferences.json`,
  resolved by `spark preferences` — are machine-resolvable keys that skills
  apply; operator knowledge is prose that humans and agents read. A convention
  that reduces to one key belongs in preferences, not here.
- **Work state** — `.spark/state.json`, rendered by `spark resume` and read by
  the session brief — is Project-layer and per-repo; nothing in it is ever
  promoted here.
