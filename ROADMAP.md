# Roadmap

This roadmap reflects current intent, not a commitment or timeline.
Priorities may shift as the project evolves.

---

## v0.2 — Plugin + lifecycle

**Status:** Shipped (`v0.2.0`)

Spark becomes a Claude Code plugin organized around the
`Ideate → Plan → Codify → Validate → Ship` lifecycle: plugin packaging,
the five lifecycle skills, the supporting skills, the two-door enforcement
(PreToolUse guard + git hooks), the `spark` CLI, and Diátaxis docs.

- [ ] Validate install end-to-end from a *published* marketplace (still open;
      the Git-URL / local-clone path is the verified install)

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

**Status:** In flight (release pending)

One command arms a repo: `spark setup` composes the git hooks, permission
baseline, and resolved standard with a truthful aggregate summary (ADR-0012).
In flight under the same milestone: setup reliability hardening, the
solo-developer force-multiplier repositioning of the README, and this
release-record truth pass.

---

## v0.7 — Consolidation

**Status:** Planned (milestone open)

The plugin ships only what carries the standard (ADR-0013): one `audit`
skill replaces `review` + `cleanup` and acts directly; `docit` and `connect`
are extracted to become separate products (`shred-env` stays); the operator
decisions store is deferred until a reader exists; `agents-md` drops its
pre-plugin relics; the work state gets a defined loop close.

---

## Later — Project inception

Project inception — `/plugin install spark` plus the `bootstrap` skill —
graduates into a guided "scaffold a new project from Spark" flow, distinct
from plain distribution. The per-client Cosmic rungs (infra, runtime,
telemetry) build on it. Bundled MCP servers stay deferred until a proven
lifecycle gap requires one.
