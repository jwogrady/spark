# Historical evidence separated from the current-truth path — the index (v0.23 cleanup, #742)

**Model.** `current fact → provenance/index pointer → historical evidence on demand`, never
`historical evidence → agent reconstruction → current fact`. The pointer is `docs/ops/evidence-index.tsv`:
every evidence artifact of the repository — 126 files, 923,720 bytes, 15,434 lines under
`docs/research`, `docs/releases`, `docs/governance`, the three evidence pages under `docs/ops`, `evaluations`
and `.spark` — is one row or one family member, with a retention class, an explicit *operative now* answer,
the release/HEAD/work unit it concerned, the fact it supported, who loads or cites it today, and why it is
kept. `tests/test-evidence-index.sh` holds the index to the tree (every artifact covered exactly once), checks
that every historical or do-not-delete row names an identity (an issue, a version or a commit) and a fact,
that every reader named exists and references the family, and — the hot-path claim — that no shipped
surface, test or CI script references a non-operative artifact the index does not list as its reader, and holds
this page's every observed-read figure to the committed capture.

**Method.** The inventory was taken over `origin/master` at `29e4f4e1f1e28c89c3d435d6f38c21d73190164a` by
reading each artifact's header for the identity it names and grepping the repository for who references it.
The index's file counts, bytes and lines are computed from the tree when the index is built; the tables below
are computed from the index and re-checked by the suite.

## Retention classes

| Class | Files | Bytes | Lines |
|---|---|---|---|
| `active-current` | 33 | 116,110 | 2,008 |
| `historical-retained` | 68 | 400,238 | 6,691 |
| `do-not-delete` | 25 | 407,372 | 6,735 |

No artifact is classified `redundant`. Two identical blobs exist (`evaluations/orchestration/rates.tsv` and
`evaluations/skill-routing/rates.tsv`; the two `run.tsv` files under `skill-routing/runs/*/routing/`) but each
is a per-suite input by design, so neither has independent retention value to disprove and neither is deletable
alone. Nothing was deleted or moved: the issue's own distinction is that moving files proves nothing about the
reasoning path, and every deletion candidate failed the "independent retention value disproven" test.

## Physical footprint, by directory

| Directory | Files | Bytes | Lines |
|---|---|---|---|
| `.spark` | 2 | 1,298 | 9 |
| `docs/governance` | 3 | 31,081 | 514 |
| `docs/ops` | 3 | 138,568 | 2,550 |
| `docs/releases` | 13 | 103,829 | 1,849 |
| `docs/research` | 2 | 7,056 | 101 |
| `docs/research/v0.23-cleanup` | 14 | 177,097 | 2,445 |
| `docs/research/v0.23-optimization-baseline` | 46 | 385,106 | 6,360 |
| `evaluations` | 43 | 79,685 | 1,606 |

## Reference footprint: what names the evidence by path

The static side. A surface that names an artifact by its repository path — the shipped runtime (`plugins/**`),
a test, a CI script — is a *reference*, not proof of a load: a citation, a fixture assertion or a documentation
link counts here. From the index's readers column:

| Family | Class | Operative now | Referenced by |
|---|---|---|---|
| `docs/research/v0.23-cleanup/741-canonical-truth.md` | `active-current` | yes | `tests/test-doc-roles.sh` |
| `docs/releases/README.md` | `active-current` | yes | `tests/test-state-docs-chronology.sh` |
| `docs/releases/v0.1*.md;docs/releases/v0.2[0-2].md` | `do-not-delete` | no | `.github/scripts/ledger-truth-check.sh`; `tests/test-docs-impact.sh`; `tests/test-readme-product-truth.sh`; `tests/test-reconcile-apply.sh`; `tests/test-state-docs-chronology.sh` |
| `docs/governance/capability-evaluation.md` | `active-current` | yes | `plugins/spark/docs/reference/release-docs-checklist.md` |
| `docs/ops/v0.21-dogfood-evaluation.md` | `do-not-delete` | no | `.github/scripts/ledger-truth-check.sh` |
| `docs/ops/telemetry-baseline.md` | `do-not-delete` | no | `tests/test-run-telemetry.sh` |
| `evaluations/lib/*;evaluations/evidence-index.tsv;evaluations/orchestration/run.sh;evaluations/orchestration/rates.tsv;evaluations/skill-routing/run.sh;evaluations/skill-routing/rates.tsv` | `active-current` | yes | `tests/test-eval-lib.sh`; `tests/test-skill-descriptions.sh` |
| `.spark/state.json;.spark/preferences.json` | `do-not-delete` | yes | `plugins/spark/bin/spark`; `plugins/spark/docs/README.md`; `plugins/spark/docs/how-to/get-started.md`; `plugins/spark/docs/how-to/resume.md`; `plugins/spark/docs/reference/cli.md`; `plugins/spark/docs/reference/compatibility.md`; `plugins/spark/docs/reference/engineering-preferences.md`; `plugins/spark/docs/reference/fact-freshness.md`; `plugins/spark/docs/reference/fact-model.md`; `plugins/spark/docs/reference/hooks.md`; `plugins/spark/docs/reference/project-standards.md`; `plugins/spark/docs/reference/stability.md`; `plugins/spark/docs/reference/state.md`; `plugins/spark/docs/tutorials/adopt-an-existing-repo.md`; `plugins/spark/docs/tutorials/scaffold-a-new-project.md`; `plugins/spark/preferences/fact-model.tsv`; `plugins/spark/preferences/templates/standards/conventions.md`; `plugins/spark/preferences/templates/standards/engineering-standards.md`; `plugins/spark/skills/bootstrap/SKILL.md`; `plugins/spark/skills/bootstrap/references/profiles.md`; `plugins/spark/skills/codify/SKILL.md`; `plugins/spark/skills/ideate/SKILL.md`; `plugins/spark/skills/knowledge/references/operator-knowledge.md`; `plugins/spark/skills/onboard/SKILL.md`; `plugins/spark/skills/plan/SKILL.md`; `plugins/spark/skills/ship/SKILL.md`; `plugins/spark/skills/validate/SKILL.md`; `tests/bench-memo.sh`; `tests/test-apply-permissions.sh`; `tests/test-brief-resume.sh`; `tests/test-course-derivation.sh`; `tests/test-doctor-standards-boundary.sh`; `tests/test-first-run.sh`; `tests/test-governance-contract.sh`; `tests/test-governance-integration.sh`; `tests/test-governance-schema.sh`; `tests/test-hot-path-memo.sh`; `tests/test-hub.sh`; `tests/test-labels.sh`; `tests/test-merge-strategy.sh`; `tests/test-orient.sh`; `tests/test-preferences.sh`; `tests/test-reconcile-apply.sh`; `tests/test-reconcile-slate.sh`; `tests/test-setup-profiles.sh`; `tests/test-state.sh`; `tests/test-triage-truth.sh` |

**23 files, 244,492 bytes** of the 126-file, 923,720-byte corpus are referenced by code,
tests or CI (26 % by bytes). The suite holds this list to the tree: a shipped surface that
starts naming a non-operative artifact fails until the index lists it.

## Observed default reads: what the runtime actually opens

The observed side, in the #730 sense. `tools/evidence-reads.sh` runs the read-only, network-free verbs
(`doctor`, `brief`, `footprint`, `preferences`, `profiles`, `list-skills`) under `strace -e trace=openat`
against a pristine clone checked out at one commit — never against a working tree, because `brief` shells out to
`git status`, which reads every modified file, and an author's edits are not runtime reads — and records every
evidence-root path each verb opens successfully, separating a file read from a directory traversal. The capture is
committed beside this page as `742-default-reads.tsv`; its header names the observed commit and the tracer, the
suite checks that commit is an ancestor of HEAD, and rerunning the tool at that commit reproduces the rows.
What the verbs opened:

| Verb | Corpus files opened | `historical-retained` | `do-not-delete` | `active-current` | Directories traversed | Non-corpus files opened |
|---|---|---|---|---|---|---|
| `doctor` | 49 | 18 | 17 | 14 | 0 | 15 |
| `brief` | 124 | 67 | 25 | 32 | 34 | 18 |
| `footprint` | 2 | 0 | 2 | 0 | 34 | 0 |
| `preferences` | 1 | 0 | 1 | 0 | 0 | 0 |
| `profiles` | 0 | 0 | 0 | 0 | 0 | 0 |
| `list-skills` | 0 | 0 | 0 | 0 | 0 | 0 |

On a clean checkout the default verbs opened 142 files under the evidence roots, 124 of them indexed corpus artifacts, of which **92 are non-operative history** (`historical-retained` or `do-not-delete`).

This contradicts the assumption the work unit started from, and it is the measurement the issue asked for. The
mechanism is a directory walk, not a citation: `spark doctor` validates the tier of every Markdown surface in the
repository, so it opens each one to read its front matter, and repo-root `docs/` is where the evidence lives;
`spark brief` performs that same validation and additionally reads the ops registers and the evaluation run data
while orienting a session. Traversal is counted separately — `footprint` walks the evidence tree to size it and
opens no file in it, which is the shape the model wants.

Which history the default path opens, by family:

| Family | Class | Files opened |
|---|---|---|
| `docs/research/v0.23-optimization-baseline/raw/*` | `historical-retained` | 21 |
| `docs/research/v0.23-optimization-baseline/tools/*` | `historical-retained` | 15 |
| `docs/releases/v0.1*.md` and 1 more pattern(s) | `do-not-delete` | 10 |
| `evaluations/orchestration/runs/**` | `historical-retained` | 9 |
| `docs/research/v0.23-optimization-baseline/raw/pr724/**` and 1 more pattern(s) | `do-not-delete` | 6 |
| `docs/research/v0.23-cleanup/738-*` | `historical-retained` | 5 |
| `docs/research/v0.23-optimization-baseline/README.md` and 2 more pattern(s) | `do-not-delete` | 3 |
| `evaluations/provenance-promotion/PROOF.md` and 2 more pattern(s) | `historical-retained` | 3 |
| `evaluations/skill-routing/runs/pre-trim-descriptions/**` | `historical-retained` | 3 |
| `.spark/state.json` and 1 more pattern(s) | `do-not-delete` | 2 |
| `docs/governance/is-state-baseline-pre-v020.md` and 1 more pattern(s) | `historical-retained` | 2 |
| `docs/research/v0.23-cleanup/tools/*` | `historical-retained` | 2 |
| `evaluations/orchestration/BASELINE.md` and 1 more pattern(s) | `historical-retained` | 2 |
| `docs/ops/telemetry-baseline.md` | `do-not-delete` | 1 |
| `docs/ops/v0.21-dogfood-evaluation.md` | `do-not-delete` | 1 |
| `docs/releases/v0.23-usage-evidence.md` | `do-not-delete` | 1 |
| `docs/research/v0.12-orchestration-recommendation.md` | `historical-retained` | 1 |
| `docs/research/v0.13-mechanical-offload-audit.md` | `historical-retained` | 1 |
| `docs/research/v0.23-cleanup/739-semantic-map.md` | `historical-retained` | 1 |
| `docs/research/v0.23-cleanup/740-test-consolidation.md` | `historical-retained` | 1 |
| `docs/research/v0.23-cleanup/741-transcript-reads.json` | `historical-retained` | 1 |
| `docs/research/v0.23-optimization-baseline/raw/branches.tsv` | `do-not-delete` | 1 |

The suite recomputes every figure in both tables from the capture and the index and fails if this page states a
different one, so a change in what the default verbs read cannot land silently: regenerate the capture and the
numbers move together. Set `SPARK_OBSERVE_READS=1` on a machine with `strace` and the suite re-observes the
capture's own commit and fails on any drift from the committed rows.

## Three leaks: non-operative evidence on the active path

| Artifact | Why it is on the path |
|---|---|
| `docs/releases/v0.1*.md;docs/releases/v0.2[0-2].md` | the runtime enumerates docs/releases/v*.md for dispositions (reconcile) and its readers are computed over the directory; deleting a record changes reconcile output |
| `docs/ops/v0.21-dogfood-evaluation.md` | LEAK: the live CI script defaults to this v0.21 record as its ledger; a proposed CI change is recorded in the manifest, not applied |
| `docs/ops/telemetry-baseline.md` | a test pins the path |

- **`docs/ops/v0.21-dogfood-evaluation.md`** — `.github/scripts/ledger-truth-check.sh` uses this v0.21
  record as its *default* ledger (and `docs/releases/v0.21.md` as its default record); the suite that tests
  the script always passes `--ledger`/`--record` explicitly, so the defaults are never exercised. The fix is a
  CI change — make the two arguments required, or default them from the current release record — and CI
  edits are human-approved in this repository, so the change is proposed here and not applied:

  ```
  # .github/scripts/ledger-truth-check.sh — proposed
  -[ -n "$ledger" ] || ledger="$root/docs/ops/v0.21-dogfood-evaluation.md"
  -[ -n "$record" ] || record="$root/docs/releases/v0.21.md"
  +[ -n "$ledger" ] || { echo "--ledger is required: the current release's ledger" >&2; exit 2; }
  +[ -n "$record" ] || { echo "--record is required: the current release's record" >&2; exit 2; }
  ```
- **The default read path opens the historical corpus** — measured above, not repaired here. `doctor`'s tier
  validation and `brief`'s orientation walk repo-root `docs/` and `evaluations/` and open every Markdown surface
  in them, so the non-operative corpus is read on the default path of the two verbs a session runs first. The
  index cannot fix this: the reads are positional (a directory walk), not by name, so no reader column and no
  file move would change them. The repair is a runtime-scope change — the tier validation needs the corpus's
  boundary as data (this index is that data) instead of walking every Markdown file it finds, and the workload
  measurement belongs to the #730 lane — so it is recorded here with its measurement and left to its own unit
  rather than smuggled into a docs-only change.
- **`.spark/state.json`** — the committed work state is a current-truth artifact by definition (ADR-0031),
  but its narrative (`updated 2026-08-30`) names work long closed (#474, #484, #616, PR #617). It is
  operative — the runtime reads it — and stale; the state verbs own it, so it is flagged for the next
  `spark` state update rather than edited by hand here.

## What is not claimed

No read-count reduction, and no claim that history is off the default-read path — the capture shows the
opposite, and that finding is recorded as a leak rather than dressed up. Nothing on the hot path changed in this
work unit, so the #730 workload figures would be unchanged by construction. What is claimed is machine-checked:
every evidence artifact is classified and reachable through one index row; a shipped surface that starts naming a
non-operative artifact fails `tests/test-evidence-index.sh` until the index lists it as a reader; and the
default-read behaviour of the read-only verbs is a committed, commit-pinned, regenerable observation whose every
reported figure the suite recomputes. Physical footprint is reported unchanged, separately from the reference
footprint and the observed reads, as the issue requires.

## Acceptance, item by item

- **Evidence families classified with retention rationale** — `docs/ops/evidence-index.tsv`, 32 rows, one
  class and one rationale each.
- **Historical material pointable by release/HEAD/work unit/fact** — every historical-retained and
  do-not-delete row names an identity and the fact it supported; the suite checks both.
- **Retained history explicitly non-operative where appropriate** — the `operative-now` column; every
  historical-retained row says `no`.
- **No evidence deleted for LOC or file count** — nothing deleted.
- **Redundant evidence deleted only when disproven and safe** — none qualified; the two identical blobs are
  per-suite inputs by design.
- **Active-reasoning claims supported by observed/default-read behaviour** — an `strace` capture of the
  read-only verbs on a clean checkout (`742-default-reads.tsv`, regenerable by `tools/evidence-reads.sh`),
  every figure recomputed by the suite. The measurement refuted the starting assumption and is reported as the
  third leak; the reference footprint is reported separately and labelled as references, not loads.
- **Physical and hot-path footprints reported separately** — the physical table, the reference table and the
  observed-reads tables above.
- **Current fact/provenance links valid** — nothing moved; the suite checks every reader path exists and
  references its family.
