# Cross-eval feedback: from 07 (Contributor) to 08 (Visual Storyteller)

**Reviewer:** Persona 07 — Contributor
**Reviewed:** `08-visuals.md` (and flagging visual moments from the Contributor
domain that 08 should consider for the README visual plan)

---

## Purpose

Per persona 07's definition: "flag the moments that deserve a visual for the
Visual Storyteller." This file is that flag list, not a critique of 08's draft.

---

## Visual moments from the Contributor domain

### 1. The contribution pipeline (high value)

**What it shows:** The four-leg contribution path:
```
scaffold → implement → validate → PR
```
Plus the mechanical gates at each leg (spark new-skill, required frontmatter,
spark doctor, commit-msg hook, pre-commit hook, PR template).

**Why a diagram:** Prose lists the gates but a flowchart would show contributors
exactly where they can fail and what stops them — the same "enforcement over
aspiration" doctrine that 05 articulates, but made visible. This is distinct from
the lifecycle diagram (Ideate→Plan→Ship) because it addresses *repo contributors*,
not *project users*.

**Ground-truth anchor:** `bin/spark` `cmd_new_skill`, `cmd_doctor`,
`cmd_install_git_hooks`; `scripts/hooks/commit-msg`; `scripts/hooks/pre-commit`;
`hooks/guard-bash.sh`; `.github/PULL_REQUEST_TEMPLATE.md`.

---

### 2. Skill directory anatomy (medium value)

**What it shows:** The canonical skill directory tree:

```
skills/<name>/
├── SKILL.md       ← required
├── REFERENCE.md   ← optional
├── EXAMPLES.md    ← optional
└── scripts/       ← optional
```

**Why a diagram:** A simple annotated tree is faster to scan than prose for a
contributor deciding how to structure their work. It also makes the "required vs.
optional" distinction immediate.

**Caveat for 08:** Note that the skill layout spec is currently inconsistent
between `CONTRIBUTING.md` (`references/`, `agents/`) and
`skills/write-a-skill/SKILL.md` (`REFERENCE.md`, `EXAMPLES.md`, `scripts/`).
Do not finalize this diagram until the canonical spec is resolved (see
`from-07-to-06.md` issue 1). Use the `write-a-skill/SKILL.md` layout as the
working assumption since it is the more detailed source.

---

### 3. `spark doctor` validation map (low-medium value)

**What it shows:** What `spark doctor` checks — plugin manifests, hooks JSON,
guard executability, skill frontmatter, agent frontmatter — and what exit code
means what.

**Why a diagram:** Contributes to the "mechanical enforcement" visual story. A
checklist-style diagram shows contributors the exact validation surface so they
know what to fix when `doctor` returns non-zero.

**Ground-truth anchor:** `bin/spark` `cmd_doctor`; `00-ground-truth.md`
§"The `spark` CLI".

---

## No corrections to 08's draft

08-visuals.md's existing plan (lifecycle flow, directory tree, install sequence)
does not contradict the Contributor domain. The above are additions, not
corrections.
