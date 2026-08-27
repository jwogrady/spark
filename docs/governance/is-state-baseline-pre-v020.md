# Spark's IS-state, immediately before v0.20

> **The #441 pre-dogfood baseline.** What Spark *is* on the eve of the v0.20
> orchestration changes, recorded so later certification has something truthful
> to compare against. A dev-doc — it governs how Spark is built and never ships.
> Owner: `jwogrady`.
>
> **Audited master:** `c9baaa9091114a6f116b0fc4309d8fa11bbbc5d0`, 2026-08-27.
> **Precedence used:** released/live truth > merged `master` > live GitHub >
> ADRs > prose. Where prose disagreed with a higher authority, the prose was
> corrected — including prose inside the issues that requested this audit.

Every claim below carries an evidence class:

| Class | Meaning |
| --- | --- |
| **current + proved** | true on `master` and demonstrated by a run or a test |
| **current + statically proved** | present in merged code/config; not exercised live in this pass |
| **planned** | an accepted intent with no implementation yet |
| **historical** | true once, retained as record, not a present-tense claim |

## Versions

| Artifact | Version | Class |
| --- | --- | --- |
| Core `spark` | **`v0.19.0`**, published 2026-08-26 at commit `4823979`, GitHub *Latest* | current + proved |
| `spark-audit` | `0.2.2` | current + statically proved |
| `spark-connect` | `0.2.2` | current + statically proved |
| `spark-docs` | `0.3.1` | current + statically proved |

`v0.17.0`, `v0.18.0`–`v0.18.2`, and the earlier `v0.19.0`/`v0.19.1` are
**historical**: published between 2026-08-13 and 2026-08-26, then withdrawn.
`v0.19.0` as published today is the *reconstructed* tag and is not
byte-equivalent to the withdrawn artifact that shared its name — proven by
content fingerprint in
[the #442 conformance audit](self-conformance-audit-v020.md).

## Supported hosts

| Host | Support | Class |
| --- | --- | --- |
| Claude Code (a version with plugin-marketplace support) | Supported. Installs via `/plugin marketplace add jwogrady/spark`; uses skills, `PreToolUse` and `SessionStart` hooks — the standard plugin spec | current + proved |
| Codex | **Not supported.** No Codex manifest exists on `master` | current + proved |

This is the honest state of the host question. PR #440 proposes a Codex
manifest and is **open and conflicted**; its issue #439 is `backlog`. No shipped
surface anywhere in the repository claims Codex support, and none should until
that work merges. Verified by search across `README`, `ROADMAP`, `AGENTS.md`,
`CLAUDE.md`, `CONTRIBUTING.md`, and every plugin surface: zero occurrences.

## Shape of the system

| Fact | Value | Class |
| --- | --- | --- |
| Marketplace | One marketplace, four installable plugins | current + proved |
| Core skills | Nine: `ideate`, `plan`, `codify`, `validate`, `ship`, `onboard`, `bootstrap`, `knowledge`, `agents-md` | current + proved |
| Lifecycle | `Ideate → Plan → Codify → Validate → Ship` | current + proved |
| Enforcement | Three doors: `PreToolUse` guard, local git hooks, GitHub trunk ruleset | current + proved |
| Validation gates | `spark doctor` (static), `tests/run.sh` (behavioural, 40 suites), `bash -n` | current + proved |
| Context footprint | Marketplace ≈143.9 KB against a 146 KB budget | current + proved |

### Responsibility boundaries

- **`codify`** implements one issue on a branch as focused commits. It does not
  review its own output (`validate`) and does not publish (`ship`).
- **`validate`** orchestrates the host's built-in `/code-review` and
  `/security-review` over one branch diff. Whole-project assessment is
  `spark-audit`, not `validate`.
- **`ship`** verifies the commit series, pushes, opens one PR. **`ship` never
  cuts a release** (ADR-0006).
- **`spark-audit`** owns whole-project assessment and evidence-backed cleanup.
  Its assess mode is *not* a read-only surface: it writes `.audit-notes/` into
  the repository and files GitHub issues at its final step.

## Authority model — what owns which fact

| Fact | Canonical surface | Class |
| --- | --- | --- |
| Work category | Exactly one `issue.taxonomy` label | current + proved (31/31 open issues) |
| Priority | Exactly one `P0`–`P3` label | current + proved (31/31 open issues) |
| Release intent | Milestone, or `backlog` with a recorded reason | current + proved |
| Hard prerequisites | Native GitHub `blocked-by` | current + statically proved |
| Delivery order within a milestone | Issue order / milestone prose | current + proved |
| Implementation linkage | Linked PR plus a closing keyword | current + proved |
| Resumable intent | `.spark/state.json` — **intent only, never backlog authority** | current + proved |
| Version authority | The milestone declares it; Release Please mints it | current + proved |
| The release act | **A human merging the Release Please PR** | current + proved |

### Where the authority model is not yet what the docs will eventually say

Three deliberate gaps, each owned. Until these merge, the behaviour described
above is the behaviour that exists — this baseline documents what *is*, not
what #438/#436/#437 will make true:

- **#438** — `codify` currently treats stale dependency *prose* as a canonical
  blocker. Native `blocked-by` is not yet the sole executable authority.
- **#436** — there is no deterministic next-work selector. Choosing the next
  issue is a human/agent judgement over milestone order today.
- **#437** — there is no category/approval-aware routing surface.
- **#447** — one shipped reference still calls `blocked-by` a delivery-order
  mechanism, which contradicts #438's direction. PR #464 corrects it.

## Release mechanism

Release Please maintains a release PR from the Conventional Commits on
`master`. Merging that PR — a human decision — produces the version bump
(`plugin.json` via `extra-files`), the `CHANGELOG.md` entry, the tag, and the
GitHub Release. Only the root package gets a *Latest* Release; companions
publish as prereleases. `CHANGELOG.md` is generated and must never be
hand-edited. **current + proved**, most recently by the `v0.19.0` cut.

Known condition, owned: generated notes still double some entries. The fix is
plain PR titles (#415, #417, #418, #421); no merge-commit setting expresses it.

## Contradictions found, and what happened to each

| Contradiction | Higher authority | Resolution |
| --- | --- | --- |
| ROADMAP header named `v0.16.2` as the shipped baseline | Published release `v0.19.0` | **Corrected** — header now names `v0.19.0` |
| ROADMAP v0.19 entry read *Merged (awaiting release)* | The release exists | **Corrected** — now `Shipped (v0.19.0)`, released 2026-08-26 |
| ROADMAP v0.19 body described publication in the future tense | The tag is cut | **Corrected** to past tense |
| ROADMAP reconciliation note said `v0.16.2` "is again the published baseline" | `v0.19.0` is | **Corrected** — scoped to the window it was true in |
| ROADMAP v0.20 read *Planned* / "Nothing here is implemented" | #442 is closed and merged | **Corrected** — now *In progress*, with #442 marked complete |
| #441's own body cited `CHANGELOG` recording `v0.19.1` | `CHANGELOG` carries one `0.19.0` section | **Stale premise; not preserved.** The issue's precedence rule governs its own text |
| #441's own body cited ROADMAP showing v0.17 *In progress* | ROADMAP says `Complete (no release)` | **Already resolved** before this pass |
| #442's body cited PR #435 as lacking an issue | #435 is closed | **Stale example**, recorded in the #442 audit |
| `.spark/state.json` described the v0.19.0 release as pending | Live GitHub | **Corrected** under #442 via `spark state --set` |

## Surfaces audited

`README.md`, `ROADMAP.md`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`,
`.spark/state.json`; all of `plugins/spark/docs/` plus the three companion doc
sets; repo-root `docs/` (ADRs, architecture, governance, ops, releases, alpha);
and live GitHub — 31 open issues, 2 open PRs, 6 milestones, published releases.

Every `v0.16`–`v0.19` occurrence in shipped code and docs was classified. All
surviving occurrences outside `CHANGELOG.md` and `docs/releases/` are
**historical by construction** — `since v0.16`, `pre-v0.16 schema`, and the
footprint-budget lineage in `bin/spark`. None is a present-tense claim, so none
was rewritten.

## Intentional gaps at this baseline

| Gap | Owner |
| --- | --- |
| `resume` reports a verified absent PR as unverified | **#488** |
| Prose can still act as an executable blocker in `codify` | **#438** |
| No deterministic next-work selector | **#436** |
| No category/approval routing surface | **#437** |
| Shipped reference miscalls `blocked-by` a delivery-order mechanism | **#447** (PR #464) |
| Release-note severity collapses in the GitHub status | **#487** |
| Ruleset required-checks list not enumerated directly | #442 (`NOT ASSESSED`) |
| `docs/releases/` v0.19.0 record not re-read | this baseline (`NOT ASSESSED`) |

No other current-state contradiction is known at
`c9baaa9091114a6f116b0fc4309d8fa11bbbc5d0`.

## See also

- [self-conformance-audit-v020.md](self-conformance-audit-v020.md) — the #442 conformance matrix
- [ADR-0027](../adr/0027-delivery-model.md) — the delivery model
- [ADR-0029](../adr/0029-four-tier-artifact-separation.md) — the four-tier separation
