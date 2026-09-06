#!/usr/bin/env python3
"""validate-findings.py <rawdir> <pr> — prove findings.txt against the cited GitHub comments.

Normalization, stated precisely: findings.txt is parsed into `## r<n> …` comment headers and `### <n>.<i>` finding
envelopes. The envelope line is removed; the text between one `###` line and the next `###`/`##`/EOF, with the
single trailing newline that the writer added after the block removed, is the candidate block. Comment bodies are
fetched live with `gh api` by the id in the header and normalized only by CRLF→LF. Each candidate block must be a
verbatim substring of that body, and the number of top-level `- ` lines in the body's reviewer section (between
the `---` separators) must equal the number of finding envelopes. Writes findings-validation.txt; exits non-zero
on any mismatch."""
import os, re, subprocess, sys
raw, pr = sys.argv[1], sys.argv[2]
text = open(os.path.join(raw, "findings.txt")).read()
rounds = re.split(r"\n(?=## r\d+ head=)", text)
out = []; bad = 0
for blk in rounds:
    m = re.match(r"## r(\d+) head=([0-9a-f]{40}) verdict=(.+?) comment_id=(\d+) at=(\S+)\n", blk)
    if not m: continue
    n, head, verdict, cid = m.group(1), m.group(2), m.group(3), m.group(4)
    body = subprocess.run(["gh", "api", f"repos/jwogrady/spark/issues/comments/{cid}", "--jq", ".body"], capture_output=True, text=True, check=True).stdout
    body = body.replace("\r\n", "\n")
    assert f"head={head} verdict={verdict} -->" in body, f"r{n}: comment {cid} is not the marker for {head}"
    parts = re.split(rf"^### ({n}\.\d+)\n", blk[m.end():], flags=re.M)
    ids = parts[1::2]; blocks = [b[:-1] if b.endswith("\n") else b for b in parts[2::2]]
    blocks = [b.rstrip("\n") if b.endswith("\n\n") else b for b in blocks]  # the blank line before the next ## header
    ok = 0
    for fid, b in zip(ids, blocks):
        if b in body: ok += 1
        else: bad += 1; out.append(f"MISMATCH {fid}: {b[:70]!r}")
    segs = body.split("\n---\n"); mid = "\n".join(segs[1:-1]) if len(segs) >= 3 else body
    top = len([ln for ln in mid.split("\n") if re.match(r"^- ", ln)])
    if top != len(ids): bad += 1; out.append(f"COUNT r{n}: body has {top} top-level bullets, findings.txt has {len(ids)}")
    out.append(f"r{n} comment {cid}: {ok}/{len(ids)} finding blocks verbatim in body after envelope removal; {top} top-level bullets in body")
hdr = (f"# PR #{pr}: findings.txt validated against live comment bodies via `gh api repos/jwogrady/spark/issues/comments/<id> --jq .body`\n"
       "# normalization: `### <round>.<bullet>` envelope lines removed; writer's trailing newline removed; body CRLF→LF; nothing else\n")
open(os.path.join(raw, "findings-validation.txt"), "w").write(hdr + "\n".join(out) + f"\nRESULT: {'OK' if bad == 0 else 'FAIL'} ({bad} problem(s))\n")
print("\n".join(out[-2:])); print("RESULT", "OK" if bad == 0 else "FAIL", bad)
sys.exit(1 if bad else 0)
