# docsmith — collaboration protocol

How the audience lenses share findings, coordinate reads, and produce coherent
public docs. Same shared-notes mechanism as `review`; the output is marketing,
not an audit.

---

## Execution order

Lenses run sequentially, not in parallel, so each reads current notes:

```
00 Cartographer    (reads: nothing yet)
   ↓ .docsmith-notes/00-ground-truth.md   ← the factual substrate
01 The Skimmer     (reads: 00)
   ↓ .docsmith-notes/01-hero.md
02 The Adopter     (reads: 00, 01)
   ↓ .docsmith-notes/02-quickstart.md
03 The Skeptic     (reads: 00, 01, 02)
   ↓ .docsmith-notes/03-positioning.md
04 The Believer    (reads: 00, 03)
   ↓ .docsmith-notes/04-philosophy.md
05 The Contributor (reads: 00, 04)
   ↓ .docsmith-notes/05-contributing.md
06 The Amplifier   (reads: 00, all prior)
   ↓ .docsmith-notes/06-launch.md
07 Editor-in-Chief (reads: 00–06)
   ↓ README.md, docs/PHILOSOPHY.md, docs/launch-copy.md, 07-editor-log.md
```

---

## Shared notes structure

Each lens writes one markdown file to `.docsmith-notes/`. Use consistent sections
so the Editor-in-Chief can cross-reference.

### Per-note sections

- **Audience** — who this lens speaks for and the question they ask.
- **Draft** — the prose/section this lens owns.
- **Claims & citations** — each concrete claim with a pointer into
  `00-ground-truth.md` (or the file/command that proves it).
- **Notes to next lens** — handoff highlights.

`00-ground-truth.md` is the exception: it has no "Audience" — it is the verified
fact base every other note cites.

---

## The honest-hype contract

The single mechanism that keeps the docs truthful:

1. The Cartographer writes only verified facts and splits shipped from roadmap.
2. Every later lens must cite ground truth for any concrete claim.
3. The Editor-in-Chief refuses any claim without a citation — cut or soften it,
   and log the decision in `07-editor-log.md`.

Energy and confidence are encouraged; fabrication is not. A bold tagline is fine;
a feature that doesn't exist is not.

---

## Output and handoff

- Final artifacts land in the repo (`README.md`, `docs/`), not in `.docsmith-notes/`.
- The Editor-in-Chief presents a diff and waits for go-ahead before overwriting
  existing public docs.
- Archive `.docsmith-notes/` (commit it) so the reasoning behind the docs is
  recoverable and the next glow-up can build on it.
- Hand the change to `commit` and `ship` to land it through the lifecycle.
