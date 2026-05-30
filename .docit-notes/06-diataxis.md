# Docit Note — 06 Coach (Diátaxis Plan)

## Persona

The Coach teaches the tool in depth. The question I ask is: **does each doc serve exactly one reader need — learning, task completion, information lookup, or understanding — and never blend them?** I map Spark's verified capabilities onto the four Diátaxis modes, audit the current docs tree for gaps and mode drift, and produce a plan that downstream personas (07 Contributor, 08 Visual Storyteller) can extend without confusion.

---

## Neighbors

- **Upstream (I read):** `00-ground-truth.md` (verified fact base), `02-quickstart.md` (not yet present — gap noted), `05-philosophy.md` (not yet present — gap noted).
- **Downstream (read me):** `07-contributing.md`, `08-visuals.md`.

---

## Draft

### Diátaxis audit — Spark docs tree

The ground truth confirms the following docs exist under `docs/` (source: `00-ground-truth.md`, "Docs (Diátaxis)" section, confirmed by `find docs/ -type f | sort`):

```
docs/tutorials/build-your-first-project.md
docs/how-to/{install,ideate,plan,build,solve,ship,bootstrap,connect,review}.md
docs/reference/{skills,hooks,cli,plugin-manifest}.md
docs/explanation/{sdlc-doctrine,scope-and-upstream,why-a-plugin}.md
docs/adr/0001..0003, docs/glossary.md, docs/architecture/spark-internals.md
```

Each mode is assessed below.

---

#### Mode 1 — Tutorials (learning-oriented)

**What exists (verified):** `docs/tutorials/build-your-first-project.md` (source: `00-ground-truth.md` §Docs; confirmed by `find docs/ -type f`)

**Assessment:** One tutorial. It walks a beginner through all five lifecycle stages once, end-to-end, correctly declared as "learning-oriented" in its own header callout. Structure is appropriate: follows a fixed narrative path, avoids branching, and ends with a concrete success state (an open PR). No choices are presented to the learner. Confirms it links to `how-to/install.md` for the prerequisite, not duplicating install steps.

**Gaps (recommended additions):**
- **No tutorial for setup skills (HIGH — blocks "start from nothing" path).** A reader who wants to run `bootstrap` or `connect` for the first time has no guided lesson; they land in how-to guides that assume prior knowledge. Recommended: `docs/tutorials/set-up-a-new-project.md` covering `bootstrap` → `connect` → `install-git-hooks` → `doctor`. This should be Tutorial 1 (prerequisite), with the existing `build-your-first-project.md` as Tutorial 2. Source: `00-ground-truth.md` §Setup/inception skills.
- **No tutorial for the knowledge/authorship skills** (`codify`, `docit`). These are non-trivial multi-agent workflows; a first-timer needs a guided lesson, not just a how-to. Lower priority — these are advanced skills, not on the beginner path.

---

#### Mode 2 — How-to guides (task-oriented)

**What exists (verified):** Nine guides — install, ideate, plan, build, solve, ship, bootstrap, connect, review (source: `00-ground-truth.md` §Docs; `find docs/how-to/ -type f`)

**Assessment:** Coverage maps one-to-one with the core lifecycle + two setup skills. Mode hygiene is good: guides are declared task-oriented and are scoped to specific goals. The `review` guide covers the `review` skill; `solve` covers `fix-issue`. This is a sound split.

**Note on partial coverage outside the Diátaxis tree:** A `CONTRIBUTING.md` exists at the repo root (verified by `ls /home/jwogrady/code/st26/spark/CONTRIBUTING.md`; source: 07-contributing cross-eval) covering branch naming, conventional commit rules, and skill-proposal workflow. These topics have partial coverage for contributors, but `CONTRIBUTING.md` is not in the `docs/how-to/` tree and will not be found by a reader navigating by Diátaxis mode.

**Gaps (recommended additions):**
- **No `commit` how-to (HIGH — quickstart sends users to `/spark:commit` with no task guide).** `commit` is a distinct Stage 5a skill (`skills/commit/SKILL.md`; source: `00-ground-truth.md` §Lifecycle skills). The existing `docs/how-to/ship.md` covers both the `/spark:commit` phase (steps 1-4) and the `/spark:ship` phase (steps 5-7) in one guide — verified by reading `docs/how-to/ship.md`. That conflation blurs two discrete tasks and buries the `commit` workflow inside `ship.md`. Recommended: `docs/how-to/commit.md` covering Stage 5a alone.
- **No `write-a-skill` how-to (Medium — partially covered by `CONTRIBUTING.md`; BLOCKED by layout inconsistency — see Reference gaps).** The `write-a-skill` skill exists (`skills/write-a-skill/SKILL.md`; source: `00-ground-truth.md` §Setup/inception skills) but there is no `docs/how-to/write-a-skill.md`. The `write-a-skill` how-to cannot be written until the canonical optional skill layout is decided (see Reference gap: "canonical skill layout spec needed").
- **No `docit` or `codify` how-to (Medium — implicit promise has no landing page).** Two of the more complex skills have no how-to. The hero promise of "13-agent crew" and "6-agent internal-knowledge crew" leaves no task-oriented landing page for a user who finishes their first Ideate→Ship cycle and wants to use these skills. Stubs linking to the SKILL.md frontmatter would suffice as a first pass. Source: `00-ground-truth.md` §Review/knowledge skills.
- **No `fork-init` how-to (Low).** The skill exists and has a distinct use case (seed a new repo from Spark; source: `00-ground-truth.md` §Setup/inception skills), but it has no guide. Low priority — niche use case.

---

#### Mode 3 — Reference (information-oriented)

**What exists (verified):** `docs/reference/{skills,hooks,cli,plugin-manifest}.md` (source: `00-ground-truth.md` §Docs; `find docs/reference/ -type f`)

**Assessment:** Four reference pages covering the four primary machinery surfaces. Mode hygiene needs verification — reference must be dry and complete, with no tutorial narrative or opinion. A spot-check of `docs/reference/skills.md` shows it opens with an appropriate "information-oriented" declaration and uses tables. `docs/reference/cli.md` and `docs/reference/hooks.md` similarly exist.

**Actual docs tree (verified):** The following are outside the four-mode tree — they are siblings of `explanation/`, not nested within it (source: `00-ground-truth.md` §Docs; `docs/README.md` Architecture & Decisions section, verified by reading):
```
docs/
├── tutorials/
├── how-to/
├── reference/
├── explanation/
├── adr/                # outside mode tree — recommend cross-linking from explanation/
├── architecture/       # outside mode tree — recommend cross-linking from explanation/
└── glossary.md         # outside mode tree — recommend cross-linking from reference/
```
`docs/README.md` already acknowledges `adr/` and `architecture/` as separate sections (the "Architecture & decisions" table row). The glossary is linked from `docs/README.md` under that same row.

**Gaps (recommended additions):**
- **`list-skills` omitted from CLI reference (Low — accuracy fix).** Verified by reading `docs/reference/cli.md`: `spark list-skills` is not documented there. The subcommand is a real dispatch case in `bin/spark` (source: `00-ground-truth.md` §Accuracy flags; confirmed by reading `docs/reference/cli.md`). The CLI reference should add a `spark list-skills` entry.
- **No reference page for agent frontmatter (Medium — plugin authors lack authoritative spec).** Skills and agents share a frontmatter schema (per `00-ground-truth.md` §Lifecycle skills verification method). There is no `docs/reference/agent-frontmatter.md` or equivalent. Plugin authors who write agents have no single source of truth for required vs. optional keys.
- **Canonical skill layout spec needed (HIGH — BLOCKING `write-a-skill` how-to).** `CONTRIBUTING.md` §"Proposing a skill" specifies optional subdirs as `references/` and `agents/`; `skills/write-a-skill/SKILL.md` specifies `REFERENCE.md`, `EXAMPLES.md`, `scripts/`. These are two different optional-structure specs in the same repo. The `write-a-skill` how-to and any agent-frontmatter reference cannot be written accurately until the canonical layout is decided. Source: cross-eval from 07-contributor; `CONTRIBUTING.md` and `skills/write-a-skill/SKILL.md` — not resolved in `00-ground-truth.md`.

---

#### Mode 4 — Explanation (understanding-oriented)

**What exists (verified):** `docs/explanation/{sdlc-doctrine,scope-and-upstream,why-a-plugin}.md`, `docs/adr/0001..0003` (source: `00-ground-truth.md` §Docs)

**Assessment:** Three explanation docs plus three ADRs. The ADR format is explanation-compatible (they explain *why* a decision was made), but the ADR directory sits outside `docs/explanation/` as a sibling (see Mode 3 corrected tree). `docs/README.md` surfaces the ADRs in an "Architecture & decisions" table row — so they are not entirely hidden, but they are not reachable via the Explanation mode directory alone. The three explanation docs are well-scoped:
- `sdlc-doctrine.md` — why these five stages in this order.
- `scope-and-upstream.md` — why additive, not reinventing Anthropic's spec.
- `why-a-plugin.md` — why plugin vs. convention doc.

**Gaps (recommended additions):**
- **No `docs/explanation/enforcement-model.md` (BLOCKING — philosophy prerequisite).** The guardrails (PreToolUse hook, `commit-msg`, `pre-commit`) are a genuine differentiator (`00-ground-truth.md` §Genuine differentiators). No explanation doc addresses *why* mechanical enforcement was chosen over advisory rules. This is a blocking prerequisite: `docs/PHILOSOPHY.md` philosophy principle 1 ("enforcement over aspiration") will have no supporting rationale doc if this file does not exist before the philosophy ships. ADR-0003 covers zero-dependency Bash but does not explain the enforcement-as-policy decision. Issue Council must treat this as a prerequisite issue. Source: `00-ground-truth.md` §Genuine differentiators; cross-eval from 05-believer.
- **No `docs/explanation/authorship-crews.md` (High — required for mode-correct linking from philosophy).** The multi-persona subagent design (`docit` 13 agents, `codify` 6 agents) is architecturally significant. `docs/PHILOSOPHY.md` principle 6 ("honest attribution, honest hype") names the docit crew as a mechanism. Without an explanation doc for the crew design, the philosophy would have to link to a how-to (task-oriented) rather than an explanation (understanding-oriented) — a Diátaxis mode violation. Source: `00-ground-truth.md` §Review/knowledge skills; cross-eval from 05-believer.
- **`docs/PHILOSOPHY.md` placement (cross-link required when it ships).** The docit crew is producing `docs/PHILOSOPHY.md`. It is an explanation-mode document (understanding-oriented, values statement). When it ships it must be cross-linked from `docs/explanation/` (either as a direct file there, or as a cross-link) and added to the `docs/README.md` navigation table (currently four rows — the philosophy belongs under Explanation or as its own row). If this is not done, the philosophy doc will be orphaned. Source: cross-eval from 05-believer.
- **ADRs not reachable via explanation mode navigation (Low — discoverability).** `docs/explanation/` has no index or README. Readers navigating to `docs/explanation/` via the `docs/README.md` table will not see the ADRs. Recommend a cross-link from `docs/explanation/` to `docs/adr/`.

---

### Cross-mode navigation (structural recommendation)

`docs/README.md` exists and was verified by reading it (Phase 3). It contains a well-formed Diátaxis navigation table with four mode rows plus an "Architecture & decisions" row that cross-links `docs/adr/` and `docs/architecture/spark-internals.md`. The glossary is linked from this table. The cross-mode navigation requirement is substantially met.

Remaining recommendation: the main `README.md` should include a brief "Documentation" section pointing to `docs/README.md` rather than duplicating the full tree. The Visual Storyteller's asset #6 (docs-tree ASCII) is appropriate for `docs/README.md` enhancement if needed, but redundant for the main README.

When `docs/PHILOSOPHY.md` ships it must be added to the `docs/README.md` navigation table (currently four mode rows + one architecture row). Source: verified by reading `docs/README.md`.

---

### Priority gaps summary (for Issue Council)

| Gap | Mode | Severity | Notes |
|---|---|---|---|
| No enforcement-model explanation doc (`docs/explanation/enforcement-model.md`) | Explanation | **BLOCKING** — philosophy prerequisite | Philosophy principle 1 has no rationale doc; must exist before `docs/PHILOSOPHY.md` ships |
| No `set-up-a-new-project` tutorial | Tutorial | High — blocks "start from nothing" path | Should be Tutorial 1 (prerequisite); `build-your-first-project.md` becomes Tutorial 2 |
| Canonical skill layout spec needed | Reference | High — **blocks** `write-a-skill` how-to | `CONTRIBUTING.md` vs. `write-a-skill/SKILL.md` specify different optional subdir layouts; must be resolved first |
| No `commit` how-to | How-to | High — quickstart sends users to `/spark:commit` with no task guide | `ship.md` absorbs commit steps but blurs two distinct Stage 5a/5b skills |
| No `authorship-crews` explanation doc (`docs/explanation/authorship-crews.md`) | Explanation | High — required for mode-correct linking from philosophy | Without it, philosophy principle 6 must link to a how-to (mode violation) |
| No agent-frontmatter reference | Reference | Medium — plugin authors lack an authoritative spec | Blocked partially by canonical layout inconsistency |
| No `write-a-skill` how-to | How-to | Medium — partially covered by `CONTRIBUTING.md` | Blocked by canonical layout inconsistency (see above) |
| No `docit`/`codify` how-to | How-to | Medium — implicit promise has no landing page | Stubs linking to SKILL.md frontmatter acceptable as first pass |
| `docs/PHILOSOPHY.md` cross-link required when it ships | Explanation | Medium — will be orphaned otherwise | Add to `docs/README.md` navigation table |
| `list-skills` missing from CLI reference | Reference | Low — accuracy fix | Verified by reading `docs/reference/cli.md` |
| `spark-internals.md` outside the mode tree | Explanation/Reference | Low — discoverability | `docs/README.md` already surfaces it under "Architecture & decisions" |
| ADRs not reachable via explanation mode navigation | Explanation | Low — discoverability | Add cross-link from `docs/explanation/` to `docs/adr/` |
| No `fork-init` how-to | How-to | Low — niche use case | Skill exists; no guide |

---

## Claims & citations

| Claim | Source |
|---|---|
| One tutorial exists: `docs/tutorials/build-your-first-project.md` | `00-ground-truth.md` §Docs; confirmed by `find docs/ -type f` |
| Nine how-to guides exist covering install + lifecycle stages + bootstrap + connect + review | `00-ground-truth.md` §Docs |
| Four reference pages exist: skills, hooks, cli, plugin-manifest | `00-ground-truth.md` §Docs |
| Three explanation docs exist: sdlc-doctrine, scope-and-upstream, why-a-plugin | `00-ground-truth.md` §Docs |
| ADRs 0001–0003 exist under `docs/adr/` | `00-ground-truth.md` §Docs |
| `list-skills` is absent from `docs/reference/cli.md` | Verified by reading `docs/reference/cli.md` (Phase 3) |
| `docs/how-to/ship.md` absorbs both commit (steps 1-4) and ship (steps 5-7) in one guide | Verified by reading `docs/how-to/ship.md` (Phase 3) |
| `docs/README.md` has a mode-organized navigation table (four mode rows + architecture row) | Verified by reading `docs/README.md` (Phase 3) |
| `docs/adr/` and `docs/architecture/` are siblings of `explanation/`, not nested within it | Verified by reading `docs/README.md` and `00-ground-truth.md` §Docs |
| PreToolUse guard + commit-msg + pre-commit are mechanical enforcement differentiators | `00-ground-truth.md` §Genuine differentiators |
| `write-a-skill` skill exists | `00-ground-truth.md` §Setup/inception skills |
| `docit` (13 agents) and `codify` (6 agents) crews exist | `00-ground-truth.md` §Review/knowledge skills |
| `fork-init` skill exists | `00-ground-truth.md` §Setup/inception skills |
| `CONTRIBUTING.md` exists at repo root, covering branch naming, commit rules, skill proposal | Cross-eval from 07-contributor; verified path `CONTRIBUTING.md` |
| Two conflicting optional skill layout specs: `CONTRIBUTING.md` (`references/`, `agents/`) vs. `write-a-skill/SKILL.md` (`REFERENCE.md`, `EXAMPLES.md`, `scripts/`) | Cross-eval from 07-contributor; `CONTRIBUTING.md` §"Proposing a skill"; `skills/write-a-skill/SKILL.md` |

---

## Cross-eval feedback

### from-00 (Cartographer) — RESOLVED ×3

**Item 1:** "likely absorbs it" re `commit` — unverified assumption.
RESOLVED: Read `docs/how-to/ship.md`. It covers both the `/spark:commit` phase (steps 1-4) and the `/spark:ship` phase (steps 5-7) in one guide. Revised Mode 2 wording to state as fact: no standalone `commit.md` exists; `ship.md` absorbs both tasks — which itself blurs two distinct workflows and remains a gap. Dropped "likely."

**Item 2:** `docs/README.md` content deferred — must verify before shipping navigation recommendation.
RESOLVED: Read `docs/README.md`. It contains a well-formed Diátaxis navigation table (tutorials, how-to, reference, explanation) plus an Architecture & Decisions section cross-linking `adr/` and `docs/architecture/spark-internals.md`. The cross-mode navigation requirement is substantially met. The `docs/README.md` correctly acknowledges that `adr/` and `architecture/` sit outside the four-mode tree. Updated the navigation section accordingly.

**Item 3:** `list-skills` missing from CLI reference — asserted from README flag, not from reading the actual reference page.
RESOLVED: Read `docs/reference/cli.md`. Confirmed: `spark list-skills` is not documented there. The gap stands. Updated Mode 3 claim to cite `docs/reference/cli.md` directly (not the README accuracy flag).

---

### from-02 (Adopter) — RESOLVED ×3

**Item 1:** `commit` how-to gap severity: MEDIUM → HIGH (quickstart sends users to `/spark:commit` but no task guide exists).
RESOLVED: Elevated `commit` how-to severity to High in the priority gaps table. The fact that `ship.md` absorbs the commit steps partially mitigates but does not eliminate the gap — `commit` is a distinct Stage 5a skill with its own invocation (`skills/commit/SKILL.md`).

**Item 2:** `docit`/`codify` how-to stubs needed — promise has no landing page.
RESOLVED: Retained at Medium severity. Added explicit note that these gaps leave an implicit promise ("13-agent crew") without a landing page. The Issue Council should treat creation of stub guides as a quick win.

**Item 3:** Setup-skills tutorial (bootstrap → connect → hooks → doctor) should be the *prerequisite* tutorial, before `build-your-first-project.md`.
RESOLVED: Updated the tutorial gap entry to reflect this sequencing recommendation — the setup tutorial should be positioned as Tutorial 1 ("Tutorial: Set up a new project"), with the existing `build-your-first-project.md` as Tutorial 2.

---

### from-05 (Believer) — RESOLVED ×3

**Item 1:** Enforcement-model explanation gap is philosophy-blocking — must exist before `docs/PHILOSOPHY.md` ships.
RESOLVED: Elevated `enforcement-model.md` from "High" to **Blocking (philosophy-prerequisite)** in the priority gaps table. Added explicit note: if this doc does not exist when `docs/PHILOSOPHY.md` is published, philosophy principle 1 ("enforcement over aspiration") has no supporting rationale doc. Flagged for Issue Council as a prerequisite.

**Item 2:** Authorship-crews explanation gap causes mode violation — philosophy principle 6 would have to link to a how-to (task-oriented) rather than an explanation (understanding-oriented).
RESOLVED: Added `docs/explanation/authorship-crews.md` as an explicit target in the Mode 4 gaps. Updated note: required for mode-correct linking from `docs/PHILOSOPHY.md` principle 6.

**Item 3:** `docs/PHILOSOPHY.md` placement not addressed — will be orphaned if not cross-linked.
RESOLVED: Added a new entry to the explanation-mode section: `docs/PHILOSOPHY.md` is an explanation-mode document (understanding-oriented, values statement). When it ships it must be cross-linked from `docs/explanation/` and from the `docs/README.md` navigation table (the table currently has four rows; `PHILOSOPHY.md` belongs under Explanation or as its own row). Issue Council should track this as a cross-link requirement, not a new doc.

---

### from-07 (Contributor) — RESOLVED ×2

**Item 1 (BLOCKING):** Two conflicting optional skill layout specs — `CONTRIBUTING.md` uses `references/`/`agents/` subdirs; `skills/write-a-skill/SKILL.md` uses `REFERENCE.md`/`EXAMPLES.md`/`scripts/`. The `write-a-skill` how-to cannot be written until the canonical layout is decided.
RESOLVED: Added to the priority gaps table as a new Reference entry, severity High, tagged: "canonical skill layout spec required before `write-a-skill` how-to can be written." Flagged for Issue Council as a blocking inconsistency.

**Item 2:** `CONTRIBUTING.md` exists at repo root — gaps are real but narrower than stated; commit and skill-authorship workflows are partially covered there.
RESOLVED: Added a note to Mode 2 (How-to): "A `CONTRIBUTING.md` exists at the repo root covering branch naming, commit rules, and skill proposal. These topics have partial coverage outside the Diátaxis tree; gaps are real but narrower than the absence of formal how-to files implies." Revised `write-a-skill` how-to severity from High to Medium (how-to gap) with High reserved for the canonical-layout inconsistency.

---

### from-08 (Visual Storyteller) — RESOLVED ×4

**Item 1:** Docs-tree ASCII in `08-visuals.md` wrongly nests `adr/` and `architecture/` under `explanation/`. Need corrected tree.
RESOLVED: Produced corrected tree in the Mode 3/4 sections and in the navigation section. Actual structure: `docs/adr/` and `docs/architecture/` are siblings of `explanation/`, not children. `docs/README.md` already acknowledges this. The corrected tree (for 08's use in Phase 3):

```
docs/
├── tutorials/
├── how-to/
├── reference/
├── explanation/
├── adr/                # outside mode tree — recommend cross-linking from explanation/
├── architecture/       # outside mode tree — recommend moving or cross-linking from explanation/
└── glossary.md         # outside mode tree — recommend cross-linking from reference/
```

**Item 2:** Current-state vs. recommendation separation unclear in mode sections.
RESOLVED: Restructured each mode section to use explicit "What exists (verified)" and "Gaps (recommended additions)" sub-headers. This ensures downstream personas (aggregators, editor, visual storyteller) can safely distinguish fact from proposal.

**Item 3:** No visual placement guidance for docs section in README.
RESOLVED: `docs/README.md` already serves as the Diátaxis index (verified by reading it — it has a navigation table). Recommending that the main `README.md` include a brief "Documentation" section with a single pointer to `docs/README.md`, rather than repeating the full tree. Asset #6 (docs-tree ASCII) is better placed in `docs/README.md` or dropped from the main README — the main README should stay concise.

**Item 4:** `docs/README.md` content deferred — blocks visual plan.
RESOLVED (same as Cartographer item 2): `docs/README.md` has a mode-organized navigation table. It is the correct anchor for the Diátaxis index. Main README can point to it. Asset #6 is now confirmed as redundant for the main README; 08 should retain it only for `docs/README.md` enhancement if needed.
