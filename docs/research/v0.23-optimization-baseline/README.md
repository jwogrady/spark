# v0.23 optimization baseline — the BEFORE side (#730, #737)

Baseline measurement evidence for the two v0.23 optimization trees, #728 (compiled fact snapshots) and
#729 (reasoning-surface cleanup). This directory is **measurement and reporting only**. Nothing here changes
Spark's behavior, and nothing here was produced by changing the measured system.

`tables.md` is generated from `raw/` by `tools/render-tables.py`. Raw evidence and interpretation are kept
apart: everything under `raw/` is a mechanical capture; this file is the interpretation.

## 0. Freeze

| Fact | Value |
|---|---|
| Frozen remote `master` (measured system) | `921c9820b92e99ef3620f4f46a0a8a6d7bb0c8b5` — "refactor: memoize repo-root and preference resolution per process (#722) (#724)" |
| Preserved PR #727 HEAD (real-world specimen) | `e3ced28f6a469b09990dfd96b3435bfb5b2b342a`, open, base `master`, unmodified by this work |
| Released governor at freeze | Spark v0.22.0 (published 2026-08-30) |
| Release / milestone / gate / orchestration | v0.23 "Never automate inefficiency" / milestone 20 / #480 (RED) / #677 |
| Milestone-20 open set at freeze | #480, #728, #729 and the 17 children of #728/#729 (20 issues) |
| Freeze observation (UTC) | 2026-09-06T16:24:54Z |
| Freeze comments | #730 comment 5560565518, #737 comment 5560565620 (`raw/freeze-comment-*.md`) |
| Ordering | The #728/#729 native sub-issue normalization happened **before** the freeze (metadata only). No #731–#736, #746 or #738–#745 work has begun. |

## 1. Instrumentation versus measured system

- **Measured system**: the frozen SHA above, checked out as a detached worktree. All repository measurements
  (`footprint.sh`, `tests/run.sh --json`, `tests/bench.sh`, `tests/structure.sh`) ran inside that worktree.
- **Instrumentation**: `tools/` in this directory, versioned by the commit that adds it. It is not part of the
  measured system and was created *after* the freeze comments were posted.
- **Reused machinery** (#609/#614/#722 discipline, not reinvented): `tests/run.sh --json` (one execution, one
  projection), `tests/bench.sh --json` (shimmed/parsers/gh invocation counts with their documented limits),
  `tests/structure.sh --json` (textual reference graph).
- **Consumption evidence**: the writer lane's own Claude Code session records, which log every tool call, every
  tool result, and the API's per-request token accounting. Two sessions: `c172f4f1…` (2026-09-04T16:13Z →
  2026-09-06T16:28Z, contains both measured workloads) and `0399c476…` (2026-08-30/31, other v0.23 work, used only
  as extra hot-path evidence). Models observed, per API request: workload A 558× `claude-opus-5`; workload B
  848× `claude-opus-5` + 143× `claude-opus-4-8`; Claude Code 2.1.260/2.1.261. These records are session-local and
  are **not** authority evidence; the numbers extracted from them are committed here so they are pointable.
- **GitHub evidence**: fetched by `tools/fetch-pr.sh` and `tools/fetch-commits.sh` (REST; raw JSON is re-fetchable
  and not committed — only `derived.json`, the finding text and the reviews are).

## 2. #730 — effective reasoning surface and context amplification

### 2.1 Workloads

| | Workload A | Workload B | Workload C |
|---|---|---|---|
| Unit | PR #727 (issue #726, bounded-increment merge authority), rounds 1–16 to HEAD `e3ced28` | PR #724 (issue #722, per-process memoization), rounds 1–32 to PASS and merge (`cdc04a5`) | Rehydration control: (i) repeat rounds on unchanged non-HEAD facts inside A and B; (ii) mechanical: `tests/bench.sh` live paths |
| Why representative | The `CHANGES REQUIRED` repair/review slice #730 requires; the PR that exposed the suspected representation problem | Same reviewer lane, same repository, same writer lane, materially different subject (runtime hot path + benchmark harness + ops doc), and it reached a terminal PASS — so it shows a complete loop, not a truncated one | Facts such as repo identity, milestone, parent, gate, authority and contract did not change during either workload; C measures how much of them was still fetched or re-derived |
| Boundary | Whole path: repository reads, GitHub reads, verification, evidence reconstruction, CI, review iterations | Same | Same |
| Cold/warm | Warm: one continuous session; A began in the same session right after B merged | Warm: the window opens 2h18m before the first commit to include orientation | — |

### 2.2 Baseline table

Full detail is in `tables.md` (T1 per workload, T2 per round). Deterministic counts are exact for what the
records contain; token figures are the API's own accounting and are marked observational.

| Workload / Surface | Frozen state | Metric | Before value | Method | Evidence | Confidence / limitation |
|---|---|---|---:|---|---|---|
| A: #727 | e3ced28 | commits / +lines / −lines / files | 20 / 4,570 / 1,847 / 12 | GitHub REST per commit | `raw/pr727/derived.json` | exact |
| A | | reviewer verdicts (exact-HEAD, trusted login) | 16 × CHANGES REQUIRED | `spark-openai-review` markers | derived.json | exact |
| A | | reviewer findings (raw bullets) / repeats of an earlier finding | 50 / 8 | bullet count; hand lineage | `raw/findings-classification.tsv` | classification is judgment |
| A | | wall clock first commit → last verdict / idle gap / active | 61,843 s / 51,023 s / 10,820 s | commit dates, marker times; gaps >30 min excluded | derived.json | exact; "active" is a convention |
| A | | push → verdict latency (median) | 13 s | head commit date → marker created_at | derived.json | exact; the reviewer is not the bottleneck |
| A | | CI runs per workflow (OpenAI Review / validate / milestone-gate / docs-truth) | 16 each; 1,812 / 3,048 / 875 / 145 s | actions/runs on the branch | derived.json | exact |
| A | | model API requests / tool calls / tool-result bytes | 558 / 529 / 290,841 | transcript | `raw/transcript-workloads.json` | exact for the writer lane only |
| A | | Read calls (unique paths / repeated) + shell reads over repo files | 16 (24 / 35) + 64 | transcript | transcript-workloads.json | exact; "unique" includes task-output files |
| A | | gh invocations (lower bound) / unique endpoints / repeated | 110 / 34 / 76 | transcript, script bodies parsed | transcript-workloads.json | lower bound (loops in scripts undercount) |
| A | | HEAD-independent fact fetches / HEAD-dependent fetches | 12 / 34 | endpoint classification | transcript-workloads.json | classification by endpoint shape |
| A | | targeted verification / full-suite / doctor / bash -n | 109 / 0 / 10 / 16 | command classification | transcript-workloads.json | exact; full suite was forbidden before PASS by standing instruction |
| A | | Edit/Write calls / unique repo files edited | 89 / 11 | transcript | transcript-workloads.json | exact |
| A | | context tokens processed (cache_read + cache_create + input) / output tokens | 168,731,098 / 559,072 | API usage per request | transcript-workloads.json | observational |
| A | | mean context per request; context per changed line; context per output token | 302,385; 26,294; 301 | derived | tables.md T1 | observational |
| B: #724 | cdc04a5 (merged as 921c982) | commits / +lines / −lines / files | 34 / 1,858 / 456 / 4 | GitHub REST | `raw/pr724/derived.json` | exact |
| B | | reviewer verdicts | 31 × CHANGES REQUIRED + 1 PASS (round 32) | markers | derived.json | exact; 3 marker echoes by the human login excluded |
| B | | reviewer findings / repeats | 76 (+4 PASS affirmations) / 11 | as above | findings-classification.tsv | judgment |
| B | | wall clock first commit → PASS / idle / active | 18,289 s / 0 / 18,289 s | as above | derived.json | exact |
| B | | push → verdict latency (median) | 11 s | as above | derived.json | exact |
| B | | CI runs per workflow | 32 each; 3,618 / 5,925 / 1,681 / 283 s | actions/runs | derived.json | exact |
| B | | model API requests / tool calls / tool-result bytes | 991 / 884 / 332,602 | transcript | transcript-workloads.json | exact |
| B | | Read calls (unique / repeated) + shell reads | 148 (101 / 79) + 84 | transcript | transcript-workloads.json | exact |
| B | | gh invocations (LB) / unique / repeated | 152 / 39 / 113 | transcript | transcript-workloads.json | lower bound |
| B | | HEAD-independent / HEAD-dependent fetches | 18 / 57 | as above | transcript-workloads.json | classification |
| B | | targeted verification / full-suite / doctor / bash -n | 103 / **48** / 20 / 21 | as above | transcript-workloads.json | exact |
| B | | Edit/Write calls / unique repo files | 115 / 5 | transcript | transcript-workloads.json | exact |
| B | | context tokens processed / output tokens | 582,515,671 / 476,609 | API usage | transcript-workloads.json | observational; the session carried context from earlier work into this window |
| B | | mean context per request; per changed line; per output token | 587,805; 251,735; 1,222 | derived | tables.md T1 | observational |
| C (mechanical) | 921c982 | `gh` invocations per run: governance validate / triage / doctor | 10 / 16 / 2 (per run; 3 runs → 30 / 48 / 6) | `tests/bench.sh --json` | `raw/bench.json` | gh invocations, not HTTP requests; live rows observational |
| C (mechanical) | 921c982 | wall ms per run (live): governance validate / triage / doctor | 4,997 / 7,225 / 2,142 | bench.sh | bench.json | observational (network) |
| C (mechanical) | 921c982 | offline paths: brief --short / footprint / governance (ms; shimmed) | 64 / 667 / 104 (19 / 257 / 42) | bench.sh | bench.json | reproducible on this host |
| C (in-workload) | A | rounds with a HEAD-independent fetch after round 1 | 2 of 15 (r5: 9 fetches, r8: 3) | per-round transcript | `raw/transcript-rounds.json` | r5/r8 were reviewer-demanded read-backs of #726/#481 |
| C (in-workload) | B | HEAD-independent fetches in round 1 / later rounds | 16 / 2 | per-round transcript | transcript-rounds.json | orientation is front-loaded |
| C (in-workload) | A | PR record re-read (`gh pr view 727`) | 21 fetches in 16 rounds | transcript | transcript-workloads.json | the record is HEAD-independent except `.head.sha` |
| C (in-workload) | B | PR conversation re-read (`issues/724/comments`) | 51 fetches in 32 rounds | transcript | transcript-workloads.json | contract needs ≈1 per round; the rest is verdict polling |
| C (in-workload) | A | runtime file re-read (`execution.sh`/`bin/spark`) in later rounds | 9 of 16 rounds | transcript | transcript-rounds.json | region reads via `sed -n`, not whole-file |
| Session start | every session | agent contract auto-loaded (`CLAUDE.md` → `AGENTS.md`) | 292 lines / 15,433 bytes | `footprint.sh` root.contract | `raw/footprint.txt` | per session, before any task work |

### 2.3 Dominant sources

**Repeated-read sources.** In A, `plugins/spark/lib/execution.sh` was touched 62 times (reads via `sed -n`,
edits) and cited by the reviewer in 15 of 16 rounds; `plugins/spark/skills/ship/SKILL.md` 18 times and
`plugins/spark/docs/reference/cli.md` 11 times because every round re-reconciled the three prose surfaces
(ADR, skill, CLI reference) with the code. In B, `tests/bench-memo.sh` 43, `plugins/spark/bin/spark` 41,
`tests/test-hot-path-memo.sh` 34, `docs/ops/execution-configuration-surface.md` 31 — the same four files the
reviewer cited in 18–20 of 32 rounds. Repeated reading is concentrated on the files under repair, not spread
over the tree: the physical tree (65,186 LOC) is not what was read.

**Context-reconstruction sources.** Reads of background task output (`/tmp/claude-…/tasks/*.output`) were the
most repeated Read target in both workloads (A: the top read path 5×; B: eight of the top eight read paths).
These are re-reads of test-runner and watcher output the lane had already produced — reconstruction of its own
recent state, not new information.

**Repeated GitHub work.** A: `gh pr view 727` 21×, `issues/727/comments` 19×, `#726` 11× (view + API),
`#481/sub_issues` 7×, check-runs 6×. B: `issues/724/comments` 51×, `pr checks` 13×, `pr view` 7×,
milestone 20/21 8×, `#677` comments 7×, `#480/sub_issues` 4×. The PR conversation is fetched far more often
than once per verdict because the lane polls for the verdict; the PR record and the parent/authority issues are
fetched repeatedly although only `.head.sha` changes between rounds.

**Repeated verification.** A: 109 targeted runs for 16 pushes (6.8 per push) and 0 full-suite runs (forbidden
before PASS). B: 103 targeted plus **48 full-suite runs** for 32 pushes; at the measured 161 s per full run that is
≈7,700 s, about 42 % of B's 18,289 s active wall clock — the single largest reproducible cost in B, and it is a
governance choice, not a property of the change.

**Stable facts reconstructed although the sources did not change.** Repository identity, milestone 20/21,
release gate #480 and its sub-issues, standing orchestration #677 (its comment stream), the parent issue and the
PR record were fetched 18 (B) and 12 (A) times in-workload plus 20 more in the two "other" windows of the same
session. `tests/bench.sh` shows the runtime side of the same pattern: every `spark governance validate` costs 10
`gh` invocations and every `triage` 16, with no reuse between invocations.

**Strongest context-amplification example.** Tool results returned to the model in A total 290,841 bytes, yet
the API processed 168.7 M context tokens across 558 requests (302 K per request): ≈580 context tokens per
tool-result byte and ≈26,300 per changed line. In B: 332,602 result bytes, 582.5 M context tokens, 588 K per
request, ≈251,700 per changed line. The amplification is dominated by re-sending accumulated conversation on
every request, not by the volume of new information read — which is exactly the cost a compiled, bounded
snapshot would have to displace to matter. (Observational: cache reads are cheaper than fresh input, and B's
window inherits context from the earlier part of the same session.)

### 2.4 Reviewer finding classification

Hand-classified from the reviewer bodies (`raw/pr*/findings.txt`; one row per bullet in
`raw/findings-classification.tsv`):

| category | A: #727 (50) | B: #724 (76) |
|---|---:|---:|
| IMPL — genuinely new implementation defect | 15 (30 %) | 9 (11 %) |
| REPR — representation / transport boundary (grammar, encoding, pagination, identity, path bytes) | 17 (34 %) | 6 (7 %) |
| DUP — duplicated-semantic drift (doc ↔ code, comment ↔ code, help ↔ impl, doc ↔ doc) | 7 (14 %) | 17 (22 %) |
| STALE — stale / reconstructed-state (state asserted, not read; temporal ordering) | 3 (6 %) | 0 |
| TEST — test-harness / fixture / measurement-instrument defect | 2 (4 %) | 36 (47 %) |
| GOV — governance / specification / evidence-contract ambiguity | 6 (12 %) | 8 (10 %) |
| repeats of an earlier finding (same lineage) | 8 | 11 |

In A, representation, stale-state and duplicate-semantics classes together are 54 % of findings, against 30 %
new implementation defects; the reviewer's dominant complaint about #727 was how facts were represented,
parsed, bound and re-read, not what the code intended. In B the loop was dominated by instrument definitions
(what "process creation" or "executed program image" means) and by prose that lagged the code (17 DUP findings,
including a PR body that was stale three times). Round 29 of B repeated all three round-28 findings verbatim: one
full push–review cycle produced no accepted change. None of this is causal proof about round counts; it is the
distribution the AFTER side must be compared against.

### 2.5 Contract-required versus repeated or avoidable work

Per round, the standing contract requires: read the exact-HEAD verdict once; repair; syntax-check; run the
targeted suites for the surfaces changed; `spark doctor`; push once; post one top-level comment. Everything
else in T2 is repeated or avoidable relative to that contract:

- Verdict acquisition: B fetched the conversation 51× for 32 verdicts (≥19 polls beyond one-per-round);
  A 19× for 16.
- PR record and parent/authority facts: A 21 + 18, B 7 + 18 fetches of facts that changed at most once
  (A's `Closes #726` edit and the #726→#481 attachment, both reviewer-demanded read-backs).
- Verification: B's 48 full-suite runs against 32 pushes (the contract for B asked for full certification per
  round; the repair path only needs the targeted run — `tests/run.sh` documents exactly this distinction).
- Prose reconciliation: A re-edited `cli.md` 7×, `ship/SKILL.md` 8×, `bounded-merge.md` 5×, ADR-0032 5× to keep
  four hand-maintained statements of one contract aligned — contract-required today, avoidable if the contract
  had one source.
- Session-start orientation: B round 1 spent 104 API requests, 45 `gh` invocations and 34 M context tokens
  before the first verdict, 16 of them on HEAD-independent facts.

### 2.6 NOT ASSESSED (#730)

- Reviewer-lane consumption (OpenAI side): tokens, repository bytes read, model identity — not observable from
  this repository; only the workflow run durations are recorded.
- Orchestrator (ChatGPT) reads and the human's reads — not observable.
- Currency cost — not derived; no price table is authority here.
- Cold-start cost — both workloads were warm continuations of one session; no cold run was captured.
- Per-tool-call wall time — timestamps exist per message, not per tool; not computed.
- Repository bytes read by the reviewer's `validate`/`doctor` CI runs — only durations captured.
- The #722 Lord's Prayer calibration fixture — defined by #722, not run here (out of this task's scope).
- HTTP request counts — `gh` invocations are a lower bound, as `tests/bench.sh` itself states.

## 3. #737 — repository and active reasoning surface

### 3.1 Physical repository footprint (tracked files at 921c982)

Method: `git ls-files` per pathspec bucket, `wc -c` / `wc -l` (physical lines). Every one of the 389 tracked
files is in exactly one bucket (coverage check in `raw/footprint.txt`: none uncovered, none double-counted).
Totals: **389 files, 3,384,375 bytes, 65,186 LOC.**

| Tier / bucket | files | bytes | LOC | share of LOC |
|---|---:|---:|---:|---:|
| **Code — runtime** (dispatcher 1 / lib 3 / scripts 2 / hooks 2 / settings 3 / manifests 5) | 16 | 599,936 | 12,881 | 19.8 % |
| — `plugins/spark/bin/spark` alone | 1 | 419,187 | 8,881 | 13.6 % |
| — `plugins/spark/lib/{execution,planning,repository}.sh` | 3 | 148,207 | 3,217 | 4.9 % |
| **Code — skills** (SKILL.md 9 / references 13 / agents 3 / scripts 5) | 30 | 197,301 | 4,030 | 6.2 % |
| **Code — preferences** | 14 | 30,278 | 600 | 0.9 % |
| **Shipped docs** `plugins/spark/docs` | 32 | 310,651 | 5,908 | 9.1 % |
| **Companions** (audit 7 / connect 5 / docs 9) | 21 | 74,583 | 1,563 | 2.4 % |
| **Tests** (91 suites / 6 harness files) | 97 | 1,037,160 | 20,580 | **31.6 %** |
| **Dev prose** `docs/` (adr 32 / ops 18 / architecture 1 / releases 13 / governance 3 / research 2 / alpha 6 / root 3) | 78 | 626,997 | 11,185 | 17.2 % |
| **Root contract** AGENTS.md + CLAUDE.md | 2 | 15,433 | 292 | 0.4 % |
| Root README + ROADMAP | 2 | 50,637 | 997 | 1.5 % |
| CHANGELOG.md (generated by Release Please) | 1 | 97,029 | 879 | 1.3 % |
| Root community files (CoC, CONTRIBUTING, LICENSE, SECURITY) | 4 | 16,502 | 375 | 0.6 % |
| `.github` (workflows 6 / scripts 12 / templates 8) | 26 | 178,704 | 3,806 | 5.8 % |
| `evaluations/` (harness 6 / fixtures 17 / recorded runs 15 / prose 5) | 43 | 79,685 | 1,606 | 2.5 % |
| `assets/logo` | 16 | 64,346 | 310 | 0.5 % |
| Release config, `.spark` state, `.vscode`, `.gitignore` | 7 | 5,133 | 174 | 0.3 % |

Other physical counts (`raw/footprint.txt`, `raw/structure.*`, `raw/run-full*`):

| Item | Value | Method / limitation |
|---|---:|---|
| Dispatcher functions / top-level globals | 151 / 22 | `tests/structure.sh` |
| Dispatcher verbs | 31 (cli.md headings = cli-stability.tsv rows = 31; `VERBS` table grep found 30 — regex limitation, doctor's parity check is the authority) | grep; `spark doctor` |
| `cmd_*` handlers in dispatcher / lib | 22 / 8 | grep |
| Largest functions | `cmd_doctor` 833 lines, `cmd_next` 327, `cmd_labels` 273, `cmd_docs_impact` 267 | structure.sh |
| Shared primitives (referenced by ≥3 verbs) / verb-local functions | 46 / 49 | structure.sh (textual references, not a call graph) |
| Lib modules | execution.sh 2,195 lines / 66 fn; planning.sh 801 / 15; repository.sh 221 / 10 | grep |
| Test suites / assertions executed / full-suite wall | 91 / 3,799 passed, 0 failed / **161 s** | `tests/run.sh --json`, one execution |
| Slowest suites | latency 14 s, course-derivation 11, hub 10, governance-integration 8, governance-schema 6 | run.sh --json |
| Static assertion call sites | ≈3,110 (five assertion idioms; runtime count differs because loops re-execute assertions) | `raw/agent-test-representation.md` |
| ADRs / partially superseded / retired-machinery | 31 (+template) / 7 / 4 | status lines; no ADR is fully `Superseded` |
| Release records | 13 | ls |
| Workflows / .github scripts | 6 / 12 | ls |
| External binaries referenced by runtime (textual) | awk 286, git 201, gh 128, jq 83, grep 67, tr 66, sort 45, sed 41, wc 36, python3 35 | grep over runtime files; mentions, not invocations |
| Remote branches (excluding master) | 134: 109 already ancestors of master, 25 not (of which several are squash-merged, e.g. `perf/722-…` ahead 34) | `raw/branches.tsv`; ancestry, not GitHub merge state |
| Hot paths (offline) | brief --short 64 ms / 19 shimmed; footprint 667 / 257; governance 104 / 42; doctor 2,142 ms / 804 shimmed / 443 parsers / 2 gh | `tests/bench.sh --json`, 3 runs |

### 3.2 Active reasoning surface (observed, not inferred from location)

Evidence: file touches by the writer lane across three sessions (`raw/transcript-*.json`, T6), what the
runtime sources (`bin/spark` + `lib/*.sh`), what CI executes per push (workflow runs above), what the harness
loads every session (`CLAUDE.md` → `AGENTS.md`), and the CI/doc link graph in `raw/agent-docs-governance-truth.md`.
Coverage caveat: one writer lane, four days; reviewer lane and downstream users are not observed, so every
classification below is provisional and the UNKNOWN class is used where evidence is absent.

| Class | Surfaces | Evidence |
|---|---|---|
| HOT-PATH / CURRENT | `plugins/spark/bin/spark`, `plugins/spark/lib/*.sh` | executed by every verb; touched 47 (Sep) + 106 (Aug) and 62 (execution.sh) times |
| | `AGENTS.md`, `CLAUDE.md` | auto-loaded into every session (292 lines) |
| | `tests/run.sh`, `tests/lib.sh`, and the suites under repair | 212 targeted + 48 full runs across A and B |
| | `plugins/spark/docs/reference/cli.md` | reconciled every round (11 + 22 touches); reviewer-cited |
| | `ROADMAP.md`, `docs/releases/v0.23*.md` | read by the `docs-truth` CI check on every push; 5 + 9 and 18 + 3 touches |
| | `.github/workflows/*`, `.github/scripts/openai-review/*` | run on every push (16 / 32 runs per workflow) |
| | `.spark/state.json` | read by the runtime; cited by the reviewer |
| REACHABLE ON DEMAND | `docs/adr/*` | touched only while authoring ADR-0032 (6) and citing 0019/0027 (3, 2) |
| | `plugins/spark/skills/*/SKILL.md`, `references/` | `ship/SKILL.md` 18 touches in A only because the PR changed it; no skill invocation observed |
| | `plugins/spark/preferences/*` | `cli-stability.tsv` 2 touches; otherwise read by doctor/runtime only |
| | `docs/ops/*` | `execution-configuration-surface.md` 31 touches in B because it was B's deliverable; 11 of 18 ops docs are reachable only from a test existence assertion |
| | `plugins/spark/docs/{how-to,tutorials,explanation}`, `docs/architecture` | `sdlc-doctrine.md` 3; others untouched |
| HISTORICAL / NON-OPERATIVE | `docs/releases/v0.17…v0.22*.md`, `docs/governance/{self-conformance-audit-v020,is-state-baseline-pre-v020}.md`, `docs/research/*`, `docs/alpha/*`, `evaluations/*/runs/*`, ADR-0003…0007 (vocabulary superseded), ADR-0023…0026 (machinery retired) | untouched in all observed sessions; linked from ROADMAP/docs index as chronology |
| GENERATED / VENDOR / BUILD | `CHANGELOG.md` (Release Please), `.release-please-manifest.json`, `assets/logo/*.png` | tool-owned or rendered |
| UNKNOWN | companions `plugins/spark-{audit,connect,docs}` (1,563 LOC), `plugins/spark/skills/*/scripts` (2,055 LOC), `evaluations/` harness + fixtures, `.github` issue/PR templates, the 7 untouched `docs/ops` files | shipped or executable, but no consumption observed in these sessions; `docs/ops/evaluation.md` itself says nothing enforces the evaluation contract |

The observed hot path is small: 12,881 runtime LOC + the contract + the files under repair + the CI scripts.
Tests are 31.6 % of the tree, and 91 suites × 161 s is the cost every full certification pays regardless of
what changed.

### 3.3 Duplicate-truth baseline (code)

Full audit with file:line evidence: `raw/agent-duplicate-truth-code.md`. Structural finding: **there is no
shared GitHub-transport helper**; every consumer opens its own `gh` call and its own parse.

| Concept | Operative definitions | Likely canonical primitive | Drift / fan-out risk |
|---|---:|---|---|
| Repository identity | 8 | `lib/repository.sh: repo_locator_normalize` (3 verbatim `gh repo view --json nameWithOwner` copies in `bin/spark`) | HIGH |
| Issue / work-unit identity | 7 | `bin/spark: issue_refs` (closing-ref regex exists twice with different tolerance) | HIGH |
| Canonical identifiers (SHA 4, trunk 8) | 12 | `claude-lane/lib.sh: cl_check_stale_head`; `bin/spark: repo_trunk` (two `release-please--branches--master` literals) | HIGH |
| GitHub transport / parsing | ~14 (10 wrappers, 4 fallback parsers) | none — no `gh_api()` | HIGH |
| Pagination / list collection | 6 strategies, ~20 sites; 5 silent-truncation sites | `bin/spark: di_linked_prs` (only fail-closed cursor loop) | HIGH |
| Authority / permission | 7 (association literal, bot-login literal, locator equality, command allowlist ×2) | `claude-lane/lib.sh: cl_resolve_publication` | MED |
| Collaborator permission API | 0 in shipped code at this SHA (the #727 branch introduces it) | — | n/a |
| Reviewer verdict representation | 6 marker surfaces + 3 vocabularies (`TELEMETRY_VERDICTS` adds `FAIL`) | `openai-review/lib.sh: orl_marker` (sole emitter) | MED / HIGH |
| Acceptance representation | 0 parsers (prose only); docs-impact proxy 2 | — | LOW / MED |
| Exact-HEAD / staleness | 4 head-staleness + 3 other senses of "stale" | `cl_check_stale_head` | MED |
| Parent / sub-issue state | 5 (GraphQL `subIssues` and REST `sub_issues` both live; two REST loops in one function) | `bin/spark: milestone_snapshot` | HIGH |
| True dependency state | 7 (3 `blocked_by` readers: one paginates, one filters cross-repo) | `bin/spark:4535` | HIGH |
| Milestone / release placement | ~13 (4 "which milestone", 4 "what version", 4 "where is the release PR") | `milestone-gate.sh:87` | HIGH — highest fan-out |
| Required checks | 8 readers; **4 disagreeing literal name sets** (`docs-truth doctor gate tests` ×2, `doctor tests docs-truth`, ruleset `doctor,tests`, shipped template `validate`) | `orl_checks_terminal/passed` | HIGH |
| Governance / reference truth in code | 6 clusters; doctor ships two reconcilers (label and CLI vocabularies) | — | MED (policed duplicates) |

### 3.4 Test baseline — representation versus assurance

Full inventory per suite: `raw/agent-test-representation.md`. Headline facts: 91 suites, 19,246 LOC, 3,799
assertions executed in 161 s; 26 suites build a private `gh` stub on disk, 34 a private `PATH` shim, 82 a temp
fixture (68 via the shared `sandbox_init`); 10 suites do not source `tests/lib.sh` at all; **22 suites carry a
byte-identical `assert_eq` (381 call sites) that `lib.sh` does not offer**; 12 redefine `ok`/`bad`; 88 of 91
have explicit negative controls; 11 use the shared `mutant_runtime` guard-the-guard helper; 0 suites touch real
`gh` or the network; 53 are pure bash, 23 use python3, 32 use jq.

Same-invariant candidate groups (audit only; each note records the discrimination that must survive):
C1 governance resolution (10 suites; the exclusive-row assertion is duplicated at `test-governance-contract.sh:141`
and `test-docs-impact.sh:324`, the rest carry distinct boundaries); C2 telemetry counters (3; `execution-count-race`
holds the only concurrency control); C3 docs truth (5; layered — `readme-product-truth` exists because
`docs-truth` missed v0.22); C4 doctor exit contract (4 + 2 budget suites; the near-duplicate pair is
`context-budget` vs `footprint-budget`); C5 footprint/budget/latency/memo (6; `budget-record-framing` is a
security invariant misgrouped by name); C6 `next` gating (4; possible overlap with `release-gate-role`, UNKNOWN);
C7 release-notes (3; fixture duplication certain, invariant overlap UNKNOWN).

### 3.5 Docs and governance baseline

Full audit: `raw/agent-docs-governance-truth.md`. Dev prose (11,185 LOC) is 1.45× the shipped prose surface
(7,689 LOC). Hand-maintained current copies per concept: lifecycle stages + nine skills **13**; attribution /
literal `jwogrady` rule **10**; commit rules with `72` hard-coded **8** (while `defaults.json` treats it as a
preference); release process **7**; delivery model **4 + an exported template** that contradicts AGENTS.md
(`conventions.md:38` "Declare the dependency on the issue (`Blocked by #A`)" versus "prose does not create a
dependency"); four tiers 4; CLI verb list 4 (3 mechanically locked by doctor); merge authority / #677 4
near-disjoint statements and **no canonical definition of "#677 standing orchestration" in the tree**; version
claims 4 (coherent); reviewer verdict vocabulary 3 (closed in code); benchmark vocabulary 2 (parity-tested);
Status26 naming 1 (two mechanical guards). Nine verified stale/incomplete statements, including
`reference/stability.md:57` (Experimental row lists 5 verbs, tsv classifies 7; doctor checks only the Stable row),
`docs/README.md` omitting ADR-0030 and two shipped reference pages, and `plugins/spark/docs/README.md` with no
how-to for `onboard`. Zero broken relative links; zero phantom verbs or skills.

### 3.6 Dead / stale candidates and surfaces that must not be removed

Candidates (audit only — no deletion target is set here):

- 109 remote branches already ancestors of `master` (`raw/branches.tsv`), plus squash-merged branches that
  ancestry cannot classify (#744 scope).
- The 10 concrete code duplicate pairs in §3.3's source report, led by the four disagreeing required-check sets
  and the wholesale duplicated `gate-runner.sh` / `release-notes-runner.sh` pipeline.
- 7 partially-superseded and 4 retired-machinery ADRs still listed inline in the current ADR index.
- The nine stale/incomplete doc statements in §3.5; the stale `tests/test-commit-msg.sh:60` comment.
- `evaluations/` (1,606 LOC) — UNKNOWN, not dead: no observed run, and its own contract doc says nothing
  enforces it.
- 22 private `assert_eq` copies and 26 private `gh` stubs in tests (#740 scope).

Surfaces that look historical or orphaned but evidence says must **not** be removed without a change elsewhere:

- `docs/ops/v0.21-dogfood-evaluation.md` — the default input of live CI (`.github/scripts/ledger-truth-check.sh:54`).
- `docs/ops/openai-reviewer-lane.md` — zero inbound Markdown links, yet it documents the live reviewer lane.
- `docs/governance/capability-evaluation.md` — linked from the shipped `release-docs-checklist.md`.
- `docs/ops/execution-configuration-surface.md` — the most reviewer-cited doc in B (14 of 32 rounds).
- `docs/releases/*` — the chronology owners ROADMAP links to; the release records own version truth.
- ADR-0004…0007 — superseded in vocabulary only; still the record of the decisions.

### 3.7 NOT ASSESSED (#737)

- Exact per-suite subprocess counts (bench covers command hot paths; the runner reports seconds only).
- Consumption by the reviewer lane, by downstream projects, and by the companion plugins.
- Whether any `evaluations/` run is current.
- Bytes of context consumed per repository file (the transcript records tool-result sizes, not per-file
  attribution for shell reads).
- Static assertion count precision (±5 %; runtime count is the authority).

## 4. Reproduction

```
# measured system
git worktree add --detach /tmp/spark-921c982 921c9820b92e99ef3620f4f46a0a8a6d7bb0c8b5
bash docs/research/v0.23-optimization-baseline/tools/footprint.sh /tmp/spark-921c982
(cd /tmp/spark-921c982 && bash tests/run.sh --json && bash tests/bench.sh --json && bash tests/structure.sh --json)
# GitHub evidence
bash tools/fetch-pr.sh 727 726 raw/pr727 && bash tools/fetch-commits.sh raw/pr727 && python3 tools/analyze-pr.py raw/pr727 727
bash tools/fetch-pr.sh 724 722 raw/pr724 && bash tools/fetch-commits.sh raw/pr724 && python3 tools/analyze-pr.py raw/pr724 724
# writer-lane consumption (requires the session records; paths inside the scripts)
python3 tools/make-windows.py && python3 tools/analyze-transcript.py <session.jsonl> raw/windows-workloads.json raw/transcript-workloads.json
python3 tools/render-tables.py raw > tables.md
```

`tests/run.sh` was executed exactly once for this baseline; every number quoted from it is a projection of
that one run (`raw/run-full.json`, `raw/run-full.meta`).

## 5. Acceptance evaluation (from current GitHub truth, not from this report's existence)

**#730** — baseline captured before snapshot-first changes (master unchanged at 921c982): yes. Exact SHA,
fixture identity, configuration and method recorded: yes (§0, §1). One #727 slice and one other workload: yes
(A, B). Unique vs repeated reads/requests distinguishable: yes (T1, T5). Contract-required vs
repeated/avoidable: yes (§2.5). Whole path measured including collection/parsing/CI: yes. Dominant repeated-read
and rehydration surfaces identified: yes (§2.3) — the suspected problem is established for the writer lane, with
the caveat that it is one lane's record. Durable and pointable from #728/#729/#480: via the #730 comment and
this committed evidence. No correctness/evidence/authority surface skipped: none touched.

**#737** — frozen on an exact SHA before cleanup: yes. Reproducible commands and explicit limitations: yes.
Physical and hot-path reported separately: yes (§3.1 vs §3.2). Major categories mutually explained, omissions
called out: yes (389/389 files bucketed; UNKNOWN class explicit). Test surface with files/LOC, assertions and
verification cost: yes. Active vs historical distinguished where observation supports it: yes, provisionally.
Duplicate-definition baseline pointable for #739/#741/#745: yes (§3.3, §3.5 and the two source audits).
Durable and pointable: via the #737 comment and this committed evidence.

Durability caveat for both: this evidence lives on branch `chore/730-737-baseline-measurement`; it becomes
permanent when that branch is merged under the standing governance, which is outside this task.
