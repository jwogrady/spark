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
assert_eq "eight invalidator grammars" "8" "$(rec invalidator | wc -l | tr -d ' ')"
assert_eq "two envelope object shapes (source, detail)" "detail source" "$(rec shape | cut -f2 | sort | tr '\n' ' ' | sed 's/ $//')"
while IFS=$'\t' read -r _ kind rx _; do
  if printf 'probe' | grep -qE "$rx" >/dev/null 2>&1; then rc=0; else rc=$?; fi
  [ "$rc" -le 1 ] && ok || bad "invalidator regex for $kind compiles"
done <<EOF
$(rec invalidator)
EOF
assert_eq "one derivable reserved boundary in v1" "1" "$(rec boundary-evidence | wc -l | tr -d ' ')"
for b in $(rec boundary-evidence | cut -f2); do printf '%s' "$b" | grep -qE "$(rec identifier | awk -F'\t' '$2=="boundary"{print $3}')" && ok || bad "boundary-evidence $b is in the closed boundary vocabulary"; done
for k in $(rec boundary-evidence | cut -f3); do rec key | cut -f3 | grep -qx "$k" && ok || bad "boundary-evidence names canonical key $k"; done
assert_eq "four status tokens" "4" "$(rec status | wc -l | tr -d ' ')"
assert_eq "ESTABLISHED is the only status that may carry a value" "ESTABLISHED" "$(rec status | awk -F'\t' '$3=="yes"{print $2}')"
assert_eq "twelve envelope fields" "12" "$(rec field | wc -l | tr -d ' ')"
assert_eq "value is optional in the envelope (present only when ESTABLISHED)" "optional" "$(rec field | awk -F'\t' '$2=="value"{print $3}')"
assert_eq "five source types" "5" "$(rec source | wc -l | tr -d ' ')"
assert_eq "seventeen rules" "17" "$(rec rule | wc -l | tr -d ' ')"
assert_eq "one source-version grammar per source type" "$(rec source | cut -f2 | sort | tr '\n' ' ')" "$(rec source-version | cut -f2 | sort | tr '\n' ' ')"
assert_eq "nineteen identifier kinds" "19" "$(rec identifier | wc -l | tr -d ' ')"
for k in issue-state check-state scope boundary decision-record derived-version; do rec identifier | cut -f2 | grep -qx "$k" && ok || bad "closed vocabulary $k declared"; done
assert_eq "one source-identity grammar per source type" "$(rec source | cut -f2 | sort | tr '\n' ' ')" "$(rec source-identity | cut -f2 | sort | tr '\n' ' ')"
while IFS=$'\t' read -r _ kind rx _; do
  if printf 'probe' | grep -qE "$rx" >/dev/null 2>&1; then rc=0; else rc=$?; fi
  [ "$rc" -le 1 ] && ok || bad "source-identity regex for $kind compiles"
done <<EOF
$(rec source-identity)
EOF
# the validator is Python: every grammar the TSV declares must compile there as well as in grep -E, and a POSIX
# class such as [[:space:]] (which Python reads as a character set) is rejected outright
python3 - "$TSV" <<'PY' | while IFS= read -r line; do case "$line" in OK*) ok ;; *) bad "$line" ;; esac; done
import re, sys
for l in open(sys.argv[1]):
    if l.startswith("#") or not l.strip(): continue
    r = l.rstrip("\n").split("\t")
    if r[0] in ("identifier", "source-identity", "source-version", "invalidator"):
        try:
            re.compile(r[2]); ok = "[[:" not in r[2]
        except re.error: ok = False
        print(("OK " if ok else "BAD ") + f"{r[0]} {r[1]} grammar compiles in Python without POSIX classes")
PY
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
for k in $(rec invalidator | cut -f2); do grep -q "^| \`$k\` | " "$DOC" && ok || bad "doc invalidator table names $k"; done
for k in $(rec shape | cut -f2); do grep -q "^| \`$k\` | \`" "$DOC" && ok || bad "doc shape table names $k"; done
# text parity (python3 present): class shapes and descriptions, field requiredness and descriptions, identifier
# canonical forms, invalidator forms, envelope shapes and every rule statement are the TSV's text, verbatim
if command -v python3 >/dev/null 2>&1; then
  while IFS= read -r line; do
    case "$line" in OK*) ok ;; *) bad "parity: $line" ;; esac
  done <<EOF
$(python3 - "$TSV" "$DOC" <<'PY'
import re, sys
tsv, doc = open(sys.argv[1]).read(), open(sys.argv[2]).read()
rows = [l.split("\t") for l in tsv.split("\n") if l.strip() and not l.startswith("#")]
def norm(x): return re.sub(r"\s+", " ", x.replace("\\|", "|").replace("`", "")).strip()
def cells(line): return [c.strip() for c in line.strip().strip("|").split(" | ")]
def table(header):
    i = doc.index(header); body = doc[doc.index("\n", doc.index("\n", i) + 1) + 1:]
    return [cells(l) for l in body.split("\n\n")[0].split("\n") if l.startswith("|")]
def say(okk, what): print(("OK " if okk else "BAD ") + what)
keyof = {r[1]: r[2] for r in rows if r[0] == "key"}
cls = {norm(c[0]): c for c in table("| Class | Canonical key |")}
for r in (r for r in rows if r[0] == "class"):
    c = cls.get(r[1]); say(c is not None and [norm(x) for x in c[1:]] == [keyof[r[1]], r[2], norm(r[3]), norm(r[4])], f"class {r[1]} row is the TSV's key, requiredness, shape and description")
flds = {norm(c[0]): c for c in table("| Field | Required |")}
for r in (r for r in rows if r[0] == "field"):
    c = flds.get(r[1]); say(c is not None and [norm(x) for x in c[1:]] == [r[2], norm(r[4])], f"field {r[1]} row is the TSV's requiredness and description")
ident = {c[0]: c for c in table("| Kind | Canonical form |")}
for r in (r for r in rows if r[0] == "identifier"):
    c = ident.get(r[1]); say(c is not None and norm(c[1]) == norm(r[3]), f"identifier {r[1]} canonical form is the TSV's")
inv = {norm(c[0]): c for c in table("| Kind | Token form and meaning |")}
for r in (r for r in rows if r[0] == "invalidator"):
    c = inv.get(r[1]); say(c is not None and norm(c[1]) == norm(r[3]), f"invalidator {r[1]} form is the TSV's")
shp = {norm(c[0]): c for c in table("| Object | Shape |")}
for r in (r for r in rows if r[0] == "shape"):
    c = shp.get(r[1]); say(c is not None and norm(c[1]) == norm(r[2]), f"envelope shape {r[1]} is the TSV's")
rules_md = doc[doc.index("## Rules"):doc.index("## Versioning")]
found = {m.group(1): norm(m.group(2)) for m in re.finditer(r"^- \*\*(R\d+)\*\* (.*?)(?=^- \*\*R|\Z)", rules_md, flags=re.S | re.M)}
for r in (r for r in rows if r[0] == "rule"):
    say(found.get(r[1]) == norm(r[2]), f"rule {r[1]} statement is the TSV's, verbatim")
say(len(found) == len([r for r in rows if r[0] == "rule"]), "the page states no rule the TSV lacks")
PY
)
EOF
fi
grep -qE '^| `next_action` \| `next_action.governed` \| derived' "$DOC" && ok || bad "doc marks next_action as derived"
assert_eq "eight examples on the page" "8" "$(grep -c '^### Example [1-8] — ' "$DOC")"
assert_eq "exactly one example is a complete snapshot" "1" "$(grep -c '^### Example [1-8] — .*(complete snapshot)$' "$DOC")"
assert_eq "the other seven are marked as fragments" "7" "$(grep -c '^### Example [1-8] — .*(fragment)$' "$DOC")"
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
ftypes = {r[1]: r[3] for r in rows if r[0] == "field"}          # envelope field types, READ from the authority
PY_TYPES = {"string": str, "list": list, "object": dict, "boolean": bool}
ids = {r[1]: re.compile(r[2]) for r in rows if r[0] == "identifier"}
sources = {r[1] for r in rows if r[0] == "source"}
sid = {r[1]: re.compile(r[2]) for r in rows if r[0] == "source-identity"}
sver = {r[1]: re.compile(r[2]) for r in rows if r[0] == "source-version"}
canon = {r[1]: r[2] for r in rows if r[0] == "key"}                       # class -> its one canonical key (R1)
evidence = {r[1]: (r[2], r[3], r[4]) for r in rows if r[0] == "boundary-evidence"}   # boundary -> (fact key, field, condition)
# Shapes are READ from the authority, never restated here: the class value-shape column and the
# envelope `shape` records share one grammar — {k: shape} exact object, [shape] list, a|b alternatives,
# <kind> an identifier (pseudo-kinds: <text> one non-empty line, <locator> a canonical locator or
# source identity, <source-type> a declared source type), bare word = literal (true/false = booleans).
invalidator_rx = {r[1]: re.compile(r[2]) for r in rows if r[0] == "invalidator"}
def parse_shape(text):
    toks = re.findall(r"\{|\}|\[|\]|:|,|\||<[a-z-]+>|[A-Za-z_][A-Za-z0-9_]*", text)
    if "".join(toks) != re.sub(r"\s+", "", text): raise ValueError(f"shape grammar: unparsed characters in {text!r}")
    pos = [0]
    def peek(): return toks[pos[0]] if pos[0] < len(toks) else None
    def take(t=None):
        tok = peek()
        if tok is None or (t is not None and tok != t): raise ValueError(f"shape grammar: expected {t or 'a token'} at {pos[0]} in {text!r}")
        pos[0] += 1; return tok
    def union():
        alts = [atom()]
        while peek() == "|": take(); alts.append(atom())
        return ("union", alts) if len(alts) > 1 else alts[0]
    def atom():
        t = peek()
        if t == "{":
            take(); fields = {}
            while True:
                k = take(); take(":"); fields[k] = union()
                if peek() == ",": take(); continue
                take("}"); break
            return ("object", fields)
        if t == "[":
            take(); inner = union(); take("]"); return ("list", inner)
        if t is not None and t.startswith("<"): take(); return ("ref", t[1:-1])
        return ("lit", take())
    out = union()
    if pos[0] != len(toks): raise ValueError(f"shape grammar: trailing tokens in {text!r}")
    return out
SHAPES = {r[1]: parse_shape(r[3]) for r in rows if r[0] == "class"}
ENVELOPE = {r[1]: parse_shape(r[2]) for r in rows if r[0] == "shape"}
def describe(sh):
    k = sh[0]
    if k == "object": return "{" + ", ".join(f"{a}: {describe(b)}" for a, b in sh[1].items()) + "}"
    if k == "list": return "[" + describe(sh[1]) + "]"
    if k == "union": return "|".join(describe(a) for a in sh[1])
    if k == "ref": return f"<{sh[1]}>"
    return sh[1]
def matches(sh, v, where):
    k = sh[0]
    if k == "object":
        if not isinstance(v, dict): fail(f"{where} must be an object")
        if set(v) != set(sh[1]): fail(f"{where} keys {sorted(v)} != declared {sorted(sh[1])} (R14)")
        for a, b in sh[1].items(): matches(b, v[a], f"{where}.{a}")
    elif k == "list":
        if not isinstance(v, list): fail(f"{where} must be a list")
        for i, it in enumerate(v): matches(sh[1], it, f"{where}[{i}]")
    elif k == "union":
        for alt in sh[1]:
            try: matches(alt, v, where); return
            except (ValueError, KeyError, TypeError): pass
        fail(f"{where} = {v!r} matches none of {describe(sh)} (R14)")
    elif k == "ref":
        kind = sh[1]
        if kind == "text":
            if not isinstance(v, str) or not v.strip() or "\n" in v: fail(f"{where} must be one non-empty line")
        elif kind == "locator":
            if not isinstance(v, str) or not locator(v): fail(f"{where} = {v!r} is not a canonical locator")
        elif kind == "source-type":
            if v not in sources: fail(f"{where} = {v!r} is not a declared source type")
        else:
            if kind not in ids: fail(f"shape names undeclared identifier kind <{kind}>")
            if not isinstance(v, str) or not ids[kind].fullmatch(v): fail(f"{where} = {v!r} is not a canonical <{kind}> (R1/R14)")
    else:
        lit = sh[1]
        if lit == "true":
            if v is not True: fail(f"{where} must be the literal true")
        elif lit == "false":
            if v is not False: fail(f"{where} must be the literal false")
        elif v != lit: fail(f"{where} = {v!r} is not the literal {lit}")
def shape(c, v): matches(SHAPES[c], v, f"{c}.value")
version = [r[1] for r in rows if r[0] == "version"][0]
LOCATOR_KINDS = ("repository", "work-unit", "comment", "milestone", "commit")
def locator(x):
    return any(ids[k].fullmatch(x) for k in LOCATOR_KINDS) or any(rx.fullmatch(x) for rx in sid.values())
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
        t = ftypes[k]
        if t != "any" and not (isinstance(f[k], PY_TYPES[t]) and not (t != "boolean" and isinstance(f[k], bool))): fail(f"field {k} must be a {t} (R14)")
    if f["schema_version"] != version: fail("schema_version mismatch")
    if not ids["fact-key"].fullmatch(f["key"]): fail(f"key not canonical: {f['key']}")
    if f["class"] not in classes: fail(f"unknown class {f['class']}")
    if f["key"].split(".")[0] != f["class"]: fail("key prefix must equal class")
    if f["key"] != canon[f["class"]]: fail(f"key {f['key']} is not the canonical key {canon[f['class']]} of class {f['class']} (R1)")
    if "inferred" in f and f["inferred"] is not True: fail("inferred must be the literal true when present")
    if f["status"] not in statuses: fail(f"unknown status {f['status']}")
    if "value" in f and f["value"] is None: fail("value: null is not a representation of absence; omit the field")
    if statuses[f["status"]] == "no" and "value" in f: fail(f"{f['status']} fact carries a value")
    if f["status"] == "ESTABLISHED" and "value" not in f: fail("ESTABLISHED fact without value")
    if f["status"] in ("UNKNOWN", "CONFLICT") and "detail" not in f: fail(f"{f['status']} without detail")
    if "detail" in f:
        if f["status"] not in ("UNKNOWN", "CONFLICT"): fail("detail is present only on UNKNOWN or CONFLICT")
        matches(ENVELOPE["detail"], f["detail"], "detail")
    src = f["source"]
    matches(ENVELOPE["source"], src, "source")
    if not sid[src["type"]].fullmatch(str(src["identity"])): fail(f"source.identity {src['identity']!r} is not in the {src['type']} grammar (R14)")
    if not src["version"]: fail("source.version empty")
    if not sver[src["type"]].fullmatch(str(src["version"])): fail(f"source.version {src['version']!r} is not in the {src['type']} version grammar (R14)")
    # a github-api commit version is only ever a HEAD-bound fact keyed by its own HEAD (R14): for any other class
    # an unrelated commit would never change when the node's metadata does
    if src["type"] == "github-api" and re.fullmatch(r"[0-9a-f]{40}", str(src["version"])):
        if f["class"] not in HEAD_BOUND: fail(f"a commit cannot version the mutable {f['class']} node (R14)")
        heads = [i[5:] for i in f["invalidators"] if isinstance(i, str) and i.startswith("head:")]
        if heads != [src["version"]]: fail("a commit version on a HEAD-bound fact must be that fact's own HEAD (R14)")
    # where the identity embeds the observed version, the two must agree (R14)
    if src["type"] in ("git", "repository-file", "human-decision"):
        m = re.search(r"@([0-9a-f]{40})(?::|$)", src["identity"])
        if m and src["version"] != m.group(1): fail(f"source.version {src['version']} must equal the commit its identity names, {m.group(1)} (R14)")
        if "/comment/" in src["identity"] and not ISO.fullmatch(str(src["version"])): fail("a decision recorded in a comment is versioned by the comment's updated_at, never by its id (R14)")
    if src["type"] == "derived":
        if not f.get("inputs"): fail("derived fact without inputs")
        if src["identity"] != f"fact-model/{f['schema_version']}": fail(f"derived identity {src['identity']} must name the fact's own schema version {f['schema_version']} (R14)")
        if not ids["derived-version"].fullmatch(src["version"]): fail("derived source.version is not a derived-version (R4)")
        parts = src["version"].split(";")
        if parts[0] != version: fail("derived-version must start with the schema version")
        vkeys = [p.split("@", 1)[0] for p in parts[1:]]
        if vkeys != sorted(f["inputs"]): fail("derived-version must list exactly the inputs, sorted by key (R4)")
    if f.get("inputs") is not None and any(not ids["fact-key"].fullmatch(i) for i in f["inputs"]): fail("inputs must be fact keys")
    if f.get("inputs") is not None and len(set(f["inputs"])) != len(f["inputs"]): fail("inputs lists a key twice (R17)")
    if not ISO.fullmatch(f["observed_at"]): fail("observed_at not ISO-8601 Z")
    if not isinstance(f["invalidators"], list) or not f["invalidators"]: fail("invalidators must be a non-empty list")
    for tok in f["invalidators"]:
        if not isinstance(tok, str) or not any(rx.fullmatch(tok) for rx in invalidator_rx.values()): fail(f"invalidator {tok!r} is in no invalidator grammar (R16)")
    if len(set(f["invalidators"])) != len(f["invalidators"]): fail("an invalidator appears twice (R16)")
    if not isinstance(f["provenance"], str) or not ids["provenance"].fullmatch(f["provenance"]): fail(f"provenance {f['provenance']!r} is not a pointer in the provenance grammar (R16)")
    if f["class"] in HEAD_BOUND:
        heads = [i for i in f["invalidators"] if i.startswith("head:")]
        if f["status"] == "ESTABLISHED":
            bound = f["value"].get("head") if isinstance(f.get("value"), dict) else None
            if not bound: fail(f"HEAD-bound class {f['class']} must carry its HEAD in the value (R7)")
            if heads != [f"head:{bound}"]: fail(f"HEAD-bound class {f['class']} must list exactly its own HEAD as its one head: invalidator (R7)")
        elif f["status"] in ("UNKNOWN", "CONFLICT"):
            if len(heads) != 1: fail(f"{f['status']} in HEAD-bound class {f['class']} must list exactly one head: invalidator, the HEAD it was observed against (R7)")
        else:
            if heads: fail(f"NOT_APPLICABLE {f['class']} has no HEAD to be stale against and lists no head: invalidator (R7)")
    if f["status"] == "CONFLICT" and len(f["detail"].get("candidates", [])) < 2: fail("CONFLICT must name at least two candidates")
    v = f.get("value")
    if v is None: return
    c = f["class"]
    shape(c, v)
    if c == "acceptance":
        item_ids = [it["id"] for it in v["items"]]
        if len(set(item_ids)) != len(item_ids): fail("acceptance item ids must be unique within the fact (R14)")
    if c == "graph":
        for name in ("children", "blocked_by"):
            got = [x["id"] for x in v[name]]
            if len(set(got)) != len(got): fail(f"graph.{name} names a work unit twice (R14)")
    if c == "authority":
        for g in v["grants"]:
            if not g["scopes"]: fail("grant scopes must be non-empty (R13)")
        if f["source"]["type"] != "human-decision": fail("authority must come from a human-decision source")
        if "inferred" in f: fail("authority can never be inferred")
        for rec in v["grants"] + v["human_boundaries"]:
            if rec["decision"] != f["source"]["identity"]: fail(f"authority record names decision {rec['decision']} but the fact's source is {f['source']['identity']}: one authority fact carries one decision record (R5)")
    if c == "checks":
        names = [r["name"] for r in v["results"]]
        sorted(names) == sorted(v["required"]) or fail("checks results must cover every required check exactly once (R12)")
        len(set(names)) == len(names) or fail("duplicate check result (R12)")
    if c == "next_action":
        set(v["because"]) <= set(f.get("inputs", [])) or fail("because must be a subset of inputs")
        len(set(v["because"])) == len(v["because"]) or fail("because lists a key twice (R17)")
        if v["boundary"] != "none" and v["action"] != "stop-decision-required": fail("only stop-decision-required rests on a reserved boundary (R15)")
    # the source identity is the node the value describes (R17)
    ident = f["source"]["identity"]
    if c == "work_unit":
        if ident != v["id"]: fail(f"work_unit source {ident} is not the work unit it describes, {v['id']} (R17)")
        if v["kind"] == "issue" and v["implements"] != "none": fail("an issue implements nothing; only a pull request closes an issue (R17)")
        if v["implements"] == v["id"]: fail("a work unit cannot implement itself (R17)")
    if c == "repository" and ident != v["id"]: fail(f"repository source {ident} is not the repository it describes, {v['id']} (R17)")
    if c == "review":
        if ident != v["record"]: fail(f"review source {ident} is not the record it reports, {v['record']} (R17)")
        if f"comment:{v['record']}" not in f["invalidators"]: fail("a review lists its record as a comment: invalidator (R17)")
    if c == "acceptance" and f["source"]["type"] == "github-api" and ident != v["contract"]: fail(f"acceptance source {ident} is not the contract it judges, {v['contract']} (R17)")
    if c in ("placement", "graph"):
        if not ids["work-unit"].fullmatch(ident): fail(f"{c} is read from a work-unit node, not {ident} (R17)")
        if not ({f"issue:{ident}", f"pull_request:{ident}"} & set(f["invalidators"])): fail(f"{c} lists the node it was read from ({ident}) as an issue: or pull_request: invalidator (R17)")
    if c == "head" and f["source"]["type"] == "github-api" and not ids["work-unit"].fullmatch(ident): fail(f"head read from GitHub names a work unit, not {ident} (R17)")
    if c == "checks" and not ids["repository"].fullmatch(ident): fail(f"checks name the repository whose rulesets require them, not {ident} (R17)")
    # freshness dependencies the value implies are listed, not optional (R17)
    if c == "graph":
        rel = ([v["parent"]] if v["parent"] != "none" else []) + v["children"] + v["blocked_by"]
        for r in rel:
            if not ({f"issue:{r['id']}", f"pull_request:{r['id']}"} & set(f["invalidators"])): fail(f"graph represents {r['id']} but does not list it as an invalidator (R17)")
    if c == "head":
        repo = ident.split("#")[0].split("@")[0]
        if f"ref:{repo}/{v['base_ref']}" not in f["invalidators"]: fail(f"head carries base_ref {v['base_ref']} but does not list ref:{repo}/{v['base_ref']} as an invalidator (R17)")
    if c == "checks" and f"ruleset:{ident}" not in f["invalidators"]: fail(f"checks do not list ruleset:{ident} — required checks change with the rulesets (R17)")

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
    # within one set, head is read from the work unit's own node and checks from the repository's (R17)
    wu1 = [f for f in facts if f["class"] == "work_unit" and f["status"] == "ESTABLISHED"]
    rp1 = [f for f in facts if f["class"] == "repository" and f["status"] == "ESTABLISHED"]
    for f in facts:
        if f["class"] == "head" and f["source"]["type"] == "github-api" and wu1 and f["source"]["identity"] != wu1[0]["value"]["id"]: fail(f"head is read from {f['source']['identity']} but the work unit is {wu1[0]['value']['id']} (R17)")
        if f["class"] in ("placement", "graph") and wu1:
            allowed = {wu1[0]["value"]["id"], wu1[0]["value"]["implements"]} - {"none"}
            if f["source"]["identity"] not in allowed: fail(f"{f['class']} is read from {f['source']['identity']}, which is neither the work unit nor the issue it implements (R17)")
        if f["class"] == "checks" and rp1 and f["source"]["identity"] != rp1[0]["value"]["id"]: fail(f"checks are read from {f['source']['identity']} but the repository is {rp1[0]['value']['id']} (R17)")
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
            gr = get("graph")
            if not est(gr): fail("merge cannot be derived without the native dependency graph (R15)")
            if any(b["state"] != "closed" for b in gr["value"]["blocked_by"]): fail("merge is blocked: a native blocker is still open (R15)")
            targets = {x["value"]["id"] for x in (repo, wu) if est(x)}
            if not (est(auth) and any("merge:routine" in g["scopes"] and g["target"] in targets for g in auth["value"]["grants"])): fail("merge requires a merge:routine grant targeting the repository or work unit (R15)")
            # no reserved boundary that targets us may apply; every boundary-evidence fact is consulted (so it is an
            # input) and an evidence fact that is not ESTABLISHED cannot show the boundary does NOT apply
            for ekey, field, cond in evidence.values():
                ev = get(ekey.split(".")[0])
                targeted = [hb["boundary"] for hb in auth["value"]["human_boundaries"] if hb["target"] in targets and hb["boundary"] in evidence and evidence[hb["boundary"]][0] == ekey]
                if targeted and not est(ev): fail(f"merge cannot be derived: boundary {targeted[0]} targets this work and its evidence fact {ekey} is not ESTABLISHED (R15)")
                if targeted and cond == "not-none" and ev["value"][field] != "none": fail(f"merge is blocked by reserved boundary {targeted[0]}, which applies here (R15)")
        elif act == "repair":
            rev = get("review")
            if not (est(rev) and rev["value"]["verdict"] == "CHANGES REQUIRED" and cur and rev["value"]["head"] == cur): fail("repair requires CHANGES REQUIRED on the current HEAD (R15)")
            if not head["value"]["current"]: fail("repair requires the HEAD to be current — a stale HEAD is re-reviewed, not repaired (R15)")
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
    kinds = {"UNKNOWN": 0, "CONFLICT": 0, "NOT_APPLICABLE": 0}
    for _, facts in exs:
        for f in facts:
            if f["status"] in kinds: kinds[f["status"]] += 1
    print(f"snapshots={len(exs)} complete={sum(1 for k,_ in exs if k=='complete snapshot')} facts={n} unknown={kinds['UNKNOWN']} conflict={kinds['CONFLICT']} not_applicable={kinds['NOT_APPLICABLE']}")
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
case "$out" in *"snapshots=8 complete=1 "*) ok ;; *) bad "eight examples parsed, one complete snapshot: $out" ;; esac
case "$out" in *"unknown=1 conflict=1 not_applicable=2"*) ok ;; *) bad "examples include exactly one UNKNOWN, one CONFLICT and two NOT_APPLICABLE facts: $out" ;; esac

# ======================== mutation controls: the validator discriminates ========================
base='{"schema_version":"1","key":"review.independent","class":"review","status":"ESTABLISHED","value":{"verdict":"PASS","head":"0123456789abcdef0123456789abcdef01234567","reviewer":"login:github-actions[bot]","record":"github.com/acme/widgets#42/comment/9100"},"source":{"type":"github-api","identity":"github.com/acme/widgets#42/comment/9100","version":"2026-09-06T11:58:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567","comment:github.com/acme/widgets#42/comment/9100"],"provenance":"https://github.com/acme/widgets/pull/42#issuecomment-9100"}'
accepts() {
  [ -n "$1" ] || { bad "control produced no fact — the mutation itself failed"; return 1; }
  printf '%s' "$1" | python3 "$VAL" "$TSV" "$DOC" one >/dev/null 2>&1
}
accepts "$base" && ok || bad "control: the canonical review fact is accepted"
mut() { printf '%s' "$base" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$(mut 'f["status"]="UNKNOWN"; f["detail"]={"reason":"x","candidates":[]}')" && bad "UNKNOWN with a value must be rejected (R6)" || ok
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]')" && bad "UNKNOWN without detail must be rejected" || ok
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"the endpoint returned 403","candidates":[]}')" && ok || bad "control: an UNKNOWN with a well-shaped detail is accepted"
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]="could not read the review"')" && bad "a string detail must be rejected (R14)" || ok
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"x"}')" && bad "a detail without candidates must be rejected (R14)" || ok
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"x","candidates":[],"body":"the raw comment"}')" && bad "a detail carrying an extra (prose) key must be rejected (R2/R14)" || ok
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"","candidates":[]}')" && bad "an empty detail.reason must be rejected (R14)" || ok
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"x","candidates":["the comment the bot left yesterday"]}')" && bad "a prose candidate must be rejected (R14)" || ok
accepts "$(mut 'f["detail"]={"reason":"x","candidates":[]}')" && bad "detail on an ESTABLISHED fact must be rejected" || ok
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
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["inputs"]="review.independent"; print(json.dumps(f))')" && bad "inputs as a string must be rejected: the field record says list (R14)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["identity"]="fact-model"; print(json.dumps(f))')" && bad "a derived source identity outside its grammar must be rejected (R14)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["identity"]="fact-model/2"; print(json.dumps(f))')" && bad "a derived identity naming another schema version than the fact's must be rejected (R14)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["inputs"]=["review.independent","review.independent"]; f["source"]["version"]="1;review.independent@2026-09-06T11:58:00Z;review.independent@2026-09-06T11:58:00Z"; print(json.dumps(f))')" && bad "a derivation listing one input twice must be rejected (R17)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["because"]=["review.independent","review.independent"]; print(json.dumps(f))')" && bad "a derivation naming one reason twice must be rejected (R17)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["version"]="1;review.independent@2026-09-06T11:58:00Z\n"; print(json.dumps(f))')" && bad "a derived version with a trailing newline must be rejected (whole-string match)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["version"]="1;review.independent@2026-09-06T11:58:00Z\tx"; print(json.dumps(f))')" && bad "a tab inside a derived version must be rejected (whitespace-safe grammar)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["version"]="1"; print(json.dumps(f))')" && bad "a derived version that omits its inputs' versions must be rejected (R4)" || ok
accepts "$(printf '%s' "$derived" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["version"]="1;checks.required@x"; print(json.dumps(f))')" && bad "a derived version naming a key that is not an input must be rejected (R4)" || ok
accepts "$(mut 'f["invalidators"]=["head:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","comment:github.com/acme/widgets#42/comment/9100"]')" && bad "a review whose head: invalidator names a different HEAD than its value must be rejected (R7)" || ok
accepts "$(mut 'f["invalidators"].append("the reviewer changes their mind")')" && bad "a prose invalidator must be rejected (R16)" || ok
accepts "$(mut 'f["invalidators"].append({"kind":"head"})')" && bad "an object invalidator must be rejected (R16)" || ok
accepts "$(mut 'f["invalidators"]=f["invalidators"]*2')" && bad "a repeated invalidator must be rejected (R16)" || ok
accepts "$(mut 'f["invalidators"].append("head:0123456")')" && bad "an abbreviated head: invalidator must be rejected (R1/R16)" || ok
accepts "$(mut 'f["provenance"]="the maintainer approved this in chat"')" && bad "prose provenance must be rejected (R16)" || ok
accepts "$(mut 'f["provenance"]={"url":"https://github.com/acme/widgets/pull/42"}')" && bad "an object provenance must be rejected (R16)" || ok
# R7 by status: UNKNOWN binds to the one HEAD it was observed against; NOT_APPLICABLE binds to none
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}')" && ok || bad "control: an UNKNOWN review observed against one HEAD is accepted (R7)"
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["invalidators"]=["pull_request:github.com/acme/widgets#42"]')" && bad "an UNKNOWN HEAD-bound fact with no observed HEAD must be rejected (R7)" || ok
accepts "$(mut 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["invalidators"].append("head:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")')" && bad "an UNKNOWN HEAD-bound fact naming two HEADs is ambiguous and must be rejected (R7)" || ok
accepts "$(mut 'f["status"]="NOT_APPLICABLE"; del f["value"]; f["invalidators"]=["issue:github.com/acme/widgets#41"]')" && ok || bad "control: a NOT_APPLICABLE review invalidated by its issue is accepted (R7)"
accepts "$(mut 'f["status"]="NOT_APPLICABLE"; del f["value"]')" && bad "a NOT_APPLICABLE HEAD-bound fact naming a HEAD must be rejected — there is none to be stale against (R7)" || ok
# the TSV is the schema authority: mutate the AUTHORITY and the same fact must fail — proof the validator reads shapes from it
mtsv="$WORK/mutant.tsv"
sed 's/^class\treview\trequired\t{verdict: <verdict>, head: <commit>, reviewer: <login>, record: <comment>}/class\treview\trequired\t{verdict: <verdict>, head: <commit>, reviewer: <login>, record: <comment>, rationale: <text>}/' "$TSV" > "$mtsv"
grep -q 'rationale: <text>' "$mtsv" && ok || bad "control: the mutant authority carries the extra key"
if printf '%s' "$base" | python3 "$VAL" "$mtsv" "$DOC" one >/dev/null 2>&1; then bad "the validator must read value shapes from the authority: a shape with an extra key rejects the old fact" ; else ok; fi
sed 's/^class\treview\trequired\t{verdict: <verdict>, head: <commit>, reviewer: <login>, record: <comment>}/class\treview\trequired\t{verdict: <verdict>, head: <commit>, reviewer: <text>, record: <comment>}/' "$TSV" > "$mtsv"
if printf '%s' "$base" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["reviewer"]="whoever ran the lane"; print(json.dumps(f))' | python3 "$VAL" "$mtsv" "$DOC" one >/dev/null 2>&1; then ok; else bad "control: loosening the authority's shape to <text> is honoured by the validator (it reads the TSV)"; fi
sed 's/^field\tobserved_at\trequired\tstring\t/field\tobserved_at\trequired\tlist\t/' "$TSV" > "$mtsv"
grep -q '^field.observed_at.required.list' "$mtsv" && ok || bad "control: the mutant authority retypes observed_at"
if printf '%s' "$base" | python3 "$VAL" "$mtsv" "$DOC" one >/dev/null 2>&1; then bad "the validator must read envelope field types from the authority: retyping observed_at to list rejects the old fact"; else ok; fi
sed 's/^identifier\tlogin\t[^\t]*\t/identifier\tlogin\t^login:[a-z]+$\t/' "$TSV" > "$mtsv"
if printf '%s' "$base" | python3 "$VAL" "$mtsv" "$DOC" one >/dev/null 2>&1; then bad "the validator must read identifier grammars from the authority: a narrowed login grammar rejects github-actions[bot]"; else ok; fi
accepts "$(mut 'f["source"]["version"]="latest"')" && bad "a github-api source version outside its grammar must be rejected (R14)" || ok
accepts "$(mut 'f["source"]["version"]="9100"')" && bad "a numeric node id must not version a mutable github-api node (freshness)" || ok
accepts "$(mut 'f["source"]["version"]="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"')" && bad "a commit version on a HEAD-bound fact that is not its own HEAD must be rejected (R14)" || ok
accepts "$(mut 'f["provenance"]="https://github.com/acme/widgets/pull/42\t#issuecomment-9100"')" && bad "a tab inside provenance must be rejected (whitespace-safe grammar)" || ok
accepts "$(mut 'f["provenance"]="https://github.com/acme/widgets/pull/42\n"')" && bad "a trailing newline in provenance must be rejected (whole-string match)" || ok
accepts "$(mut 'f["value"]["head"]="0123456789abcdef0123456789abcdef01234567\n"')" && bad "a trailing newline on a commit must be rejected (whole-string match)" || ok
accepts "$(mut 'f["source"]["version"]="2026-09-06T11:58:00Z\n"')" && bad "a trailing newline on a source version must be rejected (whole-string match)" || ok
accepts "$(mut 'f["observed_at"]=["2026-09-06T12:00:05Z"]')" && bad "observed_at as a list must be rejected: the field record says string (R14)" || ok
accepts "$(mut 'f["invalidators"]="head:0123456789abcdef0123456789abcdef01234567"')" && bad "invalidators as a string must be rejected: the field record says list (R14)" || ok
accepts "$(mut 'f["provenance"]=["https://github.com/acme/widgets/pull/42"]')" && bad "provenance as a list must be rejected: the field record says string (R14)" || ok
# exact value shapes, recursively (R14): prose keys nested inside values
accepts "$(mut 'f["value"]["conclusion"]="looks fine"')" && bad "an extra key in a review value must be rejected (R14)" || ok
# the source identity is the node the value describes (R17); repository names are one lower-case spelling
accepts "$(mut 'f["value"]["record"]="github.com/acme/widgets#42/comment/9101"; f["invalidators"].append("comment:github.com/acme/widgets#42/comment/9101")')" && bad "a review whose record is not the comment its source names must be rejected (R17)" || ok
accepts "$(mut 'f["invalidators"]=[i for i in f["invalidators"] if not i.startswith("comment:")]')" && bad "a review that does not list its record as a comment: invalidator must be rejected (R17)" || ok
accepts "$(mut 'f["value"]["record"]="github.com/Acme/Widgets#42/comment/9100"; f["source"]["identity"]=f["value"]["record"]; f["invalidators"]=["head:0123456789abcdef0123456789abcdef01234567","comment:"+f["value"]["record"]]')" && bad "a mixed-case owner/name is a projection, never the identity (R1)" || ok
wu='{"schema_version":"1","key":"work_unit.identity","class":"work_unit","status":"ESTABLISHED","value":{"kind":"pull_request","id":"github.com/acme/widgets#42","implements":"github.com/acme/widgets#41"},"source":{"type":"github-api","identity":"github.com/acme/widgets#42","version":"2026-09-06T12:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["pull_request:github.com/acme/widgets#42"],"provenance":"https://github.com/acme/widgets/pull/42"}'
accepts "$wu" && ok || bad "control: a canonical work_unit fact is accepted"
accepts "$(printf '%s' "$wu" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["source"]["version"]="0123456789abcdef0123456789abcdef01234567"; print(json.dumps(f))')" && bad "a commit cannot version a mutable work_unit node (R14)" || ok
accepts "$(printf '%s' "$wu" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["body"]="the PR description"; print(json.dumps(f))')" && bad "work_unit.value.body must be rejected (R2/R14)" || ok
accepts "$(printf '%s' "$wu" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["id"]="github.com/acme/widgets#43"; print(json.dumps(f))')" && bad "a work unit whose value names a different node than its source must be rejected (R17)" || ok
accepts "$(printf '%s' "$wu" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["kind"]="issue"; f["invalidators"]=["issue:github.com/acme/widgets#42"]; print(json.dumps(f))')" && bad "an issue that claims to implement another issue must be rejected (R17)" || ok
accepts "$(printf '%s' "$wu" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["implements"]="none"; print(json.dumps(f))')" && ok || bad "control: a pull request that implements no issue is a valid work unit"
accepts "$(printf '%s' "$wu" | python3 -c 'import json,sys; f=json.load(sys.stdin); del f["value"]["implements"]; print(json.dumps(f))')" && bad "a work unit without the implements field must be rejected (R14)" || ok
accepts "$(printf '%s' "$wu" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["id"]="github.com/Acme/widgets#42"; f["source"]["identity"]=f["value"]["id"]; f["invalidators"]=["pull_request:"+f["value"]["id"]]; print(json.dumps(f))')" && bad "a mixed-case owner in a work-unit id must be rejected (R1)" || ok
acc='{"schema_version":"1","key":"acceptance.contract","class":"acceptance","status":"ESTABLISHED","value":{"contract":"github.com/acme/widgets#41","head":"0123456789abcdef0123456789abcdef01234567","items":[{"id":"a1","state":"MET"}]},"source":{"type":"github-api","identity":"github.com/acme/widgets#41","version":"2026-09-05T18:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["issue:github.com/acme/widgets#41","head:0123456789abcdef0123456789abcdef01234567"],"provenance":"https://github.com/acme/widgets/issues/41"}'
accepts "$acc" && ok || bad "control: a canonical acceptance fact is accepted"
accepts "$(printf '%s' "$acc" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["items"][0]["summary"]="done, I think"; print(json.dumps(f))')" && bad "acceptance.items[].summary must be rejected (R2/R14)" || ok
accepts "$(printf '%s' "$acc" | python3 -c 'import json,sys; f=json.load(sys.stdin); del f["value"]["head"]; print(json.dumps(f))')" && bad "an acceptance fact without an explicit HEAD must be rejected (R7)" || ok
accepts "$(printf '%s' "$acc" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["contract"]="github.com/acme/widgets#40"; print(json.dumps(f))')" && bad "an acceptance fact whose contract is not the node its source names must be rejected (R17)" || ok
accepts "$(printf '%s' "$acc" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["items"].append({"id":"a1","state":"NOT_MET"}); print(json.dumps(f))')" && bad "duplicate acceptance item ids (one MET, one NOT_MET) must be rejected (R14)" || ok
accepts "$(printf '%s' "$acc" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["items"][0]["id"]={"body":"raw prose"}; print(json.dumps(f))')" && bad "an object as an acceptance item id must be rejected (R2/R14)" || ok
accepts "$(printf '%s' "$acc" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["items"][0]["id"]=""; print(json.dumps(f))')" && bad "an empty acceptance item id must be rejected (R14)" || ok
accepts "$(printf '%s' "$acc" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["value"]["items"][0]["id"]="the first criterion, roughly"; print(json.dumps(f))')" && bad "a prose acceptance item id must be rejected (R14)" || ok
auth='{"schema_version":"1","key":"authority.standing","class":"authority","status":"ESTABLISHED","value":{"grants":[{"decision":"github.com/acme/widgets#7/comment/9001","target":"github.com/acme/widgets","scopes":["merge:routine"]}],"human_boundaries":[{"decision":"github.com/acme/widgets#7/comment/9001","target":"github.com/acme/widgets","boundary":"release:approve"}]},"source":{"type":"human-decision","identity":"github.com/acme/widgets#7/comment/9001","version":"2026-09-01T09:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["comment:github.com/acme/widgets#7/comment/9001"],"provenance":"https://github.com/acme/widgets/issues/7"}'
accepts "$auth" && ok || bad "control: a canonical authority fact is accepted"
amut() { printf '%s' "$auth" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$(amut 'f["source"]["type"]="github-api"')" && bad "authority from a non-human-decision source must be rejected (R5)" || ok
accepts "$(amut 'f["value"]["grants"][0]["decision"]="github.com/acme/widgets#7/comment/9002"')" && bad "a grant naming a decision the fact's source does not back must be rejected (R5)" || ok
accepts "$(amut 'f["value"]["human_boundaries"][0]["decision"]="github.com/acme/widgets#8/comment/9100"')" && bad "a boundary naming a decision the fact's source does not back must be rejected (R5)" || ok
accepts "$(amut 'f["inferred"]=True')" && bad "an inferred authority fact must be rejected (R5)" || ok
accepts "$(amut 'f["inferred"]=False')" && bad "inferred: false on authority must be rejected (never a representation)" || ok
accepts "$(amut 'f["source"]["identity"]="role:owner"')" && bad "a human-decision source whose identity is a role must be rejected (R5/R14)" || ok
accepts "$(amut 'f["source"]["version"]="banana"')" && bad "a human-decision source version outside its grammar must be rejected (R14)" || ok
accepts "$(amut 'f["source"]["identity"]="the maintainer approved this in chat"')" && bad "a human-decision source whose identity is a summary must be rejected (R5/R14)" || ok
accepts "$(amut 'f["source"]["version"]="9001"')" && bad "a decision recorded in a comment versioned by the comment id must be rejected — comments are edited, ids are not (R14)" || ok
accepts "$(amut 'f["source"]["version"]="2026-09-03T10:00:00Z"')" && ok || bad "control: an edited decision carries the new updated_at as its version"
# git and repository-file sources: the commit in the identity IS the version observed
rf='{"schema_version":"1","key":"acceptance.contract","class":"acceptance","status":"ESTABLISHED","value":{"contract":"github.com/acme/widgets#41","head":"0123456789abcdef0123456789abcdef01234567","items":[{"id":"a1","state":"MET"}]},"source":{"type":"repository-file","identity":"github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:docs/acceptance/41.md","version":"0123456789abcdef0123456789abcdef01234567"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567","ref:github.com/acme/widgets/master"],"provenance":"https://github.com/acme/widgets/blob/0123456789abcdef0123456789abcdef01234567/docs/acceptance/41.md"}'
accepts "$rf" && ok || bad "control: a repository-file source with a path identity is accepted (the grammar is Python-compatible)"
rmut() { printf '%s' "$rf" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$(rmut 'f["source"]["version"]="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"')" && bad "a repository-file read pinned to commit A claiming version B must be rejected (R14)" || ok
accepts "$(rmut 'f["source"]["identity"]="github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:docs/with space.md"')" && bad "a repository-file path with whitespace is outside the grammar" || ok
accepts "$(rmut 'f["source"]["identity"]="github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:docs/with\ttab.md"')" && bad "a repository-file path with a tab is outside the grammar" || ok
accepts "$(rmut 'f["source"]["identity"]="github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:docs/acceptance/41.md\n"')" && bad "a repository-file identity with a trailing newline must be rejected (whole-string match)" || ok
accepts "$(rmut 'f["source"]={"type":"git","identity":"github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567","version":"0123456789abcdef0123456789abcdef01234567"}')" && ok || bad "control: a git source pinned to a commit with the same version is accepted"
accepts "$(rmut 'f["source"]={"type":"git","identity":"github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567","version":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}')" && bad "a git identity at commit A claiming version B must be rejected (R14)" || ok
accepts "$(rmut 'f["source"]={"type":"git","identity":"github.com/acme/widgets@ref/master","version":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}')" && ok || bad "control: a git ref identity records the commit it pointed at as its version"
accepts "$(amut 'del f["value"]["grants"][0]["target"]')" && bad "a grant without an applicability target must be rejected (R14)" || ok
accepts "$(amut 'f["value"]["grants"][0]["target"]="this repository and its forks"')" && bad "a prose grant target must be rejected (R14)" || ok
accepts "$(amut 'f["value"]["grants"][0]["decision"]="approved by the owner"')" && bad "a grant whose decision is not a durable record must be rejected (R5)" || ok
accepts "$(amut 'f["value"]["grants"][0]["scopes"]=["routine merge of a green PR"]')" && bad "a prose scope must be rejected (R13)" || ok
accepts "$(amut 'f["value"]["human_boundaries"][0]["boundary"]="release approval"')" && bad "a prose boundary must be rejected (R13)" || ok
accepts "$(amut 'f["value"]["human_boundaries"]=["release:approve"]')" && bad "a bare-token boundary without decision and target must be rejected (R13/R14)" || ok
accepts "$(amut 'f["value"]["human_boundaries"][0]["target"]="everywhere"')" && bad "a prose boundary target must be rejected (R14)" || ok
accepts "$(amut 'f["value"]["grants"][0]["scopes"]=[]')" && bad "a grant with no scopes must be rejected (R13)" || ok
chk='{"schema_version":"1","key":"checks.required","class":"checks","status":"ESTABLISHED","value":{"head":"0123456789abcdef0123456789abcdef01234567","required":["doctor","tests"],"results":[{"name":"doctor","state":"success"},{"name":"tests","state":"success"}]},"source":{"type":"github-api","identity":"github.com/acme/widgets","version":"0123456789abcdef0123456789abcdef01234567"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567","ruleset:github.com/acme/widgets"],"provenance":"https://github.com/acme/widgets/commit/0123456789abcdef0123456789abcdef01234567/checks"}'
cmut() { printf '%s' "$chk" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$chk" && ok || bad "control: a covered checks fact is accepted"
accepts "$(cmut 'f["value"]["results"]=f["value"]["results"][:1]')" && bad "a required check with no result must be rejected (R12)" || ok
accepts "$(cmut 'f["value"]["results"][1]["state"]="green"')" && bad "a check state outside the vocabulary must be rejected (R12)" || ok
accepts "$(cmut 'f["value"]["results"][1]["conclusion"]="success"')" && bad "checks.results[].conclusion (an undeclared nested key) must be rejected (R14)" || ok
accepts "$(cmut 'f["value"]["results"].append({"name":"tests","state":"failure"})')" && bad "a duplicate check result must be rejected (R12)" || ok
accepts "$(cmut 'f["source"]["identity"]="github.com/acme/widgets#42"')" && bad "checks read from something other than a repository must be rejected (R17)" || ok
accepts "$(cmut 'f["invalidators"]=[i for i in f["invalidators"] if not i.startswith("ruleset:")]')" && bad "checks without the repository's ruleset: invalidator must be rejected — required checks change with the rulesets (R17)" || ok
gr='{"schema_version":"1","key":"graph.native","class":"graph","status":"ESTABLISHED","value":{"parent":{"id":"github.com/acme/widgets#40","state":"open"},"children":[],"blocked_by":[{"id":"github.com/acme/widgets#39","state":"closed"}]},"source":{"type":"github-api","identity":"github.com/acme/widgets#41","version":"2026-09-06T11:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["issue:github.com/acme/widgets#41","issue:github.com/acme/widgets#40","issue:github.com/acme/widgets#39"],"provenance":"https://github.com/acme/widgets/issues/41"}'
gmut() { printf '%s' "$gr" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
accepts "$gr" && ok || bad "control: a graph fact with relationship states is accepted"
accepts "$(gmut 'f["value"]["blocked_by"]=["github.com/acme/widgets#39"]')" && bad "a relationship without state must be rejected" || ok
accepts "$(gmut 'f["value"]["parent"]["state"]="done"')" && bad "a relationship state outside the vocabulary must be rejected" || ok
accepts "$(gmut 'f["source"]["identity"]="github.com/acme/widgets"')" && bad "a graph read from a repository rather than a work-unit node must be rejected (R17)" || ok
accepts "$(gmut 'f["invalidators"]=["issue:github.com/acme/widgets#40","issue:github.com/acme/widgets#39"]')" && bad "a graph that does not list the node it was read from as an invalidator must be rejected (R17)" || ok
accepts "$(gmut 'f["invalidators"]=[i for i in f["invalidators"] if not i.endswith("#39")]')" && bad "a graph representing blocker #39 without listing it as an invalidator must be rejected — its state can change without the parent changing (R17)" || ok
accepts "$(gmut 'f["invalidators"]=[i for i in f["invalidators"] if not i.endswith("#40")]')" && bad "a graph representing parent #40 without listing it must be rejected (R17)" || ok
# head: the base ref is a freshness dependency the value implies
hd='{"schema_version":"1","key":"head.exact","class":"head","status":"ESTABLISHED","value":{"head":"0123456789abcdef0123456789abcdef01234567","base_ref":"master","base":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","current":true},"source":{"type":"github-api","identity":"github.com/acme/widgets#42","version":"0123456789abcdef0123456789abcdef01234567"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567","ref:github.com/acme/widgets/master"],"provenance":"https://github.com/acme/widgets/pull/42/commits"}'
accepts "$hd" && ok || bad "control: a head fact listing its HEAD and base ref is accepted"
accepts "$(printf '%s' "$hd" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["invalidators"]=["head:0123456789abcdef0123456789abcdef01234567"]; print(json.dumps(f))')" && bad "a head fact without ref:<repository>/<base_ref> must be rejected — the base moves without the HEAD moving (R17)" || ok
accepts "$(printf '%s' "$hd" | python3 -c 'import json,sys; f=json.load(sys.stdin); f["invalidators"][1]="ref:github.com/acme/widgets/main"; print(json.dumps(f))')" && bad "a head fact whose ref: invalidator names a different branch than base_ref must be rejected (R17)" || ok
accepts "$(gmut 'f["value"]["blocked_by"].append({"id":"github.com/acme/widgets#39","state":"open"})')" && bad "one blocker listed as both closed and open must be rejected (R14)" || ok
accepts "$(gmut 'f["value"]["children"]=[{"id":"github.com/acme/widgets#42","state":"open"},{"id":"github.com/acme/widgets#42","state":"open"}]')" && bad "a child listed twice must be rejected (R14)" || ok
# snapshot-level controls (R11): the page's complete snapshot minus one required class must be rejected as a snapshot
sets() {
  case "$1" in *'"facts": }'*|*'"facts": '|'') bad "snapshot control produced no facts — the mutation itself failed"; return 1 ;; esac
  printf '%s' "$1" | python3 "$VAL" "$TSV" "$DOC" set >/dev/null 2>&1
}
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
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'h=[f for f in s if f["class"]=="head"][0]; h["source"]["identity"]="github.com/acme/widgets#43"')")" && bad "a head read from a different node than the set's work unit must be rejected (R17)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'c=[f for f in s if f["class"]=="checks"][0]; c["source"]["identity"]="github.com/acme/program"; c["invalidators"]=[i for i in c["invalidators"] if not i.startswith("ruleset:")]+["ruleset:github.com/acme/program"]')")" && bad "checks read from a different repository than the set's must be rejected (R17)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'p=[f for f in s if f["class"]=="placement"][0]; p["invalidators"]=[i for i in p["invalidators"] if not i.startswith("issue:")]')")" && bad "a placement that does not list the node it was read from must be rejected (R17)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'p=[f for f in s if f["class"]=="placement"][0]; p["source"]["identity"]="github.com/acme/widgets#40"; p["invalidators"]=["issue:github.com/acme/widgets#40"]+[i for i in p["invalidators"] if not i.startswith("issue:")]')")" && bad "a placement read from a node that is neither the work unit nor the issue it implements must be rejected (R17)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'g=[f for f in s if f["class"]=="graph"][0]; g["source"]["identity"]="github.com/acme/widgets#40"; g["invalidators"]=["issue:github.com/acme/widgets#40"]+[i for i in g["invalidators"] if i!="issue:github.com/acme/widgets#41"]')")" && bad "a graph spliced in from an unrelated node must be rejected (R17)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'w=[f for f in s if f["class"]=="work_unit"][0]; w["value"]["implements"]="none"')")" && bad "with no declared implements, placement and graph read from another issue must be rejected (R17)" || ok
# merge consults the native graph: an open blocker, an unreadable graph, or a derivation that omits it is rejected
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'g=[f for f in s if f["class"]=="graph"][0]; g["value"]["blocked_by"][0]["state"]="open"')")" && bad "merge while a native blocker is open must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'g=[f for f in s if f["class"]=="graph"][0]; g["status"]="UNKNOWN"; del g["value"]; g["detail"]={"reason":"403","candidates":[]}')")" && bad "merge while the dependency graph is UNKNOWN must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="next_action"][0]; nx["inputs"]=[i for i in nx["inputs"] if i!="graph.native"]; nx["source"]["version"]=";".join(p for p in nx["source"]["version"].split(";") if not p.startswith("graph.native@"))')")" && bad "a merge derivation that omits the consulted graph from its inputs must be rejected (R4/R15)" || ok
# repair needs a CURRENT head: the page's Example 2 derives repair; make its HEAD stale and it must be rejected
ex2="$(python3 - "$DOC" <<'PY'
import json, re, sys
t = open(sys.argv[1]).read()
m = re.search(r"^### Example 2 — [^\n]*\(fragment\)\n.*?```json\n(.*?)\n```", t, flags=re.S | re.M)
print(json.dumps(json.loads(m.group(1))))
PY
)"
printf '%s' "$ex2" | grep -q '"action": "repair"' && ok || bad "control: Example 2 derives repair"
sets "$(printf '{"complete": false, "facts": %s}' "$ex2")" && ok || bad "control: the page's repair fragment is accepted"
sets "$(printf '{"complete": false, "facts": %s}' "$(printf '%s' "$ex2" | python3 -c 'import json,sys; s=json.load(sys.stdin); h=[f for f in s if f["class"]=="head"][0]; h["value"]["current"]=False; print(json.dumps(s))')")" && bad "repair on a HEAD that is not current must be rejected — a stale HEAD is re-reviewed, not repaired (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="authority"][0]; nx["value"]["grants"][0]["scopes"]=["close:issue"]')")" && bad "merge without a merge:routine grant must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="authority"][0]; nx["value"]["grants"][0]["target"]="github.com/acme/program"')")" && bad "merge with a grant targeting another repository must be rejected (R15)" || ok
# a reserved boundary that applies here blocks merge: add placement:release for this repository and place the work in a release
smerge_boundary='a=[f for f in s if f["class"]=="authority"][0]; a["value"]["human_boundaries"].append({"decision": a["source"]["identity"], "target": "github.com/acme/widgets", "boundary": "placement:release"}); p=[f for f in s if f["class"]=="placement"][0]; p["value"]["release"]="v1.2.0"'
sets "$(printf '{"complete": true, "facts": %s}' "$(smut "$smerge_boundary")")" && bad "merge while a targeted placement:release boundary applies (the work is in a release) must be rejected (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'a=[f for f in s if f["class"]=="authority"][0]; a["value"]["human_boundaries"].append({"decision": a["source"]["identity"], "target": "github.com/acme/widgets", "boundary": "placement:release"})')")" && ok || bad "control: the same boundary with no release placement does not block merge (its evidence does not hold)"
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'a=[f for f in s if f["class"]=="authority"][0]; a["value"]["human_boundaries"].append({"decision": a["source"]["identity"], "target": "github.com/acme/widgets", "boundary": "placement:release"}); p=[f for f in s if f["class"]=="placement"][0]; p["status"]="UNKNOWN"; del p["value"]; p["detail"]={"reason":"403","candidates":[]}')")" && bad "merge while the targeted boundary's evidence fact is UNKNOWN must be rejected — it cannot be shown not to apply (R15)" || ok
sets "$(printf '{"complete": true, "facts": %s}' "$(smut 'nx=[f for f in s if f["class"]=="next_action"][0]; nx["inputs"]=[i for i in nx["inputs"] if i!="placement.current"]; nx["source"]["version"]=";".join(p for p in nx["source"]["version"].split(";") if not p.startswith("placement.current@"))')")" && bad "a merge derivation that omits the consulted boundary-evidence fact (placement) from its inputs must be rejected (R4/R15)" || ok
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
