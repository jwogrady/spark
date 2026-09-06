#!/usr/bin/env python3
"""analyze-pr.py <rawdir> <pr-number> — derive round/finding/commit facts from raw GitHub JSON (no interpretation).

Inputs (from fetch-pr.sh / fetch-commits.sh): pr.json commits.json commits/<sha>.json issue-comments.json
reviews.json workflow-runs.json check-runs-head.json.
Outputs: <rawdir>/derived.json and a markdown summary on stdout.
Trusted reviewer login is github-actions[bot]; markers by any other login are counted as relay/echo, never as verdicts.
"""
import json, re, sys, os, collections
from datetime import datetime, timezone

raw = sys.argv[1]; pr = int(sys.argv[2])
def J(n):
    # `gh api --paginate` on an object-shaped endpoint concatenates one object per page.
    s = open(os.path.join(raw, n)).read(); dec = json.JSONDecoder(); i = 0; objs = []
    while i < len(s):
        while i < len(s) and s[i].isspace(): i += 1
        if i >= len(s): break
        o, i = dec.raw_decode(s, i); objs.append(o)
    if len(objs) == 1: return objs[0]
    if all(isinstance(o, list) for o in objs): return [x for o in objs for x in o]
    merged = {}
    for o in objs:
        for k, v in o.items():
            if isinstance(v, list): merged.setdefault(k, []).extend(v)
            else: merged[k] = v
    return merged
T = lambda s: datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)

prj = J("pr.json"); commits = J("commits.json"); comments = J("issue-comments.json")
reviews = J("reviews.json"); runs = J("workflow-runs.json"); checks = J("check-runs-head.json")

MARK = re.compile(r"<!-- spark-openai-review pr=(\d+) head=([0-9a-f]{40}) verdict=(PASS|CHANGES REQUIRED|DECISION REQUIRED|NOT ASSESSED) -->")
FILE = re.compile(r"`([\w./-]+\.(?:sh|md|json|tsv|yml|yaml))(?::[\d,-]+)?`")

# commits with per-commit file stats
cl = []
for c in commits:
    d = J(f"commits/{c['sha']}.json")
    files = [f["filename"] for f in d.get("files", [])]
    cl.append({"sha": c["sha"], "sha7": c["sha"][:7], "date": c["commit"]["author"]["date"],
               "subject": c["commit"]["message"].split("\n")[0], "type": c["commit"]["message"].split(":")[0],
               "files": files, "additions": d["stats"]["additions"], "deletions": d["stats"]["deletions"]})
by_sha = {c["sha"]: c for c in cl}

# reviewer rounds
rounds = []; echo = 0
for cm in sorted(comments, key=lambda x: x["created_at"]):
    m = MARK.search(cm["body"])
    if not m: continue
    if cm["user"]["login"] != "github-actions[bot]":
        echo += 1; continue
    head = m.group(2); verdict = m.group(3)
    body = cm["body"].replace("\r\n", "\n")
    # findings = top-level bullets in the reviewer's own section (between the --- separators)
    segs = body.split("\n---\n")
    mid = "\n".join(segs[1:-1]) if len(segs) >= 3 else body
    # A finding is a whole top-level bullet BLOCK: the `- ` line plus every continuation line, indented
    # sub-bullet and blank line inside it, up to the next top-level bullet. A blank line followed by
    # non-indented prose ends the bullet list (that prose is the reviewer's trailer, not a finding).
    bullets = []; cur = None; held = []   # held = blank lines kept verbatim until we know they are inside the block
    for ln in mid.split("\n"):
        if re.match(r"^- ", ln):
            if cur is not None: bullets.append("\n".join(cur).rstrip())
            cur = [ln]; held = []
        elif cur is None:
            continue
        elif ln.strip() == "":
            held.append(ln)
        elif ln[0] in " \t":
            cur.extend(held); cur.append(ln); held = []
        else:
            if held: bullets.append("\n".join(cur).rstrip()); cur = None; held = []
            else: cur.append(ln)
    if cur is not None: bullets.append("\n".join(cur).rstrip())
    for b in bullets: assert b in body, "finding text must be a verbatim substring of the comment body"
    files_cited = sorted(set(f for f in FILE.findall(mid)))
    cdate = by_sha.get(head, {}).get("date")
    lat = (T(cm["created_at"]) - T(cdate)).total_seconds() if cdate else None
    # The immutable source of record for every finding is the GitHub comment itself (id + url below);
    # the bullet text is written in full, never truncated, to findings.txt by dump-findings.py.
    rounds.append({"n": len(rounds) + 1, "head7": head[:7], "head": head, "verdict": verdict, "at": cm["created_at"],
                   "comment_id": cm["id"], "comment_url": cm["html_url"], "comment_login": cm["user"]["login"],
                   "commit_at": cdate, "push_to_verdict_s": lat, "findings": len(bullets),
                   "finding_text": bullets, "files_cited": files_cited, "body_chars": len(body)})

# author (writer) top-level comments per round window
author = [c for c in comments if c["user"]["login"] != "github-actions[bot]"]
def in_round(ts):
    for i, r in enumerate(rounds):
        lo = rounds[i-1]["at"] if i else "0"
        if lo < ts <= r["at"]: return r["n"]
    return len(rounds) + 1
author_by_round = collections.Counter(in_round(c["created_at"]) for c in author)

# files cited across rounds -> revisit counts
cite = collections.Counter()
for r in rounds:
    for f in r["files_cited"]: cite[f] += 1

# workflow runs on the branch
wf = collections.defaultdict(lambda: {"runs": 0, "seconds": 0, "heads": set()})
for r in (runs["workflow_runs"] if isinstance(runs, dict) else runs):
    w = wf[r["name"]]; w["runs"] += 1; w["heads"].add(r["head_sha"][:7])
    if r.get("run_started_at") and r.get("updated_at"):
        w["seconds"] += (T(r["updated_at"]) - T(r["run_started_at"])).total_seconds()
wf = {k: {"runs": v["runs"], "seconds": int(v["seconds"]), "distinct_heads": len(v["heads"])} for k, v in wf.items()}

touched = collections.Counter(f for c in cl for f in c["files"])
first = cl[0]["date"]; last_verdict = rounds[-1]["at"] if rounds else None
out = {
  "pr": pr, "state": prj["state"], "merged_at": prj.get("merged_at"), "head": prj["head"]["sha"], "base": prj["base"]["ref"],
  "created_at": prj["created_at"], "first_commit": first, "last_verdict": last_verdict,
  "wall_first_commit_to_last_verdict_s": int((T(last_verdict) - T(first)).total_seconds()) if last_verdict else None,
  "commits": len(cl), "commit_types": dict(collections.Counter(c["type"] for c in cl)),
  "additions": sum(c["additions"] for c in cl), "deletions": sum(c["deletions"] for c in cl),
  "distinct_files_touched": len(touched), "files_touched": dict(touched.most_common()),
  "reviewer_verdicts": len(rounds), "verdict_counts": dict(collections.Counter(r["verdict"] for r in rounds)),
  "echo_markers_untrusted_login": echo, "formal_reviews": len(reviews),
  "author_comments": len(author), "author_comment_chars": sum(len(c["body"]) for c in author),
  "author_comments_by_round": dict(sorted(author_by_round.items())),
  "reviewer_body_chars": sum(r["body_chars"] for r in rounds),
  "findings_total": sum(r["findings"] for r in rounds),
  "files_cited_rounds": dict(cite.most_common()),
  "push_to_verdict_s": [r["push_to_verdict_s"] for r in rounds],
  "workflow_runs": wf, "check_runs_on_head": [(c["name"], c["conclusion"]) for c in checks.get("check_runs", [])],
  "rounds": rounds, "commit_list": cl,
}
json.dump(out, open(os.path.join(raw, "derived.json"), "w"), indent=1, default=list)
# Compact projection for committing: finding text lives in findings.txt, per-commit file lists are
# aggregated in files_touched; everything else is kept verbatim.
compact = dict(out)
compact["rounds"] = [{k: v for k, v in r.items() if k != "finding_text"} for r in rounds]
compact.pop("commit_list", None); compact.pop("push_to_verdict_s", None)  # per-round rows carry both
json.dump(compact, open(os.path.join(raw, "derived.compact.json"), "w"), indent=0, default=list)

print(f"# PR #{pr}  state={out['state']} merged_at={out['merged_at']}  head={out['head'][:7]}")
print(f"commits={out['commits']} types={out['commit_types']} +{out['additions']}/-{out['deletions']} distinct_files={out['distinct_files_touched']}")
print(f"reviewer verdicts={out['reviewer_verdicts']} {out['verdict_counts']} echo(untrusted)={echo} formal_reviews={len(reviews)}")
print(f"findings_total={out['findings_total']}  author_comments={out['author_comments']} ({out['author_comment_chars']} chars)  reviewer chars={out['reviewer_body_chars']}")
print(f"wall first-commit→last-verdict = {out['wall_first_commit_to_last_verdict_s']}s")
lat = [x for x in out["push_to_verdict_s"] if x is not None]
if lat: print(f"push→verdict latency s: min={min(lat):.0f} median={sorted(lat)[len(lat)//2]:.0f} max={max(lat):.0f}")
print("workflow runs:", json.dumps(wf))
print("\n| round | head | verdict | findings | files cited | push→verdict s | author comments in round |")
print("|---:|---|---|---:|---|---:|---:|")
for r in rounds:
    print(f"| {r['n']} | {r['head7']} | {r['verdict']} | {r['findings']} | {', '.join(r['files_cited'])} | {r['push_to_verdict_s'] if r['push_to_verdict_s'] is None else int(r['push_to_verdict_s'])} | {author_by_round.get(r['n'],0)} |")
print("\nfiles cited in N rounds:", dict(cite.most_common(12)))
print("files touched (commits):", dict(touched.most_common(12)))
