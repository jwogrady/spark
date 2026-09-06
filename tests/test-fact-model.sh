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
assert_eq "four status tokens" "4" "$(rec status | wc -l | tr -d ' ')"
assert_eq "ESTABLISHED is the only status that may carry a value" "ESTABLISHED" "$(rec status | awk -F'\t' '$3=="yes"{print $2}')"
assert_eq "twelve envelope fields" "12" "$(rec field | wc -l | tr -d ' ')"
assert_eq "value is optional in the envelope (present only when ESTABLISHED)" "optional" "$(rec field | awk -F'\t' '$2=="value"{print $3}')"
assert_eq "five source types" "5" "$(rec source | wc -l | tr -d ' ')"
assert_eq "ten rules" "10" "$(rec rule | wc -l | tr -d ' ')"
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
for k in $(rec identifier | cut -f2); do grep -q "^| $k |" "$DOC" && ok || bad "doc identifier table names $k"; done
for r in $(rec rule | cut -f2); do grep -q "^- \*\*$r\*\*" "$DOC" && ok || bad "doc states rule $r"; done
grep -q 'preferences/fact-model.tsv' "$DOC" && ok || bad "doc names its machine-readable authority"
grep -qE '^| `next_action` \| derived' "$DOC" && ok || bad "doc marks next_action as derived"
assert_eq "seven examples on the page" "7" "$(grep -c '^### Example [1-7] — ' "$DOC")"
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
    if f["status"] not in statuses: fail(f"unknown status {f['status']}")
    if "value" in f and f["value"] is None: fail("value: null is not a representation of absence; omit the field")
    if statuses[f["status"]] == "no" and "value" in f: fail(f"{f['status']} fact carries a value")
    if f["status"] == "ESTABLISHED" and "value" not in f: fail("ESTABLISHED fact without value")
    if f["status"] in ("UNKNOWN", "CONFLICT") and "detail" not in f: fail(f"{f['status']} without detail")
    src = f["source"]
    if set(src) != {"type", "identity", "version"}: fail("source must be {type, identity, version}")
    if src["type"] not in sources: fail(f"unknown source type {src['type']}")
    if not src["version"]: fail("source.version empty")
    if src["type"] == "derived" and not f.get("inputs"): fail("derived fact without inputs")
    if f.get("inputs") is not None and any(not ids["fact-key"].match(i) for i in f["inputs"]): fail("inputs must be fact keys")
    if not ISO.match(f["observed_at"]): fail("observed_at not ISO-8601 Z")
    if not isinstance(f["invalidators"], list) or not f["invalidators"]: fail("invalidators must be a non-empty list")
    if not f["provenance"]: fail("provenance empty")
    if f["class"] in HEAD_BOUND and not any(i.startswith("head:") for i in f["invalidators"]): fail(f"HEAD-bound class {f['class']} without a head: invalidator")
    if f["status"] == "CONFLICT" and len(f["detail"].get("candidates", [])) < 2: fail("CONFLICT must name at least two candidates")
    v = f.get("value")
    if v is None: return
    c = f["class"]
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
        v["parent"] == "none" or wu(v["parent"])
        for x in v["children"] + v["blocked_by"]: wu(x)
    if c == "authority":
        for g in v["grants"]:
            ids["comment"].match(g["decision"]) or ids["work-unit"].match(g["decision"]) or fail("grant decision not a canonical record")
        if f["source"]["type"] != "human-decision": fail("authority must come from a human-decision source")
        if f.get("inferred"): fail("authority can never be inferred")
    if c == "acceptance":
        wu(v["contract"])
        for it in v["items"]: it["state"] in ("MET", "NOT_MET", "UNKNOWN") or fail("bad acceptance state")
    if c == "head": sha(v["head"]); sha(v["base"]); ids["ref"].match(v["base_ref"]) or fail("bad base_ref"); isinstance(v["current"], bool) or fail("current must be boolean")
    if c == "review": ids["verdict"].match(v["verdict"]) or fail("verdict outside vocabulary"); sha(v["head"]); ids["login"].match(v["reviewer"]) or fail("reviewer not login:"); ids["comment"].match(v["record"]) or fail("record not a comment id")
    if c == "checks": sha(v["head"]); isinstance(v["required"], list) or fail("required must be a list")
    if c == "next_action":
        ids["action"].match(v["action"]) or fail("action outside vocabulary")
        set(v["because"]) <= set(f.get("inputs", [])) or fail("because must be a subset of inputs")

def snapshots_from_doc(text):
    blocks = re.findall(r"```json\n(.*?)\n```", text, flags=re.S)
    return [json.loads(b) for b in blocks]

mode = sys.argv[3] if len(sys.argv) > 3 else "doc"
if mode == "doc":
    snaps = snapshots_from_doc(open(doc).read())
    n = 0
    for s in snaps:
        for f in s: check_fact(f); n += 1
    kinds = {"UNKNOWN": 0, "CONFLICT": 0}
    for s in snaps:
        for f in s:
            if f["status"] in kinds: kinds[f["status"]] += 1
    print(f"snapshots={len(snaps)} facts={n} unknown={kinds['UNKNOWN']} conflict={kinds['CONFLICT']}")
else:
    # mutation control: read one fact JSON from stdin; exit 0 if it validates, 1 if rejected
    try: check_fact(json.load(sys.stdin)); print("accepted")
    except (ValueError, KeyError, TypeError) as e: print(f"rejected: {e}"); sys.exit(1)
PY
if out="$(python3 "$VAL" "$TSV" "$DOC" doc 2>&1)"; then ok; else bad "every example on the page validates: $out"; fi
case "$out" in *"snapshots=7 "*) ok ;; *) bad "seven snapshots parsed: $out" ;; esac
case "$out" in *"unknown=1 conflict=1"*) ok ;; *) bad "examples include exactly one UNKNOWN and one CONFLICT fact: $out" ;; esac

# ======================== mutation controls: the validator discriminates ========================
base='{"schema_version":"1","key":"review.independent","class":"review","status":"ESTABLISHED","value":{"verdict":"PASS","head":"0123456789abcdef0123456789abcdef01234567","reviewer":"login:github-actions[bot]","record":"github.com/acme/widgets#42/comment/9100"},"source":{"type":"github-api","identity":"github.com/acme/widgets#42/comment/9100","version":"2026-09-06T11:58:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567"],"provenance":"https://github.com/acme/widgets/pull/42#issuecomment-9100"}'
accepts() { printf '%s' "$1" | python3 "$VAL" "$TSV" "$DOC" one >/dev/null 2>&1; }
accepts "$base" && ok || bad "control: the canonical review fact is accepted"
mut() { printf '%s' "$base" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$(mut 'f["status"]="UNKNOWN"; f["detail"]={"reason":"x","candidates":[]}')" && bad "UNKNOWN with a value must be rejected (R6)" || ok
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]')" && bad "UNKNOWN without detail must be rejected" || ok
accepts "$(mut 'f["value"]["record"]="#42"')" && bad "a bare #42 must not pass as an identity (R1)" || ok
accepts "$(mut 'f["value"]["head"]="0123456"')" && bad "an abbreviated commit must be rejected (R1)" || ok
accepts "$(mut 'f["invalidators"]=["comment:github.com/acme/widgets#42/comment/9100"]')" && bad "a HEAD-bound fact without a head: invalidator must be rejected (R7)" || ok
accepts "$(mut 'f["value"]["verdict"]="APPROVED"')" && bad "a verdict outside the closed vocabulary must be rejected" || ok
accepts "$(mut 'f["schema_version"]="2"')" && bad "an unknown schema_version must be rejected (R9)" || ok
accepts "$(mut 'f["body"]="the whole comment text"')" && bad "a raw prose field must be rejected (R2)" || ok
accepts "$(mut 'f["status"]="CONFLICT"; del f["value"]; f["detail"]={"reason":"x","candidates":["github.com/acme/widgets#42/comment/9100"]}')" && bad "a CONFLICT naming one candidate must be rejected (R8)" || ok
accepts "$(mut 'f["value"]=None')" && bad "value: null must not stand in for absence (R6)" || ok
derived='{"schema_version":"1","key":"next_action.governed","class":"next_action","status":"ESTABLISHED","value":{"action":"merge","because":["review.independent"]},"source":{"type":"derived","identity":"fact-model","version":"1"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567"],"provenance":"preferences/fact-model.tsv","inputs":["review.independent"]}'
accepts "$derived" && ok || bad "control: a derived fact with inputs is accepted"
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); del f["inputs"]; print(json.dumps(f))')" && bad "a derived fact without inputs must be rejected (R4)" || ok
auth='{"schema_version":"1","key":"authority.standing","class":"authority","status":"ESTABLISHED","value":{"grants":[{"decision":"github.com/acme/widgets#7/comment/9001","scope":"routine merge"}],"human_boundaries":["release approval"]},"source":{"type":"github-api","identity":"github.com/acme/widgets#7","version":"x"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["comment:github.com/acme/widgets#7/comment/9001"],"provenance":"https://github.com/acme/widgets/issues/7"}'
accepts "$auth" && bad "authority from a non-human-decision source must be rejected (R5)" || ok

finish "fact model (#731)"
