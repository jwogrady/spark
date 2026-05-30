# Feedback from 06 (Coach) to 07 (Contributor)

## Summary

The Contributor guide is accurate and well-cited. Three issues need resolution to
prevent gaps in the Diátaxis teaching surface and to keep the extension path honest.

---

## Issue 1 — "Your first contribution" step 3 sends contributors to the wrong quadrant

**Finding:** The "Your first contribution" section item 3 says:

> "Improve a doc. The Diátaxis tree (`docs/`) uses tutorial / how-to / reference /
> explanation categories — pick the right quadrant for what you're adding and follow
> that pattern."

This is correct as far as it goes, but it does not point contributors to the how-to
guide that would teach them *how* to pick the quadrant and author inside it. The
Coach's plan identifies a gap: there is no `docs/how-to/write-a-skill.md` and there
is also no equivalent "how to add a doc in the right Diátaxis mode" guide.

**Problem:** Without a concrete how-to, contributors who want to add a tutorial will
default to whatever pattern looks familiar — which tends to produce mode-blended docs
(a tutorial that reads like a reference, or a how-to that teaches rather than
instructs). The Contributor guide is the right place to catch this, but it does not
currently do so.

**Recommendation:** Add a note that directs contributors to `06-diataxis.md` (or its
eventual published form in `docs/`) before writing any doc: "Before adding or editing
a doc, read the Diátaxis plan to understand which mode you're operating in and what
rules apply to that mode." If/when a `docs/how-to/add-a-doc.md` exists, link it here.

**Citation:** `06-diataxis.md` §Mode 2 gap — "No `write-a-skill` how-to"; same pattern
applies to contributing docs; `00-ground-truth.md` §Docs — confirms Diátaxis tree
exists but no cross-mode authoring guide is listed.

---

## Issue 2 — `SKILL.md ≤ 100 lines` rule is asserted without a ground-truth source

**Finding:** The Contribution standards list and the skill-authoring section state
"SKILL.md ≤ 100 lines or split to companion files". This rule is also cited to
`skills/write-a-skill/SKILL.md §"When to Split Files"`.

**Problem:** `skills/write-a-skill/SKILL.md` is a skill doc, not a policy file — it
is a peer artifact, not a ground-truth source. The 100-line rule appears in
`CLAUDE.md` §"Skill Authoring" ("Keep SKILL.md under 100 lines"), which is an
authoritative policy. But `00-ground-truth.md` does not list the 100-line rule, so
the citation chain stops at a secondary source.

**Recommendation:** Either cite `CLAUDE.md §"Skill Authoring"` directly (it is the
authoritative source) or note the limitation: "The 100-line guideline is in
`CLAUDE.md §Skill Authoring` — see that file for the authoritative rule." This keeps
the Contributor guide honest about where its rules come from.

**Citation:** `CLAUDE.md` §"Skill Authoring" — states the 100-line limit; not
reproduced in `00-ground-truth.md`.

---

## Issue 3 — No mention of the docs contribution path for Diátaxis modes

**Finding:** The Contributor guide explains how to add a skill, an agent, and a CLI
subcommand. It mentions improving docs as an entry point but does not explain the
four-mode constraint — specifically, that all doc contributions must land in exactly
one of `tutorials/`, `how-to/`, `reference/`, or `explanation/`, and that mixing
modes in a single file is a quality failure.

**Problem:** This is the gap the Coach owns: contributors who add docs without Diátaxis
awareness produce mode-blended files. The Contributor guide is the natural place to
state this constraint, but it currently defers entirely to "follow that pattern" without
stating the constraint.

**Recommendation:** Add a brief subsection: "Contributing docs — the four-mode rule."
One paragraph: a new doc goes in exactly one mode directory; describe what each mode
is for (one sentence each); link to `docs/explanation/` or the Diátaxis plan for
deeper background. This protects the Coach's work.

**Citation:** `06-diataxis.md` §Cross-mode navigation — structural recommendation for
`docs/README.md` to anchor all four modes; `00-ground-truth.md` §Docs — confirms the
four-mode tree exists.
