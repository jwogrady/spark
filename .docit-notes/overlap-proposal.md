# Proposal — resolving the `docit` / `codify` / `ideate` overlap

> Requested by the author (2026-05-30) while breaking a docit Issue-Council
> deadlock. This is a **proposal for the human to decide**, not a decision.
> Author/credit: `jwogrady`.

## The guiding model (the author's words)

> Humans ideate ideas and **own + prioritize** the problems. Bots **validate** the
> ideas and **propose an issue** to fix. Bots then **look at the fix and help the
> human decide if it works.** The council exists to *help the human solve the
> issues that get work done.*

Every option below is judged against that pipeline:
**human frames → bots validate & propose → human picks → bots implement → bots help human verify.**

## What the three skills actually do today

| Skill | Stage | Audience / output | Engine |
|---|---|---|---|
| `ideate` | Ideate | A written **problem statement** (human-driven, uses `grill-me`) | 1 interview loop |
| `docit` | Ship+ | **Public** docs (README, philosophy, launch copy) | 13-persona crew → shared notes → cross-eval → Issue Council → Editor |
| `codify` | Knowledge | **Internal** knowledge (decisions, systems, processes, glossary) | 6-agent crew → shared notes → Editor |

## Where the overlap really is (and isn't)

The overlap is **not** in their *purpose* — problem-framing, public docs, and
internal knowledge are three genuinely different jobs with different audiences and
triggers. Collapsing them would lose real distinctions. The overlap is in **two
shared mechanisms** each skill currently re-implements:

1. **The author-crew substrate.** `docit` and `codify` are almost the same machine:
   personas/agents → a scratch-notes directory (`.docit-notes/` vs `.codify-notes/`)
   → parallel drafting → an Editor synthesis pass. The orchestration is duplicated;
   only the cast and the audience differ. (`review` is a third instance of the same
   pattern.)
2. **The "propose work" handoff.** `ideate` emits a problem statement; `docit`'s
   Issue Council emits proposed issues; `codify` and `review` surface gaps too. Each
   has its **own** bespoke path toward the Plan stage. That is the overlap the
   author *feels*: several skills independently feeding candidate work into Plan,
   with no single surface the human triages from.

## Three options

### Option A — Merge `docit` + `codify` into one "author crew", keep `ideate` separate
One skill, two modes (`--public` / `--internal`), one cast superset.
- **Pro:** removes the duplicated engine outright.
- **Con:** conflates two distinct user intents and two distinct triggers into one
  command; the public/internal casts barely overlap, so the "merge" is mostly a
  shared launcher. Loses the clear `docit` (outward) / `codify` (inward) mental
  model the author deliberately built.

### Option B — Keep all three skills; extract a shared **crew substrate** (Recommended, part 1)
Leave `ideate`, `docit`, `codify` (and `review`) as distinct skills, but factor the
common machinery into one reusable orchestration pattern they all build on:
shared-notes lifecycle, phase/barrier protocol, cross-eval, Editor synthesis.
- **Pro:** kills the real duplication without collapsing distinct intents; one place
  to fix orchestration bugs; new crews (e.g. a future audit crew) get the substrate
  free. Honors "additive, self-contained skills" — the substrate is shared *doctrine
  + reference*, not a runtime import.
- **Con:** requires defining the substrate carefully so skills stay self-contained
  (no cross-skill runtime imports, per `CLAUDE.md`).

### Option C — Unify the **"propose work" handoff** into one surface (Recommended, part 2)
Route every skill that proposes work — `ideate`, `docit` council, `codify`, `review`
— through **one shared proposed-work surface** that the Plan stage consumes. One
format, one place the human triages, one veto/priority convention.
- **Pro:** directly implements the author's model — bots *propose*, the human *owns
  and prioritizes* from a single queue; the council "helps the human solve the issues
  that get work done" instead of each skill having a private issue path.
- **Con:** needs a small spec for the shared proposal format + Plan's intake.

## Recommendation

**Adopt B + C; reject A.** Keep the three skills distinct (their jobs and audiences
are genuinely different), and remove the *actual* duplication in two targeted moves:

1. **Crew substrate** — one documented orchestration pattern (shared notes, phases,
   cross-eval, Editor) that `docit`/`codify`/`review` all follow, so the engine
   lives in one place.
2. **Unified proposal handoff** — `ideate` (human-framed), and the `docit`/`codify`/
   `review` councils (bot-discovered), all emit into **one** proposed-work surface
   that `plan` triages. This is the spine of the author's division of labor.

### How the three then map onto the pipeline

- **human frames** → `ideate` (the only human-driven intake; `grill-me` pressure-tests it)
- **bots validate & propose** → `docit`/`codify`/`review` councils discover gaps and
  file into the unified proposal surface
- **human picks & prioritizes** → triage that one surface; kept items → `plan`
- **bots implement** → `build`
- **bots help human verify** → `fix-issue` + `/code-review` + `/security-review` + `verify`

## Suggested next step (for the human to choose)

This proposal is itself a candidate problem statement. The clean way to act on it,
consistent with the model above, is to **run `ideate` on "unify the crew substrate +
proposal handoff"**, then let `plan` decompose it — rather than refactoring inline.

---

## Author's ruling — 2026-05-30 (supersedes the A/B/C menu above)

The author set the direction directly. **Eliminating overlap is P1 — done before any
new skills or agent expansion.**

**Ownership boundaries (single clear lane each):**
- **`docit`** owns **documentation**.
- **`codify`** owns **coding and implementation**.
- **`ideate`** owns **exploration and idea generation**.

> ⚠️ **Reconciliation flag:** this redefines `codify` away from its current
> implementation (a 6-agent *internal-knowledge* crew) and overlaps the existing
> **`build`** skill (the Generate/implementation stage). The audit must resolve
> `codify` vs `build` and the fate of the current knowledge-capture crew — do not
> assume; confirm with the author.

**Governing principles:**
- **Reference Claude-native, don't reimplement.** Do not create a custom Spark skill
  if Claude already provides the capability; reference the native capability instead.
- **Separate documentation workflows from coding workflows** wherever possible.
- Keep custom skills only when they add **project-specific** value.
- Every agent/skill gets **one clear lane** and **explicit non-goals** so
  responsibilities don't bleed together.

**The audit's scope:** `docit`, `codify`, `ideate`, all custom skills, and
Claude-native capabilities — find and remove overlap before expanding.
