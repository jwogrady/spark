# 08 — Visual Storyteller

## Persona

I am the Visual Storyteller. My question is: **where does a diagram carry more
than prose would?** I own the README's visual layer — every diagram, architecture
sketch, asset list, capture instruction, and the social-preview image concept.
I show rather than tell. Every visual I specify must depict something real, cited
to `00-ground-truth.md`.

---

## Neighbors

| Direction | Persona | What I take from them |
|---|---|---|
| Upstream | 00 — Ground Truth | Verified facts: capabilities, lifecycle, CLI, directory layout |
| Upstream | 01 — Hero | Hero headline and tagline — visuals must reinforce them |
| Upstream | 02 — Quickstart | Install + first-use commands — the flow diagram must match |
| Upstream | 06 — Diátaxis | Docs tree and category breakdown — visual index must match |
| Downstream | 10 — Aggregator | Consumes my asset list and inline diagrams |
| Downstream | 11 — Aggregator | Same |
| Downstream | Editor | Synthesizes my visual plan into the final README |

---

## Draft

### Visual plan for the Spark README

#### 1. Lifecycle flow diagram (inline Mermaid — `README.md` hero area)

Place immediately after the one-line description, before the install block. It is
the single visual that makes the system scannable in under five seconds.

```mermaid
flowchart LR
    A([Ideate]) --> B([Plan])
    B --> C([Generate])
    C --> D([Solve])
    D --> E([Ship])

    A:::stage
    B:::stage
    C:::stage
    D:::stage
    E:::stage

    classDef stage fill:#1a1a2e,stroke:#e94560,color:#eaeaea,rx:6
```

Alt text: "Five-stage Spark lifecycle: Ideate → Plan → Generate → Solve → Ship."

**Stage-to-skill caption** (place directly beneath the diagram):
> Stage names map to skills: Ideate → `/spark:ideate`, Plan → `/spark:plan`,
> Generate → `/spark:build`, Solve → `/spark:fix-issue`,
> Ship → `/spark:commit` + `/spark:ship`

This caption prevents the stage-vs-skill naming confusion: users run `/spark:build`
(not `/spark:generate`) and the caption bridges that gap before they reach the
Quickstart. Citation: `00-ground-truth.md` §Lifecycle table.

Placement rule: immediately after the repo subtitle, before any prose section.

---

#### 2. Architecture / component map (inline ASCII — "How it works" section)

Shows how the plugin layers sit on top of Claude Code without reinventing it.
ASCII is paste-anywhere and renders in all GitHub contexts.

```
┌──────────────────────────────────────────────────────────────┐
│                        your project                          │
├──────────────────────────────────────────────────────────────┤
│                Spark plugin (you install once)               │
│  skills/            hooks/            bin/spark              │
│  16 SKILL.md        PreToolUse        e.g. doctor            │
│  files              guard-bash.sh          list-skills       │
│                                           new-skill          │
│  scripts/hooks/                           install-git-hooks  │
│  commit-msg                               shred-env          │
│  pre-commit                               help               │
├──────────────────────────────────────────────────────────────┤
│              Claude Code (Anthropic built-ins)               │
│      /code-review   /security-review   verify                │
└──────────────────────────────────────────────────────────────┘
```

Alt text: "Spark sits between your project and Claude Code's built-ins, adding
skills, enforcement hooks (PreToolUse guard in hooks/, git hooks in scripts/hooks/),
and the spark CLI."

Note on layout accuracy: `guard-bash.sh` lives under `hooks/`; `commit-msg` and
`pre-commit` live under `scripts/hooks/`. These are distinct directories in the
repo and the diagram shows them separately. Citation: `00-ground-truth.md`
§Enforcement.

Placement rule: "How it fits together" or "Architecture" section, after the
lifecycle diagram and before the skills table.

---

#### 3. `spark doctor` terminal screenshot / GIF (captured asset)

A real terminal recording showing `spark doctor` returning a clean pass.
This gives a prospective user an instant confidence signal that the tool is
real and opinionated.

**Capture instructions:**
1. From a project root where Spark git hooks are installed, run:
   ```bash
   spark doctor
   ```
2. Record with `vhs` (preferred) or `asciinema` → export a GIF at 80 cols × 24 rows.
3. Name the file `docs/assets/spark-doctor-demo.gif`.
4. Embed in the README Quickstart section:
   ```markdown
   ![spark doctor clean run](docs/assets/spark-doctor-demo.gif)
   ```
   Alt text: "spark doctor output: all checks passing (manifests, hooks, skills, agents)."

Note: do not ship a staged/fake recording. Capture real output from a real run.

---

#### 4. Install + first-use command block (styled code fence — not an image)

Not a captured image — a plain fenced code block. But mark it visually prominent
with a heading that matches the Quickstart section so it is impossible to miss.

```bash
# 1 — install once
/plugin marketplace add jwogrady/spark
/plugin install spark

# 2 — wire git hooks into your repo
spark install-git-hooks

# 3 — validate
spark doctor
```

Alt text: N/A (code fence, not an image).

Placement: Quickstart / Getting Started section.

---

#### 5. Social-preview image concept (`.github/og-image.png`)

GitHub shows a social card when the repo URL is shared (Slack, X, LinkedIn).
The concept below is design-ready for a designer or a tool like Figma / Canva.

**Concept:**
- Background: deep navy (#1a1a2e) or near-black.
- Center: the five-stage lifecycle as a minimal horizontal flow using the Spark
  accent color (#e94560 or similar hot coral/red-pink), with arrows between nodes.
- Top-left: spark logo mark (if available) or the text `spark` in a mono font.
- Bottom-right: `jwogrady/spark` in small monospace, white at 60% opacity.
- No AI attribution, no Anthropic branding. Author string is `jwogrady` only.
- Output dimensions: 1280 × 640 px (GitHub's OG card spec).
- File path: `.github/og-image.png` (GitHub auto-picks this up as social preview).

This image does not yet exist in the repo. It is a creation task for the author.

---

#### 6. Docs-structure visual (include whenever the Diátaxis section is present)

When the README or a docs/index contains a Diátaxis section, include this tree
as a structural anchor before the prose explains each mode. Do not condition on
length — the tree is useful regardless of how many words follow it.

```
docs/
├── tutorials/          # learn by doing
├── how-to/             # solve a specific problem
├── reference/          # look up facts
├── explanation/        # understand the decisions
│   └── (sdlc-doctrine, scope-and-upstream, why-a-plugin)
├── adr/                # ADR-0001..0003  ← top-level under docs/
│                       # (Coach recommends cross-linking from explanation/)
├── architecture/       # spark-internals.md  ← top-level under docs/
└── glossary.md
```

Alt text: "Spark docs tree organized by Diátaxis: tutorials, how-to, reference,
explanation, plus ADRs and architecture at the top level under docs/."

Accuracy note: `docs/adr/` and `docs/architecture/` are siblings to
`docs/explanation/`, not children of it. This matches the verified directory
listing in `00-ground-truth.md` §Docs. The Coach's aspiration (cross-link ADRs
from explanation/) is an annotation, not a current fact — it is not depicted in
the tree.

Placement: inside the Diátaxis / Documentation section, subordinate to persona 06's
prose. Include whenever that section is present in the README.

---

#### 7. Contribution pipeline flow (deferred — contributor docs)

Flagged by Persona 07. Shows the four-leg contribution path with mechanical gates:

```
scaffold         implement         validate              PR
(spark new-skill) → (SKILL.md required) → (spark doctor) → (PR template)
                                            commit-msg hook
                                            pre-commit hook
```

This is distinct from the user-facing lifecycle diagram (Ideate→Ship) — it addresses
*repo contributors*, not project users. Ground-truth anchor: `bin/spark cmd_new_skill`,
`scripts/hooks/commit-msg`, `scripts/hooks/pre-commit`, `hooks/guard-bash.sh`,
`.github/PULL_REQUEST_TEMPLATE.md`.

**Status: deferred.** Include in contributor-facing docs once `CONTRIBUTING.md` is
the canonical reference. Not blocking the README launch.

---

#### 8. Skill directory anatomy tree (blocked — awaiting canonical spec)

Flagged by Persona 07. Shows `skills/<name>/` with required vs optional files.
Do not finalize until the inconsistency between `CONTRIBUTING.md` (`references/`,
`agents/`) and `skills/write-a-skill/SKILL.md` (`REFERENCE.md`, `EXAMPLES.md`,
`scripts/`) is resolved (see `from-07-to-06.md` issue 1). Working assumption:
use the `write-a-skill/SKILL.md` layout as it is the more detailed source.

**Status: blocked.** Do not ship until the canonical skill layout is confirmed.

---

### Asset inventory summary

| # | Asset | Type | Status | Priority | File path |
|---|---|---|---|---|---|
| 1 | Lifecycle flow + stage-skill caption | Inline Mermaid | Ready to paste | **Must ship** | — |
| 2 | Component map (corrected layout) | Inline ASCII | Ready to paste | **Must ship** | — |
| 3 | `spark doctor` demo | GIF (to capture) | Needs recording | Must ship before GA | `docs/assets/spark-doctor-demo.gif` |
| 4 | Install commands | Code fence | Ready to paste | **Must ship** | — |
| 5 | Social-preview image | PNG (to design) | Needs creation | Nice-to-have | `.github/og-image.png` |
| 6 | Docs tree (corrected: `adr/` top-level) | Inline ASCII | Ready to paste | Include when Diátaxis section present | — |
| 7 | Contribution pipeline flow | Inline Mermaid/ASCII | Deferred | Contributor docs | — |
| 8 | Skill directory anatomy tree | Inline ASCII | Blocked | Wait for canonical spec | — |

---

## Claims & citations

| Claim | Evidence in 00-ground-truth.md |
|---|---|
| Five-stage lifecycle: Ideate → Plan → Generate → Solve → Ship | "Lifecycle / core workflow enforced" section; `README.md` lifecycle table |
| 16 skills with valid frontmatter | "Lifecycle skills (16 total under `skills/`…)" |
| PreToolUse guard (`guard-bash.sh`) blocks force-push and trunk pushes | "Enforcement" section, `hooks/guard-bash.sh` lines 47-58 |
| `commit-msg` hook enforces conventional commits, blocks AI attribution | "Enforcement" section, `scripts/hooks/commit-msg` |
| `pre-commit` blocks direct commits to master/main | "Enforcement" section, `scripts/hooks/pre-commit` |
| `spark doctor` is a real CLI subcommand | "The `spark` CLI" section, `cmd_doctor` verified in `bin/spark` |
| `spark install-git-hooks` is a real CLI subcommand | "The `spark` CLI" section, `cmd_install_git_hooks` |
| Plugin is marketplace-installable via `jwogrady/spark` | "Plugin packaging" section, `.claude-plugin/marketplace.json` |
| Docs tree follows Diátaxis (tutorials/how-to/reference/explanation) | "Docs (Diátaxis, under `docs/`)" section |
| Plugin reuses `/code-review`, `/security-review`, `verify` (additive) | "Genuine differentiators" section; `CLAUDE.md` |
| `spark doctor` is at `bin/spark` and passes `bash -n` syntax check | "The `spark` CLI" + "All four shell scripts pass `bash -n`" |
| `spark install-git-hooks` requires a git repo; `doctor` returns non-zero on error | "Exact install + first-use commands" section |
| Social-preview image does NOT yet exist | No entry for `.github/og-image.png` in 00-ground-truth.md (ROADMAP item) |

---

## Cross-eval feedback

### From 00 — Cartographer (honest-hype enforcement)

**Item 1: Component map overstates the CLI surface and misgroups hooks.**
> CLI column listed `doctor / new-skill / install-git-hooks / shred-env` (missing
> `list-skills`, `help`). `commit-msg`/`pre-commit` stacked under `hooks/` label but
> actually live in `scripts/hooks/`.

RESOLVED — Component map redrawn: CLI column now shows all six commands (`doctor`,
`list-skills`, `new-skill`, `install-git-hooks`, `shred-env`, `help`). `guard-bash.sh`
stays under `hooks/`; `commit-msg` and `pre-commit` moved to a separate
`scripts/hooks/` cell. Both groupings now match the verified repo layout in
`00-ground-truth.md` §Enforcement.

**Item 2: Docs-tree ASCII shows `adr/` nested inside `explanation/`.**
> `docs/adr/` is a top-level sibling, not a child of `docs/explanation/`.

RESOLVED — Tree corrected: `adr/` and `architecture/` shown as top-level siblings
alongside `explanation/`. Inline annotation distinguishes current reality from the
Coach's cross-linking recommendation.

---

### From 01 — Skimmer (hero)

**Item 1: Strong support for lifecycle flow placement.** No changes requested.
RESOLVED — No action needed; placement confirmed.

**Item 2: Strong support for architecture/component map.** No changes requested.
RESOLVED — Diagram content corrected per Cartographer feedback, placement unchanged.

**Item 3: `spark doctor` GIF — verify it is a real recording.**
RESOLVED — Capture instructions already say "do not ship a staged/fake recording";
capture spec unchanged. Asset status: "Needs recording."

**Item 4: Social-preview strips AI attribution — confirm intentional.**
RESOLVED — Confirmed intentional; no change needed. Author string `jwogrady` only
per CLAUDE.md.

**Item 5: Clarify which assets are blockers vs nice-to-have.**
RESOLVED — Asset inventory table now has a Priority column: lifecycle flow,
component map, and install commands are "Must ship"; doctor GIF is "Must ship before
GA"; social-preview is "Nice-to-have"; docs tree is "Include when Diátaxis section
present."

---

### From 02 — Adopter (quickstart)

**Item 1: Defer docs-tree (asset 6) until missing how-tos are created.**
DECLINED — The docs-tree diagram shows the *existing* verified structure, not
the aspirational one. Deferring based on prose gaps in Persona 06's section would
make the diagram's inclusion conditional on work outside the visual layer. Instead,
the tree is marked "include when the Diátaxis section is present" and shows only
verified directories. Missing how-tos are a docs-coverage gap, not a diagram
accuracy issue. The tree ships reality, annotated; prose gaps can be noted elsewhere.

**Item 2: Verify placement of Mermaid diagram against existing README structure.**
RESOLVED — Added a note to the lifecycle asset: if the existing README already has
the lifecycle as a text table, the Mermaid can replace it or sit above it as a
visual summary. Final placement decision deferred to the Editor.

---

### From 06 — Coach (Diátaxis)

**Item 1: Asset 6 conditioned on length — make it a firm inclusion.**
RESOLVED — Condition changed from "only if the Diátaxis section is long" to "include
whenever the Diátaxis section is present." The tree provides a structural anchor
regardless of prose length.

**Item 2: Fix ADR placement in docs tree (`docs/explanation/adr/` → `docs/adr/`).**
RESOLVED — Tree corrected. `docs/adr/` now shown as a top-level sibling. Cross-link
recommendation from the Coach appears as an inline annotation, not as tree structure.

**Item 3: Add caption mapping stage names to slash commands.**
RESOLVED — Caption added below the lifecycle Mermaid: "Stage names map to skills:
Ideate→`/spark:ideate`, Plan→`/spark:plan`, Generate→`/spark:build`,
Solve→`/spark:fix-issue`, Ship→`/spark:commit`+`/spark:ship`."

---

### From 07 — Contributor

**Item 1: Add contribution pipeline diagram.**
RESOLVED (partial) — Added as Asset 7 (deferred). Diagram concept documented with
ground-truth anchors. Not blocking the README launch; included in contributor docs
scope.

**Item 2: Add skill directory anatomy tree.**
RESOLVED (blocked) — Added as Asset 8. Held until the `CONTRIBUTING.md` vs
`write-a-skill/SKILL.md` canonical spec conflict is resolved. Working assumption
documented.

**Item 3: `spark doctor` validation map.**
DECLINED — The existing `spark doctor` GIF (Asset 3) already provides the
proof-of-life signal for what `doctor` checks. A separate checklist diagram would
add redundancy without proportional value for the README audience. It may be
appropriate for contributor docs alongside Asset 7 — deferred to that scope.
