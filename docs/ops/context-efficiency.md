# Context and tool-use efficiency

Development-only prose. Not shipped with the plugin.

Issue #576 asks that Spark's Claude-facing execution path use the smallest
sufficient evidence set. This records what Spark now enforces, and — just as
importantly — what it deliberately does not claim to enforce, so a later reader
does not mistake a documented intention for a shipped guarantee.

## What Spark owns: capture once, share, invalidate by name

`spark evidence` is the mechanism. The waste it removes is each consumer
performing the same remote read, and the bug it prevents is carrying that read
forward past the moment it stopped being true.

```text
capture once -> project -> many consumers -> invalidate on named inputs
```

**Freshness is decided by stated invalidators**: the commit (`--head`), the
governing contract (`--contract`), the model, the effort class, and the tool
surface (`--tools`). A capture is reusable only while every stated invalidator
is unchanged, and a refusal names the one that moved:

```
STALE — the model changed (claude-opus-5 -> claude-sonnet-5)
```

Naming it matters. "Stale" on its own is not something an operator can act on,
and a reused capture must never be able to make an old verdict valid. An
invalidator the caller does not state cannot invalidate — otherwise every
consumer would have to restate the whole fingerprint to read anything at all.

**Completeness is decided by a declared bound.** `--bound` with `--count` marks
a capture that hit its limit as NOT ASSESSED, at capture time and on every read
thereafter. Partial evidence presented as whole evidence is how a run concludes
something false at a discount.

**Preflight happens before dispatch.** `spark evidence preflight --budget`
estimates a bundle using the same bytes-per-token heuristic as the footprint
gate — two different answers about what a surface costs would make both
useless — and exits non-zero when it is over. Discovering the bundle was too
large *after* paying for generation is the failure it exists to prevent. With
no `--budget` the answer is NOT ASSESSED, never "fits".

The measured claim: two consumers of one fact perform **one** capture, and both
reach the same verdict. The suite pins the call count with a producer stub, so
"collected once" is counted rather than asserted.

## What Spark does not own, and why

Several of #576's acceptance items describe behaviour of the **agent host**,
not of a zero-dependency Bash CLI. Spark cannot execute them, and a plugin that
claimed them would be lying in a way nobody could check:

| Acceptance item | Why it is not Spark's to enforce |
|---|---|
| Prompt-cache prefix ordering and TTL selection | The prompt is assembled by the host; Spark contributes files to it and never issues the API call |
| Deferred tool loading / tool search | The tool surface is the host's, declared per session |
| Provider context editing / compaction | A host-side conversation operation with no CLI seam |
| Batch/asynchronous API economics | Requires issuing provider requests, which Spark does not do |
| Actual cached/uncached token counts | Only the caller sees its own billing counters |

What Spark does supply for all of these is the **measurement and the seam**:
`spark telemetry` records cache read/write tokens, a derived hit ratio,
tool-schema tokens, compaction events and context before/after when the host
passes them, and reports NOT ASSESSED when it does not. `spark budget` consumes
those same facts to decide convergence. So a host that implements the
provider-side controls can prove whether they paid off, using records Spark
already keeps.

**This is why the reviewer/repair loop is not automation-ready on the strength
of this issue alone.** The Spark-side half — shared capture, bounds,
invalidation, preflight, targeted-versus-full check discipline — is in place and
tested. The host-side half is observable but unproven, and #585 should not
enable automatic handoff until representative runs produce those numbers
through the telemetry surface rather than being assumed.

## Not an excuse to see less

Every mechanism here reduces *repetition*, never *evidence*. A smaller answer
that might be wrong is not an optimization:

- a stale capture is refused, not served cheaply;
- a bounded capture reports NOT ASSESSED rather than silently truncating;
- an unbudgeted preflight reports an unknown rather than a pass;
- `--force` exists so a deliberate recapture is a stated act, not a side effect.
