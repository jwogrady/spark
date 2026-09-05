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

`\.spark/state.json` is **not** a home for any of this. State stays derived and
current-state-only; configuration and run evidence are separate layers.

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
| Output token / verbosity budget | `UX ONLY` from here | `DECLARED` (output style) | Affects presentation; no measured effect on repo-side cost. Token accounting is `NOT ASSESSED`. |
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

| Metric | Status | Basis |
|---|---|---|
| `false_positive_blocks` | `OBSERVED` (class established, count not mechanically derivable) | The compound-command guard refuses legitimate multi-part `gh`/`git` invocations and forces them to be split or written to a script. Durably owned by **#680**. Each occurrence costs a retry and operator-visible noise while blocking nothing dangerous. |
| `permission_prompts` | `NOT ASSESSED` | No per-run counter is exposed to the session. |
| `operator_interventions` | `NOT ASSESSED` | Not mechanically countable from inside a run. |
| `false_negative_boundary_events` | `NOT ASSESSED` | Would require an independent oracle for "should have blocked". |
| `automatic_actions` | `NOT ASSESSED` | No durable per-run counter. |
| `operator_wait_time` | `NOT ASSESSED` | Requires wall-clock instrumentation the harness does not expose. |
| `successful_work_units_without_interruption` | `NOT ASSESSED` | Depends on the counters above. |

Only the first has established evidence, and it is a *class* with a named owner,
not a measured count. Nothing here may be reported as a measured improvement
until a counter exists.

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
| `output_budget` | output style | `UX ONLY` |
| `retry_escalation` | #558 budgets, #575 routing | available |
| `verification_depth` | `tests/run.sh --only` vs full | available |

Anything requiring cross-provider routing is v0.25+ (#701/#714) or the deferred
provider-neutral horizon (#700) and is explicitly out of scope here.

## What this record does not establish

- **No Lord's Prayer fixture exists in this repository.** None was created here;
  if one is wanted it needs defining first. Nothing in this document depends on it.
- Token, cost, model-comparison, and thinking-effort dimensions are
  `NOT ASSESSED` — no instrumentation exposes them to a run, and no estimate is
  substituted.
- The five representative #480 workload classes are unchanged by this record.
- `NOT ASSESSED` is never upgraded to PASS, and nothing here makes #480's
  measurement criterion true.
