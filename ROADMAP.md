# Roadmap

This roadmap reflects current intent, not a commitment or timeline.
Priorities may shift as the project evolves.

**Current phase: Alpha (v0.x).** The engineering pipeline is proven and
`v0.20.0` is the published baseline; the product itself is now being validated
by real users.
The program, its evidence gates, and the Alpha → Beta → v1.0.0 promotion path
are the [Alpha program](docs/alpha/alpha-program.md) — a stable v1.0.0 is
**not** authorized just because the proving releases shipped.

> **Release-planning reconciliation, 2026-08-26.** Earlier `v0.17.0`–`v0.19.1`
> publications were withdrawn. They did not fail the same way: v0.17 had a
> milestone, a release-readiness gate, a roadmap entry and a plan, and was
> published anyway on a gate closed with unmet criteria; v0.18 and v0.19 had no
> milestone, no gate and no roadmap entry at all. Their GitHub Releases and tags
> were deleted, which returned the published baseline to `v0.16.2` until the
> catch-up tag was cut. **No commit was removed and no pull request was unmerged** — the
> implementation stayed on `master` and was replanned into the milestones below,
> where v0.17 and v0.18 are recorded as `Complete (no release)` and the
> cumulative implementation was published once, as `v0.19.0` (2026-08-26).

Each entry carries one **Status** backed by evidence — `Planned`,
`In progress`, `Merged (awaiting release)`, `Shipped (vX.Y.Z)`,
`Complete (no release)`, `Deferred`, or `Backlog`. The vocabulary and
its evidence rules are defined in
[the release-docs checklist](plugins/spark/docs/reference/release-docs-checklist.md#roadmap-status-vocabulary);
an item becomes `Shipped` only once its release exists. **Planning-wave names
(v0.13/v0.14/v0.15 below) are not the same as published tags** — a wave may ship
under one or more tags; each entry's `Shipped (vX.Y.Z)` names the actual tag.

---

## v0.2 — Plugin + lifecycle

**Status:** Shipped (`v0.2.0`)

Spark becomes a Claude Code plugin organized around the
`Ideate → Plan → Codify → Validate → Ship` lifecycle: plugin packaging,
the five lifecycle skills, the supporting skills, the two-door enforcement
(PreToolUse guard + git hooks), the `spark` CLI, and Diátaxis docs.

- [x] Validate install end-to-end from a *published* marketplace — verified
      2026-07-11 from a clean environment (marketplace add → core + companion
      install → discovery → `spark doctor` → a real skill invocation), and
      repeatable as `tests/e2e-marketplace-install.sh` (#177)

---

## v0.3 — Lifecycle readiness & naming

**Status:** Shipped (`v0.3.0` / `v0.3.1`)

Phase names aligned 1:1 with skills; `plan` records the stack as ADRs;
`codify` gained the readiness preflight; `ideate` surveys prior art; the
subagent crews (docit, knowledge) and the multi-agent review shipped as real
plugin agents; process framing stripped from generated project docs.

---

## v0.4 — Architecture v1.0 & the doctor gate

**Status:** Shipped (`v0.4.0`)

The information architecture was decided and ratified (ADRs 0008–0011:
Operator/Project/Session layers, the three carry motions, the three-tier
preferences source, doctor as the single validation gate) and the conformance
audit passed clean. `spark doctor` grew into the superset gate (`bash -n`,
doc-link scan, enforcement parity) with validation CI as its thin wrapper.
Spark adopted Release Please for its own releases.

---

## v0.5 — Carry-in / carry-forward foundation

**Status:** Shipped (`v0.5.0`)

The north-star motions became mechanical: `preferences/defaults.json` +
three-tier resolution and `spark preferences --apply` (carry-in);
`.spark/state.json`, `spark resume`, and the SessionStart brief
(carry-forward); the portable operator knowledge home; the preferences
on-ramp guide.

---

## v0.6 — The carry-in front door

**Status:** Shipped (`v0.6.0`)

One command arms a repo: `spark setup` composes the git hooks, permission
baseline, and resolved standard with a truthful aggregate summary (ADR-0012).
The same milestone carried the setup reliability hardening, the
solo-developer force-multiplier repositioning of the README, and the
release-record truth pass.

---

## v0.7 — Consolidation

**Status:** Shipped (`v0.7.0`)

The plugin ships only what carries the standard (ADR-0013): one `audit`
skill replaced `review` + `cleanup` and acts directly; `docit` and `connect`
were extracted into the `spark-docs` and `spark-connect` companion plugins
(`shred-env` moved with `connect`); the operator decisions store is deferred
until a reader exists; `agents-md` dropped its pre-plugin relics; the work
state got a defined loop close.

---

## v0.8 — Companion release trains

**Status:** Shipped (`v0.8.0`; companions `v0.2.0`)

Every plugin releases mechanically: Release Please runs in multi-package
mode (ADR-0016), giving each companion its own version, component tag, and
in-plugin changelog while the core keeps the `vX.Y.Z` train — one combined
release PR, one human merge. The same release fixed the `commit-msg` hook
rejecting git-generated merge/revert messages.

---

## v0.9 — Readiness, presets & identity

**Status:** Shipped (`v0.9.0`)

`spark doctor --requirements` gained capability-aware readiness checks (#174);
setup began offering explicit profiles before materializing defaults (#176);
permission baselines became `delivery`/`conservative` presets (#178); and the
supported-environment compatibility matrix and Spark's visual identity shipped.

---

## v0.10 — Truthful record & governance

**Status:** Shipped (`v0.10.0` + `v0.10.1`)

The public record was made to match the shipped product, with lightweight
GitHub-native governance behind it. `v0.10.0` shipped the engineering-
preferences/glossary truth pass (#179), the Release Please boundary and token
governance (#185), and the macOS-portable e2e check (#193). `v0.10.1` completed
the governance backbone: the ADRs audited and ratified against the human-
directed product model — recording the permission tiers, the behavioral-test
gate, and the model itself (#180); the changelog policy reconciled with the
Release Please boundary (#186); every feature given a release decision with a
roadmap-completeness check (#188); GitHub-native issue/metadata governance with
a doctor label-parity check (#192); and a milestone-gate readiness signal that
surfaces approval-readiness while performing no release mechanics (#194).

Deferred: the live GitHub Project board (#223) and wiring the release-pipeline
token (the #185 follow-up).

---

## v0.11 — First-run orientation & project standards

**Status:** Shipped (`v0.11.0`)

A safe, guided first run for both new and existing repositories, with visible,
editable project-local standards. Spark now orients before it acts — classifying
a repo as new, existing, or ambiguous, and recording the decision as a project
fact (#183). The `/spark:onboard` guided flow sequences orient → profile → seed
→ brief (#199), seeding create-only `CONVENTIONS.md` and `ENGINEERING-STANDARDS.md`
(#182) whose machine-backed lines are guarded against drift by a `spark doctor`
boundary check (#200). Every session brief surfaces the classification and the
standards docs (#201), and two tutorials walk the scaffold-new and adopt-existing
journeys (#202). The whole milestone shipped as one release, cut once at
completion — milestone and version in lockstep.

---

## v0.12 — Lifecycle orchestration (research & architecture)

**Status:** Complete (no release) — no version cut; nothing new to run shipped,
so Release Please published no release. The deliverables are the ratified ADRs
and the recorded baseline.

A deliberate, evidence-backed decision rather than a promise to ship a
multi-agent framework. Two ratified ADRs — the Shape / Build / Assure & Deliver
execution topology (ADR-0023) and capability-based model selection (ADR-0024) —
plus a measured single-agent baseline over one fixture per group
(`evaluations/orchestration/`). The [#198 decision gate](docs/research/v0.12-orchestration-recommendation.md)
returned **research/architecture only**: the baseline shows Build benefits least
from multi-agent work, Shape most; the candidate parallel-review slice (#206) is
**backlogged** until it is built behind a flag and measured to beat the baseline.
No new runtime orchestration capability shipped — the architecture is decided,
implementation is gated on evidence.

---

## v0.13 — Token & model efficiency

**Status:** Shipped (`v0.13.0`) — released 2026-07-22.

> Released as **`v0.13.0`**, not `0.12.0`: v0.12 (research & architecture) cut no
> version, so the `0.12.0` tag is intentionally skipped to keep the release
> version aligned with this milestone. The gap is the honest record of a
> milestone that shipped decisions, not a release.

Efficiency as a measured discipline: no optimization without a baseline, and
scripts replace model turns only where the work is mechanical. `spark footprint`
baselines the per-surface context cost (#208); `spark doctor` enforces SKILL.md
size budgets (#209); `spark state` makes the work-state write deterministic
(#210); and `spark footprint --timing` measures hot-path latency against budgets,
with doctor carrying a warn-only advisory (#213). Delivered four of six planned
issues; right-sizing the crew roles to capability tiers (#211) and the
issue-wiring manifest helper (#214) moved to the [v0.15 milestone](#v015--orchestration)
(#284), each gated on evidence.

---

## v0.14 — Repository truth and cleanup

**Status:** Shipped (`v0.13.0`) — rode the same release train, 2026-07-22.

A concentrated truth-and-cleanup pass: two shipped-bug fixes (state escaping
without `jq`, macOS-portable latency timing), the commit-type/changelog
vocabulary collapsed to one enforced table, roadmap and doc-truth corrections,
and internal duplication consolidated behind single authorities (`git_root`,
`check_json`, `STATE_STAGES`, the permission-preset map) — each with a `doctor`
guard so it cannot creep back. Shipped under the `v0.13.0` tag alongside v0.13,
keeping the one-version-behind-milestone-name skew the v0.13 note records.

---

## v0.15 — context efficiency & release hardening

**Status:** Shipped (`v0.15.0`)

The context axis of the v0.13 audit, delivered and then locked in: the skill
descriptions trimmed and heavy bodies moved to `references/` (#293, shipped on
`master`), with before/after routing evidence recorded in the governed
`evaluations/skill-routing/` suite (#313); a total footprint budget ratcheted
from the post-trim baseline so the reduction can't creep back, plus laziness
and traceability guards in doctor (#292/#294/#301); the Evaluation surface
hardened so malformed evidence cannot validate or score (#304/#306); the
release-truth engine — per-component, label-aware release-notes verification
(#291) — and the Platform Compatibility Review completed with capability
discovery fixed for breaking features and an ADR-status advisory (#312/#305);
and the deterministic issue-wiring manifest helper for the plan skill (#214).
The hardening landed via PR #314 (merged); its epic #284 is closed, and it
released as `v0.14.0` (the proving release) and `v0.15.0`.

The **model axis is descoped to backlog with reasons recorded on each issue**:
retuning crew tiers (#211) is blocked on measured quality evidence, the
validate-orchestration experiment (#206) awaits an operator-run measurement
window, and the ADR-0024 capability-selection infrastructure (#288) stays
unbuilt until its recorded trigger fires.

---

## v0.16 — Reconciled delivery architecture

**Status:** Shipped (`v0.16.0`–`v0.16.2`) — released 2026-08-12

The burn-through release: the #336–#361 reconciliation, driven by the zd-dns
v0.1.0 field test, implemented as one coherent architectural change. What the
field proved got enforced mechanically; what it disproved got deleted.

- **Derive-first orientation** (#347): `brief`/`resume` read branch, PR, and
  lifecycle position live from git/GitHub; `.spark/state.json` shrinks to the
  two judgment values no repo can answer (`next_action`, `blockers`). The
  observed stale-brief failure is structurally unreproducible.
- **The dependency-order invariant** (#344, absorbing #337/#338): Plan records
  blocked-by in GitHub; Codify fails closed when a prerequisite is missing
  from the base; resume surfaces ancestry drift.
- **Delivery decided** (ADR-0027; #358/#339/#340): canonical issue PRs to
  trunk, sequential-when-dependent; the temporary integration branch is a
  documented exception/recovery technique, never a develop branch.
- **Plan reasons model → shape → design** (#350, absorbing #345/#346/#348/#349).
- **Commit ownership** (#354/#355, conventions from #353): Codify and Validate
  commit their own work; Ship publishes the existing series.
- **Integration validation consolidated** (#341, absorbing #342/#343/#352):
  one judgment reference — combined-tree identity, finding provenance,
  docs-truth, and the CODE IMPLEMENTED / STATICALLY PROVEN / LIVE PROVEN /
  LIVE UNPROVEN evidence vocabulary taught by `validate`.
- **Milestone as version authority** (#357): the seeded Release Please policy
  becomes `always-bump-patch` + `initial-version`, so a fresh project's first
  release cannot default to 1.0.0 and no commit type mints a milestone
  version; `Release-As` does, deliberately.
- **The third enforcement door** (#359): a shipped GitHub trunk ruleset,
  inspect-and-report in `doctor --requirements`, applying always human.
- **One first-run command** (#360): install → `/spark:onboard` → `/spark:ideate`;
  the `delivery`/`conservative` preset terminology corrected.
- **Governance subtraction** (#361, absorbing #336): the CEF gate machinery,
  taxonomy-mirror guard, prose-parity greps, ADR-banner scan, and the
  constitution-as-instrument removed or archived under the deletion test;
  footprint ratchet demoted to advisory; the agent contract collapsed to one
  canonical `AGENTS.md` body with a `CLAUDE.md` import stub.

---

## v0.17 — Provenance promotion

**Status:** Complete (no release) — outcome complete on `master`; no version
cut, deliberately. `v0.17.0` was published 2026-08-13 and **withdrawn**
2026-08-26. The implementation is first published inside the cumulative
`v0.19.0`.

A Spark-managed spoke stays lean while durable cross-project learning is
deliberately promoted — with GitHub evidence and human judgment — into one
designated memory-hub repository. GitHub milestone #14 is the version
authority; issue #373 is the release gate. Architecture: ADR-0028; plan:
`docs/releases/v0.17-plan.md`.

The reconstructed boundary is wider than the withdrawn tag. #389 proved the
original gate closed while three of its own criteria were unmet, and the work
that satisfies them — the Cosmos durable record (PR #390) and the hub-locator
validation fixes for #385 and #393 (PRs #391, #403, #420) — merged *after*
`v0.17.0` was cut. Those items are part of v0.17's scope, not the next
release's.

No `v0.17.0` will be cut: `master` already carries the cumulative implementation
through the reconstructed v0.19 outcome, so a fresh `v0.17.0` from current `HEAD`
would place v0.18/v0.19 implementation inside a tag named `v0.17.0`. Remaining
gate work is this roadmap pass (#448) and the `Complete (no release)` disposition
record (#451).

- **Architecture** (#374): the memory-hub/spoke model extends ADR-0008
  without a fourth global layer.
- **Hub resolution** (#375): one explicit project fact
  (`project.memory-hub`, the `spark hub` verb) — never guessed, never
  hard-coded.
- **Knowledge promotion** (#376): the `knowledge` skill classifies local
  truth versus durable cross-project learning and promotes only with
  evidence and human authority, through the hub's own rules.
- **Lifecycle + proof** (#377): surface the promotion question at natural
  lifecycle boundaries; prove positive, negative, and Cosmos dogfood cases.
- **Release integrity** (#372): one changelog entry per logical change in the
  v0.17 Release Please output.
- **Release-record truth** (#380): the shipped v0.17 plan names the existing
  milestone instead of a stale creation limitation, guarded by a
  documentation-truth check.

---

## v0.18 — Truthful first run and provisioned governance

**Status:** Complete (no release) — outcome complete on `master`; no version
cut, deliberately. `v0.18.0`–`v0.18.2` were published 2026-08-25/26 and
**withdrawn** 2026-08-26. The implementation is first published inside the
cumulative `v0.19.0`.

A newly armed repository's first run tells the truth about itself, and the
governance Spark declares is actually provisioned on the remote. GitHub
milestone #15 is the version authority; issue #444 is the release gate.

The withdrawn v0.18.x train was three publications of one outcome, so the
reconstruction collapses them into a single milestone. No `v0.18.0` will be cut;
the `Complete (no release)` disposition record is #452.

- **Taxonomy provisioning** (#396): `setup` declared an issue taxonomy it never
  created; `spark labels` reconciles the declaration with the remote.
- **Orientation truth** (#398, #399, #400): `orient` stops reporting
  "existing (high confidence)" for greenfield repos, `brief` stops calling a
  freshly armed repo stale, and the `onboard`/`bootstrap` front doors stop
  both claiming to be the entry point.
- **Enforcement accuracy** (#397): the guard stops blocking legitimate wiki
  pushes with a remedy that could not be followed.
- **Carry-in completeness** (#401): `setup` ships a `.gitattributes`.
- **One authority per doctrine** (#364, #394, #395): duplicated doctrine bodies
  collapse to one authority each, "Status26" is canonicalized, and the scope
  ladder gains its sub-issue rung.

---

## v0.19 — Four-tier artifact separation

**Status:** Shipped (`v0.19.0`) — released 2026-08-26. **The cumulative
catch-up release, and the first core tag after `v0.16.2`.** The earlier
`v0.19.0`/`v0.19.1` were published 2026-08-25/26 and **withdrawn** 2026-08-26;
the tag now published is the reconstructed one, at commit `4823979`.

Spark's artifacts separate into four tiers, the shipped/development boundary is
mechanically held by `doctor`, and the release-record convention tells one
truth. GitHub milestone #16 is the version authority; issue #445 is the release
gate. Architecture: ADR-0029.

ADR-0029 is the architecture and the `doctor` tier-boundary check is its
enforcement, so the two withdrawn publications are one outcome. **No issue was
ever filed for any of this work** — it merged as direct PRs, a departure from
Spark's one-issue-per-branch doctrine that #442 owns as a conformance finding.

`v0.19.0` published, in one tag, the cumulative implemented state on `master`
through the reconstructed v0.17, v0.18, and v0.19 outcomes. Its generated
changelog spans every commit since `v0.16.2`; the release record (#450)
attributes the v0.17 and v0.18 blocks to their own milestones so the tag does not
read as though that work originated here. Version-state reconciliation (#446) was
a true prerequisite of publication, recorded as a native blocked-by edge on gate
#445; both closed before the tag was cut.

- **The separation** (ADR-0029, PR #434) with `doctor` holding the
  shipped/development boundary (PR #428), the dev-side `docs/reference`
  renamed to `docs/ops` (PR #431), shipped surfaces naming behaviours instead
  of this repo's issue numbers (PR #432), and ADR citations that resolve
  (PR #429).
- **Release-record integrity** (PRs #415, #417, #418, #421, #425): plain PR
  titles as the fix for doubled release notes, the record that no merge-commit
  setting can express that fix, and the pre-merge staleness gate for release
  PRs.
- **Footprint governance** (PRs #426, #427): budgets re-based above the v0.18
  measurement, and `footprint --root` documented.

---

## v0.20 — Self-host Spark

**Status:** Shipped — `v0.20.0` was published 2026-08-27 at `fd407c7`. Record:
[`docs/releases/v0.20.md`](docs/releases/v0.20.md).

Spark itself becomes a conforming Spark-managed repository and gains the
deterministic orchestration required to dogfood `zd-dns` safely. GitHub
milestone #17 is the version authority; issue #443 is the release gate. It is
also the first release developed and published normally under the repaired
governance model — every change issue-backed, branched, and merged through its
own pull request.

- **Phase A — Spark conforms to Spark:** the repository conformance audit
  (#442) with its matrix at
  [`docs/governance/self-conformance-audit-v020.md`](docs/governance/self-conformance-audit-v020.md),
  the pre-dogfood IS-state baseline (#441) at
  [`docs/governance/is-state-baseline-pre-v020.md`](docs/governance/is-state-baseline-pre-v020.md),
  truthful release-note severity in the GitHub status (#487), and the shipped
  reference that called `blocked-by` a delivery-order mechanism corrected
  (#447).
- **Phase B — dogfood-capable orchestration:** native GitHub `blocked-by` as
  the one executable dependency authority (#438), deterministic next-work
  selection via `spark next` (#436), and category/approval-aware routing
  (#437).

The slice rests on refusing to collapse two questions that look alike: what
must be **true** before work can start (the native `blocked-by` graph) and
which eligible issue to take **first** (the gate's native sub-issue order).
Milestone prose explains the order; it never defines it.

Phase A gating Phase B **was** a native dependency graph — both #441 and #442
state the prerequisite in their own bodies, so each of #438/#436/#437 carried a
native `blocked-by` edge from both. The rest of the order was preference only;
`blocked-by` stays reserved for true prerequisites.

One conformance defect the audit found is deliberately **not** in this release:
#488 (`spark resume` reports a verified absent PR as unverified) is `P2` and
`backlog`, and fails this milestone's own P0/P1 scope-growth test. Codex host
support (#439 / PR #440) also stayed out — it is `backlog` and unrelated to the
dogfood path.

---

## v0.21 — Governance as schema

**Status:** Blocked — certification was withdrawn after empirical review proved
five gate criteria false; #470, #483, #472 and #473 were reopened, and
release-blocking repairs are in progress. Most implementation is merged to
`master`, but gate #478 remains open and Release Please PR #506 remains
unmerged. Record: [`docs/releases/v0.21.md`](docs/releases/v0.21.md).

One machine-readable governance contract that can be inspected, diffed,
provisioned, validated, and used to compile approved plans into GitHub state —
replacing the mix of prose and individual commands that lets an agent hold the
doctrine correctly and still recreate labels, priorities, and metadata rules
inconsistently. GitHub milestone #18 is the version authority; issue #478 is the
release gate.

This release generalized primitives that already existed rather than building
beside them.

- The versioned canonical schema, resolved through the existing preference tiers
  (#470), and deterministic governance `inspect`/`diff`/`apply`/`validate`
  against it (#471).
- The plan compiler (#472) — `issue-manifest.sh` extended with milestone
  creation, existing-issue update, schema-validated taxonomy, cycle detection,
  diff-against-live, and verify, behind `spark plan`.
- Lifecycle integration into `doctor`, work selection, `brief`/`resume`, and
  new-repo provisioning (#473).
- `docs-impact` as a schema-defined label family with a deterministic evidence
  validator (#483). The intent is that no change can have silent documentation
  impact; #512 shows the validator does not yet hold that line when evidence
  retrieval fails, which is one of the release blockers.

The milestone is also the first held to its own `docs-impact` rule, with #470 as
the sole bootstrap exception. Making that rule satisfiable required correcting
the gate's preferred order so #483 landed before the #471 spine — recorded on
#478, with the native dependency graph and every priority untouched.

v0.21–v0.24 were separated from the v0.20 milestone on 2026-08-26, when it had
accumulated 22 open issues across six unrelated outcomes.

---

## v0.22 — Truth-first onboarding

**Status:** Planned

An existing repository is understood read-only, reconciled through approval, and
only then given a coherent course. Today `onboard` is an *arming* flow, which is
right for a clean repo and wrong for one carrying years of history, stale
branches, contradictory docs, and abandoned release state. GitHub milestone #19
is the version authority; issue #479 is the release gate.

Nothing here is implemented.

- A read-only truth pass before Spark writes anything, then approval-gated
  governance provisioning for existing repositories (#467).
- Audit findings turned into a KEEP / REWRITE-COLLAPSE / DROP-ARCHIVE /
  DECISION-REQUIRED reconciliation slate (#468).
- A coherent course derived from reconciled truth rather than session memory
  (#469).

---

## v0.23 — State and provenance separation

**Status:** Planned

Repository code and docs own current state and durable meaning; Git and GitHub
own change-over-time provenance; Spark detects leakage between them and proves
current-state documentation is truthful before a release goes green. GitHub
milestone #20 is the version authority; issue #480 is the release gate.

Nothing here is implemented.

- The state-versus-provenance ownership contract, refining ADR-0008/ADR-0028
  (#474), then removing duplicated historical chronology from state documents
  (#475).
- `audit` detecting provenance leakage as a first-class finding (#476), and the
  terminology split reserving `provenance` for change history (#477).
- `docs-truth` as a **required** release-readiness check (#484) — structural
  checks composed from what `doctor` already proves, one explicit compatibility
  classification per shipped CLI verb, and a bounded semantic verdict recorded in
  GitHub evidence and bound to the reviewed HEAD.

---

## v0.24 — Thin agent skills

**Status:** Planned

Skills become thin orchestration surfaces over deterministic Spark primitives
instead of carrying duplicated policy and mechanics. Each has a sound reasoning
core that has accumulated mechanically decidable work in its hot path — context
cost paid on every invocation, and a second place for policy to drift. GitHub
milestone #21 is the version authority; issue #481 is the release gate.

Nothing here is implemented, and the whole milestone is `P2`: it matters before
v1 but blocks nothing.

- Thin `plan` to reasoning (#459) and separate `ship` delivery from release
  governance doctrine (#460).
- Simplify `knowledge` orchestration (#461) and tighten `ideate`'s boundaries
  (#463).
- Make `bootstrap` policy-driven instead of hard-coding Bun and uv (#462).

---

## Later — Project inception

Project inception — `/plugin install spark` plus the `bootstrap` skill —
graduates into a guided "scaffold a new project from Spark" flow, distinct
from plain distribution. The per-client environment rungs (infra, runtime,
telemetry) build on it. Bundled MCP servers stay deferred until a proven
lifecycle gap requires one.
