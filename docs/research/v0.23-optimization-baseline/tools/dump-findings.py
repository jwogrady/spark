#!/usr/bin/env python3
"""dump-findings.py <rawdir> <pr> — write every reviewer attempt and every finding IN FULL with its source of record.

Record format (so the stored bytes stay verbatim):
  ## r<id> head=<sha> verdict=<v> trust=<trusted|relayed> login=<login> kind=<findings|prose|evidence> comment_id=<id> at=<time>
  ### <id>.<i>                       synthetic finding id envelope, on its own line (for kind=evidence: "### <id>.<i> evidence")
  <the original block, byte-for-byte>  everything until the next ### / ## / EOF
Every marked reviewer comment of the PR gets a header, in chronology, even when it carries no block (then the
header stands alone). The `###` line is an envelope, not part of the block; validate-findings.py strips it."""
import json, sys, os
raw, pr = sys.argv[1], sys.argv[2]
d = json.load(open(os.path.join(raw, "derived.json")))
with open(os.path.join(raw, "findings.txt"), "w") as f:
    f.write(f"# PR #{pr} reviewer attempts and findings — source of record: the GitHub comment named in each `## r<id>` header.\n")
    f.write("# Every marked reviewer comment is listed in chronology: trust=trusted (the reviewer lane's own login) or\n")
    f.write("# trust=relayed (a marker posted by another login). kind=findings (list items of a blocking verdict), kind=prose\n")
    f.write("# (a blocking verdict with no list items: the whole reviewer section is the one finding), kind=evidence (PASS bullets,\n")
    f.write("# recorded but NOT findings). Each `### <id>.<n>` line is a synthetic envelope; the lines after it, up to the next\n")
    f.write("# `###`/`##`, are the original block byte-for-byte. tools/validate-findings.py proves both directions against GitHub.\n\n")
    for r in d["rounds"]:
        f.write(f"## r{r['n']} head={r['head']} verdict={r['verdict']} trust={r['trust']} login={r['comment_login']} kind={r['kind']} comment_id={r['comment_id']} at={r['at']}\n")
        for i, t in enumerate(r["finding_text"], 1):
            tag = " evidence" if r["kind"] == "evidence" else ""
            f.write(f"### {r['n']}.{i}{tag}\n{t}\n")
        f.write("\n")
print("ok")
