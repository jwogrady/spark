#!/usr/bin/env python3
"""validate-findings.py <rawdir> <pr> [cutoff] — prove findings.txt against GitHub in BOTH directions.

Record → source: for every `## r<id> …` header the comment is fetched live by id; every block after a `###`
envelope (envelope line removed, the writer's single trailing newline removed) must be a verbatim substring of the
CRLF-normalized body; the number of blocks must equal what findings_parser.extract finds in that body for the
header's verdict; the header's login/verdict/head must match the comment.
Source → record: every comment on the PR (all logins) carrying a `spark-openai-review pr=<pr>` marker and created
at or before the cutoff must have a header in findings.txt — a marked reviewer attempt absent from the record
fails validation. Writes findings-validation.txt; exits non-zero on any problem."""
import os, re, subprocess, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from findings_parser import extract, normalize, MARKER
raw, pr = sys.argv[1], sys.argv[2]; cutoff = sys.argv[3] if len(sys.argv) > 3 else None
R = "repos/jwogrady/spark"
def gh(*args): return subprocess.run(["gh", "api", *args], capture_output=True, text=True, check=True).stdout
text = open(os.path.join(raw, "findings.txt")).read()
out = []; bad = 0; recorded = {}
for blk in re.split(r"\n(?=## r\S+ head=)", text):
    m = re.match(r"## r(\S+) head=([0-9a-f]{40}) verdict=(.+?) trust=(\w+) login=(\S+) kind=(\w+) comment_id=(\d+) at=(\S+)\n", blk)
    if not m: continue
    rid, head, verdict, trust, login, kind, cid = m.groups()[:7]
    recorded[cid] = rid
    c = json.loads(gh(f"{R}/issues/comments/{cid}"))
    body = normalize(c["body"])
    if c["user"]["login"] != login: bad += 1; out.append(f"LOGIN r{rid}: header says {login}, comment by {c['user']['login']}")
    if f"head={head} verdict={verdict} -->" not in body: bad += 1; out.append(f"MARKER r{rid}: comment {cid} is not the marker for {head} {verdict}")
    parts = re.split(rf"^### {re.escape(rid)}\.\d+(?: evidence)?\n", blk[m.end():], flags=re.M)
    blocks = [b[:-1] if b.endswith("\n") else b for b in parts[1:]]
    blocks = [b.rstrip("\n") if b.endswith("\n") else b for b in blocks]  # the blank line before the next ## header
    ok = sum(1 for b in blocks if b in body)
    bad += len(blocks) - ok
    for b in blocks:
        if b not in body: out.append(f"MISMATCH r{rid}: {b[:70]!r}")
    k2, blocks2 = extract(body, verdict)
    if k2 != kind or len(blocks2) != len(blocks): bad += 1; out.append(f"COUNT r{rid}: parser finds kind={k2} n={len(blocks2)}, record has kind={kind} n={len(blocks)}")
    out.append(f"r{rid} comment {cid} ({trust}, {kind}): {ok}/{len(blocks)} blocks verbatim; parser agrees on {len(blocks2)}")
# source -> record
live = json.loads(gh("--paginate", f"{R}/issues/{pr}/comments?per_page=100"))
marked = [c for c in live if MARKER.search(c["body"]) and MARKER.search(c["body"]).group(1) == str(pr) and (not cutoff or c["created_at"] <= cutoff)]
missing = [c for c in marked if str(c["id"]) not in recorded]
for c in missing: bad += 1; out.append(f"ABSENT: marked reviewer comment {c['id']} by {c['user']['login']} at {c['created_at']} is not in findings.txt")
extra = [cid for cid in recorded if cid not in {str(c["id"]) for c in marked}]
for cid in extra: bad += 1; out.append(f"EXTRA: recorded comment {cid} is not a marked reviewer comment of PR #{pr} within the cutoff")
out.append(f"source→record: {len(marked)} marked reviewer comments on PR #{pr}" + (f" up to {cutoff}" if cutoff else "") + f"; {len(marked) - len(missing)} recorded, {len(missing)} absent, {len(extra)} extra")
hdr = (f"# PR #{pr}: findings.txt validated in both directions against live GitHub via `gh api`\n"
       "# record→source: envelope line removed, writer's trailing newline removed, body CRLF→LF, nothing else; block must be a verbatim substring;\n"
       "#               block count must equal findings_parser.extract on the live body; login/marker must match the header\n"
       "# source→record: every comment carrying a spark-openai-review marker for this PR (any login) must have a header\n")
open(os.path.join(raw, "findings-validation.txt"), "w").write(hdr + "\n".join(out) + f"\nRESULT: {'OK' if bad == 0 else 'FAIL'} ({bad} problem(s))\n")
print("\n".join(out[-2:])); print("RESULT", "OK" if bad == 0 else "FAIL", bad)
sys.exit(1 if bad else 0)
