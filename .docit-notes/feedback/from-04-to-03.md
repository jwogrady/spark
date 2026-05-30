# Feedback from 04-Evaluator to 03-Positioning

> Phase 2 — Cross-evaluate
> Author: jwogrady

---

## Summary

03-positioning is well-reasoned and honest. Its concessions align precisely with verified ground truth. Two targeted issues follow.

---

## Issue 1: MIT badge claim in the README — overclaim not caught

**Location:** `03-positioning.md` does not address the license mismatch. The note concedes "marketplace install is unverified" but says nothing about the license gap.

**Why it matters to me (Evaluator):** The README currently displays an MIT badge. `plugin.json` declares `"license": "MIT"`. But `LICENSE` reads: *"License TBD. Copyright belongs to the author."* (verified by reading `LICENSE`, and confirmed in `00-ground-truth.md` § Accuracy flags). As Positioning, this note frames Spark as safe to adopt. A reader who follows the Skeptic's "when to use Spark" guidance and then encounters the TBD license will conclude the project misrepresented itself — exactly the kind of trust erosion Positioning is supposed to prevent.

**Action requested:** Add a one-line concession under "What Spark concedes": the license is formally unresolved. The MIT declaration in the manifest is aspirational. Callers cannot legally redistribute or fork until this is resolved.

---

## Issue 2: Version number absent — maturity context is under-specified

**Location:** "What Spark concedes" — the note says "v0.1 is a solo tool" but the current shipped version is `v0.2.0` (confirmed: `git tag -l → v0.2.0`; `plugin.json` `"version": "0.2.0"`).

The "v0.1" label is factually wrong. The Skeptic's concession reads as if Spark is at an earlier maturity checkpoint than it actually is.

**Action requested:** Replace "v0.1 is a solo tool" with "v0.2 is a solo tool" (or drop the version qualifier and say "the current release is a solo tool"). The characterization remains accurate; the version number needs correction.

---

## What is consistent and does not need changes

- All five comparison-table claims trace correctly to `00-ground-truth.md`.
- "Marketplace end-to-end install is an open v0.2 item" is precisely stated and cites the correct ground truth source (ROADMAP unchecked box).
- "Claude Code dependency is total" is accurate and appropriately stated.
- "Zero runtime dependencies / POSIX Bash" claim is correctly cited (ADR-0003, `bin/spark`).
- The "When to use / Skip it" framing is honest and matches ground truth.
