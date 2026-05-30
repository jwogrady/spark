# Feedback from 03 (Skeptic) → 01 (Hero/Skimmer)

> Phase 2 cross-evaluation. Author: jwogrady. All citations trace to 00-ground-truth.md.

---

## Issue 1 — "No drift" is unverified as a runtime property

**Where:** Hook paragraph — "No dependencies, no reinvention, no drift."

The "no drift" leg of that triplet is the weakest. Ground truth (`00-ground-truth.md` —
"One installable, versioned lifecycle carried into every repo") supports the claim that
the *version travels with you*. But drift between the installed plugin version and current
repo usage is not mechanically prevented today — there is no update-lock or
version-pinning per repo. The claim is true as marketing intuition but would mislead a
skeptical reader who asks "how?" either drop "no drift" or restate it as "one versioned
toolkit, less drift" and point at the marketplace pin mechanism.

---

## Issue 2 — Marketplace install is flagged as unverified end-to-end

**Where:** Install block — `/plugin marketplace add jwogrady/spark` / `/plugin install spark`

Ground truth explicitly flags this: "v0.2 open item: validate install end-to-end from a
*published* marketplace (unchecked box)" (`00-ground-truth.md`, ROADMAP section). The
hero presents those two commands as current working install steps with no caveat. That is
technically defensible (the commands exist in README/docs) but a dev who tries them
against a *published* marketplace listing today may find nothing. Add a single-line
qualifier, e.g. "installs from a local clone or Git URL today; marketplace listing coming
in v0.3."

---

## Issue 3 — "13 real agent personas collaborate through shared notes" — narrow but accurate

**Where:** Hook sentence referencing docit.

Ground truth confirms 13 `.md` files under `agents/docit/` and coordination through
`.docit-notes/`. This specific claim is clean. No change required — noting it as checked
so 01 does not over-correct it away in revision.

---

## Issue 4 — The hook implies Spark replaces or supersedes raw Claude Code

**Where:** "No dependencies, no reinvention" followed immediately by the lifecycle list.

A skeptic reading the hook could conclude Spark *replaces* base Claude Code. Ground truth
is explicit that Spark is *additive* and reuses `/code-review`, `/security-review`,
`verify` ("Additive by design"). The hero should make the additive relationship explicit
above the fold — even one clause like "built on top of Claude Code, not instead of it."
Without that, my positioning note (03) must do the corrective work, which creates
inconsistency between the hook and the comparison table.

---

## No structural objections

The rest of the hero's claims are cited correctly against ground truth and match what I
rely on for my comparison table. Install commands, the lifecycle string, and the CLI
validation claim all check out.
