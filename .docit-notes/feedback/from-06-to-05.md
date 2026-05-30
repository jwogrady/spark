# Feedback from 06 (Coach) to 05 (Philosophy — The Believer)

## Summary

The philosophy draft is tight and well-cited. Two issues need attention before
it links into the Explanation docs tree.

---

## Issue 1 — Principle 6 over-promises the docit enforcement contract

**Finding:** Principle 6 ("Honest attribution, honest hype") states:

> "The docit crew refuses to ship any claim untraceable to verified ground truth.
> These are not policies written in a contributing guide — they are enforced by code."

The second sentence claims docit's honest-hype contract is *enforced by code*. But
the honest-hype contract is enforced by an instruction to the docit orchestrator and
its personas — it is a behavioral constraint on an AI agent, not a deterministic code
gate the way `hooks/guard-bash.sh` or `scripts/hooks/commit-msg` are.

**Problem:** Calling both the bash hook (which blocks with exit code 2) and the
docit instruction (which relies on agent compliance) "enforced by code" conflates two
very different enforcement strengths. A reader who later sees a docit claim slip
through will reasonably conclude this was a false promise.

**Recommendation:** Separate the two claims. The hook-based enforcement is mechanical
and absolute — say so. The docit honest-hype contract is a rigorous process with human
review as the final gate — say that instead. Example rewrite: "The docit crew's
phase protocol requires every claim to trace to a verified ground-truth note before it
ships; the author reviews and rejects any note that cannot cite its evidence."

**Citation:** `00-ground-truth.md` §"Genuine differentiators" — "Honest-hype contract.
docit refuses to ship any claim not traceable to a ground-truth note (this file is its
enforcement substrate)." Note that this is a *process* description, not a code-level
enforcement claim.

---

## Issue 2 — No explicit link to the philosophy doc in the Explanation tree

**Finding:** The Coach's Diátaxis plan (`06-diataxis.md`) depends on the Philosophy
doc occupying `docs/PHILOSOPHY.md` (or `docs/explanation/` in the four-mode tree).
The current draft does not specify its target file path or confirm it will live inside
`docs/explanation/` alongside `sdlc-doctrine.md`, `scope-and-upstream.md`, and
`why-a-plugin.md` (all cited in `00-ground-truth.md` §Docs).

**Problem:** If `docs/PHILOSOPHY.md` lands at the repo root rather than inside
`docs/explanation/`, it will be invisible to readers navigating the Diátaxis tree.
The Coach's explanation doc plan and the Contributor guide (07) both reference it
as an anchor for the understanding-oriented mode. A misplaced file breaks both
downstream personas.

**Recommendation:** Add a one-line declaration: "Target path: `docs/explanation/philosophy.md`"
or confirm the root placement and note that it must be cross-linked from
`docs/explanation/`'s index. Also add a note that the ADRs (`docs/adr/0001..0003`,
cited in `00-ground-truth.md`) are the *decisions* layer and the philosophy doc is the
*values* layer — they are complementary, not redundant.

**Citation:** `00-ground-truth.md` §Docs — `docs/explanation/` contains
`sdlc-doctrine`, `scope-and-upstream`, `why-a-plugin`; philosophy is not yet listed
there; `06-diataxis.md` §Mode 4 — ADRs not cross-linked from explanation, and no
explanation index exists.
