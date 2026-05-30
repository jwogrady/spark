# docsmith — lens specifications

Detailed mission, tasks, required reads, and outputs for each audience lens.
Every lens writes one markdown file to `.docsmith-notes/`. The Editor-in-Chief
assembles the final docs from these notes.

The binding constraint for every lens: **claim only what the Cartographer
verified.** Cite `00-ground-truth.md` for any concrete capability.

---

## Lens 00 — Cartographer (ground truth)

**Mission:** Record what the project actually is and does — the factual substrate
every other lens draws from.

**Tasks:**
- Read the existing README, CLAUDE.md / AGENTS.md, and any `docs/`.
- Enumerate real capabilities: skills, commands, the CLI surface, hooks, manifests.
- Identify the lifecycle / core workflow the project enforces.
- Capture exact install and usage steps — run or trace them; do not guess.
- Name genuine differentiators (what it does that the obvious alternative doesn't).
- Separate **shipped** from **aspirational** — aspirations are roadmap, not features.

**Required reads:** none (first lens).

**Outputs to `.docsmith-notes/00-ground-truth.md`:**
- One-paragraph "what this is."
- Verified capability list (each with a file/command citation).
- The lifecycle / core flow.
- Exact install + first-use commands.
- Real differentiators vs. the obvious alternative.
- Shipped-vs-roadmap split.

**Notes to next lens:** flag anything currently overclaimed or out of date in the
existing docs.

---

## Lens 01 — The Skimmer (hero)

**Mission:** Win the first 10 seconds. A dev is scrolling GitHub; the top of the
README decides whether they keep reading.

**Tasks:**
- Draft the project name treatment and a one-line tagline (what + why, no jargon).
- Write the hook: 2–3 sentences that make the problem and the payoff land.
- Propose the above-the-fold block (tagline, one-liner, optional badges, optional
  one visual/diagram) — ruthless about length.

**Required reads:** `00-ground-truth.md`.

**Outputs to `.docsmith-notes/01-hero.md`:** tagline options, the hook, the
above-the-fold layout.

**Notes to next lens:** the promise the hero makes (the Adopter must let the reader
deliver on it fast).

---

## Lens 02 — The Adopter (install + quickstart)

**Mission:** Get a newcomer from zero to first value in minutes, with copy-paste
commands that actually work.

**Tasks:**
- Write install steps verbatim from ground truth (no invented flags).
- Write a quickstart that produces a visible first win.
- Note prerequisites honestly; call out anything that could trip a newcomer.

**Required reads:** `00-ground-truth.md`, `01-hero.md`.

**Outputs to `.docsmith-notes/02-quickstart.md`:** install block, quickstart walk-
through, prerequisites.

**Notes to next lens:** what the reader can now do (the Skeptic contrasts this with
alternatives).

---

## Lens 03 — The Skeptic (positioning)

**Mission:** Answer "why not just use the raw tool / what I already have?"

**Tasks:**
- Name the honest alternative(s).
- Build a tight comparison (table or prose) on the axes that matter to a dev.
- State the delta plainly; concede where the alternative is fine.

**Required reads:** `00-ground-truth.md`, `01-hero.md`, `02-quickstart.md`.

**Outputs to `.docsmith-notes/03-positioning.md`:** alternatives, comparison,
the one-sentence "use this when…".

**Notes to next lens:** the worldview implied by the positioning (the Believer
expands it).

---

## Lens 04 — The Believer (philosophy / motivation)

**Mission:** Say what the project stands for — the reason it exists and the future
it argues for.

**Tasks:**
- Articulate the problem the project refuses to accept.
- State the doctrine / principles in the author's voice.
- Connect philosophy back to concrete features (no untethered manifesto).

**Required reads:** `00-ground-truth.md`, `03-positioning.md`.

**Outputs to `.docsmith-notes/04-philosophy.md`:** motivation, principles,
the philosophy doc draft (`docs/PHILOSOPHY.md`).

**Notes to next lens:** the contribution invitation implied by the philosophy.

---

## Lens 05 — The Contributor (extension path)

**Mission:** Show a motivated dev exactly how to extend or contribute.

**Tasks:**
- Describe how the project is extended (e.g. authoring a skill) from ground truth.
- Point to the first good contribution and the standards that gate it.
- Keep it actionable, not boilerplate.

**Required reads:** `00-ground-truth.md`, `04-philosophy.md`.

**Outputs to `.docsmith-notes/05-contributing.md`:** extension path, standards,
"start here" pointer.

**Notes to next lens:** the single most tweetable thing about the project.

---

## Lens 06 — The Amplifier (launch copy)

**Mission:** Produce ready-to-post hype — and nothing the project can't back up.

**Tasks:**
- Write the GitHub repo description (≤350 chars) and a topics/tags list.
- Draft a short tweet/X thread, an HN/Show HN title + blurb, and a Reddit post.
- Keep every claim traceable to ground truth.

**Required reads:** `00-ground-truth.md` plus all prior notes.

**Outputs to `.docsmith-notes/06-launch.md`:** repo description, topics, post-ready
copy → assembled into `docs/launch-copy.md`.

**Notes to next lens:** which claims are load-bearing and must be verified before posting.

---

## Lens 07 — Editor-in-Chief (synthesis)

**Mission:** Assemble the final docs as one confident human voice.

**Tasks:**
- Read every lens note.
- Verify each claim traces to `00-ground-truth.md`; cut or soften anything that doesn't.
- Assemble `README.md` (hero → quickstart → positioning → contributing → philosophy link).
- Finalize `docs/PHILOSOPHY.md` and `docs/launch-copy.md`.
- Enforce voice, remove duplication, ensure `jwogrady`-only attribution.
- Present a diff to the user before overwriting existing docs.

**Required reads:** `00`–`06`.

**Outputs:** final `README.md`, `docs/PHILOSOPHY.md`, `docs/launch-copy.md`, and
`.docsmith-notes/07-editor-log.md` (what was cut/softened and why).
