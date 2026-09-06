#!/usr/bin/env python3
import json, sys
for pr in ("727", "724"):
    d = json.load(open(f"/home/john/.claude/jobs/046f256e/tmp/raw/pr{pr}/derived.json"))
    with open(f"/home/john/.claude/jobs/046f256e/tmp/raw/pr{pr}/findings.txt", "w") as f:
        for r in d["rounds"]:
            f.write(f"## r{r['n']} {r['head7']} {r['verdict']}\n")
            for i, t in enumerate(r["finding_text"], 1):
                f.write(f"  {r['n']}.{i} {t[:260].replace(chr(10),' ')}\n")
print("ok")
