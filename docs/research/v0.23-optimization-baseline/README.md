# v0.23 optimization baseline — the BEFORE side (#730, #737)

Baseline measurement evidence for the two v0.23 optimization trees, #728 (compiled fact snapshots) and
#729 (reasoning-surface cleanup). Everything in this directory is **measurement and reporting only**: nothing
changes Spark's behavior, and nothing was produced by changing the measured system.

The evidence lands in three PRs so that each diff fits the independent reviewer's 200,000-byte cap and can be
reviewed completely:

| Bundle | Files | Landed via |
|---|---|---|
| #730 analysis (this file, `tables.md`, `raw/pr*/derived.compact.json`, `raw/transcript-*`, `raw/findings-classification.tsv`, `tools/`) | this PR | PR #747 |
| #730 reviewer finding text of record (`raw/pr727/findings.txt`, `raw/pr724/findings.txt`, verbatim and complete) | companion | PR "chore/730-reviewer-findings-text" |
| #737 repository baseline (`repository-baseline.md`, `raw/footprint.txt`, `raw/run-full*`, `raw/bench*`, `raw/structure*`, `raw/branches.tsv`, `raw/agent-*.md`, `raw/transcript-aug.compact.json`, `tools/footprint.sh` …) | companion | PR "chore/737-repository-baseline" |

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
| Freeze comments | #730 comment 5560565518 (`raw/freeze-comment-730.md`), #737 comment 5560565620 |
| Ordering | The #728/#729 native sub-issue normalization happened **before** the freeze (metadata only). No #731–#736, #746 or #738–#745 work has begun. |

## 1. Instrumentation versus measured system

- **Measured system**: the frozen SHA above, checked out as a detached worktree. Nothing in the evidence
  branches is measured; every repository number is taken from that worktree.
- **Instrumentation**: `tools/` in this directory, versioned by the commit that adds it. It is not part of the
  measured system and was created *after* the freeze comments were posted.
- **Reused machinery** (#609/#614/#722 discipline, not reinvented): `tests/run.sh --json` (one execution, one
  projection), `tests/bench.sh --json` (shimmed/parsers/gh invocation counts with their documented limits),
  `tests/structure.sh --json` (textual reference graph).
- **Consumption evidence**: the writer lane's own Claude Code session records, which log every tool call, every
  tool result, and the API's per-request token accounting. Two sessions: `c172f4f1…` (2026-09-04T16:13Z →
  2026-09-06T16:28Z, contains both measured workloads) and `0399c476…` (2026-08-30/31, other v0.23 work, used only
  as extra hot-path evidence for #737). Models observed, per API request: workload A 558× `claude-opus-5`;
  workload B 848× `claude-opus-5` + 143× `claude-opus-4-8`; Claude Code 2.1.260/2.1.261. These records are
  session-local and are **not** authority evidence; the numbers extracted from them are committed here so they
  are pointable. `raw/transcript-rounds.tsv` (one row per verdict window, every counter) and
  `raw/transcript-workloads.compact.json` are the committed projections; `tools/analyze-transcript.py` produces
  them from the session record.
- **GitHub evidence**: fetched by `tools/fetch-pr.sh` and `tools/fetch-commits.sh` (REST). The raw JSON is
  re-fetchable and is not committed; `raw/pr*/derived.compact.json` carries every derived fact, including the
  id and URL of each reviewer comment of record. The verbatim, complete finding text (whole bullet blocks,
  including continuation lines and sub-bullets) is committed in the companion PR as `raw/pr*/findings.txt`
  (`tools/dump-findings.py`), with `findings-validation.txt` proving every block is a substring of the live
  comment body (`tools/validate-findings.py`). `tables.md` is rendered from the committed compact projections
  alone; every tool takes its input directory as an argument.

## 2. #730 — effective reasoning surface and context amplification

### 2.1 Workloads

| | Workload A | Workload B | Workload C |
|---|---|---|---|
| Unit | PR #727 (issue #726, bounded-increment merge authority), rounds 1–16 to HEAD `e3ced28` | PR #724 (issue #722, per-process memoization), rounds 1–32 to PASS and merge (`cdc04a5`) | Rehydration control: (i) repeat rounds on unchanged non-HEAD facts inside A and B; (ii) mechanical: `tests/bench.sh` live paths |
| Why representative | The `CHANGES REQUIRED` repair/review slice #730 requires; the PR that exposed the suspected representation problem | Same reviewer lane, same repository, same writer lane, materially different subject (runtime hot path + benchmark harness + ops doc), and it reached a terminal PASS — so it shows a complete loop, not a truncated one | Facts such as repo identity, milestone, parent, gate, authority and contract did not change during either workload; C measures how much of them was still fetched or re-derived |
| Boundary | Whole path: repository reads, GitHub reads, verification, evidence reconstruction, CI, review iterations | Same | Same |
| Cold/warm | Warm: one continuous session; A began in the same session right after B merged | Warm: the window opens 2h18m before the first commit to include orientation | — |

### 2.2 Baseline table

Per-workload totals are `tables.md` T1 (with method column); per-round detail is T2. Deterministic counts are
exact for what the records contain; token figures are the API's own accounting and are observational.
The rows below add the control and session-start facts that T1 does not carry.

| Workload / Surface | Frozen state | Metric | Before value | Method | Evidence | Confidence / limitation |
|---|---|---|---:|---|---|---|
| A: #727 | e3ced28 | commits / changed lines / files; verdicts; findings (repeats) | 20 / 6,417 / 12; 16 × CHANGES REQUIRED; 50 (8) | GitHub REST | `raw/pr727/derived.compact.json`, T1 | exact; repeat lineage is judgment |
| A | | active wall clock (idle excluded) / push→verdict median | 10,820 s (+51,023 s idle) / 13 s | commit and marker times | derived, T1 | exact |
| A | | API requests / tool calls / tool-result bytes | 558 / 529 / 290,841 | session record | `raw/transcript-workloads.compact.json` | exact, writer lane only |
| A | | gh invocations (LB) / unique / repeated; HEAD-independent / HEAD-dependent | 110 / 34 / 76; 12 / 34 | endpoint normalization | transcript, T5 | lower bound |
| A | | targeted / full-suite / doctor runs | 109 / 0 / 10 | command classification | transcript | exact |
| A | | context tokens processed; per request; per changed line | 168,731,098; 302,385; 26,294 | API usage | transcript, T1 | observational |
| B: #724 | cdc04a5 | commits / changed lines / files; verdicts; findings (repeats) | 34 / 2,314 / 4; 31 × CHANGES REQUIRED + PASS; 76 (11) | GitHub REST | `raw/pr724/derived.compact.json`, T1 | exact |
| B | | active wall clock / push→verdict median | 18,289 s / 11 s | as above | derived | exact |
| B | | API requests / tool calls / tool-result bytes | 991 / 884 / 332,602 | session record | transcript | exact |
| B | | gh (LB) / unique / repeated; HEAD-independent / HEAD-dependent | 152 / 39 / 113; 18 / 57 | as above | transcript, T5 | lower bound |
| B | | targeted / full-suite / doctor runs | 103 / **48** / 20 | as above | transcript | exact |
| B | | context tokens processed; per request; per changed line | 582,515,671; 587,805; 251,735 | API usage | transcript, T1 | observational; the window inherits earlier session context |
| C (mechanical) | 921c982 | `gh` invocations per run: governance validate / triage / doctor | 10 / 16 / 2 (3 runs → 30 / 48 / 6) | `tests/bench.sh --json` | `raw/bench.json` (#737 bundle) | gh invocations, not HTTP requests |
| C (mechanical) | 921c982 | wall ms per run (live): governance validate / triage / doctor | 4,997 / 7,225 / 2,142 | bench.sh | bench.json | observational (network) |
| C (in-workload) | A | rounds with a HEAD-independent fetch after round 1 | 2 of 15 (r5: 9, r8: 3) | per-round record | `raw/transcript-rounds.tsv` | reviewer-demanded read-backs of #726/#481 |
| C (in-workload) | B | HEAD-independent fetches in round 1 / later | 16 / 2 | per-round record | transcript-rounds.tsv | orientation is front-loaded |
| C (in-workload) | A | PR record re-read (`gh pr view 727`) | 21 fetches in 16 rounds | endpoint counts | T5 | only `.head.sha` changes between rounds |
| C (in-workload) | B | PR conversation re-read (`issues/724/comments`) | 51 fetches in 32 rounds | endpoint counts | T5 | contract needs ≈1 per round |
| C (in-workload) | A | runtime file re-read (`execution.sh` / `bin/spark`) in later rounds | 9 of 16 rounds | per-round record | transcript-rounds.json (session-local; TSV carries counts) | region reads via `sed -n` |
| Session start | every session | agent contract auto-loaded (`CLAUDE.md` → `AGENTS.md`) | 292 lines / 15,433 bytes | `tools/footprint.sh` | `raw/footprint.txt` (#737 bundle) | before any task work |

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

Source of record: the reviewer comments listed in `tables.md` T7 (comment id + URL per round, also in
`raw/pr*/derived.compact.json`); their finding bullets are committed verbatim and complete as
`raw/pr727/findings.txt` and `raw/pr724/findings.txt` in the companion PR. One row per bullet in
`raw/findings-classification.tsv` (finding id = round.bullet), classified by hand:

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

Reported separately in `repository-baseline.md` (companion PR), with its raw evidence under `raw/`.

## 4. Reproduction

All commands run from the **repository root**; `BASE` is this directory.

```
BASE=docs/research/v0.23-optimization-baseline
# GitHub evidence (re-fetches the raw JSON that is not committed)
bash $BASE/tools/fetch-pr.sh 727 726 $BASE/raw/pr727 && bash $BASE/tools/fetch-commits.sh $BASE/raw/pr727
bash $BASE/tools/fetch-pr.sh 724 722 $BASE/raw/pr724 && bash $BASE/tools/fetch-commits.sh $BASE/raw/pr724
python3 $BASE/tools/analyze-pr.py $BASE/raw/pr727 727 && python3 $BASE/tools/dump-findings.py $BASE/raw/pr727 727
python3 $BASE/tools/analyze-pr.py $BASE/raw/pr724 724 && python3 $BASE/tools/dump-findings.py $BASE/raw/pr724 724
python3 $BASE/tools/validate-findings.py $BASE/raw/pr727 727   # proves findings.txt against the live comment bodies
python3 $BASE/tools/validate-findings.py $BASE/raw/pr724 724
# writer-lane consumption (needs the session record; the two window files are committed)
python3 $BASE/tools/make-windows.py $BASE/raw    # regenerates both window files from derived*.json
python3 $BASE/tools/analyze-transcript.py <session.jsonl> $BASE/raw/windows-workloads.json $BASE/raw/transcript-workloads.json
python3 $BASE/tools/analyze-transcript.py <session.jsonl> $BASE/raw/windows-rounds.json $BASE/raw/transcript-rounds.json
python3 $BASE/tools/compact-transcript.py $BASE/raw
# tables
python3 $BASE/tools/render-tables.py $BASE/raw > $BASE/tables.md
# measured system (#737 bundle)
git worktree add --detach /tmp/spark-921c982 921c9820b92e99ef3620f4f46a0a8a6d7bb0c8b5
bash $BASE/tools/footprint.sh /tmp/spark-921c982
```

The scripts carry the paths of the session records they were run against; without those records the transcript
step cannot be replayed, which is why its projections are committed.

## 5. Acceptance evaluation for #730 (from current GitHub truth, not from this report's existence)

Baseline captured before snapshot-first changes (master unchanged at 921c982): yes. Exact SHA, fixture identity,
configuration and method recorded: yes (§0, §1). One #727 slice and one other workload: yes (A, B). Unique vs
repeated reads/requests distinguishable: yes (T1, T5). Contract-required vs repeated/avoidable: yes (§2.5).
Whole path measured including collection/parsing/CI: yes. Dominant repeated-read and rehydration surfaces
identified: yes (§2.3) — the suspected problem is established for the writer lane, with the caveat that it is one
lane's record. Durable and pointable from #728/#729/#480: via the #730 comment and this committed evidence. No
correctness/evidence/authority surface skipped: none touched.

Durability caveat: the evidence becomes permanent when the three PRs are merged under the standing governance,
which is a separate decision.
