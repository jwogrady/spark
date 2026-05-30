# Feedback from 04-Evaluator to 05-Philosophy

> Phase 2 — Cross-evaluate
> Author: jwogrady

---

## Summary

05-philosophy is tightly argued and every principle ties to a shipped feature. Two issues affect trust consistency between this note and what I (the Evaluator) have established.

---

## Issue 1: Principle 6 ("Honest attribution, honest hype") claims enforcement — but CI is absent

**Location:** `05-philosophy.md` Principle 6, last sentence: *"These are not policies written in a contributing guide — they are enforced by code."*

**The problem:** The docit honest-hype contract (enforced through the ground-truth note) is genuinely code-enforced. The `commit-msg` hook blocking AI co-author trailers is code-enforced. Both claims are verified. However, the broader implication Principle 6 creates — that Spark's quality practices are systematically enforced — collides with a gap I own: **there is no CI**. There are no `.github/workflows/`, no automated test suite. A reader of the Philosophy note will come away believing the project is rigorously protected by mechanical enforcement at every layer. That is not the current state.

**Action requested:** Add a one-sentence qualifier in Principle 6 (or in a closing note on the draft) that limits the enforcement claim to the specific mechanisms that exist: commit-msg hook, PreToolUse guard, and docit ground-truth contract. Do not imply coverage that doesn't exist yet (no automated tests, no CI lint/syntax check on PRs). A sentence like "CI and automated testing are a known gap at v0.2.0; the enforcement today covers commit conventions, trunk discipline, and docs honesty" keeps the philosophy honest without undermining the core point.

---

## Issue 2: Principle 2 ("One lifecycle, portable") — the install maturity caveat is missing

**Location:** `05-philosophy.md` Principle 2: *"A marketplace plugin is installable and versionable; it travels with the developer, not with the repo."*

**The problem:** The ground truth explicitly flags: "Marketplace end-to-end install is an open v0.2 item — validate install end-to-end from a *published* marketplace (unchecked box)" (`00-ground-truth.md` § ROADMAP). The Philosophy note states the portability/install story as fully realized, which overclaims relative to ground truth.

The install path currently works from a local path or a Git URL. The one-click public marketplace install is roadmap.

**Action requested:** Add a parenthetical or footnote on Principle 2 acknowledging that the portability story is not fully realized until marketplace install is validated end-to-end (the open v0.2 item). Something like: "At v0.2.0, install via git URL is verified; one-click public marketplace install is a v0.2 open item." This keeps the philosophy grounded without softening the principle.

---

## What is consistent and does not need changes

- All six principles cite their enforcement mechanism correctly and those mechanisms are verified in `00-ground-truth.md`.
- The `commit-msg` AI co-author trailer claim is accurate and cites the correct source.
- "Additive by design" (Principle 3) correctly cites `docs/explanation/scope-and-upstream.md` and ADR-0002.
- "Zero external dependencies" (Principle 5) is accurate per ADR-0003 and `bin/spark check_json`.
- The closing vision statement is aspirational (not claiming shipped state), which is appropriate for a philosophy doc.
