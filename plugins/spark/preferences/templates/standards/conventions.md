# Project Conventions

> **This document is yours.** Spark seeded it once from shipped defaults and
> will never overwrite it — edit it freely so it describes how this repository
> actually works. It is the readable, reviewable contract collaborators read
> before they open a pull request.

**How to read this file**

- **Default guidance** — shipped starting points. Keep them or change them.
- **`[ADAPT]`** — a project decision: replace the placeholder with what is
  true for this repo.
- **`TODO(decision)`** — a human decision Spark cannot make for you. Resolve
  it, then delete the marker.

Lines that end with a `<!-- spark:pref key=value -->` comment are
**machine-backed**: the same fact is resolved from `.spark/preferences.json`
(shipped defaults, then operator overrides, then this repo's committed project
facts). Editing only the prose does **not** change what Spark's automation
does — change the matching preference too, or the two will drift. Prose without
a marker is guidance, never silently configuration. The prose/config boundary
is documented in the Spark reference `project-standards.md`.

---

## Branching

- Branch model `{{branch.model}}`: short-lived feature branches off the trunk;
  never commit to the trunk directly. <!-- spark:pref branch.model={{branch.model}} -->
- One issue per branch — and a **sub-issue is an issue**, so it gets its own
  branch and its own pull request. An issue with children is a container: no
  branch of its own, closed when its children close. If a candidate sub-issue
  cannot justify its own PR, it is an acceptance criterion on the parent.
- Name branches by type, with the issue number when
  practical: `feat/42-password-reset`, `fix/…`, `docs/…`, `chore/…`.
- When issue B depends on issue A, start B only from a base that already
  contains A's merged result — merge A's PR first, then branch from the fresh
  trunk. Declare the dependency on the issue (`Blocked by #A`).

## Commits

- Commit convention: `{{commit.convention}}`. <!-- spark:pref commit.convention={{commit.convention}} -->
- Subject line in the imperative mood, under `{{commit.subject-max}}` characters,
  no trailing period. <!-- spark:pref commit.subject-max={{commit.subject-max}} -->
- The body explains *why*, not *what*. One logical change per commit.
- Commit when one coherent problem → solution step is complete and sensibly
  checked — an issue branch normally carries **several focused commits**, and
  its history should tell the implementation story. No per-edit WIP/checkpoint
  noise; no single end-of-work blob. Unrelated work becomes another issue.

## Pull requests & review

- Open a pull request for every change, even small ones. One concern per PR.
- The PR is the delivery unit to the trunk; keep the branch's focused commits
  rather than squashing the story away.
- `[ADAPT]` What "approved and mergeable" requires for this repo (passing
  checks, review count, up-to-date branch).
- `TODO(decision)`: required reviewers and any review SLA.

## Issue tracking

- Track work across these categories: `{{issue.taxonomy}}`. <!-- spark:pref issue.taxonomy={{issue.taxonomy}} -->
- `[ADAPT]` Any project-specific labels or milestone rules layered on top.

## Collaboration boundaries

- Permission trust tier `{{permissions.preset}}` — the baseline of what
  automation may do in this repo without a per-command prompt. <!-- spark:pref permissions.preset={{permissions.preset}} -->
- Do not close or comment on issues/PRs, and do not cut releases or tags,
  without explicit human instruction.
- `[ADAPT]` Team boundaries: who owns merges, deploy windows, and who to ask
  when a decision is unclear.

## Documentation

- Documentation describes reality. Update it in the same change that changes
  behavior.
- `[ADAPT]` Where this project's docs live and who keeps them current.
