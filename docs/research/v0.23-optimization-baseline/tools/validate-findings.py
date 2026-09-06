#!/usr/bin/env python3
"""validate-findings.py <rawdir> <pr> [cutoff] — prove findings.txt against GitHub in BOTH directions.

Record → source: for every `## r<id> …` header the comment is fetched live by id; the recorded blocks (envelope
line removed, the writer's single trailing newline removed) must EQUAL, as an ordered array, the blocks that
findings_parser.extract derives from the CRLF-normalized live body for the header's verdict — same count, same
order, same bytes — and the header's login, head and verdict must match the comment. Duplicate comment ids or
duplicate round ids in the record are rejected.
Source → record: every comment on the PR (all logins) carrying a `spark-openai-review pr=<pr>` marker and created
at or before the cutoff must have exactly one header in findings.txt — a marked reviewer attempt absent from the
record fails validation, as does a recorded comment that is not such an attempt.
Writes findings-validation.txt; exits non-zero on any problem."""
import os, re, subprocess, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from findings_parser import extract, normalize, MARKER
raw, pr = sys.argv[1], sys.argv[2]; cutoff = sys.argv[3] if len(sys.argv) > 3 else None
R = "repos/jwogrady/spark"
def gh(*args): return subprocess.run(["gh", "api", *args], capture_output=True, text=True, check=True).stdout
text = open(os.path.join(raw, "findings.txt")).read()
out = []; bad = 0; recorded = {}; seen_rid = set()
for blk in re.split(r"\n(?=## r\S+ head=)", text):
    m = re.match(r"## r(\S+) head=([0-9a-f]{40}) verdict=(.+?) trust=(\w+) login=(\S+) kind=(\w+) comment_id=(\d+) at=(\S+)\n", blk)
    if not m: continue
    rid, head, verdict, trust, login, kind, cid = m.groups()[:7]
    if cid in recorded: bad += 1; out.append(f"DUPLICATE comment_id {cid} (r{recorded[cid]} and r{rid})")
    if rid in seen_rid: bad += 1; out.append(f"DUPLICATE round id r{rid}")
    recorded[cid] = rid; seen_rid.add(rid)
    c = json.loads(gh(f"{R}/issues/comments/{cid}"))
    body = normalize(c["body"])
    if c["user"]["login"] != login: bad += 1; out.append(f"LOGIN r{rid}: header says {login}, comment by {c['user']['login']}")
    if f"head={head} verdict={verdict} -->" not in body: bad += 1; out.append(f"MARKER r{rid}: comment {cid} is not the marker for {head} {verdict}")
    parts = re.split(rf"^### {re.escape(rid)}\.\d+(?: evidence)?\n", blk[m.end():], flags=re.M)
    blocks = [b[:-1] if b.endswith("\n") else b for b in parts[1:]]
    blocks = [b.rstrip("\n") if b.endswith("\n") else b for b in blocks]  # the blank line before the next ## header
    k2, blocks2 = extract(body, verdict)
    if k2 != kind: bad += 1; out.append(f"KIND r{rid}: record says {kind}, parser says {k2}")
    if blocks != blocks2:
        bad += 1
        if len(blocks) != len(blocks2): out.append(f"COUNT r{rid}: record has {len(blocks)} blocks, parser derives {len(blocks2)}")
        for i, (a, b) in enumerate(zip(blocks, blocks2), 1):
            if a != b: out.append(f"CONTENT/ORDER r{rid} block {i}: record {a[:60]!r} != parsed {b[:60]!r}")
    out.append(f"r{rid} comment {cid} ({trust}, {kind}): {len(blocks)} recorded block(s) {'==' if blocks == blocks2 else '!='} parsed blocks (exact, ordered)")
# source -> record
live = json.loads(gh("--paginate", f"{R}/issues/{pr}/comments?per_page=100"))
marked = [c for c in live if MARKER.search(c["body"]) and MARKER.search(c["body"]).group(1) == str(pr) and (not cutoff or c["created_at"] <= cutoff)]
missing = [c for c in marked if str(c["id"]) not in recorded]
for c in missing: bad += 1; out.append(f"ABSENT: marked reviewer comment {c['id']} by {c['user']['login']} at {c['created_at']} is not in findings.txt")
extra = [cid for cid in recorded if cid not in {str(c["id"]) for c in marked}]
for cid in extra: bad += 1; out.append(f"EXTRA: recorded comment {cid} is not a marked reviewer comment of PR #{pr} within the cutoff")
out.append(f"source→record: {len(marked)} marked reviewer comments on PR #{pr}" + (f" up to {cutoff}" if cutoff else "") + f"; {len(marked) - len(missing)} recorded once each, {len(missing)} absent, {len(extra)} extra")
hdr = (f"# PR #{pr}: findings.txt validated in both directions against live GitHub via `gh api`\n"
       "# record→source: envelope line removed, writer's trailing newline removed, body CRLF→LF, nothing else; the recorded block array must\n"
       "#               EQUAL the parser's block array for the live body (count, order, bytes); login/marker/kind must match the header;\n"
       "#               duplicate comment ids or round ids are rejected\n"
       "# source→record: every comment carrying a spark-openai-review marker for this PR (any login) within the cutoff has exactly one header\n")
open(os.path.join(raw, "findings-validation.txt"), "w").write(hdr + "\n".join(out) + f"\nRESULT: {'OK' if bad == 0 else 'FAIL'} ({bad} problem(s))\n")
print("\n".join(out[-2:])); print("RESULT", "OK" if bad == 0 else "FAIL", bad)
sys.exit(1 if bad else 0)
