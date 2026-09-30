# #736 — paired snapshot benchmark: journey versus snapshot versus reuse

Historical record of the first measurements, taken 2026-09-30 UTC with `tests/bench-facts.sh` against
the compiler at the `feat/735-snapshot-first` head. It is the AFTER side of the developer-journey
question the #730 baseline posed; it is not the final #736 report, and §6 says what is still open.

## 1. Method

`tests/bench-facts.sh --issue <n> [--stub] [--json]` runs three arms back to back on **one**
repository/GitHub state, so they observe the same facts:

| Arm | What runs per round | What it stands for |
|---|---|---|
| journey | one raw read per surface the baseline showed being re-fetched: the record (`gh pr view` / `issues/N`), its comments (every page), its reviews, the check runs at its HEAD, the implemented issue with its children and blockers, the milestone, the standing-authority thread (every page), the repository, the trunk rules | the **contract-minimal** journey — one read per surface per round. The measured baseline exceeded it (README §2.5: 21 PR-record fetches in 16 rounds, 51 conversation fetches in 32), so a saving against this arm is a floor |
| snapshot | `spark facts --issue <n>` with no stored record, every round | snapshot mode, reuse disabled; round 2 repeating round 1 is the "disabling reuse restores the reads" control |
| reuse | `spark facts --issue <n> --delta`: round 1 cold, round 2 warm against round 1's record | snapshot-first with the #735 delta; the compiler still reads every source (P4) |

Counts: **requests** are gh invocations, and here one invocation is one HTTP request *by construction*
— the journey pages explicitly (`per_page=100&page=k`) and the compiler never passes `--paginate` — so
the figure is exact, not the lower bound `tests/bench.sh` reports. **bytes** are what each arm returned
to its consumer on stdout: what an agent would have to read. **ms** is wall time per arm-round and is
observational (network in live mode, host in stub mode). The snapshot arms also report the compiler's
own telemetry (`facts_api_calls`, `facts_output_bytes`, `facts_output_shape`, `facts_changed`,
`facts_unchanged`), and the suite pins that the shim's count equals the compiler's own count.

**Measured boundary.** The compiler's API calls and printed bytes are *inside* the snapshot and reuse
arms; nothing is moved out of the count. There is no cache in front of GitHub: every run of
`spark facts` re-reads every source, and the stored observation `--delta` compares against is never
consulted for a value.

**Stub mode** replays fixed GitHub answers through a `gh` stub in a throwaway sandbox (the fixture style
of `tests/test-fact-snapshot.sh`), which makes every count exact and reproducible and allows a third
round after a **simulated push** (a new HEAD) that a merged live PR cannot provide. Its byte figures
reflect the fixtures' size, not a real repository's, and are not compared with the live ones.

## 2. Workloads

| Workload | Unit | Why |
|---|---|---|
| PR #804 | pull request, merged, one comment, no closing reference | an ordinary implementation PR of this release (the #734 graph packet) |
| PR #802 | pull request, merged, one comment, no closing reference | a second PR of the same class (the #734 snapshot packet) |
| issue #734 | issue, closed, milestone 20 | the issue form of the same work unit; no HEAD-bound facts |
| stub #801 → #734 | pull request implementing an issue, fixtures | the exact-count control and the only post-push measurement |

## 3. Results (live; deterministic counts exact, ms observational)

Per round; "warm" is the reuse arm's second round against its own first-round record.

| Workload | Arm | requests | bytes to consumer | ms |
|---|---|---:|---:|---:|
| PR #804 | journey (r1 = r2) | 8 | 399,266 | 2,645 / 2,723 |
| | snapshot (r1 = r2) | 6 | 7,851 | 3,866 / 3,810 |
| | reuse cold / **warm** | 6 / 6 | 7,851 / **3,369** | 4,101 / 3,992 |
| PR #802 | journey (r1 = r2) | 8 | 399,216 | 3,615 / 2,557 |
| | snapshot (r1 = r2) | 6 | 7,851 | 3,803 / 3,755 |
| | reuse cold / **warm** | 6 / 6 | 7,851 / **3,369** | 3,901 / 3,965 |
| issue #734 | journey (r1 = r2) | 9 | 415,020 | 2,921 / 2,981 |
| | snapshot (r1 = r2) | 5 | 6,223 | 2,992 / 3,071 |
| | reuse cold / **warm** | 5 / 5 | 6,223 / **2,711** | 2,912 / 3,046 |

Raw: `736-bench-pr804.json`, `736-bench-pr802.json`, `736-bench-issue734.json`.

**Deltas, journey → snapshot (cold), per round:** requests 8 → 6 (−25 %) for a pull request and 9 → 5
(−44 %) for an issue; bytes 399 K → 7.9 K (−98 %) and 415 K → 6.2 K (−98.5 %). The journey's bytes are
dominated by the standing-authority thread (#677, 73 comments) and the record bodies — exactly the
surfaces §2.3 of the baseline lists as re-fetched although unchanged.

**Deltas, snapshot → reuse (warm), per round:** requests unchanged (6 → 6, 5 → 5: no read is
suppressed, P4); bytes 7,851 → 3,369 (−57 %) and 6,223 → 2,711 (−56 %), with `facts_changed = 0` and
`facts_unchanged = 10`.

**Repeated reads across rounds:** the journey repeats all 8–9 reads and all ~400 K bytes every round;
the reuse arm repeats the 5–6 reads and returns 2.7–3.4 K.

**Wall time:** the snapshot arms are slower than the contract-minimal journey by ~1 s per round
(sequential reads plus jq projection in Bash); observational, and not a dimension this record claims.

## 4. Stub results (exact; bytes are fixture-sized)

| Round | journey | snapshot | reuse | reuse telemetry |
|---|---:|---:|---:|---|
| 1 (cold) | 12 req / 2,296 B | 7 req / 6,721 B | 7 req / 6,721 B | changed 10, unchanged 0 |
| 2 (unchanged) | 12 / 2,296 | 7 / 6,721 | 7 / **3,193** | changed 0, unchanged 10 |
| 3 (after a push to a new HEAD) | 12 / 2,296 | 7 / 6,721 | 7 / **4,987** | **changed 5, unchanged 5** |

The five that moved are `head.exact`, `review.independent`, `checks.required`, `acceptance.contract`
and `next_action.governed`; the five reused are `repository.identity`, `authority.standing`,
`work_unit.identity`, `graph.native` and `placement.current`. Raw: `736-bench-stub.json`.

## 5. Negative controls (all pinned by `tests/test-bench-facts.sh`, 28 assertions)

- disabling reuse restores the full reads: snapshot round 2 makes the same 7 requests and returns the
  same bytes as round 1;
- reuse suppresses no source read: the warm round's request count equals the cold round's and the
  snapshot arm's, and the shim's count equals the compiler's own `facts_api_calls`;
- a new HEAD invalidates exactly the HEAD-bound facts (5) while the five non-HEAD facts are reused;
- the compiler's notes ("no previous record") are carried in the result, not hidden;
- a tampered record, a record for another unit, and a run without `--delta` are covered by
  `tests/test-fact-snapshot.sh` (#735), which this harness relies on rather than restates.

## 6. NOT ASSESSED (this record)

- tokens / context consumed by a model — no model ran; bytes to the consumer are the proxy, not a token count;
- reviewer-lane consumption — the OpenAI lane's reads are not observable here;
- review rounds, finding recurrence, round economics — the #746 review-packet arm has not landed; when
  it does, it is a fourth arm of this harness on the same state;
- cleanup attribution — nothing here separates #729's effect; this is the #728-only comparison, on the
  current tree, with the consumption policy the only variable;
- the integrated/combined v0.23 result — owed by the final #736 report once #746 lands;
- a live post-push round — a merged PR's HEAD cannot move; the stub supplies it;
- wall time as an efficiency dimension — observational only, and the snapshot arms are not faster.

## 7. Comparison with the #730 baseline, descriptively

The baseline's per-round figures were lower bounds from session records: A made 110 gh invocations
over 16 rounds (≈ 7 per round) and fetched the PR record 21 times and its conversation 19 times; B made
152 over 32 (≈ 5) and fetched the conversation 51 times. This harness's journey arm makes 8–9 requests
per round by construction and re-fetches everything every round, which is the shape the baseline
observed; the snapshot arm's 5–6 requests per round are the compiler's whole read set, and the warm
reuse round returns under 3.4 K to the consumer against the ~400 K the same surfaces weigh raw.

Governed by Spark v0.22.0
