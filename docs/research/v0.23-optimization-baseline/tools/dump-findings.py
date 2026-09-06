#!/usr/bin/env python3
"""dump-findings.py <rawdir> <pr> — write every reviewer finding bullet IN FULL (no truncation) with the
immutable source of record (GitHub comment id + url) per round. Finding ids are <round>.<bullet>."""
import json, sys, os
raw, pr = sys.argv[1], sys.argv[2]
d = json.load(open(os.path.join(raw, "derived.json")))
with open(os.path.join(raw, "findings.txt"), "w") as f:
    f.write(f"# PR #{pr} reviewer findings — source of record: the GitHub comments below (trusted login github-actions[bot]).\n")
    f.write("# Bullets are copied verbatim and complete; sub-bullets of a finding are part of that finding's text.\n\n")
    for r in d["rounds"]:
        f.write(f"## r{r['n']} head={r['head']} verdict={r['verdict']} comment_id={r['comment_id']} at={r['at']}\n")
        for i, t in enumerate(r["finding_text"], 1):
            f.write(f"{r['n']}.{i} {t}\n")
        f.write("\n")
print("ok")
