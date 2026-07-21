# ADR: Lifecycle orchestration topology — Shape, Build, Assure & Deliver

Date: 2026-07-21
Status: Accepted (2026-07-21, at the #198 decision gate — the three-group topology is the ratified orchestration model; implementation is deferred, see the v0.12 recommendation)
Owner: jwogrady

> This ADR records an **Accepted** decision (issue #203, the first deliverable of
> the #190 orchestration epic, ratified at the #198 gate on 2026-07-21). The
> three-group topology below is the adopted orchestration model. It is an
> architectural decision only: **no** lifecycle, skills, architecture, or glossary
> orchestration infrastructure has shipped, and runtime implementation stays
> deferred (see the v0.12 recommendation). The companion model-selection ADR (#204)
> builds on the group names and boundaries fixed below.

## Context

The five lifecycle stages (`Ideate → Plan → Codify → Validate → Ship`) are today
each carried by a single skill running in one agent context. #190 asks whether
some stages get better *quality* — not more ceremony — from multi-agent
topologies: parallel evidence gathering, independent review, an explicit
synthesis step. The maintainer review on #190 named two existence proofs already
in the repo and forbade building any routing infrastructure before an ADR is
ratified against the product model. This is that ADR.

**The two precedents (facts, in the repo today):**

- The **knowledge crew** (`plugins/spark/agents/knowledge/`, orchestrated by the
  `knowledge` skill) is three real subagents tiered per role — Intake (`sonnet`),
  Author (`sonnet`), Librarian-Editor (`opus`). They never self-coordinate: the
  skill's main loop does every dispatch, agents communicate only through files
  under `.knowledge-notes/`, and Intake is a **hard barrier** (no specialist
  starts until `00-intake.md` exists). This is the "orchestrate above native
  capability, tier the model per role, cross boundaries through artifacts"
  pattern.
- The **`validate` skill** (`plugins/spark/skills/validate/SKILL.md`) composes
  Claude Code's built-in `/code-review`, `/security-review`, and the `verify`
  skill rather than shipping its own reviewer, then drives the fixes. This is the
  "reuse native review capability, never duplicate it" pattern.

**Contradiction-check against ADR-0019 (the ratified human-directed model).**
ADR-0019 fixes four parties in fixed roles: the human directs (owns intent,
judgment, acceptance, the release decision), Spark orchestrates, Claude supplies
capability, GitHub is the record. Any topology moving a role must supersede
ADR-0019 explicitly, not drift past it. This proposal does **not** move any
role. Every agent it names only **gathers, proposes, implements, or critiques**;
none approves. The reserved-to-human decisions are enumerated as explicit gates
in each group below: product scope and acceptance criteria, priority and target
release assignment (#188), the merge, and the release (#185). Spark hands off to
Release Please for version/changelog/tag/Release exactly as ADR-0006/0009 and
#185 require. This ADR therefore adds an execution topology **beneath** the
ADR-0019 roles and is consistent with it.

## Decision

Organize the five stages into **three execution groups**. Each group names one
**primary (lead) agent role** that owns the group's evidence and its handoff;
parallelism is used only where inputs and outputs are genuinely separable; every
boundary is crossed by a **named artifact**, not by agents talking to each other;
and each group has a **single-agent fallback** that produces the same artifacts
with no subagents. Human decision gates are preserved unchanged.

The lead orchestrates and never sub-delegates the decision — mirroring the
knowledge crew, where the skill loop (not an agent) runs every dispatch and
barrier, and agents exchange only files.

---

### Group 1 — Shape (`Ideate → Plan`)

Establish the right problem, its evidence and constraints, the decisions, the
scoped issues, their acceptance criteria, priority, and target release.

- **Primary role — Shape Lead.** Owns the framed problem and the synthesis.
  Dispatches the helper agents, holds the synthesis barrier, and presents the
  result to the human.
- **Minimum evidence the group must produce:** a written problem statement with
  success criteria and constraints; a prior-art / existing-asset survey with
  sources; any ADRs the approach warrants; a set of GitHub-ready issues each
  carrying acceptance criteria, and a **proposed** priority and target-release
  assignment with its rationale (never applied without the human — #188).
- **Parallel vs sequential.** Parallel genuinely helps here: **evidence**,
  **constraint**, and **critique** agents work over separable inputs (the
  codebase and prior art; the roadmap, milestones, and policy; the adversarial
  read of the draft framing). They do not edit the same artifact, so they cannot
  conflict. The framing and the final issue set are **sequential** — one Lead
  writes them so the problem statement stays coherent.
- **Barriers / handoffs and the crossing artifact.**
  - *Evidence/constraint/critique → Lead:* one **synthesis barrier**. Each helper
    writes its own notes file; the Lead may not synthesize until all have landed
    (the Intake-barrier pattern). Artifact crossing: the **evidence/constraint/
    critique notes**.
  - *Lead → human:* the **problem statement + draft issue set + proposed
    priority/release**. This is a human gate.
  - *Shape → Build:* on human approval, the crossing artifact is the **approved,
    prioritized, release-assigned issue set with acceptance criteria** (created
    on GitHub — the system of record).
- **Human decision points.** The human approves the problem framing, the scope,
  the acceptance criteria, the priority, and the target-release assignment (#188).
  Agents propose all of these with evidence; none is applied on the agent's own
  authority. A roadmap gap is a blocker the Lead reports, not a value it invents.
- **Single-agent fallback.** One agent runs Ideate then Plan sequentially,
  producing the same artifacts (problem statement → issues) without helpers.
  Parallelism is an optimization for breadth and independent critique, never a
  correctness requirement.

### Group 2 — Build (`Codify`)

Implement one approved, scoped issue on a focused branch.

- **Primary role — Implementation agent (one per issue).** Owns the branch and
  the change.
- **Minimum evidence the group must produce:** a focused feature branch scoped to
  exactly one issue's acceptance criteria, the implementation, and **local
  verification evidence** (the `verify` skill actually running tests/the app, not
  just reading the diff).
- **Parallel vs sequential.** Predominantly **sequential** — one implementation
  agent per issue keeps the change coherent and the branch clean. Narrowly-scoped
  helpers are allowed **only when the sub-tasks are genuinely independent** (e.g.
  a self-contained fixture or an isolated module with no shared edits). Two agents
  must never edit overlapping files; when scope isn't cleanly separable, stay
  single-agent. Parallelism *across different issues* is really parallelism across
  separate Build instances, each on its own branch — not multiple agents on one
  branch.
- **Barriers / handoffs and the crossing artifact.** The crossing artifact into
  Build is the single approved issue; the crossing artifact out is the **branch +
  local verification evidence**, handed to Assure & Deliver. Any helper rejoins
  through a merge into the implementation agent's branch, never a direct handoff
  to the next group.
- **Human decision points.** None *within* Build beyond scope discipline: the
  agent implements the already-approved issue and does not widen scope — a new
  problem becomes a new issue (deferred to Shape), never silent scope creep.
- **Single-agent fallback.** This *is* the default: one agent, one issue, one
  branch. Helpers are the exceptional case, not the norm.

### Group 3 — Assure & Deliver (`Validate → Ship`)

Independently verify the result, resolve findings, prepare the handoff, and
preserve the human's merge and release decisions.

- **Primary role — Assure Lead.** Orchestrates the independent reviewers, runs
  the synthesis/fix loop, and prepares the handoff. Does not merge or release.
- **Minimum evidence the group must produce:** the outputs of the independent
  reviews; a triaged findings list (must-fix / should-fix / out-of-scope) with
  every not-fixed finding recorded (a new issue or a note, never silently
  dropped); a re-verified change against the issue's acceptance criteria; an
  **unresolved-risk list**; and a conventional commit + focused PR prepared for
  the human.
- **Parallel vs sequential.** Parallel genuinely helps: **code**, **security**,
  **test**, and **documentation** review run over separable inputs and are
  reused native capabilities, **not** new reviewers — `/code-review`,
  `/security-review`, and the `verify` skill, exactly as the current `validate`
  skill composes them (`/security-review` only when the change touches auth,
  input handling, secrets, or network surface). The **synthesis/fix loop is
  sequential** — one Lead reconciles the findings and applies fixes on the one
  branch so fixes don't collide. Re-verification is sequential and gates the
  handoff.
- **Barriers / handoffs and the crossing artifact.**
  - *Reviewers → Lead:* a **synthesis barrier** — the Lead reconciles duplicate
    and conflicting findings before fixing. Artifact crossing: the **review
    findings**.
  - *Fix loop → re-verify:* the barrier is that acceptance criteria must hold;
    "green" is never reported when it isn't. Artifact crossing: the **verified
    change + unresolved-risk list**.
  - *Assure & Deliver → human → Release Please:* the crossing artifact is the
    **conventional commit + focused PR**. Merge is the human's; the release is
    Release Please's after a human merges its release PR (#185, ADR-0006/0009).
- **Human decision points.** The human owns the **merge** and the **release
  decision**. Agents prepare and recommend with evidence (the risk list, the PR);
  they never merge, cut a tag, create a Release, or mutate Release-Please-managed
  files outside the configured mechanism.
- **Single-agent fallback.** One agent runs the native reviews in sequence, does
  its own triage/fix loop, re-verifies, and prepares the commit/PR — the current
  `validate` → `ship` behavior. Parallel reviewers are a latency/coverage
  optimization, not a correctness requirement.

---

**Cross-cutting rules (all three groups):**

- **Reuse native capability; never duplicate it.** Reviews are the built-in
  `/code-review` / `/security-review` / `verify` — the `validate` precedent. Spark
  orchestrates above them; it does not ship parallel reviewers.
- **Cross boundaries through artifacts, not conversation.** Agents communicate
  through files and GitHub artifacts; the lead (the skill loop) runs every
  dispatch and barrier — the knowledge-crew precedent.
- **No agent approves.** Priority, scope, release assignment (#188), merge, and
  release (#185) are human gates in every group.
- **Two fallback modes are first-class, not degraded paths.**
  - *No-subagent mode:* each group's single lead does the sequential work and
    produces the identical artifacts; subagents only add breadth, independence,
    or latency wins.
  - *Single-model mode:* when only one capability tier is available, every role
    runs on it; per-role model tiering (the #204 concern) is an optimization
    layered on top, never a prerequisite. The topology must function on one model.

*Why this shape.* It maps each group onto the work that actually varies:
Shape benefits from breadth and adversarial critique (parallel helpers, one
synthesis); Build benefits from a single coherent author (sequential, rare
independent helpers); Assure & Deliver benefits from independent perspectives on
a finished artifact (parallel native reviewers, one fix loop). It reuses two
patterns already proven in the repo instead of inventing a new agent platform,
which the #198 gate explicitly warns against. And it keeps every human authority
from ADR-0019 intact as a named gate rather than an implicit assumption.

## Alternatives Considered

- **Keep five independent single-agent stages (status quo).** Rejected as the
  target end-state, kept as the mandated fallback. It leaves the parallelizable
  wins (independent review, breadth in Shape) on the table, but it is exactly the
  no-subagent mode above — so the proposal subsumes it rather than discarding it.
- **A generic multi-agent "agent platform" with dynamic role spawning.**
  Rejected: #198 forbids duplicating native Claude/GitHub capability without a
  validated need and an explicit boundary. Three fixed groups with named roles
  and artifact handoffs are auditable; an open-ended platform is not.
- **Parallel agents within Build (multiple agents on one branch).** Rejected as
  the default: overlapping edits collide and the change loses coherence.
  Permitted only for genuinely independent sub-tasks, each merging back to the one
  implementation branch.
- **Spark-owned reviewers in Assure & Deliver.** Rejected: it duplicates
  `/code-review` / `/security-review`, contradicting ADR-0002 and the `validate`
  precedent. The group composes the built-ins.
- **Hard-coding model names per role now.** Deferred, not decided here: capability
  tiering is #204's subject. This ADR only requires that the topology run on a
  single model when that's all that's available.

## Consequences

- **Commits us to** three named groups with fixed roles, artifact-only handoffs,
  explicit synthesis barriers, and two mandatory fallback modes — a bounded,
  auditable surface rather than a general agent framework.
- **New constraint:** every future orchestration decision (starting with #204's
  model selection) must respect these group boundaries and the human gates, and
  must keep the no-subagent / single-model modes working.
- **Maintenance burden:** each parallel path needs a reconciliation rule
  (duplicate/conflicting findings in Assure; overlapping edits in Build) and a
  barrier that prevents ungrounded synthesis — real design work the
  implementation issues must carry.
- **Becomes easier:** #204 (model-selection policy) and #205 (evaluation
  fixtures) now have concrete group names and boundaries to attach to; #206
  (validate-as-independent-review-roles) is the natural first Assure & Deliver
  slice; and the #198 gate has one reviewable artifact to accept or reject.
- **Nothing ships from this ADR.** Until the maintainer records Accepted, the
  lifecycle/skills/architecture/glossary docs continue to describe the shipped
  single-agent behavior; representing this research as shipped is forbidden (#198,
  #180).

## Open Questions

- **Maximum useful parallelism per group and the exact reconciliation rule** for
  duplicate/conflicting findings (Assure) and independent-helper merges (Build).
  Owner: #204/#205 design.
- **Where the boundary sits between native Claude capability and Spark-owned
  orchestration** for the Shape helpers specifically (evidence/constraint/critique
  have no built-in equivalent the way review does). Owner: jwogrady, at the #198
  gate.
- **Failure/retry behavior** when a helper or reviewer fails mid-group — retry,
  degrade to fallback, or block. Owner: the implementation issues once ratified.

## Related Docs

- [0019-human-directed-product-model.md](0019-human-directed-product-model.md) — the four-party model this topology sits beneath and must not contradict
- [0002-additive-to-anthropic-spec.md](0002-additive-to-anthropic-spec.md) — reuse Claude's native tools rather than reinventing them
- [0006-cosmics-use-release-please.md](0006-cosmics-use-release-please.md) — the release authority Assure & Deliver hands off to
- [../../plugins/spark/skills/validate/SKILL.md](../../plugins/spark/skills/validate/SKILL.md) — the precedent for composing native `/code-review` + `/security-review`
- [../../plugins/spark/skills/knowledge/SKILL.md](../../plugins/spark/skills/knowledge/SKILL.md) — the per-role, artifact-handoff crew precedent
