# Feedback from Skimmer (01) to Adopter (02-quickstart)

**Phase:** 2 — Cross-Evaluate  
**From:** 01-Skimmer (Hero)  
**To:** 02-Adopter (Quickstart)  
**Date:** 2026-05-30

---

## Summary

Your draft is strong and actionable. You deliver on the hero's core promise: "install once, every project gets the same lifecycle" and "one full Ideate → Ship cycle in one session." All claims trace cleanly to ground truth. One small gap and one minor contradiction to reconcile.

---

## Actionable Feedback

### 1. CLARIFY: "Spark is now available globally" — scope this claim

**Location:** Your "Install the plugin" section, line 37.

**Issue:** You say "Spark is now available globally — every project you open gets the lifecycle skills." This is technically true after marketplace install, but it can read as overstated — especially to a dev who then tries `/spark:ideate` in a project that hasn't run `spark install-git-hooks` yet.

**Gap:** The hero hook says "guardrails block force-pushes and trunk commits" (lines 70-71 of 01-hero.md). But your quickstart doesn't flag that the **PreToolUse guard requires the plugin to already be installed in Claude Code globally** — it's not activated by `install-git-hooks` alone. The git hooks enforce conventional commits; the PreToolUse guard blocks force-push/trunk push.

**Recommendation:** Revise line 37 to something like:
> "Spark is now available globally — every project you open gets the lifecycle skills (/spark:ideate, /spark:plan, etc.). The enforcement hooks activate when you run `spark install-git-hooks` in a git repo (conventional commits + block trunk pushes); the PreToolUse guard (force-push prevention) works automatically once the plugin is installed."

This separates the two layers of guardrails and sets correct expectations.

### 2. VERIFY: Cycle walkthrough matches ground truth

**Location:** Your "Walk through one full cycle" section (lines 63–125).

**Status:** All five stages map correctly to ground truth:
- Stage 1: `/spark:ideate` ✓
- Stage 2: `/spark:plan` ✓
- Stage 3: `/spark:build` ✓
- Stage 4: `/spark:fix-issue` (mentions `/spark:review` as optional harsher audit) ✓
- Stage 5a–5b: `/spark:commit` then `/spark:ship` ✓

**Ground truth cite:** 00-ground-truth.md "Lifecycle / core workflow enforced" table.

No action needed on this — it's solid.

### 3. RECONCILE: "ship" requires GitHub API token, but hero doesn't mention auth/secrets

**Location:** Your prerequisite #2 (lines 132–135).

**Issue:** You correctly flag "GitHub token for PR creation" and reference `gh auth login`. But the hero (01-hero.md) makes no mention of *any* prerequisites or auth setup. A developer reading the hero hook ("Install it once...") won't know they need to authenticate with GitHub before `/spark:ship` will work.

**Note:** The ground truth lists a `connect` skill (00-ground-truth.md "Setup / inception skills") that handles "secrets via 1Password (op)," but it's not in the quick-start path. You mention it correctly as a prerequisite, but the hero doesn't.

**Recommendation:** No change needed in your draft — you're already handling this honestly. But flag to downstream personas (Skeptic, Visual Storyteller) that the hero may over-promise "ready in minutes" if the reader hasn't set up `gh auth` yet. That's a ~30-second authentication step, not a blocker, but worth a callout.

---

## Ground Truth Reconciliation

All major claims in your quickstart trace cleanly:

| Claim | Cited from |
|---|---|
| 16 skills + 19 agents verified by `spark doctor` | 00-ground-truth.md "Lifecycle skills (16 total)" |
| `spark install-git-hooks` copies hooks into `.git/hooks` | 00-ground-truth.md "Exact install + first-use commands" |
| Conventional commits enforced; subject ≤ 72 chars | 00-ground-truth.md "Enforcement"; `scripts/hooks/commit-msg` |
| Block force-push/trunk; allow `--force-with-lease` | 00-ground-truth.md "PreToolUse Bash guard" |
| AI attribution stripped by hook | 00-ground-truth.md "Enforcement" |
| One branch per work item | 00-ground-truth.md "Lifecycle / core workflow enforced" |

No contradictions detected.

---

## What the hero depends on you delivering

From 01-hero.md:
- "Install it once" → you deliver: two commands, ~30 seconds ✓
- "every project gets the same versioned lifecycle" → you deliver: global install, then per-repo `install-git-hooks` ✓
- "one full Ideate → Ship cycle" → you deliver: concrete walk-through with all five stages ✓
- "mechanical guardrails" → you explain PreToolUse guard, git hooks, conventional commits ✓

**Verdict:** You can deliver. Reconcile the guardrail scope (feedback #1) and all downstream expectations align.

---

## Mark resolved items

Once you revise #1, mark it DONE in your draft. Flag #3 as a heads-up to downstream personas (Skeptic, Visual Storyteller) about the implicit authentication step.

EOF
