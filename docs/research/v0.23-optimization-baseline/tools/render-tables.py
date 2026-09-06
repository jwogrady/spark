#!/usr/bin/env python3
"""render-tables.py <rawdir> — render the baseline tables (markdown) from the raw/derived evidence. Interpretation lives elsewhere."""
import json, sys, os, collections, csv
from datetime import datetime, timezone
raw = sys.argv[1]
T = lambda s: datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
def J(p): return json.load(open(os.path.join(raw, p)))
def JD(p):  # prefer the full derivation when present, else the committed compact projection
    return J(p + "/derived.json") if os.path.exists(os.path.join(raw, p, "derived.json")) else J(p + "/derived.compact.json")
d = {"A": JD("pr727"), "B": JD("pr724")}
TW = J("transcript-workloads.json") if os.path.exists(os.path.join(raw, "transcript-workloads.json")) else J("transcript-workloads.compact.json")
tw = {w["group"]: w for w in TW["windows"] if w["group"] in ("A", "B")}
# per-round counters: the committed TSV projection (or the full JSON when present)
if os.path.exists(os.path.join(raw, "transcript-rounds.tsv")):
    _rows = list(csv.DictReader(open(os.path.join(raw, "transcript-rounds.tsv")), delimiter="\t"))
    tr = [{k: (int(v) if v.lstrip("-").isdigit() else v) for k, v in r.items()} for r in _rows]
else:
    tr = J("transcript-rounds.json")["windows"]
cls = list(csv.DictReader(open(os.path.join(raw, "findings-classification.tsv")), delimiter="\t"))
fmt = lambda n: f"{n:,}" if isinstance(n, (int, float)) else str(n)

def active_seconds(dd, gap=1800):
    """Sum of inter-verdict intervals, excluding idle gaps longer than `gap` seconds (the writer lane was not working)."""
    ts = [T(dd["first_commit"])] + [T(r["at"]) for r in dd["rounds"]]
    tot = 0; skipped = 0
    for a, b in zip(ts, ts[1:]):
        s = (b - a).total_seconds()
        if s > gap: skipped += s
        else: tot += s
    return int(tot), int(skipped)

out = []
out.append("## T1 — Workload summary (GitHub evidence + writer-lane transcript)\n")
out.append("| Metric | A: PR #727 (#726) | B: PR #724 (#722) | Method |")
out.append("|---|---:|---:|---|")
rows = []
for k, label in (("commits", "commits"), ("additions", "lines added"), ("deletions", "lines deleted"), ("distinct_files_touched", "distinct files touched"),
                 ("reviewer_verdicts", "reviewer verdicts (exact-HEAD, trusted login)"), ("findings_total", "reviewer finding bullets (raw)"),
                 ("author_comments", "writer top-level PR comments"), ("author_comment_chars", "writer comment chars"), ("reviewer_body_chars", "reviewer body chars"),
                 ("formal_reviews", "formal PR reviews (human)"), ("echo_markers_untrusted_login", "marker echoes by untrusted login (not verdicts)")):
    rows.append((label, d["A"][k], d["B"][k], "GitHub REST, derived.json"))
rows.append(("verdict outcome", "16× CHANGES REQUIRED, no PASS (open)", "31× CHANGES REQUIRED → PASS, merged", "derived.json verdict_counts"))
aA, gA = active_seconds(d["A"]); aB, gB = active_seconds(d["B"])
rows.append(("wall clock first commit → last verdict (s)", d["A"]["wall_first_commit_to_last_verdict_s"], d["B"]["wall_first_commit_to_last_verdict_s"], "commit author date → verdict comment created_at"))
rows.append(("of which idle gaps >30 min (s)", gA, gB, "inter-verdict intervals > 1800s"))
rows.append(("active wall clock (s)", aA, aB, "wall minus idle gaps"))
for g in ("A", "B"):  # per-round rows carry the latency; the compact projection has no top-level list
    lat = sorted(r["push_to_verdict_s"] for r in d[g]["rounds"] if r.get("push_to_verdict_s") is not None); d[g]["_lat"] = lat
rows.append(("push → verdict latency median (s)", d["A"]["_lat"][len(d["A"]["_lat"])//2], d["B"]["_lat"][len(d["B"]["_lat"])//2], "head commit date → marker created_at"))
for wfn in ("OpenAI Review", "validate", "milestone-gate", "docs-truth"):
    rows.append((f"CI workflow '{wfn}' runs / seconds", f"{d['A']['workflow_runs'][wfn]['runs']} / {d['A']['workflow_runs'][wfn]['seconds']}", f"{d['B']['workflow_runs'][wfn]['runs']} / {d['B']['workflow_runs'][wfn]['seconds']}", "actions/runs on the PR branch"))
tx = [("api_requests", "model API requests (assistant turns)"), ("tool_calls", "tool calls"), ("result_bytes", "tool-result bytes returned to the model"),
      ("read_calls", "Read tool calls"), ("read_unique_files", "  unique paths"), ("read_repeated", "  repeated reads"), ("bash:shell:read", "shell read commands (sed/grep/cat over repo files)"),
      ("bash_calls", "Bash calls"), ("gh_invocations_lower_bound", "gh invocations (lower bound)"), ("gh_unique_endpoints", "  unique normalized endpoints"), ("gh_repeated_endpoints", "  repeated endpoint fetches"),
      ("gh_stable_fact_fetches", "  HEAD-independent fact fetches (authority/parent/milestone/identity)"), ("gh_head_dependent_fetches", "  HEAD-dependent fetches (PR conversation, checks)"),
      ("bash:test:targeted", "targeted verification runs (run.sh --only / single suite)"), ("bash:test:full", "full-suite certification runs"), ("bash:doctor", "spark doctor runs"), ("bash:syntax-check", "bash -n runs"),
      ("edit_calls", "Edit/Write calls on repo files"), ("edit_unique_files", "  unique repo files edited"), ("subagents", "subagents spawned"),
      ("tok_cache_read", "context tokens re-read from cache (sum over requests)"), ("tok_cache_create", "context tokens newly cached"), ("tok_input", "uncached input tokens"), ("tok_output", "output tokens")]
for k, label in tx:
    rows.append((label, tw["A"].get(k, 0), tw["B"].get(k, 0), "session transcript (writer lane), analyze-transcript.py"))
for g in ("A", "B"):
    w = tw[g]; ctx = w.get("tok_cache_read", 0) + w.get("tok_cache_create", 0) + w.get("tok_input", 0)
    w["_ctx"] = ctx; w["_ctx_per_req"] = ctx / max(1, w["api_requests"]); w["_ctx_per_line"] = ctx / max(1, d[g]["additions"] + d[g]["deletions"])
    w["_ctx_per_out"] = ctx / max(1, w.get("tok_output", 1))
rows.append(("context tokens processed (cache_read+cache_create+input)", int(tw["A"]["_ctx"]), int(tw["B"]["_ctx"]), "observational (API usage accounting)"))
rows.append(("  mean context per request", int(tw["A"]["_ctx_per_req"]), int(tw["B"]["_ctx_per_req"]), "observational"))
rows.append(("  context tokens per changed line (amplification)", int(tw["A"]["_ctx_per_line"]), int(tw["B"]["_ctx_per_line"]), "observational; changed lines = additions+deletions"))
rows.append(("  context tokens per output token", int(tw["A"]["_ctx_per_out"]), int(tw["B"]["_ctx_per_out"]), "observational"))
for r in rows: out.append(f"| {r[0]} | {fmt(r[1])} | {fmt(r[2])} | {r[3]} |")

out.append("\n## T2 — Per-round detail (verdict window = previous verdict → this verdict)\n")
for g, pr in (("A", 727), ("B", 724)):
    out.append(f"\n### PR #{pr}\n")
    out.append("| round | head | verdict | findings | files cited by reviewer | push→verdict s | round wall s | API req | tool calls | gh (LB) | stable | head-dep | tests tgt/full | doctor | edits | ctx tokens |")
    out.append("|---:|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|")
    prev = T(d[g]["first_commit"])
    for r in d[g]["rounds"]:
        w = next((x for x in tr if x["group"] == g and x["name"].split()[1] == f"r{r['n']}"), {})
        wall = int((T(r["at"]) - prev).total_seconds()); prev = T(r["at"])
        ctx = w.get("tok_cache_read", 0) + w.get("tok_cache_create", 0) + w.get("tok_input", 0)
        out.append(f"| {r['n']} | {r['head7']} | {r['verdict']} | {r['findings']} | {', '.join(f.split('/')[-1] for f in r['files_cited'])} | {int(r['push_to_verdict_s']) if r['push_to_verdict_s'] is not None else '-'} | {wall} | {w.get('api_requests',0)} | {w.get('tool_calls',0)} | {w.get('gh_invocations_lower_bound',0)} | {w.get('gh_stable_fact_fetches',0)} | {w.get('gh_head_dependent_fetches',0)} | {w.get('bash:test:targeted',0)}/{w.get('bash:test:full',0)} | {w.get('bash:doctor',0)} | {w.get('edit_calls',0)} | {fmt(ctx)} |")

out.append("\n## T3 — Reviewer finding classification (hand-classified from the reviewer bodies; PASS-round affirmations excluded)\n")
cats = {"IMPL": "genuinely new implementation defect", "REPR": "representation / transport boundary defect", "DUP": "duplicated-semantic drift (two surfaces disagree)",
        "STALE": "stale / reconstructed-state defect", "TEST": "test-harness / fixture / instrument defect", "GOV": "governance / specification / evidence-contract ambiguity"}
out.append("| category | meaning | A: #727 | B: #724 |")
out.append("|---|---|---:|---:|")
cnt = {g: collections.Counter() for g in ("727", "724")}; rep = {g: 0 for g in ("727", "724")}
for row in cls:
    cnt[row["pr"]][row["category"]] += 1
    if row["repeat_of"]: rep[row["pr"]] += 1
for c, m in cats.items():
    out.append(f"| {c} | {m} | {cnt['727'][c]} ({100*cnt['727'][c]//max(1,sum(cnt['727'].values()))}%) | {cnt['724'][c]} ({100*cnt['724'][c]//max(1,sum(cnt['724'].values()))}%) |")
out.append(f"| **total classified** | | {sum(cnt['727'].values())} | {sum(cnt['724'].values())} |")
out.append(f"| of which repeats of an earlier finding (same lineage, unfixed or partially fixed) | | {rep['727']} | {rep['724']} |")

out.append("\n## T4 — Reviewer-cited files by round (revisit concentration)\n")
for g, pr in (("A", 727), ("B", 724)):
    out.append(f"- PR #{pr}: " + "; ".join(f"`{f}` cited in {n}/{len(d[g]['rounds'])} rounds" for f, n in list(d[g]["files_cited_rounds"].items())[:5]))

out.append("\n## T5 — Repeated GitHub surfaces fetched by the writer lane (normalized endpoint → invocations, lower bound)\n")
for g, pr in (("A", 727), ("B", 724)):
    out.append(f"\nPR #{pr}:\n")
    out.append("| endpoint | fetches | class |")
    out.append("|---|---:|---|")
    for ep, n in tw[g]["top_endpoints"][:12]:
        klass = "HEAD-independent" if any(s in ep for s in ("677", "726", "480", "481", "722", "723", "milestones", "sub_issues")) else ("HEAD-dependent" if any(s in ep for s in ("comments", "pr view", "pr checks", "check-runs", "graphql")) else "other")
        out.append(f"| `{ep}` | {n} | {klass} |")
    out.append(f"\nHEAD-independent fetches by kind: {tw[g]['stable_fact_fetches_by_kind']}; HEAD-dependent by kind: {tw[g]['head_dependent_by_kind']}")

out.append("\n## T6 — Repository files touched by the writer lane (Read + Edit/Write + shell-read mentions)\n")
tb = TW["file_touches_by_group"]
for g, pr in (("A", 727), ("B", 724)):
    out.append(f"- PR #{pr}: " + "; ".join(f"`{p}` ×{n}" for p, n in tb.get(g, [])[:8]))
for cand in ("transcript-aug.json", "transcript-aug.compact.json"):
    if os.path.exists(os.path.join(raw, cand)):
        out.append("- Aug 30–31 session (different work, same lane): " + "; ".join(f"`{p}` ×{n}" for p, n in J(cand)["file_touches_all"][:10])); break
else:
    out.append("- Aug 30–31 session: see `raw/transcript-aug.compact.json` in the repository-baseline bundle (#737).")
out.append("\n## T7 — Reviewer comments of record (immutable source for the classification)\n")
for g, pr in (("A", 727), ("B", 724)):
    out.append(f"- PR #{pr}: " + ", ".join(f"r{r['n']} [{r['comment_id']}]({r['comment_url']})" for r in d[g]["rounds"]))
open(os.path.join(raw, "baseline-tables.md"), "w").write("\n".join(out) + "\n")
print("\n".join(out))
