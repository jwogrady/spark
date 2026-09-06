#!/usr/bin/env python3
"""dump-findings.py <rawdir> <pr> — write every reviewer finding IN FULL with its source of record.

Record format (so the stored bullet bytes stay verbatim):
  ## r<n> head=<sha> verdict=<v> comment_id=<id> at=<time>      one header per reviewer comment
  ### <n>.<i>                                                     synthetic finding id, on its own line
  <the original top-level bullet block, byte-for-byte>            everything until the next ### / ## / EOF
The `###` line is an envelope, not part of the finding; validate-findings.py strips it before checking that
the block is a verbatim substring of the live comment body."""
import json, sys, os
raw, pr = sys.argv[1], sys.argv[2]
d = json.load(open(os.path.join(raw, "derived.json")))
with open(os.path.join(raw, "findings.txt"), "w") as f:
    f.write(f"# PR #{pr} reviewer findings — source of record: the GitHub comments in the `## r<n>` headers (trusted login github-actions[bot]).\n")
    f.write("# Each `### <round>.<bullet>` line is a synthetic id envelope; the lines that follow it, up to the next `###`/`##`,\n")
    f.write("# are the original top-level bullet block byte-for-byte (continuation lines, indented sub-bullets, internal blank lines).\n")
    f.write("# tools/validate-findings.py strips the envelope and proves each block is a verbatim substring of the live comment body.\n\n")
    for r in d["rounds"]:
        f.write(f"## r{r['n']} head={r['head']} verdict={r['verdict']} comment_id={r['comment_id']} at={r['at']}\n")
        for i, t in enumerate(r["finding_text"], 1):
            f.write(f"### {r['n']}.{i}\n{t}\n")
        f.write("\n")
print("ok")
