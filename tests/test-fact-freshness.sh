#!/usr/bin/env bash
# Behavioral suite for the freshness, invalidation and conflict contract (contract v1, over fact-model schema v1):
# the authority (preferences/fact-freshness.tsv) parses and is complete and agrees with the fact model (every kind
# it names is a fact-model invalidator kind, every class a fact-model class, every status an admitted status);
# the class × event matrix is derived from the event and class records, never hand-edited; every fact on the
# fact-model page carries only the kinds its class declares; every scenario executes against Example 1 of the fact
# model and yields the stale set the page states; and the page renders exactly the authority (every column of every
# record kind, one row per record, none extra; every rule verbatim).
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
sandbox_init

PLUGIN="$(cd "$(dirname "$SPARK")/.." && pwd)"
TSV="$PLUGIN/preferences/fact-freshness.tsv"
DOC="$PLUGIN/docs/reference/fact-freshness.md"
FM_TSV="$PLUGIN/preferences/fact-model.tsv"
FM_DOC="$PLUGIN/docs/reference/fact-model.md"

assert_eq() { local desc="$1" want="$2" got="$3"; if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi; }

# ======================== the authority parses and is complete ========================
for f in "$TSV" "$DOC" "$FM_TSV" "$FM_DOC"; do [ -f "$f" ] && ok || bad "missing shipped file $f"; done
rec() { grep -v '^#' "$TSV" | awk -F'\t' -v k="$1" '$1==k'; }
assert_eq "contract version is 1" "1" "$(rec version | cut -f2)"
assert_eq "written against fact-model schema version 1" "1" "$(rec schema | cut -f2)"
assert_eq "the fact model on this tree is schema version 1" "1" "$(grep -v '^#' "$FM_TSV" | awk -F'\t' '$1=="version"{print $2}')"
assert_eq "eleven event classes" "11" "$(rec event | wc -l | tr -d ' ')"
assert_eq "one kinds record per fact class" "10" "$(rec kinds | wc -l | tr -d ' ')"
assert_eq "one depends record per fact class" "10" "$(rec depends | wc -l | tr -d ' ')"
assert_eq "five effects" "5" "$(rec effect | wc -l | tr -d ' ')"
assert_eq "one matrix row per fact class" "10" "$(rec matrix | wc -l | tr -d ' ')"
assert_eq "seven conflict situations" "7" "$(rec conflict | wc -l | tr -d ' ')"
assert_eq "five unreadable failures" "5" "$(rec unreadable | wc -l | tr -d ' ')"
assert_eq "one migration rule" "1" "$(rec migration | wc -l | tr -d ' ')"
assert_eq "twenty-one executable scenarios" "21" "$(rec scenario | wc -l | tr -d ' ')"
assert_eq "fifteen rules" "15" "$(rec rule | wc -l | tr -d ' ')"
# the record kinds the header comment declares are exactly the kinds present
assert_eq "record kinds present" "collection conflict depends effect event kinds matrix migration rule scenario schema unreadable version" "$(grep -v '^#' "$TSV" | cut -f1 | sort -u | tr '\n' ' ' | sed 's/ $//')"
# every record kind's field count is constant
for k in event kinds collection depends effect matrix conflict unreadable migration scenario rule; do
  n="$(rec "$k" | awk -F'\t' '{print NF}' | sort -u | wc -l | tr -d ' ')"; [ "$n" = 1 ] && ok || bad "record kind $k has rows of differing width"
done
# shipped docs carry no bare issue-number references (doctor's tier boundary)
if grep -qE '(^|[^A-Za-z0-9/])#[0-9]+' "$DOC"; then bad "doc contains a bare issue reference"; else ok; fi

command -v python3 >/dev/null 2>&1 || { echo "  (python3 absent — cross-authority, matrix, scenario and parity checks skipped)"; finish "fact freshness (#732)"; }

# ======================== agreement with the fact model, derivation, scenarios, parity ========================
last=""
while IFS= read -r line; do
  last="$line"; case "$line" in OK*) ok ;; *) bad "$line" ;; esac
done <<EOF
$(python3 - "$TSV" "$DOC" "$FM_TSV" "$FM_DOC" 2>&1 <<'PY'
import re, sys, json, collections, hashlib
tsv, doc, fm_tsv, fm_doc = (open(p).read() for p in sys.argv[1:5])
rows = [l.split("\t") for l in tsv.split("\n") if l.strip() and not l.startswith("#")]
fm = [l.split("\t") for l in fm_tsv.split("\n") if l.strip() and not l.startswith("#")]
def say(okk, what): print(("OK " if okk else "BAD ") + what)
def recs(k): return [r for r in rows if r[0] == k]
fm_classes = [r[1] for r in fm if r[0] == "class"]; fm_kinds = {r[1] for r in fm if r[0] == "invalidator"}
fm_status = {r[1] for r in fm if r[0] == "status"}; fm_admits = {r[1]: set(r[2].split(",")) for r in fm if r[0] == "class-status"}
events = recs("event"); kinds = recs("kinds"); effects = [r[1] for r in recs("effect")]
ev_names = [e[1] for e in events]
fires = {e[1]: (set() if e[2] == "none" else set(e[2].split(","))) for e in events}
ck = {k[1]: (None if k[2] == "inputs" else set(k[2].split(","))) for k in kinds}

# --- names the fact model knows
say([k[1] for k in kinds] == fm_classes, "the kinds records name exactly the fact model's classes, in the model's order")
say([r[1] for r in recs("matrix")] == fm_classes, "the matrix rows are exactly the fact model's classes, in the model's order")
for e in events: say(fires[e[1]] <= fm_kinds, f"event {e[1]} fires only fact-model invalidator kinds ({e[2]})")
for k in kinds:
    if ck[k[1]] is not None: say(ck[k[1]] <= fm_kinds, f"class {k[1]} declares only fact-model invalidator kinds ({k[2]})")
say(sum(1 for k in kinds if ck[k[1]] is None) == 1 and ck["next_action"] is None, "exactly the derived class declares its kinds as its inputs' union")
fired_union = set().union(*fires.values())
say(fired_union == fm_kinds, f"every fact-model invalidator kind is fired by some event (unfired: {sorted(fm_kinds - fired_union) or 'none'})")
say(sum(1 for e in events if not fires[e[1]]) == 3, "exactly three events fire no token (check-run, schema, unreadable)")
say({e[1] for e in events if not fires[e[1]]} == {"check-run", "schema", "unreadable"}, "the tokenless events are check-run, schema and unreadable")
for c in recs("conflict"):
    say(c[2] in fm_status or c[2] in ("canonicalized", "historical", "malformed"), f"conflict {c[1]} outcome {c[2]} is a fact-model status or a non-fact outcome")
for u in recs("unreadable"):
    say(u[2] in fm_status and all(u[2] in fm_admits[cl] for cl in fm_classes), f"unreadable {u[1]} yields {u[2]}, a status every class admits")
say(all(c[2] != "CONFLICT" or all("CONFLICT" in fm_admits[cl] for cl in fm_classes if cl != "next_action") for c in recs("conflict")), "CONFLICT outcomes apply to source-read classes, each of which admits CONFLICT")
say(set(effects) == {"stale", "re-read", "derived", "unknown", "none"}, "the effect vocabulary is closed: stale, re-read, derived, unknown, none")

# --- the matrix is derived (F2)
def effect(cls, ev):
    if ev in ("schema", "unreadable"): return "unknown"
    if cls == "next_action": return "derived" if any(effect(c, ev) in ("stale", "re-read") for c in ck if c != "next_action") else "none"
    if fires[ev] & ck[cls]: return "stale"
    if ev == "check-run" and cls == "checks": return "re-read"
    if ev == "repository": return "re-read"   # F13
    return "none"
for m in recs("matrix"):
    want = [effect(m[1], e) for e in ev_names]; got = m[2].split(",")
    say(got == want, f"matrix row {m[1]} is derived from kinds × fires: {m[2]}" + ("" if got == want else f" (derived: {','.join(want)})"))
    say(all(x in effects for x in got), f"matrix row {m[1]} uses only the effect vocabulary")
say(all(effect("next_action", e) == ("unknown" if e in ("schema", "unreadable") else "derived") for e in ev_names), "next_action re-derives on every event that moves any input (every event moves some class)")
say(all(effect(c, "repository") != "none" for c in ck), "a repository event — including the observing identity's permission — reaches every class (F13): no cached fact survives a permission loss")
say(sorted(c for c in ck if effect(c, "repository") == "re-read") == sorted(c for c in ck if c not in ("repository", "next_action")), "under F13 every source-read class other than repository is re-read on a repository event")
# --- every event that can change a class's value reaches it (F12): the category the reviewer's findings belong to
dep = recs("depends"); say([d[1] for d in dep] == fm_classes, "the depends records name exactly the fact model's classes, in order")
for d in dep:
    evs = d[2].split(",")
    say(all(e in ev_names for e in evs), f"depends {d[1]}: every named event exists ({d[2]})")
    for e in evs:
        cell = effect(d[1], e); want = ("derived",) if d[1] == "next_action" else ("stale", "re-read")
        say(cell in want, f"depends {d[1]}: a {e} event reaches the fact — matrix cell {cell}")
say(all(e in {x for d in dep for x in d[2].split(",")} for e in ev_names if fires[e] or e == "check-run"), "every token-firing event (and check-run) changes some class's value")
say({d[1] for d in dep if "comment-created" in d[2].split(",")} == {"authority", "review", "next_action"}, "the classes whose value a created comment can change are authority, review and the derived action — each carries the node a new comment lands on")
say(all(("comment-edit" in d[2].split(",")) == ("comment-created" in d[2].split(",")) for d in dep), "a class that depends on comments depends on both their edits and their creation")

# --- every fact on the fact-model page agrees with the declared kinds
facts = []
for blk in re.findall(r"```json\n(.*?)```", fm_doc, flags=re.S):
    try: obj = json.loads(blk)
    except Exception: continue
    lst = obj["facts"] if isinstance(obj, dict) and "facts" in obj else (obj if isinstance(obj, list) else [obj])
    facts += [f for f in lst if isinstance(f, dict) and "class" in f]
say(all(isinstance(f.get("versions"), dict) and set(f["versions"]) == set(f["invalidators"]) for f in facts), "every example fact records a version for exactly its tokens (fact model R20) — the material freshness compares")
say(len(facts) >= 40, f"{len(facts)} example facts read from the fact-model page")
dupf = [c for c in recs("conflict") if c[1] == "duplicate-fields"]
say(len(dupf) == 1 and dupf[0][2] == "malformed" and "UNKNOWN" in dupf[0][3] and "CONFLICT" in dupf[0][3], "duplicate fields are classified as malformed with both the alone and the beside-valid outcomes named")
say("R14" in dupf[0][4] and any(r[0] == "rule" and r[1] == "R14" and "same field twice" in r[2] for r in fm), "the fact model's R14 states the duplicate-field rule the contract relies on")
say(any(r[0] == "rule" and r[1] == "R17" and "lists that node too" in r[2] for r in fm), "the fact model's R17 states the node-listing rule the contract relies on")
say(any(r[0] == "rule" and r[1] == "R19" and "shipped contract" in r[2] for r in fm) and "R19" in [m for m in recs("migration")][0][3], "the migration record's in-place correction of an unshipped version rests on the fact model's R19")
say(any(r[0] == "rule" and r[1] == "R20" and "versions" in r[2] for r in fm) and any(r[0] == "field" and r[1] == "versions" for r in fm), "the fact model's R20 and the versions field carry what F1 compares")
say(any(r[0] == "rule" and r[1] == "R21" and "observer" in r[2] for r in fm) and any(r[0] == "shape" and r[1] == "observer" for r in fm), "the fact model's R21 and the observer shape carry what F13 compares")
seen = collections.defaultdict(set)
for f in facts:
    ks = {t.split(":")[0] for t in f.get("invalidators", [])}; seen[f["class"]] |= ks
    if ck[f["class"]] is not None:
        say(ks <= ck[f["class"]], f"{f['class']} fact ({f['status']}, {f['source']['identity']}) carries only declared kinds {sorted(ks)}")
unexercised = {"graph": {"pull_request"}, "authority": {"pull_request"}}  # R17 admits a pull-request parent/child/blocker and a decision recorded on a pull request; the page's examples use issues
for k in kinds:
    if ck[k[1]] is not None: say(ck[k[1]] - unexercised.get(k[1], set()) <= seen[k[1]], f"every declared kind of {k[1]} appears on some example fact (declared {sorted(ck[k[1]])}, seen {sorted(seen[k[1]])}, admitted unexercised {sorted(unexercised.get(k[1], set()))})")
    if ck[k[1]] is not None: say(not (unexercised.get(k[1], set()) & seen[k[1]]), f"the unexercised list for {k[1]} names only kinds no example shows")
allk = set().union(*(ck[c] for c in ck if ck[c] is not None))
say(seen["next_action"] <= allk, "the derived fact's tokens are drawn from its inputs' kinds")

# --- scenarios execute against Example 1
ex1 = fm_doc[fm_doc.index("### Example 1"):fm_doc.index("### Example 2")]
obj = json.loads(re.findall(r"```json\n(.*?)```", ex1, flags=re.S)[0])
snap, observer = (obj["facts"], obj.get("observer")) if isinstance(obj, dict) else (obj, None)
say(len(snap) == 10 and {f["class"] for f in snap} == set(fm_classes), "Example 1 is the complete snapshot: one fact per class")
say(isinstance(observer, dict) and set(observer) == {"login", "permission", "checked_at"}, "Example 1 records its observer (login, permission, checked_at — fact model R21)")
recorded = {}
for f in snap:
    for t, v in f["versions"].items(): recorded.setdefault(t, set()).add(v)
say(all(len(vs) == 1 for vs in recorded.values()), "within Example 1 every node has one recorded version (R20)")
recorded = {t: next(iter(vs)) for t, vs in recorded.items()}
repo_tok = "repository:" + [f for f in snap if f["class"] == "repository"][0]["value"]["id"]
def digest(members): return hashlib.sha256("".join(m + "\n" for m in sorted(members.split(";") if members else [])).encode()).hexdigest()
def detect(obs):
    """fired tokens, derived from the recorded versions and the observation — F1 (versions), F13 (observer), F14 (collections)"""
    fired = set()
    for pair in obs.split(","):
        k, v = pair.split("=", 1)
        if k == "observer.permission":
            if v != observer["permission"]: fired.add(repo_tok)
            continue
        if v.startswith("digest(") and v.endswith(")"): v = digest(v[7:-1])
        if k in recorded and recorded[k] != v: fired.add(k)
    return fired
coll = {c[1]: c for c in recs("collection")}
# every invalidator kind has exactly one version form, and F1 names each form once (F1, F14)
vk = {r[1]: r[4] for r in fm if r[0] == "invalidator"}
say(set(vk.values()) == {"commit", "timestamp", "digest"}, f"the fact model's invalidator kinds use exactly the three version forms: {sorted(set(vk.values()))}")
say({k for k, v in vk.items() if v == "digest"} == set(coll), "exactly the kinds with a collection record are versioned by a digest")
say({k for k, v in vk.items() if v == "commit"} == {"head", "ref"}, "exactly head: and ref: are versioned by a commit")
f1 = [r for r in recs("rule") if r[1] == "F1"][0][2]
say("commit for head: and ref:" in f1 and "collection record" in f1 and "updated_at for every other kind" in f1, "F1 names the three version forms and defers collection tokens to their record")
# agreeing duplicates: the ordering is canonical and tie-free (F15), whatever order the source enumerates
import itertools
def select(records):
    comments = [r for r in records if "/comment/" in r]
    if comments: return min(comments, key=lambda r: int(r.rsplit("/", 1)[1]))
    return min(records, key=lambda r: r.split("@")[1])
sample = ["github.com/acme/widgets#42/comment/9100", "github.com/acme/widgets#42/comment/9099", "github.com/acme/widgets#7/comment/10000", "github.com/acme/widgets@ffffffffffffffffffffffffffffffffffffffff"]
say(all(select(list(p)) == "github.com/acme/widgets#42/comment/9099" for p in itertools.permutations(sample)), "the agreeing-duplicates selection is the same under every enumeration order (24 permutations)")
say(select(["github.com/acme/widgets#42/comment/10000", "github.com/acme/widgets#42/comment/9999"]) == "github.com/acme/widgets#42/comment/9999", "comment ids compare as numbers, not strings")
say(select(["github.com/acme/widgets@ffffffffffffffffffffffffffffffffffffffff", "github.com/acme/widgets@0000000000000000000000000000000000000000"]) == "github.com/acme/widgets@0000000000000000000000000000000000000000", "commit-recorded decisions are ordered by commit id only when no comment record agrees")
dup = [c for c in recs("conflict") if c[1] == "duplicates-agree"][0]
say("smallest identity" in dup[3] and "no tie" in dup[3] and any(r[1] == "F15" and "tie-free" in r[2] for r in recs("rule")), "the duplicates-agree record and F15 state the canonical, tie-free ordering")
say(set(coll) == {"ruleset"}, "exactly the ruleset token names a collection")
rs_tok = "ruleset:" + [f for f in snap if f["class"] == "repository"][0]["value"]["id"]
say(recorded.get(rs_tok) == digest(coll["ruleset"][3]), "Example 1 records the digest of the documented ruleset membership — the two pages agree")
say(digest("b@2;a@1") == digest("a@1;b@2") and digest("a@1") != digest("a@1;b@2") and digest("a@1;b@2") != digest("a@1;b@3"), "the digest is order-free and changes with membership or a member's version")
say(hashlib.sha256(b"a@1\nb@2\n").hexdigest() == digest("b@2;a@1"), "the digest is the SHA-256 of the sorted, newline-terminated member lines — what sort and sha256sum compute")
say(digest("") == hashlib.sha256(b"").hexdigest() and digest("") != digest(""), False) if False else say(digest("") == hashlib.sha256(b"").hexdigest(), "zero members hash zero bytes, not a lone newline")
import subprocess
sh = subprocess.run(["bash", "-c", 'for m in "$@"; do printf "%s\\n" "$m"; done | sort | sha256sum | cut -d" " -f1', "_", "b@2", "a@1"], capture_output=True, text=True).stdout.strip()
sh0 = subprocess.run(["bash", "-c", 'for m in "$@"; do printf "%s\\n" "$m"; done | sort | sha256sum | cut -d" " -f1', "_"], capture_output=True, text=True).stdout.strip()
say(sh == digest("b@2;a@1") and sh0 == digest(""), "the collection record's shell form computes the same digest as the contract, for members and for none")
say("zero bytes" in coll["ruleset"][2] and any(r[1] == "F14" and "zero bytes" in r[2] for r in recs("rule")), "the collection record and F14 state the empty-collection case")
by = {f["class"]: f for f in snap}; key_of = {r[1]: r[2] for r in fm if r[0] == "key"}
def mrow_of(ev):
    col = ev_names.index(ev); return {m[1]: m[2].split(",")[col] for m in recs("matrix")}
for s in recs("scenario"):
    name, ev, obs, expect, note = s[1:6]
    fired = detect(obs)
    stale_part, reread_part, derived_part = (expect.split(";") + ["", ""])[:3]
    stale = {f["class"] for f in snap if fired & set(f.get("invalidators", [])) and f["class"] != "next_action"}
    if ev == "none":
        say(not fired and expect == ";;", f"scenario {name}: an observation equal to the record fires nothing — freshness does not expire by age")
        continue
    say(bool(fired), f"scenario {name}: the observation {obs} is detected as a change from the recorded versions")
    say(all(t.split(":")[0] in fires[ev] for t in fired), f"scenario {name}: every fired token's kind is one the {ev} event fires ({sorted(fired)})")
    reread = {f["class"] for f in snap if f["class"] not in stale and f["class"] != "next_action"} if "repository" in stale else set()   # F13
    derived = {"next_action"} if any(key_of[c] in by["next_action"].get("inputs", []) for c in stale | reread) else set()
    want_stale = set(stale_part.split(",")) if stale_part else set(); want_derived = set(derived_part.split(",")) if derived_part else set()
    want_reread = set(reread_part.split(",")) if reread_part else set()
    say(reread == want_reread, f"scenario {name}: facts re-read under F13 are exactly {sorted(want_reread)} (got {sorted(reread)})")
    say(all(mrow_of(ev)[c] == "re-read" for c in reread), f"scenario {name}: every re-read fact's class is 're-read' in the matrix column for {ev}")
    say(stale == want_stale, f"scenario {name}: facts carrying a fired token are exactly {sorted(want_stale)} (got {sorted(stale)})")
    say(derived == want_derived, f"scenario {name}: the derived fact follows ({sorted(derived)})")
    mrow = mrow_of(ev)
    say(all(mrow[c] == "stale" for c in stale), f"scenario {name}: every stale fact's class is 'stale' in the matrix column for {ev}")
    say(all(mrow[c] in ("stale", "re-read") for c in stale) and (not derived or mrow["next_action"] == "derived"), f"scenario {name}: the matrix admits the observed effects")
    say(stale, f"scenario {name}: at least one fact is stale (a scenario that moves nothing proves nothing)")
say(len({(s[2], s[3]) for s in recs("scenario")}) == len(recs("scenario")), "every scenario is a distinct event and observation pair")
# F2 as reachability, both directions: every scenario's stale set lies in the event's column (checked above), and the
# scenarios of each token-firing event together reach exactly the Example 1 facts that carry a kind the event fires
for e in ev_names:
    if not fires[e]: continue
    reach = {f["class"] for f in snap if f["class"] != "next_action" and {t.split(":")[0] for t in f["invalidators"]} & fires[e]}
    got = set().union(*[set(s[4].split(";")[0].split(",")) for s in recs("scenario") if s[2] == e]) - {""}
    say(got == reach, f"event {e}: its scenarios together reach exactly the Example 1 facts carrying a kind it fires ({sorted(reach)}; scenarios reach {sorted(got)})")
    col = mrow_of(e); say(reach <= {c for c in col if col[c] == "stale"}, f"event {e}: every reached class is 'stale' in its matrix column (reachability)")
say(sum(1 for s in recs("scenario") if s[2] == "none") == 1, "exactly one scenario is the unchanged control")
say({s[2] for s in recs("scenario")} >= {e for e in ev_names if fires[e]}, "every token-firing event has at least one scenario")
pl = [s for s in recs("scenario") if s[1] == "permission-loss"]
say(len(pl) == 1 and pl[0][4].split(";")[0] == "repository" and set(pl[0][4].split(";")[1].split(",")) == set(fm_classes) - {"repository", "next_action"}, "the permission-loss scenario re-reads every source-read fact of the snapshot")
say(len(pl) == 1 and pl[0][3].startswith("observer.permission=") and pl[0][3].split("=")[1] != observer["permission"], "the permission loss is detected from the observer record, not handed in as a token")
say(any(s[1] == "base-switch" and s[3].startswith("pull_request:") and "head" in s[4].split(";")[0].split(",") for s in recs("scenario")), "a base-branch switch is detected from the pull request's recorded version and reaches the head fact")
say(any(s[1] == "verdict-created" and s[3].startswith("pull_request:") and "review" in s[4].split(";")[0].split(",") for s in recs("scenario")), "a created verdict is detected from the pull request's recorded version and reaches the review fact")
by_name = {s[1]: s for s in recs("scenario")}
for nm in ("ruleset-created", "ruleset-deleted", "ruleset-edited", "rulesets-all-deleted"):
    sc = by_name.get(nm); say(sc is not None and sc[3].startswith(rs_tok + "=digest(") and sc[4].split(";")[0] == "checks", f"{nm}: detected from the membership digest, reaching exactly the checks fact")
say(by_name["ruleset-deleted"][3].split("digest(")[1].rstrip(")") == "1001@2026-09-01T08:00:00Z" and "1001@2026-09-01T08:00:00Z" in coll["ruleset"][3], "the deleted-ruleset scenario keeps the remaining member's timestamp unchanged and still fires")
say(by_name["rulesets-all-deleted"][3].endswith("=digest()"), "the sole-ruleset deletion is observed as an empty membership")
say("ruleset:" in by_name["unchanged"][3] and "digest(" + coll["ruleset"][3] + ")" in by_name["unchanged"][3], "the unchanged control includes the recorded membership, which fires nothing")
say(any(u[1] == "permission-denied" and u[2] == "UNKNOWN" for u in recs("unreadable")), "the re-read after a permission loss has a closed outcome: UNKNOWN")
# the three findings of round 1, as scenarios: a created verdict, a created grant, a base-branch switch
by_name = {s[1]: s for s in recs("scenario")}
say("review" in by_name["verdict-created"][4].split(";")[0].split(","), "a verdict comment created on the pull request reaches the review fact")
say(by_name["grant-created"][4].split(";")[0] == "authority", "a decision comment created on the decision issue reaches exactly the authority fact")
say("head" in by_name["base-switch"][4].split(";")[0].split(","), "a base-branch switch (pull-request metadata, no tip moves) reaches the head fact")
say(by_name["base-switch"][2] == "metadata" and by_name["verdict-created"][2] == "comment-created" and by_name["verdict-edit"][2] == "comment-edit", "the base switch is a metadata event, the created verdict a comment-created event, the edited verdict a comment-edit event")

# --- parity: the page renders exactly the authority
def norm(x): return re.sub(r"\s+", " ", x.replace("\\|", "|").replace("`", "")).strip()
def cells(line): return [c.strip() for c in line.strip().strip("|").split(" | ")]
def table(header):
    i = doc.index(header); body = doc[doc.index("\n", doc.index("\n", i) + 1) + 1:]
    return [cells(l) for l in body.split("\n\n")[0].split("\n") if l.startswith("|")]
def exact(header, k, cols, label):
    """every row of the table is a record of kind k with the listed TSV columns, in order, and nothing else"""
    t = table(header); want = recs(k)
    say(len(t) == len(want), f"the {label} table has one row per {k} record ({len(t)} rows, {len(want)} records)")
    for r, c in zip(want, t):
        say([norm(x) for x in c] == [norm(r[i]) for i in cols], f"{label} row {r[1]} is the TSV's text, column for column")
    return t
exact("| Event | Fires |", "event", [1, 2, 3, 4], "event")
exact("| Class | Invalidator kinds |", "kinds", [1, 2, 3], "kinds")
exact("| Token kind | Algorithm |", "collection", [1, 2, 3, 4], "collection")
exact("| Class | Value changes on |", "depends", [1, 2, 3], "depends")
exact("| Effect | Meaning |", "effect", [1, 2], "effect")
exact("| Situation | Outcome |", "conflict", [1, 2, 3, 4], "conflict")
exact("| Failure | Status |", "unreadable", [1, 2, 3, 4], "unreadable")
exact("| From | To |", "migration", [1, 2, 3], "migration")
exact("| Scenario | Event |", "scenario", [1, 2, 3, 4, 5], "scenario")
mt = table("| Class | `push` |")
hdr = cells(doc[doc.index("| Class | `push` |"):].split("\n")[0])
say([norm(h) for h in hdr[1:]] == ev_names, "the matrix columns are the events, in event order")
say(len(mt) == len(recs("matrix")), "the matrix table has one row per matrix record")
for r, c in zip(recs("matrix"), mt):
    say(norm(c[0]) == r[1] and [norm(x) for x in c[1:]] == r[2].split(","), f"matrix row {r[1]} on the page is the TSV's, cell for cell")
say(re.search(r"contract version 1, written against fact-model\s+schema version 1", doc) is not None, "the page names the contract version and the schema version it binds to")
rules_md = doc[doc.index("## Rules"):doc.index("## Relation to the rest of the model")]
found = re.findall(r"^- \*\*(F\d+)\*\* (.*?)(?=^- \*\*F|\Z)", rules_md, flags=re.S | re.M)
say([f[0] for f in found] == [r[1] for r in recs("rule")], "the rules list has exactly the TSV's rules, in order")
for r, f in zip(recs("rule"), found): say(norm(f[1]) == norm(r[2]), f"rule {r[1]} statement is the TSV's, verbatim")
covered = {"version": {1}, "schema": {1}, "event": {1, 2, 3, 4}, "kinds": {1, 2, 3}, "collection": {1, 2, 3, 4}, "depends": {1, 2, 3}, "effect": {1, 2}, "matrix": {1, 2}, "conflict": {1, 2, 3, 4}, "unreadable": {1, 2, 3, 4}, "migration": {1, 2, 3}, "scenario": {1, 2, 3, 4, 5}, "rule": {1, 2}}
unchecked = sorted({f"{r[0]}[{i}]" for r in rows for i in range(1, len(r)) if i not in covered.get(r[0], set())})
say(not unchecked, f"every column of every record kind is rendered on the page and compared: {unchecked or 'none unchecked'}")
for blk in re.findall(r"(?:^\|.*\n)+", doc, flags=re.M):
    ls = blk.strip("\n").split("\n"); h = cells(ls[0]); n = len(h)
    sep = [c.strip() for c in ls[1].strip().strip("|").split("|")]
    off = [l for l in ls[2:] if len(cells(l)) != n]
    say(not off and len(sep) == n and all(c and set(c) <= set("-:") for c in sep), f"table '{h[0]}' has {n} columns in every row")
print("OK the python block ran to completion")
PY
)
EOF
[ "$last" = "OK the python block ran to completion" ] && ok || bad "the python block did not run to completion (an exception would otherwise pass silently)"

# ======================== the derivation is discriminating: a hand-edited matrix cell fails ========================
mtsv="$WORK/mutant-freshness.tsv"
python3 - "$TSV" "$mtsv" <<'PY'
import sys
ls = open(sys.argv[1]).read().split("\n")
for i, l in enumerate(ls):
    if l.startswith("matrix\trepository\t"):
        c = l.split("\t"); cells = c[2].split(","); cells[cells.index("stale")] = "none"; c[2] = ",".join(cells); ls[i] = "\t".join(c)
open(sys.argv[2], "w").write("\n".join(ls))
PY
cmp -s "$TSV" "$mtsv" && bad "control: the mutation did not change the repository matrix row" || ok
if python3 - "$mtsv" <<'PY' 2>/dev/null
import sys
rows = [l.split("\t") for l in open(sys.argv[1]).read().split("\n") if l.strip() and not l.startswith("#")]
ev = [r[1] for r in rows if r[0] == "event"]; fires = {r[1]: (set() if r[2] == "none" else set(r[2].split(","))) for r in rows if r[0] == "event"}
ck = {r[1]: (None if r[2] == "inputs" else set(r[2].split(","))) for r in rows if r[0] == "kinds"}
m = {r[1]: r[2].split(",") for r in rows if r[0] == "matrix"}
def eff(c, e):
    if e in ("schema", "unreadable"): return "unknown"
    if c == "next_action": return "derived" if any(eff(x, e) in ("stale", "re-read") for x in ck if x != "next_action") else "none"
    if fires[e] & ck[c]: return "stale"
    if e == "check-run" and c == "checks": return "re-read"
    return "re-read" if e == "repository" else "none"   # F13
sys.exit(0 if all(m[c] == [eff(c, e) for e in ev] for c in m) else 1)
PY
then bad "a hand-edited matrix cell (repository unaffected by a repository event) must fail the derivation check"; else ok; fi

finish "fact freshness (#732)"
