# Run-telemetry baseline — v0.23

Development-only provenance. Not shipped with the plugin.

Issue #574 requires that representative workloads record their metrics
**before** optimization, so that later efficiency claims from #558, #575 and
#576 are comparative rather than anecdotal. This is that record. Without it,
"the new routing is cheaper" is a feeling; with it, the assertion has a
`spark telemetry compare` behind it.

## Method

Measured on the `feat/574-run-telemetry` branch against base
`20eabbb14ff883b91a144b25d5a17ce792082387`, using the verb itself:

```
spark telemetry record --run v023-baseline …
spark telemetry show   --run v023-baseline
```

The workload is one targeted verification cycle for a single governed issue —
six focused suites plus a repository-binary `spark doctor` — which is the unit
of work the sprint actually repeats. Wall time is host-dependent (WSL2, warm
filesystem cache) and is a comparison anchor for this machine, not a published
benchmark. Nothing here is a threshold: #574 explicitly refuses to hard-code
today's provider numbers as permanent Spark truth.

## The baseline record

```text
binding
  head sha                 20eabbb14ff883b91a144b25d5a17ce792082387
  attempt                  1
  trigger                  efficiency-sprint

routing
  provider / model         anthropic / claude-opus-5
  effort                   high
  escalation reason        cross-cutting-judgment-governor

economics
  estimated cost USD       NOT ASSESSED
  wall seconds             14

work
  full-suite runs          1
  targeted checks          6
  iterations               1

convergence
  failing before/after     1 / 0
  change                   -1
  repeated, no progress    no

outcome
  verdict                  PASS
  telemetry overhead       48
```

Observability overhead, measured separately with `spark telemetry --timing`:
**48 ms** per `record`+`show` cycle against a 400 ms budget. Against a 14-second
verification cycle that is roughly a third of one percent — which is the claim
#574 makes about observability not becoming a material cost, stated as a number
someone can re-measure and dispute.

## What is NOT ASSESSED here, and why

Token, cache, cost, tool-call and context fields are unrecorded in this
baseline. Spark's CLI is zero-dependency Bash with no provider instrumentation:
it cannot see the billing or cache counters of the agent that invoked it, and a
plausible-looking estimate is worse than an honest blank, because the estimate
is what a later comparison would silently treat as measurement.

Those fields exist for the runner that *does* hold the numbers — a workflow
step or agent harness passes them to `spark telemetry record` as facts it
already knows. Until one does, they report NOT ASSESSED. That is the intended
steady state of an unavailable metric, not a gap to be filled with a guess.

## Using it

```
spark telemetry compare v023-baseline <later-run>
```

Every counter carries a signed delta, so an efficiency change is argued from
two records rather than from recollection. A field that is NOT ASSESSED on
either side yields no delta — an unknown compared against a number is not an
improvement.
