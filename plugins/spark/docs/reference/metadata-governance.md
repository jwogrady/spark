# Issue & metadata governance

Spark plans work with GitHub's native metadata, one canonical location per
fact, and no ceremony. The goal is that a glance at an issue — its type,
milestone, relationships, and status — tells you everything, without the same
fact copied across labels, prose, and a board.

**This page is the readable contract; the machine authority is the governance
model.** Everything below — the label families, which surface is authoritative
for scope, hierarchy, dependency and order, the separations that must not be
collapsed, and the surfaces Spark can provision or assess — is declared as one
versioned artifact you can render with [`spark governance`](cli.md). The two
are deliberately not independent: the schema is what commands and tests read,
this page is why it says what it says. Where they could drift, the schema wins
and `spark doctor` catches it.

## Source-of-truth model

Record each fact once, on the surface that owns it:

| Fact | Canonical GitHub surface |
| --- | --- |
| Work category | One `issue.taxonomy` label (see below) |
| Release target | Milestone |
| Priority, effort, risk, lifecycle status | Project fields (or a priority label until a board exists) |
| Dependencies and hierarchy | Native blocked-by/blocking and parent/sub-issue links |
| Ownership | Assignee |
| Implementation linkage | Linked PR + a closing keyword (`Closes #N`) |
| Product-level release intent | The roadmap, linking to milestones/issues — never duplicating their fields |

If a fact already lives on one surface, do not restate it on another. A label
that repeats a milestone, or a prose "depends on" that a native link already
records, is drift waiting to happen.

## Category taxonomy

Category labels are governed by the `issue.taxonomy` preference
(`preferences/defaults.json`), which owns the category **name set** across the
shipped/operator/project tiers. Each category's **colour, description,
cardinality, and requirement** are owned by the governance model — those values
used to be hard-coded in `bin/spark`, which gave one fact two homes. `spark
doctor` holds the two shipped files in parity, so the question "which
categories exist?" cannot have two answers.

```
feature  bug  documentation  chore  tech-debt  research  infrastructure
```

Every issue carries exactly one category. `spark doctor` mechanically checks
that each issue form in `.github/ISSUE_TEMPLATE/` uses a taxonomy category and
never the deprecated `enhancement` alias, so the forms and the taxonomy cannot
drift; where a repo has no issue forms, doctor says so rather than passing
silently. Theme labels (area, priority `P0`–`P3`) may accompany a category but
never replace it.

Declaring the taxonomy is not the same as provisioning it. Labels live on
GitHub, and `spark setup` is an offline, create-only pass, so
[`spark labels`](cli.md) is the verb that reconciles the two: it reports the
missing categories by default and creates them with `--apply`, create-only,
leaving theme labels untouched. Run it once per repo after setup, or the
taxonomy this document governs will not exist on the remote it governs.

## The `docs-impact` disposition

Every issue declares what documentation its change affects, and Spark verifies
the declaration against what the implementation actually changed —
[`spark docs-impact`](cli.md). The point is not to require a documentation
change; very often none is correct. It is that **silence is never `none`**: an
issue that declares nothing fails, because an undeclared omission is
indistinguishable from a deliberate decision.

`docs-impact:none` is a first-class, respectable answer and is exactly as easy
to declare as any other. A vocabulary where "none" reads as an admission gets
filled in dishonestly.

The agent decides the semantic impact; Spark only checks that the decision was
satisfied. The class vocabulary, the path mapping, and the exclusivity of
`none` are all schema data, so the rule and its enforcement cannot drift.

## The `backlog` disposition label

A feature that is deliberately deferred carries the `backlog` label. It is a
disposition label, not a category — it accompanies the `feature` category, it
does not replace it. The label is the machine-readable record of the backlog
decision: `plan/scripts/roadmap-check.sh` reads it to distinguish a deferred
feature from one with no release decision at all, so a disposition recorded only
in a comment or a linked recommendation stays invisible to the check. Apply the
label and keep the *reason* where it belongs (the roadmap, a recommendation doc,
or the issue body) — the label answers "decided?", the reason answers "why?".

## Which surfaces carry release-decision authority

Exactly two, and both are structured fields a human sets deliberately:

| Surface | Records |
| --- | --- |
| **milestone** | the work is scheduled into a release |
| a **`disposition`** family label | the decision *not* to schedule it yet |

The `disposition` members come from the resolved model, so the set has one
authority and adding a member is schema data rather than a code change.

**A member name may contain spaces.** `not planned` is an ordinary disposition,
and the check carries member names whole — one per line, since a line-oriented
TSV cannot declare a label containing a newline in the first place. A member is
never split on whitespace: a governed value that resolves and can be provisioned
must not then produce a false `DECISION REQUIRED` because of how the set was
serialised on its way to the reader.
`roadmap-check` reads them from the model rather than naming them, and reports
**not assessed** if the family cannot be resolved — a hard-coded fallback would
take over at exactly the moment the real authority was unusable.

### An issue body carries none of it

A sentence is evidence *about* a decision, never the decision. These are all
prose, and none of them records a release disposition:

```text
Backlog: automated recommendation only; pending human approval.
Blocked pending a human decision about the next release.
Depends on: #<n>
```

The model already says this of dependencies — *"a `Blocked by #N` sentence
explains a prerequisite; it never creates one"* — and the same holds for the
release disposition. `roadmap-check` once accepted all three spellings, so an
agent could clear a human-decision gap by writing one sentence into an issue
body: a false green reachable by prose, which is precisely what the authority
boundary exists to prevent.

Recommendation text is still welcome, and the check still reports that it is
there. It simply has no authority on its own, and the report says so rather than
staying silent about a proposal a reader can see.

**Being blocked is not a release decision.** It says work cannot start, not
whether the work happens in this release. A blocked feature with no milestone
and no disposition label still owes a decision.

## The governed label families

The taxonomy is one family among several, and each one is declared in the
schema with its cardinality and whether it is required:

| Family | Cardinality | Members |
| --- | --- | --- |
| `category` | exactly one, required | the `issue.taxonomy` categories |
| `priority` | exactly one where priority is required | `P0`–`P3`, most urgent first |
| `theme` | any, optional | orthogonal routing/safety signals: `decision`, `human-approval` |
| `disposition` | at most one, optional | `backlog` — the release decision, recorded mechanically |
| `role` | at most one, optional | `release-gate` — the structural role an issue plays in its milestone |
| `docs-impact` | at least one, **required** | the declared documentation impact of the change |

**Priority order is data, not spelling.** `P0`–`P3` rank by their declaration
order in the schema, so a project that overrides the family gets the order it
declared rather than one inferred from the label text.

**Adding a governed family is data.** A `family` record and its `member`
records in any tier's artifact is the whole change — generic consumers pick the
family up with no code change.

**Spark mutates only the families it owns.** Authority over labels is granted by
family. A plan that changes governed labels has said nothing about a label no
family claims, and saying nothing is not permission to delete it. An
`update … labels` record therefore declares intent for the families it names:
applying it removes the current members *of those families only*, and every
other label stays.

An issue carrying `feedback`, `bug` and `docs-impact:public`, under a plan that
sets `feature,docs-impact:none,backlog`:

| Label | Family | Result |
| --- | --- | --- |
| `feedback` | none — project-local | preserved |
| `bug` | `category`, declared | replaced by `feature` |
| `docs-impact:public` | `docs-impact`, declared | replaced by `docs-impact:none` |
| — | `disposition`, declared | `backlog` added |

Two consequences are the point of the rule. A project-local label never has to
be adopted into the governance model merely to survive an update — an
ungoverned label in the *artifact* is still refused, because it survives by
Spark not reaching into its family, not by the model widening. And an update
never restates families it is not changing, so a required family that is
already satisfied on the issue is not demanded again; a **create** carries the
whole set, so there the requirement still holds.

`diff` previews the family-scoped mutation and names what it preserves.
`verify` holds the artifact to the governed projection of the live set, so a
correct apply verifies clean without the artifact owning unrelated labels.

Full label-set replacement remains available as the low-level operation —
driving `issue-manifest.sh` directly, where the artifact's CSV *is* the whole
set — and is deliberately not what an ordinary governed update means.

## Milestone rules

- **A milestone represents release scope** — the set of work a release ships.
  A milestone titled `vX.Y …` maps to the release whose version is `X.Y.*`.
- **Issue order within a milestone is delivery priority.** The top issue is
  next.
- **No feature begins without a release decision**, recorded in a governed
  field — a milestone, or a label from the `disposition` family. This is the
  [`plan` release-assignment rule](../../skills/plan/references/release-assignment.md),
  checked by `plan/scripts/roadmap-check.sh`.
- **Spark recommends; the human approves.** Spark never silently assigns a
  milestone, priority, or owner, and never retargets existing work — it
  proposes and reports the gap.

## The release-readiness convention

The scope rules for sub-issues and parents are doctrine, stated once in
[sdlc-doctrine](../explanation/sdlc-doctrine.md): a sub-issue is an issue (its
own branch, its own PR) and a parent is a container (no branch, closes when its
children close). The release-readiness issue below is the canonical instance of
that parent rule, not an exception to it.

A milestone may declare **at most one release-readiness issue**. The convention
is optional — a milestone that does not use it simply has no release gate, and
that is a complete, valid answer rather than a gap. When a milestone does use
it, that issue doubles as the milestone epic:

- **The gate is the issue carrying the `release-gate` role**, and that marker
  is the only thing that makes it the gate. Parenthood does not: the model
  declares hierarchy and delivery order as two separate facts, and a milestone
  may hold ordinary parents that are containers without being the release
  boundary. Nothing infers the gate from a title, an issue number, a position
  in a list, or prose. The binding is itself declared in the model —
  `structure release-gate role:release-gate` — so a project that governs the
  role differently is followed rather than second-guessed.
- The release-readiness issue carries the milestone's issues as **native
  sub-issues**, so scope and progress are visible on the gate itself. That
  means *the* scope, not a sample of it: every open issue in the milestone sits
  somewhere beneath the gate. Ancestry is what counts, so the gate may carry
  the milestone through ordinary parents of its own — an issue two levels down
  is still inside the gate's scope. An open issue in the milestone that the
  gate does not reach is work the delivery order cannot see, and closing the
  gate over it would declare a release across it.
- **Blocked-by links record true prerequisites only** — what must be *true*
  before work can start. They are not a sequencing hint: the Codify preflight
  treats the native graph as the executable prerequisite authority, so an edge
  added merely to express preference becomes a false blocker that fails
  readiness closed.
- **The native graph is the only executable dependency authority.** A
  `Blocked by #N` sentence in an issue body explains a prerequisite; it never
  creates one. Where the two disagree, the preflight reports the body as drift
  to reconcile and proceeds from the native graph — one fact, one surface. When
  the native graph cannot be read at all, readiness is *not assessed*, never
  assumed clear.
- **Delivery order lives in sub-issue order** within the parent (as above: the
  top issue is next), and in the readiness issue's own stated preferred order —
  never in `blocked-by`, and never by distorting `P0`–`P3`.
- The readiness issue **closes last**, when the milestone is complete and the
  release evidence is assembled (see the
  [release-docs checklist](release-docs-checklist.md)).

### What Spark checks about the gate

`spark governance` reports the release gate as its own surface, and every
failure below is mechanical — no decision resolves them, so none is handed to a
human as a choice:

| State | Result |
| --- | --- |
| no issue carries the role | **known**: this milestone has no release gate |
| one does | that issue is the gate |
| more than one does | fails: a milestone has at most one |
| the marked issue is in no milestone | fails: it gates no release |
| the marked issue is itself a sub-issue | fails: a gate is a container, not a child |
| an open issue in the milestone sits outside the gate's hierarchy | fails: the gate does not carry the milestone's scope |
| the gate is closed while the milestone still holds open work | fails: the gate closes last |
| the milestones, their issues, or an issue's labels could not be read | **not assessed** |

`spark next` reads this same projection rather than working the question out
again from its own issue list, so the two verbs cannot hold opposite views of
one repository: a state that fails here refuses selection there, with the same
verdict and the same words.

The question is asked of **every open milestone**, including one that holds no
issues at all, and of that milestone's issues **in every state**. The role is
structural issue metadata, not open-issue metadata: a gate that has closed is
still the gate, and it stays on this surface rather than leaving its milestone
looking like one that never had a gate at all.

**Absence is known, not unknown.** A milestone with no release gate is a
complete answer and reports as such; `spark next` ranks by priority and says
so. *Not assessed* is reserved for a surface Spark tried to read and could
not — collapsing the two would let an unread hierarchy be reported as a
milestone with nothing left to do.

### The milestone gate

A workflow (`.github/workflows/milestone-gate.yml`) turns this convention into a
signal on the Release Please PR. It maps the PR's proposed version `X.Y.*` to
the milestone titled `vX.Y …` and posts a `milestone-gate` commit status:

- **blocked** while the milestone has open issues (it names them) or validation
  is not green;
- **ready** once every mapped issue is closed and validation is green — with a
  summary that says *ready for human approval — merge to release*;
- **neutral** when no milestone maps to the version (release behavior unchanged).

The gate is a **verification surface only**. It never merges the PR, creates a
tag, or publishes a Release — its workflow is granted no write access to
repository contents, so it cannot even in principle. The human merge remains
the release act (ADR-0009); Release Please owns the mechanics. Reopening a
milestone issue withdraws the ready state. The decision logic is offline-tested
via fixtures (`tests/test-milestone-gate.sh`). Its **ready (green)** path needs
validation to actually run on the Release Please PR, which is why release-please
creates that PR under a dedicated token (`RELEASE_PLEASE_TOKEN`, see
release-token-governance.md); the gate re-evaluates when the `validate` workflow
completes so it reads the final result rather than racing it.

## The metadata-completeness audit

`spark governance validate` mechanizes the audit below: it drives the per-issue
invariants from the schema's own cardinality and requirement fields, detects
cycles in the native blocked-by graph, and reports what needs a decision
without ever making it. A required family is demanded of work that has a
release decision; a cardinality violation is reported regardless.

It is a report, not an auto-fix: gaps are handed to the human with the smallest
decision that resolves each.

### Broken state and owed decisions are different results

`validate` separates the two rather than reporting both as failure:

- **mechanically invalid** (exit `1`) — no decision resolves it. A cycle in the
  native blocked-by graph is the case: whichever issue you start, the graph
  forbids it. Anyone may correct it.
- **decision required** (exit `5`) — the gap names a value only a human has the
  authority to choose: which category an issue means, which `docs-impact` class
  applies, whether work is milestoned or backlogged, what belongs in a surface
  the model says only a human provisions.

The distinction is not cosmetic. A gate that reports an owed decision as broken
state leaves an autonomous run exactly one mechanical route to green — write the
decision — and that route gets taken. The same partition drives `spark next`, so
selection and validation cannot disagree about which kind of gap they see.

**A recommendation is not authority.** An agent may propose a value together
with its evidence; the check clears only when the governed field itself carries
the decision. A comment, a report, or a sentence in the issue body is not a
recorded decision, and neither is the run that noticed the gap. Once a human
records it, deterministic checks consume the value normally.

Two states that must not be collapsed, either:

| | |
| --- | --- |
| **unknown / not assessed** | an *evidence* state — the surface could not be read, so nothing is claimed |
| **decision required** | an *authority* state — the evidence is complete and a human must choose |

Missing evidence is not a missing decision, and neither is a licence to supply
one.

Every **active** issue should have:

- [ ] one `issue.taxonomy` category label;
- [ ] a release disposition in a governed field — a milestone, or a
      `disposition` label (features especially, per the `plan` rule);
- [ ] native dependency/sub-issue links where the relationship affects order;
- [ ] an assignee or an explicit unassigned state;
- [ ] a linked PR + closing keyword once implementation starts.

The roadmap side of the audit — a current release named, a next release named,
unshipped sections linking issues or deferring explicitly, every open feature
decided — is mechanized by `plan/scripts/roadmap-check.sh`.

## Not yet standardized

A live GitHub **Project board** (Status/Priority/Target/Size/Risk fields with
add/status/archive automation) is the intended home for the priority/effort/risk
facts above. Until it exists, priority lives on `P0`–`P3` labels and status on
the milestone/issue state. Standing up the board is tracked as a follow-up.
