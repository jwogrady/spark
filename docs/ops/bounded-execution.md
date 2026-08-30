# Bounded autonomous execution and convergence

Development-only prose. Not shipped with the plugin.

Spark can make the *repository* deterministic and still leave the *run* inside
it unbounded. That was the v0.21/v0.22 dogfooding failure behind #558: long
productive sessions repeatedly invoked expensive certification, rediscovered
known findings instead of carrying a shrinking failing set, and had no boundary
anywhere except the agent's own sense of having done enough.

`spark budget` makes the boundary external and declared. This is the operator's
model of what it enforces and why.

## The contract

```text
declare convergence condition and envelope
  -> establish the failing set once
  -> repair, checking before each expensive act
  -> prove material progress
  -> one intentional final verification
  -> CONVERGED: finish
     STOP: a bound was reached — report the remaining set
     ESCALATE: the same work, the same answer — a human decides
```

A run declares two different things, and conflating them is the mistake the
verb exists to prevent:

- **The convergence condition** — what finishing *means*. Required before any
  spend is authorized, because a budget bounds a run; it does not tell the run
  what it is for.
- **The envelope** — how much this is allowed to cost on the way there.
  Entirely optional. An undeclared bound is not a bound of zero.

## The five answers

`spark budget check` returns one of five, as text *and* as an exit code, so a
loop that reads only the status still terminates:

| Verdict | Exit | Meaning |
|---|---|---|
| `PROCEED` | 0 | Inside the envelope, and something material changed |
| `STOP` | 2 | A hard bound was reached, or a soft one with no movement |
| `ESCALATE` | 3 | The same expensive work, repeated, with no material change |
| `CONVERGED` | 4 | The declared condition is met; the loop is finished |
| error | 1 | Usage — including a run that never declared convergence |

## Hard bounds, soft signals, and the no-progress boundary

**Hard bounds** — repair iterations, full verifications, tool calls, remote API
requests, wall seconds, estimated cost — stop the run outright.

**Soft signals** — currently the targeted-check count — behave differently on
purpose. Targeted checks are the cheap half of verification, and a run that is
still shrinking its failing set is doing exactly what the contract wants.
Stopping it would punish the behaviour we are trying to encourage, so crossing
a soft signal *while converging* continues with a warning.

Movement is measured against the failing set at the **last targeted check**,
not the last time anyone recorded one. Measuring against a stale record lets a
run bank one improvement and then coast on it indefinitely — a runaway wearing
the costume of progress.

**The no-progress boundary** is the one that matters most. Expensive
verification repeated over an unchanged failing set buys the same answer at the
same price. One repeat is allowed (a failing set can be legitimately unchanged
for a turn); beyond `--max-no-progress`, the run escalates.

The important property of that fixture is that it stops **with the resource
budget almost untouched**. Convergence, not spend, is what ends a stalled run.
Unused tokens are not a reason to ask the same question again.

## A budget is never authority

Reaching a boundary stops work. It can never:

- drop a blocker or mark a failing set clean;
- resolve a `DECISION REQUIRED`;
- turn a `STOP` into a `PASS`.

Every stop reports the failing set it is stopping on, and the suite pins that a
stop can never read as success. A budget that could quietly launder a failure
would be a worse defect than the unbounded run it replaced.

New release-critical evidence may deliberately reopen a stopped or converged
run with `spark budget reopen --reason`. The reopen is announced, its reason is
recorded, and it clears the no-progress escalation — but it never clears the
failing set. New evidence admits new work; it does not absolve old findings.

## Per-request caps are not episode budgets

A provider's `max_tokens`, thinking budget, or effort class bounds **one
request**. An autonomous episode is many requests and many tool calls, so a
per-request cap cannot bound it. `spark budget status` prints these apart from
the envelope, under "routing inputs (not budgets)", so the two cannot be read
as the same thing. The suite runs five full verifications under a declared
per-request cap to demonstrate that it never bounded the episode.

## Where the facts come from

The budget stores only the **bounds**. The facts — iterations, tool calls, API
requests, wall seconds, cost — come from the #574 telemetry record for the same
run id, written by whoever did the work. Two files, one run: what happened, and
what was permitted. The budget never re-measures, which is what keeps checking
a boundary cheaper than crossing it.

No numbers here are product truth. Every bound is declared per run, because one
fixed wall-clock or token figure is not a universal definition of "too much".
