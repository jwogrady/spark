# ADR: Freshness by identity — invalidation and conflict for operative facts

Date: 2026-09-07
Status: Accepted
Owner: jwogrady

## Alignment

- **Identity / prior decisions served:** ADR-0033 (one operative fact model
  with provenance, freshness and certainty as facets of the envelope), ADR-0031
  (the repository owns current state and durable meaning, Git/GitHub own
  provenance, runtime owns observed truth), ADR-0030 (a governance model is
  data, with one machine-readable authority and a page checked against it),
  ADR-0008 (GitHub owns the backlog and execution history).
- **Supersedes / Superseded by:** nothing.
- **Status tracks evidence:** n/a — this ADR records a contract; the compiler
  and snapshot behavior that honor it land under their own issues and are
  measured against the frozen v0.23 baseline before adoption.

## Context

The v0.23 baseline found that most reviewer findings and most repeated reads
were about *whether a fact was still true*: a verdict judged on a HEAD that had
moved, a decision comment edited after it was read, a check re-run at the same
HEAD, a source that answered 403 and a cached value that quietly kept standing
in for it. ADR-0033 gave every fact a source identity, a source version, a list
of invalidator tokens and an explicit status, but stopped short of saying which
change fires which token, what a consumer does when the source cannot be
re-read, and how two disagreeing records resolve. Without that contract a
compiler is free to invent TTLs, keep stale authority because re-fetching is
expensive, or let the model pick the record that "looks newer".

## Decision

**Freshness, invalidation and conflict are one machine-readable contract,
`plugins/spark/preferences/fact-freshness.tsv` (contract version 1, written
against fact-model schema version 1), rendered by
`plugins/spark/docs/reference/fact-freshness.md` and proven by
`tests/test-fact-freshness.sh`.**

- Every fact records the version it observed for each invalidator token (a
  digest of the membership for a token that names a collection) and a complete
  snapshot records its observer, so a consumer decides freshness by
  comparing recorded versions with current ones — from the cached snapshot alone.
- Eleven **event** classes cover the invalidation the release asked for: HEAD
  push, base move, issue or pull-request metadata, comment edit/deletion and
  comment creation as two events with exact fired kinds,
  relationship and milestone changes, check runs, ruleset changes, repository
  and permission changes, schema/compiler version changes, and unreadable
  sources. Each names the invalidator kinds it fires.
- Each fact **class declares the invalidator kinds its facts may carry** — the
  fact model's R7 and R17 as data — and the **class × event matrix is derived**
  from the two, never edited: a fact is stale exactly when an event fires a token
  it carries; a check run at the same HEAD is re-read on observation; a derived
  fact re-derives when any input moves; a schema change or an unreadable source
  makes a fact UNKNOWN.
- **Conflict** outcomes are closed: disagreeing authorities and malformed
  evidence beside valid evidence are CONFLICT with every candidate named;
  agreeing duplicates are ESTABLISHED from the earliest record with every
  duplicate carried as a token; noncanonical spellings are canonicalized; evidence
  for another HEAD or work unit is historical and never competes.
- **Unreadable** sources yield UNKNOWN with the failure named in `detail`; the
  old value never survives as authority. Readability is a property of the
  snapshot: a repository event — including the observing identity's permission
  — re-reads every source-read fact of the set, so a permission loss cannot
  leave a cached fact usable. A schema or compiler version mismatch
  makes every fact UNKNOWN; nothing is migrated in place.
- **Scenarios** are observations against Example 1 of the fact model — current
  node versions, or the observer's re-read permission — and the suite derives the
  fired tokens from the versions the example recorded, then checks the stale set
  against the page and the matrix.

## Rationale

Identity beats age. GitHub exposes a stable identity or version for almost
everything a fact depends on — a commit id, a node's `updated_at`, a comment's
id and `updated_at`, the ruleset set — so a TTL is never the strongest
invalidator available, and the contract forbids it from being the only one.
Putting the matrix in data and deriving it keeps the page from becoming a table
of intentions: the suite recomputes every cell. Making the unreadable and
conflict outcomes closed removes the two places where a model would otherwise
arbitrate: a 403 is UNKNOWN, two disagreeing records are CONFLICT, and a human
or a released contract resolves either.

## Alternatives Considered

- **TTL-based caching with a generous window.** Rejected: age says nothing
  about truth; a verdict is stale one second after a push and current a week
  later if nothing moved.
- **Letting the compiler keep the last good value when a source is unreadable.**
  Rejected: that is stale authoritative reuse, the exact failure the baseline
  recorded; UNKNOWN is honest and derivable.
- **A precedence rule for conflicting records (latest wins).** Rejected: a
  released contract may add one later; the model must not infer it.
- **Folding this contract into the fact model's rules.** Rejected: the model
  says what a fact is; this contract says when it stops being true. They version
  together but read separately.

## Consequences

- The compiler (#733) and the snapshot (#734) have a closed answer for every
  invalidation class and every failed read; nothing is left to judgment.
- Consumers gain a derivable staleness test: tokens and versions in the
  snapshot, no history.
- The suite is a second cross-authority check on the fact model: every example
  fact must carry only the kinds its class declares, and every event that can
  change a class's value must reach it. Writing that check exposed two gaps the
  fact model now closes in R17 and R14: a fact whose value depends on which
  records a node carries lists the node itself (a review its pull request, an
  authority fact the node of its decision records, a head fact its pull request),
  and a record carrying a field twice is malformed before parsing; then two
  more: every fact records the version it observed for each token (R20) and a
  complete snapshot records its observer (R21), so freshness is a comparison the
  consumer can make from the cached snapshot alone. All of them change
  which schema-v1 records are valid; R19 states why that is allowed: a version
  identifies a shipped contract, and v1 has not shipped, so it is corrected in
  place and v0.23 fixes it.
- Until the compiler lands, nothing reads this contract at runtime; the measured
  system stays frozen for the AFTER comparison.

## Files

- `plugins/spark/preferences/fact-freshness.tsv`, `plugins/spark/docs/reference/fact-freshness.md`, `tests/test-fact-freshness.sh`
