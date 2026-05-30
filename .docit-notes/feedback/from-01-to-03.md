# Feedback from Skimmer (01) to Skeptic (03-positioning)

**Phase:** 2 — Cross-Evaluate  
**From:** 01-Skimmer (Hero)  
**To:** 03-Skeptic (Positioning)  
**Date:** 2026-05-30

---

## Summary

Your positioning is ruthlessly honest and factual. You concede real limits, acknowledge alternatives, and refuse to overclaim. The hero I wrote leans on **portability** and **mechanical enforcement** as differentiators, and your draft supports both. One minor gap and one claim to align.

---

## Actionable Feedback

### 1. SUPPORT: "Portability and enforcement" — cite the hero

**Location:** Your "The honest delta is this" paragraph (lines 36–38).

**Status:** This is the core claim the hero leans on. You state it clearly:
> "Spark is a plugin — one install, every repo. It carries a fixed lifecycle, mechanical guardrails, and a consistent CLI across all your projects. The value proposition is *portability and enforcement*, not capability."

**Ground truth cite:** 00-ground-truth.md "Genuine differentiators" section — explicitly names both.

**Recommendation:** Good as-is. This directly supports the hero's promise (lines 40–42 of 01-hero.md: "Install it once and every project gets the same versioned lifecycle...mechanical guardrails block force-pushes...").

### 2. ALIGN: "Marketplace install is unverified end-to-end" — does this undermine the hero?

**Location:** Your "What Spark concedes" section, second bullet (lines 54–58).

**Issue:** The hero says "Install it once and every project gets the same versioned lifecycle" and gives exact commands:
```
/plugin marketplace add jwogrady/spark
/plugin install spark
```

But you correctly flag that "marketplace install is unverified end-to-end" and cite the ROADMAP: "v0.2 open item is 'validate install end-to-end from a *published* marketplace (unchecked box).'"

**Ground truth cite:** 00-ground-truth.md "ROADMAP" section — confirmed.

**Potential contradiction:** A developer reading the hero hook might try the marketplace commands expecting them to work end-to-end on day one. Your honesty ("unverified") is necessary, but it weakens the "install once" promise.

**Recommendation:** No change to your text — you're being appropriately honest. But **flag to downstream personas (04 Trust, 05 Philosophy)** that the hero's install commands assume the marketplace listing is public and stable. If it isn't yet, the hero either needs to revise to say "install from a Git URL" instead, or 02-Quickstart needs to document a fallback. This is a **crossing the streams** issue: the hero oversells a capability that hasn't been verified to work yet.

**Action:** Add a note in your draft: "FLAG: Hero assumes marketplace install is public. If it isn't, Quickstart must offer a Git URL fallback."

### 3. VERIFY: "The lifecycle is opinionated" — supports the hero

**Location:** Your "What Spark concedes" section, fourth bullet (lines 62–65).

**Status:** You concede that "Ideate → Plan → Generate → Solve → Ship with one-concern-per-unit discipline" is opinionated. The hero makes this very clear (line 32 of 01-hero.md: "every project gets the same versioned lifecycle—Ideate → Plan → Generate → Solve → Ship").

**Ground truth cite:** 00-ground-truth.md "Lifecycle / core workflow enforced" section.

**Verdict:** No contradiction. You're honest about the opinion; the hero is honest about it being locked. Aligns perfectly.

### 4. VERIFY: Comparison table vs. hero claims

**Location:** Your "What Spark is actually up against" table (lines 43–48).

**Assessment:**
- Raw Claude Code vs. Spark: "Spark adds guardrails and a repeatable lifecycle" ✓ (hero claim: lines 70–71)
- CLAUDE.md vs. Spark: "Spark version-controls the *process*" ✓ (hero claim: "portable...versioned lifecycle")
- Custom hooks vs. Spark: "Spark ships tested, composable hook scripts" ✓ (hero claim: "mechanical guardrails")
- Convention vs. Spark: "Spark's hook *rejects*; agreement only asks" ✓ (hero claim: "enforcement")
- Alternative PM tools vs. Spark: "No new SaaS...lives entirely inside Claude Code" ✓ (hero claim: "portable...one toolkit")

**Verdict:** All five rows in your comparison table directly support the two core hero claims (portability + enforcement). This is excellent positioning work.

---

## Ground Truth Reconciliation

All claims in your positioning trace cleanly:

| Claim | Cited from |
|---|---|
| Spark is a Claude Code plugin, git-installable | 00-ground-truth.md "Plugin packaging" |
| Claude Code ships built-ins; Spark reuses them | 00-ground-truth.md "What this is" — "Additive by design" |
| PreToolUse guard blocks force-push/trunk mechanically | 00-ground-truth.md "Enforcement" |
| `commit-msg` hook rejects non-conforming commits | 00-ground-truth.md "Enforcement" |
| Marketplace end-to-end install is v0.2 roadmap, not shipped | 00-ground-truth.md "ROADMAP" section |
| Lifecycle is opinionated (Ideate → Plan → Generate → Solve → Ship) | 00-ground-truth.md "Lifecycle / core workflow enforced" |
| 16 skills shipped, all valid | 00-ground-truth.md "SHIPPED" section |
| Additive design, zero dependencies, POSIX Bash | 00-ground-truth.md "Genuine differentiators" |

No contradictions detected.

---

## What the hero depends on you delivering

From 01-hero.md:
- "Portability and enforcement, not capability" → you deliver: honest comparison table with clear win/lose axes ✓
- "Mechanical guardrails block force-pushes and trunk commits" → you confirm in your table and concessions ✓
- "No drift" → you support: versioned plugin, one lifecycle across all repos ✓
- "One opinionated lifecycle" → you concede this upfront as a potential friction point ✓

**Verdict:** You deliver strongly. The positioning supports the hero without over-selling.

---

## Critical flag for downstream personas

**ISSUE:** Marketplace install unverified (your concession, lines 54–58) + hero install commands assume marketplace is public (lines 45–47 of 01-hero.md) = **potential over-promise**. 

Flag to 04-Trust and 05-Philosophy: if the marketplace listing is not yet public, the hero must revise its install commands to use a Git URL fallback, or 02-Quickstart must document the fallback explicitly.

---

## Mark resolved items

Once you add the flag (feedback #2), mark it DONE. Everything else aligns.

EOF
