#!/usr/bin/env python3
"""make-windows.py [rawdir] — build transcript windows from the reviewer-verdict timeline of each PR.
rawdir defaults to ../raw relative to this script; reads pr727/derived*.json and pr724/derived*.json."""
import json, os, sys
raw = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "raw")
def JD(p):
    for n in ("derived.json", "derived.compact.json"):
        f = os.path.join(raw, p, n)
        if os.path.exists(f): return json.load(open(f))
    raise SystemExit(f"missing {p}/derived*.json under {raw}")
d727 = JD("pr727"); d724 = JD("pr724")
B_START = "2026-09-05T15:00:00Z"            # after the previous (unrelated) session block ended 02:xx; before #724's first commit 17:18
B_END = d724["merged_at"]                   # 2026-09-05T22:35:55Z
A_START = B_END                              # #727 work began after the #724 merge (first commit 22:49:55)
A_END = d727["last_verdict"]                # 2026-09-06T16:00:38Z
work = [
  {"name": "other-pre (Sep 4-5 docs work, not a measured workload)", "group": "other", "start": "2026-09-04T00:00:00Z", "end": B_START},
  {"name": "B: PR #724 (#722 memoization) — 32 verdicts → PASS, merged", "group": "B", "start": B_START, "end": B_END},
  {"name": "A: PR #727 (#726 merge authority) — 16 verdicts, all CHANGES REQUIRED", "group": "A", "start": A_START, "end": A_END},
  {"name": "other-post (hierarchy metadata task)", "group": "other", "start": A_END, "end": "2026-09-06T16:30:00Z"},
]
rounds = []
prev = B_START
for r in d724["rounds"]:
    rounds.append({"name": f"B r{r['n']} {r['head7']} {r['verdict']}", "group": "B", "start": prev, "end": r["at"]}); prev = r["at"]
rounds.append({"name": "B post-PASS → merge", "group": "B", "start": prev, "end": B_END})
prev = A_START
for r in d727["rounds"]:
    rounds.append({"name": f"A r{r['n']} {r['head7']} {r['verdict']}", "group": "A", "start": prev, "end": r["at"]}); prev = r["at"]
json.dump(work, open(os.path.join(raw, "windows-workloads.json"), "w"), indent=1)
json.dump(rounds, open(os.path.join(raw, "windows-rounds.json"), "w"), indent=1)
print(len(work), len(rounds))
