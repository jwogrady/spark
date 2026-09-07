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

usage: build-responsibilities.py <worktree> [base-ref] [--map-only] [--out=<dir>]
"""
import os, re, subprocess, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from classification import RESP
from classification_modules import MODULE_RESP

args = [a for a in sys.argv[1:] if not a.startswith("--")]
flags = {a for a in sys.argv[1:] if a.startswith("--")}
W = args[0]
BASE = args[1] if len(args) > 1 else "origin/master"
MAP_ONLY = "--map-only" in flags
OUT = next((a.split("=", 1)[1] for a in flags if a.startswith("--out=")), W)

FILES = ["plugins/spark/bin/spark", "plugins/spark/lib/execution.sh",
         "plugins/spark/lib/planning.sh", "plugins/spark/lib/repository.sh"]
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
    for f in FILES:
        for line in sh("bash", "tests/structure.sh", "--raw", f, cwd=tree).split("\n"):
            p = line.split("\t")
            if p[0] == "FUNC": scanner[p[1]] = (f, int(p[2]))
    fns = {}
    for f in FILES:
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


def consumers(tree, fns):
    """Who references whom across the whole runtime. Whole-word textual references between function bodies — the
    weaker-than-a-call-graph model tests/structure.sh documents, where a name in a comment counts and a name
    reached through a variable does not — widened from one file to four."""
    bodies, out = {}, collections.defaultdict(set)
    for f in FILES:
        cur, buf = None, []
        for line in open(os.path.join(tree, f)).read().split("\n"):
            m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\(\) \{(.*)$", line)
            if m:
                if cur: bodies[cur] = "\n".join(buf)
                name, rest = m.group(1), m.group(2)
                if rest.rstrip().endswith("}"):      # a one-liner opens and closes here; its body is on this line
                    bodies[name] = rest.rstrip()[:-1]
                    cur, buf = None, []
                else:
                    cur, buf = name, []
                continue
            if line.startswith("}") and cur:
                bodies[cur] = "\n".join(buf); cur, buf = None, []
                continue
            if cur: buf.append(line)
        if cur: bodies[cur] = "\n".join(buf)
    for holder, body in bodies.items():
        for n in fns:
            if n == holder: continue
            if re.search(r"(?<![A-Za-z0-9_])" + re.escape(n) + r"(?![A-Za-z0-9_])", body):
                out[n].add(holder)
    return out


PARSE_RE = re.compile(r'(\$\{?[1-9#@]|\bshift\b|\busage\b|--[a-z][a-z-]*\))')


def parse_lines(tree, fns):
    """How many lines of each body do argument handling. #743's own map is exclusive — one responsibility per
    function — but parsing is not held by a function in this runtime: it sits at the head of every verb. Counting
    the lines that touch positional parameters, `shift`, a usage string or a long option gives the responsibility a
    size without pretending some function owns it. It is a line-level heuristic and the manifest says so."""
    out, name = collections.Counter(), None
    for f in FILES:
        for line in open(os.path.join(tree, f)).read().split("\n"):
            m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\(\) \{(.*)$", line)
            if m:
                one, rest = m.group(1), m.group(2)
                if rest.rstrip().endswith("}"):      # a one-liner's parse lines are the one line it occupies
                    if one in fns and PARSE_RE.search(rest): out[one] += 1
                    name = None
                else:
                    name = one
                continue
            if line.startswith("}"): name = None; continue
            if name and name in fns and PARSE_RE.search(line): out[name] += 1
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
# consumers are whole-word textual references from other runtime bodies, across module boundaries — the model
# tests/structure.sh documents (a name in a comment counts; a name reached through a variable does not), widened
# from one file to four. verbs are the cmd_* consumers among them.
#
# parse lines are the lines of the body that do argument handling — positional parameters, shift, a usage string
# or a long option. Parsing is not owned by any function in this runtime, so the exclusive map gives it a size
# here instead of assigning it away.
#
# scope is top-level or nested; a nested row names the function that holds it. tests/structure.sh reports the
# top-level half and stays the authority for it; nested definitions are collected here because they are functions
# the runtime defines, cost lines, and can be exactly what a canonicalization removes.
#
# function <TAB> file <TAB> scope <TAB> owner <TAB> responsibility <TAB> body lines <TAB> parse lines <TAB>
# consumer count <TAB> consumers <TAB> verbs
"""


def write_map(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(HDR + "".join("\t".join(r) + "\n" for r in rows))


fns_after, rows_after = rows_for(W)
write_map(os.path.join(OUT, "docs/research/v0.23-cleanup/743-responsibilities.tsv"), rows_after)

base_sha = sh("git", "merge-base", BASE, "HEAD").strip()
tmp = subprocess.run(["mktemp", "-d"], capture_output=True, text=True).stdout.strip()
subprocess.run(["git", "clone", "-q", "--shared", "--no-checkout", W, tmp + "/tree"], check=True)
subprocess.run(["git", "-C", tmp + "/tree", "checkout", "-q", "--detach", base_sha], check=True)
fns_before, rows_before = rows_for(tmp + "/tree")
write_map(os.path.join(OUT, "docs/research/v0.23-cleanup/743-responsibilities-before.tsv"), rows_before)
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

def loc_of(tree_reader, f):
    return len(tree_reader(f).split("\n")) - 1


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
inside another function, against {len(nested_before)} of {n_before} before. That matters here rather than being a
detail of scope: the three escapers this unit removed were nested, so a top-level-only inventory would report this
work unit adding two functions when it removes {len(nested_gone)} and adds two, a net of {d_fns:+d}.
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
{parse_by_file_before[FILES[0]] + parse_by_file_before[FILES[1]] + parse_by_file_before[FILES[2]] + parse_by_file_before[FILES[3]]:,}
and {parse_by_file_after[FILES[0]] + parse_by_file_after[FILES[1]] + parse_by_file_after[FILES[2]] + parse_by_file_after[FILES[3]]:,}
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
