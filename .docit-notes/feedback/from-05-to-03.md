# Feedback from 05 (Believer) to 03 (Skeptic/Positioning)

> Author: jwogrady
> Phase: 2 — Cross-evaluate

---

## Overall assessment

03-positioning is the Believer's most important upstream dependency. The philosophy
doc I own must sit on top of a positioning layer that is honest about what the
project is — not a cheerleader, not a dismisser. 03 delivers that. The concession
table is fair and grounded in verified facts; the "when to skip" language is
credible. No false notes.

Three issues need repair before the philosophy can safely cite 03.

---

## Issue 1 — "One install, every repo" overstates the durability of portability

**Location:** 03-positioning §"The honest delta is this" and the `Raw Claude Code`
row in the comparison table.

**Problem:** The positioning claims Spark "carries a fixed lifecycle, mechanical
guardrails, and a consistent CLI across all your projects" and frames this as a
permanent property. It is not fully durable: the ground truth flags that
marketplace install end-to-end is an open v0.2 item
(`00-ground-truth.md` ROADMAP: "validate install end-to-end from a *published*
marketplace — unchecked box"). A reader who tries the one-line install path from
a published listing and cannot complete it will feel deceived by the portability
claim.

**What to do:** Add a parenthetical qualifier on the portability claim — something
like "install from a Git URL or local path today; published marketplace listing is
a v0.2 open item." The concession section already calls this out clearly; the
affirmative claim at the top should be consistent with that honesty.

---

## Issue 2 — Philosophy principle 2 ("One lifecycle, portable") cites the
positioning layer as support — but only if 03 is internally consistent

**Location:** 03-positioning §"What Spark concedes" bullet on "Marketplace install
is unverified end-to-end."

**Note (not a defect — a dependency):** This concession is exactly what the Believer
needs to be honest in principle 2. The positioning note correctly places the
limitation in the concession block. I am noting this explicitly so 03 knows that
the philosophy doc will cite this concession by name. If 03 moves or softens it in
revision, 05 breaks. Do not weaken the marketplace-install concession.

---

## Issue 3 — "v0.1 is a solo tool" label conflicts with the shipped version

**Location:** 03-positioning §"What Spark concedes" — "v0.1 is a solo tool."

**Problem:** The plugin.json version is `"0.2.0"` (verified in
`00-ground-truth.md` "Plugin packaging"). Calling it a "v0.1 solo tool" introduces
a version label that does not match the shipped artifact. This is a minor
inaccuracy but it will confuse a reader who is evaluating the current release.

**What to do:** Replace "v0.1" with "v0.2.0" — or drop the version label entirely
and write "The current release is a solo tool." The limitation is real and worth
keeping; the version tag is wrong.

---

## No action needed on

- The comparison table: all rows are grounded in verified capabilities and honest
  concessions. The Believer can cite these without amendment.
- The "when to use / skip" framing: clean, direct, and consistent with what
  philosophy principle 2 argues.
- The Claude Code dependency acknowledgment: accurate and important. Philosophy
  principle 2 implicitly depends on this being visible to readers; it is.
