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

## Later — Project inception

Project inception — `/plugin install spark` plus the `bootstrap` skill —
graduates into a guided "scaffold a new project from Spark" flow, distinct
from plain distribution. The per-client environment rungs (infra, runtime,
telemetry) build on it. Bundled MCP servers stay deferred until a proven
lifecycle gap requires one.
