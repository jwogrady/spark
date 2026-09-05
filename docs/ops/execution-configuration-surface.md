# Execution configuration surface (#722)

Companion to [`telemetry-baseline.md`](telemetry-baseline.md). That record measures
what a run *cost*. This one names what can be *controlled*, how confidently each
fact is known, and which controls may never be tuned for speed.

It exists because #480 requires material efficiency improvement in at least two
useful dimensions **without reducing correctness**, and the first bounded attempt
could not honestly compare unequal work. Before optimizing further, the
controllable surface has to be written down — including the parts that are not
measurable, which stay `NOT ASSESSED` rather than being guessed.

## Evidence vocabulary

Every environment or configuration fact carries exactly one class. The classes are
not interchangeable, and none of them is authority.

| Class | Meaning |
|---|---|
| `DECLARED` | Explicitly configured by the operator or the project (a settings file, a preference, a governing issue). |
| `OBSERVED` | Mechanically verified as a current fact (read from a file, measured by a tool, returned by an API). |
| `INFERRED` | Supported by evidence but not proven. Never reported as fact. |
| `UNKNOWN` | Not established. **Distinct from "does not exist"** — a posture that was never gathered is unknown, not absent. |

Three separations follow from this and are load-bearing:

- **Desired configuration ≠ effective configuration ≠ observed result.** What a
  settings file asks for is not what the runtime applied, and neither is what the
  run actually produced.
- **Capability is not authority.** An installed binary, a reachable API, or a
  granted token is `OBSERVED` capability. Authority comes only from an explicit
  governing grant (#677 for routine engineering here). The 1Password CLI being on
  `PATH` authorizes nothing.
- **An alarm heuristic is not a clearance.** A name containing `prod` raises
  suspicion; the *absence* of that string proves nothing. An unrecognized target
  stays `UNKNOWN` and outside authority.

## The measurement model

A benchmark row is only meaningful if every stage is recorded, because a
difference at any stage can explain a difference in the result:

```
INTENT              what the run was asked to accomplish (the outcome contract)
  -> EFFECTIVE CONFIGURATION   what the runtime actually applied, not what was asked for
  -> RESOURCES        model/context/cache/tools actually available to the run
  -> EXECUTION        what the run actually did (tools, subprocesses, API calls, retries)
  -> MEASURED RESULT  mechanically verified outcome + cost dimensions
  -> OPERATOR JUDGMENT  where a human decision or preference applies (never scored as correctness)
```

Where these facts live — the existing derive-first contract is preserved:

- **Desired policy/configuration** → the preference/configuration layer
  (`preferences/defaults.json`, operator tier, project `.spark/preferences.json`).
- **Effective configuration** → derived from the actual execution environment at
  run time, never hand-asserted.
- **Run evidence** → immutable benchmark/telemetry artifacts.

`\.spark/state.json` is **not** a home for any of this. Configuration and run
evidence are separate layers and are excluded from it. That is a statement about
those two layers only — it does not imply everything in state is derivable: state
retains the non-derivable judgments it owns (for example `next_action` and
`blockers`) while mechanically current facts are derived.

## Controllable settings inventory

Each control is classified so that the ones which must never be traded for speed
are visible as such.

| Class | Meaning |
|---|---|
| `PERFORMANCE CONTROL` | Legitimately tunable for cost/latency/quality. |
| `OBSERVABLE ONLY` | Can be read, not set from here. |
| `UX ONLY` | Affects presentation, not cost or correctness. |
| `AUTHORITY / SAFETY` | Governs authority, safety, or evidence. **Never tuned to make a benchmark faster.** |
| `UNAVAILABLE` | No programmatic control surface exists from inside a run. |

| Control | Class | Evidence | Notes |
|---|---|---|---|
| Model / execution class | `OBSERVABLE ONLY` | `OBSERVED` (session-reported identity) | Not settable per-run from inside a session; no API to read it programmatically. Cost/quality comparison across models is `NOT ASSESSED`. |
| Reasoning / thinking effort | `UNAVAILABLE` | `UNKNOWN` | No in-session control surface. |
| Context amount / retrieval strategy | `PERFORMANCE CONTROL` (partial) | `OBSERVED` for repo-side retrieval | Repo-side controllable (what a command reads, how much a suite loads). Session-side context budget is `UNAVAILABLE`. |
| Auto-compaction | `UNAVAILABLE` | `UNKNOWN` | Harness-managed; not settable or observable per run. |
| Presentation / verbosity style | `UX ONLY` | `DECLARED` (output style) | Affects how a response is presented. Not a cost control. |
| Maximum output / token budget | `UNAVAILABLE` | `UNKNOWN` | A distinct control from presentation style, and a genuine `PERFORMANCE CONTROL` wherever it can be set — but no such surface is exposed here. Its token and cost effects are `NOT ASSESSED`. |
| Cache / evidence reuse | `PERFORMANCE CONTROL` | `OBSERVED` | Repo-side: the #722 per-process memo, and #576 evidence reuse. Measurable. Provider-side prompt caching is `UNAVAILABLE`. |
| Retry / escalation policy | `PERFORMANCE CONTROL` | `DECLARED` (#575 routing, #558 budgets) | Governed by existing convergence budgets. |
| Dynamic workflow size | `PERFORMANCE CONTROL` | `DECLARED` | Harness setting; affects agent fan-out cost. |
| Tool / API batching | `PERFORMANCE CONTROL` | `OBSERVED` | Measurable as subprocess and `gh` invocation counts. |
| Verification depth | `PERFORMANCE CONTROL` | `OBSERVED` | `tests/run.sh --only <substring>` vs a full run. The repo's own contract already says: targeted while repairing, full run only at an intentional certification boundary. |
| Parallelism / concurrency | `PERFORMANCE CONTROL` | `OBSERVED` | Suite and subshell concurrency. |
| Permission / Auto Mode behaviour | `AUTHORITY / SAFETY` | `DECLARED` (`permissions.defaultMode`) | Affects operator interruption cost, but is an authority control. Reducing *unnecessary* prompts is legitimate; weakening a boundary to speed a benchmark is not. |
| Secrets access (`op`) | `AUTHORITY / SAFETY` | `OBSERVED` capability only | Presence is not authority. Human-owned. |
| Branch protection / rulesets | `AUTHORITY / SAFETY` | `OBSERVED` | Human-owned; never modified to unblock work. |

## Operator-interruption economics

Human attention is a real resource. Removing an *unnecessary* interruption while
preserving the boundary is a genuine efficiency gain; removing the boundary is
not.

Every metric below is **`NOT ASSESSED`**: no counter for any of them is exposed to
a run. A metric is not "observed" because an instance of it is known — a count
that cannot be mechanically derived is not a measurement.

| Metric | Status | Basis |
|---|---|---|
| `false_positive_blocks` | `NOT ASSESSED` | No counter exists. (A *known example class* is recorded separately below — that is observed evidence of the class, not a measurement of the metric.) |
| `permission_prompts` | `NOT ASSESSED` | No per-run counter is exposed to the session. |
| `operator_interventions` | `NOT ASSESSED` | Not mechanically countable from inside a run. |
| `false_negative_boundary_events` | `NOT ASSESSED` | Would require an independent oracle for "should have blocked". |
| `automatic_actions` | `NOT ASSESSED` | No durable per-run counter. |
| `operator_wait_time` | `NOT ASSESSED` | Requires wall-clock instrumentation the harness does not expose. |
| `successful_work_units_without_interruption` | `NOT ASSESSED` | Depends on the counters above. |

**Observed evidence of one class (not a metric value).** The compound-command
guard refuses legitimate multi-part `gh`/`git` invocations, forcing them to be
split or written to a script — a retry and operator-visible noise while blocking
nothing dangerous. This class is durably owned by **#680**. Recording that the
class exists is `OBSERVED`; the *number* of such blocks in a run remains
`NOT ASSESSED`, and the two must not be conflated.

Nothing in this section may be reported as a measured improvement until a counter
exists.

## Provider abstraction (deliberately minimal for v0.23)

v0.23 does **not** build provider-neutral routing. The smallest vocabulary
sufficient to express a control is recorded, mapped to a concrete control only
where one is currently available:

| Generic control | Current mapping | Status |
|---|---|---|
| `model` | session-reported identity | `OBSERVABLE ONLY` |
| `reasoning_effort` | none | `UNAVAILABLE` |
| `context_strategy` | repo-side read/retrieval choices | partial |
| `context_compaction` | none | `UNAVAILABLE` |
| `output_budget` | none (presentation style is a separate `UX ONLY` control) | `UNAVAILABLE` |
| `retry_escalation` | #558 budgets, #575 routing | available |
| `verification_depth` | `tests/run.sh --only` vs full | available |

Anything requiring cross-provider routing is **out of scope here and not
currently scheduled**. Provider-neutral execution is the closed *Later* horizon
([#700](https://github.com/jwogrady/spark/issues/700)); it is **not** v0.25
scope, which is Versioned Blueprints (#701/#714). This record asserts no release
placement for it and has no authority to assign one.

## Cross-version comparison: why no numbers are presented here

A probe compared released **v0.22.0** with the v0.23 candidate by running both
against one neutral fixture repository. That does remove two defects of the first
bounded attempt: it no longer measures against Spark's own differing plugin tree,
and the verbs no longer short-circuit as they did in an archived tree. Every verb
tried returned the same exit status on both sides.

That is **not sufficient** to publish performance evidence, so the numbers it
produced are deliberately not reproduced here:

- **Identical target and exit status do not establish equivalent outcomes.** No
  outcome contract was defined for these verbs, and no comparable-result evidence
  was gathered — nothing shows the two versions performed the same required work.
  Two runs can both exit `0` having done materially different amounts.
- **The measurements were not durably reproducible.** No committed harness,
  recorded fixture identity, pinned commit per side, or captured effective
  configuration existed, so the figures were not pointable or re-derivable.
- **`triage` is a live path.** Shimming `gh` shows it invokes the CLI seven
  times, while `brief --short` and `governance` invoke it zero times. A path that
  reaches the network has no reproducible wall time.

Applying **one** significance rule consistently to what was collected, the
offline verbs' wall-time ranges overlap, so their latency differences are
`NOT ASSESSED` in both directions. An earlier revision of this record called one
of them a regression while treating the same overlap elsewhere as unassessed;
that inconsistency was wrong and is withdrawn.

**The one rigorous equal-workload comparison available is not cross-version at
all.** It is the per-process memo measured on the *same* binary — memo on versus
`SPARK_NO_MEMO=1` — where the workload is identical by construction and the
output is asserted byte-identical by `tests/test-hot-path-memo.sh`. That
comparison (total process creation 47 → 39, complete tool set 36 → 28, parser
calls 21 → 13, median wall 84 → 68 ms) lives with its negative control in PR
#724.

A defensible v0.22 → v0.23 comparison still needs exactly what #722 asks for:
outcome contracts per workload, a committed harness, pinned versions and fixture
identity, captured effective configuration, and paired runs. Until that exists,
cross-version efficiency is **`NOT ASSESSED`**.

### A located optimization target (no performance claim attached)

Independently of the above, profiling `triage` shows it repeats identical work
inside a single run: `git ls-files` four times, and its repository-identity
resolution three times. That is the same recompute pattern the per-process memo
already removed elsewhere. It is recorded as a target to investigate, not as a
measured saving.

## What this record does not establish

- **No Lord's Prayer fixture exists in this repository.** None was created here;
  if one is wanted it needs defining first. Nothing in this document depends on it.
- Token, cost, model-comparison, and thinking-effort dimensions are
  `NOT ASSESSED` — no instrumentation exposes them to a run, and no estimate is
  substituted.
- The five representative #480 workload classes are unchanged by this record.
- `NOT ASSESSED` is never upgraded to PASS, and nothing here makes #480's
  measurement criterion true.
