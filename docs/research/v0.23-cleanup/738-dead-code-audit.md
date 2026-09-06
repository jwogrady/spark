# Dead-code audit — runtime and support code (v0.23 cleanup)

Owning issue: the "audit and remove dead code and obsolete compatibility paths" child of the v0.23
reasoning-surface cleanup parent (release gate: the v0.23 release-readiness issue). BEFORE evidence: the frozen
repository baseline in `../v0.23-optimization-baseline/repository-baseline.md` (measured system
`921c9820b92e99ef3620f4f46a0a8a6d7bb0c8b5`; runtime unchanged since until this packet).

## Method

`tools/deadscan.sh <worktree> <outdir>` (committed beside this file) runs read-only and produces every number
and every per-candidate evidence block below. Surfaces scanned — every function defined with `name() {`:

| Surface | Files | Functions (before → after) |
|---|---|---:|
| runtime | `plugins/spark/bin/spark`, `plugins/spark/lib/*.sh`, `plugins/spark/hooks/*.sh`, `plugins/spark/scripts/hooks/*` | 250 → 242 |
| ci support | `.github/scripts/**/*.sh` (the code the workflows execute) | 64 → 64 |
| shipped skill scripts | `plugins/spark/skills/*/scripts/*`, `plugins/spark-*/skills/*/scripts/*` (support scripts the skills run downstream) | 42 → 42 |
| test harness | `tests/lib.sh` (the shared helpers; a suite's own local functions are the suite's business, owned by the test-consolidation child) | 20 → 20 |

**What a "reference" is.** A reference is a *line* that contains the function name as a whole word
(`grep -w`), is not the function's own definition line, and is not a comment line (first non-blank character
`#`). It is counted in three places: the function's own surface (for ci support, also
`.github/workflows/*.yml`), `tests/`, and every other tracked text file *except* this audit's own artifacts
under `docs/research/v0.23-cleanup/`, which list every function name and would otherwise give every function an
artificial reference. A name inside a string or heredoc still counts, so the count is an **upper bound on real
call sites** — it errs toward keeping code. A function is a candidate only when all three counts are zero:
nothing anywhere mentions it outside its definition and comments. (An earlier revision of this scan counted
files rather than lines and did not strip comment lines or exclude the audit; the stricter method surfaced three
further candidates in `bin/spark` that comment mentions had hidden, recorded below.)

For each candidate the scan then records mechanically:

- an **indirect** search over every tracked file for the name reached through prefix construction
  (`"${x}_get"`, `bg_$…`) or as a quoted string — so a call built at run time cannot hide;
- **git history**: `git log -S<name>` (commits that added or removed the string), `git log -G<name>` (every
  commit whose diff mentions it), and — because those lists alone do not show whether a revision *called* the
  function — a `git grep -w` of the whole tree **at each of those revisions**, with definition and comment lines
  removed. "No revision ever called it" below is that per-revision count, not an inference from commit lists.

It also lists obsolete-compatibility markers (legacy, deprecated, compat, "no longer …", "since v0.x") in
the runtime and ci surfaces, and shipped or ci scripts that nothing references.

Results of both runs are committed: `738-deadscan-before.txt` (the frozen tree: candidates with their
indirect and history evidence), `738-functions-before.tsv` and `738-functions-after.tsv` (every function with its
three reference counts, before and after the removal).

## Findings

**Runtime.** Eight functions had zero references in every surface. Five in `lib/execution.sh`: the indirect
search finds no constructed or quoted use — the `${x}_dir` hits the scan prints for `bg_dir`/`ci_dir` are shell
*variables* named `tmpl_dir`, `docs_dir`, `log_dir`, `memo_dir`, not function names, and no variable ever holds
`bg` or `ci` as a prefix — and the per-revision search shows 0 reference lines at both commits that ever
mentioned them (the feature that introduced each on 2026-08-30 and the module extraction the same day). Three
in `bin/spark` that only comment lines mentioned: `ms_open_count_of` and `leaves_of` (introduced 2026-08-29 by
`4baea20`, 0 reference lines at that revision — written but never wired in) and `fp_over_budget` (introduced
2026-07-21 by `e335532` with 6 call sites, all removed the same day by `ef1a204`, 0 reference lines since).

**CI support (`.github/scripts`).** 64 functions, all referenced from their own scripts or from a workflow.
No zero-reference candidate. No obsolete-compatibility marker in this surface. No script unreferenced.
Nothing to remove; nothing needs review.

**Shipped skill scripts.** 42 functions across the core and companion skill scripts, all referenced from their
own script, a sibling script, a `SKILL.md` or a test. No zero-reference candidate; no compatibility marker; every
script file is itself referenced.

**Test harness (`tests/lib.sh`).** 20 helpers, all referenced by at least one suite or by the runner. No
candidate. (Whether several suites re-implement helpers the harness already offers is the test-consolidation
child's question, not dead code.)

## Candidates and classification

| Candidate | Where | Evidence | Class |
|---|---|---|---|
| `bg_dir` | `plugins/spark/lib/execution.sh` (budget domain) | 0 references in runtime, tests or docs; no indirect construction; introduced by the budget feature (`22a9f75`), moved by the module extraction (`d86e78d`); no other commit ever mentions it; `bg_file` (1 call site) is the helper the code uses | **Safe delete** |
| `bg_get` | same | 0 references anywhere, ever (`22a9f75`, `d86e78d` only); the budget domain reads its records through `bg_apply_staged`, not this accessor | **Safe delete** |
| `route_class_desc` | `plugins/spark/lib/execution.sh` (routing) | 0 references anywhere, ever (`0b84a82`, `d86e78d` only); `route_class_rank` (3 call sites) is the sibling the router uses; no consumer reads the description column | **Safe delete** |
| `ci_dir` | `plugins/spark/lib/execution.sh` (CI hand-off) | 0 references anywhere, ever (`96702b4`, `d86e78d` only); `ci_file` is the helper in use | **Safe delete** |
| `ci_get` | same | 0 references anywhere, ever (`96702b4`, `d86e78d` only); `ci_load` reads the record | **Safe delete** |
| `ms_open_count_of` | `plugins/spark/bin/spark` (milestone snapshot) | 0 non-comment references; introduced by `4baea20` (2026-08-29) with 0 reference lines at that revision; the snapshot's consumers read `ms` rows through `milestone_snapshot`'s own awk, not this accessor | **Safe delete** |
| `leaves_of` | same | 0 non-comment references; introduced by `4baea20` with 0 reference lines at that revision; `containers_of`, the sibling defined next to it, is the one the leaf/container rule calls | **Safe delete** |
| `fp_over_budget` | `plugins/spark/bin/spark` (latency) | 0 non-comment references; 6 call sites at introduction (`e335532`, 2026-07-21) removed the same day by `ef1a204`, 0 since; `fp_latency` compares inline; `tests/test-latency.sh` does not reference it | **Safe delete** |
| Legacy state keys (`STATE_LEGACY_KEYS`, `is_legacy_key`, the "legacy keys found and ignored" notice, the close-out migration) | `plugins/spark/bin/spark` (state) | A compatibility path for pre-v0.16 `.spark/state.json` files that still carry `stage`/`issue`/`branch`/`pr`; referenced at 3 sites and executes; 0 test references; whether any downstream repository still carries such a file is unknowable from this repository | **Needs review** — behavior-bearing compatibility; remove only with evidence that no consumer has an unmigrated file, or after a documented deprecation window |
| `enhancement` deprecated-alias handling and `--prune-deprecated` | `plugins/spark/bin/spark` (labels) | A documented flag of a Stable CLI verb (`spark labels`) that deliberately handles GitHub's default label; referenced and tested | **Do not delete** — public CLI/compatibility behavior |
| `cmd_*`, `fp_hot_*` and other single-reference runtime functions | `plugins/spark/bin/spark` | One reference each because they are dispatched through the `VERBS` table or passed by name (`fp_median3_ms fp_hot_guard`); the reference is the dispatch, not dead code | **Do not delete** |

## What was removed

Eight functions, 29 lines, two files: `plugins/spark/lib/execution.sh` 2,195 → 2,182 lines
(99,985 → 99,562 bytes) and `plugins/spark/bin/spark` 8,881 → 8,865 lines (419,187 → 418,450 bytes). No public
CLI surface, flag, exit code or documented behavior changes; every removed function was unreachable at every
revision that mentioned it (or, for `fp_over_budget`, at every revision since its callers were removed).

## Verification

- `bash -n` on both changed files; a repository-wide `grep -w` for the eight names finds nothing; the
  after-scan finds zero candidates in all four surfaces (368 functions).
- Focused suites (`tests/run.sh --only …`): `budget` (3 suites), `ci-handoff`, `capability-routing`,
  `runtime-modules`, `e2e-bounded-run` after the first removal; `next-selection`, `next-gate-order`,
  `milestone-gate`, `latency`, `footprint` (2 suites), `runtime-modules` after the second — all green.
- `spark doctor`: 0 errors on every HEAD of this change. Its *warning* count depends on the environment it
  runs in, so a bare number is not evidence; the verified outputs are: locally (authenticated `gh`, hooks
  installed) `Healthy — 0 errors, 2 warning(s)` — the shipped-footprint budget and the shipped-doc issue
  references, both pre-existing; the `doctor` required-check job for `bd7d00b` logged
  `Healthy — 0 errors, 4 warning(s)` — those two plus `remote governance NOT ASSESSED — labels live on GitHub
  and need an authenticated gh` and `Spark git hooks not installed here`; the independent reviewer's own run
  reported three. None of the warnings names a file or behavior this change touches. The `doctor` and `tests`
  required checks on the PR's exact HEAD are the authority for that HEAD.
- Required final behavioral validation: one full `tests/run.sh --json` run after each removal — 91 suites,
  3,799 assertions passed, 0 failed (156 s, then 155 s; baseline before: 91 / 3,799 / 0 / 161 s). The `tests`
  and `doctor` required checks on the PR's exact HEAD re-execute this on every HEAD.

## Before / after

| Measure | Before (frozen baseline) | After this packet |
|---|---:|---:|
| Functions scanned (runtime + ci support + skill scripts + test harness) | 376 | 368 |
| Runtime functions | 250 | 242 |
| Zero-reference candidates (corrected method) | 8 | 0 |
| `plugins/spark/lib/execution.sh` lines / bytes | 2,195 / 99,985 | 2,182 / 99,562 |
| `plugins/spark/bin/spark` lines / bytes | 8,881 / 419,187 | 8,865 / 418,450 |
| Runtime LOC (all runtime buckets) | 12,881 | 12,852 |
| Files changed | — | 2 |
| Full-suite assertions | 3,799 | 3,799 |

The Needs-review item is left in place and recorded here so the parent's final validation can decide it with
evidence rather than by this packet's judgment. With the four scanned surfaces clean and the one
behavior-bearing compatibility path deliberately kept, the audit covers every runtime and support-code surface
the repository ships or executes: the dispatcher and modules, the hooks, the CI scripts, the skill scripts and
the shared test harness.
