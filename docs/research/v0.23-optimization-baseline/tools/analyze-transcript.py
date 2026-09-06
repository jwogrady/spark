#!/usr/bin/env python3
"""analyze-transcript.py <session.jsonl> <windows.json> <out.json>

Observed agent/tool consumption from a Claude Code session transcript (the writer lane's own record of
what it read, ran, fetched and edited). Deterministic counts (tool calls, files, bytes returned) are exact
for what the transcript records; token figures are the API's own usage accounting per request and are
observational (model-dependent). Nothing here is inferred from prose.

windows.json: [{"name":..., "start": ISO-Z, "end": ISO-Z, "group": ...}, ...]  (start exclusive, end inclusive)
"""
import json, re, sys, collections, os

src, wfile, outp = sys.argv[1:4]
windows = json.load(open(wfile))
WT_PREFIXES = ["/home/john/code/spark/.claude/worktrees/feat-476-provenance-leakage/", "/home/john/code/spark/"]
TMP = "/home/john/.claude/jobs/"

def rel(p):
    for w in WT_PREFIXES:
        if p.startswith(w): return p[len(w):]
    return p

SHA = re.compile(r"\b[0-9a-f]{40}\b"); SHA7 = re.compile(r"\b[0-9a-f]{7,12}\b")
def norm_endpoint(cmd):
    """Normalize a gh invocation to a fact-shaped endpoint key."""
    m = re.search(r"gh api\s+(?:--method\s+\w+\s+)?(?:--paginate\s+)?(?:-X\s+\w+\s+)?[\"']?/?(repos/[^\s\"'?]+|graphql|user|orgs/[^\s\"']+)", cmd)
    if m:
        e = m.group(1).replace("jwogrady/spark", "{repo}")
        e = SHA.sub("{sha}", e); return "api:" + e
    m = re.search(r"gh (pr|issue|run|repo|release|api|search) (\w+)(?:\s+(\d+))?", cmd)
    if m: return f"gh:{m.group(1)} {m.group(2)}" + (f" {m.group(3)}" if m.group(3) else "")
    return "gh:other"

STABLE = [  # HEAD-independent facts: identity, authority, placement, contract, parents
    (re.compile(r"issues/(677|726|480|584|585|481|728|729)(/comments|/sub_issues)?$"), "authority/parent/placement issue"),
    (re.compile(r"milestones"), "milestone"),
    (re.compile(r"repos/\{repo\}$"), "repo identity"),
    (re.compile(r"rulesets|branches/master/protection|branches/master$"), "trunk protection/ruleset"),
    (re.compile(r"collaborators/.*/permission"), "permission"),
    (re.compile(r"releases"), "release"),
    (re.compile(r"contents/"), "repo content via API"),
]
HEADDEP = [
    (re.compile(r"pulls/\d+$"), "PR record"),
    (re.compile(r"issues/\d+/comments|pulls/\d+/comments|pulls/\d+/reviews"), "PR conversation"),
    (re.compile(r"check-runs|actions/runs|commits/\{sha\}|statuses"), "checks/runs for a head"),
    (re.compile(r"pulls/\d+/(files|commits)"), "PR files/commits"),
]
def fact_class(ep):
    for rx, name in STABLE:
        if rx.search(ep): return "stable", name
    for rx, name in HEADDEP:
        if rx.search(ep): return "head", name
    return "other", "other"

def classify_bash(cmd):
    if "tests/run.sh" in cmd: return "test:full" if "--only" not in cmd else "test:targeted"
    if re.search(r"bash tests/test-[\w-]+\.sh|tests/test-[\w-]+\.sh\b", cmd): return "test:targeted"
    if re.search(r"\bbash -n\b", cmd): return "syntax-check"
    if re.search(r"spark doctor|bin/spark doctor", cmd): return "doctor"
    if re.search(r"\bgh\b", cmd): return "gh"
    if re.search(r"\bgit (push)", cmd): return "git:push"
    if re.search(r"\bgit (fetch|pull|ls-remote)", cmd): return "git:fetch"
    if re.search(r"\bgit (commit|add|rebase|merge|checkout|switch|reset|stash|worktree)", cmd): return "git:mutate"
    if re.search(r"\bgit\b", cmd): return "git:read"
    if re.search(r"^(cat|sed -n|head|tail|grep|rg|wc|ls|find|awk)\b|\| *(head|tail|grep)", cmd.strip()): return "shell:read"
    if re.search(r"^python3|^bash /home/john/.claude/jobs", cmd.strip()): return "script"
    return "shell:other"

# pass 1: tool results by tool_use_id and tmp-script contents (from Write inputs)
results = {}; tmp_scripts = {}
recs = []
with open(src) as f:
    for line in f:
        try: o = json.loads(line)
        except Exception: continue
        t = o.get("type")
        if t == "user":
            for b in o.get("message", {}).get("content", []) if isinstance(o.get("message", {}).get("content"), list) else []:
                if isinstance(b, dict) and b.get("type") == "tool_result":
                    c = b.get("content"); n = 0
                    if isinstance(c, str): n = len(c)
                    elif isinstance(c, list): n = sum(len(x.get("text", "")) for x in c if isinstance(x, dict))
                    results[b["tool_use_id"]] = n
        elif t == "assistant":
            recs.append(o)

def win_of(ts):
    for w in windows:
        if w["start"] < ts <= w["end"]: return w["name"]
    return None

REPOPATH = re.compile(r"(?<![\w/])((?:plugins|tests|docs|\.github|evaluations)/[\w./-]+\.(?:sh|md|json|tsv|yml|txt)|plugins/spark/bin/spark|AGENTS\.md|CLAUDE\.md|ROADMAP\.md|README\.md|CHANGELOG\.md)")
touches = collections.Counter(); touches_by_group = collections.defaultdict(collections.Counter)
def w_group(name):
    for w in windows:
        if w["name"] == name: return w.get("group")
agg = {w["name"]: collections.defaultdict(int) for w in windows}
detail = {w["name"]: {"reads": collections.Counter(), "read_tool_paths": collections.Counter(), "endpoints": collections.Counter(), "edits": collections.Counter(),
                      "bash_kinds": collections.Counter(), "tools": collections.Counter(), "stable": collections.Counter(),
                      "head": collections.Counter(), "first": None, "last": None, "requests": set()} for w in windows}
seen_req = {}
for o in recs:
    ts = o.get("timestamp", ""); w = win_of(ts)
    if not w: continue
    d = detail[w]; a = agg[w]
    d["first"] = d["first"] or ts; d["last"] = ts
    msg = o.get("message", {}); rid = o.get("requestId") or msg.get("id")
    u = msg.get("usage") or {}
    if rid and rid not in seen_req:
        seen_req[rid] = w; d["requests"].add(rid)
        a["tok_input"] += u.get("input_tokens", 0); a["tok_cache_create"] += u.get("cache_creation_input_tokens", 0)
        a["tok_cache_read"] += u.get("cache_read_input_tokens", 0); a["tok_output"] += u.get("output_tokens", 0)
    for b in msg.get("content", []) if isinstance(msg.get("content"), list) else []:
        if not (isinstance(b, dict) and b.get("type") == "tool_use"): continue
        name = b["name"]; inp = b.get("input") or {}; rb = results.get(b["id"], 0)
        d["tools"][name] += 1; a["tool_calls"] += 1; a["result_bytes"] += rb
        if name == "Read":
            p = rel(inp.get("file_path", "")); d["reads"][p] += 1; d["read_tool_paths"][p] += 1; a["read_calls"] += 1; a["read_bytes"] += rb
            if p.startswith("/tmp/claude-1000/"): a["read_task_output_calls"] += 1; a["read_task_output_bytes"] += rb
            elif not p.startswith(TMP) and not p.startswith("/"):
                a["read_repo_calls"] += 1; a["read_repo_bytes"] += rb; touches[p] += 1; touches_by_group[w_group(w)][p] += 1
        elif name in ("Edit", "Write", "MultiEdit"):
            p = rel(inp.get("file_path", ""))
            if p.startswith(TMP): tmp_scripts[p] = inp.get("content", "") if name == "Write" else tmp_scripts.get(p, "")
            elif p.startswith("/"): a["edit_outside_repo"] += 1
            else: d["edits"][p] += 1; a["edit_calls"] += 1; touches[p] += 1; touches_by_group[w_group(w)][p] += 1
        elif name == "Bash":
            cmd = inp.get("command", ""); k = classify_bash(cmd); d["bash_kinds"][k] += 1; a["bash_calls"] += 1; a["bash_bytes"] += rb
            a["bash:" + k] += 1
            if k == "shell:read":
                a["shell_read_bytes"] += rb
                for pth in set(REPOPATH.findall(cmd)):
                    d["reads"]["(sh) " + pth] += 1; touches[pth] += 1; touches_by_group[w_group(w)][pth] += 1
            ghs = []
            if k == "gh":
                for part in re.split(r"\s*(?:&&|\|\||;|\|)\s*", cmd):
                    if re.search(r"\bgh\b", part): ghs.append(part)
            m = re.match(r"\s*bash (/home/john/.claude/jobs/\S+\.sh)", cmd)
            if m and m.group(1) in tmp_scripts:
                for ln in tmp_scripts[m.group(1)].split("\n"):
                    if re.search(r"\bgh (api|pr|issue|run|repo|release|search)\b", ln): ghs.append(ln)
                if ghs: a["gh_from_scripts_lower_bound"] += len(ghs)
            for g in ghs:
                ep = norm_endpoint(g); d["endpoints"][ep] += 1; a["gh_invocations_lower_bound"] += 1
                cls, fname = fact_class(ep)
                if cls == "stable": d["stable"][fname] += 1; a["gh_stable_fact_fetches"] += 1
                elif cls == "head": d["head"][fname] += 1; a["gh_head_dependent_fetches"] += 1
                else: a["gh_other_fetches"] += 1
        elif name in ("Grep", "Glob"):
            a["search_calls"] += 1
        elif name == "Agent":
            a["subagents"] += 1

out = {"source": os.path.basename(src), "windows": []}
for w in windows:
    n = w["name"]; a = agg[n]; d = detail[n]
    # two path statistics, kept apart: Read-tool calls only, and the combined set of Read-tool paths plus
    # repository paths named in shell read commands (sed/grep/cat) — the latter is what "reads" holds.
    reads = d["reads"]; uniq = len(reads); rep = sum(reads.values()) - uniq
    rt = d["read_tool_paths"]; rt_uniq = len(rt); rt_rep = sum(rt.values()) - rt_uniq
    eps = d["endpoints"]; ue = len(eps); re_ = sum(eps.values()) - ue
    row = dict(a); row.update({
        "name": n, "group": w.get("group"), "start": w["start"], "end": w["end"], "first_activity": d["first"], "last_activity": d["last"],
        "api_requests": len(d["requests"]), "read_tool_unique_paths": rt_uniq, "read_tool_repeated": rt_rep,
        "paths_all_unique": uniq, "paths_all_repeated": rep, "read_unique_files": uniq, "read_repeated": rep,
        "gh_unique_endpoints": ue, "gh_repeated_endpoints": re_,
        "edit_unique_files": len(d["edits"]), "tools": dict(d["tools"]), "bash_kinds": dict(d["bash_kinds"]),
        "top_reads": reads.most_common(12), "top_endpoints": eps.most_common(15),
        "stable_fact_fetches_by_kind": dict(d["stable"]), "head_dependent_by_kind": dict(d["head"]), "edits": dict(d["edits"]),
    })
    out["windows"].append(row)
out["file_touches_all"] = touches.most_common()
out["file_touches_by_group"] = {g: c.most_common() for g, c in touches_by_group.items()}
json.dump(out, open(outp, "w"), indent=1)

def fmt(n): return f"{n:,}"
print("| window | api req | tool calls | tool-result bytes | Read calls (Read-tool uniq/rep) | all paths uniq/rep (Read + shell-read) | shell-read cmds | Bash | gh inv (LB) | gh uniq/rep | stable-fact | head-dep | tests tgt/full | doctor | edits (files) | cache_read tok | cache_create tok | output tok |")
print("|---|---:|---:|---:|---|---|---:|---:|---:|---|---:|---:|---|---:|---|---:|---:|---:|")
for r in out["windows"]:
    print(f"| {r['name']} | {r['api_requests']} | {r.get('tool_calls',0)} | {fmt(r.get('result_bytes',0))} | {r.get('read_calls',0)} ({r['read_tool_unique_paths']}/{r['read_tool_repeated']}) | {r['paths_all_unique']}/{r['paths_all_repeated']} | {r.get('bash:shell:read',0)} | {r.get('bash_calls',0)} | {r.get('gh_invocations_lower_bound',0)} | {r['gh_unique_endpoints']}/{r['gh_repeated_endpoints']} | {r.get('gh_stable_fact_fetches',0)} | {r.get('gh_head_dependent_fetches',0)} | {r.get('bash:test:targeted',0)}/{r.get('bash:test:full',0)} | {r.get('bash:doctor',0)} | {r.get('edit_calls',0)} ({r['edit_unique_files']}) | {fmt(r.get('tok_cache_read',0))} | {fmt(r.get('tok_cache_create',0))} | {fmt(r.get('tok_output',0))} |")
print("\nrepo file touches (Read + Edit/Write + shell-read path mentions), top 25:")
for p, n in touches.most_common(25): print(f"  {n:4d}  {p}")
