# Feedback from 03 (Skeptic) → 02 (Quickstart/Adopter)

> Phase 2 cross-evaluation. Author: jwogrady. All citations trace to 00-ground-truth.md.

---

## Issue 1 — "spark doctor" output description overpromises

**Where:** "Verify the install worked" block — "You should see all 16 skills listed as ✓
and all docit/codify agents verified (13 + 6 = 19 agents)."

Ground truth verifies that `doctor` validates "plugin manifests are JSON, hooks JSON +
guard executable, every skill's `name:`/`description:` frontmatter, every
`agents/**/*.md` frontmatter" (`00-ground-truth.md`, CLI section). The claim about the
exact output format (a ✓ checkmark per skill, a "19 agents" line) is not verified in
ground truth — it's an inference about presentation, not a confirmed CLI output. A dev
who runs `spark doctor` and sees different formatting will distrust the quickstart. Either
verify the exact output by running the command and citing the transcript, or rephrase to
"confirms all skills and agents pass validation" without specifying the symbol/count
formatting.

---

## Issue 2 — "/spark:build creates a feature branch" is stated as definite behavior

**Where:** Stage 3 Generate block — "The skill creates a feature branch (e.g.
`feat/health-check-endpoint`), scaffolds a commit message template, and hands you the
work."

Ground truth says `build` implements "one issue on a feature branch" (`skills/build/SKILL.md`)
but does not verify the exact branch-naming convention or that the skill *automatically*
creates the branch vs. instructing the user to create it. The quickstart presents this as
a mechanical operation ("The skill creates..."). If the skill actually instructs Claude
to run `git checkout -b feat/...` and Claude sometimes names branches differently, a user
following the quickstart would be confused. Verify the branch-creation behavior against
`skills/build/SKILL.md` and adjust to match what the skill actually does.

---

## Issue 3 — "fix-issue runs /code-review and /security-review automatically"

**Where:** Stage 4 Solve block — "Runs `/code-review` and `/security-review`
automatically."

Ground truth confirms `fix-issue` "orchestrate[s] built-in reviews, then fix[es] to
acceptance criteria" (`00-ground-truth.md`, lifecycle skills table). The word
"automatically" implies zero user interaction, but reviews in Claude Code may involve
prompts or pauses. If the behavior is semi-interactive (Claude runs the review but
surfaces results to the user), "automatically" is an overclaim. Rephrase to "invokes
`/code-review` and `/security-review` as part of the solve loop" — accurate without
implying full automation.

---

## Issue 4 — Marketplace install caveat missing (same flag as in 01 feedback)

**Where:** Install block, Step 1.

The quickstart presents `/plugin marketplace add jwogrady/spark` as the install path
without noting the v0.2 open item (end-to-end marketplace install unverified from a
*published* listing — `00-ground-truth.md`, ROADMAP section). Since the Adopter persona
is specifically someone who just decided to try it, this is the highest-stakes place for
the caveat. Add: "Note: currently installable from a Git URL or local clone. Marketplace
listing in progress — check `ROADMAP.md` for status."

---

## Issue 5 — "AI attribution is forbidden" gotcha may surprise adopters

**Where:** Gotcha 5 — "The `commit-msg` hook strips out any trailer that credits Claude,
ChatGPT, Copilot, or any AI system."

Ground truth confirms the hook blocks AI attribution trailers (`scripts/hooks/commit-msg`).
This gotcha is accurate and important. No change required. I flag it positively: this is
the kind of honest disclosure my positioning note (03) depends on — the quickstart is
forthright about opinionated constraints. Keep it.

---

## No structural objections

The overall structure is sound, the install sequence matches ground truth, and the
lifecycle walkthrough maps correctly to the 5-stage model. The issues above are targeted
to specific over-claims, not systemic problems.
