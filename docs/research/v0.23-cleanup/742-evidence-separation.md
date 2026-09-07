# Historical evidence separated from the current-truth path — the index (v0.23 cleanup, #742)

**Model.** `current fact → provenance/index pointer → historical evidence on demand`, never
`historical evidence → agent reconstruction → current fact`. The pointer is `docs/ops/evidence-index.tsv`:
every evidence artifact of the repository — 132 files, 1,036,774 bytes, 16,771 lines under
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
| `active-current` | 52 | 430,069 | 7,027 |
| `historical-retained` | 67 | 397,371 | 6,644 |
| `do-not-delete` | 13 | 209,334 | 3,100 |

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
| `docs/research/v0.23-cleanup` | 20 | 290,151 | 3,782 |
| `docs/research/v0.23-optimization-baseline` | 46 | 385,106 | 6,360 |
| `evaluations` | 43 | 79,685 | 1,606 |

## Reference footprint: what names the evidence by path

The static side. A surface that names an artifact by its repository path — the shipped runtime (`plugins/**`),
a test, a CI script — is a *reference*, not proof of a load: a citation, a fixture assertion or a documentation
link counts here. This unit's own five files are excluded by name — `docs/ops/evidence-index.tsv`,
`tests/test-evidence-index.sh`, `docs/research/v0.23-cleanup/742-evidence-separation.md`,
`docs/research/v0.23-cleanup/742-default-reads.tsv` and
`docs/research/v0.23-cleanup/tools/evidence-reads.sh` — so the metric measures the repository's references to its
evidence rather than the index's references to itself. From the readers column:

| Family | Class | Operative now | Referenced by |
|---|---|---|---|
| `docs/research/v0.23-cleanup/741-canonical-truth.md` | `active-current` | yes | `tests/test-doc-roles.sh` |
| `docs/research/v0.23-cleanup/743-responsibilities.tsv` | `active-current` | yes | `tests/test-runtime-responsibilities.sh` |
| `docs/research/v0.23-cleanup/743-responsibilities-before.tsv` | `active-current` | yes | `tests/test-runtime-responsibilities.sh` |
| `docs/research/v0.23-cleanup/743-runtime-surface.md` | `active-current` | yes | `tests/test-runtime-responsibilities.sh` |
| `docs/research/v0.23-cleanup/tools/build-responsibilities.py;docs/research/v0.23-cleanup/tools/classification.py;docs/research/v0.23-cleanup/tools/classification_modules.py` | `active-current` | yes | `tests/test-runtime-responsibilities.sh` |
| `docs/releases/README.md` | `active-current` | yes | `tests/test-state-docs-chronology.sh` |
| `docs/releases/v0.1*.md;docs/releases/v0.2[0-2].md` | `active-current` | yes | `.github/scripts/ledger-truth-check.sh`; `tests/test-docs-impact.sh`; `tests/test-readme-product-truth.sh`; `tests/test-reconcile-apply.sh`; `tests/test-state-docs-chronology.sh` |
| `docs/governance/capability-evaluation.md` | `active-current` | yes | `plugins/spark/docs/reference/release-docs-checklist.md` |
| `docs/ops/v0.21-dogfood-evaluation.md` | `active-current` | yes | `.github/scripts/ledger-truth-check.sh` |
| `docs/ops/telemetry-baseline.md` | `active-current` | yes | `tests/test-run-telemetry.sh` |
| `evaluations/lib/*;evaluations/evidence-index.tsv;evaluations/orchestration/run.sh;evaluations/orchestration/rates.tsv;evaluations/skill-routing/run.sh;evaluations/skill-routing/rates.tsv` | `active-current` | yes | `tests/test-eval-lib.sh`; `tests/test-skill-descriptions.sh` |
| `.spark/state.json;.spark/preferences.json` | `do-not-delete` | yes | `plugins/spark/bin/spark`; `plugins/spark/docs/README.md`; `plugins/spark/docs/how-to/get-started.md`; `plugins/spark/docs/how-to/resume.md`; `plugins/spark/docs/reference/cli.md`; `plugins/spark/docs/reference/compatibility.md`; `plugins/spark/docs/reference/engineering-preferences.md`; `plugins/spark/docs/reference/fact-freshness.md`; `plugins/spark/docs/reference/fact-model.md`; `plugins/spark/docs/reference/hooks.md`; `plugins/spark/docs/reference/project-standards.md`; `plugins/spark/docs/reference/stability.md`; `plugins/spark/docs/reference/state.md`; `plugins/spark/docs/tutorials/adopt-an-existing-repo.md`; `plugins/spark/docs/tutorials/scaffold-a-new-project.md`; `plugins/spark/preferences/fact-model.tsv`; `plugins/spark/preferences/templates/standards/conventions.md`; `plugins/spark/preferences/templates/standards/engineering-standards.md`; `plugins/spark/skills/bootstrap/SKILL.md`; `plugins/spark/skills/bootstrap/references/profiles.md`; `plugins/spark/skills/codify/SKILL.md`; `plugins/spark/skills/ideate/SKILL.md`; `plugins/spark/skills/knowledge/references/operator-knowledge.md`; `plugins/spark/skills/onboard/SKILL.md`; `plugins/spark/skills/plan/SKILL.md`; `plugins/spark/skills/ship/SKILL.md`; `plugins/spark/skills/validate/SKILL.md`; `tests/bench-memo.sh`; `tests/test-apply-permissions.sh`; `tests/test-brief-resume.sh`; `tests/test-course-derivation.sh`; `tests/test-doctor-standards-boundary.sh`; `tests/test-first-run.sh`; `tests/test-governance-contract.sh`; `tests/test-governance-integration.sh`; `tests/test-governance-schema.sh`; `tests/test-hot-path-memo.sh`; `tests/test-hub.sh`; `tests/test-labels.sh`; `tests/test-merge-strategy.sh`; `tests/test-orient.sh`; `tests/test-preferences.sh`; `tests/test-reconcile-apply.sh`; `tests/test-reconcile-slate.sh`; `tests/test-setup-profiles.sh`; `tests/test-state.sh`; `tests/test-triage-truth.sh` |

**29 files, 355,265 bytes** of the 132-file, 1,036,774-byte corpus are referenced by code,
tests or CI outside this index's own machinery (34 % by bytes; the exclusion and its
reason are stated under the footprint section below). The suite holds this list to the tree: a shipped surface
that starts naming a non-operative artifact fails until the index lists it.

## Observed default reads: what the runtime actually opens

The observed side, in the #730 sense. `tools/evidence-reads.sh` runs the read-only, network-free verbs
(`doctor`, `brief`, `footprint`, `preferences`, `profiles`, `list-skills`) under `strace -e trace=openat`
against a pristine clone checked out at one commit — never against a working tree, because `brief` shells out to
`git status`, which reads every file git cannot vouch for, and an author's edits are not runtime reads. Before
measuring anything the tool proves git is not the reader: it warms the clone's index and then traces a bare
`git status`, which must open no file under the evidence roots. It arms the clone with the git hooks a developer's
tree has, requires every verb to exit 0, and records each exit status in the capture's header, so a run that ends
early cannot be mistaken for a measurement. Each evidence-root path is recorded once per verb, with a file read
and a directory traversal kept apart. The capture is committed beside this page as `742-default-reads.tsv`.
What the verbs opened:

| Verb | Corpus files opened | `historical-retained` | `do-not-delete` | `active-current` | Directories traversed | Non-corpus files opened |
|---|---|---|---|---|---|---|
| `doctor` | 50 | 18 | 5 | 27 | 0 | 15 |
| `brief` | 2 | 0 | 2 | 0 | 34 | 0 |
| `footprint` | 2 | 0 | 2 | 0 | 34 | 0 |
| `preferences` | 1 | 0 | 1 | 0 | 0 | 0 |
| `profiles` | 0 | 0 | 0 | 0 | 0 | 0 |
| `list-skills` | 0 | 0 | 0 | 0 | 0 | 0 |

`spark doctor` opens **50** indexed corpus artifacts, **23** of them non-operative. The session path opens **2** corpus files, both the runtime's own committed state. Across the six read-only verbs, **24** non-operative evidence files are opened by default.

The session path's files are `.spark/preferences.json`, `.spark/state.json`, and it opens nothing else under the evidence roots.

The two sides of that line are different acts. The session-orientation path — `brief`, `footprint`,
`preferences`, `profiles`, `list-skills` — opens no evidence file at all: it reads the two committed state files
the runtime owns and, where it needs a size, traverses directories without opening what is in them. Historical
evidence is therefore off the path a session reasons on, which is what #742 asks for.

The reads that remain are one mechanical validation. `spark doctor`'s Doc-links check
(`plugins/spark/bin/spark`, the `Doc links:` section) opens every Markdown file it can find and resolves each
relative link in it, so it reads the evidence pages because they are Markdown, not because anything cites them.
That check is what keeps this index's pointers honest — the acceptance item "current fact/provenance links
valid" is enforced by it — so narrowing it would trade a guarantee for a read count, and the read is one open of
each file by a validator that runs on demand, not a load into a session's reasoning context. It is reported here
as a measured fact rather than repaired, and **#768 owns the repair**: bounding that read set is a shipped-runtime
change, and an index-mediated path is not available to a plugin installed where this index does not exist. The
suite pins the measurement meanwhile: the capture's `doctor` rows must equal exactly the Markdown surfaces HEAD's
tree has under the evidence roots, which is also what makes the committed capture valid for HEAD rather than only
for the commit it was observed at.

**Method correction.** The first capture in this PR was taken on a cold clone, and this page reported git's work
as Spark's. In a fresh checkout git has no stat data for any file, and entries written in the same second as the
index are racily clean, so the next `git status` re-hashes the whole tree — 144 extra evidence-file opens
attributed to `brief`, nondeterministically: two runs of the same tool at the same commit disagreed. Refreshing
the index is not enough to state as an assumption, so the tool now measures the precondition, and the header line
above is written only after a traced `git status` opens no evidence file. The directory traversals in the table
are that same `git status` walking the tree for untracked files, which is why they are counted apart from reads.

Which non-operative evidence the default path opens, by family. The two `.spark` files are the runtime's own
committed state — classified `do-not-delete`, read by design — and every other row is the link validator:

| Family | Class | Files opened |
|---|---|---|
| `docs/research/v0.23-optimization-baseline/raw/*` | `historical-retained` | 6 |
| `docs/research/v0.23-optimization-baseline/README.md` and 2 more pattern(s) | `do-not-delete` | 3 |
| `evaluations/provenance-promotion/PROOF.md` and 2 more pattern(s) | `historical-retained` | 3 |
| `.spark/state.json` and 1 more pattern(s) | `do-not-delete` | 2 |
| `docs/governance/is-state-baseline-pre-v020.md` and 1 more pattern(s) | `historical-retained` | 2 |
| `evaluations/orchestration/BASELINE.md` and 1 more pattern(s) | `historical-retained` | 2 |
| `docs/releases/v0.23-usage-evidence.md` | `do-not-delete` | 1 |
| `docs/research/v0.12-orchestration-recommendation.md` | `historical-retained` | 1 |
| `docs/research/v0.13-mechanical-offload-audit.md` | `historical-retained` | 1 |
| `docs/research/v0.23-cleanup/738-*` | `historical-retained` | 1 |
| `docs/research/v0.23-cleanup/739-semantic-map.md` | `historical-retained` | 1 |
| `docs/research/v0.23-cleanup/740-test-consolidation.md` | `historical-retained` | 1 |

The suite recomputes every figure in both tables *and the sentence above* from the capture and the index, and
fails if this page states a different one. It asserts the separation claim directly — no verb other than
`doctor` may open a file under the evidence roots except the two `.spark` state files — and it binds the capture
to HEAD three ways: the observed commit must be in HEAD's history, `plugins/` must be byte-identical between
them, and the corpus's set of paths must be unchanged, so no verb can open a file that did not exist when the
capture was taken. On any machine with `strace` the suite additionally re-observes HEAD itself and requires the
committed rows back, unbroken; `SPARK_SKIP_OBSERVE=1` is the documented escape for a sandbox that forbids
`ptrace`, and the suite prints that it skipped rather than passing quietly.

## Three current-state dependencies on historical records

Separation is proven for the path a session reasons on, and it is not complete for the repository: three closed
records are read by current-state surfaces today. They are classified `operative-now = yes`, because they are —
the classification follows the behaviour, not the intent — and each names the issue that owns its repair.

The boundary is the repository operator's decision, recorded on #742 and quoted here so this page carries the
approval rather than a claim about one — [issue comment 5575893971](https://github.com/jwogrady/spark/issues/742#issuecomment-5575893971),
by `jwogrady`, whom GitHub reports as `OWNER`, on 2026-09-07:

> ## Human decision — narrow #742; preserve work-unit boundaries
>
> Approved: **accept the narrowed #742 claim**.
>
> #742 should land only the evidence index plus the measured separation it actually proves. Do **not** widen this
> unit to modify CI, shipped `spark reconcile` behavior, or the #558 telemetry suite.
>
> The three remaining current dependencies on historical records must move to a bounded follow-up under parent
> #729 and remain required v0.23 cleanup work […]
>
> This decision narrows #742's claim; it does **not** waive those dependencies or declare #729/#480 complete. #742
> still requires exact-HEAD independent PASS before governed merge/closeout.

All three dependencies therefore move to **#768**, a sub-issue of #729 alongside this one, and nothing here
declares #729 or #480 complete.

| Artifact | Class | Operative now | Why it is on the current path |
|---|---|---|---|
| `docs/releases/v0.1*.md;docs/releases/v0.2[0-2].md` | `active-current` | yes | `spark reconcile`'s release-record residue loop globs `docs/releases/v*.md` and reads each record's `Disposition:` line against the published tags, so every closed record is read by a current-state verb and deleting one changes its output |
| `docs/ops/v0.21-dogfood-evaluation.md` | `active-current` | yes | the live CI script defaults its ledger to this v0.21 record, so a release two versions old is the fallback truth of a current check |
| `docs/ops/telemetry-baseline.md` | `active-current` | yes | tests/test-run-telemetry.sh pins this path, so a closed baseline is load-bearing for a suite that runs on every change |

- **`docs/releases/v0.1*.md;docs/releases/v0.2[0-2].md`** — concerns v0.10 – v0.22, one record each; it supported what each release shipped and its disposition. Owner: #768, which owns the remaining current dependencies on historical evidence; repairing it means deriving current state from a canonical source while published-release contradictions stay detectable
- **`docs/ops/v0.21-dogfood-evaluation.md`** — concerns milestone #18 (v0.21) driven by v0.20.0; fd407c72; it supported the v0.21 dogfood ledger. Owner: #768; the exact diff is proposed on this page and applied there, under the human approval a CI change requires here
- **`docs/ops/telemetry-baseline.md`** — concerns #574; base 20eabbb; it supported the run-telemetry baseline for #558, #575, #576. Owner: #768; repairing it means the suite asserting against a fixture it owns, without reducing discrimination

The CI default is the one with a diff ready, and it is deliberately not applied — CI edits are human-approved
in this repository:

```
# .github/scripts/ledger-truth-check.sh — proposed
-[ -n "$ledger" ] || ledger="$root/docs/ops/v0.21-dogfood-evaluation.md"
-[ -n "$record" ] || record="$root/docs/releases/v0.21.md"
+[ -n "$ledger" ] || { echo "--ledger is required: the current release's ledger" >&2; exit 2; }
+[ -n "$record" ] || { echo "--record is required: the current release's record" >&2; exit 2; }
```

## One stale current artifact

`.spark/state.json` is a current-truth artifact by definition (ADR-0031) and operative — the runtime reads it —
but its narrative (`updated 2026-08-30`) names work long closed (#474, #484, #616, PR #617). That is staleness,
not a dependency on history, so it is listed separately: the state verbs own the file and it is flagged for the
next `spark` state update rather than edited by hand here.

## Footprint before and after this work unit

Physical, over the same roots, against `efbdb47` — the commit this branch left:

| | Files | Bytes | Lines |
|---|---|---|---|
| before | 129 | 998,837 | 16,256 |
| after | 132 | 1,036,774 | 16,771 |
| delta | +3 | +37,937 | +515 |

The corpus grew, and this page is part of the growth: this manifest, the observation capture and the tool that
regenerates it are themselves evidence, and they are indexed like everything else. Nothing was moved or deleted,
so every byte of the delta is new material, not relocation. The reference footprint did not move: 29 files before
this unit and 29 after, because this unit's own five files are excluded as readers and no other surface
started naming evidence. The corpus grew and the count of referenced files did not, so the share of the corpus that any surface names by path fell.

The hot path moved too, and by exactly the amount this unit added to it. `doctor`'s link validator opens every
Markdown surface under these roots, so its read set is the tree's Markdown: **63 files before this
unit, 64 after**, a delta of **+1** — this unit adds `docs/research/v0.23-cleanup/742-evidence-separation.md`. That is a measurement, not an
argument from construction: both figures come from the same roots, the after figure is the committed capture's
own `doctor` rows, and the suite recomputes the delta from the base commit whenever it is present. No other
verb's read set changed, because the session path opens no evidence file at either commit.

**What the corpus excludes, and why.** The corpus is evidence *about the repository's past*. The index and its
machinery are current-truth metadata *about the corpus*, so they are not members of it: `docs/ops/evidence-index.tsv`
and `tests/test-evidence-index.sh` are outside the counted roots by construction, and the reference footprint
does not count this unit's own five files — `docs/ops/evidence-index.tsv`, `tests/test-evidence-index.sh`,
`docs/research/v0.23-cleanup/742-evidence-separation.md`, `docs/research/v0.23-cleanup/742-default-reads.tsv`
and `docs/research/v0.23-cleanup/tools/evidence-reads.sh` — as readers, because a metric that counted its own
machinery would report itself as the repository's dependence on history. The capture is the clearest case: it
names almost every evidence path, because recording them is its job. The two artifacts of this unit that *are* evidence — this manifest and the observation capture — sit
under `docs/research` and are indexed like everything else. Both exclusions are checked by the suite, and the
reference footprint is labelled accordingly: it counts surfaces outside this index's own machinery.

## What is not claimed

The separation claim is narrow and exact, and deliberately so: historical evidence is off the path a session
reasons on, measured verb by verb. It is not a claim that nothing current touches history — three named records
are still read by a verb, a suite and a CI default, each listed above against #768, which owns ending them. That
division was the operator's call, taken so this unit keeps its boundary instead of expanding into shipped-runtime
and CI work. No read-count reduction is claimed: the hot path grew by
one Markdown surface, this page, measured above rather than argued away, and the corpus grew by this unit's own
artifacts. A #730 workload re-run would show that one extra open by `doctor` and nothing else. No claim that nothing reads the corpus, either — `doctor`'s link validator reads
every Markdown surface it finds, measured above and left in place deliberately, because it is the check that
keeps this index's pointers valid. What is claimed is machine-checked:
every evidence artifact is classified and reachable through one index row; a shipped surface that starts naming a
non-operative artifact fails `tests/test-evidence-index.sh` until the index lists it as a reader; and the
default-read behaviour of the read-only verbs is a committed, regenerable observation whose every reported
figure the suite recomputes and whose `doctor` rows the suite derives from HEAD's own tree; and the session
path — every read-only verb but the validator — opens no evidence file, which the suite asserts directly. Physical footprint is reported before and after, separately from the
reference footprint and the observed reads, as the issue requires: it grew by this unit's own evidence, and the
table above is the accounting.

## Acceptance, item by item

- **Evidence families classified with retention rationale** — `docs/ops/evidence-index.tsv`, 37 rows, one
  class and one rationale each.
- **Historical material pointable by release/HEAD/work unit/fact** — every historical-retained and
  do-not-delete row names an identity and the fact it supported; the suite checks both.
- **Retained history explicitly non-operative where appropriate** — the `operative-now` column; every
  historical-retained row says `no`.
- **No evidence deleted for LOC or file count** — nothing deleted; the corpus grew by this unit's own
  artifacts, reported before and after against the PR's base commit.
- **Redundant evidence deleted only when disproven and safe** — none qualified; the two identical blobs are
  per-suite inputs by design.
- **Active-reasoning claims supported by observed/default-read behaviour** — an `strace` capture of the
  read-only verbs on a clean checkout (`742-default-reads.tsv`, regenerable by `tools/evidence-reads.sh`),
  every figure recomputed by the suite, `doctor`'s rows derived from HEAD's tree, and the separation claim
  asserted verb by verb. The reference footprint is reported separately and labelled as references, not loads.
- **Physical and hot-path footprints reported separately** — the physical table, the reference table and the
  observed-reads tables above.
- **Current fact/provenance links valid** — nothing moved; the suite checks every reader path exists and
  references its family.
