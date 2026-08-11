# The Spark Evaluation surface

> Reference — the canonical contract for Spark's Evaluation surface. This is the
> **policy**: the file formats, metrics, governance, and boundaries every
> evaluation suite shares. The **mechanism** that implements it is
> [`../../evaluations/lib/eval.sh`](../../evaluations/lib/eval.sh). A dev-doc — it
> governs how Spark is built and never ships. Owner: `jwogrady`.
>
> **Status (v0.16):** the recorded suites and the library remain the evidence
> behind Spark's measured decisions (v0.12 orchestration, v0.15 routing), and
> the library still runs future measurements. The *CI gates* that consumed the
> evidence index — the platform-compat review and the PR traceability check —
> were retired by the governance deletion test (#361). Nothing enforces this
> contract on ordinary changes anymore; it applies when an evaluation is run.

Spark owns evaluation (Constitution [Article II.4](../product-constitution.md);
adopted by [ADR-0025](../adr/0025-capability-evaluation-framework.md)). This
document is the reusable contract: a capability's Q4 evidence (see the
[Capability Evaluation Framework](../governance/capability-evaluation.md)) is
produced here, in a form any suite can adopt.

## Anatomy of the surface

```
evaluations/
├── lib/eval.sh            # the shared mechanism (score, validate, list)
└── <suite>/               # one suite per evaluation domain
    ├── run.sh             # thin: sets this suite's policy, calls eval_main
    ├── rates.tsv          # model → $/Mtok, for the cost metric
    ├── fixtures/<group>/  # the fixed inputs a candidate is scored on
    └── runs/<topology>/<group>/   # one recorded set of results per topology
```

`evaluations/orchestration/` is the first suite; it consumes the library. Suites
are graded measurement, not pass/fail tests — they live outside `tests/` and are
not run by `tests/run.sh`.

## The TSV contract

All files are tab-separated; lines beginning with `#` are comments; blank lines
are ignored. This lets fixtures annotate themselves and keeps everything
diffable and `jq`-free.

| File | Owner | Columns |
|---|---|---|
| `fixtures/<group>/answer-key.tsv` | fixture | one checkable item per row (→ correctness denominator) |
| `fixtures/<group>/rubric.tsv` | fixture | `dimension`, `max` (→ quality denominator) |
| `runs/<t>/<group>/findings.tsv` | a run | one row per answer-key item; column 2 is `caught` (1/0) |
| `runs/<t>/<group>/scorecard.tsv` | a run | one row per rubric dimension; column 2 is the graded score |
| `runs/<t>/<group>/run.tsv` | a run | `key<TAB>value`: `model`, `tokens_in`, `tokens_out`, `tokens_method`, `latency_seconds`, `latency_method` |

`validate` enforces both shape and value integrity: findings must have one row
per answer-key item and scorecard one per rubric dimension (matching column-1
ids); `caught` must be exactly `0`/`1`; each score must be a non-negative number
within its rubric max; every rubric max must be a positive number; and every
number scoring reads — `tokens_in`/`tokens_out`/`latency_seconds` and the model's
in/out rates — must be a present, non-negative number (otherwise awk would coerce
it to 0 and publish a silently wrong figure). Any of these failing means the run
is not well-formed. This is what the release gate consumes, so a run carrying a
malformed metric or run-fact value cannot pass validation, and therefore cannot
reach a green release-readiness result. (Free-text fields such as notes and the
`*_method` labels are not scored and are not validated.)

## The four metrics

Derivations are fixed by the library and must not drift per suite:

- **correctness** — `caught / total`. Objective; the answer key is fixed and a
  run only records 1/0 per item.
- **quality** — `score / max`. Human-graded; a grader fills `scorecard.tsv`.
- **latency** — read from `run.tsv` and labeled `measured` or `estimate`. The
  harness never times a run itself (a zero-dep bash script cannot observe an LLM
  run's wall clock); it reports what the run recorded.
- **cost** — `tokens_in/1e6·in_rate + tokens_out/1e6·out_rate`, rates keyed by
  model from `rates.tsv`. The arithmetic is exact; its token inputs may be
  estimates, and `tokens_method` says which.

**Honesty discipline:** the harness computes correctness and cost exactly and
never invents a latency or token figure it cannot observe — it labels every
recorded value `measured` or `estimate`. A result is cited only as what it is.

## Three instruments, one boundary

Spark verifies three different things three different ways. Keep them distinct:

| Instrument | Nature | Home | Records |
|---|---|---|---|
| `spark doctor` | static, pass/fail | the CLI ([ADR-0011](../adr/0011-doctor-is-the-validation-gate.md)) | layout, JSON, frontmatter, links |
| behavioral tests | executed, pass/fail | `tests/` ([ADR-0018](../adr/0018-behavioral-tests-are-the-second-ci-gate.md)) | shipped flows and both enforcement doors |
| **evaluation** | graded measurement | `evaluations/` (this doc) | quality/correctness/latency/cost of a capability |

Doctor and behavioral tests answer *is it well-formed / does it work?* Evaluation
answers *how well, and at what cost?* — a graded question, never a green check.

## Experiment governance

An evaluation exists to decide something. State the decision rule up front:

- **Adopt/kill bar.** A candidate is adopted only if it beats the recorded
  baseline on a stated threshold (e.g. "≥3/4 fixtures with an acceptable
  cost/latency trade"). A measured "no" is a successful outcome — record it.
- **Baseline first.** Record the current behavior as a topology before scoring a
  candidate, so the comparison is on identical inputs.
- **Grader discipline.** Quality is human-graded; the grader and the rubric are
  named, and `scorecard.tsv` carries a per-dimension note. Single-grader, n=1
  results are labeled as such and never presented as benchmarks.

## Evidence retention

- Recorded runs (`runs/<topology>/`) are committed evidence — they are the audit
  trail behind an adopt/kill decision and are not deleted when a topology loses.
- A run's `*_method` labels are retained verbatim; a later reader must be able to
  tell measured from estimated without re-deriving.
- Research evidence is marked as such at its source (a banner) and never promoted
  to a product claim until an implementation ships and validates.

## The Evaluation → Release seam

Capability Traceability ends `… → Evaluation → Release`. The
[Platform Compatibility Review gate](../product-constitution.md) (Constitution
Article VII) consumes evaluation results at release time: a capability whose
declared `required` evidence is absent or malformed does not ship. This document
defines the evidence and the declaration; the gate enforces it.

## The evidence index (capability → evidence)

A capability declares its evaluation evidence in `evaluations/evidence-index.tsv`
(the machine-readable form of the CEF's Q4, adopted in
[ADR-0026](../adr/0026-evidence-declaration-and-release-gate.md)). Tab-separated;
`#` comments and blank lines ignored:

```
capability_id    requirement    suite    topology
```

- `capability_id` — originating issue number, or another stable capability id.
- `requirement` — `required` or `not-required`.
- `suite` / `topology` — the recorded evidence to validate; may be empty when
  `not-required`.

Three deliberate states:

- **absent** — the capability is *undeclared* (advisory during initial adoption);
- **`not-required`** — a deliberate CEF determination that graded evaluation is
  unnecessary, not an accidental absence;
- **`required`** — must resolve to valid evidence, or the release is blocked.

The gate resolves each `required` row's suite and topology and runs that suite's
own `run.sh validate <topology>` — reading only pass/fail. It **validates, never
interprets**: no scoring, no recomputation, no reinterpretation of adopt/kill.
The orchestration suite is research evidence, not a shipped capability, so it is
intentionally not indexed.

## Adding a new suite

No new mechanism is needed — reuse the library:

1. Create `evaluations/<suite>/` with `fixtures/`, `runs/`, and `rates.tsv`.
2. Write a thin `run.sh` that sources `../lib/eval.sh`, sets `EVAL_TITLE`,
   `EVAL_FIXTURES`, `EVAL_RUNS`, `EVAL_RATES`, `EVAL_GROUPS`,
   `EVAL_DEFAULT_TOPOLOGY`, and (optionally) `EVAL_BANNER`, then calls
   `eval_main "$@"`.
3. State the suite's adopt/kill bar in its README.

## See also

- [`../../evaluations/lib/eval.sh`](../../evaluations/lib/eval.sh) — the shared mechanism
- [`../../evaluations/orchestration/README.md`](../../evaluations/orchestration/README.md) — the first suite
- [Constitution Article II.4](../product-constitution.md) and [ADR-0025](../adr/0025-capability-evaluation-framework.md) — the surface's authority
- [Applying the CEF](../governance/capability-evaluation.md) — where evaluation supplies the Q4 evidence
