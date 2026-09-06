#!/usr/bin/env python3
"""validate-findings.py <rawdir> <pr> — prove findings.txt against the cited GitHub comments.
For every round header (comment_id) the comment body is fetched live with `gh api`; every finding block must be
a verbatim substring of that body, and the number of top-level `- ` lines in the body's reviewer section must
equal the number of findings recorded. Writes findings-validation.txt next to findings.txt; exits non-zero on any mismatch."""
import json, os, re, subprocess, sys
raw, pr = sys.argv[1], sys.argv[2]
text = open(os.path.join(raw, "findings.txt")).read()
rounds = re.split(r"\n(?=## r\d+ head=)", text)
out = []; bad = 0
for blk in rounds:
    m = re.match(r"## r(\d+) head=([0-9a-f]{40}) verdict=(.+?) comment_id=(\d+) at=(\S+)\n", blk)
    if not m: continue
    n, head, verdict, cid = m.group(1), m.group(2), m.group(3), m.group(4)
    body = subprocess.run(["gh", "api", f"repos/jwogrady/spark/issues/comments/{cid}", "--jq", ".body"], capture_output=True, text=True, check=True).stdout
    if not body.endswith("\n"): body += "\n"
    body = body.replace("\r\n", "\n")
    assert f"head={head} verdict={verdict} -->" in body, f"r{n}: comment {cid} is not the marker for {head}"
    findings = re.split(rf"\n(?={n}\.\d+ )", blk[m.end():].rstrip("\n"))
    findings = [f for f in findings if re.match(rf"^{n}\.\d+ ", f)]
    ok = 0
    for f in findings:
        t = re.sub(rf"^{n}\.\d+ ", "", f, count=1)
        if t in body: ok += 1
        else: bad += 1; out.append(f"MISMATCH r{n} {f[:60]!r}")
    segs = body.split("\n---\n"); mid = "\n".join(segs[1:-1]) if len(segs) >= 3 else body
    top = len([ln for ln in mid.split("\n") if re.match(r"^- ", ln)])
    if top != len(findings): bad += 1; out.append(f"COUNT r{n}: body has {top} top-level bullets, findings.txt has {len(findings)}")
    out.append(f"r{n} comment {cid}: {ok}/{len(findings)} findings verbatim in body; {top} top-level bullets in body")
open(os.path.join(raw, "findings-validation.txt"), "w").write(f"# PR #{pr}: findings.txt validated against live comment bodies via gh api\n" + "\n".join(out) + f"\nRESULT: {'OK' if bad == 0 else 'FAIL'} ({bad} problem(s))\n")
print("\n".join(out[-3:])); print("RESULT", "OK" if bad == 0 else "FAIL", bad)
sys.exit(1 if bad else 0)
