# Integration validation — proving a combined state

Judgment guidance for the two moments ordinary issue-level validation is not
enough: running the delivery ADR's **exception pattern** (a temporary
integration branch combining several branches), and closing a milestone whose
issues landed separately. Individually valid changes can be jointly wrong —
the highest-value defects in the zd-dns field test existed only where two
changes interacted (deploy-time zone inventory × new secondaries left the
secondaries serving nothing). This is a protocol to apply, not machinery: no
finding database, no gate framework.

## Identify the tree, then prove that tree

- Name the final combined state **by branch and commit** before validating.
- **Evidence from intermediate trees does not transfer.** A review that passed
  on issue A's branch proves A-alone; after A and B combine, re-verify every
  claim the combination could have changed. "Both halves passed" is not
  "the whole passes."
- Compose with the native reviews (`/code-review`, `/security-review`, the
  `verify` skill) on the combined diff — never duplicate them.
- Ask the interaction question explicitly: **what became false when these
  changes started coexisting?** Walk the invariants each change relied on and
  check the other change didn't break them.

## Classify every blocking finding by provenance

Route work by what a finding *is*, not where it surfaced:

| Provenance | Meaning | Route |
|---|---|---|
| **merge-introduced** | the combination itself created it (bad conflict resolution, semantic collision) | fix in the integration; owned by the integrator |
| **inherited** | present in one branch before combining; the integration only made it visible | fix as issue-local work; a confirmed inherited defect does **not** reopen a semantically correct merge |
| **cross-issue interaction** | exists only because both changes coexist | attach to the milestone/integration context, naming the participating issues |
| **independent new problem** | unrelated scope discovered along the way | a new issue — never silently expanded scope |
| **policy/design ambiguity** | the combined state exposes an undecided question | stop mutating; get the explicit decision first |

State the classification and the evidence for it before fixing anything when
ownership is ambiguous. The readiness report names the provenance of every
blocking finding, and the combined state is not ready while a blocking
interaction finding stands.

## Documentation truth

Structural change falsifies prose silently. At integration and at milestone
close, ask: **what existing documentation did this change make false?** Check
the contract docs (`CLAUDE.md`/`AGENTS.md`, `CONVENTIONS.md`,
`ENGINEERING-STANDARDS.md`), README, ROADMAP, and the ADRs whose context the
change touches. The review looks for statements that *became wrong* — it never
demands gratuitous edits. Documentation rendered into runtime artifacts
(templates, generated configs) is operational state: a comment-only edit there
can still change deployed systems, so treat it as a real change. For a
whole-project truth pass, `spark-audit`'s assess mode owns the deep version of
this question.

## Evidence classes

Say what kind of proof each claim carries, in the acceptance report and PR:

- **CODE IMPLEMENTED** — written, compiles/parses; nothing observed yet.
- **STATICALLY PROVEN** — tests, review, or analysis passed against the code.
- **LIVE PROVEN** — the behavior was observed running, in the combined state.
- **LIVE UNPROVEN** — claimed for live behavior but not yet observed there.

A claim about live behavior requires live observation; intermediate-tree
observations downgrade to LIVE UNPROVEN after the combination. This is
vocabulary for honest reporting — nothing enforces it.
