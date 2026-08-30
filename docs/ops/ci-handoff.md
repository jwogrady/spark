# The CI handoff boundary

Development-only prose. Not shipped with the plugin.

Once local certification is finished and the PR is pushed, the only thing still
changing is GitHub. An agent that sits in `gh pr checks` spends wall time and
remote calls to re-learn the same answer, stays occupied with no productive work
left, and keeps the episode open while an operator waits on it.

`spark ci` makes stopping safe, which is the only reason an agent keeps polling
in the first place: it is afraid of losing its place.

```text
local work complete
  -> spark ci handoff --run <id> --pr <n> --head <sha>
  -> STOP
  -> resume on a transition
  -> spark ci resume
```

## What the boundary records

`handoff` stores the PR, the **exact HEAD** the certification covered, the
required check names and their state at that moment. The head is mandatory:
without it a later resume cannot tell whether CI answered about *this* work or
about something pushed since, and a green rollup for a newer commit is not
evidence about the one that was certified.

It also writes `pr`, `head_sha`, `certified_at` and `ci_state` into the run's
`spark telemetry` record, so resuming needs no replay of the episode.

## The three verdicts, and why two of them are restraint

| Verdict | Exit | Meaning |
|---|---|---|
| `READY` | 0 | Every required check passed on the certified head |
| `CHANGES REQUIRED` | 2 | CI failed — the failing set is printed |
| `PENDING` | 4 | CI has not answered yet |
| `NOT ASSESSED` | 1 | The rollup could not be read |

**Pending is not a failure.** A run that reported FAIL because CI had not
answered yet would send someone to debug work that is correct and merely
unfinished elsewhere. It is a distinct state with its own exit code, and it is
explicitly not a reason to poll.

**An unreadable rollup is an unknown, never a pass.** A rollup that cannot be
read would otherwise resolve to "nothing is failing", which is how an unchecked
commit gets merged.

**A failure resumes from the GitHub failing set.** `resume` prints exactly the
checks that failed. Re-running the whole local certification to rediscover what
CI already named is the replay this issue exists to prevent.

**A pass does not re-open local work.** The certification already covered that
commit; repeating it produces the same result at the same cost.

## Polling is counted, not forbidden

`spark ci status` performs one read and compares it against the recorded
snapshot. An unchanged rollup reports `NO TRANSITION` and exits 3 — this read
produced no new information — and the unchanged count is kept.

Each read is also recorded as a remote request in the run's telemetry. That is
deliberate: it makes a polling loop appear as *spend* in the same place a
convergence budget already looks, so `spark budget` can see repeated expensive
reads with no material change and escalate. The waste becomes visible in the
system that is already watching for waste, rather than needing its own alarm.

Counting rather than banning is the honest design. There are legitimate reasons
to read the rollup once more; there are no legitimate reasons to do it forty
times without noticing.
