# Feedback from 03 (Skeptic) → 05 (Philosophy/Believer)

> Phase 2 cross-evaluation. Author: jwogrady. All citations trace to 00-ground-truth.md.

---

## Overall assessment

05 is well-grounded — every principle ties back to a shipped feature and a citation. The
philosophy *does* answer the doubts my positioning note raises rather than dodge them.
The feedback below is targeted to places where the doctrine over-asserts or leaves
a gap I depend on.

---

## Issue 1 — "Enforcement over aspiration" does not acknowledge enforcement gaps

**Where:** Doctrine point 1 — "Spark's rules are enforced by code that runs before
Claude acts or before a commit lands."

Ground truth confirms both the PreToolUse guard and the git hooks are real and mechanical
(`hooks/guard-bash.sh` lines 47-58, `scripts/hooks/commit-msg`). However:

- The PreToolUse guard only fires when Claude runs a Bash tool via Claude Code. A
  developer who bypasses Claude and runs `git push --force` directly from their terminal
  is not blocked by the PreToolUse hook — only the `pre-commit`/`commit-msg` git hooks
  apply there.
- `install-git-hooks` must be run explicitly; they are not automatically in place on
  install (`00-ground-truth.md`, CLI section — "copy `commit-msg`/`pre-commit` into the
  current repo's git hooks dir").

The philosophy's claim that "rules are enforced by code that runs before Claude acts
*or* before a commit lands" is accurate but implies broader coverage than it has. A
reader could conclude direct git commands are equally governed. Add a one-sentence
acknowledgment: enforcement covers AI-mediated actions (PreToolUse) and git commits
(hooks, once installed) — not all git operations at the shell level.

---

## Issue 2 — "One lifecycle, portable" elides the unverified marketplace path

**Where:** Doctrine point 2 — "A marketplace plugin is installable and versionable; it
travels with the developer, not with the repo."

Ground truth flags: "v0.2 open item: validate install end-to-end from a *published*
marketplace (unchecked box)" (`00-ground-truth.md`, ROADMAP section). The philosophy
presents marketplace portability as a present-tense property. It is architecturally
correct and partially true (Git-URL install works), but the "installable from a public
marketplace listing" leg is not fully verified. Either qualify with "installable today
via Git URL" or note the marketplace listing is in progress. The philosophy is the
one place where understating roadmap items matters most — it is read by people deciding
whether to trust the vision.

---

## Issue 3 — Scoped-work doctrine vs. real multi-user gap

**Where:** Doctrine point 4 — "The lifecycle's constraint — one problem per ideate, one
feature per issue, one issue per branch, one concern per PR."

My positioning note concedes that Spark today is a solo-developer tool. The philosophy
presents the scope doctrine as universal without acknowledging that there is no team
coordination layer — no shared milestone view, no multi-user state. The scope doctrine
is valid and enforced; the gap is that it operates on a single developer's context.
Philosophy does not need to dwell on this, but one sentence noting the current scope
("for one developer across their projects today; team tooling on the roadmap") would make
the doctrine honest rather than aspirational.

---

## Issue 4 — "Honest attribution, honest hype" is the cleanest doctrine point

**Where:** Doctrine point 6.

This one is fully grounded and does not over-assert. The commit-msg hook citation is
correct, the docit ground-truth contract is accurate. No change required — noting
it explicitly so 05 does not second-guess it in Phase 3.

---

## Issue 5 — "The Future Spark Argues For" crosses from philosophy into roadmap

**Where:** "The future Spark is building toward is one where AI-assisted development is
*indistinguishable from disciplined development*..."

This paragraph makes no factual claims and therefore has nothing to verify — it is
genuinely aspirational. That is fine for a philosophy doc. The risk is that a skeptical
reader who just saw the license-TBD and no-CI disclosures will find the rhetorical uplift
jarring. Consider keeping the future-vision paragraph but immediately following it with a
one-sentence grounding: "The v0.2 release is the first proof of concept; the architecture
is set, the gaps are documented." That prevents the closing from feeling like it undoes
the honest-maturity work in 04.
