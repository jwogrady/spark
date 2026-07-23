# Spark Alpha — exit criteria

> The exact evidence required to move between phases. **Evidence thresholds, not
> dates.** Alpha ends when these are met; if they are never met, that is itself
> the finding. Program design is in [alpha-program.md](alpha-program.md).

## Phase model

```
Alpha  → learn whether Spark is the right product   (redesign allowed & expected)
Beta   → prove the settled model is durable          (compatibility now matters)
v1.0.0 → stable public product                       (the promise the contract makes)
```

## Alpha → Beta: required evidence

All of the following must hold, each backed by evidence in the
[feedback record](feedback-template.md), not by assertion. The numbers are
thresholds against the [sample of 8–12](alpha-program.md#duration-and-sample-size);
scale proportionally if the roster differs.

### 1. Workflow validated
- [ ] **≥10 full `ideate→ship` runs across ≥5 distinct participants** are on
      record.
- [ ] **≥70% of started lifecycles reach a shipped PR unaided** (no
      author/coordinator help mid-run).
- [ ] Stop-and-think points per lifecycle **trend down** across a participant's
      1st → 2nd run (the workflow is learnable, not just survivable).

### 2. Command model stable
- [ ] **No verb or lifecycle stage has a redesign still pending** on evidence.
      Either it was validated, or it was changed and the change re-tested.
- [ ] **≥60% of the core verbs are discovered unaided** by a majority of
      participants (measured, not assumed).
- [ ] No single concept (a stage, a verb cluster like brief/resume/state) that
      **no unaided participant can explain back** in their own words.

### 3. Documentation understandable
- [ ] For every "stuck" moment, the doc participants reached for **answered
      them** in the majority of cases.
- [ ] **No doc that a majority of participants never opened** survives without a
      decision to relocate, shrink, or delete it (ignored docs are a finding).

### 4. No major conceptual redesign remaining
- [ ] Every **Learn** item in the [Alpha backlog](alpha-program.md#alpha-backlog)
      has an evidence-backed disposition: validated, changed, or explicitly
      deferred with a reason.
- [ ] The four "fundamental redesign" signals (below) are **absent**.

### 5. Feature set substantially complete
- [ ] The keep / demote-to-companion / merge / delete decision is **made** for
      every capability, with evidence.
- [ ] No capability that **3+ independent participants** needed and found
      missing remains unaddressed.

### 6. Users consistently succeed without author assistance
- [ ] **≥3 participants complete a *second* project** through Spark unaided.
- [ ] **≥3 independent participants** report, in their own words, that Spark
      **saved time or prevented a mistake** on real work.
- [ ] The "would you keep using it?" one-liner is **net positive** across
      participants who finished ≥2 runs.

**Any one criterion unmet → stay in Alpha** and address it. Alpha is not
time-boxed; it is evidence-boxed.

## The "fundamental redesign" signals (Alpha stop conditions)

If any of these appear with independent corroboration, redesign **during**
Alpha — this is success, not failure:

- Participants consistently succeed by **ignoring or fighting** the intended
  workflow (they ship, but not the Spark way).
- **Multiple independent participants abandon** before a shipped PR for the same
  reason.
- The **value question is answered "no" on project #2** by multiple
  participants — novelty carried run 1, nothing carried run 2.
- A core concept (a stage, a verb cluster) that **no unaided participant can
  explain back**.

## Beta → v1.0.0: what Beta must prove

Beta assumes the model is settled; it proves **durability and promise-keeping**:

- [ ] The stable command model holds across **more projects and ≥3 distinct
      stacks** without a conceptual change.
- [ ] **Upgrades do not surprise users**: at least one real version-to-version
      upgrade is completed by participants with no undocumented breakage — the
      [stability contract](../../plugins/spark/docs/reference/stability.md)'s
      classifications match what actually changed.
- [ ] The **known limitations** in the stability contract are still true and
      still acceptable to Beta users (solo scope, skill-quality-by-use, routing
      evidence, `.spark/` as non-API).
- [ ] **No release-critical defect** across the Beta window's releases (the
      proving-release pipeline keeps working on every cut, not just once).
- [ ] Repeat usage sustains: participants keep choosing Spark for **new** work
      without prompting.

When Beta shows all of that — on evidence — Spark is promoted to `v1.0.0` with a
`Release-As: 1.0.0` commit: a promotion, not a feature release.

## What none of these are

Not "N weeks elapsed," not "N stars," not "no open issues," not "the author is
satisfied." Every gate above is something a person who is not the author did,
succeeded at, or told us — because that is the only evidence that can answer the
question Alpha exists to ask.
