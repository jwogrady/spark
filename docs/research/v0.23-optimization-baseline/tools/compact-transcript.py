#!/usr/bin/env python3
"""compact-transcript.py <rawdir> — commit-sized projections of the transcript analysis:
transcript-rounds.tsv (one row per verdict window, every numeric counter) and trimmed workload/aug JSON."""
import json, os, sys
raw = sys.argv[1]
rounds = json.load(open(os.path.join(raw, "transcript-rounds.json")))["windows"]
num_keys = sorted({k for w in rounds for k, v in w.items() if isinstance(v, int)})
with open(os.path.join(raw, "transcript-rounds.tsv"), "w") as f:
    f.write("name\tgroup\tfirst_activity\tlast_activity\t" + "\t".join(num_keys) + "\n")
    for w in rounds:
        f.write(f"{w['name']}\t{w['group']}\t{w['first_activity']}\t{w['last_activity']}\t" + "\t".join(str(w.get(k, 0)) for k in num_keys) + "\n")
def trim(path, keep_touch=30):
    d = json.load(open(os.path.join(raw, path)))
    for w in d["windows"]:
        w["top_reads"] = w["top_reads"][:10]; w["top_endpoints"] = w["top_endpoints"][:12]
    d["file_touches_all"] = d["file_touches_all"][:keep_touch]
    d["file_touches_by_group"] = {g: v[:15] for g, v in d["file_touches_by_group"].items()}
    json.dump(d, open(os.path.join(raw, path.replace(".json", ".compact.json")), "w"), indent=0)
trim("transcript-workloads.json"); trim("transcript-aug.json")
print("ok", len(rounds), len(num_keys))
