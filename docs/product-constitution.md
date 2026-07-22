# The Spark Product Constitution

> **Authoritative — the governing document for what Spark is, owns, and refuses.**
> A dev-doc: it governs how Spark is built and never ships into a user project.
> Derived by extraction from the identity and explanation docs; it introduces no
> new product direction. Subordinate only to the Mission. Amendable **only by a
> new ADR** — not by ad-hoc edit. Owner: `jwogrady`.

The order of authority every decision defers to:

```
Mission → Constitution → Identity → Accepted ADRs → Roadmap → Issues → Implementation
```

A lower layer may refine a higher one; it may never contradict it. Where two
inputs strain, [`identity.md`](../plugins/spark/docs/explanation/identity.md) —
self-labeled *Authoritative* — breaks the tie.

---

## Article I — What Spark exists to do

Spark turns a Claude subscription and a GitHub subscription into a **software
delivery system** for one operator running many projects to a single standard.
Success is *more finished software, not more AI activity*. Its mechanism: **Spark
is the layer between the operator's intent and Claude's tools** — it refuses the
premise that speed and discipline trade off, and answers it with a system that
makes the right thing easy and the wrong thing hard. Spark exists to improve the
engineering discipline of Claude- and GitHub-powered delivery — not merely to
automate GitHub or wrap Claude.

## Article II — What Spark owns

Spark owns three things, realized as concrete surfaces:

1. **The sequence** — the portable lifecycle `Ideate → Plan → Codify → Validate →
   Ship` plus the setup and supporting skills serving it.
2. **The gaps** — project inception, scoped-work decomposition, mechanical
   enforcement, repository onboarding / carry-in (`spark setup`), brief-on-entry
   and resume (session continuity), and the resolved engineering standard.
3. **The standards** — the operator's preferences and engineering policy, loaded
   once and carried everywhere, plus their deterministic enforcement.

**4. Evaluation.** Spark owns the **evaluation framework**: deterministic
evaluation, benchmark conventions, experiment governance, evidence collection,
evidence storage, acceptance criteria, and reporting conventions. **Claude owns
reasoning; Spark owns the evaluation of it.** A claim of quality, savings, or
improvement is a Spark artifact only when Spark's evaluation produced the
evidence beneath it.

Cross-cutting invariants: **one canonical source per class of information**, and
the **Operator / Project / Session** layer separation, with movement between
layers only when explicit.

## Article III — What Spark delegates

- **To Claude:** *how* to use tools; the skill/plugin spec, MCP, and the built-in
  reviewers (`/code-review`, `/security-review`, `verify`).
- **To GitHub:** the durable record — issues, branches, pull requests, releases,
  and project/board tracking.
- **To Git:** commit and history mechanics.
- **To Release Please:** version-bump calculation and the release PR.
- **To the operating system / the project:** the runtime and environment a
  project runs in.

**Constitutional law — Spark owns engineering *policy*, not *mechanisms*.** Spark
decides *what standard applies* (conventional commits, trunk discipline,
review-before-ship, scoped work, acceptance criteria, model-tier and context
budgets). It delegates the *mechanism* to the platform wherever one exists — Git
for history, hooks for enforcement points, Claude for review and reasoning,
Release Please for version math, GitHub for tracking. Spark builds a mechanism
only to fill a gap the platform leaves — and owns the *determinism* of its own
policy even when the underlying calls belong to the platform.

## Article IV — What Spark will always do

1. **Enforce, not advise** (the PreToolUse guard, git hooks, `spark doctor`).
2. **One lifecycle, versioned and portable** — installed once, carried everywhere.
3. **Stay additive** — reference upstream, never reinvent it.
4. **Hold scope** — one problem / feature / issue / branch / PR.
5. **Stay zero-dependency** — POSIX-friendly Bash, graceful degradation without
   `jq` / `python3`.
6. **Keep attribution and hype honest** — author credit is `jwogrady` only, AI
   trailers blocked; **claims travel only as far as their evidence**; new skills
   are issue-first.
7. **Keep one canonical source per class; keep the three layers separate.**
8. **Carry context, never recreate it** — carry-in, carry-through, carry-forward.

## Article V — What Spark will never do

- **Reinvent a native tool** — a club that duplicates one in Claude's, GitHub's,
  or Git's bag is dead weight.
- **Credit an AI** in any authorship or metadata field.
- **Be a runtime or hosting environment**, or own the project's environment.
- **Push to trunk, force-push a shared branch, or hand-cut a release** where
  Release Please owns it.
- **Ship advisory-only rules** for anything it claims to guarantee.
- **Duplicate truth** across two sources, or **silently copy** across layers.
- **Decide for the operator, or fake a tool it doesn't have** — it advises; the
  operator takes the shot.
- **Coordinate teams (v1).** Team coordination and shared cross-operator state
  are **out of scope for v1** — noted as a possible future direction beyond v1,
  so it is neither promised nor silently forgotten.

## Article VI — How future capabilities are evaluated: the Capability Evaluation Framework

Every proposed capability — existing or new — is admitted through the **Capability
Evaluation Framework (CEF)**, Spark's permanent capability entry point. A
capability earns a place only if it passes **all five** questions:

1. **Mission** — does this strengthen Spark's mission (engineering discipline
   around Claude and GitHub)?
2. **User value** — does it produce meaningful value the operator would notice?
3. **Constitutional ownership** — is it inside Spark's owned surfaces
   (Article II) and additive to Claude, GitHub, Git, and the OS (Article III)?
4. **Evidence** — is it supported by evidence the Evaluation surface (Article II.4)
   produced?
5. **Smallest implementation** — what is the least build that satisfies 1–4?
   Extend existing work; never rebuild it.

**The three lenses, and the tie-break.** Questions 1–3 are probed by three lenses
that can disagree:

- **The Mission test** — would we intentionally build this today because it
  materially improves the workflow?
- **The User Value test** — if it disappeared, would the operator notice?
- **The Deletion Test** — can Claude, GitHub, Git, or the OS *technically* replace
  it? If deletion loses no outcome the platform can't provide, it does not belong.

A capability may fail one lens and pass another — deterministic issue wiring
fails the Deletion Test (technically replaceable) yet passes Mission and User
Value. **When the lenses disagree, the governing hierarchy decides: Mission
first.** A Deletion-Test failure alone never disqualifies a capability that the
Mission and User Value tests endorse.

New skills additionally require a GitHub issue and feedback before code.

**Capability Traceability.** Every capability remains traceable end-to-end along
the lifecycle spine:

```
Mission → Capability → Constitution → ADR → Issue → Pull Request → Evaluation → Release
```

The CEF governs *admission*; Evaluation governs *release*; Capability Traceability
connects the two. The `Evaluation → Release` hop is enforced, not documentary: no
release ships a capability whose Q4 evidence is absent.

## Article VII — How Spark evolves with Claude Code and GitHub

Spark **references** upstream, so the host evolving is the signal to update Spark,
not a break. When a native tool comes to duplicate a Spark club, Spark **retires
its club**. The identity is stable across delivery vehicles; the plugin is how
Spark is delivered today, not what it is.

**Platform Compatibility Review — a permanent release gate.** Before **every**
release, Spark re-runs the Deletion Test against the *current* platform surfaces
and confirms: no native tool now duplicates a Spark club; every referenced host
guidance still exists; every enforced mechanism still fires; and every Accepted
ADR whose implementation was gated on an experiment has a status that matches the
experiment's verdict (re-status it, never implement around it). The review's
result is recorded as release-readiness evidence. No release ships without it.

---

## Procedure and evidence live elsewhere (canonical-source principle)

This document defines **invariants**. It does not explain how to run them.

- The **procedure** for applying the CEF — running each lens, the worked
  examples, the extend-don't-rebuild discipline — lives in
  [`governance/capability-evaluation.md`](governance/capability-evaluation.md).
- The **decision** to adopt the CEF as permanent governance is recorded in
  [ADR-0025](adr/0025-capability-evaluation-framework.md).
- The **per-capability answers** are collected by the issue, pull-request, and ADR
  templates — which collect evidence, never redefine policy.

## Material extensions beyond prior doctrine (recorded, not silent)

- *Evaluation* is a first-class owned surface (Article II.4); prior docs treated
  skill testing as a *known gap*.
- *Policy-not-mechanism* (Article III) is a newly explicit law.
- The *Deletion Test*, the *CEF*, and the *Platform Compatibility Review* gate are
  new governance instruments (Articles VI–VII).
- Team coordination is explicitly deferred-with-a-future-note (Article V).

## See also

- [`identity.md`](../plugins/spark/docs/explanation/identity.md) — the authoritative product identity
- [`philosophy.md`](../plugins/spark/docs/explanation/philosophy.md) — the values layer
- [ADR-0019](adr/0019-human-directed-product-model.md) — the four-party human-directed model
