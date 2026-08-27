# Spark's self-conformance audit (v0.20 Phase A)

> **The #442 conformance record.** Spark audited against the engineering model
> it expects downstream repositories to follow, before v0.20 uses Spark to
> orchestrate another repository. A dev-doc — it governs how Spark is built and
> never ships. Owner: `jwogrady`.
>
> **Audited master:** `48239794e7f2fe4ef10b2fc9db98ae4d37642bc9`, 2026-08-26,
> which is also tag `v0.19.0` — the audited tree and the published release are
> the same commit.

Every row ends as `PASS`, `GAP` with a named owner, `EXCEPTION` with a bounded
rationale, or `NOT ASSESSED`. There is no fifth disposition: an interesting
observation either becomes one of these four or it is not a finding.

## How the audit was run

The operator was the **released** plugin, not the checkout: `spark 0.19.0`
resolved from `~/.claude/plugins/cache/spark/spark/0.19.0/bin/spark`. Two
identities were kept separate throughout, because the released CLI derives
`SPARK_ROOT` from its own executable location:

| Identity | Command | Validates |
| --- | --- | --- |
| Released operator | `spark doctor` | the installed plugin |
| Current checkout | `./plugins/spark/bin/spark doctor` | this source tree |

That distinction is architecture, not a defect. `doctor` is the plugin-layout
validator; it is one evidence row in this matrix, never the repository
conformance auditor.

### Operator provenance

Two artifacts have carried the name `v0.19.0` — the withdrawn one and the
reconstructed one — so the version string was not accepted as proof. The
installed tree was compared to the tag by content: **81 files, 0 mismatches, 0
extra, 0 missing**, bidirectional. The comparison discriminates:

| Tree | Content fingerprint |
| --- | --- |
| Installed cache | `595d39447093e34f` |
| Published `v0.19.0` (`4823979`) | `595d39447093e34f` |
| Withdrawn `v0.19.1` (`6f9c026`) | `9c37204ce11cdb6f` |
| Withdrawn `v0.19.0` (`48238d1`) | `d44e88cb9975290f` |

The marketplace clone is at the same commit, and `installed_plugins.json`
records the same SHA. Marketplace revision, installed revision, and published
release agree. The operator is the reconstructed release.

## The matrix

### Repository workflow

| Standard | Canonical source | Evidence | Verdict | Owner |
| --- | --- | --- | --- | --- |
| Trunk naming and server-side policy | [enforcement-model](../../plugins/spark/docs/explanation/enforcement-model.md) | `master`; PRs required, merges CI-gated, force-push and deletion blocked | `PASS` | — |
| No direct implementation commits to trunk outside the release mechanism | [AGENTS.md](../../AGENTS.md) | First-parent non-merge commits since `v0.16.2`: **5, all Release Please releases** (#392, #416, #424, #430, #433), alongside 45 PR merges | `PASS` | — |
| Conventional Commits | `scripts/hooks/commit-msg` | 0 of 93 non-merge commits since `v0.16.2` violate the type grammar | `PASS` | — |
| Subject ≤ 72 characters | `scripts/hooks/commit-msg` | 2 historical violations on `master` | `EXCEPTION` | this doc |
| One issue per implementation branch | [ADR-0027](../adr/0027-delivery-model.md) | Bounded set of pre-`v0.19.0` merges with no issue | `EXCEPTION` | #442 |
| Implementation linkage on open PRs | [metadata-governance](../../plugins/spark/docs/reference/metadata-governance.md) | #464 `Closes #447`; #440 `Closes #439` — both carry the canonical linkage fact | `PASS` | — |
| `.spark/state.json` reflects current resumable intent | #442 acceptance | Was stale at audit time; corrected in this change | `PASS` | #442 |

### GitHub execution metadata

| Standard | Canonical source | Evidence | Verdict | Owner |
| --- | --- | --- | --- | --- |
| Exactly one taxonomy category per issue | metadata-governance | **31 / 31** open issues | `PASS` | — |
| Exactly one `P0`–`P3` priority | metadata-governance | **31 / 31** open issues | `PASS` | — |
| Explicit release disposition | metadata-governance | 30 milestoned; #439 carries `backlog` | `PASS` | — |
| Deprecated `enhancement` alias | metadata-governance | 35 issues carry it — **all closed**; 0 open | `EXCEPTION` | this doc |
| Milestone scope integrity | #443 | v0.20 holds #436, #437, #438, #441, #442, #443, #447, #487 — the seven-issue scope plus its own gate | `PASS` | — |
| PR-level milestone and category labels | metadata-governance | **Not a requirement.** The canonical PR fact is a linked PR plus a closing keyword; category and milestone are issue-side facts. Imposing them on PRs would duplicate a fact that already lives on the issue | `PASS` | — |

### Repository standards artifacts

| Standard | Canonical source | Evidence | Verdict | Owner |
| --- | --- | --- | --- | --- |
| `AGENTS.md` canonical agent contract | agents-md skill | Present; single canonical body | `PASS` | — |
| `CLAUDE.md` pointer/import relationship | agents-md skill | Imports `AGENTS.md`; no second body | `PASS` | — |
| Artifact-tier separation | [ADR-0029](../adr/0029-four-tier-artifact-separation.md) | Checkout `doctor`: no development-only material under `plugins/`, no unresolvable issue references in shipped surfaces | `PASS` | — |
| Destructive-change and human-approval boundaries | AGENTS.md | Guard blocks force-push and trunk pushes; release act reserved to a human merge | `PASS` | — |
| Release ownership / version authority | [ADR-0009](../adr/0009-spark-release-mechanism.md) | Milestone declares the version; Release Please mints it; `ship` never cuts releases | `PASS` | — |
| Project-tier engineering standard carried in-repo | [ADR-0010](../adr/0010-preferences-source-model.md) | `.spark/preferences.json` absent — Spark runs on shipped defaults | `EXCEPTION` | this doc |

### Enforcement

| Standard | Canonical source | Evidence | Verdict | Owner |
| --- | --- | --- | --- | --- |
| Door 1 — assistant/tool guard | `hooks/guard-bash.sh` | Present and executable; `test-guard-bash` passes | `PASS` | — |
| Door 2 — local git hooks | `scripts/hooks/` | Installed in the working clone; `doctor` confirms | `PASS` | — |
| Door 3 — GitHub server-side trunk policy | `settings/github-ruleset-trunk.json` | `doctor --requirements`: policy held on the remote | `PASS` | — |
| `spark doctor` clean on the audited tree | #442 acceptance | Checkout identity: **0 errors, 0 warnings** | `PASS` | — |
| Behavioral suite passes | [ADR-0018](../adr/0018-behavioral-tests-are-the-second-ci-gate.md) | **40 / 40 suites** | `PASS` | — |
| Shell syntax gates | `bash -n` | 8 shipped scripts clean via `doctor` | `PASS` | — |
| Negative controls prove guards refuse | #442 acceptance | `commit-msg` fed the two historical subjects **rejected both** (78 and 79 chars) and accepted a valid 35-char subject; `test-remote-enforcement` (54 assertions) and `test-guard-bash` pass | `PASS` | — |
| A green check never means an unassessed condition | #442 acceptance | The inverse failure exists: `resume` reports a verified absent PR as unverified | `GAP` | **#488** |
| Required CI is actually required on the remote | #442 acceptance | `validate.yml` and `milestone-gate.yml` trigger on `pull_request`, and `doctor --requirements` reports merges CI-gated; the ruleset's required-checks list was not enumerated directly | `NOT ASSESSED` | #442 |

### Release governance

| Standard | Canonical source | Evidence | Verdict | Owner |
| --- | --- | --- | --- | --- |
| Release Please remains the release mechanism | ADR-0009 | Config and workflow present; the human merge is the release act | `PASS` | — |
| Version authority and `Release-As` semantics | ADR-0009 | Milestone declares; Release Please mints | `PASS` | — |
| Release PR staleness and notes checks current | #425 | Pre-merge staleness gate present | `PASS` | — |
| Changelog integrity | Release Please | One `0.19.0` section from the `v0.16.2` boundary plus the withdrawal notice | `PASS` | — |
| Duplicated changelog entries | #415, #417, #418, #421 | Doubling persists (e.g. #396 twice); the fix is plain PR titles, and no merge-commit setting expresses it | `EXCEPTION` | #418 |
| ROADMAP and release records agree with published releases | release-docs checklist | ROADMAP still names `v0.16.2` as baseline and marks v0.19 *Merged (awaiting release)* | `GAP` | **#441** |
| `docs/releases/` record for `v0.19.0` | release-docs checklist | Not opened during this pass | `NOT ASSESSED` | #441 |

## The exceptions, in full

Each is bounded, argued, and grants nothing forward.

### 1. One issue per implementation branch, before `v0.19.0`

Recorded 2026-08-26 as the disposition #445 required. Gate #445 asked whether to
retro-fit issue linkage onto merged work that never had it. **The decision is
the exception.** Spark's doctrine says a gap is recorded, never retro-fitted;
filing issues after the fact to satisfy a checklist would manufacture
provenance rather than describe it. The complete set is enumerated in #442 —
the v0.19 architectural core (#434, #428, #431, #432, #429, #425, #427, #426,
#418, #417, #415, #421) and the v0.18 outcome (#419, #422, #413, #414).

Bounded to work merged before `v0.19.0`. It grants nothing forward.

### 2. Subject length is promised locally, not server-side

Two commits on `master` exceed the 72-character subject limit:

| Commit | Length | Landed via |
| --- | --- | --- |
| `d7baf10` | 78 | merge PR #420 |
| `b8eaa37` | 79 | merge PR #407 |

Both were authored with the over-length subject — they arrived through merge
commits, so no squash suffix inflated them. Four questions decide the
classification:

1. **Did they predate the rule?** No. The 72-character check has been in the
   hook source since `44b4c92` (2026-07-08); the commits are from 2026-08-24
   and 2026-08-25.
2. **Did the local gate fail?** No. Fed both subjects, `commit-msg` rejects
   each with the correct message and accepts a valid one. The gate's logic is
   sound; the commits reached `master` through a path where it was not running.
3. **Can GitHub enforce the same rule under current doctrine?** Not as the
   doctrine now stands. Door 3's promised scope is explicit and structural —
   *requires pull requests, gates merges on required CI checks, blocks
   force-pushes and deletion*. Commit-message content is not in it, and Spark
   **inspects, never applies** remote policy: changing what the remote enforces
   is an explicit human action, never Spark's.
4. **So what is it?** Not an enforcement GAP, because **no promised invariant is
   unenforced.** The enforcement model already states the boundary in its own
   words: *"the `commit-msg`/`pre-commit` hooks only protect a repo after `spark
   install-git-hooks` has run there. Enforcement you didn't install is back to
   being advisory."* These two commits are precisely that documented limitation
   producing its predicted result.

The history is immutable — rewriting it is forbidden — so the two subjects
stand as a bounded historical fact. **No new issue.** Expanding door 3 to cover
message content would be a human decision to widen the enforcement contract,
not a defect repair.

### 3. The `enhancement` alias on closed issues

35 issues carry the deprecated `enhancement` label. **All 35 are closed; zero
open issues carry it.** They predate taxonomy provisioning, and 30 of them also
predate any canonical category.

The requirement is *exactly one `issue.taxonomy` category*, not exactly one
label — theme labels may accompany a category. `enhancement` is not a taxonomy
category, so it is not a competing second category; it is historical metadata on
work that is already finished. Recurrence is mechanically prevented: `doctor`
checks that no issue form uses the alias, and that check passes.

`spark labels` offers `--apply --prune-deprecated`. It is deliberately **not**
run: mass-editing 35 closed issues would rewrite the metadata of finished work
to make a report cosmetically clean, changing nothing about any active decision.

### 4. No project-tier preferences file

Spark resolves all 11 preferences from shipped defaults; `.spark/preferences.json`
does not exist. This is correct rather than missing. Spark *is* the repository
that defines those defaults, so committing a project-tier file would create a
second copy of the same facts and invite the two to drift — exactly the
duplication the source-of-truth model forbids. Recorded here so a future audit
reads the absence as a decision.

### 5. Duplicated changelog entries

Generated release notes double some entries. The cause and the fix are already
recorded (#415, #417, #418, #421): plain PR titles are the fix, and no
merge-commit setting expresses it. Carried as a known, owned condition rather
than re-raised here.

## What this audit changed

- **`.spark/state.json`** was stale at audit time. It claimed `v0.19.0` was
  unpublished, #446 open, gates #373/#444/#445 pending, and PRs #464/#440 frozen
  awaiting a tag — all four contradicted by live GitHub. Inspection found no
  underlying Spark defect: state is written at stage close-out by `spark state
  --set`, and the release completed after the last write. Ordinary drift, not a
  behavior bug, so no behavior issue was filed. Corrected through the canonical
  writer, never by hand-editing the file as if it were backlog authority.
- **#488** was filed for the one genuine behavior GAP.

## The one GAP that became an issue

**#488 — `spark resume` reports a verified absent PR as unverified.**

`gh pr view … 2>/dev/null || true` discards exit status and stderr, so a
verified "no PR" and an unreachable GitHub collapse into one hedged string. The
invariant is `known false != unknown`. Filed `bug` / `P2` / `backlog`: it is a
real defect against Spark's honesty doctrine, but it fails #443's P0/P1
scope-growth test, and its error direction is conservative — it over-hedges and
never asserts a false positive. The nearest precedent, #224, was the more
dangerous direction (a false green) and was also P2.

## See also

- [ADR-0027](../adr/0027-delivery-model.md) — the delivery model this audits against
- [ADR-0029](../adr/0029-four-tier-artifact-separation.md) — the tier separation `doctor` enforces
- [enforcement-model](../../plugins/spark/docs/explanation/enforcement-model.md) — the three doors and where they stop
