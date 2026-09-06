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
# Frozen-baseline guards: the expected PR head and the observation cutoff (ISO-8601 Z). With them the
# derivation is pinned — a later comment, rerun or commit cannot silently change the "frozen" facts.
expect_head = sys.argv[3] if len(sys.argv) > 3 else None
cutoff = sys.argv[4] if len(sys.argv) > 4 else None
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
if expect_head and prj["head"]["sha"] != expect_head:
    raise SystemExit(f"PR #{pr} head is {prj['head']['sha']}, expected frozen head {expect_head}: refusing to derive a different baseline")
if cutoff:
    comments = [c for c in comments if c["created_at"] <= cutoff]
    reviews = [r for r in reviews if r["submitted_at"] <= cutoff]
    commits = [c for c in commits if c["commit"]["author"]["date"] <= cutoff]
    if isinstance(runs, dict): runs = {**runs, "workflow_runs": [r for r in runs["workflow_runs"] if r["created_at"] <= cutoff]}
    else: runs = [r for r in runs if r["created_at"] <= cutoff]
    # check runs can be re-run on an unchanged HEAD: keep only those started at or before the cutoff
    checks = {**checks, "check_runs": [c for c in checks.get("check_runs", []) if (c.get("started_at") or "") <= cutoff]}
# PR state is mutable (a later close/merge would change it): derive the state AS OF the cutoff from immutable
# timestamps instead of reading the live field.
def state_at(ts):
    if prj.get("merged_at") and (not ts or prj["merged_at"] <= ts): return "merged"
    if prj.get("closed_at") and (not ts or prj["closed_at"] <= ts): return "closed"
    return "open"
merged_at_pinned = prj.get("merged_at") if (prj.get("merged_at") and (not cutoff or prj["merged_at"] <= cutoff)) else None

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

# reviewer attempts: EVERY marked comment in chronology. trust=trusted for the reviewer lane's own login,
# trust=relayed for a marker posted by any other login (an authorized relay of a reviewer run is still a review
# attempt on that HEAD and its findings are part of the path to the governed outcome). Round numbers count
# trusted verdicts (r1, r2, …); a relayed attempt is numbered after the trusted round of the same HEAD with
# an `r` suffix (26r, 27r, …) so trusted round ids stay stable.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from findings_parser import extract, reviewer_section, normalize
rounds = []; echo = 0; trusted_n = 0; relayed_seen = collections.Counter()
for cm in sorted(comments, key=lambda x: x["created_at"]):
    m = MARK.search(cm["body"])
    if not m: continue
    head = m.group(2); verdict = m.group(3)
    body = normalize(cm["body"])
    trusted = cm["user"]["login"] == "github-actions[bot]"
    kind, blocks = extract(body, verdict)
    files_cited = sorted(set(f for f in FILE.findall(reviewer_section(body))))
    cdate = by_sha.get(head, {}).get("date")
    lat = (T(cm["created_at"]) - T(cdate)).total_seconds() if cdate else None
    if trusted:
        trusted_n += 1; rid = str(trusted_n)
    else:
        echo += 1; relayed_seen[trusted_n] += 1
        rid = f"{trusted_n}r" + ("" if relayed_seen[trusted_n] == 1 else chr(ord("a") + relayed_seen[trusted_n] - 1))
    # The immutable source of record for every finding is the GitHub comment itself (id + url below);
    # the block text is written in full, never truncated, to findings.txt by dump-findings.py.
    rounds.append({"n": rid, "trust": "trusted" if trusted else "relayed", "kind": kind, "head7": head[:7], "head": head,
                   "verdict": verdict, "at": cm["created_at"], "comment_id": cm["id"], "comment_url": cm["html_url"],
                   "comment_login": cm["user"]["login"], "commit_at": cdate, "push_to_verdict_s": lat,
                   "findings": len(blocks) if kind != "evidence" else 0, "evidence_bullets": len(blocks) if kind == "evidence" else 0,
                   "finding_text": blocks, "files_cited": files_cited, "body_chars": len(body)})

trusted_rounds = [r for r in rounds if r["trust"] == "trusted"]
# author (writer) top-level comments per trusted-round window (marker relays are not writer comments)
author = [c for c in comments if c["user"]["login"] != "github-actions[bot]" and not MARK.search(c["body"])]
def in_round(ts):
    for i, r in enumerate(trusted_rounds):
        lo = trusted_rounds[i-1]["at"] if i else "0"
        if lo < ts <= r["at"]: return r["n"]
    return str(len(trusted_rounds) + 1)
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
first = cl[0]["date"]; last_verdict = trusted_rounds[-1]["at"] if trusted_rounds else None
out = {
  "pr": pr, "frozen_head_expected": expect_head, "observation_cutoff": cutoff, "state_at_cutoff": state_at(cutoff), "merged_at": merged_at_pinned, "head": prj["head"]["sha"], "base": prj["base"]["ref"],
  "created_at": prj["created_at"], "first_commit": first, "last_verdict": last_verdict,
  "wall_first_commit_to_last_verdict_s": int((T(last_verdict) - T(first)).total_seconds()) if last_verdict else None,
  "commits": len(cl), "commit_types": dict(collections.Counter(c["type"] for c in cl)),
  "additions": sum(c["additions"] for c in cl), "deletions": sum(c["deletions"] for c in cl),
  "distinct_files_touched": len(touched), "files_touched": dict(touched.most_common()),
  "review_attempts_total": len(rounds), "reviewer_verdicts": len(trusted_rounds), "relayed_attempts": echo,
  "verdict_counts": dict(collections.Counter(r["verdict"] for r in trusted_rounds)),
  "relayed_verdict_counts": dict(collections.Counter(r["verdict"] for r in rounds if r["trust"] == "relayed")),
  "attempt_kinds": dict(collections.Counter(r["kind"] for r in rounds)),
  "formal_reviews": len(reviews),
  "author_comments": len(author), "author_comment_chars": sum(len(c["body"]) for c in author),
  "author_comments_by_round": dict(sorted(author_by_round.items())),
  "reviewer_body_chars": sum(r["body_chars"] for r in rounds),
  "findings_total": sum(r["findings"] for r in rounds), "findings_trusted": sum(r["findings"] for r in trusted_rounds),
  "findings_relayed": sum(r["findings"] for r in rounds if r["trust"] == "relayed"),
  "evidence_bullets_in_pass": sum(r["evidence_bullets"] for r in rounds),
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

print(f"# PR #{pr}  state_at_cutoff={out['state_at_cutoff']} merged_at={out['merged_at']}  head={out['head'][:7]}")
print(f"commits={out['commits']} types={out['commit_types']} +{out['additions']}/-{out['deletions']} distinct_files={out['distinct_files_touched']}")
print(f"attempts={out['review_attempts_total']} trusted verdicts={out['reviewer_verdicts']} {out['verdict_counts']} relayed={echo} {out['relayed_verdict_counts']} kinds={out['attempt_kinds']} formal_reviews={len(reviews)}")
print(f"findings_total={out['findings_total']} (trusted {out['findings_trusted']}, relayed {out['findings_relayed']}; PASS evidence bullets {out['evidence_bullets_in_pass']})  author_comments={out['author_comments']} ({out['author_comment_chars']} chars)  reviewer chars={out['reviewer_body_chars']}")
print(f"wall first-commit→last-verdict = {out['wall_first_commit_to_last_verdict_s']}s")
lat = [x for x in out["push_to_verdict_s"] if x is not None]
if lat: print(f"push→verdict latency s: min={min(lat):.0f} median={sorted(lat)[len(lat)//2]:.0f} max={max(lat):.0f}")
print("workflow runs:", json.dumps(wf))
print("\n| attempt | trust | kind | head | verdict | findings | files cited | push→verdict s | author comments in round |")
print("|---|---|---|---|---|---:|---|---:|---:|")
for r in rounds:
    print(f"| {r['n']} | {r['trust']} | {r['kind']} | {r['head7']} | {r['verdict']} | {r['findings']} | {', '.join(r['files_cited'])} | {r['push_to_verdict_s'] if r['push_to_verdict_s'] is None else int(r['push_to_verdict_s'])} | {author_by_round.get(r['n'],0)} |")
print("\nfiles cited in N rounds:", dict(cite.most_common(12)))
print("files touched (commits):", dict(touched.most_common(12)))
