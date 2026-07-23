# Spark Alpha — pilot plan

> A 3-participant pilot that validates the **testing method**, not Spark's
> product design, before the full 8–12-person cohort. If the method is broken
> or unsafe, fix the Alpha materials immediately; do **not** change Spark's
> product design on one participant's experience.

## Who

Exactly three, one per experience band (the bands that will stress different
parts of the method):

| Slot | Participant | What they pressure-test |
|---|---|---|
| 1 | Strong engineer | The abstractions and the redesign questions; will the form capture a sharp critique? |
| 2 | Mid-level solo developer | The core audience path end to end |
| 3 | Newcomer to structured delivery | Onboarding, discoverability, and recovery — fails fastest, exposes the most method gaps |

Each runs **one full `ideate→ship` lifecycle** on real (non-toxic, shareable)
work and files one `alpha-feedback` report.

## Pilot-success checklist

The pilot succeeds when the **method** clears all of these. Each is about the
process, not the product.

### Installation & environment
- [ ] All three install from the published path (`/plugin marketplace add
      jwogrady/spark` → `install spark`) with no coordinator intervention.
- [ ] `spark doctor --requirements` reports **Ready** for each before they
      start (the environment arbiter fired correctly).

### First lifecycle completion
- [ ] Each participant carries one unit of work from `ideate` to a shipped PR
      (or reaches a clear, self-explained stopping point — a *documented* stop
      is a valid pilot outcome).

### Instructions are self-sufficient
- [ ] Each followed `testing-guide.md` **without asking the coordinator to
      interpret it.** Any question that required interpretation is a method bug
      to fix before the cohort.

### The form captures enough to apply the exit criteria
- [ ] Every field in `alpha-feedback.yml` was answerable and answered.
- [ ] The three filed reports contain enough to evaluate each
      [exit criterion](exit-criteria.md) — unaided completion, stage friction,
      discoverability, docs used, value, keep/stop. (Mapping below.)

### No routinely-misunderstood or vague question
- [ ] No form field was misread by ≥2 of the 3, and none produced an
      unusably vague answer across the board. A field that did is reworded
      immediately.

### Coordinator can separate product friction from environment failure
- [ ] For every problem reported, the coordinator could classify it as
      environment (doctor --requirements not Ready → fix setup) vs product
      (Ready and still confused → real signal), per `coordinator-guide.md`.

## Exit-criteria coverage (why the form is sufficient)

Each Alpha→Beta criterion maps to at least one form field, so three real reports
are enough to *rehearse* applying the criteria (not meet them — that needs the
full cohort):

| Exit criterion | Form field(s) |
|---|---|
| Full runs across N participants | `participant`, `run_number`, `unaided` |
| ≥70% unaided completion | `unaided`, `unaided_detail` |
| Friction trends down run-over-run | `run_number`, `stage_friction` |
| Command model stable / no redesign pending | `stop_and_think`, `anything_else` |
| Verbs discovered unaided | `discoverability` |
| A concept no one can explain | `discoverability`, `stop_and_think` |
| Docs answered / docs ignored | `docs_used` |
| Missing / unnecessary capabilities | `value`, `anything_else` |
| Repeat-usage value | `run_number`, `value` |
| Time saved / mistake prevented | `value` |
| Keep-using net positive | `keep_using`, `keep_using_why` |

## When to change what

- **Method broken or unsafe** (install fails, a field is misunderstood, privacy
  gap, coordinator can't classify friction) → fix the Alpha materials
  **immediately**, before the cohort.
- **A product opinion** (a stage felt tedious, a verb is confusingly named) →
  **record only.** One participant is a hypothesis, never a change. Product
  changes wait for the cohort's independent corroboration (≥3), per the
  coordinator guide.

## After the pilot

Confirm the checklist, apply any method fixes, then open the full cohort per
[alpha-program.md](alpha-program.md). The pilot's own three reports roll into the
Alpha evidence set — nothing is wasted.
