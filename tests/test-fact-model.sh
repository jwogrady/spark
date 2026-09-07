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
assert_eq "one class-status record per class" "$(rec class | cut -f2 | sort | tr '\n' ' ')" "$(rec class-status | cut -f2 | sort | tr '\n' ' ')"
assert_eq "exactly one canonical key per class" "$(rec class | cut -f2 | sort | tr '\n' ' ')" "$(rec key | cut -f2 | sort | tr '\n' ' ')"
assert_eq "every canonical key is prefixed by its class" "" "$(rec key | awk -F'\t' 'index($3, $2 ".") != 1')"
assert_eq "eight invalidator grammars" "8" "$(rec invalidator | wc -l | tr -d ' ')"
assert_eq "30 constraint records" "30" "$(rec constraint | wc -l | tr -d ' ')"
while IFS=$'\t' read -r _ scope rx _; do
  if printf 'probe' | grep -qE "$rx" >/dev/null 2>&1; then rc=0; else rc=$?; fi
  [ "$rc" -le 1 ] && ok || bad "constraint regex for $scope compiles as an ERE (no lookaround, so any consumer can apply it)"
  case "$scope" in invalidator|source-identity/*) ok ;; invalidator/*) rec invalidator | cut -f2 | grep -qx "${scope#invalidator/}" && ok || bad "constraint scope $scope names a declared invalidator kind" ;; *) rec identifier | cut -f2 | grep -qx "$scope" && ok || bad "constraint scope $scope names a declared identifier kind" ;; esac
done <<EOF
$(rec constraint)
EOF
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
assert_eq "eighteen rules" "18" "$(rec rule | wc -l | tr -d ' ')"
assert_eq "one source-version grammar per source type" "$(rec source | cut -f2 | sort | tr '\n' ' ')" "$(rec source-version | cut -f2 | sort | tr '\n' ' ')"
assert_eq "twenty-one identifier kinds" "21" "$(rec identifier | wc -l | tr -d ' ')"
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
    if r[0] in ("identifier", "source-identity", "source-version", "invalidator", "constraint"):
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
assert_eq "doc constraint table has one row per constraint record" "$(rec constraint | wc -l | tr -d ' ')" "$(awk '/^## Constraints/,/^## Invalidators/' "$DOC" | grep -c '^| `')"
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
sta = {norm(c[0]): c for c in table("| Status | `value` allowed |")}
for r in (r for r in rows if r[0] == "status"):
    c = sta.get(r[1]); say(c is not None and [norm(x) for x in c[1:]] == [r[2], norm(r[3])], f"status {r[1]} row is the TSV's value-allowed flag and meaning")
sidr = {r[1]: r for r in rows if r[0] == "source-identity"}; sverr = {r[1]: r for r in rows if r[0] == "source-version"}
srcr = {norm(c[0]): c for c in table("| Source type | What it is |")}
for r in (r for r in rows if r[0] == "source"):
    c = srcr.get(r[1]); say(c is not None and [norm(x) for x in c[1:]] == [norm(r[3]), norm(r[2]), norm(sidr[r[1]][3]), norm(sverr[r[1]][3])], f"source {r[1]} row is the TSV's description, version identity, identity form and version grammar")
bev = {norm(c[0]): c for c in table("| Boundary | Evidence fact |")}
for r in (r for r in rows if r[0] == "boundary-evidence"):
    c = bev.get(r[1]); say(c is not None and [norm(x) for x in c[1:]] == [r[2], r[3], r[4], norm(r[5])], f"boundary-evidence {r[1]} row is the TSV's fact, field, condition and meaning")
cst = {norm(c[0]): c for c in table("| Class | Admitted statuses |")}
for r in (r for r in rows if r[0] == "class-status"):
    c = cst.get(r[1]); say(c is not None and norm(c[1]).replace(", ", ",") == r[2], f"class-status {r[1]} row lists the TSV's admitted statuses")
con = [c for c in table("| Scope | Forbidden (ERE) |")]
want = [[r[1], r[2], r[3]] for r in rows if r[0] == "constraint"]
got = [[norm(c[0]), c[1].strip("`").replace("\\|", "|"), norm(c[2])] for c in con]
say(got == [[w[0], w[1], norm(w[2])] for w in want], "every constraint row is the TSV's scope, regex and meaning, in order")
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
assert_eq "nine examples on the page" "9" "$(grep -c '^### Example [1-9] — ' "$DOC")"
assert_eq "two examples are complete snapshots (a pull request; an issue with no HEAD)" "2" "$(grep -c '^### Example [1-9] — .*(complete snapshot)$' "$DOC")"
assert_eq "the other seven are marked as fragments" "7" "$(grep -c '^### Example [1-9] — .*(fragment)$' "$DOC")"
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
class_status = {r[1]: set(r[2].split(",")) for r in rows if r[0] == "class-status"}   # class -> admitted statuses (R18)
evidence = {r[1]: (r[2], r[3], r[4]) for r in rows if r[0] == "boundary-evidence"}   # boundary -> (fact key, field, condition)
# Shapes are READ from the authority, never restated here: the class value-shape column and the
# envelope `shape` records share one grammar — {k: shape} exact object, [shape] list, a|b alternatives,
# <kind> an identifier (pseudo-kinds: <text> one non-empty line, <locator> a canonical locator or
# source identity, <source-type> a declared source type), bare word = literal (true/false = booleans).
invalidator_rx = {r[1]: re.compile(r[2]) for r in rows if r[0] == "invalidator"}
constraints = {}
for r in rows:
    if r[0] == "constraint": constraints.setdefault(r[1], []).append((re.compile(r[2]), r[3]))
def constrained(scope, v, where):
    """a value is canonical only when none of its scope's constraint records match (R1)"""
    for rx, meaning in constraints.get(scope, []):
        if rx.search(v): fail(f"{where} = {v!r} is not canonical: {meaning} (R1)")
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
            constrained(kind, v, where)
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
def clean(scope, x):
    """True when no constraint record for the scope matches (R1)"""
    return not any(rx.search(x) for rx, _ in constraints.get(scope, []))
def locator(x):
    """a canonical locator: in some identifier or source-identity grammar AND free of that grammar's constraints"""
    return any(ids[k].fullmatch(x) and clean(k, x) for k in LOCATOR_KINDS) or any(rx.fullmatch(x) and clean(f"source-identity/{t}", x) for t, rx in sid.items())
HEAD_BOUND = {"head", "review", "checks", "acceptance"}
def wu_token(kind, wid): return f"{'pull_request' if kind == 'pull_request' else 'issue'}:{wid}"
def one_wu_token(f, wid, what):
    """fact-level: exactly one of the two work-unit tokens names the node; the set-level check pins the kind"""
    have = {f"issue:{wid}", f"pull_request:{wid}"} & set(f["invalidators"])
    if len(have) != 1: fail(f"{what} lists {wid} as an invalidator exactly once, as issue: or pull_request: (R17)")
FORBIDDEN_KEYS = {"body", "comments", "timeline", "prose", "summary", "history"}
ISO = ids["timestamp"]
import datetime
def real_instant(v, where):
    """the grammar bounds each field; the calendar (30-day months, leap years) needs a parse (R18)"""
    try: datetime.datetime.strptime(v, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError: fail(f"{where} = {v!r} is not a real calendar instant (R18)")

def fail(msg): raise ValueError(msg)

def check_fact(f):
    if not isinstance(f, dict): fail("fact is not an object")
    for k in FORBIDDEN_KEYS & set(f): fail(f"forbidden prose field {k}")
    for name, req in fields.items():
        if req == "required" and name not in f: fail(f"missing required field {name}")
    for k in f:
        if k not in fields: fail(f"unknown field {k}")
        t = ftypes[k]
        if t in PY_TYPES:
            if not (isinstance(f[k], PY_TYPES[t]) and not (t != "boolean" and isinstance(f[k], bool))): fail(f"field {k} must be a {t} (R14)")
        elif t != "any":
            if t not in ids: fail(f"field {k} is typed by an undeclared identifier kind {t}")
            if not isinstance(f[k], str) or not ids[t].fullmatch(f[k]): fail(f"field {k} = {f[k]!r} is not in the {t} grammar (R14/R18)")
            constrained(t, f[k], k)
            if t == "timestamp": real_instant(f[k], k)
    if f["schema_version"] != version: fail("schema_version mismatch")
    if not ids["fact-key"].fullmatch(f["key"]): fail(f"key not canonical: {f['key']}")
    if f["class"] not in classes: fail(f"unknown class {f['class']}")
    if f["key"].split(".")[0] != f["class"]: fail("key prefix must equal class")
    if f["key"] != canon[f["class"]]: fail(f"key {f['key']} is not the canonical key {canon[f['class']]} of class {f['class']} (R1)")
    if "inferred" in f and f["inferred"] is not True: fail("inferred must be the literal true when present")
    if f["status"] not in statuses: fail(f"unknown status {f['status']}")
    if f["status"] not in class_status[f["class"]]: fail(f"{f['class']} does not admit status {f['status']} (R18)")
    if "value" in f and f["value"] is None: fail("value: null is not a representation of absence; omit the field")
    if statuses[f["status"]] == "no" and "value" in f: fail(f"{f['status']} fact carries a value")
    if f["status"] == "ESTABLISHED" and "value" not in f: fail("ESTABLISHED fact without value")
    if f["status"] in ("UNKNOWN", "CONFLICT") and "detail" not in f: fail(f"{f['status']} without detail")
    if "detail" in f:
        if f["status"] not in ("UNKNOWN", "CONFLICT"): fail("detail is present only on UNKNOWN or CONFLICT")
        matches(ENVELOPE["detail"], f["detail"], "detail")
    src = f["source"]
    matches(ENVELOPE["source"], src, "source")
    if classes[f["class"]] == "derived" and src["type"] != "derived": fail(f"{f['class']} is a derived class and carries a derived source, never a raw read (R4/R15)")
    if classes[f["class"]] != "derived" and src["type"] == "derived": fail(f"{f['class']} is read from its source, never derived (R4)")
    if not sid[src["type"]].fullmatch(str(src["identity"])): fail(f"source.identity {src['identity']!r} is not in the {src['type']} grammar (R14)")
    constrained(f"source-identity/{src['type']}", str(src["identity"]), "source.identity")
    if not src["version"]: fail("source.version empty")
    if not sver[src["type"]].fullmatch(str(src["version"])): fail(f"source.version {src['version']!r} is not in the {src['type']} version grammar (R14)")
    if ISO.fullmatch(str(src["version"])): real_instant(str(src["version"]), "source.version")
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
    if not isinstance(f["invalidators"], list) or not f["invalidators"]: fail("invalidators must be a non-empty list")
    for tok in f["invalidators"]:
        if not isinstance(tok, str) or not any(rx.fullmatch(tok) for rx in invalidator_rx.values()): fail(f"invalidator {tok!r} is in no invalidator grammar (R16)")
        constrained("invalidator", tok, "invalidator")
        for kind, rx in invalidator_rx.items():
            if rx.fullmatch(tok): constrained(f"invalidator/{kind}", tok, f"invalidator {kind}")
    if len(set(f["invalidators"])) != len(f["invalidators"]): fail("an invalidator appears twice (R16)")
    if not isinstance(f["provenance"], str) or not ids["provenance"].fullmatch(f["provenance"]): fail(f"provenance {f['provenance']!r} is not a pointer in the provenance grammar (R16)")
    constrained("provenance", f["provenance"], "provenance")
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
            wid = f["source"]["identity"]
            if not ids["work-unit"].fullmatch(wid): fail(f"NOT_APPLICABLE {f['class']} names the work unit it was read from, not {wid} (R17)")
            one_wu_token(f, wid, f"NOT_APPLICABLE {f['class']}")
    if f["status"] == "CONFLICT" and len(f["detail"].get("candidates", [])) < 2: fail("CONFLICT must name at least two candidates")
    c = f["class"]; ident = f["source"]["identity"]
    # invariants that hold for every status (R5, R17): the authority class, and the source/invalidator requirements
    if c == "authority":
        if f["source"]["type"] != "human-decision": fail("authority must come from a human-decision source, whatever its status (R5)")
        if "inferred" in f: fail("authority can never be inferred, whatever its status (R5)")
    if c in ("placement", "graph"):
        if not ids["work-unit"].fullmatch(ident): fail(f"{c} is read from a work-unit node, not {ident} (R17)")
        one_wu_token(f, ident, c)
    if c == "acceptance" and f["source"]["type"] == "github-api":
        if not ids["work-unit"].fullmatch(ident): fail(f"acceptance read from GitHub names its contract, a work-unit node, not {ident} (R17)")
        one_wu_token(f, ident, "acceptance")
    # a fact whose source is a comment lists it; a CONFLICT lists every comment it names as a candidate (R17)
    if ids["comment"].fullmatch(ident) and f"comment:{ident}" not in f["invalidators"]: fail(f"a fact read from comment {ident} lists it as a comment: invalidator, so an edited record goes stale (R17)")
    if f["status"] == "CONFLICT":
        for cand in f["detail"]["candidates"]:
            if ids["comment"].fullmatch(cand) and f"comment:{cand}" not in f["invalidators"]: fail(f"a CONFLICT naming comment {cand} as a candidate lists it as a comment: invalidator (R17)")
    if c == "head" and f["source"]["type"] == "github-api" and f["status"] != "NOT_APPLICABLE" and not ids["work-unit"].fullmatch(ident): fail(f"head read from GitHub names a work unit, not {ident} (R17)")
    if c == "checks" and f["status"] != "NOT_APPLICABLE":   # NOT_APPLICABLE checks name their work unit like every HEAD-bound class (R7)
        if not ids["repository"].fullmatch(ident): fail(f"checks name the repository whose rulesets require them, not {ident} (R17)")
        if f"ruleset:{ident}" not in f["invalidators"]: fail(f"checks do not list ruleset:{ident} — required checks change with the rulesets (R17)")
    v = f.get("value")
    if v is None: return
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
    if c == "work_unit":
        if ident != v["id"]: fail(f"work_unit source {ident} is not the work unit it describes, {v['id']} (R17)")
        if v["kind"] == "issue" and v["implements"] != "none": fail("an issue implements nothing; only a pull request closes an issue (R17)")
        if v["implements"] == v["id"]: fail("a work unit cannot implement itself (R17)")
    if c == "repository" and ident != v["id"]: fail(f"repository source {ident} is not the repository it describes, {v['id']} (R17)")
    if c == "review":
        if ident != v["record"]: fail(f"review source {ident} is not the record it reports, {v['record']} (R17)")
        if f"comment:{v['record']}" not in f["invalidators"]: fail("a review lists its record as a comment: invalidator (R17)")
    if c == "acceptance" and f["source"]["type"] == "github-api" and ident != v["contract"]: fail(f"acceptance source {ident} is not the contract it judges, {v['contract']} (R17)")
    if c == "acceptance": one_wu_token(f, v["contract"], "acceptance")
    # freshness dependencies the value implies are listed, not optional (R17)
    if c == "graph":
        rel = ([v["parent"]] if v["parent"] != "none" else []) + v["children"] + v["blocked_by"]
        for r in rel:
            if wu_token(r["kind"], r["id"]) not in f["invalidators"]: fail(f"graph represents {r['kind']} {r['id']} but does not list {wu_token(r['kind'], r['id'])} as an invalidator (R17)")
            if len({f"issue:{r['id']}", f"pull_request:{r['id']}"} & set(f["invalidators"])) != 1: fail(f"graph lists {r['id']} under two kinds (R17)")
    if c == "head":
        repo = ident.split("#")[0].split("@")[0]
        if f"ref:{repo}/{v['base_ref']}" not in f["invalidators"]: fail(f"head carries base_ref {v['base_ref']} but does not list ref:{repo}/{v['base_ref']} as an invalidator (R17)")

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
    if wu1 and rp1 and wu1[0]["value"]["id"].split("#")[0] != rp1[0]["value"]["id"]: fail(f"work unit {wu1[0]['value']['id']} does not belong to repository {rp1[0]['value']['id']} (R17)")
    for f in facts:
        if f["class"] == "head" and f["source"]["type"] == "github-api" and wu1 and f["source"]["identity"] != wu1[0]["value"]["id"]: fail(f"head is read from {f['source']['identity']} but the work unit is {wu1[0]['value']['id']} (R17)")
        if f["class"] == "acceptance" and wu1 and f["source"]["type"] == "github-api":
            allowed = {wu1[0]["value"]["id"], wu1[0]["value"]["implements"]} - {"none"}
            contract = f["value"]["contract"] if f["status"] == "ESTABLISHED" else f["source"]["identity"]
            if contract not in allowed: fail(f"acceptance contract {contract} is neither the work unit nor the issue it implements — for every status (R17)")
        if f["class"] in ("placement", "graph") and wu1:
            allowed = {wu1[0]["value"]["id"], wu1[0]["value"]["implements"]} - {"none"}
            if f["source"]["identity"] not in allowed: fail(f"{f['class']} is read from {f['source']['identity']}, which is neither the work unit nor the issue it implements (R17)")
        if wu1:
            w = wu1[0]["value"]; kinds = {w["id"]: w["kind"]}
            if w["implements"] != "none": kinds[w["implements"]] = "issue"
            for tok in f["invalidators"]:
                m = re.fullmatch(r"(issue|pull_request):(.*)", tok)
                if m and m.group(2) in kinds and m.group(1) != kinds[m.group(2)]: fail(f"invalidator {tok} names the node under the wrong kind: it is a {kinds[m.group(2)]} (R17)")
        if f["class"] == "checks" and f["status"] != "NOT_APPLICABLE" and rp1 and f["source"]["identity"] != rp1[0]["value"]["id"]: fail(f"checks are read from {f['source']['identity']} but the repository is {rp1[0]['value']['id']} (R17)")
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
        def head_now():
            h = get("head"); return h, (h["value"]["head"] if est(h) else None)
        if act == "merge":
            head, cur = head_now()
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
            head, cur = head_now(); rev = get("review")
            if not (est(rev) and rev["value"]["verdict"] == "CHANGES REQUIRED" and cur and rev["value"]["head"] == cur): fail("repair requires CHANGES REQUIRED on the current HEAD (R15)")
            if not head["value"]["current"]: fail("repair requires the HEAD to be current — a stale HEAD is re-reviewed, not repaired (R15)")
        elif act == "wait-review":
            head, cur = head_now(); rev, chk = get("review"), get("checks")
            no_verdict = not est(rev) or (cur is not None and rev["value"]["head"] != cur)
            pending = (chk is not None and chk["status"] == "UNKNOWN") or (est(chk) and any(r["state"] in ("pending", "missing") for r in chk["value"]["results"]))
            if not (no_verdict or pending): fail("wait-review requires no verdict on the current HEAD or a pending/missing/UNKNOWN required check (R15)")
        elif act == "stop-decision-required":
            # by CONFLICT: every conflicting fact in the set is consulted, and nothing else; by DECISION REQUIRED:
            # the review; by reserved boundary: authority, repository, work unit and the boundary's evidence fact
            conflicts = [x for x in facts if x["status"] == "CONFLICT"]
            b = f["value"]["boundary"]; by_boundary = False; decision = False
            if conflicts:
                for x in conflicts: used.add(x["key"])
                if b != "none": fail("a stop derived from a CONFLICT names no boundary (R15)")
            else:
                rev = get("review") if b == "none" else None
                decision = est(rev) and rev["value"]["verdict"] == "DECISION REQUIRED"
                if not decision and b == "none": fail("stop-decision-required requires a CONFLICT fact, a DECISION REQUIRED verdict, or an applicable reserved boundary (R15)")
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
            if not (conflicts or decision or by_boundary): fail("stop-decision-required requires a CONFLICT fact, a DECISION REQUIRED verdict, or an applicable reserved boundary (R15)")
        else:
            fail(f"action {act} has no derivation rule in this version (R15)")
        missing = used - set(f["inputs"]); extra = set(f["inputs"]) - used
        if missing: fail(f"next_action consulted {sorted(missing)} but does not list them as inputs (R4/R15)")
        if extra: fail(f"next_action lists {sorted(extra)} as inputs but its derivation never consulted them — one conclusion has one representation (R15)")
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
case "$out" in *"snapshots=9 complete=2 "*) ok ;; *) bad "nine examples parsed, two complete snapshots: $out" ;; esac
case "$out" in *"unknown=2 conflict=1 not_applicable=6"*) ok ;; *) bad "examples include exactly two UNKNOWN, one CONFLICT and six NOT_APPLICABLE facts: $out" ;; esac

# ======================== mutation controls: the validator discriminates ========================
base='{"schema_version":"1","key":"review.independent","class":"review","status":"ESTABLISHED","value":{"verdict":"PASS","head":"0123456789abcdef0123456789abcdef01234567","reviewer":"login:github-actions[bot]","record":"github.com/acme/widgets#42/comment/9100"},"source":{"type":"github-api","identity":"github.com/acme/widgets#42/comment/9100","version":"2026-09-06T11:58:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567","comment:github.com/acme/widgets#42/comment/9100"],"provenance":"https://github.com/acme/widgets/pull/42#issuecomment-9100"}'
# m <fact-json> <python-statements> [<arg>] — one fact, mutated: the statements see it as `f` (and the arg as sys.argv[2])
m() { printf '%s' "$1" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$2" "${3:-}"; }
# snap <facts-json> — a complete-snapshot envelope for sets()
snap() { printf '{"complete": true, "facts": %s}' "$1"; }
# rej <fixture-name> <python> <why-it-must-be-rejected> [<arg>]  /  acc <fixture-name> <python> <control-description> [<arg>]
rej() { accepts "$(m "${!1}" "$2" "${4:-}")" && bad "$3" || ok; }
acc() { accepts "$(m "${!1}" "$2" "${4:-}")" && ok || bad "$3"; }
# srej <python over the complete snapshot s> <why>  /  sacc <python> <control-description>
srej() { sets "$(snap "$(smut "$1")")" && bad "$2" || ok; }
sacc() { sets "$(snap "$(smut "$1")")" && ok || bad "$2"; }
accepts() {
  [ -n "$1" ] || { bad "control produced no fact — the mutation itself failed"; return 1; }
  printf '%s' "$1" | python3 "$VAL" "$TSV" "$DOC" one >/dev/null 2>&1
}

# ======================== the matrix: every class × every status ========================
# One canonical fact per cell, built from the rules (not copied from the page): admitted cells must validate,
# excluded cells must be rejected. A contradiction between two rules shows up here as an unsatisfiable cell.
MATRIX="$WORK/matrix.py"
cat > "$MATRIX" <<'PY'
import json, sys
tsv = sys.argv[1]
rows = [l.rstrip("\n").split("\t") for l in open(tsv) if l.strip() and not l.startswith("#")]
admitted = {r[1]: set(r[2].split(",")) for r in rows if r[0] == "class-status"}
key = {r[1]: r[2] for r in rows if r[0] == "key"}
R = "github.com/acme/widgets"; WU = R + "#42"; ISS = R + "#41"; A = "0123456789abcdef0123456789abcdef01234567"; B = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
T = "2026-09-06T12:00:05Z"; ISO = "2026-09-06T11:58:00Z"; C1 = WU + "/comment/9100"; C2 = WU + "/comment/9101"; DEC = R + "#7/comment/9001"; DEC2 = R + "#7/comment/9002"
gh = lambda ident, ver=ISO: {"type": "github-api", "identity": ident, "version": ver}
def fact(cls, status, value, src, inv, detail=None, inputs=None):
    f = {"schema_version": "1", "key": key[cls], "class": cls, "status": status, "source": src, "observed_at": T, "invalidators": inv, "provenance": "https://" + R}
    if status == "ESTABLISHED": f["value"] = value
    if status in ("UNKNOWN", "CONFLICT"): f["detail"] = detail or {"reason": "the source answered 403", "candidates": []}
    if inputs is not None: f["inputs"] = inputs
    return f
def cell(cls, status):
    E, U, C, N = status == "ESTABLISHED", status == "UNKNOWN", status == "CONFLICT", status == "NOT_APPLICABLE"
    conf = lambda a, b: {"reason": "two authoritative reads disagree", "candidates": [a, b]}
    if cls == "work_unit": return fact(cls, status, {"kind": "pull_request", "id": WU, "implements": ISS}, gh(WU), ["pull_request:" + WU], conf(WU, R + "#43") if C else None)
    if cls == "repository": return fact(cls, status, {"id": R, "default_branch": "master"}, gh(R), ["repository:" + R], conf(R, "github.com/acme/program") if C else None)
    if cls == "placement": return fact(cls, status, {"milestone": "none", "release": "none", "gate": "none"}, gh(ISS), ["issue:" + ISS], conf(ISS, R + "#40") if C else None)
    if cls == "graph": return fact(cls, status, {"parent": "none", "children": [], "blocked_by": []}, gh(ISS), ["issue:" + ISS], conf(ISS, R + "#40") if C else None)
    if cls == "authority":
        return fact(cls, status, {"grants": [], "human_boundaries": []}, {"type": "human-decision", "identity": DEC, "version": ISO},
                    ["comment:" + DEC] + (["comment:" + DEC2] if C else []), conf(DEC, DEC2) if C else None)
    if cls == "acceptance":
        if N: return fact(cls, status, None, gh(WU), ["pull_request:" + WU])
        return fact(cls, status, {"contract": ISS, "head": A, "items": []}, gh(ISS), ["issue:" + ISS, "head:" + A], conf(ISS, R + "#40") if C else None)
    if cls == "head":
        if N: return fact(cls, status, None, gh(WU), ["pull_request:" + WU])
        return fact(cls, status, {"head": A, "base_ref": "master", "base": B, "current": True}, gh(WU, A if E else ISO), ["head:" + A, "ref:" + R + "/master"], conf(WU, R + "#43") if C else None)
    if cls == "review":
        if N: return fact(cls, status, None, gh(WU), ["pull_request:" + WU])
        if C: return fact(cls, status, None, gh(WU), ["head:" + A, "comment:" + C1, "comment:" + C2], conf(C1, C2))
        return fact(cls, status, {"verdict": "PASS", "head": A, "reviewer": "login:reviewer", "record": C1}, gh(C1), ["head:" + A, "comment:" + C1])
    if cls == "checks":
        if N: return fact(cls, status, None, gh(WU), ["pull_request:" + WU])
        return fact(cls, status, {"head": A, "required": ["doctor"], "results": [{"name": "doctor", "state": "success"}]}, gh(R, A if E else ISO), ["head:" + A, "ruleset:" + R], conf(R, "github.com/acme/program") if C else None)
    if cls == "next_action":
        src = {"type": "derived", "identity": "fact-model/1", "version": "1;head.exact@" + A}
        return fact(cls, status, {"action": "wait-review", "because": ["head.exact"], "boundary": "none"}, src, ["head:" + A], conf("head.exact", "review.independent") if C else None, inputs=["head.exact"])
    raise SystemExit("no cell for " + cls)
for cls in key:
    for status in ("ESTABLISHED", "UNKNOWN", "CONFLICT", "NOT_APPLICABLE"):
        print("\t".join([cls, status, "admit" if status in admitted[cls] else "exclude", json.dumps(cell(cls, status))]))
PY
while IFS=$'\t' read -r mcls mstatus mexp mjson; do
  if [ "$mexp" = "admit" ]; then
    accepts "$mjson" && ok || bad "matrix: canonical $mstatus $mcls must validate — the rules for this cell contradict each other: $(printf '%s' "$mjson" | python3 "$VAL" "$TSV" "$DOC" one 2>&1 | tail -1)"
  else
    accepts "$mjson" && bad "matrix: $mcls does not admit $mstatus and must reject it (R18)" || ok
  fi
done <<EOF
$(python3 "$MATRIX" "$TSV")
EOF

accepts "$base" && ok || bad "control: the canonical review fact is accepted"
mut() { printf '%s' "$base" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1"; }
rej base 'f["status"]="UNKNOWN"; f["detail"]={"reason":"x","candidates":[]}' "UNKNOWN with a value must be rejected (R6)"
rej base 'f["status"]="UNKNOWN"; del f["value"]' "UNKNOWN without detail must be rejected"
acc base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"the endpoint returned 403","candidates":[]}' "control: an UNKNOWN with a well-shaped detail is accepted"
rej base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]="could not read the review"' "a string detail must be rejected (R14)"
rej base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"x"}' "a detail without candidates must be rejected (R14)"
rej base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"x","candidates":[],"body":"the raw comment"}' "a detail carrying an extra (prose) key must be rejected (R2/R14)"
rej base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"","candidates":[]}' "an empty detail.reason must be rejected (R14)"
rej base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"x","candidates":["the comment the bot left yesterday"]}' "a prose candidate must be rejected (R14)"
rej base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"x","candidates":["github.com/acme/widgets.git#42"]}' "a candidate in a grammar but caught by its constraint (.git) must be rejected (R1/R14)"
acc base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"x","candidates":["github.com/acme/widgets#42","github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:docs/a.md"]}' "control: canonical work-unit and repository-file locators are valid candidates"
rej base 'f["detail"]={"reason":"x","candidates":[]}' "detail on an ESTABLISHED fact must be rejected"
rej base 'f["value"]["record"]="#42"' "a bare #42 must not pass as an identity (R1)"
rej base 'f["key"]="review.cached"' "a key other than the class's canonical key must be rejected (R1)"
rej base 'f["key"]="review.foo"' "an arbitrary <class>.<name> key must be rejected (R1)"
rej base 'f["inferred"]=False' "inferred: false must be rejected (only the literal true is a representation)"
accepts "$(mut 'f["inferred"]="true"')" && bad "inferred: \"true\" (a string) must be rejected" || ok
acc base 'f["inferred"]=True' "control: inferred: true on a non-authority fact is accepted"
rej base 'f["value"]["head"]="0123456"' "an abbreviated commit must be rejected (R1)"
rej base 'f["invalidators"]=["comment:github.com/acme/widgets#42/comment/9100"]' "a HEAD-bound fact without a head: invalidator must be rejected (R7)"
rej base 'f["value"]["verdict"]="APPROVED"' "a verdict outside the closed vocabulary must be rejected"
rej base 'f["schema_version"]="2"' "an unknown schema_version must be rejected (R9)"
rej base 'f["body"]="the whole comment text"' "a raw prose field must be rejected (R2)"
rej base 'f["status"]="CONFLICT"; del f["value"]; f["detail"]={"reason":"x","candidates":["github.com/acme/widgets#42/comment/9100"]}' "a CONFLICT naming one candidate must be rejected (R8)"
rej base 'f["value"]=None' "value: null must not stand in for absence (R6)"
derived='{"schema_version":"1","key":"next_action.governed","class":"next_action","status":"ESTABLISHED","value":{"action":"merge","because":["review.independent"],"boundary":"none"},"source":{"type":"derived","identity":"fact-model/1","version":"1;review.independent@2026-09-06T11:58:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567"],"provenance":"preferences/fact-model.tsv","inputs":["review.independent"]}'
accepts "$derived" && ok || bad "control: a derived fact with inputs is accepted"
rej derived 'del f["inputs"]' "a derived fact without inputs must be rejected (R4)"
rej derived 'f["source"]={"type":"github-api","identity":"github.com/acme/widgets#42","version":"2026-09-06T11:58:00Z"}' "a next_action asserted from a raw read (a valid non-derived source) must be rejected — the class is derived, never asserted (R4/R15)"
rej base 'f["source"]={"type":"derived","identity":"fact-model/1","version":"1;head.exact@0123456789abcdef0123456789abcdef01234567"}; f["inputs"]=["head.exact"]' "a review carrying a derived source must be rejected — a required class is read, never derived (R4)"
rej derived 'f["inputs"]="review.independent"' "inputs as a string must be rejected: the field record says list (R14)"
rej derived 'f["source"]["identity"]="fact-model"' "a derived source identity outside its grammar must be rejected (R14)"
rej derived 'f["source"]["identity"]="fact-model/2"' "a derived identity naming another schema version than the fact's must be rejected (R14)"
rej derived 'f["inputs"]=["review.independent","review.independent"]; f["source"]["version"]="1;review.independent@2026-09-06T11:58:00Z;review.independent@2026-09-06T11:58:00Z"' "a derivation listing one input twice must be rejected (R17)"
rej derived 'f["value"]["because"]=["review.independent","review.independent"]' "a derivation naming one reason twice must be rejected (R17)"
rej derived 'f["source"]["version"]="1;review.independent@2026-09-06T11:58:00Z\n"' "a derived version with a trailing newline must be rejected (whole-string match)"
rej derived 'f["source"]["version"]="1;review.independent@2026-09-06T11:58:00Z\tx"' "a tab inside a derived version must be rejected (whitespace-safe grammar)"
rej derived 'f["source"]["version"]="1"' "a derived version that omits its inputs' versions must be rejected (R4)"
rej derived 'f["source"]["version"]="1;checks.required@x"' "a derived version naming a key that is not an input must be rejected (R4)"
rej base 'f["invalidators"]=["head:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","comment:github.com/acme/widgets#42/comment/9100"]' "a review whose head: invalidator names a different HEAD than its value must be rejected (R7)"
rej base 'f["invalidators"].append("the reviewer changes their mind")' "a prose invalidator must be rejected (R16)"
rej base 'f["invalidators"].append({"kind":"head"})' "an object invalidator must be rejected (R16)"
rej base 'f["invalidators"]=f["invalidators"]*2' "a repeated invalidator must be rejected (R16)"
rej base 'f["invalidators"].append("head:0123456")' "an abbreviated head: invalidator must be rejected (R1/R16)"
rej base 'f["provenance"]="the maintainer approved this in chat"' "prose provenance must be rejected (R16)"
rej base 'f["provenance"]={"url":"https://github.com/acme/widgets/pull/42"}' "an object provenance must be rejected (R16)"
# R7 by status: UNKNOWN binds to the one HEAD it was observed against; NOT_APPLICABLE binds to none
acc base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}' "control: an UNKNOWN review observed against one HEAD is accepted (R7)"
rej base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["invalidators"]=[i for i in f["invalidators"] if not i.startswith("comment:")]' "an UNKNOWN review read from a comment that does not list it must be rejected (R17)"
rej base 'f["status"]="CONFLICT"; del f["value"]; f["source"]["identity"]="github.com/acme/widgets#42"; f["detail"]={"reason":"two trusted verdicts disagree","candidates":["github.com/acme/widgets#42/comment/9300","github.com/acme/widgets#42/comment/9301"]}; f["invalidators"]=["head:0123456789abcdef0123456789abcdef01234567"]' "a CONFLICT review naming two comment candidates but listing neither as an invalidator must be rejected — an edited verdict would not go stale (R17)"
acc base 'f["status"]="CONFLICT"; del f["value"]; f["source"]["identity"]="github.com/acme/widgets#42"; f["detail"]={"reason":"two trusted verdicts disagree","candidates":["github.com/acme/widgets#42/comment/9300","github.com/acme/widgets#42/comment/9301"]}; f["invalidators"]=["head:0123456789abcdef0123456789abcdef01234567","comment:github.com/acme/widgets#42/comment/9300","comment:github.com/acme/widgets#42/comment/9301"]' "control: a CONFLICT review listing both conflicting comments is accepted (Example 4's form)"
rej base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["invalidators"]=["pull_request:github.com/acme/widgets#42"]' "an UNKNOWN HEAD-bound fact with no observed HEAD must be rejected (R7)"
rej base 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["invalidators"].append("head:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")' "an UNKNOWN HEAD-bound fact naming two HEADs is ambiguous and must be rejected (R7)"
acc base 'f["status"]="NOT_APPLICABLE"; del f["value"]; f["source"]["identity"]="github.com/acme/widgets#41"; f["invalidators"]=["issue:github.com/acme/widgets#41"]' "control: a NOT_APPLICABLE review read from its issue and invalidated by it is accepted (R7)"
rej base 'f["status"]="NOT_APPLICABLE"; del f["value"]; f["source"]["identity"]="github.com/acme/widgets#41"; f["invalidators"]=["repository:github.com/acme/widgets"]' "a NOT_APPLICABLE HEAD-bound fact that is not invalidated by its work unit must be rejected — it would never go stale when the issue gains a HEAD (R7/R17)"
rej base 'f["status"]="NOT_APPLICABLE"; del f["value"]; f["invalidators"]=["issue:github.com/acme/widgets#41"]' "a NOT_APPLICABLE HEAD-bound fact read from a comment rather than its work unit must be rejected (R17)"
rej base 'f["status"]="NOT_APPLICABLE"; del f["value"]' "a NOT_APPLICABLE HEAD-bound fact naming a HEAD must be rejected — there is none to be stale against (R7)"
# the TSV is the schema authority: mutate the AUTHORITY and the same fact must fail — proof the validator reads shapes from it
mtsv="$WORK/mutant.tsv"
sed 's/^class\treview\trequired\t{verdict: <verdict>, head: <commit>, reviewer: <login>, record: <comment>}/class\treview\trequired\t{verdict: <verdict>, head: <commit>, reviewer: <login>, record: <comment>, rationale: <text>}/' "$TSV" > "$mtsv"
grep -q 'rationale: <text>' "$mtsv" && ok || bad "control: the mutant authority carries the extra key"
if printf '%s' "$base" | python3 "$VAL" "$mtsv" "$DOC" one >/dev/null 2>&1; then bad "the validator must read value shapes from the authority: a shape with an extra key rejects the old fact" ; else ok; fi
sed 's/^class\treview\trequired\t{verdict: <verdict>, head: <commit>, reviewer: <login>, record: <comment>}/class\treview\trequired\t{verdict: <verdict>, head: <commit>, reviewer: <text>, record: <comment>}/' "$TSV" > "$mtsv"
if m "$base" 'f["value"]["reviewer"]="whoever ran the lane"' | python3 "$VAL" "$mtsv" "$DOC" one >/dev/null 2>&1; then ok; else bad "control: loosening the authority's shape to <text> is honoured by the validator (it reads the TSV)"; fi
sed 's/^field\tobserved_at\trequired\ttimestamp\t/field\tobserved_at\trequired\tlist\t/' "$TSV" > "$mtsv"
grep -q '^field.observed_at.required.list' "$mtsv" && ok || bad "control: the mutant authority retypes observed_at"
if printf '%s' "$base" | python3 "$VAL" "$mtsv" "$DOC" one >/dev/null 2>&1; then bad "the validator must read envelope field types from the authority: retyping observed_at to list rejects the old fact"; else ok; fi
sed 's/^identifier\tlogin\t[^\t]*\t/identifier\tlogin\t^login:[a-z]+$\t/' "$TSV" > "$mtsv"
if printf '%s' "$base" | python3 "$VAL" "$mtsv" "$DOC" one >/dev/null 2>&1; then bad "the validator must read identifier grammars from the authority: a narrowed login grammar rejects github-actions[bot]"; else ok; fi
rej base 'f["source"]["version"]="latest"' "a github-api source version outside its grammar must be rejected (R14)"
rej base 'f["source"]["version"]="9100"' "a numeric node id must not version a mutable github-api node (freshness)"
rej base 'f["source"]["version"]="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"' "a commit version on a HEAD-bound fact that is not its own HEAD must be rejected (R14)"
rej base 'f["provenance"]="https://github.com/acme/widgets/pull/42\t#issuecomment-9100"' "a tab inside provenance must be rejected (whitespace-safe grammar)"
rej base 'f["provenance"]="https://github.com/acme/widgets/pull/42\n"' "a trailing newline in provenance must be rejected (whole-string match)"
rej base 'f["value"]["head"]="0123456789abcdef0123456789abcdef01234567\n"' "a trailing newline on a commit must be rejected (whole-string match)"
rej base 'f["source"]["version"]="2026-09-06T11:58:00Z\n"' "a trailing newline on a source version must be rejected (whole-string match)"
rej base 'f["observed_at"]=["2026-09-06T12:00:05Z"]' "observed_at as a list must be rejected: the field is typed by the timestamp grammar (R14/R18)"
rej base 'f["observed_at"]="yesterday"' "observed_at outside the timestamp grammar must be rejected — the canonical form is data, not prose (R18)"
rej base 'f["observed_at"]="2026-09-06T12:00:05.123Z"' "observed_at with fractional seconds is outside the grammar (R18)"
for ts in '2026-99-99T99:99:99Z' '2026-13-01T00:00:00Z' '2026-00-10T00:00:00Z' '2026-09-06T24:00:00Z' '2026-09-06T12:60:00Z'; do
  rej base "f[\"observed_at\"]=\"$ts\"" "observed_at $ts is outside the calendar ranges the grammar encodes (R18)"
  rej base "f[\"source\"][\"version\"]=\"$ts\"" "a github-api updated_at of $ts is outside the timestamp grammar (R18)"
done
for ts in '2026-02-30T00:00:00Z' '2026-04-31T00:00:00Z' '2025-02-29T00:00:00Z'; do
  rej base "f[\"observed_at\"]=\"$ts\"" "observed_at $ts passes the ranges but is not a real calendar date and must be rejected (R18)"
  rej base "f[\"source\"][\"version\"]=\"$ts\"" "a github-api updated_at of $ts is not a real calendar date (R18)"
done
acc base 'f["observed_at"]="2024-02-29T23:59:59Z"' "control: a leap-day instant at the last second of the day is a real instant"
rej base 'f["schema_version"]="01"' "a schema_version outside the schema-version grammar must be rejected (R18)"
rej base 'f["invalidators"]="head:0123456789abcdef0123456789abcdef01234567"' "invalidators as a string must be rejected: the field record says list (R14)"
rej base 'f["provenance"]=["https://github.com/acme/widgets/pull/42"]' "provenance as a list must be rejected: the field record says string (R14)"
# exact value shapes, recursively (R14): prose keys nested inside values
rej base 'f["value"]["conclusion"]="looks fine"' "an extra key in a review value must be rejected (R14)"
# the source identity is the node the value describes (R17); repository names are one lower-case spelling
rej base 'f["value"]["record"]="github.com/acme/widgets#42/comment/9101"; f["invalidators"].append("comment:github.com/acme/widgets#42/comment/9101")' "a review whose record is not the comment its source names must be rejected (R17)"
rej base 'f["invalidators"]=[i for i in f["invalidators"] if not i.startswith("comment:")]' "a review that does not list its record as a comment: invalidator must be rejected (R17)"
rej base 'f["value"]["record"]="github.com/Acme/Widgets#42/comment/9100"; f["source"]["identity"]=f["value"]["record"]; f["invalidators"]=["head:0123456789abcdef0123456789abcdef01234567","comment:"+f["value"]["record"]]' "a mixed-case owner/name is a projection, never the identity (R1)"
wu='{"schema_version":"1","key":"work_unit.identity","class":"work_unit","status":"ESTABLISHED","value":{"kind":"pull_request","id":"github.com/acme/widgets#42","implements":"github.com/acme/widgets#41"},"source":{"type":"github-api","identity":"github.com/acme/widgets#42","version":"2026-09-06T12:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["pull_request:github.com/acme/widgets#42"],"provenance":"https://github.com/acme/widgets/pull/42"}'
accepts "$wu" && ok || bad "control: a canonical work_unit fact is accepted"
rej wu 'f["source"]["version"]="0123456789abcdef0123456789abcdef01234567"' "a commit cannot version a mutable work_unit node (R14)"
rej wu 'f["value"]["body"]="the PR description"' "work_unit.value.body must be rejected (R2/R14)"
rej wu 'f["value"]["id"]="github.com/acme/widgets#43"' "a work unit whose value names a different node than its source must be rejected (R17)"
rej wu 'f["value"]["kind"]="issue"; f["invalidators"]=["issue:github.com/acme/widgets#42"]' "an issue that claims to implement another issue must be rejected (R17)"
acc wu 'f["value"]["implements"]="none"' "control: a pull request that implements no issue is a valid work unit"
rej wu 'del f["value"]["implements"]' "a work unit without the implements field must be rejected (R14)"
rej wu 'f["value"]["id"]="github.com/Acme/widgets#42"; f["source"]["identity"]=f["value"]["id"]; f["invalidators"]=["pull_request:"+f["value"]["id"]]' "a mixed-case owner in a work-unit id must be rejected (R1)"
rej wu 'f["value"]["id"]="github.com/acme/widgets.git#42"; f["source"]["identity"]=f["value"]["id"]; f["invalidators"]=["pull_request:"+f["value"]["id"]]' "a .git-suffixed repository name is the clone URL's spelling, never the identity (R1)"
rp='{"schema_version":"1","key":"repository.identity","class":"repository","status":"ESTABLISHED","value":{"id":"github.com/acme/widgets","default_branch":"master"},"source":{"type":"github-api","identity":"github.com/acme/widgets","version":"2026-09-01T08:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["repository:github.com/acme/widgets"],"provenance":"https://github.com/acme/widgets"}'
accepts "$rp" && ok || bad "control: a canonical repository fact is accepted"
rej rp 'f["value"]["id"]="github.com/acme/widgets.git"; f["source"]["identity"]=f["value"]["id"]; f["invalidators"]=["repository:"+f["value"]["id"]]' "a repository id ending in .git must be rejected (R1)"
# ETag round trip: a delimiter-safe etag versions a node and is carried inside a derived-version; a ';' etag is outside the grammar
acc rp 'f["source"]["version"]="W/\"a1b2c3d4:e5f6\""' "control: a delimiter-safe etag is a valid github-api version"
rej rp 'f["source"]["version"]="W/\"a1b2;c3d4\""' "an etag containing ';' must be rejected — it could not be carried inside a derived-version (R4/R14)"
acc derived 'f["source"]["version"]="1;review.independent@W/\"a1b2c3d4:e5f6\""' "control: a derived-version carrying an etag input version round-trips"
acc='{"schema_version":"1","key":"acceptance.contract","class":"acceptance","status":"ESTABLISHED","value":{"contract":"github.com/acme/widgets#41","head":"0123456789abcdef0123456789abcdef01234567","items":[{"id":"a1","state":"MET"}]},"source":{"type":"github-api","identity":"github.com/acme/widgets#41","version":"2026-09-05T18:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["issue:github.com/acme/widgets#41","head:0123456789abcdef0123456789abcdef01234567"],"provenance":"https://github.com/acme/widgets/issues/41"}'
accepts "$acc" && ok || bad "control: a canonical acceptance fact is accepted"
rej acc 'f["value"]["items"][0]["summary"]="done, I think"' "acceptance.items[].summary must be rejected (R2/R14)"
rej acc 'del f["value"]["head"]' "an acceptance fact without an explicit HEAD must be rejected (R7)"
rej acc 'f["value"]["contract"]="github.com/acme/widgets#40"' "an acceptance fact whose contract is not the node its source names must be rejected (R17)"
rej acc 'f["invalidators"]=[i for i in f["invalidators"] if not i.startswith("issue:")]' "an acceptance fact that does not list its contract as an invalidator must be rejected — the criteria change without the HEAD moving (R17)"
acc acc 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}' "control: an UNKNOWN acceptance read from its contract and invalidated by it is accepted"
rej acc 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["invalidators"]=[i for i in f["invalidators"] if not i.startswith("issue:")]' "an UNKNOWN acceptance without its contract invalidator must be rejected — the requirement does not wait for ESTABLISHED (R17)"
rej acc 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["source"]["identity"]="github.com/acme/widgets"; f["invalidators"]=["repository:github.com/acme/widgets","head:0123456789abcdef0123456789abcdef01234567"]' "an UNKNOWN acceptance read from a repository rather than its contract must be rejected (R17)"
rej acc 'f["value"]["items"].append({"id":"a1","state":"NOT_MET"})' "duplicate acceptance item ids (one MET, one NOT_MET) must be rejected (R14)"
rej acc 'f["value"]["items"][0]["id"]={"body":"raw prose"}' "an object as an acceptance item id must be rejected (R2/R14)"
rej acc 'f["value"]["items"][0]["id"]=""' "an empty acceptance item id must be rejected (R14)"
rej acc 'f["value"]["items"][0]["id"]="the first criterion, roughly"' "a prose acceptance item id must be rejected (R14)"
auth='{"schema_version":"1","key":"authority.standing","class":"authority","status":"ESTABLISHED","value":{"grants":[{"decision":"github.com/acme/widgets#7/comment/9001","target":"github.com/acme/widgets","scopes":["merge:routine"]}],"human_boundaries":[{"decision":"github.com/acme/widgets#7/comment/9001","target":"github.com/acme/widgets","boundary":"release:approve"}]},"source":{"type":"human-decision","identity":"github.com/acme/widgets#7/comment/9001","version":"2026-09-01T09:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["comment:github.com/acme/widgets#7/comment/9001"],"provenance":"https://github.com/acme/widgets/issues/7"}'
accepts "$auth" && ok || bad "control: a canonical authority fact is accepted"
rej auth 'f["source"]["type"]="github-api"' "authority from a non-human-decision source must be rejected (R5)"
rej auth 'f["invalidators"]=["repository:github.com/acme/widgets"]' "an authority recorded in a comment that does not list that comment as an invalidator must be rejected — an edited decision would never go stale (R17)"
acc auth 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}' "control: an UNKNOWN authority fact from its decision record is accepted"
rej auth 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["inferred"]=True' "an UNKNOWN authority fact marked inferred must be rejected — never inferred, whatever the status (R5)"
rej auth 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["source"]={"type":"github-api","identity":"github.com/acme/widgets#7","version":"2026-09-01T09:00:00Z"}; f["invalidators"]=["issue:github.com/acme/widgets#7"]' "an UNKNOWN authority fact from a non-decision source must be rejected (R5)"
rej auth 'f["value"]["grants"][0]["decision"]="github.com/acme/widgets#7/comment/9002"' "a grant naming a decision the fact's source does not back must be rejected (R5)"
rej auth 'f["value"]["human_boundaries"][0]["decision"]="github.com/acme/widgets#8/comment/9100"' "a boundary naming a decision the fact's source does not back must be rejected (R5)"
rej auth 'f["inferred"]=True' "an inferred authority fact must be rejected (R5)"
for ts in '2026-99-99T99:99:99Z' '2026-02-30T00:00:00Z' '2025-02-29T00:00:00Z'; do
  rej auth "f[\"source\"][\"version\"]=\"$ts\"" "a decision comment's updated_at of $ts is not a real calendar instant (R18)"
done
rej auth 'f["inferred"]=False' "inferred: false on authority must be rejected (never a representation)"
rej auth 'f["source"]["identity"]="role:owner"' "a human-decision source whose identity is a role must be rejected (R5/R14)"
rej auth 'f["source"]["version"]="banana"' "a human-decision source version outside its grammar must be rejected (R14)"
rej auth 'f["source"]["identity"]="the maintainer approved this in chat"' "a human-decision source whose identity is a summary must be rejected (R5/R14)"
rej auth 'f["source"]["version"]="9001"' "a decision recorded in a comment versioned by the comment id must be rejected — comments are edited, ids are not (R14)"
acc auth 'f["source"]["version"]="2026-09-03T10:00:00Z"' "control: an edited decision carries the new updated_at as its version"
# git and repository-file sources: the commit in the identity IS the version observed
hd0='{"schema_version":"1","key":"head.exact","class":"head","status":"ESTABLISHED","value":{"head":"0123456789abcdef0123456789abcdef01234567","base_ref":"master","base":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","current":true},"source":{"type":"github-api","identity":"github.com/acme/widgets#42","version":"0123456789abcdef0123456789abcdef01234567"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567","ref:github.com/acme/widgets/master"],"provenance":"https://github.com/acme/widgets/pull/42/commits"}'
rf='{"schema_version":"1","key":"acceptance.contract","class":"acceptance","status":"ESTABLISHED","value":{"contract":"github.com/acme/widgets#41","head":"0123456789abcdef0123456789abcdef01234567","items":[{"id":"a1","state":"MET"}]},"source":{"type":"repository-file","identity":"github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:docs/acceptance/41.md","version":"0123456789abcdef0123456789abcdef01234567"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567","ref:github.com/acme/widgets/master","issue:github.com/acme/widgets#41"],"provenance":"https://github.com/acme/widgets/blob/0123456789abcdef0123456789abcdef01234567/docs/acceptance/41.md"}'
accepts "$rf" && ok || bad "control: a repository-file source with a path identity is accepted (the grammar is Python-compatible)"
rmut() { printf '%s' "$rf" | python3 -c "import json,sys; f=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(f))" "$1" "${2:-}"; }
rej rf 'f["source"]["version"]="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"' "a repository-file read pinned to commit A claiming version B must be rejected (R14)"
rej rf 'f["source"]["identity"]="github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:docs/with space.md"' "a repository-file path with whitespace is outside the grammar"
rej rf 'f["source"]["identity"]="github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:docs/with\ttab.md"' "a repository-file path with a tab is outside the grammar"
rej rf 'f["source"]["identity"]="github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:docs/acceptance/41.md\n"' "a repository-file identity with a trailing newline must be rejected (whole-string match)"
for pth in '/docs/acceptance/41.md' 'docs/../acceptance/41.md' 'docs//41.md' './41.md' 'docs/./41.md'; do
  accepts "$(rmut 'f["source"]["identity"]="github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567:"+sys.argv[2]' "$pth")" && bad "a non-normalized repository path ($pth) must be rejected — one string per file (R1)" || ok
done
rej base 'f["provenance"]="docs/../reference/fact-model.md"' "a non-normalized repository-relative provenance path must be rejected (R1)"
rej base 'f["provenance"]="/preferences/fact-model.tsv"' "an absolute provenance path must be rejected (R1)"
acc rf 'f["source"]={"type":"git","identity":"github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567","version":"0123456789abcdef0123456789abcdef01234567"}' "control: a git source pinned to a commit with the same version is accepted"
rej rf 'f["source"]={"type":"git","identity":"github.com/acme/widgets@0123456789abcdef0123456789abcdef01234567","version":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}' "a git identity at commit A claiming version B must be rejected (R14)"
acc rf 'f["source"]={"type":"git","identity":"github.com/acme/widgets@ref/master","version":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}' "control: a git ref identity records the commit it pointed at as its version"
acc rf 'f["source"]={"type":"git","identity":"github.com/acme/widgets@ref/release/v1.2.x","version":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}' "control: a dotted, slashed branch embedded in a git identity is accepted"
for r in 'refs/heads/master' 'foo..bar' 'a@{b}' 'master.lock' 'foo.lock/bar' 'trail.' '@'; do
  accepts "$(rmut 'f["source"]={"type":"git","identity":"github.com/acme/widgets@ref/"+sys.argv[2],"version":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}' "$r")" && bad "a non-canonical ref ($r) embedded in a git identity must be rejected (R1)" || ok
  accepts "$(m "$hd0" 'f["invalidators"][1]="ref:github.com/acme/widgets/"+sys.argv[2]' "$r")" && bad "a non-canonical ref ($r) embedded in a ref: invalidator must be rejected (R1)" || ok
done
rej auth 'del f["value"]["grants"][0]["target"]' "a grant without an applicability target must be rejected (R14)"
rej auth 'f["value"]["grants"][0]["target"]="this repository and its forks"' "a prose grant target must be rejected (R14)"
rej auth 'f["value"]["grants"][0]["decision"]="approved by the owner"' "a grant whose decision is not a durable record must be rejected (R5)"
rej auth 'f["value"]["grants"][0]["scopes"]=["routine merge of a green PR"]' "a prose scope must be rejected (R13)"
rej auth 'f["value"]["human_boundaries"][0]["boundary"]="release approval"' "a prose boundary must be rejected (R13)"
rej auth 'f["value"]["human_boundaries"]=["release:approve"]' "a bare-token boundary without decision and target must be rejected (R13/R14)"
rej auth 'f["value"]["human_boundaries"][0]["target"]="everywhere"' "a prose boundary target must be rejected (R14)"
rej auth 'f["value"]["grants"][0]["scopes"]=[]' "a grant with no scopes must be rejected (R13)"
chk='{"schema_version":"1","key":"checks.required","class":"checks","status":"ESTABLISHED","value":{"head":"0123456789abcdef0123456789abcdef01234567","required":["doctor","tests"],"results":[{"name":"doctor","state":"success"},{"name":"tests","state":"success"}]},"source":{"type":"github-api","identity":"github.com/acme/widgets","version":"0123456789abcdef0123456789abcdef01234567"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567","ruleset:github.com/acme/widgets"],"provenance":"https://github.com/acme/widgets/commit/0123456789abcdef0123456789abcdef01234567/checks"}'
accepts "$chk" && ok || bad "control: a covered checks fact is accepted"
rej chk 'f["value"]["results"]=f["value"]["results"][:1]' "a required check with no result must be rejected (R12)"
rej chk 'f["value"]["results"][1]["state"]="green"' "a check state outside the vocabulary must be rejected (R12)"
rej chk 'f["value"]["results"][1]["conclusion"]="success"' "checks.results[].conclusion (an undeclared nested key) must be rejected (R14)"
rej chk 'f["value"]["results"].append({"name":"tests","state":"failure"})' "a duplicate check result must be rejected (R12)"
rej chk 'f["source"]["identity"]="github.com/acme/widgets#42"' "checks read from something other than a repository must be rejected (R17)"
rej chk 'f["invalidators"]=[i for i in f["invalidators"] if not i.startswith("ruleset:")]' "checks without the repository's ruleset: invalidator must be rejected — required checks change with the rulesets (R17)"
rej chk 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["invalidators"]=[i for i in f["invalidators"] if not i.startswith("ruleset:")]' "an UNKNOWN checks fact without its ruleset: invalidator must be rejected — the requirement does not wait for ESTABLISHED (R17)"
acc chk 'f["status"]="NOT_APPLICABLE"; del f["value"]; f["source"]["identity"]="github.com/acme/widgets#41"; f["source"]["version"]="2026-09-05T18:00:00Z"; f["invalidators"]=["issue:github.com/acme/widgets#41"]' "control: NOT_APPLICABLE checks are read from the work unit and invalidated by it, like every HEAD-bound class (R7/R17)"
rej chk 'f["status"]="NOT_APPLICABLE"; del f["value"]; f["invalidators"]=["ruleset:github.com/acme/widgets"]' "NOT_APPLICABLE checks in the repository-and-ruleset form must be rejected — one canonical representation (R7/R17)"
gr='{"schema_version":"1","key":"graph.native","class":"graph","status":"ESTABLISHED","value":{"parent":{"kind":"issue","id":"github.com/acme/widgets#40","state":"open"},"children":[],"blocked_by":[{"kind":"issue","id":"github.com/acme/widgets#39","state":"closed"}]},"source":{"type":"github-api","identity":"github.com/acme/widgets#41","version":"2026-09-06T11:00:00Z"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["issue:github.com/acme/widgets#41","issue:github.com/acme/widgets#40","issue:github.com/acme/widgets#39"],"provenance":"https://github.com/acme/widgets/issues/41"}'
accepts "$gr" && ok || bad "control: a graph fact with relationship states is accepted"
rej gr 'f["value"]["blocked_by"]=[{"kind":"issue","id":"github.com/acme/widgets#39"}]' "a relationship without state must be rejected"
rej gr 'f["value"]["parent"]["state"]="done"' "a relationship state outside the vocabulary must be rejected"
rej gr 'f["source"]["identity"]="github.com/acme/widgets"' "a graph read from a repository rather than a work-unit node must be rejected (R17)"
rej gr 'f["invalidators"]=["issue:github.com/acme/widgets#40","issue:github.com/acme/widgets#39"]' "a graph that does not list the node it was read from as an invalidator must be rejected (R17)"
rej gr 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["invalidators"]=["issue:github.com/acme/widgets#40"]' "an UNKNOWN graph that does not list the node it was read from must be rejected (R17)"
rej gr 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["source"]["identity"]="github.com/acme/widgets"; f["invalidators"]=["repository:github.com/acme/widgets"]' "an UNKNOWN graph read from a repository rather than a work-unit node must be rejected (R17)"
acc gr 'f["status"]="UNKNOWN"; del f["value"]; f["detail"]={"reason":"403","candidates":[]}; f["invalidators"]=["issue:github.com/acme/widgets#41"]' "control: an UNKNOWN graph read from and invalidated by its work unit is accepted"
rej gr 'f["invalidators"]=[i for i in f["invalidators"] if not i.endswith("#39")]' "a graph representing blocker #39 without listing it as an invalidator must be rejected — its state can change without the parent changing (R17)"
rej gr 'f["invalidators"]=[i for i in f["invalidators"] if not i.endswith("#40")]' "a graph representing parent #40 without listing it must be rejected (R17)"
# head: the base ref is a freshness dependency the value implies
# ref grammar: one spelling of a branch; refs/heads/…, empty or dotted components, .. and .lock are rejected
for r in 'refs/heads/master' '/' 'foo//bar' 'foo..bar' 'master.lock' '.hidden' 'feat/' '/feat' 'a/.b' 'a b' 'a~b' 'a^b' 'a:b' 'a?b' 'a*b' 'a[b' 'a\\b' 'a@{b}' 'trail.' '@' 'foo.lock/bar' "$(printf 'a\001b')" "$(printf 'a\177b')"; do
  accepts "$(m "$hd0" 'f["value"]["base_ref"]=sys.argv[2]; f["invalidators"][1]="ref:github.com/acme/widgets/"+sys.argv[2]' "$r")" && bad "ref spelling '$r' must be rejected — one canonical branch name (R1)" || ok
done
acc hd0 'f["value"]["base_ref"]="release/v1.2.x"; f["invalidators"][1]="ref:github.com/acme/widgets/release/v1.2.x"' "control: a dotted, slashed branch name is a valid ref"
for r in 'feat/x+y' 'user@host' 'a#b' 'x=1' 'ünïcode'; do
  accepts "$(m "$hd0" 'f["value"]["base_ref"]=sys.argv[2]; f["invalidators"][1]="ref:github.com/acme/widgets/"+sys.argv[2]' "$r")" && ok || bad "control: valid Git branch name '$r' is a valid ref"
done
hd='{"schema_version":"1","key":"head.exact","class":"head","status":"ESTABLISHED","value":{"head":"0123456789abcdef0123456789abcdef01234567","base_ref":"master","base":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","current":true},"source":{"type":"github-api","identity":"github.com/acme/widgets#42","version":"0123456789abcdef0123456789abcdef01234567"},"observed_at":"2026-09-06T12:00:05Z","invalidators":["head:0123456789abcdef0123456789abcdef01234567","ref:github.com/acme/widgets/master"],"provenance":"https://github.com/acme/widgets/pull/42/commits"}'
accepts "$hd" && ok || bad "control: a head fact listing its HEAD and base ref is accepted"
rej hd 'f["invalidators"]=["head:0123456789abcdef0123456789abcdef01234567"]' "a head fact without ref:<repository>/<base_ref> must be rejected — the base moves without the HEAD moving (R17)"
rej hd 'f["invalidators"][1]="ref:github.com/acme/widgets/main"' "a head fact whose ref: invalidator names a different branch than base_ref must be rejected (R17)"
rej gr 'f["value"]["blocked_by"].append({"kind":"issue","id":"github.com/acme/widgets#39","state":"open"})' "one blocker listed as both closed and open must be rejected (R14)"
rej gr 'f["value"]["children"]=[{"kind":"issue","id":"github.com/acme/widgets#42","state":"open"},{"kind":"issue","id":"github.com/acme/widgets#42","state":"open"}]; f["invalidators"].append("issue:github.com/acme/widgets#42")' "a child listed twice must be rejected (R14)"
rej gr 'del f["value"]["parent"]["kind"]' "a relationship without its kind must be rejected — the kind fixes the one canonical invalidator (R14/R17)"
rej gr 'f["value"]["parent"]["kind"]="pull_request"' "a relationship whose kind disagrees with its invalidator token must be rejected (R17)"
rej gr 'f["invalidators"].append("pull_request:github.com/acme/widgets#39")' "one node listed under both kinds must be rejected — one canonical token (R17)"
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
sets "$(snap "$full")" && ok || bad "control: the page's complete snapshot is accepted as a snapshot"
# R15 controls: the complete snapshot derives merge; break one condition at a time and the derivation must be rejected
smut() { printf '%s' "$full" | python3 -c "import json,sys; s=json.load(sys.stdin); exec(sys.argv[1]); print(json.dumps(s))" "$1"; }
srej 'nx=[f for f in s if f["class"]=="checks"][0]; nx["value"]["results"][1]["state"]="failure"' "merge with a failed required check must be rejected (R15)"
srej 'nx=[f for f in s if f["class"]=="review"][0]; nx["value"]["verdict"]="CHANGES REQUIRED"' "merge with a CHANGES REQUIRED review must be rejected (R15)"
srej 'nx=[f for f in s if f["class"]=="acceptance"][0]; nx["value"]["items"][0]["state"]="NOT_MET"' "merge with an unmet acceptance item must be rejected (R15)"
srej 'nx=[f for f in s if f["class"]=="head"][0]; nx["value"]["current"]=False' "merge on a HEAD that is not current must be rejected (R15)"
srej 'h=[f for f in s if f["class"]=="head"][0]; h["source"]["identity"]="github.com/acme/widgets#43"' "a head read from a different node than the set's work unit must be rejected (R17)"
srej 'r=[f for f in s if f["class"]=="repository"][0]; r["value"]["id"]="github.com/acme/program"; r["source"]["identity"]="github.com/acme/program"; r["invalidators"]=["repository:github.com/acme/program"]' "a work unit from one repository spliced with another repository's facts must be rejected (R17)"
srej 'a=[f for f in s if f["class"]=="acceptance"][0]; a["value"]["contract"]="github.com/acme/widgets#40"; a["source"]["identity"]="github.com/acme/widgets#40"; a["invalidators"]=["issue:github.com/acme/widgets#40"]+[i for i in a["invalidators"] if not i.startswith("issue:")]' "acceptance judged against an unrelated issue's contract must be rejected — merge may not rest on it (R17)"
unk_acc='a=[f for f in s if f["class"]=="acceptance"][0]; a["status"]="UNKNOWN"; del a["value"]; a["detail"]={"reason":"403","candidates":[]}; n=[f for f in s if f["class"]=="next_action"][0]; n["value"]={"action":"wait-review","because":["acceptance.contract"],"boundary":"none"}; n["inputs"]=["acceptance.contract","head.exact","review.independent","checks.required"]; n["source"]["version"]="1;"+";".join(k+"@"+[f for f in s if f["key"]==k][0]["source"]["version"] for k in sorted(n["inputs"]))'
sets "$(printf '{"complete": false, "facts": %s}' "$(smut "$unk_acc"'; s[:]=[f for f in s if f["class"]!="next_action"]')")" && ok || bad "control: an UNKNOWN acceptance read from the implemented issue is accepted in a set"
sets "$(printf '{"complete": false, "facts": %s}' "$(smut "$unk_acc"'; s[:]=[f for f in s if f["class"]!="next_action"]; a["source"]["identity"]="github.com/acme/widgets#40"; a["invalidators"]=["issue:github.com/acme/widgets#40"]+[i for i in a["invalidators"] if not i.startswith("issue:")]')")" && bad "an UNKNOWN acceptance read from an unrelated issue must be rejected in a set — the binding does not wait for ESTABLISHED (R17)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(smut "$unk_acc"'; s[:]=[f for f in s if f["class"]!="next_action"]; a["status"]="CONFLICT"; a["detail"]={"reason":"two reads disagree","candidates":["github.com/acme/widgets#40","github.com/acme/widgets#39"]}; a["source"]["identity"]="github.com/acme/widgets#40"; a["invalidators"]=["issue:github.com/acme/widgets#40"]+[i for i in a["invalidators"] if not i.startswith("issue:")]')")" && bad "a CONFLICT acceptance read from an unrelated issue must be rejected in a set (R17)" || ok
srej 'c=[f for f in s if f["class"]=="checks"][0]; c["source"]["identity"]="github.com/acme/program"; c["invalidators"]=[i for i in c["invalidators"] if not i.startswith("ruleset:")]+["ruleset:github.com/acme/program"]' "checks read from a different repository than the set's must be rejected (R17)"
srej 'p=[f for f in s if f["class"]=="placement"][0]; p["invalidators"]=[i for i in p["invalidators"] if not i.startswith("issue:")]' "a placement that does not list the node it was read from must be rejected (R17)"
srej 'p=[f for f in s if f["class"]=="placement"][0]; p["source"]["identity"]="github.com/acme/widgets#40"; p["invalidators"]=["issue:github.com/acme/widgets#40"]+[i for i in p["invalidators"] if not i.startswith("issue:")]' "a placement read from a node that is neither the work unit nor the issue it implements must be rejected (R17)"
srej 'g=[f for f in s if f["class"]=="graph"][0]; g["source"]["identity"]="github.com/acme/widgets#40"; g["invalidators"]=["issue:github.com/acme/widgets#40"]+[i for i in g["invalidators"] if i!="issue:github.com/acme/widgets#41"]' "a graph spliced in from an unrelated node must be rejected (R17)"
srej 'w=[f for f in s if f["class"]=="work_unit"][0]; w["value"]["implements"]="none"' "with no declared implements, placement and graph read from another issue must be rejected (R17)"
# merge consults the native graph: an open blocker, an unreadable graph, or a derivation that omits it is rejected
srej 'g=[f for f in s if f["class"]=="graph"][0]; g["value"]["blocked_by"][0]["state"]="open"' "merge while a native blocker is open must be rejected (R15)"
srej 'p=[f for f in s if f["class"]=="placement"][0]; p["invalidators"]=["pull_request:" + i.split(":",1)[1] if i.startswith("issue:github.com/acme/widgets#41") else i for i in p["invalidators"]]' "a placement naming the implemented issue under pull_request: must be rejected — the set knows its kind (R17)"
# a stop derived from a CONFLICT consults only the conflicting fact, whether or not a head fact is present in the set
conflict_stop='r=[f for f in s if f["class"]=="review"][0]; r["status"]="CONFLICT"; del r["value"]; r["detail"]={"reason":"two trusted verdicts disagree","candidates":["github.com/acme/widgets#42/comment/9100","github.com/acme/widgets#42/comment/9101"]}; r["invalidators"]=[i for i in r["invalidators"] if i.startswith("head:")]+["comment:github.com/acme/widgets#42/comment/9100","comment:github.com/acme/widgets#42/comment/9101"]; n=[f for f in s if f["class"]=="next_action"][0]; n["value"]={"action":"stop-decision-required","because":["review.independent"],"boundary":"none"}; n["inputs"]=["review.independent"]; n["source"]["version"]="1;review.independent@"+r["source"]["version"]'
sets "$(snap "$(smut "$conflict_stop")")" && ok || bad "control: in a complete snapshot, a stop derived from a CONFLICT lists exactly the conflicting fact as its input (R15)"
sets "$(snap "$(smut "$conflict_stop"'; h=[f for f in s if f["class"]=="head"][0]; n["inputs"]=["head.exact","review.independent"]; n["source"]["version"]="1;head.exact@"+h["source"]["version"]+";review.independent@"+r["source"]["version"]')")" && bad "a conflict stop that lists the unrelated head as an input must be rejected — HEAD is consulted only by derivations that depend on it (R15)" || ok
# a CONFLICT in any class — not only review — derives the stop, with exactly that fact as the input
for cls in acceptance authority placement; do
  conflict_other='c=[f for f in s if f["class"]=="'"$cls"'"][0]; c["status"]="CONFLICT"; del c["value"]; c["detail"]={"reason":"two authoritative reads disagree","candidates":["github.com/acme/widgets#41","github.com/acme/widgets#40"]}; n=[f for f in s if f["class"]=="next_action"][0]; n["value"]={"action":"stop-decision-required","because":[c["key"]],"boundary":"none"}; n["inputs"]=[c["key"]]; n["source"]["version"]="1;"+c["key"]+"@"+c["source"]["version"]'
  sets "$(snap "$(smut "$conflict_other")")" && ok || bad "control: a stop derived from a CONFLICT in $cls lists exactly that fact (R15)"
done
srej 'c=[f for f in s if f["class"]=="acceptance"][0]; c["status"]="CONFLICT"; del c["value"]; c["detail"]={"reason":"x","candidates":["github.com/acme/widgets#41","github.com/acme/widgets#40"]}; r=[f for f in s if f["class"]=="review"][0]; n=[f for f in s if f["class"]=="next_action"][0]; n["value"]={"action":"stop-decision-required","because":["acceptance.contract"],"boundary":"none"}; n["inputs"]=["acceptance.contract","review.independent"]; n["source"]["version"]="1;acceptance.contract@"+c["source"]["version"]+";review.independent@"+r["source"]["version"]' "a conflict stop listing the non-conflicting review as an input must be rejected (R15)"
srej 'g=[f for f in s if f["class"]=="graph"][0]; g["status"]="UNKNOWN"; del g["value"]; g["detail"]={"reason":"403","candidates":[]}' "merge while the dependency graph is UNKNOWN must be rejected (R15)"
srej 'nx=[f for f in s if f["class"]=="next_action"][0]; nx["inputs"]=[i for i in nx["inputs"] if i!="graph.native"]; nx["source"]["version"]=";".join(p for p in nx["source"]["version"].split(";") if not p.startswith("graph.native@"))' "a merge derivation that omits the consulted graph from its inputs must be rejected (R4/R15)"
# repair needs a CURRENT head: the page's Example 2 derives repair; make its HEAD stale and it must be rejected
ex2="$(python3 - "$DOC" <<'PY'
import json, re, sys
t = open(sys.argv[1]).read()
m = re.search(r"^### Example 2 — [^\n]*\(fragment\)\n.*?```json\n(.*?)\n```", t, flags=re.S | re.M)
print(json.dumps(json.loads(m.group(1))))
PY
)"
printf '%s' "$ex2" | grep -q '"action": "repair"' && ok || bad "control: Example 2 derives repair"
# the complete issue snapshot (Example 9): every required class, HEAD-bound ones NOT_APPLICABLE; minus one class it is no snapshot
ex9="$(python3 - "$DOC" <<'PY'
import json, re, sys
t = open(sys.argv[1]).read()
m = re.search(r"^### Example 9 — [^\n]*\(complete snapshot\)\n.*?```json\n(.*?)\n```", t, flags=re.S | re.M)
print(json.dumps(json.loads(m.group(1))))
PY
)"
sets "$(snap "$ex9")" && ok || bad "control: the complete snapshot of an issue with no HEAD is accepted (all nine required classes)"
sets "$(snap "$(printf '%s' "$ex9" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps([f for f in s if f["class"]!="checks"]))')")" && bad "the issue snapshot without its NOT_APPLICABLE checks fact is not complete (R11)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$ex2")" && ok || bad "control: the page's repair fragment is accepted"
sets "$(printf '{"complete": false, "facts": %s}' "$(printf '%s' "$ex2" | python3 -c 'import json,sys; s=json.load(sys.stdin); n=[f for f in s if f["class"]=="next_action"][0]; c=[f for f in s if f["class"]=="checks"][0]; n["inputs"].append("checks.required"); n["source"]["version"]="1;"+";".join(k+"@"+[f for f in s if f["key"]==k][0]["source"]["version"] for k in sorted(n["inputs"])); print(json.dumps(s))')")" && bad "a repair derivation listing an input it never consulted (checks) must be rejected — one conclusion, one representation (R15)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(printf '%s' "$ex2" | python3 -c 'import json,sys; s=json.load(sys.stdin); h=[f for f in s if f["class"]=="head"][0]; h["value"]["current"]=False; print(json.dumps(s))')")" && bad "repair on a HEAD that is not current must be rejected — a stale HEAD is re-reviewed, not repaired (R15)" || ok
srej 'nx=[f for f in s if f["class"]=="authority"][0]; nx["value"]["grants"][0]["scopes"]=["close:issue"]' "merge without a merge:routine grant must be rejected (R15)"
srej 'nx=[f for f in s if f["class"]=="authority"][0]; nx["value"]["grants"][0]["target"]="github.com/acme/program"' "merge with a grant targeting another repository must be rejected (R15)"
# a reserved boundary that applies here blocks merge: add placement:release for this repository and place the work in a release
smerge_boundary='a=[f for f in s if f["class"]=="authority"][0]; a["value"]["human_boundaries"].append({"decision": a["source"]["identity"], "target": "github.com/acme/widgets", "boundary": "placement:release"}); p=[f for f in s if f["class"]=="placement"][0]; p["value"]["release"]="v1.2.0"'
sets "$(snap "$(smut "$smerge_boundary")")" && bad "merge while a targeted placement:release boundary applies (the work is in a release) must be rejected (R15)" || ok
sacc 'a=[f for f in s if f["class"]=="authority"][0]; a["value"]["human_boundaries"].append({"decision": a["source"]["identity"], "target": "github.com/acme/widgets", "boundary": "placement:release"})' "control: the same boundary with no release placement does not block merge (its evidence does not hold)"
srej 'a=[f for f in s if f["class"]=="authority"][0]; a["value"]["human_boundaries"].append({"decision": a["source"]["identity"], "target": "github.com/acme/widgets", "boundary": "placement:release"}); p=[f for f in s if f["class"]=="placement"][0]; p["status"]="UNKNOWN"; del p["value"]; p["detail"]={"reason":"403","candidates":[]}' "merge while the targeted boundary's evidence fact is UNKNOWN must be rejected — it cannot be shown not to apply (R15)"
srej 'nx=[f for f in s if f["class"]=="next_action"][0]; nx["inputs"]=[i for i in nx["inputs"] if i!="placement.current"]; nx["source"]["version"]=";".join(p for p in nx["source"]["version"].split(";") if not p.startswith("placement.current@"))' "a merge derivation that omits the consulted boundary-evidence fact (placement) from its inputs must be rejected (R4/R15)"
srej 'nx=[f for f in s if f["class"]=="next_action"][0]; nx["inputs"]=[i for i in nx["inputs"] if i!="repository.identity"]; nx["source"]["version"]=";".join(p for p in nx["source"]["version"].split(";") if not p.startswith("repository.identity@"))' "a merge derivation that omits a consulted fact (repository) from its inputs must be rejected (R4/R15)"
rej derived 'f["value"]["action"]="close"' "an action outside the v1 vocabulary (close) must be rejected"
rej derived 'del f["value"]["boundary"]' "a next_action without the boundary field must be rejected (R14)"
rej derived 'f["value"]["boundary"]="placement:release"' "a merge resting on a reserved boundary must be rejected (R15)"
rej derived 'f["value"]["boundary"]="release placement"' "a prose boundary on next_action must be rejected (R13)"
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
sets "$(snap "$(printf '%s' "$full" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps([f for f in s if f["class"]!="authority"]))')")" && bad "a snapshot lacking a required class must be rejected (R11)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(printf '%s' "$full" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps(s+[s[0]]))')")" && bad "a set repeating a class must be rejected (R11)" || ok
sets "$(printf '{"complete": false, "facts": %s}' "$(printf '%s' "$full" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps([f for f in s if f["class"] not in ("authority","next_action")]))')")" && ok || bad "control: a subset with no dangling derived inputs is a valid fragment when not claimed complete"
sets "$(printf '{"complete": false, "facts": %s}' "$(printf '%s' "$full" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(json.dumps([f for f in s if f["class"]!="authority"]))')")" && bad "a fragment whose derived fact names an absent input must be rejected (R4)" || ok

finish "fact model (#731)"
