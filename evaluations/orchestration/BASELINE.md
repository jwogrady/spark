# Orchestration baseline — single-agent lifecycle

> # ⚠️ RESEARCH EVIDENCE — NOT SHIPPED CAPABILITY
>
> This document records a measurement of Spark's **current single-agent
> lifecycle** on the orchestration evaluation fixtures. It exists to give the
> #198 decision gate and the topology (#203) / model-selection (#204) ADRs a
> defensible comparison point.
>
> It is **not** a claim about shipped behavior. Nothing here may be represented
> as a Spark feature, a roadmap commitment, or a validated result in the README,
> ROADMAP, ADRs, or generated standards **until an implementation ships and
> validates**. It is evidence for a decision, not a description of the product.

Filed against #205 (build the fixtures and measure the baseline), under the
#190 orchestration research epic, attached to the #198 v0.12 decision gate.

---

## What was measured

The three lifecycle execution groups from #190, one representative fixture each:

| Group | Fixture | Task |
|---|---|---|
| **Shape** (Ideate → Plan) | `fixtures/shape/` | Turn a vague "I can't tell what setup changed / where I am" request into a problem statement + scoped issues. |
| **Build** (Codify) | `fixtures/build/` | Implement a scoped issue: `spark doctor --quiet`. |
| **Assure & Deliver** (Validate → Ship) | `fixtures/assure-deliver/` | Review a diff carrying four seeded defects. |

The **topology under measurement** is `single-agent-baseline`: one agent
carrying the whole lifecycle, the behavior Spark ships today. Its run records
live under `runs/single-agent-baseline/`.

---

## Results

Reproduce with `./run.sh score single-agent-baseline` (verbatim output):

```
group             correctness   quality    latency   cost(USD,est)
----------------  -----------  --------  ---------  --------------
shape                5/7  0.71      0.80     300~           0.4250
build                6/6  1.00      0.88     150~           0.2125
assure-deliver       3/4  0.75      0.88     180~           0.2000
```

`~` marks an estimated latency; `cost(USD,est)` is derived, not metered (method
below).

---

## How each metric is derived (method)

**correctness — objective, exact.**
`answer-key items caught / total`. Each fixture ships a fixed `answer-key.tsv`;
a run records `1`/`0` per item in its `findings.tsv`. The harness sums and
divides. No judgment at score time — the judgment is the per-item `caught` value,
recorded with a rationale note in `findings.tsv`.

**quality — subjective, human-graded, normalised.**
`sum(scorecard scores) / sum(rubric max)`. Each fixture ships a `rubric.tsv` of
0..max dimensions; a human grader records a score per dimension in the run's
`scorecard.tsv` with a note. Grader for this baseline: `jwogrady`, one pass.

**latency — read, not timed, and labeled.**
Read from each run's `run.tsv` (`latency_seconds`), carrying `latency_method`.
A zero-dependency bash harness cannot observe an LLM run's wall clock, so it
reports the recorded value and marks it `measured` (`s`) or `estimate` (`~`).
**All baseline latencies are estimates** (see Measurement limits).

**cost — derived, exact arithmetic on labeled inputs.**
`tokens_in/1e6 * input_rate + tokens_out/1e6 * output_rate`. Rates come from
[`rates.tsv`](rates.tsv) (Anthropic published pricing, recorded 2026-06-24),
keyed by the run's `model`. Token counts come from `run.tsv` with a
`tokens_method` field. The multiplication is exact; the **token counts are
estimates** for this baseline, so the resulting cost is an estimate. Model:
`claude-opus-4-8` at $5.00 / $25.00 per 1M input / output tokens.

---

## Measurement limits (read before citing any number)

1. **n = 1, single grader.** Each group is one recorded pass, graded by the
   author. These are point observations, not distributions. Treat them as a
   reference line, not a statistic. Re-running with multiple passes and an
   independent grader is future work.
2. **Latency and token counts are estimates**, not instrument readings. The
   harness deliberately does not fabricate precise wall-clock or usage figures
   it cannot observe from bash; it reads recorded values and labels them
   `estimate`. The estimates here are the author's informed sizing of a typical
   single-agent pass on each fixture, recorded so cost can be computed by a
   fixed formula. When a run is instrumented for real token/latency capture,
   drop the numbers into `run.tsv` and flip the `*_method` field to `measured`.
3. **cost is a formula, not a bill.** It reflects token estimates × published
   rates for one model. It ignores prompt caching, retries, and subagent
   fan-out — all of which a candidate topology would change.
4. **correctness and quality are only as good as the fixtures.** One fixture per
   group cannot represent the whole space of lifecycle work; it is a
   representative probe chosen to be realistic, not exhaustive.

---

## What the baseline suggests (hypotheses for #198, not conclusions)

These readings are consistent with #190's starting hypotheses but do **not**
confirm them — a candidate topology has to be measured on these same fixtures to
show a real delta.

- **Build scored highest on correctness (6/6).** Consistent with #190's premise
  that a single, well-scoped implementation issue benefits least from parallel
  agents — the baseline already clears the bar. A candidate Build topology has
  little headroom to justify added orchestration here.
- **Shape scored lowest (5/7).** The two misses were a thin prior-art survey
  (`S4`) and premature solutioning (`S7`) — exactly the failure modes #190
  expects parallel evidence/critique agents plus a synthesis barrier to address.
  This is where a candidate topology has the most to prove.
- **Assure & Deliver caught the bug and the security defect but missed the
  repo-specific style standard (`AD4`, "no commented-out code").** The native
  single-agent review is strong on general bug/security detection and weak on
  Spark-specific standards — evidence relevant to the #206 "independent review
  roles" slice, which the #198 gate decides whether to ship.

None of the above is a shipped capability or a committed plan. It is input to a
human go/no-go decision.

---

## Reproducing and extending

```sh
cd evaluations/orchestration
./run.sh list                          # fixtures + recorded topologies
./run.sh validate single-agent-baseline
./run.sh score single-agent-baseline   # the table above
```

To measure a **candidate topology** for a direct comparison, add
`runs/<topology>/<group>/{findings,scorecard,run}.tsv` mirroring the baseline's
files, then `./run.sh score <topology>`. Same fixtures, same metrics, same
formula — the comparison is apples to apples by construction. See the
[README](README.md) for file formats.
