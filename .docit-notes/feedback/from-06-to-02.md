# Feedback from 06 (Coach) to 02 (Quickstart)

## Summary

The Quickstart draft is well-structured, commands are accurate, and citations are
solid. Three targeted issues follow.

---

## Issue 1 — Tutorial boundary violation: the Quickstart is doing tutorial work

**Finding:** The walk-through in `02-quickstart.md` steps a beginner from zero to
an open PR across all five lifecycle stages. That is a learning-oriented narrative
— which is the Diátaxis Tutorial mode. But `docs/tutorials/build-your-first-project.md`
exists (`00-ground-truth.md` §Docs) and covers the same full-cycle journey.

**Problem:** A reader who follows the Quickstart and then opens the tutorial will
encounter significant overlap. The Quickstart is supposed to be a fast "you're running"
confirmation, not a guided first lesson. If both documents walk through all five stages
end-to-end, one of them is redundant and both become harder to maintain.

**Recommendation:** The Quickstart should shrink to: install → `spark doctor` green →
one representative command (`/spark:ideate`) confirming the plugin works. The full
guided lesson belongs exclusively in `docs/tutorials/build-your-first-project.md`.
The Quickstart should link there explicitly: "Ready for a deeper walkthrough? See
[Build your first project](docs/tutorials/build-your-first-project.md)."

**Citation:** `00-ground-truth.md` §Docs — tutorial exists; `06-diataxis.md` §Mode 1 —
tutorial assessment confirms the tutorial already covers this path.

---

## Issue 2 — `spark doctor` output description is speculative

**Finding:** The Quickstart states:

> "You should see all 16 skills listed as ✓ and all docit/codify agents verified
> (13 + 6 = 19 agents)."

`00-ground-truth.md` (§CLI `cmd_doctor`) verifies that `doctor` validates manifests,
hooks, skill frontmatter, and agent frontmatter — but it does not describe the exact
output format (whether it prints ✓ per skill, or a summary count, or a list).

**Problem:** Claiming a specific UI string ("all 16 skills listed as ✓") that is not
confirmed in the ground truth is an honest-hype violation. If `doctor`'s output format
changes, this line breaks silently.

**Recommendation:** Describe the *contract*, not the assumed output format: "You should
see `spark doctor` exit 0 with no errors. If any check fails, it exits non-zero and
prints the failing item." Only add specific UI text if it is verified by running the
command and observing the output (then cite the observation in ground truth).

**Citation:** `00-ground-truth.md` §CLI — `doctor` description does not confirm output
format or per-skill ✓ notation.

---

## Issue 3 — `/verify` command reference is unverified

**Finding:** Stage 3 (Generate) instructs: "Implement the feature, then call `/verify`
when you think it's ready." The built-in `/verify` skill is real (listed in
`00-ground-truth.md` §"What this is" as one of the Claude Code built-ins Spark reuses),
but the Quickstart does not explain what it does or when to use it, and it appears
mid-step without any setup. A first-time user hitting `/verify` blind may not know
what to expect.

**Recommendation:** Either add a one-sentence description ("Claude Code's `/verify`
runs the app and observes the change working — it checks your feature against real
behavior, not just tests") or move the `/verify` mention to the Solve stage where
`/spark:fix-issue` runs review. Whichever choice is made, the ground truth does not
document what `/verify` does in detail — so keep the description brief and accurate
rather than speculative.

**Citation:** `00-ground-truth.md` §"What this is" — mentions `verify` as a reused
built-in; no detailed spec of its behavior is in the ground truth.
