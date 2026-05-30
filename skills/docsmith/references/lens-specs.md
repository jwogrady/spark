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

**Notes to next lens:** the maturity questions a skeptic will ask next (for the
Evaluator).

---

## Lens 04 — The Evaluator (trust & maturity)

**Mission:** Reassure a senior dev or tech lead deciding whether to bet a team on
it — "is this alive, maintained, and safe to depend on?"

**Tasks:**
- Inventory trust signals from the repo: license, CI workflows, test presence,
  release/tag cadence, issue/PR activity, security posture, supported versions.
- Propose the README badge row (only badges that reflect real, current state).
- Surface honest maturity caveats (pre-1.0, breaking-change policy) rather than hide them.

**Required reads:** `00-ground-truth.md`, `03-positioning.md`.

**Outputs to `.docsmith-notes/04-trust.md`:** trust-signal inventory, badge row,
maturity statement.

**Notes to next lens:** the values the trust signals imply (for the Believer).

---

## Lens 05 — The Believer (philosophy / motivation)

**Mission:** Say what the project stands for — the reason it exists and the future
it argues for.

**Tasks:**
- Articulate the problem the project refuses to accept.
- State the doctrine / principles in the author's voice.
- Connect philosophy back to concrete features (no untethered manifesto).

**Required reads:** `00-ground-truth.md`, `03-positioning.md`, `04-trust.md`.

**Outputs to `.docsmith-notes/05-philosophy.md`:** motivation, principles,
the philosophy doc draft (`docs/PHILOSOPHY.md`).

**Notes to next lens:** which principles should shape the teaching docs (for the Coach).

---

## Lens 06 — The Coach (Diátaxis docs)

**Mission:** Teach the tool in depth by producing the four
[Diátaxis](https://diataxis.fr/) documentation modes, each serving a distinct need.
Keep the modes separate — do not blend a tutorial with reference, or a how-to with
explanation.

**The four modes:**
- **Tutorials** (`docs/tutorials/`) — *learning-oriented.* A guided lesson that
  takes a beginner by the hand to a successful first result. Concrete, repeatable,
  no choices to make.
- **How-to guides** (`docs/how-to/`) — *task-oriented.* Steps to accomplish a
  specific real-world goal for someone who already knows the basics.
- **Reference** (`docs/reference/`) — *information-oriented.* Dry, accurate,
  complete description of the machinery (commands, skills, flags, config). No
  teaching, no opinion.
- **Explanation** (`docs/explanation/`) — *understanding-oriented.* Discursive
  prose on the why and the how-it-fits. Links to (does not duplicate) the
  philosophy doc.

**Tasks:**
- Map ground-truth capabilities onto the four modes; note gaps where a doc is missing.
- Draft or outline at least one doc per applicable mode.
- Cross-link the modes and the README so readers can navigate by intent.

**Required reads:** `00-ground-truth.md`, `02-quickstart.md`, `05-philosophy.md`.

**Outputs to `.docsmith-notes/06-diataxis.md`:** per-mode doc plan and drafts/outlines
→ files under `docs/tutorials|how-to|reference|explanation/`.

**Notes to next lens:** the extension surface that needs its own how-to (for the
Contributor).

---

## Lens 07 — The Contributor (extension path)

**Mission:** Show a motivated dev exactly how to extend or contribute.

**Tasks:**
- Describe how the project is extended (e.g. authoring a skill) from ground truth.
- Point to the first good contribution and the standards that gate it.
- Keep it actionable, not boilerplate; reuse the Coach's how-to where it fits.

**Required reads:** `00-ground-truth.md`, `05-philosophy.md`, `06-diataxis.md`.

**Outputs to `.docsmith-notes/07-contributing.md`:** extension path, standards,
"start here" pointer.

**Notes to next lens:** the moments that deserve a visual (for the Visual Storyteller).

---

## Lens 08 — The Visual Storyteller (show, don't tell)

**Mission:** Make the README scannable and memorable with visuals — diagrams,
architecture sketches, screenshots/GIFs, and the social-preview image.

**Tasks:**
- Identify where a visual carries more than prose (the lifecycle, the hero, a flow).
- Specify each asset: a Mermaid/ASCII diagram inline, or a described image/GIF to
  capture (alt text included for accessibility).
- Recommend a social-preview image concept (the card shown when the repo is shared).

**Required reads:** `00-ground-truth.md`, `01-hero.md`, `02-quickstart.md`, `06-diataxis.md`.

**Outputs to `.docsmith-notes/08-visuals.md`:** asset list with placement, inline
diagrams (Mermaid/ASCII ready to paste), and capture instructions for image/GIF assets.

**Notes to next lens:** none required; flag any visual that documents a recent change
(for the Returning User).

---

## Lens 09 — The Returning User (changelog / release notes)

**Mission:** Keep existing users engaged — tell them what changed and how to upgrade.

**Tasks:**
- Reconcile `CHANGELOG.md` against ground truth and recent commits.
- Draft the release notes for the pending version (Keep a Changelog format).
- State the upgrade path and any breaking changes plainly.

**Required reads:** `00-ground-truth.md`, `04-trust.md`.

**Outputs to `.docsmith-notes/09-changelog.md`:** changelog/release-note draft,
upgrade notes.

**Notes to next lens:** the headline change worth promoting (for SEO + Amplifier).

---

## Lens 10 — The SEO / Discoverability

**Mission:** Help devs who haven't found the repo yet actually find it.

**Tasks:**
- Extract the keywords and search terms a target dev would type.
- Propose the GitHub repo description (≤350 chars, keyword-rich but honest) and a
  topics/tags list.
- Note awesome-list / directory fit and the social-preview metadata.

**Required reads:** `00-ground-truth.md` plus all prior notes.

**Outputs to `.docsmith-notes/10-discoverability.md`:** keywords, repo description,
topics, awesome-list targets, social-preview metadata.

**Notes to next lens:** the strongest hook phrases (for the Amplifier).

---

## Lens 11 — The Amplifier (launch copy)

**Mission:** Produce ready-to-post hype — and nothing the project can't back up.

**Tasks:**
- Draft a short tweet/X thread, an HN/Show HN title + blurb, and a Reddit post.
- Lead with the headline change (Returning User) and SEO hook phrases.
- Keep every claim traceable to ground truth.

**Required reads:** `00-ground-truth.md` plus all prior notes.

**Outputs to `.docsmith-notes/11-launch.md`:** post-ready copy → assembled with the
SEO note into `docs/launch-copy.md`.

**Notes to next lens:** which claims are load-bearing and must be verified before posting.

---

## Lens 12 — Editor-in-Chief (synthesis)

**Mission:** Assemble the final docs as one confident human voice.

**Tasks:**
- Read every lens note.
- Verify each claim traces to `00-ground-truth.md`; cut or soften anything that doesn't.
- Assemble `README.md` (hero → quickstart → positioning → trust → visuals →
  contributing → links to philosophy and Diátaxis docs).
- Finalize `docs/PHILOSOPHY.md`, the `docs/` Diátaxis tree, `CHANGELOG.md`, and
  `docs/launch-copy.md`.
- Enforce voice, remove duplication, ensure `jwogrady`-only attribution.
- Present a diff to the user before overwriting existing docs.

**Required reads:** `00`–`11`.

**Outputs:** final `README.md`, `docs/PHILOSOPHY.md`, the Diátaxis docs,
`CHANGELOG.md`, `docs/launch-copy.md`, and `.docsmith-notes/12-editor-log.md`
(what was cut/softened and why).
