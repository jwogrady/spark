# Test consolidation by invariant — proof-preservation manifest (v0.23 cleanup)

**Baseline (BEFORE).** The #737 test-representation inventory
(`../v0.23-optimization-baseline/raw/agent-test-representation.md`) is the authority for
what the corpus looked like before any cleanup: 91 suites, 19,246 LOC, ≈3,110 assertion
call sites (static count), 26 private `gh` stubs, 34 private `PATH=` shims, 11 suites not
sourcing `tests/lib.sh`, and the repeated-fixture findings B1–B7. The measured figures
below extend that inventory reproducibly: a full `tests/run.sh` at the packet's base and
at its HEAD, with every suite's own `N passed, M failed` line captured, so the runtime
assertion count per suite is compared exactly rather than estimated.

Each packet below is one bounded change with its own BEFORE/AFTER and its own mapping.
The rule for every packet: **no assertion or discriminating case is dropped silently** —
either the per-suite counts are identical, or a removed case is listed with its surviving
proof.

---

## Packet 1 — the shared assertion harness (baseline findings B1, B2)

**What the baseline found.** B1: a byte-identical `assert_eq()` in 22 suites (23 after
#739's suite landed), absent from `tests/lib.sh`. B2: byte-identical `ok()`/`bad()` in 12
suites — 8 of which never sourced `tests/lib.sh` and re-implemented the summary tail by
hand, 4 of which sourced it and shadowed the helpers.

**What changed.** `tests/lib.sh` gains the one `assert_eq` (same body, same message). The 23
local copies are deleted. The 12 `ok`/`bad` redefinitions are deleted; the 8 suites that
never sourced the shared lib now do, and their hand-copied two-line tail
(`echo "  $pass passed, $fail failed"; [ "$fail" -eq 0 ]`) becomes the shared `finish`,
which prints the identical line and returns the identical status. No assertion, fixture,
stub or expectation was touched.

| Existing test/case | Invariant proved | Surviving test/case | Same/stronger discrimination? | Validation |
|---|---|---|---|---|
| local `assert_eq()` in 23 suites (body md5 `d11048d5`) | exact-equality assertion with `want`/`got` in the failure message | `tests/lib.sh` `assert_eq` (same body) | **Same** — identical body, identical message, so failure localization is unchanged | per-suite `N passed, M failed` identical before/after for all 92 suites (table below) |
| local `ok()`/`bad()` in 12 suites | pass/fail tally and the `✖` line | `tests/lib.sh:85-86` | **Same** — byte-identical bodies | as above |
| hand-copied summary tail in 11 suites | the runner's parsed `  N passed, M failed` line and non-zero exit on any failure | `tests/lib.sh` `finish` | **Same** — same line, same `[ "$fail" -eq 0 ]` status | `tests/run.sh` parses the same line; full run 92/92 green |

No test case was removed, so the "removed behaviour under an approved contract" column
is empty by construction.

**Before / after (this packet).**

| | BEFORE (branch base `c0ef567`) | AFTER |
|---|---|---|
| test files | 92 | 92 |
| test LOC (`tests/test-*.sh`) | 19,476 | 19,341 (−135) |
| `tests/lib.sh` LOC | 254 | 261 (+7) |
| private `assert_eq` definitions | 23 | 0 |
| private `ok`/`bad` definitions | 12 | 0 |
| suites not sourcing `tests/lib.sh` | 10 | 3 (`test-e2e-bounded-run.sh`, `test-guard-bash.sh`, `test-roadmap-check.sh` — each has its own domain idiom (`check`, `allow`/`deny`) rather than a copy of the shared one; left for a later packet if their idioms are worth sharing) |
| assertions, full run | 3,908 passed / 0 failed | 3,908 passed / 0 failed |
| per-suite pass/fail lines | 92 | 92, **all identical** |
| full-suite wall clock | 159 s | 162 s (noise; the change adds one `source` per suite and removes nothing that executes) |
| suites changed | — | 34 (22 assert_eq only; 1 both; 8 ok/bad + now sourcing lib; 3 ok/bad + tail) |

Subprocess/tool counts for the suites are not mechanically available from `tests/run.sh`
(`tests/bench.sh` measures the runtime hot path, not the suites); the wall clock is the
comparable figure and it did not move outside noise.

### Per-suite assertion counts at the packet HEAD (identical to the base — `diff` empty)

| suite | passed | failed |
|---|---|---|
| `test-alpha-intake.sh` | 20 | 0 |
| `test-apply-permissions.sh` | 32 | 0 |
| `test-benchmark-vocab.sh` | 9 | 0 |
| `test-bounded-runs.sh` | 46 | 0 |
| `test-brief-resume.sh` | 53 | 0 |
| `test-budget-record-framing.sh` | 27 | 0 |
| `test-canonical-primitives.sh` | 100 | 0 |
| `test-capability-routing.sh` | 80 | 0 |
| `test-changelog-mode.sh` | 4 | 0 |
| `test-ci-handoff.sh` | 74 | 0 |
| `test-claude-lane.sh` | 72 | 0 |
| `test-codify-prereqs.sh` | 77 | 0 |
| `test-commit-msg.sh` | 35 | 0 |
| `test-context-budget.sh` | 6 | 0 |
| `test-course-derivation.sh` | 92 | 0 |
| `test-crossroad.sh` | 27 | 0 |
| `test-docs-impact-evidence.sh` | 66 | 0 |
| `test-docs-impact.sh` | 100 | 0 |
| `test-docs-truth.sh` | 39 | 0 |
| `test-doctor-governance.sh` | 17 | 0 |
| `test-doctor-requirements.sh` | 22 | 0 |
| `test-doctor-standards-boundary.sh` | 15 | 0 |
| `test-doctor-tier-boundary.sh` | 22 | 0 |
| `test-e2e-bounded-run.sh` | 11 | 0 |
| `test-eval-lib.sh` | 37 | 0 |
| `test-evidence-reuse.sh` | 51 | 0 |
| `test-execution-count-race.sh` | 24 | 0 |
| `test-existing-implementation.sh` | 38 | 0 |
| `test-first-run.sh` | 26 | 0 |
| `test-footprint-budget.sh` | 15 | 0 |
| `test-footprint.sh` | 13 | 0 |
| `test-governance-contract.sh` | 21 | 0 |
| `test-governance-decision.sh` | 35 | 0 |
| `test-governance-engine.sh` | 86 | 0 |
| `test-governance-exclusive.sh` | 39 | 0 |
| `test-governance-integration.sh` | 29 | 0 |
| `test-governance-provenance.sh` | 10 | 0 |
| `test-governance-schema.sh` | 124 | 0 |
| `test-governed-pr.sh` | 34 | 0 |
| `test-guard-bash.sh` | 102 | 0 |
| `test-hot-path-memo.sh` | 60 | 0 |
| `test-hub.sh` | 205 | 0 |
| `test-issue-manifest.sh` | 50 | 0 |
| `test-knowledge-promotion.sh` | 13 | 0 |
| `test-label-family-scope.sh` | 23 | 0 |
| `test-labels.sh` | 21 | 0 |
| `test-latency.sh` | 14 | 0 |
| `test-ledger-truth.sh` | 74 | 0 |
| `test-lifecycle-promotion.sh` | 25 | 0 |
| `test-member-identity.sh` | 39 | 0 |
| `test-milestone-gate.sh` | 16 | 0 |
| `test-naming.sh` | 4 | 0 |
| `test-new-skill.sh` | 22 | 0 |
| `test-next-gate-order.sh` | 17 | 0 |
| `test-next-governance-gate.sh` | 18 | 0 |
| `test-next-routing.sh` | 24 | 0 |
| `test-next-selection.sh` | 35 | 0 |
| `test-openai-review.sh` | 208 | 0 |
| `test-orient.sh` | 50 | 0 |
| `test-plan-compiler.sh` | 110 | 0 |
| `test-plan-order-parents.sh` | 20 | 0 |
| `test-plan-update-targets.sh` | 40 | 0 |
| `test-plan-verify-coverage.sh` | 82 | 0 |
| `test-pre-commit.sh` | 4 | 0 |
| `test-preferences.sh` | 22 | 0 |
| `test-provenance-leakage.sh` | 19 | 0 |
| `test-readme-product-truth.sh` | 12 | 0 |
| `test-readonly-mutation.sh` | 35 | 0 |
| `test-reconcile-apply.sh` | 50 | 0 |
| `test-reconcile-slate.sh` | 37 | 0 |
| `test-release-gate-role.sh` | 74 | 0 |
| `test-release-notes-carriers.sh` | 36 | 0 |
| `test-release-notes-check.sh` | 44 | 0 |
| `test-release-notes-runner.sh` | 54 | 0 |
| `test-release-plan-truth.sh` | 15 | 0 |
| `test-release-template.sh` | 8 | 0 |
| `test-remote-enforcement.sh` | 54 | 0 |
| `test-repo-boundary.sh` | 41 | 0 |
| `test-roadmap-check.sh` | 43 | 0 |
| `test-roadmap-headline.sh` | 34 | 0 |
| `test-run-telemetry.sh` | 59 | 0 |
| `test-runner-projection.sh` | 81 | 0 |
| `test-runtime-modules.sh` | 53 | 0 |
| `test-setup-profiles.sh` | 25 | 0 |
| `test-setup-provisioning-boundary.sh` | 13 | 0 |
| `test-setup.sh` | 20 | 0 |
| `test-skill-descriptions.sh` | 9 | 0 |
| `test-standards-docs.sh` | 26 | 0 |
| `test-state-docs-chronology.sh` | 19 | 0 |
| `test-state.sh` | 25 | 0 |
| `test-structure-scanner.sh` | 15 | 0 |
| `test-triage-truth.sh` | 81 | 0 |

---

## Packet 2 — wrong-layer `gh` stubs (contract: "mocks that assume production transport/parser output")

**What was wrong.** Two suites answered `gh api … --jq <program>` with rows already shaped
the way *one* caller's jq shapes them (`printf '100\topen\tacme/widgets'`), so the
production jq programs — the milestone list, the sub-issue list, the shared blocked-by
reader, the identity read — were never executed by those suites: a stub that prints
pre-shaped rows agrees with any jq, including a broken one. #739 had already corrected
three such stubs that answered with a pre-shaped count `0`.

**What changed.** `tests/lib.sh` gains `gh_stub_prelude`, the lines a `gh` stub begins with:
it parses the caller's `--jq` and defines `answer_json <json>`, which applies that jq
exactly as gh would. `tests/test-plan-verify-coverage.sh`'s `api` branch and the recording
stub in `tests/test-canonical-primitives.sh` now answer with the JSON GitHub returns
(milestones with `title`/`description`, sub-issues as `{number}` objects, blockers as
`{number, state, repository.full_name}`, the identity as `{nameWithOwner}`, the open-issue
list with `milestone`, `labels` and `issue_dependencies_summary`), shaped by the binary's
own jq. The canonical-primitives suite builds its fixtures through four small helpers
(`bl`, `si`, `nwo`, `iss`) so each scenario states what GitHub said, not what a reader
would print. Two scenarios that no jq program can produce — a row with too few or too
many columns, a transport fault — are still fed raw, and the stub says so (`.raw`).

| Existing test/case | Invariant proved | Surviving test/case | Same/stronger discrimination? | Validation |
|---|---|---|---|---|
| plan-verify `api` stub rows (milestones, sub-issues, blocked-by, identity), 9 scenarios | verify's milestone, hierarchy, dependency and order checks over each scenario | the same 9 scenarios answered as JSON through the binary's jq | **Stronger** — the production jq programs (`.[] \| "\(.title)\t\(.description // "")"`, `.[].number`, the blocked-by row jq, `.nameWithOwner`) now execute on every call; a jq regression would fail here | suite 82/0 unchanged; per-suite counts identical |
| canonical-primitives recording stub, 26 scenarios | the three primitives' contracts and the consumers' filters | the same scenarios as JSON fixtures via `bl`/`si`/`nwo`/`iss`; two transport-fault rows kept raw and labelled | **Stronger** for every JSON scenario (the reader's jq and the `// ""` defaults are exercised; malformed values arrive as GitHub's JSON would carry them); **same** for the two raw rows | suite 100/0 unchanged; per-suite counts identical |

**Before / after (this packet).**

| | BEFORE (branch base `89d0e33`) | AFTER |
|---|---|---|
| stubs answering `gh api --jq` with pre-shaped rows | 2 suites (plan-verify-coverage, canonical-primitives) | 0 — plus 2 labelled raw transport-fault rows in canonical-primitives |
| production jq programs exercised by those suites | 0 | 5 (milestones, sub-issues, blocked-by reader, identity, open-issue list) |
| shared stub scaffolding in `lib.sh` | none | `gh_stub_prelude` (used by 2 suites; packet 3 adopts it elsewhere) |
| assertions, full run | 3,908 / 0 | 3,908 / 0 |
| per-suite pass/fail lines | 92 | 92, **all identical** |
| full-suite wall clock | 161 s | 161 s |
| files changed | — | 3 (`tests/lib.sh`, the two suites) |

**Still pre-shaped, deferred to packet 3.** `tests/test-codify-prereqs.sh` carries ten
inline `gh` stubs answering `api repos/{owner}/{repo} --jq .full_name`, the blocked-by
endpoint (`12\thttps://api.github.com/repos/o/self`, the skill script's own jq shape) and
GraphQL closing-reference queries; converting them is the scaffolding packet's job, since
it means adopting `gh_stub_prelude` across ten stubs in one suite.

---

## Remaining scope (later packets, in order; packets 1 and 2 above are done)

1. **Repeated `gh` stub scaffolding** (baseline B3/B4): 24+ suites each invent a shim
   directory, write a stub, `chmod +x`, prepend `PATH`; `test-codify-prereqs.sh` alone
   carries ten inline stubs with pre-shaped answers (`api repos/{owner}/{repo} --jq
   .full_name`, the blocked-by endpoint in the skill script's own jq shape, GraphQL
   closing-reference queries). `gh_stub_prelude` (packet 2) is the first shared piece; a
   `shim_init`/`stub_gh` pair would remove the rest of the scaffolding while leaving each
   stub's *answers* in the suite that owns them, and converting the codify-prereqs stubs
   rides the same change. Discrimination is unaffected by construction; the risk is in
   PATH ordering, so it is its own packet with its own per-suite proof.
2. **Same-invariant candidates** (baseline C1–C7). The baseline's own verdicts stand:
   most groups are layered, not duplicated. The two worth a line-level read are
   `test-context-budget.sh` vs `test-footprint-budget.sh` (C4: same fixture marketplace,
   hard-error vs warn — but different functions under test) and the three
   `release-notes-*` suites' private `gitc`/`seed` fixtures (C7). Neither is touched until
   its invariant overlap is read line by line; the non-goal "merging unrelated invariants
   into a giant script" governs.
