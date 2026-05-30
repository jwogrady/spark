# Cross-eval feedback: from 07 (Contributor) to 05 (Philosophy/Believer)

**Reviewer:** Persona 07 — Contributor
**Reviewed:** `05-philosophy.md`

---

## Overall assessment

05 is grounded and honest. Every principle ties to a shipped feature with a
verified citation. No untethered manifesto claims. The draft is safe to carry
forward with the targeted corrections below.

---

## Specific issues

### 1. Principle 3 (Additive) mismatch — extension path uses `write-a-skill`, not just routed commands

**Location:** "3. Additive by design." paragraph.

**Issue:** The Believer describes "additive" solely from the user-facing angle
(Spark routes to `/code-review`, etc. instead of reinventing them). This is
accurate, but the extension path (07's territory) adds a second dimension of
"additive": a contributor adds new skills alongside the existing toolkit rather
than patching the core. That contributor lens is absent from the principle
statement, which matters because downstream readers who want to extend Spark
may not see themselves reflected in principle 3 as written.

**Recommendation:** Add one sentence to principle 3 acknowledging that the same
additive design applies to contributors — new skills sit alongside the lifecycle,
not inside it. Example: "The same logic governs contributions: a new skill is
additive, not a patch to the core lifecycle." This aligns doctrine with the
extension path without changing the core claim.

**Ground-truth anchor:** `00-ground-truth.md` §"Skill Authoring" (`CLAUDE.md`)
and `skills/write-a-skill/SKILL.md` — skills are self-contained, no cross-skill
imports at runtime.

---

### 2. Principle 6 (Honest attribution) omits the issue-first gate

**Location:** "6. Honest attribution, honest hype." paragraph.

**Issue:** Principle 6 focuses on attribution enforcement (commit-msg hook, docit
honest-hype contract). This is correct. However, `CONTRIBUTING.md` adds an
under-stated gate: skills must have a GitHub issue opened (via the Skill template)
and feedback received *before* any code is written. This is also a "honest hype"
mechanism — it prevents unvetted features from landing. The principle doesn't
mention it, creating a gap between the doctrine and the actual gates a contributor
faces.

**Recommendation:** Either widen principle 6 to cover the issue-first gate, or
add a brief principle 7 for "issue-first, not code-first" discipline. If the
Believer considers this out of scope for philosophy, flag it as a cross-reference
to the Contributor note.

**Ground-truth anchor:** `CONTRIBUTING.md` §"Proposing a skill" — step 1 is
"Open a GitHub issue…"; step 2 is "Get feedback before writing anything."

---

### 3. No contradiction, but a terminology gap that affects the Contributor

**Location:** Principle 2 ("One lifecycle, portable.") and principle 4 ("Scoped
work as the unit of discipline.").

**Issue:** The Believer uses "one concern per PR" and the branch discipline
language correctly. The Contributor note uses the same terms. No contradiction.
However, neither note names the branch naming convention (`feat/`, `fix/`,
`docs/`, `chore/`) that is in `CONTRIBUTING.md`. This is minor — it is reference
material, not philosophy — but the 07 draft cites `CLAUDE.md` §"Development
Workflow" for branch discipline rather than `CONTRIBUTING.md`, which is the
canonical source. No action required on 05; flagged for 07's own revision.

---

## No blocking issues

05 does not over-promise, does not contradict ground truth, and its claims table
is fully cited. The two items above are additive improvements, not corrections of
errors.
