# How to audit a project — assess or purge

> How-to — task-oriented.

Use this for whole-project quality control: **assess** grades the project's
health with cited evidence; **purge** removes what is proven dead or false.
Both run directly in your session — the skill dispatches its own small crew
and delivers the result; nothing is emitted for manual pasting. For one
diff/branch/PR, use `validate` (or the native `/code-review` +
`/security-review`) instead.

## 1. Invoke the skill

```bash
/spark-audit:audit
```

Say which mode you want — "assess the project's health" or "purge the dead
code / stale branches / doc drift" — and any scope limits (e.g. branches only,
docs only). The skill asks if the intent is ambiguous.

## 2. The crew runs in-session

The skill dispatches at most five roles, coordinating through the gitignored
`.audit-notes/` scratch directory: the **Mapper** intakes the repo first, then
the mode's roles run — **Health** and **Reliability Assessors** (assess) or
the **Evidence Gatherer** (purge) — and the **Synthesis Lead** consolidates.

## 3a. Assess — read the report

The report scores six dimensions 1–10 (documentation, architecture, code
quality, testing/reliability, security/config, product readiness) and lists
critical risks, debt, top actions, and quick wins — every claim backed by
file paths and line numbers.

Act on it: file each critical risk and top action as a GitHub issue, pasting
the evidence in (`.audit-notes/` is never committed, so links into it won't
survive). The notes themselves are disposable process exhaust, regenerated on
the next run.

## 4b. Purge — review the slate and approve

Every purge finding lands in an evidence table —
`Area | Claim | Evidence | Confidence | Action | Risk | Validation` — with
High / Medium / Low confidence, and every candidate is categorized:

- **Safe delete** — generated artifacts, merged branches, docs proven false.
- **Needs review** — old feature code, ambiguous branches, migrations, public APIs.
- **Do not delete** — default/protected/release branches, production config, secrets.

A human approval gate precedes any remote-branch deletion or risky-code
deletion — nothing protected, default, or release-tagged is removed
automatically. After you approve, removals land in small isolated commits so
each is independently revertible, validated (tests/build/`spark doctor`) after
each group. Land the result through the normal lifecycle (`validate`, then
`ship`).

## Provenance leakage — a finding class in both modes

Both modes classify **provenance leakage**: a second maintained account of how
state changed over time, kept on a surface that does not own that account. Two
copies of one history, written on different days, drift — and the stale one is
found by whoever relies on it.

It is deliberately narrow. Prose that merely *mentions* the past is not a
finding: a current-state document may cite history, a decision record may
explain the alternative it rejected, and a runbook may explain the incident that
justifies its rule. Dates, issue references, and old-sounding words are not
evidence of anything, and a release record or a generated changelog is not
leaking when it holds history — that is its job.

A finding names the passage, what the present system still needs from it, what
is already owned elsewhere, and the record that owns it. The proposed action is
**REWRITE-COLLAPSE**: keep the conclusion, cite the evidence, drop the duplicate
account.

**Audit never performs that rewrite.** It classifies and cites; changing the
document stays behind the same human approval gate as every other finding, and a
passage whose evidence could not be read is reported as NOT ASSESSED rather than
passed.

**Done when** — assess: the critical risks are triaged into issues; purge:
every removal is backed by cited evidence, the docs claim no more than the
code proves, and the truth report's validation status is green (or the gaps
carry a manual validation plan).
