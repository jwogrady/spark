# #744 repository cleanup evidence

Observed from GitHub on 2026-09-25 UTC.

## Scope and method

This audit is evidence-first. A remote branch is a safe stale-ref candidate only when its **current branch SHA exactly equals the HEAD SHA of a merged pull request**. Active pull-request heads, the default branch, and release/release-please refs are excluded. A familiar branch name is not evidence.

The repository has no conventional root dependency manifest such as `package.json`, `go.mod`, `requirements.txt`, `Cargo.toml`, or `Gemfile`; no dependency removal is proposed by this work unit. Current CI helper scripts were checked by repository references and remain exercised by tests and/or active workflow/release surfaces, so no script deletion is proposed.

No tracked generated/vendor/build artifact is proposed for deletion. Historical evidence is governed separately by #742/#768 and is not treated as cruft.

## Branch disposition summary

- Remote branches observed: **169**
- Safe stale-ref candidates: **147**
- Current active PR heads excluded: **8**
- Branches whose current SHA differs from a historical merged-PR HEAD: **3**
- Remote refs deleted by this execution environment: **0**

The final number is a tooling boundary, not a safety decision: the available GitHub connector has no delete-ref operation. It can prove candidates but cannot physically delete those remote refs. Do not substitute a force-move for deletion.

## Safe stale-ref candidates

Every row below is safe by the exact-SHA/merged-PR rule. The branch is recreatable from the merged PR and Git history.

| Branch | Current SHA | Merged PR |
| --- | --- | ---: |
| `chore/442-self-conformance-audit` | `fe546c9d4bf7` | #489 |
| `chore/454-current-work-state` | `dd31f21f4282` | #466 |
| `chore/478-certify` | `d177acbf5027` | #542 |
| `chore/478-final-recertify` | `6775d5a859ad` | #560 |
| `chore/478-recertify` | `8f4ed4247e08` | #545 |
| `chore/478-recertify-2` | `e282d1fc6de1` | #548 |
| `chore/479-release-evidence` | `4d35897ca6bc` | #612 |
| `chore/479-release-record` | `22e9a20ae3de` | #596 |
| `chore/483-reaudit-pagination` | `1c4d72d7a7cd` | #552 |
| `chore/730-737-baseline-measurement` | `5bd53e727372` | #747 |
| `chore/730-findings-completeness` | `8ffff0e8ec0e` | #750 |
| `chore/730-reviewer-findings-text` | `524c593b1797` | #748 |
| `chore/737-repository-baseline` | `07884f8abfb0` | #749 |
| `chore/738-dead-code` | `55851d3c193e` | #752 |
| `chore/740-closeout` | `abe4642bbcb9` | #759 |
| `chore/740-stub-scaffolding` | `4fd81b03c576` | #756 |
| `chore/740-stub-sweep` | `3f9774c97ec2` | #757 |
| `chore/740-test-consolidation` | `a39ce526d8fa` | #754 |
| `chore/740-wrong-layer-stubs` | `d0eda3db6061` | #755 |
| `chore/743-runtime-surface` | `2fd2fcc2a63a` | #767 |
| `chore/rebase-footprint-budgets` | `33edd81eb22a` | #427 |
| `chore/record-issue-sweep-handoff` | `21c4a1ef4871` | #413 |
| `chore/record-v0180-release` | `2e398154cb18` | #414 |
| `chore/v022-admit-570-571` | `9a61e7e97cbd` | #572 |
| `chore/v022-sprint-start` | `570dc95f7ab9` | #565 |
| `docs/364-collapse-doctrine-duplication` | `46b94c429c78` | #412 |
| `docs/373-cosmos-record-filed` | `3c47a8912818` | #390 |
| `docs/394-status26-naming` | `5979d428d8a0` | #410 |
| `docs/395-subissue-rung` | `d1f70a015a3d` | #411 |
| `docs/448-roadmap-truth` | `194ceb0c0916` | #449 |
| `docs/450-v019-record` | `5dab86ec4b77` | #458 |
| `docs/451-v017-record` | `a25504b764d9` | #456 |
| `docs/452-v018-record` | `67171164e555` | #457 |
| `docs/453-collapse-release-archaeology` | `db67b42cf6ab` | #465 |
| `docs/473-narrow-contract` | `de2c960e755e` | #553 |
| `docs/474-state-provenance-contract` | `24b8bb90349c` | #621 |
| `docs/480-release-record-contract-truth` | `179444f7cdf3` | #723 |
| `docs/480-roadmap-v025-coverage` | `014b0a4ec508` | #720 |
| `docs/480-v023-roadmap-outcome` | `1be1839a35d1` | #721 |
| `docs/546-ledger-truth` | `8b0448543cc2` | #547 |
| `docs/549-suite-counts` | `a5cabf040641` | #556 |
| `docs/709-v0.23-usage-evidence` | `b61e17c071a9` | #718 |
| `docs/741-canonical-truth` | `00e615886d62` | #762 |
| `docs/742-evidence-index` | `d90556a34500` | #766 |
| `docs/adr-glossary-pointer` | `60a40660549e` | #429 |
| `docs/adr-tier-separation` | `96d9aa431872` | #434 |
| `docs/document-footprint-root` | `8db3c97e7d40` | #426 |
| `docs/merge-convention-setting-correction` | `ea3714895119` | #415 |
| `docs/merge-setting-invalid-combo` | `77d61bd23e26` | #417 |
| `docs/plain-pr-titles` | `d749f2ea8eda` | #418 |
| `docs/release-pr-staleness-gate` | `f42751a2bd7f` | #425 |
| `docs/rename-dev-reference-to-ops` | `66f9f73d9a6e` | #431 |
| `docs/sweep-shipped-issue-refs` | `4f07a7b8fa66` | #432 |
| `feat/396-issue-taxonomy-labels` | `a165860d64e6` | #408 |
| `feat/401-gitattributes` | `7bb246582acf` | #409 |
| `feat/468-reconcile-apply` | `2c095789b898` | #588 |
| `feat/468-reconciliation-slate` | `66d99be6a17e` | #586 |
| `feat/469-course-derivation` | `90320aedf720` | #591 |
| `feat/484-docs-truth` | `9a0d15e1a4ac` | #652 |
| `feat/558-bounded-runs` | `0dcfea6778de` | #640 |
| `feat/574-run-telemetry` | `2f0db6ae0abc` | #639 |
| `feat/575-cost-based-routing` | `502ce9a10215` | #644 |
| `feat/576-token-efficient-context` | `73de4dc75e20` | #643 |
| `feat/583-claude-lane` | `8a46c7bd3d23` | #672 |
| `feat/584-openai-reviewer-lane` | `41f90d10c65a` | #688 |
| `feat/636-stop-ci-polling` | `18e5a29d931c` | #646 |
| `feat/710-governance-attribution` | `546ed40b5197` | #712 |
| `feat/731-fact-model-suite` | `57af24801f08` | #758 |
| `feat/731-operative-fact-model` | `079c3fbfc45e` | #751 |
| `feat/732-fact-freshness` | `a16383652345` | #760 |
| `feat/733-acceptance-contract` | `4b59e9ac1611` | #781 |
| `feat/733-checks-required` | `fc77cfcbdd70` | #779 |
| `feat/733-fact-compiler` | `38362156b654` | #771 |
| `feat/733-graph` | `664307c57223` | #773 |
| `feat/733-head-checks` | `3a983f548402` | #778 |
| `feat/733-placement-current` | `2e93cbe77e84` | #777 |
| `feat/733-review-fact` | `56b537c06201` | #780 |
| `feat/733-work-unit-placement` | `c844b8faeae7` | #775 |
| `feat/763-merge-strategy` | `ec6c0a241d4f` | #764 |
| `feat/doctor-tier-boundary` | `6f011eb02220` | #428 |
| `fix-446-changelog` | `3a4eec5bd816` | #486 |
| `fix/393-hub-locator-grammar` | `9ddfeb4aa376` | #403 |
| `fix/397-wiki-push` | `7a61ca336c11` | #404 |
| `fix/398-orient-readme-weight` | `91961ba15909` | #405 |
| `fix/399-stale-warning` | `963cff4e2d33` | #406 |
| `fix/400-front-door-routing` | `b8eaa37fd9f3` | #407 |
| `fix/446-release-state-baseline` | `b5cb81fbb844` | #455 |
| `fix/467-triage-truth` | `bad4438bbcf1` | #569 |
| `fix/470-contract-reaudit` | `800d08ab7ab0` | #525 |
| `fix/472-compiler-reaudit` | `91d3f312992a` | #533 |
| `fix/473-integration-reaudit` | `8f8002a11b0e` | #536 |
| `fix/475-roadmap-provenance-residual` | `163aa887e2eb` | #635 |
| `fix/483-grammar-reaudit` | `c0e350bee2b3` | #528 |
| `fix/511-exclusive-one-authority` | `a91d59e1266f` | #523 |
| `fix/512-evidence-failure-not-assessed` | `31e711b2cb05` | #527 |
| `fix/515-update-target-validation` | `1582bfea0607` | #529 |
| `fix/516-local-refusal-before-gh` | `72674a27d9bb` | #538 |
| `fix/517-verify-every-mutation` | `5864d83bd5ed` | #531 |
| `fix/518-order-per-parent` | `b615fae956ee` | #532 |
| `fix/520-next-fails-closed` | `e2536d20a88a` | #534 |
| `fix/521-headline-baseline-check` | `ab85822ad773` | #537 |
| `fix/524-release-pr-not-evidence` | `1c417f8743d2` | #551 |
| `fix/526-guard-data-not-command` | `7dd02731a606` | #557 |
| `fix/530-paginate-linked-prs` | `95ff21840399` | #550 |
| `fix/540-preserve-empty-fields` | `fd578d568ccf` | #543 |
| `fix/541-headline-region` | `4a3279a24896` | #544 |
| `fix/554-corroborate-release-pr` | `4e042c171d85` | #555 |
| `fix/559-decision-required` | `d97f7f425f3a` | #566 |
| `fix/567-ledger-interval` | `385a0e970b79` | #568 |
| `fix/570-prose-not-authority` | `f3f02ab13fd9` | #573 |
| `fix/571-explicit-issue-refs` | `db39212f3c93` | #577 |
| `fix/583-claude-lane-edit-permission` | `0d93f6b8b046` | #687 |
| `fix/587-multiword-disposition` | `8d30fccc5f6b` | #589 |
| `fix/590-fresh-slate-per-approval` | `2b0afb8bf922` | #593 |
| `fix/592-member-identity` | `a07e26e4e20d` | #595 |
| `fix/594-597-conformance` | `53983a5a4f45` | #598 |
| `fix/599-label-set-verify` | `202590a2acab` | #600 |
| `fix/602-milestone-work-authority` | `0bf677975f0e` | #604 |
| `fix/605-release-gate-role` | `2ca2760899eb` | #606 |
| `fix/609-measurement-truth` | `6fcf073fd923` | #662 |
| `fix/623-repo-boundary` | `a9f9d698c673` | #669 |
| `fix/626-readonly-mutation` | `1f00141a1284` | #653 |
| `fix/637-family-scoped-labels` | `0acd72103698` | #638 |
| `fix/642-budget-record-framing` | `1627a8c75f58` | #704 |
| `fix/647-evidence-invalidator` | `0294513288d5` | #705 |
| `fix/648-run-id-path-safety` | `c732e85a71e0` | #706 |
| `fix/658-ci-stale-head` | `2e29490f3a0a` | #703 |
| `fix/664-targeted-runner-streaming` | `67ed3db7a0af` | #707 |
| `fix/665-telemetry-counter-race` | `a8d677659e60` | #708 |
| `fix/666-benchmark-vocab-parity` | `5807cc92edf5` | #716 |
| `fix/670-runtime-telemetry-per-run` | `33fa4fc1c830` | #717 |
| `fix/732-fact-model-versions` | `aac4e976da6b` | #761 |
| `fix/733-unknown-version` | `2cd73898a780` | #772 |
| `fix/733-version-proof` | `f9921bde17e1` | #774 |
| `fix/guard-wiki-name-bypass` | `57e39e820c83` | #419 |
| `fix/labels-probe-accuracy` | `cacfeb7cd7ea` | #422 |
| `fix/release-notes-autolink` | `08002a1aa9c6` | #613 |
| `fix/scp-userinfo-grammar` | `d7baf10a9058` | #420 |
| `fix/ship-title-rule-conditional` | `eee833b2eb8e` | #421 |
| `perf/609-runtime-baseline` | `d746c9ab551c` | #661 |
| `perf/609-runtime-hotpaths` | `79148202cff0` | #657 |
| `perf/722-memoize-hot-path-resolution` | `cdc04a504afc` | #724 |
| `refactor/614-decompose` | `c53e15509b56` | #663 |
| `refactor/739-canonical-semantics` | `71733d7e1307` | #753 |
| `worktree-feat-476-provenance-leakage` | `0f7b7258fb29` | #633 |
| `worktree-fix-475-chronology` | `a7f12391b86b` | #632 |
| `worktree-v023-docs-truth-repair` | `8bf47c389db9` | #617 |

## Active PR heads — do not delete

| Branch | PR | Purpose |
| --- | ---: | --- |
| `chore/768-current-truth-inputs` | #784 | Remove historical evidence from current truth paths (#768) |
| `chore/project-audit` | #676 | Record the guard-scoping friction pattern and its cure |
| `docs/control-plane-recipes` | #715 | docs: record GitHub control-plane and Blueprint architecture |
| `feat/726-bounded-increment-merge-authority` | #727 | feat: define merge authority for bounded increments (#726) |
| `feat/733-authority-standing` | #783 | Compile standing authority from canonical decision record (#733) |
| `fix/696-crossroad-invalid-input` | #697 | fix: crossroad reports INVALID for input it cannot classify |
| `fix/733-review-record-provenance` | #782 | Preserve review record provenance on UNKNOWN verdicts (#733) |
| `release-please--branches--master` | #618 | chore: release spark v0.23.0 |

## Changed or special-history branches — needs review / do not delete automatically

These names have at least one merged PR in history, but the branch's current SHA no longer equals that merged PR HEAD. They are not safe-delete candidates under this audit.

| Branch | Current SHA | Historical merged PR HEAD | PR |
| --- | --- | --- | ---: |
| `fix/628-existing-impl` | `a9f9d698c673` | `349dc2b12102` | #668 |
| `refactor/614-plan-module` | `349dc2b12102` | `a848482eac19` | #667 |
| `release-please--branches--master` | `8b18a27e62a9` | `44d0c101e9b4` | #563 |

## Scripts and configuration disposition

- `.github/scripts/docs-truth.sh` — keep: current docs-truth workflow/test surface.
- `.github/scripts/gate-runner.sh` — keep: current milestone-gate/release runner surface.
- `.github/scripts/milestone-gate.sh` — keep: current milestone gate + tests.
- `.github/scripts/release-notes-check.sh` — keep: current release-note validation + tests.
- `.github/scripts/release-notes-runner.sh` — keep: current release/milestone runner + tests.
- `.github/scripts/ledger-truth-check.sh` — keep: live invariant checker; #768 removes its historical default instead of deleting the checker.
- `.github/scripts/alpha-intake-check.sh` — keep: current behavioral test contract.
- Release Please configuration — keep: active release PR #618 depends on it.

No duplicate or obsolete config was established strongly enough to remove. No deletion is performed from absence of evidence.

## Validation / remaining action

After any remote-ref deletion, re-read the branch list and verify:
1. all active PR heads still exist;
2. `master` and release/release-please refs still exist;
3. only rows from the safe-candidate table were removed;
4. build/CI/release checks remain green.

This report is the before/disposition evidence for #744 and #745. It does **not** claim that remote refs were deleted when the current connector cannot perform that operation.
