# Spark Alpha Program

> The canonical plan for Spark's Alpha validation phase. Companion docs:
> [testing-guide.md](testing-guide.md) (what participants do),
> [feedback-template.md](feedback-template.md) (how evidence is captured),
> [coordinator-guide.md](coordinator-guide.md) (running the program — identity, consent, evidence, triage),
> [pilot-plan.md](pilot-plan.md) (the 3-person method-validation pilot),
> [exit-criteria.md](exit-criteria.md) (the evidence thresholds that end each phase).

## Why Alpha, and why now

The v0.14.0 proving release validated Spark's **engineering**: the release
pipeline, install path, doctor, the three release gates, and the behavioral
suites all work end-to-end on a real cut. That is necessary and now settled.

It validated nothing about the **product**. Every claim about usefulness,
usability, and workflow rests on the author's own use — a sample of one, and
the most biased one possible. Spark's defining principle is that claims follow
evidence; the one claim it cannot yet support is *"this is the right product."*

The Alpha exists to gather that evidence before the compatibility promise of a
stable 1.0 makes redesign expensive. During Alpha, **backwards compatibility is
explicitly not a goal** — if real usage disproves a design, we change it.

## Goals — what success looks like

Alpha succeeds when we can answer, with evidence from people who are not the
author, the one question that gates 1.0:

**Is Spark becoming the right product — and if not, what has to change?**

Concretely, success is:

1. Every [Alpha Objective](#alpha-objectives) below has an evidence-backed
   answer, not a hypothesis.
2. The command/verb model and the lifecycle are either **validated as-is** or
   **redesigned** on the strength of that evidence — and the redesign has itself
   been re-tested.
3. Participants who are not the author complete a real project through the
   lifecycle **without author assistance**, more than once.
4. We know which capabilities to keep first-class, demote to companions, merge,
   or delete.

Alpha does **not** succeed by "no bugs found" or "everyone was polite." It
succeeds by producing decisions.

## Alpha Objectives

These are the questions the whole program is instrumented to answer. Each maps
to evidence in the [feedback template](feedback-template.md) and a threshold in
[exit-criteria.md](exit-criteria.md).

**Workflow** — Can users discover the intended `ideate → plan → codify →
validate → ship` flow on their own? Where do they get confused, which verbs are
opaque, which lifecycle steps feel unnecessary, where is it magical, where
tedious?

**Product completeness** — What is missing, unnecessary, or overlapping? Which
capabilities should become companions, and which deserve first-class status?
(Live tension to resolve: `knowledge` vs `spark-docs:docit`; `bootstrap` vs
`onboard`; whether `validate` earns its own step or folds into `ship`.)

**Usability** — Can a new developer succeed unaided and recover from mistakes?
Which docs get ignored? Which commands must be memorized rather than discovered?
What surprises people?

**Value** — Does Spark actually save time, prevent mistakes, and improve
planning and delivery — and would experienced developers keep using it once the
novelty is gone? (This is the hardest and most important signal.)

**Product direction** — Should Spark stay CLI-first / skill-first / GitHub-first
/ Claude-first? Are the verbs right? Are there better abstractions? Should any
concept disappear? Redesign is on the table.

## Target users

**Include (the signal we need):**

- **Solo developers shipping real projects** with a Claude + GitHub
  subscription — Spark's actual audience per the stability contract.
- A spread of experience: 2–3 strong engineers (will stress the abstractions
  and the redesign questions), 3–4 mid-level (the core audience), 2–3 relative
  newcomers to structured delivery (will expose discoverability and recovery
  gaps fastest).
- People willing to use Spark on **work they actually care about**, not a toy —
  value only shows up under real stakes.
- A mix of new-project and existing-repo starts (so both `bootstrap`-then-setup
  and `onboard`-into-an-existing-repo paths get exercised).

**Exclude (would poison the signal):**

- The author and close collaborators — their fluency hides every discoverability
  and onboarding failure.
- Teams needing multi-user governance — out of scope by design; their feedback
  would pull toward a product Spark deliberately is not.
- Anyone who cannot use Claude Code + GitHub (the platform floor).
- Pure spectators who will not run a real lifecycle — they generate opinions,
  not evidence.

## Duration and sample size

**Evidence-gated, not calendar-gated.** The recommended window is a **floor of
6 weeks and a soft ceiling of ~10**, but Alpha ends when the [exit
criteria](exit-criteria.md) are met, not when a date passes.

- **Sample size: 8–12 active participants.** Small enough to read every session
  closely, large enough that a friction point reported by 3+ independent users
  is a signal rather than a personality. Below ~8, one loud opinion dominates;
  above ~15, qualitative depth (the thing Alpha needs) turns into survey noise.
- **Completed-lifecycle floor:** at least **10 full `ideate→ship` runs across
  ≥5 distinct users** before any exit decision. A large roster that never
  finishes a lifecycle proves nothing.

## Feedback methods, cadence, and prioritization

The evidence Spark needs is mostly qualitative and behavioral. Collect four
kinds, in decreasing order of trustworthiness:

1. **Observed sessions (highest signal).** 3–5 recorded or watched
   walkthroughs where a participant runs a lifecycle unaided while thinking
   aloud. Where they hesitate, backtrack, or ask "what does this do?" is the
   product's real map. One good observed session outweighs ten surveys.
2. **Structured per-lifecycle reports.** After each `ideate→ship` run,
   participants file the [feedback template](feedback-template.md) — one entry
   per run, not per week, so friction is captured while fresh.
3. **Friction log (continuous).** A running GitHub Discussions thread (or
   issues labeled `alpha-feedback`) for anything that made them stop and think,
   captured in the moment.
4. **Exit interview.** A 30-minute conversation at the end of each
   participant's Alpha, anchored on the Value questions — especially *"would you
   keep using this?"*

**Cadence:** template after every lifecycle; friction log continuous; a
15-minute weekly async check-in; observed sessions front-loaded (week 1–3, when
onboarding failures are freshest).

**Prioritization rule:** rank feedback by *independent reproduction*, not
volume or seniority. A confusion hit by **3+ independent users** is a
must-address finding. A single expert's redesign idea is a **Learn** item until
a second user's experience corroborates it. Delight signals are ranked the same
way — a workflow 3+ users call "magical" is a **Preserve**, protected from
change.

## Success metrics (and the vanity metrics we refuse)

Measured against the objectives, not for a dashboard:

| Dimension | Real metric | Not this (vanity) |
|---|---|---|
| Adoption | # participants who run ≥1 full lifecycle on real work | # installs, # stars |
| Completion | % of started lifecycles that reach a shipped PR unaided | # commands run |
| Workflow friction | Distinct stop-and-think points per lifecycle, trend over runs | "satisfaction 4.2/5" |
| Command discoverability | % of verbs a user invokes without being told they exist | # of verbs |
| Documentation effectiveness | Which docs are opened before asking for help vs never opened | # doc pageviews |
| Feature utilization | Which skills/companions get used unprompted a second time | # features shipped |
| Repeat usage | % who start a *second* project with Spark after novelty fades | DAU/session count |
| Qualitative satisfaction | Verbatim "would keep using because…/would drop because…" | NPS as a number |

The single most important number: **unaided completion rate on a second
project.** Novelty carries the first run; only value carries the second.

## Alpha Backlog

Grounded in the current repository (post-v0.14.0). Three buckets.

### Learn — needs user evidence before we touch it

- **Lifecycle shape.** Do all five stages earn their place, or do users
  routinely skip/merge some (esp. `validate` vs `ship`, `ideate` for small
  work)?
- **Verb model.** Are `brief`/`resume`/`state`/`orient` four concepts or one
  overloaded one? Do users understand `preferences` tiers without the diagram?
- **Onboarding entry.** Do first-timers find `/spark:onboard`, or bounce to raw
  verbs? Is `bootstrap` vs `onboard` a distinction users can make?
- **Companion boundaries.** Do users understand when to reach for `spark-audit`
  / `spark-connect` / `spark-docs` vs the core? Does `knowledge` (core) vs
  `docit` (companion) confuse?
- **Value under repetition.** Does Spark still feel worth it on project #2?
- **GitHub-first friction.** Does the hard `gh`/GitHub dependency exclude or
  frustrate otherwise-ideal users?

### Improve — justified now, pending only prioritization

- The install-e2e coverage gap (`onboard`) — *already fixed* this cycle; listed
  as the model for "found by validation, fixed with evidence."
- Discoverability scaffolding for the CLI verbs (a `spark help`/`--help` audit)
  *if* the discoverability metric is poor — hold until Alpha week 2 data.
- Any doc a majority of participants never open is a candidate for deletion or
  relocation, not expansion.

### Preserve — already validated, protect from churn

- The **enforcement doors** (PreToolUse guard + git hooks) — engineering-proven,
  hostile-tested; do not weaken without extraordinary evidence.
- **Release Please ownership** of tags/changelog/releases — proven end-to-end by
  v0.14.0; the human-merges-the-release-PR gate held correctly.
- **The three release gates** (milestone, release-notes, platform-compat) and
  the evidence-index contract — hardened and adversarially reviewed.
- **The stability contract** as the honesty backbone — extend it, don't dilute
  it.
- **Create-only / idempotent setup** — a safety property, not a preference.

## Beta readiness

Alpha → Beta is defined precisely in [exit-criteria.md](exit-criteria.md). In
summary, Spark may enter **Beta** when the *product questions are answered and
the command model has stopped moving*: workflow validated by unaided repeat
completion, no major conceptual redesign still pending, docs demonstrably
understandable, and the feature set substantially settled (adds allowed in Beta,
but no more "should this concept exist" questions open).

**Beta then proves durability, not discovery:** that the now-stable model holds
up across more projects and stacks, that upgrades don't surprise users, and that
the compatibility promise the stability contract makes is one the implementation
can actually keep. When Beta shows that — with evidence, not time — Spark earns
`v1.0.0`.

## Final recommendation

1. **Why Alpha is the correct stage.** Engineering is proven; the product is
   not. Jumping to 1.0 would freeze a compatibility promise around designs that
   exactly one biased user has validated. Alpha buys the right to change our
   mind cheaply, which is the whole point of a pre-1.0 phase.
2. **Biggest risks Alpha must intentionally expose.** (a) That the five-stage
   lifecycle is more ceremony than value for real solo work. (b) That the verb
   surface is broader than users can hold in their heads. (c) That the hard
   GitHub-first dependency narrows the audience more than assumed. (d) That the
   value evaporates once novelty does. Alpha should be designed to *provoke*
   these failures early, not to avoid them.
3. **Evidence that says "ready for Beta."** Unaided repeat completion, a command
   model that survived Alpha without a pending redesign, docs used-not-ignored,
   and 3+-user corroboration that the workflow saves time. Thresholds in
   [exit-criteria.md](exit-criteria.md).
4. **Evidence that says "fundamental redesign."** Users consistently succeeding
   *by ignoring or fighting* the intended workflow; multiple independent users
   abandoning before a shipped PR; the value question answered "no" on project
   #2; or a single concept (a stage, a verb cluster) that no unaided user can
   explain back. Any of these is a signal to redesign *during* Alpha — which is
   allowed, and is success, not failure.

The goal of Alpha is not to prove Spark is finished. It is to learn whether
Spark is becoming the right product — while changing it is still cheap.
