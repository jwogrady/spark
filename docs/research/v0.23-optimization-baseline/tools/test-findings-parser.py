#!/usr/bin/env python3
"""test-findings-parser.py — discriminating fixtures for findings_parser.extract. Exit non-zero on any failure.
Each fixture is shaped like a real reviewer comment; the expected counts are known by construction."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from findings_parser import extract, list_items, reviewer_section

def hdr(v, head="a" * 40): return f"<!-- spark-openai-review pr=1 head={head} verdict={v} -->\n## Reviewer verdict: {v}\n\nChanges are required on this exact HEAD. Do not merge.\n"
FOOT = "\n_Independent reviewer for HEAD `" + "a" * 40 + "`. It cannot edit code, push, merge, or assign roadmap metadata._\n"
fails = 0
def check(name, cond, detail=""):
    global fails
    print(("ok   " if cond else "FAIL ") + name + (f"  {detail}" if detail and not cond else ""))
    if not cond: fails += 1

# 1. hyphen bullets with sub-bullets, internal blank line and a trailing reviewer paragraph
b1 = hdr("CHANGES REQUIRED") + "\n---\n\nCHANGES REQUIRED\n\nIntro sentence.\n\n- `a.sh:1` — first finding:\n  - sub one\n  - sub two\n  \n  Validate it.\n- `b.sh:2` — second finding.\n\nTrailer guidance paragraph, not a finding.\n\n---\n" + FOOT
k, bl = extract(b1, "CHANGES REQUIRED")
check("hyphen: kind findings", k == "findings")
check("hyphen: two findings, trailer excluded", len(bl) == 2, str(len(bl)))
check("hyphen: first block keeps sub-bullets and blank line", "sub two" in bl[0] and "Validate it." in bl[0])
check("hyphen: blocks verbatim", all(b in b1 for b in bl))

# 2. ORDERED-LIST findings with indented sub-bullets, no --- fences (relayed shape), trailing unindented prose
b2 = hdr("CHANGES REQUIRED") + "\nCHANGES REQUIRED\n\nThe repair is directionally correct.\n\n1. **First.** Detail one.\n\n2. **Second.** Detail two. Either:\n   - option a, or\n   - option b.\n\nKeep the stronger result. Do not optimize further.\n\n#480 remains RED.\n" + FOOT
k, bl = extract(b2, "CHANGES REQUIRED")
check("ordered: kind findings", k == "findings")
check("ordered: two findings", len(bl) == 2, str(len(bl)))
check("ordered: second keeps its sub-options", "option b." in bl[1])
check("ordered: trailer prose excluded", not any("Do not optimize" in b for b in bl))
check("ordered: verbatim", all(b in b2 for b in bl))

# 3. PROSE/CODE-ONLY CHANGES REQUIRED (no list items at all) -> exactly one whole-section finding
b3 = hdr("CHANGES REQUIRED") + "\nOne narrow correctness issue remains. Do not merge.\n\n`count()` currently ends with:\n\n```sh\n... | grep -cv X || echo 0\n```\n\nWith pipefail the zero path prints two zeros. Emit exactly one integer.\n\n#480 remains RED.\n" + FOOT
k, bl = extract(b3, "CHANGES REQUIRED")
check("prose: kind prose", k == "prose")
check("prose: exactly one finding", len(bl) == 1, str(len(bl)))
check("prose: block carries the code fence", "grep -cv X" in bl[0] and "exactly one integer" in bl[0])
check("prose: verbatim", bl[0] in b3)
check("prose: envelope lines excluded", "_Independent reviewer" not in bl[0] and "## Reviewer verdict" not in bl[0])

# 4. PASS with bullets -> evidence, zero findings
b4 = "<!-- spark-openai-review pr=1 head=" + "b" * 40 + " verdict=PASS -->\n## Reviewer verdict: PASS\n\n**READY FOR GOVERNED CLOSE-OUT.** Nothing blocking was found.\n\n---\n\nPASS\n\n- positive fact one.\n- positive fact two.\n\n---\n" + FOOT
k, bl = extract(b4, "PASS")
check("pass: kind evidence", k == "evidence")
check("pass: two evidentiary bullets recorded, not findings", len(bl) == 2)

# 5. CRLF body -> same result, blocks verbatim against the normalized body
b5 = b1.replace("\n", "\r\n")
k, bl = extract(b5, "CHANGES REQUIRED")
check("crlf: two findings", len(bl) == 2)
check("crlf: verbatim against normalized body", all(b in b5.replace("\r\n", "\n") for b in bl))

# 6. discrimination: a parser that only sees `- ` would return 0 for fixture 2 and 3
check("discriminates ordered vs hyphen", len(list_items("1. a\n2. b\n")) == 2 and len(list_items("- a\n- b\n")) == 2)
check("section recovery without fences drops envelope", "Reviewer verdict" not in reviewer_section(hdr("CHANGES REQUIRED") + "\nbody text\n" + FOOT))

print("RESULT", "OK" if fails == 0 else f"FAIL ({fails})")
sys.exit(1 if fails else 0)
