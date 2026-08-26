# ADR: Capability-to-evidence declaration and the Evaluation → Release gate

Date: 2026-07-22
Status: Accepted (enforcement retired 2026-08-11: the evidence-index remains
the recorded declaration format for evaluation evidence, but the Platform
Compatibility Review that enforced the `Evaluation → Release` seam was removed
by the #361 governance deletion test. Release truth is still gated — the
milestone gate and release-notes verification stay live; capability-evidence
declarations are now judgment applied when an evaluation is actually run.)
Owner: jwogrady

> Records how a capability declares its evaluation evidence and how the Platform
> Compatibility Review enforces the `Evaluation → Release` seam. Builds on the
> Evaluation surface ([ADR-0025](0025-capability-evaluation-framework.md),
> [`../ops/evaluation.md`](../ops/evaluation.md)); does not amend it —
> the linkage and release-enforcement semantics are durable enough for their own
> record.

## Alignment

- **Mission / Constitution / Identity served:** Constitution Article VII (the
  Platform Compatibility Review gate) and Article VI (the `Evaluation → Release`
  hop of Capability Traceability); ADR-0025 (the CEF and the Evaluation surface).
- **Supersedes:** nothing. **Superseded by:** nothing.
- **Status tracks evidence:** n/a — this adopts a governance mechanism, not an
  experiment-gated implementation.

## Context

Capability Traceability ends `… → Evaluation → Release`, and Constitution Article
VII says no release ships a capability whose Q4 evaluation evidence is absent. But
after ADR-0025 the repository had **no machine-readable link** from a capability
to its evidence: the CEF's Q4 answer lived as free text in an issue/PR body, and
the Evaluation surface stored runs under `evaluations/<suite>/runs/<topology>/`
with no back-reference to the capability they measure. A gate cannot enforce a
seam it cannot resolve deterministically.

Two false options had to be rejected. **Blocking every `feat:` in a release
without evidence** is unworkable and dishonest: the surface is nascent (one
research-only suite today), most capabilities have no graded evidence, and many
never need it (a deterministic helper, a docs change). **Inferring which
capabilities need evidence** is not deterministic — "does this need a graded
evaluation?" is a per-capability CEF judgment, not something a script can decide.

The honest, deterministic path is an **explicit declaration**: the CEF's Q4
judgment, recorded in a repository-local artifact the gate can read.

## Decision

**1. A capability declares its evaluation evidence in `evaluations/evidence-index.tsv`.**
Tab-separated; `#` comments and blank lines ignored (the Evaluation-surface TSV
convention):

```
capability_id    requirement    suite    topology
```

- `capability_id` — the originating issue number, or another stable capability id.
- `requirement` — `required` or `not-required`.
- `suite` — the evaluation suite under `evaluations/` (e.g. `orchestration`).
- `topology` — the recorded evidence to validate (the suite's `runs/<topology>/`).

`suite` and `topology` may be empty for a `not-required` row. The three states are
distinct and deliberate:

- an **absent** entry is an *undeclared* capability;
- a **`not-required`** entry is a deliberate CEF determination that graded
  evaluation is unnecessary — not an accidental absence of evidence;
- a **`required`** entry must resolve to valid evidence.

`capability_id` is the stable identity — an issue number, never a commit subject
(prose is not stable). At release time the gate derives one deterministic record
per capability from the release's `feat` commits, keyed by issue reference and
deduplicated. A `feat` with **no** resolvable issue reference has no stable
identity; the gate never invents one from the subject — it reports the capability
as *unresolved-identity*, advisory and non-blocking, alongside the undeclared set.

**2. The Platform Compatibility Review validates declared evidence; it never
interprets it.** For each `required` capability the gate resolves the suite and
topology and invokes that suite's *own* mechanism — `run.sh validate <topology>`
(ADR-0025's `eval.sh`) — and reads only pass/fail. It does **not** score,
recompute, compare, or reinterpret adopt/kill: interpretation belongs to the
evaluation and its human grader, enforcement to the gate. This keeps the gate a
consumer of the Evaluation surface, not a second evaluation framework.

**3. The gate blocks only on declared-but-invalid `required` evidence.** It blocks
when a `required` declaration is incomplete, its suite or topology is missing, or
`validate` fails. A `not-required` entry is reported and never blocks. An
**undeclared** capability is reported honestly and, during initial adoption, does
**not** block — because mandating a declaration for every capability before the
existing backlog is migrated would block all releases. The gate's language says
"declared evaluation evidence," never "all capabilities evaluated."

**4. The gate is the third gate in the existing milestone-gate workflow.** It
follows the established split: a pure, offline, file-driven, exit-coded decision
script (`platform-compat-check.sh`), a CI runner that discovers the Release Please
PR and range and posts an advisory status + one comment
(`platform-compat-runner.sh`), and behavioral tests. No new workflow; no
`contents: write`; the human merge remains the release act (ADR-0006/0009).

*Why record it as an ADR.* The evidence linkage is a durable addition to the
traceability model, and the block/advisory stance is a release-governance
decision future work defers to (including the ratchet below). A new ADR — not an
ADR-0025 amendment — because ADR-0025 adopted the *surface*; this adopts the
*linkage and enforcement*, a separable concern.

## The ratchet (future, not this decision's enforcement)

Enforcement graduates in stages, each a deliberate step, never silent:

1. **Now:** block on declared-but-invalid `required` evidence; advise on
   undeclared.
2. **After migration:** once existing capabilities carry index entries, require
   every release capability to be declared (`required` or `not-required`) — an
   undeclared capability then blocks.

Step 2 is out of scope here and must be adopted explicitly when the migration is
done.

## Alternatives Considered

- **Block every `feat:` lacking evidence.** Rejected: blocks all releases today;
  asserts a property the repository cannot satisfy — the #297 honesty failure.
- **Infer which capabilities need evidence from commit type/labels.** Rejected:
  not deterministic; the need for a graded evaluation is a CEF judgment, not a
  heuristic.
- **Store the link in `run.tsv` or the issue body.** Rejected: `run.tsv` is the
  Evaluation surface's contract (do not overload it); an issue body is not
  repository-local or machine-checkable at release time. A dedicated index is
  both.
- **Amend ADR-0025.** Rejected per the ADR convention: 0025 is an accepted,
  append-only decision about the surface; the linkage/enforcement is a distinct,
  durable decision that earns its own number.

## Consequences

- **Commits us to** maintaining `evidence-index.tsv` as capabilities gain graded
  evidence, and to the gate reading it at release time.
- **New constraint:** a `required` declaration is a promise the gate enforces —
  an incomplete or broken one blocks the release until fixed.
- **Becomes easier:** the `Evaluation → Release` seam is now deterministic and
  auditable; a capability's evidence is one lookup, not a body-text hunt.
- **Maintenance burden:** the index needs curation, and the ratchet's step 2
  needs an explicit follow-up once migration is complete.

## Related Docs

- [../product-constitution.md](../product-constitution.md) — Article VII (the gate) and Article VI (the seam)
- [../ops/evaluation.md](../ops/evaluation.md) — the Evaluation surface and the index format
- [0025-capability-evaluation-framework.md](0025-capability-evaluation-framework.md) — the CEF and the surface this consumes
- [0011-doctor-is-the-validation-gate.md](0011-doctor-is-the-validation-gate.md) and [0018-behavioral-tests-are-the-second-ci-gate.md](0018-behavioral-tests-are-the-second-ci-gate.md) — the two instruments the gate is distinct from
