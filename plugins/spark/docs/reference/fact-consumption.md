# Reference — consuming facts: snapshot first, history on demand

> Reference — information-oriented.

The [fact model](fact-model.md) says what an operative fact is and the
[freshness contract](fact-freshness.md) says when one is stale. This page says
how an agent or operator **consumes** them: the bounded snapshot is read first,
and the history behind a fact is read only for a stated reason. The
machine-readable authority is `preferences/fact-consumption.tsv` (policy
version 1, written against fact-model schema 1); this page renders it and the
behavioral suite `tests/test-fact-consumption.sh` holds the page to the data.

The developer journey this replaces is the one the v0.23 baseline measured: a
repair round that re-fetched the pull-request record, the parent issue, the
authority thread and the milestone although only the HEAD had moved, and
polled the conversation for a verdict it could have read once.

## The three surfaces

| Surface | What it gives | When |
|---|---|---|
| `spark facts --issue <n>` | the complete `{observer, facts}` snapshot for a supported work unit, or a fragment with the reason | first, for any work on the unit |
| `spark facts --issue <n> --delta` | the same compilation, presented against the last observation: facts that moved in full, the rest by key and version | every later round on the same unit |
| `spark facts --issue <n> --explain <key> --because <reason>` | one fact's provenance and the record behind it, fetched now, with the reason recorded | only for a reason below |

`--delta` re-reads every fact from its source on every run; the stored record
under `.spark/facts/<n>.json` is compared, never consulted, so a tampered or
stale record can only ever be reported as a change. Its output is not a
snapshot shape — `{"delta": …}` — and a consumer must not act on it as one
(R22); the full observation it was compared to is in the record it names.

`--explain` refuses a key the run did not emit, a reason outside the
vocabulary, and a reason whose required status the fact does not have. The
record it fetches is the GitHub node the fact's source identity names — the
issue, the comment, the milestone or the repository — and a derived fact has
none: its `inputs` are its record.

## Policy

| Id | Rule |
|---|---|
| `P1` | Current truth for a supported work unit is read from the snapshot first, never from issue bodies, comment threads or review timelines. |
| `P2` | The source behind a fact is read only for a reason in the closed vocabulary, through `--explain`, which records it; a raw read without a reason is the developer journey, counted by its absence from the log. |
| `P3` | Reuse is decided by invalidators, never by age or session: unchanged facts are reported by key and version and not re-sent; a new HEAD moves the HEAD-bound facts and what derives from them, nothing else. |
| `P4` | No source read is suppressed to preserve a metric; every run re-reads every fact, and the stored observation is compared, never consulted. |
| `P5` | UNKNOWN, CONFLICT and missing facts are resolved at the source with the reason recorded, or the work declines; an unsupported work unit is read from history as `unsupported`, not silently. |
| `P6` | Human authority, exact-HEAD evidence and review completeness are unchanged: the snapshot projects authority, and an independent reviewer may read any source it needs, with the reason recorded. |
| `P7` | The benchmark harness holds the policy off for the journey-mode arm and uses `--delta` for the reuse arm; `facts_output_shape`, `facts_changed`, `facts_unchanged`, `facts_drilldowns` and `facts_drilldown_reasons` are what the arms are compared on. |

## Reasons

| Reason | Applies to | When |
|---|---|---|
| `unknown` | an `UNKNOWN` fact | the work needs its value, so the source is read to establish it or to confirm it cannot be |
| `conflict` | a `CONFLICT` fact | the candidates it names must be resolved where they were written; the model never picks one |
| `audit` | any | an audit, an independent review or a release check needs the source record itself |
| `explanation` | any | the reader asked why a fact is what it is; the answer is explanation, never a new fact |
| `missing-fact` | any | the work needs something no fact class carries |
| `invalidation` | any | a source moved and the dependent fact is being re-established |
| `unsupported` | any | the work unit, class or path has no snapshot support yet |

## What is recorded

When a run is observed (`SPARK_RUN_ID`), each drill-down appends
`<reason>\t<key>\t<instant>` to `.spark/telemetry/<run>.drilldowns`, and
`spark telemetry show` derives `facts_drilldowns` and
`facts_drilldown_reasons` from that log — a count across many invocations that
a later one cannot overwrite low. `--delta` records `facts_changed` and
`facts_unchanged`; every run records `facts_output_shape` (`snapshot`,
`fragment`, `delta` or `explain`) and `facts_output_bytes`, the bytes actually
printed.

## Where the policy is applied

The lifecycle skills consume the snapshot at the points where they used to
re-derive truth: `codify` before branching, `validate` at the start of each
review round, `ship` before publishing. Each names this page rather than
restating it.
