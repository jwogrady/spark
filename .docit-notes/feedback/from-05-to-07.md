# Feedback from 05 (Believer) to 07 (Contributor)

> Author: jwogrady
> Phase: 2 — Cross-evaluate

---

## Overall assessment

07-contributing is downstream: it reads the philosophy note I own. The Contributor
note is practical, accurate, and well-grounded in verified facts. The six-point
contribution standards list is tight and consistent with the ground truth. Two
concerns from the Believer's perspective: one place where the note under-represents
the philosophy, and one inconsistency in how the doctrine is surfaced to contributors.

---

## Issue 1 — The "why" of the contribution standards is absent

**Location:** 07-contributing §"Contribution standards in one list."

**Problem:** The standards list is accurate and complete. But it reads as a
compliance checklist with no rationale. A developer who asks "why must I use
conventional commits?" or "why is `set -euo pipefail` required?" has nowhere to
go. The philosophy doc (`docs/PHILOSOPHY.md`) will be the canonical answer — but
07 does not point to it or acknowledge it.

The Believer's doctrine is that contributors should internalize the principles, not
just follow the rules. A contributing guide that lists rules without linking to the
rationale is consistent with "aspiration over enforcement" thinking — which is
exactly what the philosophy contests.

**What to do:** Add a short intro paragraph (2–3 sentences) to the standards list
that names the doctrine source: "These standards are enforced mechanically (hooks,
doctor) and explained in `docs/PHILOSOPHY.md`. If you want to understand why the
rules are what they are, start there." This does not require the philosophy doc to
exist yet — it can be a forward reference — but it should be present in the
Contributor note so the two docs are explicitly linked.

---

## Issue 2 — The "your first contribution" section sends new contributors to a skill
file, not a doc

**Location:** 07-contributing §"Your first contribution" — bullet 1 references
`skills/write-a-skill/SKILL.md`.

**Problem:** SKILL.md files are instruction sets for the AI, not human-readable how-to
guides. Directing a new contributor to `skills/write-a-skill/SKILL.md` may work today
because the file is reasonably readable, but it is the wrong artifact type for a
human contributor. The ground truth confirms there is no `docs/how-to/write-a-skill.md`
(noted by 06-diataxis as a gap). The contributing guide should acknowledge this gap
honestly rather than routing contributors to a SKILL.md as a workaround.

**What to do:** Change the bullet to read: "Write a skill for something you do
repeatedly. Use `spark new-skill` to scaffold — a how-to guide for skill authoring
is a known gap (`docs/how-to/write-a-skill.md` does not yet exist; follow the
patterns in `skills/write-a-skill/SKILL.md` until it does)." This is honest, it
flags the gap without hiding it, and it still gives a contributor a path forward.

Ground-truth citation: `00-ground-truth.md` §Accuracy flags (implicit — no
`docs/how-to/write-a-skill.md` listed in the Docs section); 06-diataxis §How-to
gaps explicitly flags this absence.

---

## Issue 3 — Attribution standard: "Attribution field: `jwogrady`" is correct
but the context is ambiguous

**Location:** 07-contributing §"Contribution standards in one list" — "Attribution
field: `jwogrady`."

**Problem:** This line is factually correct per the ground truth and the philosophy.
But the context of a contribution guide raises a question a new contributor will
have: "If I am contributing and I am not `jwogrady`, what attribution do I use?"
The note does not answer this. If attribution is always `jwogrady` regardless of
contributor, that is a policy the note should state explicitly and explain (it is
consistent with this being a solo-author project). If other contributors would use
their own identity, the note needs to say so.

**What to do:** Clarify with one sentence: "This is a single-author project;
attribution in commit metadata and manifests is always `jwogrady`. If that changes
as the project accepts external contributions, this policy will be documented here."
The Believer has no objection to the current policy — it just needs to be stated
rather than implied.

---

## No action needed on

- The six-step skill contribution walkthrough: accurate, mechanical, and consistent
  with the ground truth. The philosophy's "enforcement over aspiration" principle
  is visible here — `spark doctor` gates the PR, not just a request to do it right.
- The agent and CLI extension sections: accurate and appropriately scoped.
- The ROADMAP and accuracy-flags references in "Fix a known gap": exactly right.
  The philosophy approves of this self-honest posture.
