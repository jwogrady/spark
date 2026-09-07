# Historical evidence separated from the current-truth path — the index (v0.23 cleanup, #742)

**Model.** `current fact → provenance/index pointer → historical evidence on demand`, never
`historical evidence → agent reconstruction → current fact`. The pointer is `docs/ops/evidence-index.tsv`:
every evidence artifact of the repository — 124 files, 898,028 bytes, 15,030 lines under
`docs/research`, `docs/releases`, `docs/governance`, the three evidence pages under `docs/ops`, `evaluations`
and `.spark` — is one row or one family member, with a retention class, an explicit *operative now* answer,
the release/HEAD/work unit it concerned, the fact it supported, who loads or cites it today, and why it is
kept. `tests/test-evidence-index.sh` holds the index to the tree (every artifact covered exactly once), checks
that every historical or do-not-delete row names an identity (an issue, a version or a commit) and a fact,
that every reader named exists and references the family, and — the hot-path claim — that no shipped
surface, test or CI script references a non-operative artifact the index does not list as its reader.

**Method.** The inventory was taken over `origin/master` at `29e4f4e1f1e28c89c3d435d6f38c21d73190164a` by
reading each artifact's header for the identity it names and grepping the repository for who references it.
The index's file counts, bytes and lines are computed from the tree when the index is built; the tables below
are computed from the index and re-checked by the suite.

## Retention classes

| Class | Files | Bytes | Lines |
|---|---|---|---|
| `active-current` | 32 | 93,285 | 1,651 |
| `historical-retained` | 67 | 397,371 | 6,644 |
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
| `docs/research/v0.23-cleanup` | 12 | 151,405 | 2,041 |
| `docs/research/v0.23-optimization-baseline` | 46 | 385,106 | 6,360 |
| `evaluations` | 43 | 79,685 | 1,606 |

## Hot-path footprint: what code actually loads

The active reasoning path is what the shipped runtime (`plugins/**`), the tests and the CI scripts load or
assert on — not what a directory listing contains. From the index's readers column:

| Family | Class | Operative now | Loaded by |
|---|---|---|---|
| `docs/research/v0.23-cleanup/741-canonical-truth.md` | `active-current` | yes | `tests/test-doc-roles.sh` |
| `docs/releases/README.md` | `active-current` | yes | `tests/test-state-docs-chronology.sh` |
| `docs/releases/v0.1*.md;docs/releases/v0.2[0-2].md` | `do-not-delete` | no | `.github/scripts/ledger-truth-check.sh`; `tests/test-docs-impact.sh`; `tests/test-readme-product-truth.sh`; `tests/test-reconcile-apply.sh`; `tests/test-state-docs-chronology.sh` |
| `docs/governance/capability-evaluation.md` | `active-current` | yes | `plugins/spark/docs/reference/release-docs-checklist.md` |
| `docs/ops/v0.21-dogfood-evaluation.md` | `do-not-delete` | no | `.github/scripts/ledger-truth-check.sh` |
| `docs/ops/telemetry-baseline.md` | `do-not-delete` | no | `tests/test-run-telemetry.sh` |
| `evaluations/lib/*;evaluations/evidence-index.tsv;evaluations/orchestration/run.sh;evaluations/orchestration/rates.tsv;evaluations/skill-routing/run.sh;evaluations/skill-routing/rates.tsv` | `active-current` | yes | `tests/test-eval-lib.sh`; `tests/test-skill-descriptions.sh` |
| `.spark/state.json;.spark/preferences.json` | `do-not-delete` | yes | `plugins/spark/bin/spark`; `plugins/spark/docs/README.md`; `plugins/spark/docs/how-to/get-started.md`; `plugins/spark/docs/how-to/resume.md`; `plugins/spark/docs/reference/cli.md`; `plugins/spark/docs/reference/compatibility.md`; `plugins/spark/docs/reference/engineering-preferences.md`; `plugins/spark/docs/reference/fact-freshness.md`; `plugins/spark/docs/reference/fact-model.md`; `plugins/spark/docs/reference/hooks.md`; `plugins/spark/docs/reference/project-standards.md`; `plugins/spark/docs/reference/stability.md`; `plugins/spark/docs/reference/state.md`; `plugins/spark/docs/tutorials/adopt-an-existing-repo.md`; `plugins/spark/docs/tutorials/scaffold-a-new-project.md`; `plugins/spark/preferences/fact-model.tsv`; `plugins/spark/preferences/templates/standards/conventions.md`; `plugins/spark/preferences/templates/standards/engineering-standards.md`; `plugins/spark/skills/bootstrap/SKILL.md`; `plugins/spark/skills/bootstrap/references/profiles.md`; `plugins/spark/skills/codify/SKILL.md`; `plugins/spark/skills/ideate/SKILL.md`; `plugins/spark/skills/knowledge/references/operator-knowledge.md`; `plugins/spark/skills/onboard/SKILL.md`; `plugins/spark/skills/plan/SKILL.md`; `plugins/spark/skills/ship/SKILL.md`; `plugins/spark/skills/validate/SKILL.md`; `tests/bench-memo.sh`; `tests/test-apply-permissions.sh`; `tests/test-brief-resume.sh`; `tests/test-course-derivation.sh`; `tests/test-doctor-standards-boundary.sh`; `tests/test-first-run.sh`; `tests/test-governance-contract.sh`; `tests/test-governance-integration.sh`; `tests/test-governance-schema.sh`; `tests/test-hot-path-memo.sh`; `tests/test-hub.sh`; `tests/test-labels.sh`; `tests/test-merge-strategy.sh`; `tests/test-orient.sh`; `tests/test-preferences.sh`; `tests/test-reconcile-apply.sh`; `tests/test-reconcile-slate.sh`; `tests/test-setup-profiles.sh`; `tests/test-state.sh`; `tests/test-triage-truth.sh` |

**23 files, 244,492 bytes** of the 124-file, 898,028-byte evidence corpus are on that
path (27 % by bytes). Everything else — the whole `v0.23-optimization-baseline`
bundle, the cleanup records, the pre-v0.20 audits, the evaluation runs — is reached only through the index or
through another evidence page, which is the desired shape.

## Two leaks: non-operative evidence on the active path

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
- **`.spark/state.json`** — the committed work state is a current-truth artifact by definition (ADR-0031),
  but its narrative (`updated 2026-08-30`) names work long closed (#474, #484, #616, PR #617). It is
  operative — the runtime reads it — and stale; the state verbs own it, so it is flagged for the next
  `spark` state update rather than edited by hand here.

## What is not claimed

No read-count reduction: nothing on the hot path changed in this work unit, so the #730 workload figures
would be unchanged by construction. The claim made is structural and machine-checked: every non-operative
artifact is reachable only through the index, and any future shipped surface that starts reading one fails
`tests/test-evidence-index.sh` until the index names it as a reader. Physical footprint is reported above
unchanged, separately from the hot-path footprint, as the issue requires.

## Acceptance, item by item

- **Evidence families classified with retention rationale** — `docs/ops/evidence-index.tsv`, 31 rows, one
  class and one rationale each.
- **Historical material pointable by release/HEAD/work unit/fact** — every historical-retained and
  do-not-delete row names an identity and the fact it supported; the suite checks both.
- **Retained history explicitly non-operative where appropriate** — the `operative-now` column; every
  historical-retained row says `no`.
- **No evidence deleted for LOC or file count** — nothing deleted.
- **Redundant evidence deleted only when disproven and safe** — none qualified; the two identical blobs are
  per-suite inputs by design.
- **Active-reasoning claims supported by observed/default-read behaviour** — the hot-path table is derived
  from what code loads (the readers column, verified by grep), not from directory movement; no read-count
  claim is made.
- **Physical and hot-path footprints reported separately** — the two tables above.
- **Current fact/provenance links valid** — nothing moved; the suite checks every reader path exists and
  references its family.
