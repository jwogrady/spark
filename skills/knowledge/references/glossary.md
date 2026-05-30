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
  2. This shipped seed (the default) when no project glossary is found.
- **Forks replace the seed.** Spark is portable; the terms below are *Status26's*
  defaults. In another project, edit this file (or add a project-local glossary)
  to that project's vocabulary. The mechanism is generic; the contents are not.
- The **librarian** maintains the glossary: it adds new canonical terms it
  encounters, flags duplicates and drift, and proposes a single canonical
  definition when the same concept is named two ways.

## Rules for terms

- **Preserve casing and spelling exactly** (`CosmOS`, not `Cosmos` or `cosmos`;
  `zd`, not `ZD`, unless the entry says otherwise).
- **Do not expand or substitute.** Don't turn an internal name into "the platform"
  or "the system" to sound neutral.
- **First use in a doc** may gloss an internal term once (`Zonedock (zd)`), then
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

## Status26 seed vocabulary (do not over-normalize)

These terms are preserved as written. Definitions here are intentionally thin —
the librarian fills them in from verified sources; mark anything unverified.

- **CosmOS** — the platform Status26 is building.
- **Prime**
- **Nous**
- **Pulse**
- **Cronos**
- **Orbit**
- **Apex**
- **Valhalla**
- **Zonedock** (alias **zd**)
- **Rise Local** (alias **rl**)
- **WhoSpark**
- **ServiceRadar**
- **Cheap Websites**
- **Opstar**
- **Oasis**
- **Genesis**
- **cosmic** — adjective form, lowercase.
- **status26** / **Status26** — the company. Preserve the casing the source uses;
  `Status26` in prose, `status26` as an identifier/handle.

> Definitions above are placeholders to protect the *spelling and intent* of each
> term. They are **not** verified descriptions. The librarian should replace each
> with a sourced canonical definition (or mark it `Status: proposed` and leave an
> open question) rather than inventing one.
