#!/usr/bin/env python3
"""findings_parser.py — the one parser for reviewer-comment bodies (imported by analyze-pr.py and its fixtures).

A reviewer comment is: an HTML marker line, a "## Reviewer verdict" heading, a standard sentence, then the
reviewer's own section, then a trailer line beginning with `_Independent reviewer`. Usually the section is
fenced by `---` lines; the relayed comments are not always fenced, so the section is recovered by stripping the
known envelope lines when fewer than two fences exist.

Findings are the section's TOP-LEVEL LIST ITEMS — hyphen bullets (`- `) or ordered items (`1. `) — each taken as
its whole block (continuation lines, indented sub-items, internal blank lines) until the next top-level item; a
blank line followed by unindented prose ends the list. A CHANGES REQUIRED section with no list items is ONE
prose/code finding: the entire section, verbatim. Bullets in a PASS comment are EVIDENCE, not findings.
Every returned block is a verbatim substring of the (CRLF-normalized) body."""
import re

MARKER = re.compile(r"<!-- spark-openai-review pr=(\d+) head=([0-9a-f]{40}) verdict=(PASS|CHANGES REQUIRED|DECISION REQUIRED|NOT ASSESSED) -->")
TOP = re.compile(r"^(- |\d+\. )")
ENVELOPE = (re.compile(r"^<!-- spark-openai-review .* -->$"), re.compile(r"^## Reviewer verdict: "),
            re.compile(r"^Changes are required on this exact HEAD\."), re.compile(r"^\*\*Stopping for @"),
            re.compile(r"^\*\*READY FOR GOVERNED CLOSE-OUT\.\*\*"), re.compile(r"^_Independent reviewer for "),
            re.compile(r"^(PASS|CHANGES REQUIRED|DECISION REQUIRED|NOT ASSESSED)$"))

def normalize(body):
    return body.replace("\r\n", "\n")

def reviewer_section(body):
    """The reviewer's own text: between the first and last `---` fence when there are two or more fences,
    otherwise the body minus the known envelope lines. Always a verbatim substring (or verbatim line subset)."""
    segs = body.split("\n---\n")
    if len(segs) >= 3:
        return "\n".join(segs[1:-1])
    lines = [ln for ln in body.split("\n") if not any(rx.match(ln) for rx in ENVELOPE)]
    return "\n".join(lines).strip("\n")

def list_items(section):
    items = []; cur = None; held = []
    for ln in section.split("\n"):
        if TOP.match(ln):
            if cur is not None: items.append("\n".join(cur).rstrip())
            cur = [ln]; held = []
        elif cur is None:
            continue
        elif ln.strip() == "":
            held.append(ln)
        elif ln[0] in " \t":
            cur.extend(held); cur.append(ln); held = []
        else:
            if held: items.append("\n".join(cur).rstrip()); cur = None; held = []
            else: cur.append(ln)
    if cur is not None: items.append("\n".join(cur).rstrip())
    return items

def extract(body, verdict):
    """-> (kind, blocks): kind is 'findings' (blocking list items), 'prose' (one whole-section finding),
    or 'evidence' (PASS bullets — not findings). Blocks are verbatim substrings of the normalized body."""
    body = normalize(body)
    section = reviewer_section(body)
    items = list_items(section)
    if verdict == "PASS":
        blocks = items
        kind = "evidence"
    elif items:
        blocks, kind = items, "findings"
    else:
        # prose/code-only finding: the whole reviewer section, minus the vocabulary line and a leading
        # "do not merge" sentence is NOT removed — the section is kept verbatim so it stays a substring.
        text = section.strip("\n")
        blocks, kind = ([text] if text else []), "prose"
    for b in blocks:
        assert b in body, "block must be a verbatim substring of the comment body"
    return kind, blocks
