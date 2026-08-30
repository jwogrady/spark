# audit — the provenance-leakage contract

**One contract, read by every role.** The Evidence Gatherer, the Health
Assessor and the Synthesis Lead all classify against this file and the producer
it describes. None of them derives the rule again: three derivations are three
answers, and the one that reaches the slate is whichever ran last.

The boundary is not this skill's to invent. It is
[ADR-0031](https://github.com/jwogrady/spark/blob/master/docs/adr/0031-state-provenance-ownership.md):

> Repository code and docs own current state and durable meaning. Git and GitHub
> own provenance: how that state changed over time. Runtime owns observed
> operational truth.

## The defect

**Provenance leakage is a second maintained account of how state changed over
time, living on a surface that does not own that account.**

It is not "prose that mentions the past". A current-state document may cite
history. An ADR may explain a rejected alternative. A runbook may explain the
incident that justifies its rule. None of those is leakage, and treating them as
leakage teaches authors to delete the reasoning a reader needs.

The harm is specific: two copies of one account, written on different days,
corrected at different times. Both look right when written. They disagree later,
silently, usually while someone relies on the stale one — which is exactly what
happened when the withdrawal of the `v0.17`–`v0.19.1` line was told in the
roadmap, the changelog and the problem statement at once, and the changelog's
copy went on naming a published baseline two releases after it stopped being
true.

## These are not evidence

A classification built on any of these is wrong even when it guesses right:

- **dates** — a current rule may be dated; a leak may carry none;
- **issue, PR or commit references** — those are citations, which is the
  behaviour the contract *asks* for;
- **document age** — staleness is a different defect, and #476 excludes it;
- **historical nouns** — "withdrawn", "superseded", "previously" describe
  durable rationale as often as chronology;
- **length** — a long rationale is not a leak; a two-line diary is.

Do not build a general prose critic. The question is never "does this sound
historical". It is "does this surface own this account".

## The five classes

| Class | What it is | #468 disposition |
|---|---|---|
| **CURRENT STATE** | What is true now | `KEEP` |
| **DURABLE RATIONALE** | Why the system has its present shape — the constraint that forced it, the alternative rejected and why, the failure mode a rule prevents | `KEEP` |
| **PROVENANCE ONLY** | A second account of change over time, on a surface that does not own it | `REWRITE-COLLAPSE` |
| **GENERATED RELEASE PROJECTION** | Rendered from commits by release tooling, not hand-authored | `KEEP` |
| **INTENTIONALLY RETAINED HISTORICAL EVIDENCE** | Chronology on a surface whose role *is* the account | `KEEP` |
| *(no class)* | Evidence could not be read | *(none — `NOT ASSESSED`)* |

`NOT ASSESSED` carries no disposition. That is core's two-axis rule: evidence is
`known` or `unread`, disposition is a separate column, and proposing one for
something nobody could read is how missing evidence becomes a guessed decision.
**`NOT ASSESSED` is never `PASS` and never `KEEP`.**

## The deterministic half

[`../scripts/provenance-scan.sh`](../scripts/provenance-scan.sh) is the producer.
Read it; do not re-derive it.

```bash
provenance-scan.sh role <path>          # the surface's ownership role
provenance-scan.sh owners [root]        # subjects that have an owning record
provenance-scan.sh scan <path> [root]   # classified TSV rows for one file
```

It mechanizes three clauses, and a finding needs all three:

1. **the surface does not own chronology** — release records and the changelog
   do own it, so history there is evidence, not leakage;
2. **the passage ties together two or more subjects that have owning records** —
   one mention is a status line; a chain across several is an account;
3. **the passage anchors to no provenance** — no owning record, commit, pull
   request, issue or GitHub URL.

Clause 3 is ADR-0031 stated mechanically: *the citation carries the evidence, the
tree carries the conclusion*. A passage pointing at the record that owns the
account is doing what the contract asks. One that re-tells it, while that record
sits right there, is the copy that will drift.

## The judgment half

The producer bounds the search. It does not close the finding.

- A `PROVENANCE-ONLY` row is a **candidate**. Read the passage. Decide what the
  present system still needs from it, and say so in the finding.
- A `NOT-ASSESSED` row is a **question**, never a pass. Report it as unread.
- Anything the producer keeps may still deserve a human eye; it simply is not
  this finding class.

**Where deterministic evidence is insufficient, preserve the uncertainty.** Do
not promote an ambiguous passage to a confident leakage finding to make a report
look decisive.

## The finding

Use the shared vocabulary. Do not invent a parallel schema.

```text
Area:     <path>
Finding:  <bounded passage> is a second account of <subjects>
Class:    provenance leakage
Keep:     the current conclusion and durable rationale the present system needs
Collapse: the chronology already owned elsewhere
Evidence: <the record, commit, PR or release that owns it>
Action:   REWRITE-COLLAPSE
```

`Area` is a path *and* enough location to find the passage. A finding an author
cannot locate is not actionable evidence.

## Authority

**Audit discovers and classifies. It does not gain mutation authority.**

A provenance-leakage finding *recommends* `REWRITE-COLLAPSE`; it never performs
the rewrite. Findings route through the approval-gated reconciliation path, and
the human decides — the same boundary every other audit finding respects.

This is a finding class inside the existing modes, not a third top-level mode.
`assess` reports it under documentation; `purge` carries it in the evidence
table. Nothing here changes what those modes are.

Never rewrite a historical artifact to match current vocabulary. A record edited
to agree with the present has stopped being evidence of anything.
