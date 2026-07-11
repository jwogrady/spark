# knowledge — project glossary (configurable)

This is the **vocabulary the crew must preserve verbatim**. Knowledge reads it before
writing and never normalizes, expands, or "corrects" a term on this list into
generic corporate language. Domain language carries meaning; flattening it loses
the meaning.

## How this file is used

- Every knowledge agent consults a glossary before writing. **Resolution order:**
  1. A project-local glossary if one exists — `docs/glossary.md`, anything under
     `docs/glossary/`, or `.knowledge/glossary.md`. This is the source of truth for
     the repo knowledge runs in.
  2. The operator store — `~/.config/spark/knowledge/glossary.md` — for terms the
     project glossary doesn't define. Written only through the librarian-editor's
     explicit promotion step (see [`operator-knowledge.md`](operator-knowledge.md)).
  3. This shipped seed (the default) when neither defines the term.
- **The seed ships generic.** Spark is portable; the entries below are format
  examples, not anyone's real vocabulary. Replace them with your own terms (or
  add a project-local glossary) — the mechanism is generic, and the contents are
  yours to define.
- The **librarian-editor** maintains the glossary: it adds new canonical terms it
  encounters, flags duplicates and drift, and proposes a single canonical
  definition when the same concept is named two ways.

## Rules for terms

- **Preserve casing and spelling exactly** as the entry defines it — an internal
  name like `AcmeOS` stays `AcmeOS`, never `Acmeos` or `acme-os`.
- **Do not expand or substitute.** Don't turn an internal name into "the platform"
  or "the system" to sound neutral.
- **First use in a doc** may gloss an internal term once (`Widgetron (wt)`), then
  use it bare. Don't re-gloss on every mention.
- If a term looks wrong or stale, **flag it** in the doc's `## Knowledge Notes` — do
  not silently change canonical vocabulary.

## Glossary entry format

```
### <Term>

**Canonical:** <the one definition the company agrees on>
**Aliases:** <other names seen in the wild, if any>
**Domain:** <product | architecture | ops | brand>
**Status:** <current | deprecated | proposed>
**See also:** [[related-term]], <doc path>
```

---

## Example entries (replace with your vocabulary)

These are **placeholders that show the format** — no real project uses them.
Delete them and seed your own terms, or let the librarian-editor grow this file
as it encounters your vocabulary.

### AcmeOS

**Canonical:** The internal platform every Acme product runs on.
**Aliases:** —
**Domain:** architecture
**Status:** current
**See also:** [[widgetron]], docs/architecture/acmeos.md

### Widgetron

**Canonical:** Acme's flagship widget-configuration product.
**Aliases:** wt
**Domain:** product
**Status:** current
**See also:** [[acmeos]]

### ship-it Friday

**Canonical:** The weekly release window; nothing merges to trunk after it closes.
**Aliases:** —
**Domain:** ops
**Status:** proposed
**See also:** docs/ops/release-process.md
