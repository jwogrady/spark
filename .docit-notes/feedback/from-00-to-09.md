# Feedback from 00 (Cartographer) to 09 (Changelog / Returning User)

Reviewer: 00-cartographer (honest-hype enforcement). Claims must trace to ground
truth, `git`, or a file. This draft has the most factual errors of the set — four
must-fix items, two of them flat contradictions of the repo.

## Verdict: NEEDS REVISION — multiple verified-false claims

### Must fix (verified false)

1. **CONTRADICTS REPO: "codify Coordinates through `.docit-notes/` (shared with
   `docit`)."** False. `skills/codify/SKILL.md` uses **`.codify-notes/`** and
   explicitly says to keep it out of the repo. docit uses `.docit-notes/`. They
   are deliberately separate scratch dirs. Remove every claim that codify shares
   `.docit-notes/` with docit — it is wrong in the "What Changed" bullet AND in
   the "For projects heavy on public docs" migration note. This is the single
   biggest accuracy defect in the whole team's drafts.

2. **WRONG COUNT: "13 commits ahead" / "13 commits unreleased."** Verified:
   `git rev-list v0.2.0..HEAD --count` = **15**, not 13. (You may be confusing the
   commit count with PR #13.) Fix to 15, or — safer — drop the exact count and say
   "unreleased commits since the v0.2.0 tag," since this number changes with every
   commit.

3. **WRONG HASH: v0.2.0 is commit `e013d6b`.** Verified: `git rev-list -n1 v0.2.0`
   = **`e4082cb`**. `e013d6b` does not match the tag. Either use `e4082cb` or, since
   the tag name is the durable reference, just cite `v0.2.0` and drop the hash.

4. **PUTS WORDS IN THE TOOL'S MOUTH: `spark doctor` does NOT print "OK".** Twice
   the draft says doctor "prints OK" / "prints 'OK' if plugin layout… pass."
   Verified by reading `bin/spark`: it prints a green `✓` per item and ends with
   `Healthy — 0 errors, N warning(s)`. There is no "OK" string. Reword to
   "`spark doctor` ends with `Healthy — 0 errors` when everything passes."

### Should fix (unverifiable / premature)

5. **Version bump to 0.3.0 is asserted, not shipped.** `.claude-plugin/plugin.json`
   still reads `"version": "0.2.0"`. Calling this "0.3.0" in the changelog is fine
   as a *proposed* next-release heading, but label it clearly as the unreleased /
   `[Unreleased]` section — do not state 0.3.0 as the current version. (Trust
   persona 04 correctly reports current = v0.2.0; stay consistent with it.)

6. **"codify added" as the headline.** Verify against `CHANGELOG.md`'s
   `[Unreleased]` block that codify is in fact the unreleased headline and not
   already part of v0.2.0. Ground truth lists codify under SHIPPED capabilities,
   so confirm whether it landed before or after the v0.2.0 tag before framing it
   as "the next release."

### Verified-good

- codify = 6 agents under `agents/codify/` (00-intake..05-editor) — CORRECT.
- docit = 13 personas, unchanged — CORRECT.
- 6 lifecycle skills intact, no removals/renames — consistent with ground truth.
- "No breaking changes; additive" — plausible and consistent with the additive
  design principle.

Fix items 1-4 before this can ship; they are falsifiable against the repo.
