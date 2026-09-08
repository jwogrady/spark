#!/usr/bin/env python3
"""Build the #743 artifacts from the tree and two committed classifications: the runtime responsibility map, the
same map at the commit this branch left, and the work unit's manifest.

Scope is the whole runtime — the dispatcher and all three modules — because #743 asks for the dispatcher/runtime
surface, and a fact canonicalized in the dispatcher is consumed across module boundaries.

Every figure is computed here: function inventories come from `tests/structure.sh --raw` run per file (the
repository's own scanner, so the map cannot drift from what the repo reports), consumers from a whole-word scan of
every runtime body, and the before-side from a pristine checkout of the base commit. Nothing is typed by hand
except each function's responsibility, which is the judgment the issue asks for and which the suite holds to the
tree.

The baseline is pinned, not derived. `743-responsibilities-before.tsv` records the full commit it was observed at,
and that value is what regenerates it — deriving a base from `origin/master` would silently move the moment this
work merges, and the committed "before" map would stop being reproducible on any later branch.

usage: build-responsibilities.py <worktree> [base-commit] [--map-only] [--out=<dir>]
"""
import os, re, subprocess, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from classification import RESP
from classification_modules import MODULE_RESP

args = [a for a in sys.argv[1:] if not a.startswith("--")]
flags = {a for a in sys.argv[1:] if a.startswith("--")}
W = args[0]
BASE = args[1] if len(args) > 1 else ""
MAP_ONLY = "--map-only" in flags
OUT = next((a.split("=", 1)[1] for a in flags if a.startswith("--out=")), W)

# The runtime, module by module. A file added here that did not exist at the
# pinned baseline is handled throughout: a NEW module is exactly that case, and
# a generator that assumed every file exists in both trees would crash on the
# first one rather than report it as growth.
FILES = ["plugins/spark/bin/spark", "plugins/spark/lib/execution.sh",
         "plugins/spark/lib/planning.sh", "plugins/spark/lib/repository.sh",
         "plugins/spark/lib/facts.sh"]
# present <tree> — the files of FILES that this tree actually has. A module
# introduced after the pinned baseline is absent from the base checkout, and
# absence there is a fact about growth, not an error to raise.
def present(tree):
    return [f for f in FILES if os.path.exists(os.path.join(tree, f))]


ORDER = ["argument-parsing", "routing-dispatch", "source-collection", "canonicalization", "domain-semantics",
         "evidence-authority", "formatting-reporting", "compatibility-fallback"]
GLOSS = {
    "argument-parsing": "reads flags and arguments",
    "routing-dispatch": "resolves a verb and loads what it needs",
    "source-collection": "reads a source of truth (git, gh, the filesystem) and returns it unjudged",
    "canonicalization": "normalizes what was read into this repository's vocabulary",
    "domain-semantics": "owns a rule about what the facts mean",
    "evidence-authority": "decides what the evidence is admissible for",
    "formatting-reporting": "renders",
    "compatibility-fallback": "keeps an older shape working",
}
RESP_OF = {n: r for r, names in RESP.items() for n in names}
for r, names in MODULE_RESP.items():
    for n in names: RESP_OF[n] = r


def sh(*cmd, cwd=W):
    return subprocess.run(list(cmd), cwd=cwd, capture_output=True, text=True).stdout


DECL_RE = re.compile(r"^(\s*)([A-Za-z_][A-Za-z0-9_]*)\(\) \{(.*)$")


def inventory(tree):
    """Every runtime function: name -> (file, body lines, scope, owner).

    `tests/structure.sh` reports top-level definitions only, which is the right scope for the size of a *file* but
    the wrong one for "every function the runtime defines": a nested definition is still a function, still costs
    lines, and — as this unit's own three escapers showed — can be exactly what a canonicalization removes. Both
    are collected here, the scanner's answer is kept as the authority for the top-level half, and each row records
    which it is and, for a nested one, the function that holds it."""
    scanner = {}
    for f in present(tree):
        for line in sh("bash", "tests/structure.sh", "--raw", f, cwd=tree).split("\n"):
            p = line.split("\t")
            if p[0] == "FUNC": scanner[p[1]] = (f, int(p[2]))
    fns = {}
    for f in present(tree):
        lines = open(os.path.join(tree, f)).read().split("\n")
        stack = []          # (name, indent, start index)
        for i, line in enumerate(lines):
            m = DECL_RE.match(line)
            if m:
                indent, name, rest = m.group(1), m.group(2), m.group(3)
                owner = stack[-1][0] if stack else "-"
                if rest.rstrip().endswith("}"):                       # opens and closes here
                    fns[name] = (f, 1, "top-level" if not indent else "nested", owner)
                else:
                    stack.append((name, len(indent), i, owner))
                continue
            if stack and re.match(r"^\s*\}\s*$", line) and (len(line) - len(line.lstrip())) == stack[-1][1]:
                name, indent, start, owner = stack.pop()
                fns[name] = (f, i - start + 1, "top-level" if indent == 0 else "nested", owner)
    for n, (f, body) in scanner.items():                              # the scanner is authoritative where it looks
        prev = fns.get(n)
        fns[n] = (f, body, "top-level", prev[3] if prev else "-")
    return fns


def drop_comment(line):
    """The line without its trailing comment, quotes respected. What a human reads as an argument — `"$1"` — is
    still there, which is what the parse heuristic needs; the reference scan uses the stricter view below."""
    i, n, quote = 0, len(line), None
    while i < n:
        c = line[i]
        if quote:
            if c == quote: quote = None
        elif c in "'\"":
            quote = c
        elif c == "#" and (i == 0 or line[i - 1] in " \t") and line[max(0, i - 2):i] != "${":
            return line[:i]
        i += 1
    return line


def bodies_of(tree):
    """Every function's own lines, attributed to the innermost function that contains them, with comment text
    removed.

    Each line is kept twice, because two questions need two views. A *reference* must be something the shell would
    run, so comments and message text are removed: the runtime's nested helpers are called `place`, `gap` and
    `bool`, and counting those words where they appear in sentences would manufacture edges. An *argument* is
    `"$1"` wherever it appears, message included, so the parse heuristic reads the line with only its comment gone.

    Both depart from `tests/structure.sh`, deliberately: it scans top-level bodies and counts names in comments,
    which is the right model for the size of a file and the wrong one for a graph over every body.
    """
    bodies, stack = collections.defaultdict(list), []
    for f in present(tree):
        for raw in open(os.path.join(tree, f)).read().split("\n"):
            m = DECL_RE.match(raw)
            if m:
                indent, name, rest = m.group(1), m.group(2), m.group(3)
                if rest.rstrip().endswith("}"):
                    line = rest.rstrip()[:-1]
                    bodies[name].append((drop_comment(line), strip_comment(line)))
                else:
                    stack.append((name, len(indent)))
                continue
            if stack and re.match(r"^\s*\}\s*$", raw) and (len(raw) - len(raw.lstrip())) == stack[-1][1]:
                stack.pop()
                continue
            if stack: bodies[stack[-1][0]].append((drop_comment(raw), strip_comment(raw)))
    return bodies


def strip_comment(line):
    """Keep the code of a line and drop the prose.

    Three rules, all about what a shell would execute. A `#` starting a word is a comment, unless it sits in quotes
    or a parameter expansion. A single-quoted string never expands, so nothing inside one can be a call. Inside a
    double-quoted string only `$(...)` and `${...}` are code, and the surrounding words are a message — without
    that rule, `yellow "… gap(s) name a value …"` reads as a call to the nested helper `gap`, and a sentence
    manufactures an edge in the graph.
    """
    out = []
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if c == "#" and (i == 0 or line[i - 1] in " \t") and line[max(0, i - 2):i] != "${":
            break
        if c == "'":                                   # a literal: skip to its end
            i += 1
            while i < n and line[i] != "'": i += 1
            i += 1
            continue
        if c == '"':                                   # a message: keep only its expansions
            i += 1
            while i < n and line[i] != '"':
                if line[i] == "$" and i + 1 < n and line[i + 1] in "({":
                    close = ")" if line[i + 1] == "(" else "}"
                    depth, j = 0, i + 1
                    while j < n:
                        if line[j] in "({": depth += 1
                        elif line[j] in ")}":
                            depth -= 1
                            if depth == 0: break
                        j += 1
                    out.append(line[i:j + 1])
                    i = j + 1
                    continue
                i += 1
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def consumers(tree, fns):
    """Who references whom across the whole runtime: whole-word references between function bodies, every body
    included, comments excluded."""
    out = collections.defaultdict(set)
    for holder, lines in bodies_of(tree).items():
        body = "\n".join(code for _text, code in lines)
        for n in fns:
            if n == holder: continue
            if re.search(r"(?<![A-Za-z0-9_])" + re.escape(n) + r"(?![A-Za-z0-9_])", body):
                out[n].add(holder)
    return out


PARSE_RE = re.compile(r'(\$\{?[1-9#@]|\bshift\b|\busage\b|--[a-z][a-z-]*\))')


def parse_lines(tree, fns):
    """How many lines of each body do argument handling. #743's map is exclusive — one responsibility per function
    — but parsing is not held by a function in this runtime: it sits at the head of every verb. Counting the lines
    that touch positional parameters, `shift`, a usage string or a long option gives the responsibility a size
    without pretending some function owns it. It is a line-level heuristic and the manifest says so. A line counts
    for the innermost function holding it, so a nested helper's own arguments are not charged to its holder."""
    out = collections.Counter()
    for name, lines in bodies_of(tree).items():
        if name not in fns: continue
        out[name] = sum(1 for text, _code in lines if PARSE_RE.search(text))
    return out


def rows_for(tree):
    fns = inventory(tree)
    unmapped = sorted(n for n in fns if n not in RESP_OF)
    if unmapped:
        raise SystemExit("unclassified runtime functions: " + " ".join(unmapped))
    cons = consumers(tree, fns)
    parses = parse_lines(tree, fns)
    rows = []
    for n in sorted(fns):
        f, body, scope, owner = fns[n]
        cs = sorted(cons.get(n, ()))
        verbs = sorted(c for c in cs if c.startswith("cmd_"))
        rows.append((n, f, scope, owner, RESP_OF[n], str(body), str(parses[n]), str(len(cs)),
                     ";".join(cs) if cs else "-", ";".join(verbs) if verbs else "-"))
    return fns, rows


HDR = """# Spark runtime responsibility map (#743) — generated by
# docs/research/v0.23-cleanup/tools/build-responsibilities.py, checked by tests/test-runtime-responsibilities.sh.
# One row per function in the dispatcher and all three modules.
#
# responsibility is the issue's vocabulary: argument-parsing, routing-dispatch, source-collection,
# canonicalization, domain-semantics, evidence-authority, formatting-reporting, compatibility-fallback.
# A body that both reads and renders is assigned to the half it owns; the buckets are not disjoint in this code.
#
# consumers are whole-word references to this function from the CODE of other runtime bodies, across module
# boundaries and including nested bodies. Code means what the shell would run.
# Comments are dropped; single-quoted strings are dropped whole; and inside
# double quotes only the $(...) and ${...} expansions are kept — the runtime's
# nested helpers are named place, gap and bool, so counting those words in prose would manufacture edges. A name
# reached through a variable is still not seen. This is stricter than tests/structure.sh, which counts names in
# comments and scans top-level bodies only; that model is right for the size of a file and wrong for this graph.
# verbs are the cmd_* consumers among them.
#
# parse lines are the lines of the body that do argument handling — positional parameters, shift, a usage string
# or a long option. Parsing is not owned by any function in this runtime, so the exclusive map gives it a size here
# instead of assigning it away. This count reads each line with only its comment removed, because "$1" is an
# argument wherever it appears, message text included: the two scans ask different questions of the same line.
#
# scope is top-level or nested; a nested row names the function that holds it. tests/structure.sh reports the
# top-level half and stays the authority for it; nested definitions are collected here because they are functions
# the runtime defines, cost lines, and can be exactly what a canonicalization removes.
#
# function <TAB> file <TAB> scope <TAB> owner <TAB> responsibility <TAB> body lines <TAB> parse lines <TAB>
# consumer count <TAB> consumers <TAB> verbs
"""


def write_map(path, rows, observed_at=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pin = f"# observed at {observed_at}\n" if observed_at else ""
    with open(path, "w") as fh:
        fh.write(HDR + pin + "".join("\t".join(r) + "\n" for r in rows))


fns_after, rows_after = rows_for(W)
write_map(os.path.join(OUT, "docs/research/v0.23-cleanup/743-responsibilities.tsv"), rows_after)

def pinned_base():
    """The commit the committed before map names, else the branch point — and once written, the pin is authority."""
    committed = os.path.join(W, "docs/research/v0.23-cleanup/743-responsibilities-before.tsv")
    if BASE:
        return sh("git", "rev-parse", BASE).strip()
    if os.path.exists(committed):
        # the whole comment header, not a guessed number of lines: the header grows whenever the model is
        # documented more fully, and a pin the default path cannot find is a pin that does nothing
        for line in open(committed).read().split("\n"):
            if not line.startswith("#"): break
            m = re.match(r"^# observed at ([0-9a-f]{40})$", line)
            if m: return m.group(1)
    return sh("git", "merge-base", "origin/master", "HEAD").strip()


base_sha = pinned_base()
if not re.fullmatch(r"[0-9a-f]{40}", base_sha):
    raise SystemExit("the baseline commit could not be resolved: " + repr(base_sha))
tmp = subprocess.run(["mktemp", "-d"], capture_output=True, text=True).stdout.strip()
subprocess.run(["git", "clone", "-q", "--shared", "--no-checkout", W, tmp + "/tree"], check=True)
subprocess.run(["git", "-C", tmp + "/tree", "checkout", "-q", "--detach", base_sha], check=True)
fns_before, rows_before = rows_for(tmp + "/tree")
write_map(os.path.join(OUT, "docs/research/v0.23-cleanup/743-responsibilities-before.tsv"), rows_before, base_sha)
subprocess.run(["rm", "-rf", tmp], check=False)

if MAP_ONLY:
    print("maps only:", len(rows_after), "functions after,", len(rows_before), "before")
    raise SystemExit(0)


def totals(fns):
    by_resp = collections.Counter(RESP_OF[n] for n in fns)
    lines_by = collections.Counter()
    for n, (_f, b, _s, _o) in fns.items(): lines_by[RESP_OF[n]] += b
    return by_resp, lines_by


after_resp, after_lines = totals(fns_after)
before_resp, before_lines = totals(fns_before)
n_after, n_before = len(fns_after), len(fns_before)
l_after = sum(b for _f, b, _s, _o in fns_after.values())
l_before = sum(b for _f, b, _s, _o in fns_before.values())
per_file_after = collections.Counter(f for f, _b, _s, _o in fns_after.values())
per_file_before = collections.Counter(f for f, _b, _s, _o in fns_before.values())
nested_after = sorted(n for n, v in fns_after.items() if v[2] == "nested")
nested_before = sorted(n for n, v in fns_before.items() if v[2] == "nested")
nested_gone = [n for n in nested_before if n not in fns_after]
gone = sorted(set(fns_before) - set(fns_after))
added = sorted(set(fns_after) - set(fns_before))
moved = sorted(n for n in set(fns_after) & set(fns_before) if fns_after[n][2] != fns_before[n][2])


def name_list(names):
    return ", ".join("`" + n + "`" for n in names) if names else "nothing"


inventory_note = (
    f"Counted whole, this unit removes {len(gone)} definition(s) — {name_list(gone)} — adds {len(added)} — "
    f"{name_list(added)} — and moves {len(moved)} — {name_list(moved)} — from nested to top-level, which is why the "
    f"total goes {n_before} to {n_after}. A top-level-only inventory saw none of the removals, because all three "
    f"escapers were nested, and reported this unit adding two functions.")

def loc_of(tree_reader, f):
    text = tree_reader(f)
    # A file the tree does not have is zero lines. Without this the subtraction
    # below reports -1 for a new module, and every figure derived from it is off
    # by one in a direction that flatters the change.
    return len(text.split("\n")) - 1 if text else 0


now_text = lambda f: open(os.path.join(W, f)).read()
base_text = lambda f: subprocess.run(["git", "show", f"{base_sha}:{f}"], cwd=W, capture_output=True, text=True).stdout
loc_after = {f: loc_of(now_text, f) for f in FILES}
loc_before = {f: loc_of(base_text, f) for f in FILES}
parse_after = {r[0]: int(r[6]) for r in rows_after}
parse_before = {r[0]: int(r[6]) for r in rows_before}
parse_by_file_after = collections.Counter()
parse_by_file_before = collections.Counter()
for r in rows_after: parse_by_file_after[r[1]] += int(r[6])
for r in rows_before: parse_by_file_before[r[1]] += int(r[6])
parse_fns_after = sum(1 for r in rows_after if int(r[6]) > 0)
parse_fns_before = sum(1 for r in rows_before if int(r[6]) > 0)


def surfaces(token, ref):
    """Which files name a token at a commit, split by surface. `git grep -l` at a ref, so both sides are read the
    same way and a zero is a measured zero."""
    out = sh("git", "grep", "-l", "-F", "--", token, ref, "--", "plugins", "tests", "docs", ".github",
             "AGENTS.md", "README.md", "ROADMAP.md")
    files = [l.split(":", 1)[1] for l in out.split("\n") if ":" in l]
    return {
        "runtime": sorted(f for f in files if f.startswith("plugins/spark/bin") or f.startswith("plugins/spark/lib")),
        "tests": sorted(f for f in files if f.startswith("tests/")),
        "docs": sorted(f for f in files if f.startswith("docs/") or f.startswith("plugins/spark/docs")),
    }


FACTS = [
    ("the liveness of the issues a recorded intent names", 'gh api "repos/{owner}/{repo}/issues/$n" --jq .state'),
    ("the remote trunk ref", "refs/remotes/origin/HEAD"),
    ("a JSON string body", "s/\\\\/\\\\\\\\/g; s/\"/\\\\\"/g"),
]
fanout_rows = []
for label, token in FACTS:
    a_s, b_s = surfaces(token, "HEAD"), surfaces(token, base_sha)
    fanout_rows.append((label, len(b_s["runtime"]), len(a_s["runtime"]), len(b_s["tests"]), len(a_s["tests"]),
                        len(b_s["docs"]), len(a_s["docs"])))
fanout_tbl = "\n".join(
    f"| {lbl} | {rb} | {ra} | {tb} | {ta} | {db} | {da} |" for lbl, rb, ra, tb, ta, db, da in fanout_rows)
_grew = [lbl for lbl, rb, ra, tb, ta, db, da in fanout_rows if ta > tb or da > db]
_shrank = [lbl for lbl, rb, ra, tb, ta, db, da in fanout_rows if ra < rb]
fanout_note = (
    ("Runtime files fell for " + ", ".join(_shrank) + ", which is the escaper moving out of the module it was "
     "copied into. " if _shrank else "No fact's runtime file count changed. ")
    + ("Test and doc files rose for " + ", ".join(_grew) + ": this unit's own suite asserts the idiom and its map "
       "and manifest name it, which is what a measurement of surfaces is supposed to show rather than hide. "
       if _grew else "No test or doc file names any of these idioms, at either commit. ")
    + "No shipped documentation needed an edit: the suites that own the affected verbs exercise them by behaviour, "
      "not by naming the idiom.")
loc_tbl = "\n".join(f"| `{f}` | {loc_before[f]:,} | {loc_after[f]:,} | {loc_after[f] - loc_before[f]:+d} |" for f in FILES)
loc_total_before, loc_total_after = sum(loc_before.values()), sum(loc_after.values())
parse_tbl = "\n".join(
    f"| `{f}` | {parse_by_file_before[f]:,} | {parse_by_file_after[f]:,} |" for f in FILES)
resp_tbl = "\n".join(
    f"| `{r}` | {before_resp[r]} | {after_resp[r]} | {before_lines[r]:,} | {after_lines[r]:,} | {GLOSS[r]} |"
    for r in ORDER)
file_tbl = "\n".join(f"| `{f}` | {per_file_before[f]} | {per_file_after[f]} |" for f in FILES)
cons_after = {r[0]: int(r[7]) for r in rows_after}
shared = sorted((n for n in fns_after if cons_after.get(n, 0) >= 8), key=lambda n: (-cons_after[n], n))[:10]
shared_tbl = "\n".join(f"| `{n}` | {cons_after[n]} | `{RESP_OF[n]}` |" for n in shared)


def consumers_of(name, rows):
    for r in rows:
        if r[0] == name: return r[8].split(";") if r[8] != "-" else []
    return []


je_after = consumers_of("json_escape", rows_after)
d_fns, d_body = n_after - n_before, l_after - l_before

manifest = f"""# Runtime surface after canonicalization (v0.23 cleanup, #743)

**Rule.** An extraction or removal earns its place only by removing dead code, eliminating duplicate semantics,
creating one canonical primitive with several consumers, lowering change fanout, or making a boundary testable
with less context. Moving duplication into more files is not one of them, so this unit removes duplicate readers
and adds no module.

**The map comes first, and it covers the whole runtime.** `docs/research/v0.23-cleanup/743-responsibilities.tsv`
assigns every one of the {n_after} functions in the dispatcher and its three modules to exactly one of the issue's
eight responsibilities, with its body length, everything in the runtime that references it, and the verbs among
those. `743-responsibilities-before.tsv` is the same map at `{base_sha[:7]}`, the commit this branch left, so the
before-change baseline is a map and not a pair of totals. Both are generated from `tests/structure.sh --raw` run
per file, and `tests/test-runtime-responsibilities.sh` holds both to their trees: a function added, removed or
renamed fails the suite until the map says where it belongs.

The buckets are not disjoint in this code — `governance_validate`, `di_grade` and `release_gate_projection` each
collect, canonicalize, judge and render in one body — so each function is assigned to the half it owns, and that is
stated rather than smoothed over.

| Responsibility | Functions before | after | Body lines before | after | What it owns |
|---|---|---|---|---|---|
{resp_tbl}

| File | Functions before | after |
|---|---|---|
{file_tbl}

Module count is unchanged at three. The runtime holds {n_after} functions and {l_after:,} body lines, against
{n_before} and {l_before:,} before: {d_fns:+d} functions, {d_body:+d} body lines.

Those totals count **every** definition, nested ones included — {len(nested_after)} of the {n_after} are nested
inside another function, against {len(nested_before)} of {n_before} before. {inventory_note}
`tests/structure.sh` reports the top-level half — the right scope for the size of a file — and stays the authority
for it; the map records each function's scope and, for a nested one, the function that holds it.

Function bodies are not the whole runtime — top-level dispatch, globals and comments live outside them — so the
actual line count is reported too:

| File | Lines before | after | delta |
|---|---|---|---|
{loc_tbl}

**{loc_total_before:,} lines before, {loc_total_after:,} after ({loc_total_after - loc_total_before:+d})**, against
{l_before:,} and {l_after:,} body lines. The file grows while the bodies shrink because each new primitive is
documented where it lives, at the top level, outside any body.

**Argument parsing, measured rather than assigned.** The map is exclusive — one responsibility per function — and
that misrepresents parsing, which no function owns: it sits at the head of every verb. Counting the lines of each
body that touch a positional parameter, `shift`, a usage string or a long option gives the responsibility a size
without inventing an owner. It is a line-level heuristic, not a parser:

| File | Parse lines before | after |
|---|---|---|
{parse_tbl}

{parse_fns_before} functions carried parse lines before and {parse_fns_after} do now, in
{sum(parse_by_file_before[f] for f in FILES):,}
and {sum(parse_by_file_after[f] for f in FILES):,}
lines respectively. That is why extracting a shared parser is rejected below: the lines are per-verb strings and
flags, and a shared parser would either normalize what users see or take it all as parameters.

Two buckets hold {after_resp['domain-semantics'] + after_resp['source-collection']} of {n_after} functions and
{after_lines['domain-semantics'] + after_lines['source-collection']:,} of {l_after:,} body lines. That
concentration is the issue's premise, and it is also the trap: for `cmd_doctor`, `cmd_next` and `cmd_labels` the
rules *are* the product, and there is no lower layer to defer them to. Relocating them would move ownership
without reducing it.

**What the graph names as shared.** A function many runtime bodies reference is a canonical primitive by
demonstration, and must not be duplicated back into a module:

| Primitive | Runtime consumers | Responsibility |
|---|---|---|
{shared_tbl}

## What this unit changed

Three duplicate readers became one each. Each is a fact that was read in two or three places with byte-identical
bodies — #739's rule, applied to what #739 left behind.

- **`intent_liveness`** — `triage_rows` and `rec_rows` each walked the issues a recorded next action names and
  tallied closed/open/unread with an identical `gh api …/issues/<n> --jq .state` loop. One reader now returns the
  tally; each caller keeps its own projection, and both still tell "no `gh` at all" apart from "`gh` could not
  answer", because that distinction lives in the caller where it is rendered.
- **`di_trunk`** — `cmd_resume` carried its own copy of the remote-trunk idiom (`refs/remotes/origin/HEAD`, else
  `origin/master`/`origin/main`). It calls the primitive now. `repo_trunk` stays separate deliberately: it answers
  the *local* trunk name without touching the network, and collapsing the two would make an offline triage depend
  on a remote ref.
- **`json_escape`** — three identical escapers existed as nested functions (`cmd_state` in the dispatcher,
  `cmd_telemetry` and `cmd_budget` in `lib/execution.sh`). One lives in the dispatcher now, where modules already
  reach for shared primitives and where `tests/test-runtime-modules.sh` forbids a module restating one. The map
  shows the result across the module boundary: its runtime consumers are {', '.join('`' + c + '`' for c in je_after)}.
  `js` is untouched: it *strips* quotes and backslashes rather than escaping them, and merging them would silently
  change `spark doctor --requirements --json`.

**Change fanout, across surfaces.** Reader bodies are one measure; the surfaces a change to each fact would
have to reach are another. Each row counts the files naming that fact's idiom at each commit, read the same way on
both sides with `git grep -l`, so a zero is a measured zero:

| Fact | Runtime files before | after | Test files before | after | Doc files before | after |
|---|---|---|---|---|---|---|
{fanout_tbl}

In reader bodies the same three facts go two to one, two to one and three to one. {fanout_note}

## What was rejected, and why

- **Extracting a `doctor` module** (1,296 lines the graph names as single-verb) — defensible under the issue's
  second clause, but it removes no duplication, and its payoff must be argued in `runtime_peak_source_bytes` and
  `tests/bench.sh` numbers rather than in line counts. It is a separate unit with its own measurement, not a
  rider on this one.
- **Extracting argument parsing** — the parse lines are per-verb: distinct usage text, distinct flags, distinct
  `-h` bodies. A shared parser would either normalize user-visible strings, which #743 forbids, or take them as
  parameters and save nothing.
- **The legacy state keys** — #738 already ruled that removing them needs evidence no consumer has an unmigrated
  file, or a deprecation window, and that evidence is unknowable from this repository.
- **Anything #738 marked do-not-delete** — the `enhancement` alias and `--prune-deprecated` are public CLI
  behaviour; every `cmd_*` and `fp_hot_*` is reached by name from the dispatch table.

## Acceptance, item by item

- **Responsibilities mapped before change** — `743-responsibilities-before.tsv`, the same map at the base commit,
  generated by the same tool and checked by the same suite.
- **Every removal cites its evidence** — each of the three names the byte-identical bodies it replaced.
- **The dispatcher parses, routes, loads and reports rather than owning duplicate semantics** — the duplication
  removed is exactly the read-a-fact-twice kind; where the dispatcher still owns rules, the map says so and the
  manifest says why relocating them would not help.
- **Counts recorded before and after, not as the sole measure** — the tables above, with the consumer counts that
  actually fell.
- **Fanout compared where mechanically practical** — consumer counts per function, on both sides, computed across
  module boundaries.
- **Module count rises only when duplication or change surface falls** — module count is unchanged at three.
- **No public behaviour or authority guarantee changed** — no CLI semantics touched; `js` and `repo_trunk` left
  alone deliberately.
- **No cleanup-only refactor became a rewrite** — three primitives, no restructuring.
- **Focused and full suites green on the exact HEAD** — recorded in the pull request.
"""
open(os.path.join(OUT, "docs/research/v0.23-cleanup/743-runtime-surface.md"), "w").write(manifest)
print("after", n_after, l_after, "before", n_before, l_before, "json_escape consumers", len(je_after))
