# Canonical governance and documentation truth — the audit and its register (v0.23 cleanup, #741)

**Scope.** Every documentation surface of the repository — 170 files: the root contract and roadmap, the
`.github` templates (the Markdown pull-request template and the YAML issue forms, governance prose in
either syntax),
the repo-root developer docs (ADRs, ops, releases, governance, research, alpha), the shipped plugin
docs and every skill's SKILL.md and references — classified by exactly one primary role in `docs/ops/doc-roles.tsv`, and the seven governed concepts
the issue named (plus two the audit found contested) mapped to one operative source each in
`docs/ops/canonical-truth.tsv`. `tests/test-doc-roles.sh` holds both files to the tree: every surface
registered once, every role in the closed vocabulary, every locator resolving, every projection registered
as such, no surface left in a finding state.

**Method.** The evidence sweep ran over `origin/master` at `19e20b5e6ae7834baacf7cef2cb7eda7e570dd08`
(after #731 landed, before #732) with `git grep` over several patterns per concept, reading the
surrounding lines to classify each hit as an operative definition, a projection, an explanation or a
historical record. The register was then built from directory defaults (ADRs, releases and research are
historical evidence; shipped reference pages are projections; the rest is explanation) with per-file
overrides where a page is the one definition of something or was found stale; every surface a map row
names carries that concept in the register (derived from the map when the register is built, and the suite
enforces it). Of the counts below, the role counts and the after-counts are computed from the two data
files when this page is built and re-checked by the suite; the before-counts are the sweep's, recorded here
and checked as numbers.

## Roles

| Role | Surfaces |
|---|---|
| `operative-authority` | 30 |
| `current-projection` | 18 |
| `explanation` | 59 |
| `historical-evidence` | 63 |
| `superseded` | 0 |

Nothing is left as `duplicate` or `false-stale`: the six findings of those kinds were treated and the
surfaces re-registered under their steady-state role (below).

## Operative definitions per concept, before and after

"Before" counts the surfaces the evidence sweep read as current operative definitions of the concept
(prose only — not explanation, not history, and CI code excluded); the two concepts the audit added are
counted the same way from the same sweep. "After" counts the operative sources the map names; where a
concept names two, the map's treatment declares the composite (which aspect each source owns); `non-prose`
marks an executable CI surface, the shipped runtime that derives an instance at read time, or GitHub state
(a decision record, the milestone list) that the map cites as a source without a repository page defining it. `tests/test-doc-roles.sh` recomputes the role counts and the after-column from
the two data files and fails if this page disagrees; the before-counts are the sweep's, recorded here, and
the suite checks each is a number.

| Concept | Before | After |
|---|---|---|
| `release-gate-placement` | 8 | 3 + 2 non-prose |
| `version-minting` | 4 | 1 + 1 non-prose |
| `authority-boundaries` | 9 | 2 |
| `routine-merge-authority` | 9 | 1 + 1 non-prose |
| `exact-head-stale-evidence` | 7 | 2 |
| `verdict-vocabulary` | 6 | 1 |
| `parent-dependency` | 7 | 2 |
| `review-lifecycle` | 6 | 1 + 1 non-prose |
| `merge-method` | 3 | 1 + 1 non-prose |

## Contradictions found, and what was done

| # | Surfaces | Contradiction | Treatment |
|---|---|---|---|
| 1 | `AGENTS.md` vs `plugins/spark/docs/explanation/release-ownership.md` | the contract said "the milestone declares the version; Release-As mints it" without qualification; the ownership page says this repository runs Release Please's default bump semantics and only seeded projects use `Release-As` | the contract clause now distinguishes the two and points at the ownership page, the boundary's one full statement (evidence: `release-please-config.json` has no `always-bump-patch`; no `Release-As` trailer on master since the v0.19 certification refresh) |
| 2 | `docs/product-constitution.md` vs `docs/adr/0026-…` | the constitution calls the Platform Compatibility Review "a permanent release gate"; ADR-0026 records its retirement on 2026-08-11 with the #361 governance deletion test | the paragraph carries a dated superseded marker pointing at the ADR; the constitution keeps its text as the record of what was decided |
| 3 | `docs/ops/release-merge-convention.md` vs `.github/spark-trunk-ruleset.json`, `plugins/spark/skills/ship/SKILL.md`, practice | the convention prefers true merge commits with plainly titled pull requests; the ruleset allows squash; the ship skill titles conventionally for squash merges; every v0.23 packet landed as a squash merge with a conventional title | **decided by the owner, 2026-09-07 (PR #762):** true merge commits are Spark's default governed merge strategy; the strategy becomes an explicit repository/operator preference, squash and rebase permitted when selected with equivalent exact-HEAD and provenance guarantees (its own work unit); the convention records the decision and the packets already landed as the exception |
| 4 | `plugins/spark/preferences/fact-model.tsv` (`verdict`) vs `docs/ops/ci-handoff.md`, `.github/scripts/docs-truth.sh`, `docs/ops/bounded-execution.md` | four token sets read as "the verdict vocabulary" | the reviewer's vocabulary is the fact model's `verdict` identifier; ci-handoff.md now names its tokens as handoff states and points there; the docs-truth results and bounded-execution outcomes are distinct vocabularies of their own surfaces and are left as they are |
| 5 | `plugins/spark/docs/reference/metadata-governance.md` vs `docs/governance/is-state-baseline-pre-v020.md` | "the native graph is the only executable dependency authority" vs "native blocked-by is not yet the sole executable authority" | the baseline (audited master `c9baaa9`, 2026-08-27) carries a historical banner; so does the v0.20 self-conformance audit |
| 6 | `.github/ISSUE_TEMPLATE/feature.yml`, `bug.yml` vs `spark-default.tsv` | the templates asked authors to write "Blocked by #86" in the body; the model says such a sentence explains a prerequisite and never creates one | the field now says prose explains and the native blocked-by relationship records, keeping the real-number rule |

Duplicates treated: the crossroad definition (verbatim in `cli.md` and the doctrine) — `cli.md` now points at
the doctrine; the non-escalatable human boundary (verbatim in `cli.md` and `docs/ops/execution-routing.md`) —
the ops page now points at the shipped statement. Not treated, by the issue's own non-goal: the how-to's
restatement of the ship guardrail (user-facing prose that mirrors the agent-facing skill) and the
enforcement-model page's explanation of the docs-truth script.

## Gaps the map records as exceptions

- **Routine merge authority (#677)** has no defining surface in the repository: four citations, zero
  definitions. The grant is a human decision record on GitHub; its prose home, ADR-0032, is in review as
  PR #727 and is human-owned. The map cites `github:jwogrady/spark#677` and fact-model R15 (the mechanical
  merge condition) and defines nothing.
- **Two review lanes** share the name "independent review": the built-in `/code-review` lane the `validate`
  skill orchestrates, and the OpenAI reviewer lane (#584). The map registers both surfaces under
  `review-lifecycle`; the lane document is dev-only and the workflow executes it.
- The audit brief assumed a `HEAD:` line in pull-request bodies; none exists on master. The comment
  marker `<!-- spark-openai-review pr=… head=… verdict=… -->` is the only HEAD-bound record.

## Mutable GitHub state in prose

`ROADMAP.md` and `docs/releases/v0.23.md` restate per-milestone placement (which issue is the release gate,
which sub-issues it carries). Both are dated projections: the roadmap now says so in its introduction and
names the operative source (the milestone and the governance model's role marker); the in-progress release
record is registered as a projection that becomes historical evidence at release. The pre-v0.20 baselines
that asserted live state are banners now.

## Hot-path reads, compared where the baseline instrumented them

Two instruments observed the hot path in the #737/#730 baseline, and both are re-run here.

**Footprint** (`tools/footprint.sh`, frozen `921c982` vs this change's HEAD) — what a session loads and
what the reviewer re-read, as tracked bytes and lines:

| Bucket | Before (921c982) | After (this HEAD) |
|---|---|---|
| `root.contract` (AGENTS.md + CLAUDE.md, auto-loaded every session) | 15,433 bytes / 292 lines | 15,648 bytes / 295 lines |
| `shipped.docs.spark` | 310,651 bytes / 5,908 lines | 427,680 bytes / 7,072 lines |
| `devdocs.ops` | 225,751 bytes / 4,286 lines | 256,730 bytes / 4,503 lines |

The contract grows by one clause (contradiction 1); the shipped docs shrink by the two duplicated
paragraphs and grow by the fact-freshness page #732 added between the two measurements — the figures are the
trees', not this change's alone.

**Workload reads** (`tools/analyze-transcript.py`, the baseline's transcript analyzer, over this job's own
Claude Code transcript). The baseline's workloads A (repairing PR #727) and B (PR #724) cannot be re-run:
each was a repair episode driven by a reviewer finding stream against a tree that no longer exists, so no
after-measurement of *those* workloads can be produced. What can be measured is the same instrument over
the workloads that consumed the audited surfaces after the change — the #732 contract rounds (D) and this
audit's own rounds (C), windows pinned in `741-transcript-reads.json` beside this page:

| Measure | A (#727 repair, baseline §2.3) | B (#724 repair, baseline §2.3) | D (#732 contract) | C (#741 audit) |
|---|---|---|---|---|
| tool calls in the window | 558 API requests | — | 184 | 65 |
| Read-tool calls | top read path 5× | top eight paths were task output | 2 | 2 |
| shell reads (sed/grep/cat) of repository files | — | — | 55 | 10 |
| distinct repository paths read | — | — | 2 | 7 |
| repeated repository path reads | — | — | 0 | 4 |
| gh invocations (lower bound) | `gh pr view 727` 21×, comments 19× | `issues/724/comments` 51× | 87 | 20 |
| touches of `plugins/spark/docs/reference/cli.md` | 11 | — | 0 (whole after-side) | 0 (whole after-side) |
| touches of `plugins/spark/skills/ship/SKILL.md` | 18 | — | 2 (whole after-side) | 2 (whole after-side) |
| touches of `plugins/spark/lib/execution.sh` | 62 | — | 0 (whole after-side) | 0 (whole after-side) |
| touches of `AGENTS.md` | — | — | 0 (whole after-side) | 0 (whole after-side) |

The two after-windows read the governed prose surfaces a handful of times because the evidence was captured
once (one sweep, kept as findings) and the rounds ran from scripts; the baseline's repeated reads were the
re-reconciliation of ADR, skill and CLI reference in every round. The workloads differ in kind (repair of
a runtime change vs. a schema contract and an audit), so the table compares instruments, not outcomes:
it shows the after-side is observable with the baseline's own tool and records what it observed. No claim
of a read-count reduction is made from it.

## Acceptance, item by item

- **Surfaces classified by role with evidence** — `docs/ops/doc-roles.tsv`, 170 rows, one role each; the
  evidence per concept is the sweep summarised above and the map's surface lists.
- **One operative source per concept or an explicit exception** — `docs/ops/canonical-truth.tsv`, nine
  concepts; one exception (routine merge authority), stated as such; the merge-method contradiction is
  decided and recorded.
- **Duplicate current prose treated** — two verbatim duplicates now point at their source; six contradictions
  treated or recorded (table above).
- **Mutable GitHub state not presented as timeless** — roadmap and release record registered as dated
  projections; the roadmap says so; baselines carry banners.
- **Historical evidence preserved, clearly non-operative** — ADRs, release records, research and dated
  audits registered as `historical-evidence`; two banners added; nothing deleted.
- **Projections state provenance/freshness** — the shipped reference pages are held to their authorities by
  their suites (governance model, fact model, freshness contract, CLI verbs, skills); the roadmap names its
  source and its dated nature.
- **Before/after counts recorded** — the table above, computed from the map.
- **Hot-path reads compared where observable** — the footprint table above; read counts are not claimed.
- **Docs-truth/governance suites green** — the docs suites, doctor and the new role suite ran green at this
  HEAD (the pull request records the figures).
