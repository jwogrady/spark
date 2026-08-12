# Cosmos dogfood run

> Real proof against the actual `jwogrady/cosmos` repository — not a described
> or invented one — through to the point ADR-0028 requires a human ruling.
> `[observed]` = seen in a live command or a live `gh api` read; `[reasoned]`
> = argued from the mechanism's rules; `[human]` = the ruling this run stops
> for.

## 1. Resolve the destination — `spark hub`

`[observed]` Run live in a scratch spoke (not the Spark repo itself — Spark is
the mechanism's *owner*, not a spoke of Cosmos, per ADR-0028's own framing):

```
$ spark hub
Memory hub (ADR-0028)
  hub     not configured — this project is standalone

$ spark hub --set jwogrady/cosmos
hub: recorded project.memory-hub=jwogrady/cosmos in .spark/preferences.json

$ spark hub
Memory hub (ADR-0028)
  hub     jwogrady/cosmos
  source  project

$ spark doctor | grep 'memory hub'
✓ memory hub: jwogrady/cosmos ('spark hub' names the source tier)
```

Resolution, recording, and doctor's validity check all work end to end
against a real locator — no naming-convention guess, no hard-coded path (the
`jwogrady/cosmos` string exists only in this scratch spoke's own committed
fact, never in Spark's source, per `tests/test-knowledge-promotion.sh`'s
provider-neutrality scan).

## 2. Classify a real candidate

`[observed]` Cosmos already carries a journal entry that is itself part of
this exact story:
`docs/journal/2026-08-12-spark-provenance-promotion.md` (read live via `gh api
repos/jwogrady/cosmos/contents/docs/journal/...`) records the human ruling
that Spark owns the reusable promotion process, and explicitly defers three
questions:

- "Deferred to Spark #375: exact representation of the spoke-to-hub project fact."
- "Deferred to Spark #376: exact knowledge-classification/evidence bundle and promotion contract."
- "Deferred to Spark #377: exact lifecycle handoff points and dogfood proof."

`[reasoned]` Applying the deletion test to *resolving those three deferrals*:
would the shape of the resolution (the fact key, the evidence contract, the
lifecycle trigger points) still be true and useful if this particular
implementation were deleted and rebuilt? **Yes** — the resolution is an
architectural answer to questions Cosmos's own durable record already asked,
not an implementation detail of this PR. **Verdict: promote.**

`[observed]` This is the positive-fixture pattern proven in `PROOF.md`,
applied to a real case instead of a described one.

## 3. Inspect the hub's actual structure before proposing placement

`[observed]` Read live via `gh api repos/jwogrady/cosmos/contents/...`:

- `docs/journal/` — reasoning/evolution, Cosmos's own "journal-like authority"
  (`docs/journal/README.md`: *"Architecture is discovered in conversation...
  this directory preserves the first part"*). Its explicit rule: **entries
  are never edited to reflect later reversals — a later entry supersedes
  them, and the original stays.**
- `docs/DECISIONS.md` — the heavier `D-####` decision register, requiring
  entries to be numbered and cross-linked; reserved for binding architectural
  decisions, not for recording a deferred-question resolution.
- `CONTRIBUTING.md` — a short-lived feature branch, Conventional Commits, one
  concern per PR, human-only attribution; architecture changes additionally
  read `docs/REVIEW.md`.

`[reasoned]` Per hub-promotion.md's routing rule ("route reasoning/evolution
to the hub's journal-like authority; route accepted decisions/specification
only when the hub's own rules and human ruling warrant it") and per Cosmos's
own supersession rule, the correct placement is a **new** journal entry —
never an edit to `2026-08-12-spark-provenance-promotion.md` — that resolves
the three deferred questions and cross-links back to the original.

## 4. The prepared candidate (not written)

The following is the exact content prepared for
`docs/journal/2026-08-12-spark-provenance-promotion-resolved.md` in
`jwogrady/cosmos`, following that repository's own journal template
(`docs/journal/README.md`) — evidence cited, not transcribed:

> ---
>
> # Spark v0.17 resolves the deferred provenance-promotion questions
>
> ## Summary
>
> The prior entry ([spark-provenance-promotion](https://github.com/jwogrady/cosmos/blob/master/docs/journal/2026-08-12-spark-provenance-promotion.md))
> recorded the human ruling that Spark owns the reusable provenance-promotion
> process and deferred three specifics to Spark #375, #376, and #377. Spark
> v0.17 implemented all three; this entry records what was actually decided.
>
> ## Problem
>
> The prior entry could not record the exact fact representation, evidence
> contract, or lifecycle trigger points because they had not been built yet.
> Leaving the deferrals open after implementation would let this journal's own
> record go stale — the failure class Spark issue #380 named and fixed inside
> Spark's own release record.
>
> ## Observations
>
> - `[observed]` Spark #375 (PR #381) shipped one project-tier fact,
>   `project.memory-hub`, resolved through Spark's existing three-tier
>   preference hierarchy and reported by a new `spark hub` verb — configured,
>   explicit `none`, absent, or malformed, with malformed failing truthfully
>   rather than guessing. The locator accepts `owner/repo`, a URL, or an
>   scp-style git address — GitHub-backed today without GitHub-specific
>   transport as the semantic model, resolving this entry's first open
>   question.
> - `[observed]` Spark #376 (PR #383) extended Spark's `knowledge` skill with
>   a hub-promotion lane: the deletion test classifies local versus durable
>   learning, candidates carry source-repo GitHub evidence (cited, not
>   copied), the destination resolves only via `spark hub`, and any write goes
>   through the hub's own inspected structure and rules — never Spark's.
> - `[observed]` Spark #377 (this work) put the classification question at
>   three natural lifecycle boundaries — implementation discovery (`codify`),
>   review findings (`validate`), and issue/milestone completion (`ship`) —
>   each routing a "yes" to `knowledge` rather than duplicating classification
>   logic per boundary, resolving this entry's second open question. A
>   positive and three negative fixtures, evidence-tagged the way this
>   journal tags observations, are recorded in Spark's
>   `evaluations/provenance-promotion/`.
>
> ## Proposals
>
> 1. Treat the three Spark deferrals as resolved by the shipped mechanism
>    rather than reopening them here.
> 2. Record this as a new entry, not an edit to the original — the original's
>    ruling (Spark owns the process) still stands and is not being reversed.
>
> ## Critiques
>
> - The mechanism has not yet dogfooded a **second** real spoke beyond this
>   proof run; one clean pass is evidence the plumbing works, not evidence the
>   classification judgment generalizes across many spokes over time.
> - Lifecycle-boundary placement (codify/validate/ship) is itself a design
>   choice that traded completeness for restraint — a real discovery that
>   surfaces *between* those boundaries has no trigger point yet, by design
>   (the non-goal explicitly rejects per-commit ceremony), which means a slow
>   drip of small durable facts could still go unpromoted until the next
>   boundary.
>
> ## Decisions
>
> - **Accepted:** the three deferred questions are resolved as described
>   above; Spark #375/#376/#377 are the binding record on the Spark side.
> - **Deferred:** whether the classification judgment needs recalibration
>   awaits a second real dogfood case.
>
> ## Open questions
>
> - Whether Spark and Cosmos should record a lightweight signal (an issue
>   label, a check) when a promotion candidate is pending review, so a
>   proposed entry doesn't sit unnoticed. Not specified by either #377 or this
>   entry.
>
> ## Design laws
>
> No new Cosmos design law. This entry closes deferrals the prior entry opened.
>
> ## Evidence
>
> - Spark PR #381 (#375), PR #383 (#376), and this PR (#377).
> - Spark `evaluations/provenance-promotion/PROOF.md` — the fixture proof run.
> - Cosmos journal entry `2026-08-12-spark-provenance-promotion.md` — the
>   entry this one resolves.
>
> ---

## 5. Where this stops

`[human]` Per ADR-0028 ("a candidate that would create or change an
architectural decision stops for the human ruling required by ADR-0019 and by
the destination repository's own governance") and Cosmos's own
`CONTRIBUTING.md` (feature branch, PR, human-only attribution), **this content
is prepared, not filed.** No branch was opened and no PR was created against
`jwogrady/cosmos`. Filing it is the one action this proof deliberately leaves
for John's explicit go-ahead — the same gate the mechanism enforces for every
promotion candidate, demonstrated by actually stopping there rather than
narrating that it would.
