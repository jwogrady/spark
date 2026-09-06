#!/usr/bin/env bash
# Behavioral suite for the operative fact model (schema v1): the machine-readable
# authority (preferences/fact-model.tsv) parses and is complete; the shipped
# reference page renders exactly that authority (parity, never prose drift);
# every JSON example on the page validates against the schema, so the examples
# are fixtures rather than illustrations; and the validator itself is proven
# discriminating with mutation controls (a permissive validator would pass a
# schema that lets UNKNOWN collapse into a value, or a bare #42 pass as an id).
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
sandbox_init

PLUGIN="$(cd "$(dirname "$SPARK")/.." && pwd)"
TSV="$PLUGIN/preferences/fact-model.tsv"
DOC="$PLUGIN/docs/reference/fact-model.md"

# Exact-match assertion (the shared lib carries exit-code and substring asserts).
assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then ok; else bad "$desc — want '$want', got '$got'"; fi
}

# ======================== the authority parses and is complete ========================
[ -f "$TSV" ] && ok || bad "fact-model.tsv is shipped under preferences/"
[ -f "$DOC" ] && ok || bad "reference/fact-model.md is shipped"

rec() { grep -v '^#' "$TSV" | awk -F'\t' -v k="$1" '$1==k' ; }
assert_eq "schema version is 1" "1" "$(rec version | cut -f2)"
assert_eq "ten fact classes" "10" "$(rec class | wc -l | tr -d ' ')"
assert_eq "nine required + one derived class" "9 1" "$(rec class | cut -f3 | sort | uniq -c | awk '{print $1}' | sort -rn | tr '\n' ' ' | sed 's/ $//')"
assert_eq "three envelope facets" "3" "$(rec facet | wc -l | tr -d ' ')"
assert_eq "exactly one canonical key per class" "$(rec class | cut -f2 | sort | tr '\n' ' ')" "$(rec key | cut -f2 | sort | tr '\n' ' ')"
assert_eq "every canonical key is prefixed by its class" "" "$(rec key | awk -F'\t' 'index($3, $2 ".") != 1')"
assert_eq "one derivable reserved boundary in v1" "1" "$(rec boundary-evidence | wc -l | tr -d ' ')"
for b in $(rec boundary-evidence | cut -f2); do printf '%s' "$b" | grep -qE "$(rec identifier | awk -F'\t' '$2=="boundary"{print $3}')" && ok || bad "boundary-evidence $b is in the closed boundary vocabulary"; done
for k in $(rec boundary-evidence | cut -f3); do rec key | cut -f3 | grep -qx "$k" && ok || bad "boundary-evidence names canonical key $k"; done
assert_eq "four status tokens" "4" "$(rec status | wc -l | tr -d ' ')"
assert_eq "ESTABLISHED is the only status that may carry a value" "ESTABLISHED" "$(rec status | awk -F'\t' '$3=="yes"{print $2}')"
assert_eq "twelve envelope fields" "12" "$(rec field | wc -l | tr -d ' ')"
assert_eq "value is optional in the envelope (present only when ESTABLISHED)" "optional" "$(rec field | awk -F'\t' '$2=="value"{print $3}')"
assert_eq "five source types" "5" "$(rec source | wc -l | tr -d ' ')"
assert_eq "fifteen rules" "15" "$(rec rule | wc -l | tr -d ' ')"
assert_eq "one source-version grammar per source type" "$(rec source | cut -f2 | sort | tr '\n' ' ')" "$(rec source-version | cut -f2 | sort | tr '\n' ' ')"
assert_eq "seventeen identifier kinds" "17" "$(rec identifier | wc -l | tr -d ' ')"
for k in issue-state check-state scope boundary decision-record derived-version; do rec identifier | cut -f2 | grep -qx "$k" && ok || bad "closed vocabulary $k declared"; done
assert_eq "one source-identity grammar per source type" "$(rec source | cut -f2 | sort | tr '\n' ' ')" "$(rec source-identity | cut -f2 | sort | tr '\n' ' ')"
while IFS=$'\t' read -r _ kind rx _; do
  if printf 'probe' | grep -qE "$rx" >/dev/null 2>&1; then rc=0; else rc=$?; fi
  [ "$rc" -le 1 ] && ok || bad "source-identity regex for $kind compiles"
done <<EOF
$(rec source-identity)
EOF
for c in work_unit repository placement graph authority acceptance head review checks next_action; do
  rec class | cut -f2 | grep -qx "$c" && ok || bad "class $c declared"
done
# every identifier regex compiles (grep -E accepts it)
while IFS=$'\t' read -r _ kind rx _; do
  if printf 'probe' | grep -qE "$rx" >/dev/null 2>&1; then rc=0; else rc=$?; fi   # 1 = no match (fine); 2 = bad regex
  [ "$rc" -le 1 ] && ok || bad "identifier regex for $kind compiles"
done <<EOF
$(rec identifier)
EOF

# ======================== the page renders the authority (parity) ========================
for c in $(rec class | cut -f2); do grep -q "^| \`$c\` |" "$DOC" && ok || bad "doc table names class $c"; done
for s in $(rec status | cut -f2); do grep -q "^| \`$s\` |" "$DOC" && ok || bad "doc table names status $s"; done
for f in $(rec field | cut -f2); do grep -q "^| \`$f\` |" "$DOC" && ok || bad "doc envelope table names field $f"; done
while IFS=$'\t' read -r _ c k; do grep -q "^| \`$c\` | \`$k\` |" "$DOC" && ok || bad "doc class table shows canonical key $k"; done <<EOF
$(rec key)
EOF
for b in $(rec boundary-evidence | cut -f2); do grep -q "^| \`$b\` | \`$(rec boundary-evidence | awk -F'\t' -v b="$b" '$2==b{print $3}')\` |" "$DOC" && ok || bad "doc boundary table names $b with its evidence fact"; done
for k in $(rec identifier | cut -f2); do grep -q "^| $k |" "$DOC" && ok || bad "doc identifier table names $k"; done
for k in $(rec source-identity | cut -f2); do grep -q "^| \`$k\` |" "$DOC" && ok || bad "doc source table names $k"; done
for r in $(rec rule | cut -f2); do grep -q "^- \*\*$r\*\*" "$DOC" && ok || bad "doc states rule $r"; done
grep -q 'preferences/fact-model.tsv' "$DOC" && ok || bad "doc names its machine-readable authority"
grep -qE '^| `next_action` \| `next_action.governed` \| derived' "$DOC" && ok || bad "doc marks next_action as derived"
assert_eq "seven examples on the page" "7" "$(grep -c '^### Example [1-7] — ' "$DOC")"
assert_eq "exactly one example is a complete snapshot" "1" "$(grep -c '^### Example [1-7] — .*(complete snapshot)$' "$DOC")"
assert_eq "the other six are marked as fragments" "6" "$(grep -c '^### Example [1-7] — .*(fragment)$' "$DOC")"
# shipped docs carry no bare issue-number references (doctor's tier boundary); a canonical work-unit id
# such as github.com/acme/widgets#42 has a name immediately before the '#', so it is not a bare reference
if grep -qE '(^|[^A-Za-z0-9/])#[0-9]+' "$DOC"; then bad "doc contains a bare issue reference"; else ok; fi

# ======================== python3 validator over every example ========================
if ! command -v python3 >/dev/null 2>&1; then
  echo "  (python3 absent — example validation and mutation controls skipped; parity checks above still ran)"
  finish "fact model (#731)"
fi
VAL="$WORK/validate.py"
cat > "$VAL" <<'PY'
import json, re, sys
tsv, doc = sys.argv[1], sys.argv[2]
rows = [l.rstrip("\n").split("\t") for l in open(tsv) if l.strip() and not l.startswith("#")]
classes = {r[1]: r[2] for r in rows if r[0] == "class"}
statuses = {r[1]: r[2] for r in rows if r[0] == "status"}
fields = {r[1]: r[2] for r in rows if r[0] == "field"}
ids = {r[1]: re.compile(r[2]) for r in rows if r[0] == "identifier"}
sources = {r[1] for r in rows if r[0] == "source"}
sid = {r[1]: re.compile(r[2]) for r in rows if r[0] == "source-identity"}
sver = {r[1]: re.compile(r[2]) for r in rows if r[0] == "source-version"}
canon = {r[1]: r[2] for r in rows if r[0] == "key"}                       # class -> its one canonical key (R1)
evidence = {r[1]: (r[2], r[3], r[4]) for r in rows if r[0] == "boundary-evidence"}   # boundary -> (fact key, field, condition)
# exact value shapes (R14): the declared keys and nothing else, recursively
SHAPES = {"work_unit": {"kind", "id"}, "repository": {"id", "default_branch"}, "placement": {"milestone", "release", "gate"},
          "graph": {"parent", "children", "blocked_by"}, "authority": {"grants", "human_boundaries"}, "acceptance": {"contract", "head", "items"},
          "head": {"head", "base_ref", "base", "current"}, "review": {"verdict", "head", "reviewer", "record"},
          "checks": {"head", "required", "results"}, "next_action": {"action", "because", "boundary"}}
NESTED = {"graph.parent": {"id", "state"}, "graph.children[]": {"id", "state"}, "graph.blocked_by[]": {"id", "state"},
          "authority.grants[]": {"decision", "target", "scopes"}, "authority.human_boundaries[]": {"decision", "target", "boundary"},
          "acceptance.items[]": {"id", "state"}, "checks.results[]": {"name", "state"}}
def exact(obj, keys, where):
    if not isinstance(obj, dict): fail(f"{where} must be an object")
    if set(obj) != keys: fail(f"{where} keys {sorted(obj)} != declared {sorted(keys)} (R14)")
def shape(c, v):
    exact(v, SHAPES[c], f"{c}.value")
    for k, sub in NESTED.items():
        cls, path = k.split(".", 1)
        if cls != c: continue
        if path.endswith("[]"):
            items = v[path[:-2]]
            if not isinstance(items, list): fail(f"{k} must be a list")
            for it in items: exact(it, sub, k)
        else:
            if v[path] != "none": exact(v[path], sub, k)
    for k in ("required", "because", "human_boundaries"):
        if k in v and not isinstance(v[k], list): fail(f"{c}.{k} must be a list")
version = [r[1] for r in rows if r[0] == "version"][0]
HEAD_BOUND = {"head", "review", "checks", "acceptance"}
FORBIDDEN_KEYS = {"body", "comments", "timeline", "prose", "summary", "history"}
ISO = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

def fail(msg): raise ValueError(msg)

def check_fact(f):
    if not isinstance(f, dict): fail("fact is not an object")
    for k in FORBIDDEN_KEYS & set(f): fail(f"forbidden prose field {k}")
    for name, req in fields.items():
        if req == "required" and name not in f: fail(f"missing required field {name}")
    for k in f:
        if k not in fields: fail(f"unknown field {k}")
    if f["schema_version"] != version: fail("schema_version mismatch")
    if not ids["fact-key"].match(f["key"]): fail(f"key not canonical: {f['key']}")
    if f["class"] not in classes: fail(f"unknown class {f['class']}")
    if f["key"].split(".")[0] != f["class"]: fail("key prefix must equal class")
    if f["key"] != canon[f["class"]]: fail(f"key {f['key']} is not the canonical key {canon[f['class']]} of class {f['class']} (R1)")
    if "inferred" in f and f["inferred"] is not True: fail("inferred must be the literal true when present")
    if f["status"] not in statuses: fail(f"unknown status {f['status']}")
    if "value" in f and f["value"] is None: fail("value: null is not a representation of absence; omit the field")
    if statuses[f["status"]] == "no" and "value" in f: fail(f"{f['status']} fact carries a value")
    if f["status"] == "ESTABLISHED" and "value" not in f: fail("ESTABLISHED fact without value")
    if f["status"] in ("UNKNOWN", "CONFLICT") and "detail" not in f: fail(f"{f['status']} without detail")
    src = f["source"]
    if set(src) != {"type", "identity", "version"}: fail("source must be {type, identity, version}")
    if src["type"] not in sources: fail(f"unknown source type {src['type']}")
    if not sid[src["type"]].match(str(src["identity"])): fail(f"source.identity {src['identity']!r} is not in the {src['type']} grammar (R14)")
    if not src["version"]: fail("source.version empty")
    if not sver[src["type"]].match(str(src["version"])): fail(f"source.version {src['version']!r} is not in the {src['type']} version grammar (R14)")
    if src["type"] == "derived":
        if not f.get("inputs"): fail("derived fact without inputs")
        if not ids["derived-version"].match(src["version"]): fail("derived source.version is not a derived-version (R4)")
        parts = src["version"].split(";")
        if parts[0] != version: fail("derived-version must start with the schema version")
        vkeys = [p.split("@", 1)[0] for p in parts[1:]]
        if vkeys != sorted(f["inputs"]): fail("derived-version must list exactly the inputs, sorted by key (R4)")
    if f.get("inputs") is not None and any(not ids["fact-key"].match(i) for i in f["inputs"]): fail("inputs must be fact keys")
    if not ISO.match(f["observed_at"]): fail("observed_at not ISO-8601 Z")
    if not isinstance(f["invalidators"], list) or not f["invalidators"]: fail("invalidators must be a non-empty list")
    if not f["provenance"]: fail("provenance empty")
    if f["class"] in HEAD_BOUND and f["status"] == "ESTABLISHED":
        bound = f["value"].get("head") if isinstance(f.get("value"), dict) else None
        if not bound: fail(f"HEAD-bound class {f['class']} must carry its HEAD in the value (R7)")
        if [i for i in f["invalidators"] if i.startswith("head:")] != [f"head:{bound}"]: fail(f"HEAD-bound class {f['class']} must list exactly its own HEAD as its one head: invalidator (R7)")
    elif f["class"] in HEAD_BOUND and not any(i.startswith("head:") for i in f["invalidators"]): fail(f"HEAD-bound class {f['class']} without a head: invalidator")
    if f["status"] == "CONFLICT" and len(f["detail"].get("candidates", [])) < 2: fail("CONFLICT must name at least two candidates")
    v = f.get("value")
    if v is None: return
    c = f["class"]
    shape(c, v)
    def wu(x):
        if not ids["work-unit"].match(x): fail(f"work-unit id not canonical: {x}")
    def sha(x):
        if not ids["commit"].match(x): fail(f"commit not canonical: {x}")
    if c == "work_unit": wu(v["id"]); v["kind"] in ("issue", "pull_request") or fail("bad kind")
    if c == "repository": ids["repository"].match(v["id"]) or fail("repository id not canonical"); ids["ref"].match(v["default_branch"]) or fail("bad ref")
    if c == "placement":
        v["milestone"] == "none" or ids["milestone"].match(v["milestone"]) or fail("milestone id not canonical")
        v["release"] == "none" or ids["release"].match(v["release"]) or fail("release not canonical")
        v["gate"] == "none" or wu(v["gate"])
    if c == "graph":
        def rel(x):
            if not isinstance(x, dict) or set(x) != {"id", "state"}: fail("relationship must be {id, state}")
            wu(x["id"]); ids["issue-state"].match(x["state"]) or fail(f"relationship state outside vocabulary: {x['state']}")
        v["parent"] == "none" or rel(v["parent"])
        for x in v["children"] + v["blocked_by"]: rel(x)
    if c == "authority":
        for g in v["grants"]:
            ids["decision-record"].match(g["decision"]) or fail("grant decision is not a durable decision record (R5)")
            ids["repository"].match(g["target"]) or ids["work-unit"].match(g["target"]) or fail("grant target must be a canonical repository or work unit (R14)")
            g["scopes"] and all(ids["scope"].match(s) for s in g["scopes"]) or fail("grant scopes must be non-empty closed tokens (R13)")
        for b in v["human_boundaries"]:
            ids["decision-record"].match(b["decision"]) or fail("boundary decision is not a durable decision record (R5)")
            ids["repository"].match(b["target"]) or ids["work-unit"].match(b["target"]) or fail("boundary target must be a canonical repository or work unit (R14)")
            ids["boundary"].match(b["boundary"]) or fail("boundary outside the closed vocabulary (R13)")
        if f["source"]["type"] != "human-decision": fail("authority must come from a human-decision source")
        if "inferred" in f: fail("authority can never be inferred")
    if c == "acceptance":
        wu(v["contract"]); sha(v["head"])
        for it in v["items"]: it["state"] in ("MET", "NOT_MET", "UNKNOWN") or fail("bad acceptance state")
    if c == "head": sha(v["head"]); sha(v["base"]); ids["ref"].match(v["base_ref"]) or fail("bad base_ref"); isinstance(v["current"], bool) or fail("current must be boolean")
    if c == "review": ids["verdict"].match(v["verdict"]) or fail("verdict outside vocabulary"); sha(v["head"]); ids["login"].match(v["reviewer"]) or fail("reviewer not login:"); ids["comment"].match(v["record"]) or fail("record not a comment id")
    if c == "checks":
        sha(v["head"]); isinstance(v["required"], list) or fail("required must be a list")
        names = [r["name"] for r in v["results"]]
        sorted(names) == sorted(v["required"]) or fail("checks results must cover every required check exactly once (R12)")
        len(set(names)) == len(names) or fail("duplicate check result (R12)")
        all(ids["check-state"].match(r["state"]) for r in v["results"]) or fail("check state outside vocabulary (R12)")
    if c == "next_action":
        ids["action"].match(v["action"]) or fail("action outside vocabulary")
        set(v["because"]) <= set(f.get("inputs", [])) or fail("because must be a subset of inputs")
        v["boundary"] == "none" or ids["boundary"].match(v["boundary"]) or fail("next_action.boundary outside the closed boundary vocabulary")
        if v["boundary"] != "none" and v["action"] != "stop-decision-required": fail("only stop-decision-required rests on a reserved boundary (R15)")

REQUIRED = {c for c, req in classes.items() if req == "required"}
def check_set(facts, complete):
    """Snapshot-level rules (R11): a complete snapshot has every required class exactly once; a fragment
    never repeats a class. Both: every fact validates; next_action.because ⊆ keys present."""
    seen = [f["class"] for f in facts]
    if len(set(seen)) != len(seen): fail("a class appears twice in one set")
    if complete:
        missing = REQUIRED - set(seen)
        if missing: fail(f"complete snapshot lacks required classes: {sorted(missing)}")
    keys = {f["key"]: f for f in facts}
    for f in facts:
        for i in f.get("inputs", []) or []:
            if i not in keys: fail(f"derived input {i} is not present in the same set")
    # R15: next_action is derived from the inputs present, never asserted; every fact the derivation
    # consults must be among its inputs (R4), so the conclusion re-versions when any of them changes
    def one(cls):
        c = [f for f in facts if f["class"] == cls]
        return c[0] if c else None
    for f in facts:
        if f["class"] != "next_action" or f["status"] != "ESTABLISHED": continue
        act = f["value"]["action"]; used = set()
        def get(cls):
            x = one(cls)
            if x is not None: used.add(x["key"])
            return x
        est = lambda x: x is not None and x["status"] == "ESTABLISHED"
        head = get("head"); cur = head["value"]["head"] if est(head) else None
        if act == "merge":
            rev, chk, acc, auth, repo, wu = get("review"), get("checks"), get("acceptance"), get("authority"), get("repository"), get("work_unit")
            if not (est(rev) and rev["value"]["verdict"] == "PASS" and cur and rev["value"]["head"] == cur): fail("merge requires a PASS review on the current HEAD (R15)")
            if not (est(chk) and chk["value"]["head"] == cur and all(r["state"] == "success" for r in chk["value"]["results"])): fail("merge requires every required check success on the current HEAD (R15)")
            if not (est(acc) and acc["value"]["head"] == cur and all(i["state"] == "MET" for i in acc["value"]["items"])): fail("merge requires every acceptance item MET on the current HEAD (R15)")
            if not head["value"]["current"]: fail("merge requires the HEAD to be current (R15)")
            targets = {x["value"]["id"] for x in (repo, wu) if est(x)}
            if not (est(auth) and any("merge:routine" in g["scopes"] and g["target"] in targets for g in auth["value"]["grants"])): fail("merge requires a merge:routine grant targeting the repository or work unit (R15)")
        elif act == "repair":
            rev = get("review")
            if not (est(rev) and rev["value"]["verdict"] == "CHANGES REQUIRED" and cur and rev["value"]["head"] == cur): fail("repair requires CHANGES REQUIRED on the current HEAD (R15)")
        elif act == "wait-review":
            rev, chk = get("review"), get("checks")
            no_verdict = not est(rev) or (cur is not None and rev["value"]["head"] != cur)
            pending = (chk is not None and chk["status"] == "UNKNOWN") or (est(chk) and any(r["state"] in ("pending", "missing") for r in chk["value"]["results"]))
            if not (no_verdict or pending): fail("wait-review requires no verdict on the current HEAD or a pending/missing/UNKNOWN required check (R15)")
        elif act == "stop-decision-required":
            rev = get("review")
            conflict = any(keys[k]["status"] == "CONFLICT" for k in f["inputs"])
            decision = est(rev) and rev["value"]["verdict"] == "DECISION REQUIRED"
            b = f["value"]["boundary"]; by_boundary = False
            if b != "none":
                # the boundary must be reserved for THIS repository or work unit, and its evidence must hold here
                auth, repo, wu = get("authority"), get("repository"), get("work_unit")
                targets = {x["value"]["id"] for x in (repo, wu) if est(x)}
                if not targets: fail("a stop on a reserved boundary needs the repository or work unit it targets (R15)")
                if not (est(auth) and auth["key"] in f["value"]["because"] and any(hb["boundary"] == b and hb["target"] in targets for hb in auth["value"]["human_boundaries"])):
                    fail(f"boundary {b} is not reserved for this repository or work unit by the authority fact named in because (R15)")
                if b not in evidence: fail(f"boundary {b} has no boundary-evidence record: no derivation in this version (R15)")
                ekey, field, cond = evidence[b]
                ev = get(ekey.split(".")[0])
                if not (est(ev) and ev["key"] == ekey and ev["key"] in f["value"]["because"]): fail(f"boundary {b} needs its evidence fact {ekey} ESTABLISHED and in because (R15)")
                if cond == "not-none" and ev["value"][field] == "none": fail(f"boundary {b} does not apply: {ekey}.{field} is none (R15)")
                by_boundary = True
            if not (conflict or decision or by_boundary): fail("stop-decision-required requires a CONFLICT input, a DECISION REQUIRED verdict, or an applicable reserved boundary (R15)")
        else:
            fail(f"action {act} has no derivation rule in this version (R15)")
        missing = used - set(f["inputs"])
        if missing: fail(f"next_action consulted {sorted(missing)} but does not list them as inputs (R4/R15)")
        if f["source"]["type"] == "derived":
            for part in f["source"]["version"].split(";")[1:]:
                k, ver = part.split("@", 1)
                if keys[k]["source"]["version"] != ver: fail(f"derived-version records {k}@{ver} but the input's source.version is {keys[k]['source']['version']} (R4)")

def examples_from_doc(text):
    """(kind, facts) per example, kind read from the heading marker: complete snapshot | fragment."""
    out = []
    for m in re.finditer(r"^### Example \d+ — [^\n]*\((complete snapshot|fragment)\)\n(.*?)```json\n(.*?)\n```", text, flags=re.S | re.M):
        out.append((m.group(1), json.loads(m.group(3))))
    return out

mode = sys.argv[3] if len(sys.argv) > 3 else "doc"
if mode == "doc":
    exs = examples_from_doc(open(doc).read())
    n = 0
    for kind, facts in exs:
        for f in facts: check_fact(f); n += 1
        check_set(facts, kind == "complete snapshot")
    kinds = {"UNKNOWN": 0, "CONFLICT": 0}
    for _, facts in exs:
        for f in facts:
            if f["status"] in kinds: kinds[f["status"]] += 1
    print(f"snapshots={len(exs)} complete={sum(1 for k,_ in exs if k=='complete snapshot')} facts={n} unknown={kinds['UNKNOWN']} conflict={kinds['CONFLICT']}")
elif mode == "set":
    # snapshot-level control: stdin = {"complete": bool, "facts": [...]}
    d = json.load(sys.stdin)
    try:
        for f in d["facts"]: check_fact(f)
        check_set(d["facts"], d["complete"]); print("accepted")
    except (ValueError, KeyError, TypeError) as e: print(f"rejected: {e}"); sys.exit(1)
else:
    # mutation control: read one fact JSON from stdin; exit 0 if it validates, 1 if rejected
    try: check_fact(json.load(sys.stdin)); print("accepted")
    except (ValueError, KeyError, TypeError) as e: print(f"rejected: {e}"); sys.exit(1)
PY
if out="$(python3 "$VAL" "$TSV" "$DOC" doc 2>&1)"; then ok; else bad "every example on the page validates: $out"; fi
case "$out" in *"snapshots=7 complete=1 "*) ok ;; *) bad "seven examples parsed, one complete snapshot: $out" ;; esac
case "$out" in *"unknown=1 conflict=1"*) ok ;; *) bad "examples include exactly one UNKNOWN and one CONFLICT fact: $out" ;; esac

# ======================== mutation controls: the validator discriminates ========================
base='{"schema_version":"1","key":"review.independent","class":"review","status":"ESTABLISHED","value":{"verdict":"PASS","head":"0123456789abcdef0123456789abcdef01234567","reviewer":"login:github-actions[bot]","record":"github.com/acme/widgets#42/comment/9100"},"source":{"type":"github-api","identity":"github.com/acme/widgets#42/comment/9100","version":"2026-09-06T11:58:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567"],"provenance":"https://github.com/acme/widgets/pull/42#issuecomment-9100"}'
accepts() { printf '%s' "$1" | python3 "$VAL" "$TSV" "$DOC" one >/dev/null 2>&1; }
accepts "$base" && ok || bad "control: the canonical review fact is accepted"
mut() { printf '%s' "$base" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$(mut 'f["status"]="UNKNOWN"; f["detail"]={"reason":"x","candidates":[]}')" && bad "UNKNOWN with a value must be rejected (R6)" || ok
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]')" && bad "UNKNOWN without detail must be rejected" || ok
accepts "$(mut 'f["value"]["record"]="#42"')" && bad "a bare #42 must not pass as an identity (R1)" || ok
accepts "$(mut 'f["key"]="review.cached"')" && bad "a key other than the class's canonical key must be rejected (R1)" || ok
accepts "$(mut 'f["key"]="review.foo"')" && bad "an arbitrary <class>.<name> key must be rejected (R1)" || ok
accepts "$(mut 'f["inferred"]=False')" && bad "inferred: false must be rejected (only the literal true is a representation)" || ok
accepts "$(mut 'f["inferred"]="true"')" && bad "inferred: \"true\" (a string) must be rejected" || ok
accepts "$(mut 'f["inferred"]=True')" && ok || bad "control: inferred: true on a non-authority fact is accepted"
accepts "$(mut 'f["value"]["head"]="0123456"')" && bad "an abbreviated commit must be rejected (R1)" || ok
accepts "$(mut 'f["invalidators"]=["comment:github.com/acme/widgets#42/comment/9100"]')" && bad "a HEAD-bound fact without a head: invalidator must be rejected (R7)" || ok
accepts "$(mut 'f["value"]["verdict"]="APPROVED"')" && bad "a verdict outside the closed vocabulary must be rejected" || ok
accepts "$(mut 'f["schema_version"]="2"')" && bad "an unknown schema_version must be rejected (R9)" || ok
accepts "$(mut 'f["body"]="the whole comment text"')" && bad "a raw prose field must be rejected (R2)" || ok
accepts "$(mut 'f["status"]="CONFLICT"; del f["value"]; f["detail"]={"reason":"x","candidates":["github.com/acme/widgets#42/comment/9100"]}')" && bad "a CONFLICT naming one candidate must be rejected (R8)" || ok
accepts "$(mut 'f["value"]=None')" && bad "value: null must not stand in for absence (R6)" || ok
derived='{"schema_version":"1","key":"next_action.governed","class":"next_action","status":"ESTABLISHED","value":{"action":"merge","because":["review.independent"],"boundary":"none"},"source":{"type":"derived","identity":"fact-model/1","version":"1;review.independent@2026-09-06T11:58:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567"],"provenance":"preferences/fact-model.tsv","inputs":["review.independent"]}'
accepts "$derived" && ok || bad "control: a derived fact with inputs is accepted"
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); del f["inputs"]; print(json.dumps(f))')" && bad "a derived fact without inputs must be rejected (R4)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["identity"]="fact-model"; print(json.dumps(f))')" && bad "a derived source identity outside its grammar must be rejected (R14)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["version"]="1"; print(json.dumps(f))')" && bad "a derived version that omits its inputs' versions must be rejected (R4)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["version"]="1;checks.required@x"; print(json.dumps(f))')" && bad "a derived version naming a key that is not an input must be rejected (R4)" || ok
accepts "$(mut 'f["invalidators"]=["head:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"]')" && bad "a review whose head: invalidator names a different HEAD than its value must be rejected (R7)" || ok
accepts "$(mut 'f["source"]["version"]="latest"')" && bad "a github-api source version outside its grammar must be rejected (R14)" || ok
# exact value shapes, recursively (R14): prose keys nested inside values
accepts "$(mut 'f["value"]["conclusion"]="looks fine"')" && bad "an extra key in a review value must be rejected (R14)" || ok
wu='{"schema_version":"1","key":"work_unit.identity","class":"work_unit","status":"ESTABLISHED","value":{"kind":"pull_request","id":"github.com/acme/widgets#42"},"source":{"type":"github-api","identity":"github.com/acme/widgets#42","version":"2026-09-06T12:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["pull_request:github.com/acme/widgets#42"],"provenance":"https://github.com/acme/widgets/pull/42"}'
accepts "$wu" && ok || bad "control: a canonical work_unit fact is accepted"
accepts "$(printf '%s' "$wu" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["body"]="the PR description"; print(json.dumps(f))')" && bad "work_unit.value.body must be rejected (R2/R14)" || ok
acc='{"schema_version":"1","key":"acceptance.contract","class":"acceptance","status":"ESTABLISHED","value":{"contract":"github.com/acme/widgets#41","head":"0123456789abcdef0123456789abcdef01234567","items":[{"id":"a1","state":"MET"}]},"source":{"type":"github-api","identity":"github.com/acme/widgets#41","version":"2026-09-05T18:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["issue:github.com/acme/widgets#41","head:0123456789abcdef0123456789abcdef01234567"],"provenance":"https://github.com/acme/widgets/issues/41"}'
accepts "$acc" && ok || bad "control: a canonical acceptance fact is accepted"
accepts "$(printf '%s' "$acc" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["items"][0]["summary"]="done, I think"; print(json.dumps(f))')" && bad "acceptance.items[].summary must be rejected (R2/R14)" || ok
accepts "$(printf '%s' "$acc" | python3 -c 'import json,sys; f=json.load(sys.stdin); del f["value"]["head"]; print(json.dumps(f))')" && bad "an acceptance fact without an explicit HEAD must be rejected (R7)" || ok
auth='{"schema_version":"1","key":"authority.standing","class":"authority","status":"ESTABLISHED","value":{"grants":[{"decision":"github.com/acme/widgets#7/comment/9001","target":"github.com/acme/widgets","scopes":["merge:routine"]}],"human_boundaries":[{"decision":"github.com/acme/widgets#7/comment/9001","target":"github.com/acme/widgets","boundary":"release:approve"}]},"source":{"type":"human-decision","identity":"github.com/acme/widgets#7/comment/9001","version":"9001"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["comment:github.com/acme/widgets#7/comment/9001"],"provenance":"https://github.com/acme/widgets/issues/7"}'
accepts "$auth" && ok || bad "control: a canonical authority fact is accepted"
amut() { printf '%s' "$auth" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$(amut 'f["source"]["type"]="github-api"')" && bad "authority from a non-human-decision source must be rejected (R5)" || ok
accepts "$(amut 'f["inferred"]=True')" && bad "an inferred authority fact must be rejected (R5)" || ok
accepts "$(amut 'f["inferred"]=False')" && bad "inferred: false on authority must be rejected (never a representation)" || ok
accepts "$(amut 'f["source"]["identity"]="role:owner"')" && bad "a human-decision source whose identity is a role must be rejected (R5/R14)" || ok
accepts "$(amut 'f["source"]["version"]="banana"')" && bad "a human-decision source version outside its grammar must be rejected (R14)" || ok
accepts "$(amut 'f["source"]["identity"]="the maintainer approved this in chat"')" && bad "a human-decision source whose identity is a summary must be rejected (R5/R14)" || ok
accepts "$(amut 'del f["value"]["grants"][0]["target"]')" && bad "a grant without an applicability target must be rejected (R14)" || ok
accepts "$(amut 'f["value"]["grants"][0]["target"]="this repository and its forks"')" && bad "a prose grant target must be rejected (R14)" || ok
accepts "$(amut 'f["value"]["grants"][0]["decision"]="approved by the owner"')" && bad "a grant whose decision is not a durable record must be rejected (R5)" || ok
accepts "$(amut 'f["value"]["grants"][0]["scopes"]=["routine merge of a green PR"]')" && bad "a prose scope must be rejected (R13)" || ok
accepts "$(amut 'f["value"]["human_boundaries"][0]["boundary"]="release approval"')" && bad "a prose boundary must be rejected (R13)" || ok
accepts "$(amut 'f["value"]["human_boundaries"]=["release:approve"]')" && bad "a bare-token boundary without decision and target must be rejected (R13/R14)" || ok
accepts "$(amut 'f["value"]["human_boundaries"][0]["target"]="everywhere"')" && bad "a prose boundary target must be rejected (R14)" || ok
accepts "$(amut 'f["value"]["grants"][0]["scopes"]=[]')" && bad "a grant with no scopes must be rejected (R13)" || ok
chk='{"schema_version":"1","key":"checks.required","class":"checks","status":"ESTABLISHED","value":{"head":"0123456789abcdef0123456789abcdef01234567","required":["doctor","tests"],"results":[{"name":"doctor","state":"success"},{"name":"tests","state":"success"}]},"source":{"type":"github-api","identity":"github.com/acme/widgets","version":"0123456789abcdef0123456789abcdef01234567"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567"],"provenance":"https://github.com/acme/widgets/commit/0123456789abcdef0123456789abcdef01234567/checks"}'
cmut() { printf '%s' "$chk" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$chk" && ok || bad "control: a covered checks fact is accepted"
accepts "$(cmut 'f["value"]["results"]=f["value"]["results"][:1]')" && bad "a required check with no result must be rejected (R12)" || ok
accepts "$(cmut 'f["value"]["results"][1]["state"]="green"')" && bad "a check state outside the vocabulary must be rejected (R12)" || ok
accepts "$(cmut 'f["value"]["results"][1]["conclusion"]="success"')" && bad "checks.results[].conclusion (an undeclared nested key) must be rejected (R14)" || ok
accepts "$(cmut 'f["value"]["results"].append({"name":"tests","state":"failure"})')" && bad "a duplicate check result must be rejected (R12)" || ok
gr='{"schema_version":"1","key":"graph.native","class":"graph","status":"ESTABLISHED","value":{"parent":{"id":"github.com/acme/widgets#40","state":"open"},"children":[],"blocked_by":[{"id":"github.com/acme/widgets#39","state":"closed"}]},"source":{"type":"github-api","identity":"github.com/acme/widgets#41","version":"2026-09-06T11:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["issue:github.com/acme/widgets#41"],"provenance":"https://github.com/acme/widgets/issues/41"}'
gmut() { printf '%s' "$gr" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$gr" && ok || bad "control: a graph fact with relationship states is accepted"
accepts "$(gmut 'f["value"]["blocked_by"]=["github.com/acme/widgets#39"]')" && bad "a relationship without state must be rejected" || ok
accepts "$(gmut 'f["value"]["parent"]["state"]="done"')" && bad "a relationship state outside the vocabulary must be rejected" || ok
# snapshot-level controls (R11): the page's complete snapshot minus one required class must be rejected as a snapshot
sets() { printf '%s' "$1" | python3 "$VAL" "$TSV" "$DOC" set >/dev/null 2>&1; }
full="$(python3 - "$DOC" <<'PY'
import json, re, sys
t = open(sys.argv[1]).read()
m = re.search(r"^### Example 1 — [^\n]*\(complete snapshot\)\n.*?```json\n(.*?)\n```", t, flags=re.S | re.M)
print(json.dumps(json.loads(m.group(1))))
PY
)"
sets "$(printf '{"complete": true, "facts": %s}' "$full")" && ok || bad "control: the page's complete snapshot is accepted as a snapshot"
# R15 controls: the complete snapshot derives merge; break one condition at a time and the derivation must be rejected
smut() { printf '%s' "$full" | python3 -c "import json,sys; s=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(s))" "$1"; }
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="checks"][0]; nx["value"]["results"][1]["state"]="failure"')")" && bad "merge with a failed required check must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="review"][0]; nx["value"]["verdict"]="CHANGES REQUIRED"')")" && bad "merge with a CHANGES REQUIRED review must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="acceptance"][0]; nx["value"]["items"][0]["state"]="NOT_MET"')")" && bad "merge with an unmet acceptance item must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="head"][0]; nx["value"]["current"]=False')")" && bad "merge on a HEAD that is not current must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="authority"][0]; nx["value"]["grants"][0]["scopes"]=["close:issue"]')")" && bad "merge without a merge:routine grant must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="authority"][0]; nx["value"]["grants"][0]["target"]="github.com/acme/program"')")" && bad "merge with a grant targeting another repository must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="next_action"][0]; nx["inputs"]=[i for i in nx["inputs"] if i!="repository.identity"]; nx["source"]["version"]=";".join(p for p in nx["source"]["version"].split(";") if not p.startswith("repository.identity@"))')")" && bad "a merge derivation that omits a consulted fact (repository) from its inputs must be rejected (R4/R15)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["action"]="close"; print(json.dumps(f))')" && bad "an action outside the v1 vocabulary (close) must be rejected" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); del f["value"]["boundary"]; print(json.dumps(f))')" && bad "a next_action without the boundary field must be rejected (R14)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["boundary"]="placement:release"; print(json.dumps(f))')" && bad "a merge resting on a reserved boundary must be rejected (R15)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["boundary"]="release placement"; print(json.dumps(f))')" && bad "a prose boundary on next_action must be rejected (R13)" || ok
# reserved-boundary controls (R15): the page's Example 6 stops on placement:release; each applicability condition broken in turn must be rejected
ex6="$(python3 - "$DOC" <<'PY'
import json, re, sys
t = open(sys.argv[1]).read()
m = re.search(r"^### Example 6 — [^\n]*\(fragment\)\n.*?```json\n(.*?)\n```", t, flags=re.S | re.M)
print(json.dumps(json.loads(m.group(1))))
PY
)"
xmut() { printf '%s' "$ex6" | python3 -c "import json,sys; s=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(s))" "$1"; }
sets "$(printf '{"complete": false, "facts": %s}' "$ex6")" && ok || bad "control: the page's reserved-boundary fragment is accepted"
sets "$(printf '{"complete": false, "facts": %s}' "$(xmut 'a=[f for f in s if f["class"]=="authority"][0]; [b.__setitem__("target","github.com/acme/program") for b in a["value"]["human_boundaries"]]')")" && bad "a boundary reserved for another repository must not stop this work unit (R15)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(xmut 'p=[f for f in s if f["class"]=="placement"][0]; p["value"]["release"]="none"')")" && bad "placement:release must not apply when the work unit is in no release (R15)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(xmut 'n=[f for f in s if f["class"]=="next_action"][0]; n["value"]["boundary"]="settings:repository"')")" && bad "a boundary with no evidence record has no derivation in v1 and must be rejected (R15)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(xmut 'n=[f for f in s if f["class"]=="next_action"][0]; n["value"]["boundary"]="none"')")" && bad "a stop with no boundary, no CONFLICT and no DECISION REQUIRED must be rejected (R15)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(xmut 'n=[f for f in s if f["class"]=="next_action"][0]; a=[f for f in s if f["class"]=="authority"][0]; a["value"]["human_boundaries"]=[b for b in a["value"]["human_boundaries"] if b["boundary"]!="placement:release"]')")" && bad "a boundary the authority fact does not reserve must be rejected (R15)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(xmut 's[:]=[f for f in s if f["class"] not in ("repository","work_unit")]; n=[f for f in s if f["class"]=="next_action"][0]; n["inputs"]=[i for i in n["inputs"] if i not in ("repository.identity","work_unit.identity")]; n["value"]["because"]=[i for i in n["value"]["because"] if i not in ("repository.identity","work_unit.identity")]; n["source"]["version"]=";".join(p for p in n["source"]["version"].split(";") if not (p.startswith("repository.identity@") or p.startswith("work_unit.identity@")))')")" && bad "a boundary stop without the repository or work unit it targets must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(printf '%s' "$full" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps([f for f in s if f["class"]!="authority"]))')")" && bad "a snapshot lacking a required class must be rejected (R11)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(printf '%s' "$full" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps(s+[s[0]]))')")" && bad "a set repeating a class must be rejected (R11)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(printf '%s' "$full" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps([f for f in s if f["class"] not in ("authority","next_action")]))')")" && ok || bad "control: a subset with no dangling derived inputs is a valid fragment when not claimed complete"
sets "$(printf '{"complete": false, "facts": %s}' "$(printf '%s' "$full" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps([f for f in s if f["class"]!="authority"]))')")" && bad "a fragment whose derived fact names an absent input must be rejected (R4)" || ok

finish "fact model (#731)"
