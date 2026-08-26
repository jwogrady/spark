# ADR: Every artifact belongs to one of four tiers

Date: 2026-08-26
Status: Accepted
Owner: jwogrady

## Alignment

- **Identity / prior decisions served:** ADR-0008 (three information layers, one canonical source per class), ADR-0001 (a plugin, not a framework — what ships is the product), ADR-0014 (core plus companion plugins).
- **Supersedes / Superseded by:** nothing. This is orthogonal to ADR-0008: those layers govern *whose* knowledge an artifact is (operator / project / session); these tiers govern *whether it ships*.
- **Status tracks evidence:** Accepted on implementation. The structural half has held since the repo was laid out; the enforcement half ships in `spark doctor` and is covered by `tests/test-doctor-tier-boundary.sh`.

## Context

Spark is a plugin marketplace whose repository contains far more than the plugin. Alongside the shipped code and its user documentation sit ADRs, release records, governance notes, research, and repo-operations references — none of which belong to anyone who installs the plugin.

That separation existed, but only as a fact of the directory layout and one line in the repo map. Two problems followed.

**It held in one direction only.** Repo-root `docs/` sits outside `plugins/`, so development prose physically cannot ship. Nothing held the reverse: a decision record filed under `plugins/spark/docs/` would ship silently, handing an installer this repository's internal history. No check would notice, and the mistake is easy — during the v0.18 cycle an incident record was nearly filed into the shipped tree, and two directories named `reference/` (one shipped, one not) actively invited it.

**Provenance leaked across the boundary.** An audit of the shipped surfaces found 18 bare `#NNN` issue citations and 60 `ADR-NNNN` references. Both resolve only against this repository. A reader who installed the plugin met "adopt create-only (ADR-0022)" and "(#241)" with nothing to follow — provenance cited into a consumer artifact, which is the same class of defect as documentation that does not match its code.

The two cases are not equivalent, and treating them identically would have been wrong. An ADR reference reads as shared vocabulary and names a durable decision; a bare issue number names a moment in this tracker and nothing else.

## Decision

**Every artifact belongs to exactly one of four tiers:**

| Tier | Home | Ships |
|---|---|---|
| Code | `plugins/*/` — `bin`, `hooks`, `scripts`, `settings`, `skills` | yes |
| Shipped documentation | `plugins/*/docs/` (Diátaxis) | yes |
| Prose and provenance | repo-root `docs/` — `adr/`, `ops/`, `architecture/`, `releases/`, `governance/`, `research/`, `alpha/` | **no** |
| Project management | GitHub issues, milestones, PRs, labels; `.spark/state.json` | n/a |

**The boundary is held in both directions.** Structurally outward: repo-root `docs/` is outside `plugins/` and cannot ship. Mechanically inward: `spark doctor` **errors** when a development-only kind (`adr`, `releases`, `governance`, `research`, `alpha`) appears anywhere under `plugins/`.

**Citations are weighed by what they resolve to.** Doctor **warns** on bare `#NNN` in shipped markdown, because it resolves to this tracker alone. It does **not** flag `ADR-NNNN`: those are vocabulary with a documented home, and the shipped glossary now states where ADRs live and that a citation is provenance, not a prerequisite.

**Where the tiers must touch, they touch explicitly.** A shipped document that needs to point at a development-only one uses a full GitHub URL labelled developer-only. A repo-relative path would resolve in this checkout and break for every installer — the failure the label exists to prevent.

Scope: the check reads markdown under `docs/` and `skills/`. Issue citations in shipped *shell scripts* are deliberately untouched; a script comment addresses the maintainer reading the code, not the operator reading the documentation.

## Alternatives rejected

- **Ship an ADR index so every reference resolves.** Rejected: it puts 29 entries of internal history into a consumer artifact and creates a mirror that must stay in sync with `docs/adr/` — the kind of duplication the governance deletion test removed and the one-body rule exists to prevent.
- **Strip every ADR citation from shipped surfaces.** Rejected: a 60-site edit that discards provenance which is load-bearing in places, to solve a problem one glossary entry solves.
- **Suppress the issue-reference warning with an allowlist.** Rejected for the same reason as an index: an allowlist is a mirror of the files it exempts, and it would have to be maintained by the people most likely to forget.
- **Leave the boundary conventional.** Rejected: the structural half already prevented the worst case, but the direction that actually bites — dev material filed into the shipped tree — had no guard at all, and the near-miss during v0.18 showed convention was not enough.
- **Rename the shipped `reference/` instead of the development one.** Rejected: it would break relative links from skills and any external reference to the published docs, for no gain over renaming the four development files, which share no filename with the eleven shipped ones.

## Consequences

The rule is now stated where agents read rules (`AGENTS.md` carries the tier table), enforced where mistakes are made (`spark doctor`), and covered by tests that prove both findings and their difference in weight.

Two follow-through costs were paid rather than deferred: the development-side `docs/reference/` became `docs/ops/`, killing the name collision, and all 18 issue citations were replaced by the behaviour they stood in for — which reads better than a number regardless of who is reading. `spark doctor` reports zero errors and zero warnings.

The check is Spark-repo-scoped, like the other marketplace-layout checks. A downstream project gets the enforcement only if it adopts the same tier layout; nothing here imposes it on a generated project.
