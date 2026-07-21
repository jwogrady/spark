# Orchestration evaluation

> # ⚠️ RESEARCH EVIDENCE — NOT SHIPPED CAPABILITY
>
> Everything in this directory is evidence for the #198 v0.12 decision gate,
> under the #190 orchestration research epic. It measures lifecycle behavior so
> a proposed multi-agent topology can be compared to what Spark does today. No
> result here describes a shipped feature. Do **not** derive any README /
> ROADMAP / ADR / standards claim from these fixtures until an implementation
> ships and validates. See [`BASELINE.md`](BASELINE.md).

This is **not** a pass/fail test suite. It lives outside `tests/` on purpose and
is not run by `tests/run.sh` — its outputs are graded measurements, not
assertions.

---

## Why it exists

#190 proposes reorganising the lifecycle into three execution groups —
**Shape** (Ideate → Plan), **Build** (Codify), **Assure & Deliver** (Validate →
Ship) — each with its own agent topology and model profile. A recommendation
without a baseline is opinion. This directory:

1. pins one representative, realistic fixture per group, and
2. records how today's **single-agent lifecycle** does on them across four
   metrics — **quality, correctness, latency, cost** —
3. behind a **rerunnable harness** so any candidate topology can be scored on
   the *same* fixtures for a direct comparison.

---

## Layout

```
evaluations/orchestration/
├── README.md                # this file
├── BASELINE.md              # the recorded single-agent measurement + method
├── run.sh                   # the harness (zero-dep bash + awk)
├── rates.tsv                # model → $/Mtok, for the derived cost metric
├── fixtures/
│   ├── shape/               # framing/planning task
│   ├── build/               # scoped implementation issue
│   └── assure-deliver/      # seeded-defect diff
│       ├── task.md          # the task a candidate is given
│       ├── answer-key.tsv   # enumerated, checkable items → correctness
│       ├── rubric.tsv       # graded dimensions → quality
│       └── seeded.diff      # (assure-deliver only) the change under review
└── runs/
    └── single-agent-baseline/   # one topology's recorded results
        └── <group>/
            ├── findings.tsv     # per answer-key item: caught 1/0 (+ note)
            ├── scorecard.tsv    # per rubric dimension: score (+ note)
            └── run.tsv          # model, token counts, latency (+ methods)
```

---

## The four metrics

Full derivations are in [`BASELINE.md`](BASELINE.md). In brief:

| Metric | Derivation | Nature |
|---|---|---|
| **correctness** | answer-key items caught / total (`findings.tsv` vs `answer-key.tsv`) | objective, exact |
| **quality** | rubric score / rubric max (`scorecard.tsv` vs `rubric.tsv`) | subjective, human-graded |
| **latency** | `latency_seconds` read from `run.tsv`, labeled measured/estimate | recorded, not timed by the harness |
| **cost** | `tokens_in/1e6·in_rate + tokens_out/1e6·out_rate` (rates from `rates.tsv`) | derived; exact math on possibly-estimated token inputs |

The harness is deliberate about honesty: it computes correctness and cost
exactly, but it never invents latency or token figures it cannot observe — it
reads them from `run.tsv` and labels each with its `*_method` (`measured` or
`estimate`).

---

## How to run

```sh
cd evaluations/orchestration
./run.sh list                          # fixtures + recorded topologies
./run.sh validate single-agent-baseline  # check files are well-formed
./run.sh score single-agent-baseline   # print the metrics table
./run.sh help
```

`score` defaults to `single-agent-baseline` when no topology is named.

## How to measure a candidate topology

To compare a proposed topology against the baseline on identical inputs:

1. Create `runs/<topology>/<group>/` for each of the three groups.
2. Fill `findings.tsv` (one row per `answer-key.tsv` item, `caught` = 1/0),
   `scorecard.tsv` (one row per `rubric.tsv` dimension), and `run.tsv`
   (`model`, `tokens_in`, `tokens_out`, `tokens_method`, `latency_seconds`,
   `latency_method`) — mirroring the baseline's files.
3. If the topology uses a model not already in [`rates.tsv`](rates.tsv), add it.
4. `./run.sh score <topology>` and compare to
   [`./run.sh score single-agent-baseline`](BASELINE.md).

File formats are plain tab-separated values; lines starting with `#` are
comments. No JSON, no `jq`, no network — only bash and `awk`.

---

## Research-evidence caveat (again, on purpose)

The recorded baseline is **n = 1, single-grader**, with **estimated** latency and
token counts. It is a reference line for a decision, not a benchmark result and
not a product claim. Cite it only as what it is: research evidence attached to
#198. See [`BASELINE.md`](BASELINE.md) → *Measurement limits*.
