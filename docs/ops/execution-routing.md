# Execution routing — capability, cost and escalation

Development-only prose. Not shipped with the plugin.

An automated loop that sends every task to the strongest model wastes money and
latency; one that always takes the cheapest path risks correctness. Neither is a
policy. `spark route` makes the tradeoff governed data.

## Configuration, not product truth

Model ids, effort levels, availability and prices change underneath a stable
routing semantics. So `plugins/spark/preferences/routing-classes.tsv` says what
a class currently means, and nothing in `bin/spark` names a provider model — a
model id compiled into routing logic becomes product truth the day it ships and
a lie the day that model is retired. A project replaces the policy wholesale
with `.spark/routing-classes.tsv`; the suite proves an override changes the
route without a line of code changing.

## The classes

| Class | Rank | For |
|---|---|---|
| `deterministic` | 0 | Work with a right answer no model improves |
| `routine` | 1 | Scoped classification and review |
| `normal` | 2 | Ordinary coding and reasoning |
| `complex` | 3 | Architecture, hard diagnosis, conflicting evidence |
| `human` | 9 | A decision boundary — routing stops |

Rank 9 is not a strength tier. It is where routing ends.

## Two rules that carry the weight

**The human boundary is not escalatable.** `select` on a human-class task names
no model at all and exits 5; `escalate` refuses both *from* and *to* that class.
A DECISION REQUIRED that could be escalated into an autonomous attempt is not a
boundary — it is a speed bump. Escalation otherwise moves exactly one rank, so a
run cannot leap to the strongest class on its first disappointment, and every
escalation carries a recorded reason. Escalating without a stated cause is just
starting at the top one step later.

**A failed cheap attempt is still spend.** `spark route benchmark` reports cost
per *completed* task and attributes the wasted attempt to the two-stage path:

```
route                             attempts  successes       cost     cost/completed
normal                                   2          2     0.8000             0.4000
routine                                  1          0     0.0500       NOT ASSESSED
routine->normal (two-stage)              1          1     0.4500             0.4500
```

Cheaper per token, dearer per result. Without carrying the failure, "start cheap
and escalate" wins every argument by not counting its losses. A class with
attempts but no successes has no unit cost at all — NOT ASSESSED, not zero.

## Effort is a cache invalidator

Changing effort mid-conversation rebuilds the cached prefix, a cost that never
appears on the line item that motivated the change. So `select --run` refuses to
move a run's effort and points at `--rebuild-cache` for when the rebuild is
worth it. Route between work units by preference. This is the same invalidator
`spark evidence` tracks, so the two surfaces agree about what makes a prefix
stale.

## Where the numbers come from

`route attempt` reads cost and wall time from the run's `spark telemetry`
record; the routing ledger never re-measures. `select` and `escalate` write the
chosen model, effort and reason back into that record, so a route decision and
its resulting cost are read side by side rather than correlated by hand.

## What this does not do

Running an effort sweep across representative workloads requires actually
executing model work, which the CLI does not do. What Spark supplies is the
ledger and the comparison: a host that runs the sweep records attempts and
outcomes, and `benchmark` answers on completed-task economics rather than token
price. Until representative fixtures are recorded that way, the sweep is
unproven — and #585 should not treat routing as exercised merely because the
policy exists.
