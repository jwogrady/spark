# Roadmap

This roadmap reflects current intent, not a commitment or timeline.
Priorities may shift as the project evolves.

Each entry carries one **Status** backed by evidence — `Planned`,
`In progress`, `Shipped (vX.Y.Z)`, `Deferred`, or `Backlog`. The vocabulary and
its evidence rules are defined in
[the release-docs checklist](plugins/spark/docs/reference/release-docs-checklist.md#roadmap-status-vocabulary);
an item becomes `Shipped` only once its release exists.

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

**Status:** Merged (awaiting release) — all deliverables are on `master`; the
`v0.13.0` release PR is pending a human merge.

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
issue-wiring manifest helper (#214) were **backlogged** — the first needs the
ADR-0024 selection infrastructure, the second a live-repo verification run.

---

## Later — Project inception

Project inception — `/plugin install spark` plus the `bootstrap` skill —
graduates into a guided "scaffold a new project from Spark" flow, distinct
from plain distribution. The per-client environment rungs (infra, runtime,
telemetry) build on it. Bundled MCP servers stay deferred until a proven
lifecycle gap requires one.
