# TEST-REPRESENTATION BASELINE — issue #737

Worktree: `/home/john/code/spark/.claude/worktrees/baseline-921c982` (read-only; no tests executed; no git run against it — the session sandbox refused, so all evidence is from file reads/greps).

## Method note (assertion counting)

`tests/lib.sh` defines these assertion/scoring helpers: `ok` (L85), `bad` (L86), `assert_rc` (L89), `assert_contains` (L94), `finish` (L102), `assert_flat_contains_all` (L113), `assert_flat_lacks` (L126), `assert_no_constellation_names` (L141). Fixture helpers: `sandbox_init` (L9), `make_repo` (L22), `fixture_clean_dir/empty_git/mature_repo/imported_repo/ambiguous_repo` (L36–82), `gov_iss` (L155), `gate_iss/gate_mil/gate_cap` (L179–209), `mutant_runtime` (L224).

Suites use **five different assertion idioms**, so a single grep undercounts. The `ASRT` column below counts call sites of lib.sh helpers **plus** each suite's own locally-defined assertion wrappers (functions whose body calls `ok`/`bad`/`assert_*`). Four suites use wrappers my parser missed; corrected by hand and flagged. Numbers are approximate (±5%) — the exact count is only knowable at runtime from `finish()`.

---

## A) Mechanical inventory

Legend: `G` = defines its own gh stub/fake; `P` = private `PATH=` shim; `F` = temp git repo / temp project fixture.

| file | LOC | ASRT | G | P | F | issues referenced |
|---|---|---|---|---|---|---|
| test-alpha-intake.sh | 101 | 14 | - | - | F | #322 #332 |
| test-apply-permissions.sh | 117 | 31 | - | P | F | — |
| test-benchmark-vocab.sh | 68 | 7 | - | - | - | #662 #666 #677 |
| test-bounded-runs.sh | 190 | 47 | - | - | F | #1 #558 #574 |
| test-brief-resume.sh | 259 | 45 | G | P | F | #7 #9 #201 #344 #347 #369 #399 |
| test-budget-record-framing.sh | 186 | 20 | - | - | F | #642 |
| test-capability-routing.sh | 205 | 54 | - | - | F | #575 #648 |
| test-changelog-mode.sh | 39 | 3 | - | - | F | #186 |
| test-ci-handoff.sh | 272 | 69 | G | P | F | #574 #636 #658 #703 |
| test-claude-lane.sh | 286 | 50 | - | - | F | #583 #584 #585 #672 |
| test-codify-prereqs.sh | 420 | 71 | G | P | F | #12 #15 #98 #99 #344 #363 #438 |
| test-commit-msg.sh | 168 | 30 | - | P | F | #1 #710 |
| test-context-budget.sh | 57 | 6 | - | - | F | #209 |
| test-course-derivation.sh | 613 | 61 | G | P | F | #469 #594 #602 #605 #700 #800 #900–902 #4242 |
| test-crossroad.sh | 112 | 22 | - | - | - | #480 #584 #677 #688 #690 #691 |
| test-docs-impact-evidence.sh | 480 | 63 | G | P | F | #9 #11 #12 #77 #101 #151 #483 #512 #524 #530 #554 #900 #901 |
| test-docs-impact.sh | 381 | 91 | - | - | F | #483 #4242 |
| test-docs-truth.sh | 200 | 37 | G | P | F | #436 #437 #480 #484 #491 |
| test-doctor-governance.sh | 94 | 17 | - | - | F | #291 #294 |
| test-doctor-requirements.sh | 112 | 22 | G | P | F | — |
| test-doctor-standards-boundary.sh | 62 | 14 | - | - | F | #182 #200 |
| test-doctor-tier-boundary.sh | 127 | 11 | - | - | F | #1 #42 #372 #393 #402 |
| test-e2e-bounded-run.sh | 80 | 10 * | G | P | F | #193 |
| test-eval-lib.sh | 249 | 34 | - | - | F | #304 #306 |
| test-evidence-reuse.sh | 191 | 47 | G | - | F | #576 #647 |
| test-execution-count-race.sh | 226 | 20 | - | - | F | #274 #665 |
| test-existing-implementation.sh | 168 | 32 | G | P | F | #50 #500 #501 #628 #5001 |
| test-first-run.sh | 80 | 25 | - | - | F | #199 |
| test-footprint-budget.sh | 109 | 14 | - | - | F | #292 #361 |
| test-footprint.sh | 99 | 12 | - | P | F | #208 |
| test-governance-contract.sh | 163 | 21 | - | - | F | #470 |
| test-governance-decision.sh | 292 | 25 | - | - | F | #1 #2 #3 #12 #100 #101 #558 #559 |
| test-governance-engine.sh | 295 | 65 | - | - | F | #0–3 #9 #10 #471 #535 #559 |
| test-governance-exclusive.sh | 289 | 36 | - | P | F | #511 |
| test-governance-integration.sh | 182 | 26 | - | P | F | #473 |
| test-governance-provenance.sh | 88 | 6 | - | - | F | #710 |
| test-governance-schema.sh | 473 | 102 | - | - | F | #470 |
| test-governed-pr.sh | 139 | 26 | G | P | F | #710 #711 |
| test-guard-bash.sh | 222 | 102 * | - | - | F | #397 #526 |
| test-hot-path-memo.sh | 528 | 47 | - | P | F | #722 |
| test-hub.sh | 225 | 51 | - | P | F | #375 #385 #393 |
| test-issue-manifest.sh | 254 | 41 | G | P | F | #12 #37 #101 #214 #472 |
| test-knowledge-promotion.sh | 69 | 13 | - | - | - | #376 #377 |
| test-label-family-scope.sh | 237 | 12 | G | P | F | #7 #637 |
| test-labels.sh | 131 | 18 | - | P | F | #396 |
| test-latency.sh | 67 | 13 | G | P | F | #213 #265 #281 #361 |
| test-ledger-truth.sh | 467 | 73 | - | - | F | #470 #501 #507 #514 #515 #545 #546 #549 #567 |
| test-lifecycle-promotion.sh | 84 | 19 | - | - | - | #377 |
| test-member-identity.sh | 339 | 33 | G | P | F | #100 #101 #592 #597 #900–906 |
| test-milestone-gate.sh | 97 | 13 | - | - | F | #194 #196 |
| test-naming.sh | 61 | 4 | - | - | - | #394 |
| test-new-skill.sh | 66 | 11 * | - | - | F | #274 |
| test-next-gate-order.sh | 191 | 11 | - | - | F | #474 #475 #477 #480 #574 #611 |
| test-next-governance-gate.sh | 189 | 13 | G | P | F | #10 #11 #520 |
| test-next-routing.sh | 178 | 21 | - | - | - | #74 #118 #133 #134 #145 #152 #437 |
| test-next-selection.sh | 345 | 37 | G | - | - | #1–6 #10 #20 #23 #25 #27 #31 #40 #52 #61 #80 #100 #436 #488 #611 #622 |
| test-openai-review.sh | 527 | 200 | - | - | F | #1–4 #12 #584 #585 #692 #693 |
| test-orient.sh | 200 | 46 | - | P | F | #183 #242 #398 #400 |
| test-plan-compiler.sh | 445 | 87 | G | P | F | #12 #472 #516 |
| test-plan-order-parents.sh | 162 | 20 | - | - | F | #518 |
| test-plan-update-targets.sh | 129 | 15 | G | P | F | #0 #00 #1 #5 #007 #12 #42 #515 #100000 |
| test-plan-verify-coverage.sh | 539 | 28 | G | P | F | #100 #300 #517 #540 #599 #637 |
| test-pre-commit.sh | 26 | 4 | - | - | F | — |
| test-preferences.sh | 65 | 21 | - | - | F | — |
| test-provenance-leakage.sh | 206 | 20 | - | - | F | #464 #475 #476 #611 |
| test-readme-product-truth.sh | 100 | 13 | - | - | - | #483 #484 #521 |
| test-readonly-mutation.sh | 145 | 29 | - | - | F | #626 |
| test-reconcile-apply.sh | 284 | 46 | G | P | F | #468 #590 #4242 |
| test-reconcile-slate.sh | 220 | 34 | G | P | F | #468 #476 #558 #4242 |
| test-release-gate-role.sh | 478 | 75 | G | P | F | #479 #605 #700 #800–802 #900–902 #910 |
| test-release-notes-carriers.sh | 307 | 35 | - | - | F | #447 #508 |
| test-release-notes-check.sh | 423 | 38 | - | - | F | #9–12 #77 #88 #224 #226 #232 #256 #291 #297 #372 #487 #599 #615 |
| test-release-notes-runner.sh | 340 | 45 | G | P | F | #9 #42 #77 #291 #301–305 #487 #710 #999 |
| test-release-plan-truth.sh | 91 | 16 | - | - | F | #1 #2 #3 #9 #15 #21 #373 #377 #380 |
| test-release-template.sh | 46 | 7 | - | - | F | #357 |
| test-remote-enforcement.sh | 307 | 51 | G | P | F | #359 |
| test-repo-boundary.sh | 187 | 39 | - | - | F | #611 #623 |
| test-roadmap-check.sh | 486 | 32 * | G | P | F | #177 #179 #185 #188 #190–195 #197 #224 #267 #559 #570 #587 #900–902 #999 |
| test-roadmap-headline.sh | 199 | 33 | - | - | F | #1 #478 #479 #521 #541 |
| test-run-telemetry.sh | 245 | 60 | G | P | F | #558 #574 #638 |
| test-runner-projection.sh | 255 | 46 | G | - | F | #558 #609 #648 #664 |
| test-runtime-modules.sh | 259 | 40 | - | - | F | #614 #667 #670 |
| test-setup-profiles.sh | 74 | 25 | - | - | F | — |
| test-setup-provisioning-boundary.sh | 106 | 9 | - | - | F | #473 #535 |
| test-setup.sh | 64 | 20 | - | - | F | #401 |
| test-skill-descriptions.sh | 53 | 10 | - | - | - | #293 #313 |
| test-standards-docs.sh | 80 | 21 | - | - | F | #182 #241 |
| test-state-docs-chronology.sh | 113 | 22 | - | - | F | #475 #476 #477 |
| test-state.sh | 116 | 23 | - | P | F | #210 #264 #347 |
| test-structure-scanner.sh | 111 | 10 | - | - | F | #614 |
| test-triage-truth.sh | 436 | 74 | G | P | F | #1 #2 #7 #12 #22 #467 #468 #558 #564 #571 #4242 #4243 |

`*` = hand-corrected wrapper counts: `test-guard-bash.sh` (`allow` 29 + `deny` 34 + `allow_in` 17 + `deny_in` 22 = 102), `test-roadmap-check.sh` (`check` 24 + `parity` 5 + `mwcheck` 3), `test-new-skill.sh` (`reject`/`accept` 11), `test-e2e-bounded-run.sh` (`check` 10).

**Totals**
- Files: **91** `tests/test-*.sh`
- Total LOC: **19,246** (plus `lib.sh` 254, `run.sh` 182, `bench.sh` 161, `bench-memo.sh` 433, `structure.sh` 163, `e2e-marketplace-install.sh` 141)
- Total assertion call sites: **≈3,110** (parser total 2,957 + 153 hand corrections). Approximate — see method note.
- Files with a private gh stub/fake: **26** create an executable `.../gh` stub on disk; **0** define a `gh()` shell function. (`test-e2e-bounded-run.sh` has `make_stub` for non-gh tools.)
- Files with private temp-repo/fixture bootstrap: **82** of 91 (`F`); of those, **68** call the shared `sandbox_init`, **44** call the shared `make_repo`.
- Files with a private `PATH=` shim: **34**.
- Files that do **not** source `tests/lib.sh` at all: **10** — `test-crossroad.sh`, `test-e2e-bounded-run.sh`, `test-eval-lib.sh`, `test-guard-bash.sh`, `test-issue-manifest.sh`, `test-milestone-gate.sh`, `test-release-notes-check.sh`, `test-release-notes-runner.sh`, `test-roadmap-check.sh`, `test-skill-descriptions.sh`.

---

## B) Repeated fixtures / bootstrap (≥3 suites)

**B1. Byte-identical `assert_eq()` definition — 22 suites. NOT in lib.sh.**
All 22 bodies are byte-for-byte identical (`local desc="$1" want="$2" got="$3"; if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi`). Verified: 22/22 match.
Representatives: `tests/test-docs-impact.sh:20`, `tests/test-governance-schema.sh:23`, `tests/test-ledger-truth.sh:28` (also test-plan-compiler.sh:22, test-triage-truth.sh:25, test-release-gate-role.sh:22, …).
**Shared helper in lib.sh? NO** — lib.sh offers `assert_rc` and `assert_contains` but no equality assert. This is the single largest duplication in the corpus (381 `assert_eq` call sites).

**B2. Byte-identical `ok()`/`bad()` redefinition — 12 suites.**
Identical to `tests/lib.sh:85-86`.
Representatives: `tests/test-crossroad.sh:17-18`, `tests/test-openai-review.sh:14-15`, `tests/test-eval-lib.sh:14-15` (also milestone-gate:14, next-selection:19, next-routing:20, issue-manifest:14, release-notes-{check:14,runner:17,carriers:23}, skill-descriptions:18, next-gate-order:38).
**Shared helper in lib.sh? YES** (`lib.sh:85-86`) — but 10 of these suites do not source lib.sh at all, and 2 shadow it.

**B3. Private PATH-shim directory + `gh` stub + `chmod +x` + `env PATH=…` invocation — 24+ suites.**
Every suite invents its own directory name (`$WORK/bin`, `$WORK/shim`, `$WORK/fakegh`, `$WORK/stub`, `$abin`, `$nxbin`, `$lsbin`, `$qbin`, `$dupbin`, `$WORK/lshim`, `$WORK/dishim`, `$WORK/hshim`, `$WORK/oshim`).
Representatives: `tests/test-remote-enforcement.sh:77-90`, `tests/test-codify-prereqs.sh:123-137`, `tests/test-ci-handoff.sh:25-44` (also brief-resume:82-90, docs-truth:49-62, run-telemetry:29-40, issue-manifest:157-179, plan-verify-coverage:388-408, label-family-scope:151-180, triage-truth:343-359, course-derivation:547-579, member-identity:185-228, governed-pr:92, plan-compiler:414, governance-exclusive:219, orient:186, hub:211, labels:31, apply-permissions:53, docs-impact-evidence:57, existing-implementation:30, hot-path-memo:59, plan-update-targets:106).
**Shared helper in lib.sh? NO.** There is no `make_shim`/`stub_gh`.

**B4. The `gh auth status → exit 0` stub body — ≥6 suites, 21 occurrences.**
Identical `case "$1 $2" in "auth status") exit 0 ;;` line.
Representatives: `tests/test-remote-enforcement.sh:82`, `tests/test-plan-verify-coverage.sh:65`, `tests/test-docs-impact-evidence.sh:65` (also next-governance-gate:48,155; labels:93; governance-exclusive:230; plan-verify-coverage:218,280,326,395,526).
**Shared helper in lib.sh? NO.**

**B5. `sandbox_init` + `make_repo` + `. "$SPARK"` triple — 24 suites source the dispatcher after sandboxing.**
Representatives: `tests/test-governance-schema.sh:10-11`, `tests/test-docs-impact.sh:14`, `tests/test-footprint-budget.sh:12` (also course-derivation:17, existing-implementation:47, member-identity:19, governance-engine:13, doctor-governance:10, label-family-scope:24).
**Shared helper in lib.sh? PARTIAL** — `sandbox_init` (L9) and `make_repo` (L22) are shared; the `. "$SPARK"` source-guard step and its comment are copied per suite.

**B6. GraphQL gate-capture fixtures — already consolidated.** `gate_iss`/`gate_mil`/`gate_cap` (`lib.sh:179-209`) used by 3 suites (course-derivation, member-identity, release-gate-role); `gov_iss` (`lib.sh:155`) used by 5 (member-identity, governance-engine, governance-integration, governance-contract, governance-exclusive). **This is the model the other patterns are not following.**

**B7. `state.json` seeding — only 6 suites; below the duplication threshold in shape.** UNKNOWN whether the 6 bodies are near-identical (not compared line-by-line).

---

## C) Same-invariant candidates

### C1. Governance model resolution (`resolve_governance`) — 10 suites touch it
Files: `test-governance-schema.sh`, `test-governance-contract.sh`, `test-governance-exclusive.sh`, `test-governance-engine.sh`, `test-governance-decision.sh`, `test-governance-integration.sh`, `test-docs-impact.sh`, `test-member-identity.sh`, `test-label-family-scope.sh`, `test-plan-compiler.sh`.
Shared invariant: *the three-tier (shipped → operator → project) governance model resolves deterministically to exactly one row per family fact.*
Overlap evidence: `resolve_governance` is driven at `test-governance-contract.sh:54,77,123,140`, `test-governance-exclusive.sh:47,54,61,83,97,141,181`, `test-governance-schema.sh:305`, `test-governance-engine.sh:24`, `test-governance-decision.sh:34`, `test-governance-integration.sh:70,107`, `test-docs-impact.sh:48,213`, `test-member-identity.sh:86,149`, `test-label-family-scope.sh:30`. Single-exclusive-row assertions appear in **both** `test-governance-contract.sh:141-144` and `test-docs-impact.sh:313-324`.
**Discrimination each adds (the suites document their own boundaries — `test-governance-contract.sh:21-23`):**
- `governance-schema` — record grammar and closure (its own words).
- `governance-exclusive` — exclusivity resolution; 51 `exclusive` references, header L13-14 states measured red-counts per defect.
- `governance-contract` — #470's reopened acceptance contract as a permanent re-audit; explicitly disclaims the other three.
- `governance-engine` — the row *generators* + create/report safety boundary.
- `governance-decision` — the verdict layer's authority boundary and the "a human must decide" outcome (#559).
- `governance-integration` — doctor/next/brief all reading the *same* resolved model.
- `docs-impact` / `member-identity` / `label-family-scope` / `plan-compiler` — consumers; they assert the model reaches *their* consumer, not that it resolves.
**Verdict: overlap is real but each carries distinct discrimination. The redundant slice is narrower than the group: the "two tiers yield ONE exclusive row" assertion is duplicated at `test-governance-contract.sh:141` and `test-docs-impact.sh:324`.**

### C2. Telemetry execution counters — 3 suites
Files: `test-run-telemetry.sh`, `test-execution-count-race.sh`, `test-runner-projection.sh`.
Shared invariant: *`full_suite_runs`/`targeted_checks` reported by telemetry equal the append-only execution log, and a projection is never an execution.*
Overlap evidence: `full_suite_runs` asserted at `test-runner-projection.sh:150,154,161`, `test-execution-count-race.sh:144,170-171,182-183,189-192`; `telemetry show/relay/compare` driven in run-telemetry (19 refs), execution-count-race (9), runner-projection, plus incidentally `test-capability-routing.sh` and `test-runtime-modules.sh`.
**Discrimination:** `runner-projection` = one execution → many projections (#609/#664, incl. `--only` matching zero suites); `execution-count-race` = **concurrency** (two runners overlapping, stale last-write; barrier fixtures at :44,:90-119) — this is the only concurrency control in the corpus; `run-telemetry` = the record is cheap/honest (gh stub logging every call, #574).
**Verdict: overlapping surface, genuinely distinct failure modes. Losing `execution-count-race` loses the only race discrimination.**

### C3. Docs truth / docs impact — 5 suites
Files: `test-docs-truth.sh`, `test-docs-impact.sh`, `test-docs-impact-evidence.sh`, `test-readme-product-truth.sh`, `test-state-docs-chronology.sh`.
Shared invariant: *a release cannot go green while current-state documentation is stale or unassessed.*
Overlap evidence: 17 suites reference `docs-impact`; `test-readme-product-truth.sh:2-9` explicitly names itself a guard for "the v0.22 docs-truth miss" that `test-docs-truth.sh` did not catch.
**Discrimination:** `docs-impact` = grammar + path classification from schema data; `docs-impact-evidence` = the empty-vs-failed evidence distinction (#512) — a lookup failure graded as PASS; `docs-truth` = docs as a *required release gate* (#484); `readme-product-truth` = README positioning specifically (a documented escape from docs-truth); `state-docs-chronology` = duplication of chronology across four docs (#475), an orthogonal property.
**Verdict: layered, not duplicated. `readme-product-truth` exists precisely because `docs-truth` was insufficient.**

### C4. doctor-* suites — 4 suites (+2 budget suites driving `doctor`)
Files: `test-doctor-governance.sh`, `test-doctor-requirements.sh`, `test-doctor-standards-boundary.sh`, `test-doctor-tier-boundary.sh`; overlapping drivers `test-context-budget.sh`, `test-footprint-budget.sh`.
Shared invariant: *`spark doctor` exits non-zero exactly when a check finds a real defect, and never on an optional/absent input.*
Overlap evidence: all six invoke the same binary verb — `test-doctor-standards-boundary.sh:16,32,45,54`, `test-doctor-requirements.sh:43,96,101,104,109`, `test-context-budget.sh:19,44,54`, `test-footprint-budget.sh:101`. `doctor-governance` and `doctor-tier-boundary` instead *source* `$SPARK` and drive the factored `check_*` functions.
**Discrimination:** requirements = capability grouping + core-only exit contract; standards-boundary = `<!-- spark:pref -->` drift (#200); tier-boundary = ship/no-ship document tiers (#372/#393); doctor-governance = reference laziness (#294) + release-component parity (#291); context-budget = per-file SKILL.md budgets (hard error); footprint-budget = total footprint (warn-only after #361).
**Verdict: only the exit-contract assertion is shared. The near-duplicate pair to look at is `test-context-budget.sh` vs `test-footprint-budget.sh` — both budget gates on the same fixture marketplace, differing only in hard-error vs warn.**

### C5. Footprint / budget / latency / memo — 6 suites
Files: `test-footprint.sh`, `test-footprint-budget.sh`, `test-context-budget.sh`, `test-budget-record-framing.sh`, `test-latency.sh`, `test-hot-path-memo.sh`.
Shared invariant: *measured cost (bytes, forks, wall-clock) stays inside a declared, env-overridable budget.*
Overlap evidence: all build a throwaway fixture marketplace and drive env-set budgets (`test-footprint.sh:2-6`, `test-footprint-budget.sh:2-7`, `test-latency.sh:2-5`).
**Discrimination:** footprint = per-surface byte counts + "no jq/python3" claim; footprint-budget = the *advisory* rendering after #361; context-budget = per-file SKILL.md limits; budget-record-framing = a **security** invariant (#642, TSV injection via budget text) — not a cost invariant at all; latency = env-overridden budgets so wall clock never flakes; hot-path-memo = fork counting with a `SPARK_NO_MEMO=1` negative control.
**Verdict: `budget-record-framing` is misgrouped by name only. The rest are distinct measurements sharing a fixture shape (see B3/B5).**

### C6. next-* selection/gating — 4 suites
Files: `test-next-selection.sh`, `test-next-routing.sh`, `test-next-gate-order.sh`, `test-next-governance-gate.sh`.
Shared invariant: *`spark next` must not hand back an actionable route when the governing authority cannot be resolved or the gate order is unknown.*
Overlap evidence: `test-governance-contract.sh:23` states "test-next-selection.sh owns selection". `next-governance-gate` header quotes the exact defect (exit 0 alongside "readiness NOT ASSESSED").
**Discrimination:** selection = which issue; routing = which lane; gate-order = two independent order defects (nested order loss, priority overriding order — #611); governance-gate = the exit-code/authority defect (#520). **UNKNOWN** whether `next-gate-order`'s order assertions are re-asserted inside `test-release-gate-role.sh` (both reference #611/#605 and both use `gate_iss`) — worth a line-level diff.

### C7. release-notes-* — 3 suites
Files: `test-release-notes-carriers.sh`, `test-release-notes-check.sh`, `test-release-notes-runner.sh`.
Shared invariant: *release notes are derived from commit/PR carriers and a note that cannot be derived is reported, not invented.*
**Discrimination: UNKNOWN.** All three are pure-bash, none sources `tests/lib.sh` (carriers does), each redefines `ok`/`bad`, and all three build their own `gitc`/`seed` commit fixtures (`carriers:96-97`, `runner:170-171`). The fixture duplication is certain (B-class); the invariant overlap needs a line-level read I did not do.

---

## D) Negative controls and mutation controls

- Suites containing an explicit negative control (non-zero expected exit, `deny`/`reject`, `assert_flat_lacks`, "must not", mutant, forbidden): **88 of 91**.
- Positive-assertions-only: **3** — `tests/test-e2e-bounded-run.sh`, `tests/test-pre-commit.sh` (26 LOC, 4 assertions), `tests/test-preferences.sh`.
- Suites using the shared **`mutant_runtime`** guard-the-guard helper (`lib.sh:224`): **11** — `test-bounded-runs.sh`, `test-evidence-reuse.sh`, `test-execution-count-race.sh`, `test-existing-implementation.sh`, `test-capability-routing.sh`, `test-next-gate-order.sh`, `test-ci-handoff.sh`, `test-repo-boundary.sh`, `test-label-family-scope.sh`, `test-run-telemetry.sh`, `test-runtime-modules.sh`.
- Suites with private (non-`mutant_runtime`) mutation controls: `test-provenance-leakage.sh:167` (`mutant()` via `sed`), `test-state-docs-chronology.sh:45,54` (`mutate()`, `control()`), `test-docs-truth.sh:195` (`$MUT`).
- Suites mentioning `mutation|guard the guard|control` at all: **39**. Highest density: `test-execution-count-race.sh` (10), `test-hot-path-memo.sh` (10), `test-state-docs-chronology.sh` (10), `test-next-gate-order.sh` (8), `test-readonly-mutation.sh` (8), `test-claude-lane.sh` (8), `test-label-family-scope.sh` (7), `test-repo-boundary.sh` (7).
- Notable: several suites report *measured* discrimination rather than asserting it — `test-governance-exclusive.sh:11-14` ("Of the 39 assertions: restoring the per-member key turns 9 red"), `test-governance-contract.sh:10-14` ("a grep for a function name … is NOT evidence").

---

## E) Subprocess / tool use

- **Real `gh` (network): 0 suites.** Every `gh` occurrence outside a stub heredoc is a string literal fed to a guard (`test-guard-bash.sh:140-172`, `test-repo-boundary.sh:98-118`, `test-milestone-gate.sh:90`), a doc/workflow regex (`test-openai-review.sh:37-516`), or a comment. `test-governance-integration.sh:28` and `test-plan-verify-coverage.sh:526` deliberately build a **gh-free / failing-gh** PATH.
- **Real network: 0 suites.** Only two `curl` mentions exist, both as regexes matched against a workflow file (`test-openai-review.sh:511,519`). The one network-requiring script, `tests/e2e-marketplace-install.sh`, is not a `test-*.sh` and is exercised offline via `SPARK_E2E_LIB_ONLY=1` (`test-e2e-bounded-run.sh:3-5`).
- **`python3`: 23 suites** — apply-permissions, course-derivation, guard-bash, governance-schema, member-identity, plan-verify-coverage, preferences, footprint, hub, claude-lane, doctor-governance, doctor-requirements, labels, governance-integration, roadmap-check, state, reconcile-apply, triage-truth, orient, plan-compiler, reconcile-slate, latency, release-gate-role.
- **`jq`: 32 suites** directly. Heaviest: remote-enforcement (27), plan-verify-coverage (23), course-derivation (15), codify-prereqs (11), state (11), roadmap-check (11), release-gate-role (10). **Indirect jq dependency** via `lib.sh:182,190` (`gate_iss` uses `jq -R`): course-derivation, member-identity, release-gate-role — all three already use jq directly.
- **Pure bash (no jq, no python3, no curl): 53 of 91 suites.**
- **`perl`: 1** — `test-codify-prereqs.sh:329` (fallback for a non-GNU `sed -i`).
- `test-footprint.sh:2-6` asserts as a *property* that the measured code requires neither jq nor python3.
