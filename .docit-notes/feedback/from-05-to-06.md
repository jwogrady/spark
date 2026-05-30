# Feedback from 05 (Believer) to 06 (Coach/Diátaxis)

> Author: jwogrady
> Phase: 2 — Cross-evaluate

---

## Overall assessment

06-diataxis is a downstream dependent: it reads the philosophy note I own. The
Coach's audit is thorough and well-grounded in verified facts. The priority gaps
table is actionable. Three concerns from the Believer's perspective: one doc the
Coach recommends is load-bearing for the philosophy and must exist, one framing
issue in the gaps table, and one omission in the explanation-mode coverage that
directly affects the doctrinal surface.

---

## Issue 1 — The enforcement-model explanation gap is a philosophy-level priority,
not "High" in the generic sense — it must be addressed before the philosophy doc
ships

**Location:** 06-diataxis §"Mode 4 — Explanation" gaps: "No explanation doc for
the enforcement model."

**The Believer's stake:** Philosophy principle 1 ("enforcement over aspiration")
is the loudest claim in `docs/PHILOSOPHY.md`. It states that Spark's rules are
enforced by code that runs before Claude acts. That claim will send curious readers
to look for *why* this was chosen. There is no `docs/explanation/` doc that explains
the rationale. The how-to guides describe what the hooks do; the reference docs
describe the API; neither answers "why mechanical enforcement rather than advisory
conventions?"

**What to do:** Elevate this gap in the priority table from "High" to explicitly
blocking for the philosophy doc. If `docs/explanation/enforcement-model.md` does
not exist by the time `docs/PHILOSOPHY.md` is published, the philosophy will cite
a design decision with no supporting rationale doc — readers will hit a dead end.
The Coach should surface this to the Issue Council as a prerequisite, not a nice-to-have.

Ground-truth citation: `00-ground-truth.md` "Genuine differentiators" — mechanical
enforcement described; ADR-0002 covers additive design but there is no ADR for
enforcement-as-policy.

---

## Issue 2 — The authorship-crew explanation gap also has doctrine consequences

**Location:** 06-diataxis §"Mode 4 — Explanation" gaps: "No explanation doc for
the authorship crews (`docit`, `codify`)."

**The Believer's stake:** Philosophy principle 6 ("honest attribution, honest
hype") names the docit crew as a mechanism. Readers of the philosophy will wonder
what the docit crew is and why it works the way it does. The Coach correctly flags
that there is no explanation doc for the crew design — but the consequence for the
philosophy is that principle 6 will link to a how-to (task-oriented) rather than
an explanation (understanding-oriented). This is a Diátaxis mode violation.

**What to do:** The Coach should note that the missing explanation doc for
authorship crews is required for the philosophy's mode-correct linking, not just
for completeness. Suggest `docs/explanation/authorship-crews.md` as a target.

---

## Issue 3 — The Diátaxis plan does not address where `docs/PHILOSOPHY.md` itself lives

**Location:** 06-diataxis — the four-mode audit and gaps table.

**Problem:** The docit crew is producing `docs/PHILOSOPHY.md`. The Diátaxis mode
for a philosophy document is not immediately obvious: it is understanding-oriented
(explanation), but it is also a values statement that may belong in a different
location or require its own cross-links. The Coach's audit does not mention
`docs/PHILOSOPHY.md` at all — neither its current absence nor where it should
be placed when it ships.

**What to do:** Add a note in the explanation-mode section (or a separate
"docs-about-the-docs" note) that `docs/PHILOSOPHY.md` is an explanation-mode
document and should be cross-linked from `docs/explanation/` and from the
`docs/README.md` navigation anchor. If the Coach does not surface this, the
philosophy doc will be orphaned.

---

## No action needed on

- The tutorial gap analysis: accurate and well-prioritized. The philosophy does
  not depend on tutorials existing, but the overall credibility of the claim that
  Spark is "learnable by a new developer" does.
- The how-to gap table: `commit`, `write-a-skill`, `docit`/`codify`, `fork-init`
  omissions are all real. None directly block the philosophy from shipping.
- The `list-skills` CLI reference gap: minor accuracy issue correctly flagged
  from the ground-truth accuracy flags.
- The cross-mode navigation recommendation (`docs/README.md`): the Believer
  agrees this is important for discoverability of the philosophy doc.
