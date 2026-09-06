## T1 — Workload summary (GitHub evidence + writer-lane transcript)

| Metric | A: PR #727 (#726) | B: PR #724 (#722) | Method |
|---|---:|---:|---|
| commits | 20 | 34 | GitHub REST, derived.json |
| lines added | 4,570 | 1,858 | GitHub REST, derived.json |
| lines deleted | 1,847 | 456 | GitHub REST, derived.json |
| distinct files touched | 12 | 4 | GitHub REST, derived.json |
| marked reviewer attempts (all logins, chronological) | 16 | 35 | GitHub REST, derived.json |
|   trusted exact-HEAD verdicts (reviewer lane login) | 16 | 32 | GitHub REST, derived.json |
|   relayed attempts (marker posted by another login) | 0 | 3 | GitHub REST, derived.json |
| blocking findings (list items / prose of non-PASS attempts) | 50 | 81 | GitHub REST, derived.json |
|   in trusted attempts | 50 | 76 | GitHub REST, derived.json |
|   in relayed attempts | 0 | 5 | GitHub REST, derived.json |
| evidentiary bullets in the PASS comment (not findings) | 0 | 4 | GitHub REST, derived.json |
| writer top-level PR comments (marker relays excluded) | 29 | 43 | GitHub REST, derived.json |
| writer comment chars | 123,211 | 87,230 | GitHub REST, derived.json |
| reviewer body chars (all attempts) | 32,454 | 53,537 | GitHub REST, derived.json |
| formal PR reviews (human) | 2 | 0 | GitHub REST, derived.json |
| verdict outcome | 16× CHANGES REQUIRED, no PASS (open at cutoff) | 31× CHANGES REQUIRED → PASS, merged at cutoff | derived verdict_counts; state as of the observation cutoff |
| wall clock first commit → last verdict (s) | 61,843 | 18,289 | commit author date → verdict comment created_at |
| of which idle gaps >30 min (s) | 51,023 | 0 | inter-verdict intervals > 1800s |
| active wall clock (s) | 10,820 | 18,289 | wall minus idle gaps |
| push → verdict latency median (s) | 13.0 | 11.0 | head commit date → marker created_at |
| CI workflow 'OpenAI Review' runs / seconds | 16 / 1812 | 32 / 3618 | actions/runs on the PR branch |
| CI workflow 'validate' runs / seconds | 16 / 3048 | 32 / 5925 | actions/runs on the PR branch |
| CI workflow 'milestone-gate' runs / seconds | 16 / 875 | 32 / 1681 | actions/runs on the PR branch |
| CI workflow 'docs-truth' runs / seconds | 16 / 145 | 32 / 283 | actions/runs on the PR branch |
| model API requests (assistant turns) | 558 | 991 | session transcript (writer lane), analyze-transcript.py |
| tool calls | 529 | 884 | session transcript (writer lane), analyze-transcript.py |
| tool-result bytes returned to the model | 290,841 | 332,602 | session transcript (writer lane), analyze-transcript.py |
| Read tool calls | 16 | 148 | session transcript (writer lane), analyze-transcript.py |
|   Read-tool unique paths | 9 | 98 | session transcript (writer lane), analyze-transcript.py |
|   Read-tool repeated reads | 7 | 50 | session transcript (writer lane), analyze-transcript.py |
| shell read commands (sed/grep/cat over repo files) | 64 | 84 | session transcript (writer lane), analyze-transcript.py |
| combined unique paths (Read-tool paths + repo paths named in shell reads) | 24 | 101 | session transcript (writer lane), analyze-transcript.py |
| combined repeated path touches | 35 | 79 | session transcript (writer lane), analyze-transcript.py |
| Bash calls | 342 | 548 | session transcript (writer lane), analyze-transcript.py |
| gh invocations (lower bound) | 110 | 152 | session transcript (writer lane), analyze-transcript.py |
|   unique normalized endpoints | 34 | 39 | session transcript (writer lane), analyze-transcript.py |
|   repeated endpoint fetches | 76 | 113 | session transcript (writer lane), analyze-transcript.py |
|   HEAD-independent fact fetches (authority/parent/milestone/identity) | 12 | 18 | session transcript (writer lane), analyze-transcript.py |
|   HEAD-dependent fetches (PR conversation, checks) | 34 | 57 | session transcript (writer lane), analyze-transcript.py |
| targeted verification runs (run.sh --only / single suite) | 109 | 103 | session transcript (writer lane), analyze-transcript.py |
| full-suite certification runs | 0 | 48 | session transcript (writer lane), analyze-transcript.py |
| spark doctor runs | 10 | 20 | session transcript (writer lane), analyze-transcript.py |
| bash -n runs | 16 | 21 | session transcript (writer lane), analyze-transcript.py |
| Edit/Write calls on repo files | 89 | 115 | session transcript (writer lane), analyze-transcript.py |
|   unique repo files edited | 11 | 5 | session transcript (writer lane), analyze-transcript.py |
| subagents spawned | 3 | 0 | session transcript (writer lane), analyze-transcript.py |
| context tokens re-read from cache (sum over requests) | 167,893,724 | 581,032,586 | session transcript (writer lane), analyze-transcript.py |
| context tokens newly cached | 836,258 | 1,481,103 | session transcript (writer lane), analyze-transcript.py |
| uncached input tokens | 1,116 | 1,982 | session transcript (writer lane), analyze-transcript.py |
| output tokens | 559,072 | 476,609 | session transcript (writer lane), analyze-transcript.py |
| context tokens processed (cache_read+cache_create+input) | 168,731,098 | 582,515,671 | observational (API usage accounting) |
|   mean context per request | 302,385 | 587,805 | observational |
|   context tokens per changed line (amplification) | 26,294 | 251,735 | observational; changed lines = additions+deletions |
|   context tokens per output token | 301 | 1,222 | observational |

## T2 — Per-round detail (verdict window = previous verdict → this verdict)


### PR #727

| round | head | verdict | findings | files cited by reviewer | push→verdict s | round wall s | API req | tool calls | gh (LB) | stable | head-dep | tests tgt/full | doctor | edits | ctx tokens |
|---:|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|
| 1 | f8c825d | CHANGES REQUIRED | 4 | 0032-bounded-increment-merge-authority.md, execution.sh, test-merge-authority.sh | 52 | 340 | 77 | 75 | 7 | 0 | 0 | 15/0 | 3 | 14 | 14,566,506 |
| 2 | 073fbd7 | CHANGES REQUIRED | 4 | 0032-bounded-increment-merge-authority.md, execution.sh, SKILL.md, test-merge-authority.sh | 13 | 317 | 25 | 24 | 1 | 0 | 0 | 1/0 | 2 | 9 | 5,945,635 |
| 3 | 3735edd | CHANGES REQUIRED | 4 | execution.sh, test-merge-authority.sh | 13 | 274 | 21 | 20 | 4 | 0 | 1 | 3/0 | 0 | 9 | 5,369,189 |
| 4 | c1ed999 | CHANGES REQUIRED | 3 | execution.sh | 9 | 598 | 41 | 39 | 12 | 0 | 3 | 4/0 | 1 | 11 | 11,624,366 |
| 5 | 2abdd5e | CHANGES REQUIRED | 3 | execution.sh, test-merge-authority.sh | 15 | 446 | 25 | 24 | 16 | 9 | 1 | 2/0 | 1 | 4 | 7,900,643 |
| 6 | bc1f5ff | CHANGES REQUIRED | 3 | execution.sh, test-merge-authority.sh | 11 | 561 | 26 | 23 | 4 | 0 | 1 | 5/0 | 0 | 2 | 8,936,799 |
| 7 | a1f6174 | CHANGES REQUIRED | 4 | cli.md, execution.sh, bounded-merge.md, test-merge-authority.sh | 11 | 1319 | 36 | 33 | 3 | 0 | 0 | 6/0 | 0 | 2 | 14,743,149 |
| 8 | eedd339 | CHANGES REQUIRED | 4 | execution.sh | 12 | 1536 | 57 | 56 | 15 | 3 | 1 | 10/0 | 1 | 0 | 29,350,273 |
| 9 | 6e9206e | CHANGES REQUIRED | 3 | execution.sh | 12 | 792 | 27 | 24 | 5 | 0 | 1 | 5/0 | 0 | 0 | 16,129,184 |
| 10 | cd3eafd | CHANGES REQUIRED | 4 | execution.sh | 19 | 51023 | 69 | 68 | 3 | 0 | 1 | 18/0 | 1 | 14 | 11,975,796 |
| 11 | 549a709 | CHANGES REQUIRED | 2 |  | 14 | 1206 | 27 | 27 | 4 | 0 | 2 | 7/0 | 0 | 10 | 5,539,076 |
| 12 | f4ebacc | CHANGES REQUIRED | 3 | execution.sh | 14 | 639 | 37 | 33 | 17 | 0 | 14 | 4/0 | 0 | 8 | 8,826,446 |
| 13 | d47d0e8 | CHANGES REQUIRED | 2 | cli.md, execution.sh | 17 | 827 | 29 | 27 | 6 | 0 | 3 | 9/0 | 0 | 5 | 7,925,075 |
| 14 | ee6cf2a | CHANGES REQUIRED | 2 | execution.sh, test-merge-authority.sh | 13 | 472 | 17 | 15 | 8 | 0 | 3 | 4/0 | 0 | 1 | 5,071,649 |
| 15 | 34b136b | CHANGES REQUIRED | 3 | execution.sh, cli-stability.tsv | 12 | 865 | 24 | 22 | 3 | 0 | 2 | 8/0 | 1 | 0 | 7,777,276 |
| 16 | e3ced28 | CHANGES REQUIRED | 2 | execution.sh, test-merge-authority.sh | 11 | 628 | 20 | 19 | 2 | 0 | 1 | 8/0 | 0 | 0 | 7,050,036 |

### PR #724

| round | head | verdict | findings | files cited by reviewer | push→verdict s | round wall s | API req | tool calls | gh (LB) | stable | head-dep | tests tgt/full | doctor | edits | ctx tokens |
|---:|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|
| 1 | e5a8c87 | CHANGES REQUIRED | 3 | test-hot-path-memo.sh | 208 | 208 | 104 | 95 | 45 | 16 | 4 | 7/3 | 0 | 7 | 34,161,425 |
| 2 | e2ca402 | CHANGES REQUIRED | 2 | test-hot-path-memo.sh | 17 | 617 | 18 | 16 | 1 | 0 | 1 | 5/1 | 0 | 4 | 7,233,161 |
| 3 | 38f7188 | CHANGES REQUIRED | 2 | test-hot-path-memo.sh | 10 | 560 | 16 | 13 | 2 | 0 | 2 | 3/1 | 0 | 3 | 6,651,166 |
| 4 | ff7a8ce | CHANGES REQUIRED | 2 | test-hot-path-memo.sh | 12 | 562 | 22 | 21 | 3 | 0 | 2 | 5/1 | 1 | 2 | 9,473,448 |
| 5 | a6dfde1 | CHANGES REQUIRED | 2 |  | 10 | 527 | 23 | 21 | 7 | 0 | 3 | 2/1 | 0 | 2 | 10,249,984 |
| 6 | 67743e4 | CHANGES REQUIRED | 2 | execution-configuration-surface.md, test-hot-path-memo.sh | 198 | 799 | 40 | 36 | 9 | 1 | 2 | 3/1 | 0 | 3 | 19,003,132 |
| 7 | cecbb5c | CHANGES REQUIRED | 3 | state.json, execution-configuration-surface.md | 8 | 568 | 21 | 19 | 4 | 0 | 2 | 3/1 | 0 | 3 | 10,463,764 |
| 8 | 4c805d6 | CHANGES REQUIRED | 3 | execution-configuration-surface.md | 9 | 661 | 51 | 46 | 6 | 0 | 4 | 0/2 | 0 | 6 | 26,659,672 |
| 9 | 4a7b366 | CHANGES REQUIRED | 3 | test-hot-path-memo.sh | 11 | 537 | 55 | 49 | 6 | 0 | 2 | 2/5 | 0 | 5 | 30,796,121 |
| 10 | 0db6fa6 | CHANGES REQUIRED | 3 | execution-configuration-surface.md, test-hot-path-memo.sh | 9 | 689 | 55 | 49 | 4 | 0 | 2 | 11/3 | 0 | 3 | 32,923,675 |
| 11 | 6cc4d1f | CHANGES REQUIRED | 2 | execution-configuration-surface.md, bench-memo.sh, test-hot-path-memo.sh | 12 | 552 | 26 | 22 | 4 | 0 | 2 | 0/1 | 0 | 4 | 16,206,872 |
| 12 | e263f60 | CHANGES REQUIRED | 3 | bench-memo.sh, test-hot-path-memo.sh | 8 | 602 | 29 | 25 | 4 | 0 | 2 | 5/1 | 1 | 5 | 18,638,768 |
| 13 | ebea342 | CHANGES REQUIRED | 3 | execution-configuration-surface.md, bench-memo.sh | 11 | 536 | 18 | 16 | 2 | 0 | 2 | 2/1 | 1 | 4 | 11,888,711 |
| 14 | 568d6d7 | CHANGES REQUIRED | 2 | bench-memo.sh, test-hot-path-memo.sh | 11 | 551 | 18 | 16 | 2 | 0 | 2 | 0/1 | 1 | 5 | 12,109,780 |
| 15 | b1a44d4 | CHANGES REQUIRED | 2 | test-hot-path-memo.sh | 11 | 585 | 18 | 16 | 2 | 0 | 2 | 2/1 | 1 | 3 | 12,328,909 |
| 16 | c90da9e | CHANGES REQUIRED | 1 | bench-memo.sh | 12 | 541 | 21 | 19 | 3 | 0 | 2 | 5/1 | 1 | 2 | 14,655,076 |
| 17 | 9787cf1 | CHANGES REQUIRED | 2 | bench-memo.sh | 9 | 498 | 23 | 20 | 3 | 0 | 2 | 0/1 | 1 | 3 | 16,381,137 |
| 18 | 62b7746 | CHANGES REQUIRED | 3 | bench-memo.sh | 8 | 498 | 23 | 20 | 3 | 0 | 2 | 0/1 | 1 | 5 | 16,731,268 |
| 19 | 688a306 | CHANGES REQUIRED | 1 | bench-memo.sh | 10 | 553 | 26 | 23 | 2 | 0 | 2 | 2/2 | 1 | 5 | 19,474,201 |
| 20 | 9c6665d | CHANGES REQUIRED | 3 | execution-configuration-surface.md, test-hot-path-memo.sh | 14 | 489 | 18 | 15 | 2 | 0 | 2 | 0/1 | 2 | 1 | 13,775,799 |
| 21 | 475ff72 | CHANGES REQUIRED | 2 | bench-memo.sh, test-hot-path-memo.sh | 8 | 610 | 35 | 32 | 3 | 0 | 2 | 4/2 | 0 | 9 | 27,574,280 |
| 22 | e5dcf55 | CHANGES REQUIRED | 3 | execution-configuration-surface.md, test-hot-path-memo.sh | 11 | 615 | 33 | 29 | 2 | 0 | 1 | 4/2 | 1 | 6 | 26,739,539 |
| 23 | 4253779 | CHANGES REQUIRED | 2 | execution-configuration-surface.md, bench-memo.sh, test-hot-path-memo.sh | 10 | 601 | 26 | 23 | 2 | 0 | 1 | 5/1 | 1 | 6 | 21,627,077 |
| 24 | 0ef7d36 | CHANGES REQUIRED | 3 | test-hot-path-memo.sh | 10 | 630 | 29 | 26 | 2 | 0 | 1 | 11/1 | 1 | 2 | 24,864,265 |
| 25 | fb2accf | CHANGES REQUIRED | 3 | execution-configuration-surface.md, bench-memo.sh | 11 | 617 | 33 | 30 | 1 | 0 | 1 | 7/2 | 1 | 4 | 29,198,132 |
| 26 | 1bb345c | CHANGES REQUIRED | 2 | bench-memo.sh, test-hot-path-memo.sh | 10 | 632 | 30 | 25 | 2 | 0 | 1 | 0/2 | 1 | 2 | 27,170,037 |
| 27 | 02d88c7 | CHANGES REQUIRED | 3 | execution-configuration-surface.md, bench-memo.sh | 12 | 535 | 15 | 13 | 1 | 0 | 1 | 2/1 | 1 | 0 | 13,789,026 |
| 28 | 143bd9c | CHANGES REQUIRED | 3 | preferences.json, bench-memo.sh, test-hot-path-memo.sh | 9 | 383 | 18 | 16 | 1 | 0 | 1 | 0/1 | 1 | 0 | 16,755,745 |
| 29 | 7da4311 | CHANGES REQUIRED | 3 | preferences.json, execution-configuration-surface.md, bench-memo.sh, test-hot-path-memo.sh | 9 | 536 | 24 | 21 | 1 | 0 | 1 | 2/3 | 1 | 0 | 22,671,233 |
| 30 | 8718432 | CHANGES REQUIRED | 3 | execution-configuration-surface.md, bench-memo.sh | 16 | 692 | 44 | 41 | 3 | 0 | 1 | 10/1 | 1 | 2 | 24,302,442 |
| 31 | fba8de3 | CHANGES REQUIRED | 2 | execution-configuration-surface.md, bench-memo.sh, test-hot-path-memo.sh | 18 | 825 | 43 | 39 | 5 | 0 | 1 | 0/1 | 0 | 5 | 3,804,077 |
| 32 | cdc04a5 | PASS | 0 | bench-memo.sh | 18 | 480 | 16 | 15 | 1 | 0 | 0 | 1/0 | 0 | 4 | 1,743,036 |

Relayed attempts (marker posted by `jwogrady`, inside the trusted-round windows above): r26r on 1bb345c at 2026-09-05T21:30:58Z — CHANGES REQUIRED, 2 finding(s), kind findings (comment 5554916926); r27r on 02d88c7 at 2026-09-05T21:36:30Z — CHANGES REQUIRED, 2 finding(s), kind findings (comment 5554946668); r28r on 143bd9c at 2026-09-05T21:45:17Z — CHANGES REQUIRED, 1 finding(s), kind prose (comment 5554992763)

## T3 — Reviewer finding classification (hand-classified from every marked attempt's blocking findings; PASS evidentiary bullets excluded)

| category | meaning | A: #727 | B: #724 |
|---|---|---:|---:|
| IMPL | genuinely new implementation defect | 15 (30%) | 9 (11%) |
| REPR | representation / transport boundary defect | 17 (34%) | 6 (7%) |
| DUP | duplicated-semantic drift (two surfaces disagree) | 7 (14%) | 19 (23%) |
| STALE | stale / reconstructed-state defect | 3 (6%) | 0 (0%) |
| TEST | test-harness / fixture / instrument defect | 2 (4%) | 39 (48%) |
| GOV | governance / specification / evidence-contract ambiguity | 6 (12%) | 8 (9%) |
| **total classified** | | 50 | 81 |
| of which repeats of an earlier finding (same lineage, unfixed or partially fixed) | | 8 | 15 |

## T4 — Reviewer-cited files by round (revisit concentration)

- PR #727: `plugins/spark/lib/execution.sh` cited in 15/16 attempts; `tests/test-merge-authority.sh` cited in 8/16 attempts; `docs/adr/0032-bounded-increment-merge-authority.md` cited in 2/16 attempts; `plugins/spark/docs/reference/cli.md` cited in 2/16 attempts; `ship/SKILL.md` cited in 1/16 attempts
- PR #724: `tests/test-hot-path-memo.sh` cited in 20/35 attempts; `tests/bench-memo.sh` cited in 18/35 attempts; `docs/ops/execution-configuration-surface.md` cited in 14/35 attempts; `.spark/preferences.json` cited in 2/35 attempts; `.spark/state.json` cited in 1/35 attempts

## T5 — Repeated GitHub surfaces fetched by the writer lane (normalized endpoint → invocations, lower bound)


PR #727:

| endpoint | fetches | class |
|---|---:|---|
| `gh:pr view 727` | 21 | HEAD-dependent |
| `api:repos/{repo}/issues/727/comments` | 19 | HEAD-dependent |
| `gh:pr comment 727` | 11 | other |
| `gh:pr edit 727` | 8 | other |
| `gh:issue view 726` | 7 | HEAD-independent |
| `api:graphql` | 5 | HEAD-dependent |
| `api:repos/{repo}/issues/481/sub_issues` | 4 | HEAD-independent |
| `api:repos/{repo}/commits/{sha}/check-runs` | 4 | HEAD-dependent |
| `api:repos/$R/issues/481/sub_issues` | 3 | HEAD-independent |
| `api:repos/{repo}/commits/3735edd/check-runs` | 2 | HEAD-dependent |
| `api:repos/{repo}/issues/726` | 2 | HEAD-independent |
| `api:repos/$R/issues/726` | 2 | HEAD-independent |

HEAD-independent fetches by kind: {'authority/parent/placement issue': 12}; HEAD-dependent by kind: {'checks/runs for a head': 13, 'PR conversation': 21}

PR #724:

| endpoint | fetches | class |
|---|---:|---|
| `api:repos/{repo}/issues/724/comments` | 51 | HEAD-dependent |
| `gh:pr comment 724` | 14 | other |
| `gh:pr checks 724` | 13 | HEAD-dependent |
| `gh:pr view 724` | 7 | HEAD-dependent |
| `api:repos/{repo}/issues/$n` | 6 | other |
| `api:repos/{repo}/milestones/20` | 5 | HEAD-independent |
| `api:repos/{repo}/issues/677/comments` | 4 | HEAD-independent |
| `api:repos/{repo}/issues/480/sub_issues` | 4 | HEAD-independent |
| `gh:issue view 722` | 4 | HEAD-independent |
| `api:repos/{repo}/milestones/21` | 3 | HEAD-independent |
| `gh:issue comment 677` | 3 | HEAD-independent |
| `api:repos/{repo}/issues/723/comments` | 3 | HEAD-independent |

HEAD-independent fetches by kind: {'authority/parent/placement issue': 10, 'milestone': 8}; HEAD-dependent by kind: {'PR conversation': 55, 'checks/runs for a head': 2}

## T6 — Repository files touched by the writer lane (Read + Edit/Write + shell-read mentions)

- PR #727: `plugins/spark/lib/execution.sh` ×62; `plugins/spark/skills/ship/SKILL.md` ×18; `tests/test-merge-authority.sh` ×12; `plugins/spark/docs/reference/cli.md` ×11; `plugins/spark/skills/ship/references/bounded-merge.md` ×7; `docs/adr/0032-bounded-increment-merge-authority.md` ×6; `plugins/spark/bin/spark` ×5; `docs/adr/0019-human-directed-product-model.md` ×3
- PR #724: `tests/bench-memo.sh` ×43; `plugins/spark/bin/spark` ×41; `tests/test-hot-path-memo.sh` ×34; `docs/ops/execution-configuration-surface.md` ×31; `docs/releases/v0.23.md` ×3; `plugins/spark/lib/repository.sh` ×1
- Aug 30–31 session (different work, same lane): `plugins/spark/bin/spark` ×106; `plugins/spark/docs/reference/cli.md` ×22; `.claude/worktrees/fix-611-selector-order/plugins/spark/bin/spark` ×13; `ROADMAP.md` ×9; `tests/structure.sh` ×9; `plugins/spark/skills/plan/scripts/issue-manifest.sh` ×8; `tests/bench.sh` ×8; `.github/scripts/docs-truth.sh` ×7; `tests/test-ci-handoff.sh` ×6; `tests/run.sh` ×6

## T7 — Reviewer comments of record (every marked attempt; source for the classification)

- PR #727: r1 [5555345257](https://github.com/jwogrady/spark/pull/727#issuecomment-5555345257), r2 [5555370419](https://github.com/jwogrady/spark/pull/727#issuecomment-5555370419), r3 [5555393693](https://github.com/jwogrady/spark/pull/727#issuecomment-5555393693), r4 [5555443019](https://github.com/jwogrady/spark/pull/727#issuecomment-5555443019), r5 [5555478568](https://github.com/jwogrady/spark/pull/727#issuecomment-5555478568), r6 [5555522727](https://github.com/jwogrady/spark/pull/727#issuecomment-5555522727), r7 [5555624886](https://github.com/jwogrady/spark/pull/727#issuecomment-5555624886), r8 [5555747928](https://github.com/jwogrady/spark/pull/727#issuecomment-5555747928), r9 [5555811436](https://github.com/jwogrady/spark/pull/727#issuecomment-5555811436), r10 [5559975617](https://github.com/jwogrady/spark/pull/727#issuecomment-5559975617), r11 [5560093436](https://github.com/jwogrady/spark/pull/727#issuecomment-5560093436), r12 [5560155814](https://github.com/jwogrady/spark/pull/727#issuecomment-5560155814), r13 [5560233736](https://github.com/jwogrady/spark/pull/727#issuecomment-5560233736), r14 [5560278135](https://github.com/jwogrady/spark/pull/727#issuecomment-5560278135), r15 [5560358402](https://github.com/jwogrady/spark/pull/727#issuecomment-5560358402), r16 [5560416150](https://github.com/jwogrady/spark/pull/727#issuecomment-5560416150)  (ᴿ = relayed attempt)
- PR #724: r1 [5553496635](https://github.com/jwogrady/spark/pull/724#issuecomment-5553496635), r2 [5553558226](https://github.com/jwogrady/spark/pull/724#issuecomment-5553558226), r3 [5553615644](https://github.com/jwogrady/spark/pull/724#issuecomment-5553615644), r4 [5553673147](https://github.com/jwogrady/spark/pull/724#issuecomment-5553673147), r5 [5553725370](https://github.com/jwogrady/spark/pull/724#issuecomment-5553725370), r6 [5553807625](https://github.com/jwogrady/spark/pull/724#issuecomment-5553807625), r7 [5553862342](https://github.com/jwogrady/spark/pull/724#issuecomment-5553862342), r8 [5553926676](https://github.com/jwogrady/spark/pull/724#issuecomment-5553926676), r9 [5553978175](https://github.com/jwogrady/spark/pull/724#issuecomment-5553978175), r10 [5554048081](https://github.com/jwogrady/spark/pull/724#issuecomment-5554048081), r11 [5554101918](https://github.com/jwogrady/spark/pull/724#issuecomment-5554101918), r12 [5554159385](https://github.com/jwogrady/spark/pull/724#issuecomment-5554159385), r13 [5554208294](https://github.com/jwogrady/spark/pull/724#issuecomment-5554208294), r14 [5554258645](https://github.com/jwogrady/spark/pull/724#issuecomment-5554258645), r15 [5554313960](https://github.com/jwogrady/spark/pull/724#issuecomment-5554313960), r16 [5554362906](https://github.com/jwogrady/spark/pull/724#issuecomment-5554362906), r17 [5554407821](https://github.com/jwogrady/spark/pull/724#issuecomment-5554407821), r18 [5554454153](https://github.com/jwogrady/spark/pull/724#issuecomment-5554454153), r19 [5554505218](https://github.com/jwogrady/spark/pull/724#issuecomment-5554505218), r20 [5554549808](https://github.com/jwogrady/spark/pull/724#issuecomment-5554549808), r21 [5554606568](https://github.com/jwogrady/spark/pull/724#issuecomment-5554606568), r22 [5554663030](https://github.com/jwogrady/spark/pull/724#issuecomment-5554663030), r23 [5554718061](https://github.com/jwogrady/spark/pull/724#issuecomment-5554718061), r24 [5554776906](https://github.com/jwogrady/spark/pull/724#issuecomment-5554776906), r25 [5554833010](https://github.com/jwogrady/spark/pull/724#issuecomment-5554833010), r26 [5554889955](https://github.com/jwogrady/spark/pull/724#issuecomment-5554889955), r26rᴿ [5554916926](https://github.com/jwogrady/spark/pull/724#issuecomment-5554916926), r27 [5554937854](https://github.com/jwogrady/spark/pull/724#issuecomment-5554937854), r27rᴿ [5554946668](https://github.com/jwogrady/spark/pull/724#issuecomment-5554946668), r28 [5554971569](https://github.com/jwogrady/spark/pull/724#issuecomment-5554971569), r28rᴿ [5554992763](https://github.com/jwogrady/spark/pull/724#issuecomment-5554992763), r29 [5555018476](https://github.com/jwogrady/spark/pull/724#issuecomment-5555018476), r30 [5555076732](https://github.com/jwogrady/spark/pull/724#issuecomment-5555076732), r31 [5555149009](https://github.com/jwogrady/spark/pull/724#issuecomment-5555149009), r32 [5555189660](https://github.com/jwogrady/spark/pull/724#issuecomment-5555189660)  (ᴿ = relayed attempt)
