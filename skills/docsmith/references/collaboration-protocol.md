# docsmith — collaboration protocol

How the personas work as a team — a multi-phase process where drafts are produced
in parallel, every persona evaluates its related neighbors, and the feedback is
folded back in before a single Editor-in-Chief voice ships. It borrows `review`'s
shared-notes mechanism but, unlike `review`, is **not strictly sequential**: only
ground truth blocks; the rest of the team runs concurrently and reconciles through
a cross-evaluation round.

---

## The dependency graph

Each persona declares the notes it **reads**. That graph has two jobs:

- It seeds drafting — a persona drafts from ground truth plus whatever neighbor
  drafts already exist.
- It defines **cross-evaluation neighbors** — the personas a draft must stay
  consistent with: its **upstream** (the notes it reads) and its **downstream**
  (the personas that read it).

```
00 The Cartographer  → read by: everyone (ground truth)
01 Skimmer           reads 00            → read by: 02, 03, 08
02 Adopter           reads 00,01         → read by: 03, 06, 08
03 Skeptic           reads 00,01,02      → read by: 04, 05
04 Evaluator         reads 00,03         → read by: 05, 09
05 Believer          reads 00,03,04      → read by: 06, 07
06 Coach             reads 00,02,05      → read by: 07, 08
07 Contributor       reads 00,05,06      → read by: aggregators
08 Visual Storyteller reads 00,01,02,06  → read by: aggregators
09 Returning User    reads 00,04         → read by: aggregators
10 Discoverer (SEO)  reads 00 + all prior   (aggregator)
11 Amplifier         reads 00 + all prior   (aggregator)
12 Editor-in-Chief   reads 00–11            (synthesis)
```

---

## The phases

```
Phase 0 — Ground truth (barrier)
  00 The Cartographer drafts .docsmith-notes/00-ground-truth.md alone.
  Nothing else starts until this exists. It is the only hard barrier.

Phase 1 — Parallel drafting
  Personas 01–09 draft concurrently, each from ground truth plus any
  neighbor drafts already on disk. They do NOT block on the full upstream
  chain — parallelism is safe because Phase 2 repairs any drift.
        ↓ .docsmith-notes/01-hero.md … 09-changelog.md

Phase 2 — Cross-evaluation (parallel)
  Each persona reads its dependency-graph neighbors (upstream + downstream)
  and writes targeted feedback to the "Cross-eval feedback" section of each
  neighbor's note. Focused, not blanket: review only your neighbors.
        ↓ feedback appended to each neighbor's note

Phase 3 — Revise in place (parallel)
  Each persona revises its own draft using the feedback it received, then
  marks the note resolved. Repeat Phase 2–3 once more if a round surfaced
  contradictions; stop when a round produces no new feedback.

Phase 3b — Aggregators
  10 Discoverer then 11 Amplifier draft from the revised set (11 reads 10).
  They run after 01–09 are stable because they summarize everything.

Phase 4 — Issue Council (the personas debate and fight for issues)
  Every persona nominates the gaps it found, argues for them, contests the
  others', and votes. The outcome is a ranked slate of issues — see "The
  Issue Council" below. Deadlocks go to the human.
        ↓ .docsmith-notes/issue-council.md (nominations, debate, tally)

Phase 5 — Synthesis + file the slate (barrier)
  12 The Editor-in-Chief — the team leader — reads every revised note, all
  cross-eval feedback, and the council outcome; resolves any remaining
  conflict; enforces one voice; writes the final artifacts; and files the
  council's ranked slate as `proposed`-labeled GitHub issues for the human
  to triage (keep or close).
        ↓ README.md, docs/PHILOSOPHY.md, docs/ Diátaxis tree,
          CHANGELOG.md, docs/launch-copy.md, 12-editor-log.md,
          13-proposed-issues.md
```

The Cartographer's cross-evaluation role is special: in Phase 2 it fact-checks
**every** draft against ground truth (it is upstream to all), flagging any claim
that lacks a citation. That is the enforcement arm of the honest-hype contract —
and in Phase 4 it carries a veto (below).

---

## Shared notes structure

Each persona writes one markdown file to `.docsmith-notes/`. Use consistent
sections so neighbors can leave feedback and the Editor-in-Chief can cross-reference.

### Per-note sections

- **Persona** — which perspective this note is written from and the question it asks.
- **Neighbors** — the upstream + downstream personas this note must reconcile with.
- **Draft** — the prose/section this persona owns.
- **Claims & citations** — each concrete claim with a pointer into
  `00-ground-truth.md` (or the file/command that proves it).
- **Cross-eval feedback** — left by neighbors in Phase 2; the owner addresses each
  item in Phase 3 and marks it resolved.

`00-ground-truth.md` is the exception: it has no "Persona" or "Cross-eval
feedback" section — it is the verified fact base every other note cites, and the
Cartographer instead leaves fact-check feedback on others.

---

## The honest-hype contract

The single mechanism that keeps the docs truthful:

1. The Cartographer writes only verified facts and splits shipped from roadmap.
2. Every later persona must cite ground truth for any concrete claim.
3. In Phase 2 the Cartographer fact-checks every draft and flags uncited claims;
   the owner cuts or sources them in Phase 3.
4. The Editor-in-Chief refuses any claim still without a citation — cut or soften
   it, and log the decision in `12-editor-log.md`.

Energy and confidence are encouraged; fabrication is not. A bold tagline is fine;
a feature that doesn't exist is not.

---

## The Issue Council (Phase 4)

The personas don't just hand gaps to the leader — they **debate and fight for**
which gaps become issues and how high they rank. The whole council happens in one
file, `.docsmith-notes/issue-council.md`, in four steps:

1. **Nominate.** Any persona may nominate an issue from its domain — a gap it
   found, the Coach's missing how-to, the Evaluator's absent CI, a claim the
   Cartographer made the team cut. Each nomination carries a one-paragraph case,
   provenance (which note/finding raised it, cited to ground truth), and a
   proposed priority.

2. **Debate.** Other personas respond: **co-sign** (add weight), **contest**
   (duplicate, out of scope, low value, or unsafe under honest-hype), or
   **counter** (reframe / merge / split). Argue from your perspective — the
   Skimmer fights for what wins a star, the Adopter for what unblocks a newcomer,
   the Evaluator for what earns trust. The debate is recorded, not erased.

3. **Vote.** Two ballots per nomination:
   - **Admission** — in or out. A contested nomination needs more in-votes than
     out-votes to survive.
   - **Priority** — each persona scores survivors (P1=3, P2=2, P3=1); the mean
     sets the proposed rank.

4. **Tally.** The Editor-in-Chief, as chair, tallies the votes into a ranked slate
   and records the result. The chair does **not** break ties.

**Two overrides:**
- **Cartographer veto.** Any issue that asserts an unbuilt feature as real, or
  would push the docs to overclaim, is vetoed regardless of the vote. Honest-hype
  is not up for election.
- **Human breaks ties.** When admission splits evenly, or two issues tie for a
  priority rank that matters, the chair surfaces the deadlock to the human with
  **both sides' arguments** and the human decides before anything is filed. The
  team debates; the human rules.

The human is still the final authority after filing, too: the slate is *proposed*,
and triage on GitHub (keep/close) remains theirs.

---

## Output and handoff

- Final artifacts land in the repo (`README.md`, `docs/`), not in `.docsmith-notes/`.
- The Editor-in-Chief presents a diff and waits for go-ahead before overwriting
  existing public docs.
- **The leader files the council's slate, the human decides.** From the Issue
  Council outcome the Editor-in-Chief writes `13-proposed-issues.md` — the ranked,
  fully-annotated slate — and files each as a `proposed`-labeled GitHub issue
  (`gh issue create`). Any deadlock was already resolved by the human in Phase 4.
  The human then triages in GitHub: keep the keepers, close the rejects; accepted
  issues flow on to `plan`.
  The leader **files** but never **closes or comments** — that triage is the
  human's, per Spark's GitHub guardrails. If `gh`/remote is unavailable, the issues
  stay in `13-proposed-issues.md` for manual filing.
- Archive `.docsmith-notes/` (commit it) so the reasoning behind the docs — drafts,
  cross-eval feedback, revisions, and the issue proposals — is recoverable and the
  next glow-up can build on it.
- Hand the docs change to `commit` and `ship` to land it through the lifecycle.
