# Dead-code audit — runtime and support code (v0.23 cleanup)

Owning issue: the "audit and remove dead code and obsolete compatibility paths" child of the v0.23
reasoning-surface cleanup parent (release gate: the v0.23 release-readiness issue). BEFORE evidence: the frozen
repository baseline in `../v0.23-optimization-baseline/repository-baseline.md` (measured system
`921c9820b92e99ef3620f4f46a0a8a6d7bb0c8b5`; runtime unchanged since).

## Method

`tools/deadscan.sh` (committed beside this file) runs read-only against a worktree and, for every function
defined in the runtime and hook code (`plugins/spark/bin/spark`, `plugins/spark/lib/*.sh`,
`plugins/spark/hooks/guard-bash.sh`, `plugins/spark/scripts/hooks/*`), counts whole-word references
(`grep -w`) in three places other than the function's own definition line: the runtime itself, `tests/`, and
everything else (skills, shipped docs, `.github`, companions, dev docs). A function with zero runtime references
is a candidate. Indirect construction (`"${prefix}_get"`, `bg_$…`, `ci_$…`, `route_class_$…`) was searched
separately; none exists for the candidates. Git history (`git log -S`, `git log -G`) was read for each candidate
to establish whether a caller ever existed. The scan also flags obsolete-compatibility markers in runtime code
and shipped scripts referenced nowhere.

Scan coverage: 250 functions; 0 shipped scripts unreferenced. `.github/scripts` and `tests/` are support code
outside this packet's runtime scope; their duplication and obsolescence are owned by the canonicalization and
obsolete-scripts children of the same parent.

## Candidates and classification

| Candidate | Where | Evidence | Class |
|---|---|---|---|
| `bg_dir` | `plugins/spark/lib/execution.sh` (budget domain) | 0 references in runtime, tests or docs; introduced 2026-08-30 by the budget feature and moved by the module extraction; no commit ever referenced it; `bg_file` (used at 1 site) is the helper the code actually calls | **Safe delete** |
| `bg_get` | same | 0 references anywhere, ever; the budget domain reads its records through `bg_load`/`bg_apply_staged`, not this accessor | **Safe delete** |
| `route_class_desc` | `plugins/spark/lib/execution.sh` (routing) | 0 references anywhere, ever; `route_class_rank` (3 call sites) is the sibling the router uses; the description column of a class row is not read by any consumer | **Safe delete** |
| `ci_dir` | `plugins/spark/lib/execution.sh` (CI hand-off) | 0 references anywhere, ever; `ci_file` is the helper in use | **Safe delete** |
| `ci_get` | same | 0 references anywhere, ever; `ci_load` reads the record | **Safe delete** |
| Legacy state keys (`STATE_LEGACY_KEYS`, `is_legacy_key`, the "legacy keys found and ignored" notice, the close-out migration) | `plugins/spark/bin/spark` (state) | A compatibility path for pre-v0.16 `.spark/state.json` files that still carry `stage`/`issue`/`branch`/`pr`; it is referenced (3 sites) and executes; 0 test references; whether any downstream repository still carries such a file is unknowable from this repository | **Needs review** — behavior-bearing compatibility; remove only with evidence that no consumer has an unmigrated file, or after a documented deprecation window |
| `enhancement` deprecated-alias handling and `--prune-deprecated` | `plugins/spark/bin/spark` (labels) | A documented flag of a Stable CLI verb (`spark labels`) that deliberately handles GitHub's default label; referenced and tested | **Do not delete** — public CLI/compatibility behavior |
| `cmd_*`, `fp_hot_*` and other single-reference functions | `plugins/spark/bin/spark` | One runtime reference each because they are dispatched through the `VERBS` table or passed by name (`fp_median3_ms fp_hot_guard`); the reference is the dispatch, not dead code | **Do not delete** |

## What was removed

Five functions, 13 lines, one file: `plugins/spark/lib/execution.sh` 2,195 → 2,182 lines
(99,985 → 99,562 bytes). No public CLI surface, flag, exit code or documented behavior changes; every removed
function was unreachable.

## Verification

- `bash -n` on the changed module; a repository-wide `grep -w` for the five names finds nothing.
- Focused suites (`tests/run.sh --only …`): `budget` (3 suites), `ci-handoff`, `capability-routing`,
  `runtime-modules`, `e2e-bounded-run` — all green.
- `spark doctor`: healthy (0 errors; the 2 pre-existing warnings are unrelated shipped-doc issue references).
- Required final behavioral validation: one full `tests/run.sh --json` run after the removal — 91 suites,
  3,799 assertions passed, 0 failed, 156 s (baseline before: 91 / 3,799 / 0 / 161 s).

## Before / after

| Measure | Before (frozen baseline) | After this packet |
|---|---:|---:|
| Runtime functions (dispatcher + lib + hooks) | 250 | 245 |
| `plugins/spark/lib/execution.sh` lines / bytes | 2,195 / 99,985 | 2,182 / 99,562 |
| Runtime LOC (all runtime buckets) | 12,881 | 12,868 |
| Files changed | — | 1 |
| Full-suite assertions | 3,799 | 3,799 |

The Needs-review item is left in place and recorded here so the parent's final validation can decide it with
evidence rather than by this packet's judgment.
