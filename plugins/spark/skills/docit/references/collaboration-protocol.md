# docit — collaboration protocol

How the personas run as **real subagents** and how the skill orchestrates them.
Each persona is a plugin agent under [`agents/docit/`](../../../agents/docit/)
(registered as `spark:docit:<name>`). They draft in parallel, every persona
evaluates its related neighbors, and the feedback is folded back in before a single
Editor-in-Chief voice ships. It borrows `review`'s shared-notes mechanism but,
unlike `review`, is **not strictly sequential**: only ground truth blocks; the rest
of the team runs concurrently and reconciles through a cross-evaluation round.

---

## Who orchestrates

The skill — the main loop — is the sole orchestrator: a subagent cannot spawn
another, so every dispatch and barrier is the main loop's job, and the agents
coordinate only through shared notes on disk, never by calling each other. That
general pattern is documented once in
the architecture map;
below is what's specific to `docit`.

A persona is **dispatched fresh once per phase it takes part in** — there is no
long-lived agent that drafts, waits, then cross-evals. The agent *definition* under
`agents/docit/` carries the durable identity (domain, neighbors, honest-hype);
the orchestrator's per-dispatch brief names the phase. Launch the agents of one
phase together in a single turn (multiple Agent calls) so they run concurrently.

---

## The dependency graph

Each persona declares the notes it **reads**. That graph has two jobs:

- It seeds drafting — a persona drafts from ground truth plus whatever neighbor
  drafts already exist.
- It defines **cross-evaluation neighbors** — the personas a draft must stay
  consistent with: its **upstream** (the notes it reads) and its **downstream**
  (the personas that read it).

```
00 cartographer       → read by: everyone (ground truth)
01 skimmer            reads 00            → read by: 02, 03, 08
02 adopter            reads 00,01         → read by: 03, 06, 08
03 skeptic            reads 00,01,02      → read by: 04, 05
04 evaluator          reads 00,03         → read by: 05, 09
05 believer           reads 00,03,04      → read by: 06, 07
06 coach              reads 00,02,05      → read by: 07, 08
07 contributor        reads 00,05,06      → read by: aggregators
08 visual-storyteller reads 00,01,02,06   → read by: aggregators
09 returning-user     reads 00,04         → read by: aggregators
10 discoverer (SEO)   reads 00 + all prior   (aggregator)
11 amplifier          reads 00 + all prior   (aggregator)
12 editor-in-chief    reads 00–11            (synthesis)
```

---

## The phases — what the orchestrator dispatches

```
Phase 0 — Ground truth (barrier)
  Dispatch ONE agent: spark:docit:cartographer.
  It writes .docit-notes/00-ground-truth.md alone. Wait for it.
  Nothing else starts until this exists. It is the only hard barrier.

Phase 1 — Parallel drafting
  Dispatch 01–09 CONCURRENTLY (nine Agent calls in one turn), each with a
  "Phase 1 — Draft" brief. Each reads ground truth plus any neighbor drafts
  already on disk; they do NOT block on the full upstream chain — Phase 2
  repairs any drift. Wait for all nine.
        ↓ .docit-notes/01-hero.md … 09-changelog.md

Phase 2 — Cross-evaluation (parallel)
  Re-dispatch 00–09 CONCURRENTLY with a "Phase 2 — Cross-evaluate" brief.
  Each reads its dependency-graph neighbors and appends targeted feedback to
  the "Cross-eval feedback" section of each neighbor's note. The Cartographer
  fact-checks EVERY draft (it is upstream to all). Wait for all.
        ↓ feedback appended to each neighbor's note

Phase 3 — Revise in place (parallel)
  Re-dispatch 01–09 CONCURRENTLY with a "Phase 3 — Revise" brief. Each folds
  the feedback it received into its own draft and marks it resolved. If a round
  surfaced contradictions, run Phase 2–3 once more; stop when a round produces
  no new feedback. Wait for all.

Phase 3b — Aggregators
  Dispatch spark:docit:discoverer, wait, then spark:docit:amplifier
  (11 reuses 10's hook phrases). They run after 01–09 are stable because they
  summarize everything.
        ↓ 10-discoverability.md, 11-launch.md

Phase 4 — Issue Council (file-mediated rounds, each a barrier)
  A subagent debate can't be a live conversation, so the council runs as rounds
  through .docit-notes/issue-council.md — see "The Issue Council" below.
        ↓ .docit-notes/issue-council.md (nominations, debate, tally)

Phase 5 — Synthesis + file the slate (barrier)
  Dispatch ONE agent: spark:docit:editor-in-chief. It reads every revised
  note, all cross-eval feedback, and the council outcome; resolves remaining
  conflict; enforces one voice; presents a diff and waits for go-ahead; writes
  the final artifacts; and files the council's ranked slate as `proposed`
  GitHub issues for the human to triage.
        ↓ README.md, docs/PHILOSOPHY.md, docs/ Diátaxis tree,
          CHANGELOG.md, examples/launch-copy.md, 12-editor-log.md,
          13-proposed-issues.md
```

The Cartographer's cross-evaluation role is special: in Phase 2 it fact-checks
**every** draft against ground truth (it is upstream to all), flagging any claim
that lacks a citation. That is the enforcement arm of the honest-hype contract —
and in Phase 4 it carries a veto (below).

---

## Shared notes structure

Each persona writes one markdown file to `.docit-notes/`. Use consistent
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
which gaps become issues and how high they rank. Because subagents can't talk to
each other directly, the orchestrator runs the council as **file-mediated rounds**,
all in `.docit-notes/issue-council.md`, each round a barrier:

1. **Nominate (parallel dispatch).** Re-dispatch every persona with a "Phase 4 —
   nominate" brief. Any persona may nominate an issue from its domain — a gap it
   found, the Coach's missing how-to, the Evaluator's absent CI, a claim the
   Cartographer made the team cut. Each nomination carries a one-paragraph case,
   provenance (which note/finding raised it, cited to ground truth), and a
   proposed priority. Wait for all.

2. **Debate (parallel dispatch).** Re-dispatch every persona with a "Phase 4 —
   debate" brief; each reads the full nominations list and responds: **co-sign**
   (add weight), **contest** (duplicate, out of scope, low value, or unsafe under
   honest-hype), or **counter** (reframe / merge / split). Argue from your
   perspective — the Skimmer fights for what wins a star, the Adopter for what
   unblocks a newcomer, the Evaluator for what earns trust. The debate is recorded,
   not erased. Wait for all.

3. **Vote (parallel dispatch).** Re-dispatch every persona with a "Phase 4 — vote"
   brief; each casts two ballots per nomination:
   - **Admission** — in or out. A contested nomination needs more in-votes than
     out-votes to survive.
   - **Priority** — each persona scores survivors (P1=3, P2=2, P3=1); the mean
     sets the proposed rank.
   Wait for all.

4. **Tally (Editor-in-Chief).** Dispatched in Phase 5, the Editor-in-Chief, as
   chair, tallies the votes into a ranked slate and records the result. The chair
   does **not** break ties.

**Two overrides:**
- **Cartographer veto.** Any issue that asserts an unbuilt feature as real, or
  would push the docs to overclaim, is vetoed regardless of the vote. Honest-hype
  is not up for election.
- **Human breaks ties.** When admission splits evenly, or two issues tie for a
  priority rank that matters, the Editor-in-Chief surfaces the deadlock to the
  human (via the orchestrator) with **both sides' arguments**, and the human
  decides before anything is filed. The team debates; the human rules.

The human is still the final authority after filing, too: the slate is *proposed*,
and triage on GitHub (keep/close) remains theirs.

---

## Output and handoff

- Final artifacts land in the repo (`README.md`, `docs/`), not in `.docit-notes/`.
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
- `.docit-notes/` is scratch — gitignored, not committed. It holds the reasoning
  behind the docs (drafts, cross-eval feedback, revisions, issue proposals) for the
  duration of a run; the published docs and their git history are the durable record.
- Hand the docs change to [`ship`](../../ship/SKILL.md) to commit and open a PR.
