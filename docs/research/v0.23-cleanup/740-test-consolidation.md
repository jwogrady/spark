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

---

## Packet 3 — the `gh` stub scaffolding and the codify-prereqs stubs (baseline B3/B4)

**What was wrong.** Every suite that fakes `gh` restated the same scaffolding — write a
file, start it with a shebang, `chmod +x`, prepend a shim directory to `PATH` — and
`tests/test-codify-prereqs.sh` carried ten such stubs whose answers were pre-shaped the way
the codify preflight's own jq shapes them (`o/self` for `--jq .full_name`,
`12\thttps://api.github.com/repos/o/self` for the blocked-by row jq, bare `CLOSED` for
`--jq .state`, bare merge-commit ids for the GraphQL closing-reference jq), so none of the
skill script's jq programs ran under test.

**What changed.** `tests/lib.sh` gains `stub_gh <path>`: shebang, `gh_stub_prelude`, the
suite's case-body from stdin, `chmod +x`, in one call. The two packet-2 suites adopt it.
All eleven codify-prereqs stubs (`mk_gh` plus ten inline) are written through it and every pre-shaped answer becomes
the JSON GitHub returns, shaped by the preflight's own jq: the repository node
(`{"full_name": …}`), blocker rows (`{"number", "repository_url"}`, an unknown owner as an
absent field, "no blockers" as `[]`), issue bodies and states as `{"body"}`/`{"state"}`,
and the GraphQL closing-reference payload with `merged` and `mergeCommit.oid` nodes — the
multi-PR scenario now carries two merged nodes, the "no merged PR" scenario an empty node
list. The one remaining `printf` is a sentinel that must never be reached. No scenario,
assertion or expected exit code changes.

**Defect found and fixed while doing this.** The first cut of this packet wrote two heredoc
openers with literal backslashes (`<<\'STUB\'`), so those suites never terminated their
heredoc, ran zero assertions and exited 0 — and `tests/run.sh` counted them as passed:
the full run reported 3,726 assertions with every suite "green". The runner now fails any
suite that prints no `N passed, M failed` line (silence is not evidence), the heredocs are
terminated, and the per-suite proof below is the strict one: the chain refuses to ship on
any difference.

| Existing test/case | Invariant proved | Surviving test/case | Same/stronger discrimination? | Validation |
|---|---|---|---|---|
| eleven codify-prereqs stubs (`mk_gh` plus ten inline) with pre-shaped answers | the preflight's READY / BLOCKED / NOT ASSESSED verdicts across 15 end-to-end scenarios | the same eleven stubs written with `stub_gh`, answering GitHub's JSON through the skill script's own jq | **Stronger** — `.full_name`, the blocked-by row jq (`.number`, `.repository_url // ""`), `.body`, `.state` and the closing-reference jq (`select(.merged) \| .mergeCommit.oid // empty`) now execute on every scenario; a jq regression in the preflight fails here | suite assertions unchanged; per-suite counts identical |
| scaffolding in the two packet-2 suites | — | `stub_gh` | **Same** by construction | per-suite counts identical |

**Before / after (this packet).**

| | BEFORE (branch base `dcda139`) | AFTER |
|---|---|---|
| suites with pre-shaped `gh` answers assuming a caller's jq | 1 (`test-codify-prereqs.sh`, eleven stubs: `mk_gh` plus ten inline) | 0 |
| production jq programs newly exercised | — | 5 (`.full_name`, blocked-by row, `.body`, `.state`, closing references) |
| stubs written through `stub_gh` | 0 | 13 (eleven in codify-prereqs — `mk_gh` plus ten inline — and one each in the packet-2 suites) |
| `chmod +x`/shebang restatements removed | — | 13 |
| suites the runner would pass while printing no summary line | any (a silent suite counted as passed) | 0 — `tests/run.sh` now fails a suite with no `N passed, M failed` line |
| assertions, full run | 3908 passed, 0 failed | 3908 passed, 0 failed |
| per-suite pass/fail lines | 92 | 92, **all identical** |
| full-suite wall clock | 160s | 166s |

The remaining ~24 suites with their own shim scaffolding (baseline B3) keep it for now: their
stub *bodies* are not pre-shaped in the same way, so adopting `stub_gh` there is a mechanical
sweep with no discrimination change — packet 4 below, so its per-suite proof stands alone.

---

## Packet 4 — the `stub_gh` sweep (baseline B3)

**What changed.** Every remaining hand-written `gh` stub — 36 heredoc/shebang openers in 15
suites, 24 of which were followed by their own `chmod +x` (the other 12 reused a directory
whose file was already executable) — is now written through `stub_gh`: the
`cat > "$dir/gh" <<TAG` + shebang opener becomes `stub_gh "$dir/gh" <<TAG`, and each
per-stub `chmod +x` is gone. Stub
*bodies* are untouched: this sweep is scaffolding only, so the answers each suite gives
stay exactly where they were and mean exactly what they meant. Every stub now also carries
the prelude (`GH_JQ`, `answer_json`), which a later change can use to answer with JSON
where a body still pre-shapes rows; none of the swept bodies does so in the packet-3
sense (they answer GraphQL snapshots through the caller's jq already, or plain text for
`gh issue view --json … --jq` reads).

| Existing test/case | Invariant proved | Surviving test/case | Same/stronger discrimination? | Validation |
|---|---|---|---|---|
| 36 hand-written stubs (heredoc + shebang openers, 24 with a per-stub chmod) in 15 suites | each suite's own scenarios | the same 36 stubs via `stub_gh`, bodies unchanged | **Same** by construction — bodies identical, PATH ordering unchanged | per-suite pass/fail lines identical (92/92); the runner's silent-suite guard (packet 3) would fail any stub whose heredoc did not terminate |

**Before / after (this packet).**

| | BEFORE (branch base `a504e2c`) | AFTER |
|---|---|---|
| hand-written `gh` stubs (`cat > … <<TAG` + shebang openers; 24 with a per-stub chmod) | 36 in 15 suites | 0 |
| stubs written through `stub_gh` | 13 | 49 (13 + 36) |
| scaffolding lines removed (shebang + `chmod +x`) | — | 60 (36 shebang lines, 24 chmod lines; the remaining converted stubs reused a directory whose file was already executable) |
| test LOC (`tests/test-*.sh`) | 19,363 | 19,303 |
| assertions, full run | 3908 passed, 0 failed | 3908 passed, 0 failed |
| per-suite pass/fail lines | 92 | 92, **all identical** |
| full-suite wall clock | 162s | 163s |

## Final overlap assessment

The remaining candidates were inspected at `a2d0ef9`. No additional regression
is removed or consolidated: their shared names do not establish shared proof.

| Candidate | Distinct proof and fixture | Disposition |
|---|---|---|
| `test-context-budget.sh` / `test-footprint-budget.sh` (C4) | The former drives doctor against oversized/missing individual skills and requires a hard failure. The latter drives byte summation and cache-stability helpers against a two-plugin marketplace, then checks that doctor renders a total-footprint breach as a warning. | Keep both suites and all cases. A common budget wrapper would obscure different inputs and exit contracts. |
| `test-release-notes-check.sh` (C7) | Feeds commit TSV and notes text to the completeness checker; no Git repository, `gitc`, or `seed` fixture. | Keep the pure decision suite. The baseline statement that all three suites have Git fixtures is incorrect. |
| `test-release-notes-carriers.sh` / `test-release-notes-runner.sh` (C7) | Carriers requires dated commits and a branched/tagged history to prove carrier reachability, ambiguity and cycles. Runner requires component paths/tags and label mappings to prove per-component collection and result aggregation; its `seed` takes no date. | Keep the two small local fixture helpers. Sharing them would need new parameters for different histories without consolidating a behavioral invariant. |
| Dispatcher setup (B5) | `sandbox_init` and `make_repo` already share setup. Explicit `. "$SPARK"` selects tests of sourced functions rather than CLI dispatch. | Keep the explicit source operation; no new wrapper. |
| Gate fixtures (B6) | `gate_iss`, `gate_mil`, `gate_cap` and `gov_iss` are already shared. | Keep existing helpers. |
| Authentication answers (B4) | Some stubs require authenticated access; `test-remote-enforcement.sh` also deliberately returns authentication failure. | Keep answers in the case bodies; the shared writer must not silently grant authentication. |

This completes the selected overlap assessment. B7's state-seeding similarity
was not established by the baseline; no state fixture was removed or counted
as a saving. No claim is made that every superficially similar line in the
repository should be consolidated.

## Combined measurements and acceptance

The frozen inventory and the start of this issue are different baselines.
Between `921c982` and packet 1's base `c0ef567`, runtime canonicalization added
`test-canonical-primitives.sh` and changed other tests. Those additions must
not be attributed to this consolidation, or hidden by comparing unequal work.

| Metric | Frozen inventory `921c982` | Issue start `c0ef567` | Landed packets 1–4 `a2d0ef9` |
|---|---|---|---|
| Test suites | 91 | 92 | 92 |
| Suite lines (`tests/test-*.sh`) | 19,246 | 19,476 | 19,303 |
| Shared library lines | 254 | 254 | 284 |
| Runner lines | 182 | 182 | 189 |
| All text lines under `tests/` | 20,580 | 20,810 | 20,674 |
| Private `assert_eq` definitions | 22 | 23 | 0 |
| Calls to shared `stub_gh` | 0 | 0 | 49 |

Reproduce the line counts from each committed tree with `git archive <commit>
 tests` (on one command line), counting newline bytes in regular files; suite
selection is `tests/test-*.sh`. Count private definitions anchored at
`^assert_eq\(\)` and helper calls anchored at `^[[:space:]]*stub_gh `.
These are static representation measurements, not model-token measurements.

Across this issue, suite representation fell by 173 lines; including the shared
library and runner, the `tests/` reduction is **136 lines**. Relative to the
older frozen inventory, `tests/` instead grew by 94 lines because the intervening
runtime work added proof. Both comparisons are reported; only the former
isolates this issue's changes.

All four packets retained the same per-suite assertion totals (92/92; 3,908
passing assertions). Their individual full-run timings above do **not** establish
a speedup: the initial 159 s and final 163 s runs differ, and there are no repeat
samples establishing a noise range. Tool/subprocess counts remain NOT ASSESSED.
The changes establish shared setup and stronger parser coverage, not reduced
full-suite latency. No new full run was performed merely to restate these results.

Acceptance is supported by the packet mappings and unchanged cases: the baseline
is identified; no regression was dropped; negative controls and failure messages
survive; production jq executes for the converted JSON fixtures; the silent-suite
runner defect was fixed; and representation decreased after shared helpers were
included. Exact-HEAD independent PASS and green doctor/tests/docs-truth/gate
checks on `3f9774c97ec2857f87955bcc975265c363fc6ed0` certify packet 4. Its merge
`a2d0ef9a4159db25412361f6e2879e7cffe6a0f8` has the identical tree. This final
assessment changes only this manifest; it does not claim new executable coverage
or an efficiency result for the wider release gate.

## Acceptance, item by item

| Contract item | Evidence | State |
|---|---|---|
| Baseline test inventory comes from #737 or a reproducible extension of it | the frozen inventory `921c982` (`agent-test-representation.md`) plus a captured full run per packet at its base and HEAD, with every suite's own `N passed, M failed` line | met |
| Every removed/consolidated regression maps to surviving proof or an approved removed behaviour | no regression was removed; each packet's mapping table names the surviving proof for every replaced definition or stub | met |
| No assertion or discriminating case silently dropped | per-suite pass/fail lines identical before and after in every packet (92/92; 3,908 assertions); the runner now fails a suite that prints no summary line, closing the one way a drop could have hidden | met |
| Mutation/negative controls at least as discriminating | no control changed; the JSON-fixture stubs exercise the production jq the pre-shaped rows had assumed, so the converted scenarios discriminate more, not less | met |
| Production transports/parsers exercised where mocks assumed their output | packets 2 and 3: five jq programs in the binary and five in the codify preflight now run under test; the remaining stubs answer GraphQL snapshots or `gh issue view` reads through the caller's jq already | met |
| Failure localization remains useful | identical failure messages; each converted scenario still names its case | met |
| Test/harness representation reduced where evidence supports it | suite lines 19,476 → 19,303 across the issue; shared library +30, runner +7; net `tests/` −136 against the issue start (+94 against the frozen inventory because the intervening runtime work added proof — both reported) | met |
| Focused/full verification cost compared | full-run wall clock 159–163 s across packets with no repeat samples: no speedup is claimed; tool/subprocess counts NOT ASSESSED (the runner does not measure them) | met as reported, not as an efficiency win |
| Required focused/full suites green on the exact candidate HEAD | every packet: doctor and tests green at the reviewed HEAD, exact-HEAD independent PASS before merge | met |

The honest release-gate reading: this issue made the suites safer and their transports
better covered, and it removed representation; it did not make the full suite faster.
