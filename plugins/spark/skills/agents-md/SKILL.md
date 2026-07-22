---
name: agents-md
description: Create, maintain, audit, and sync a repo's AI-agent contract files — AGENTS.md (any agent) and CLAUDE.md (Claude Code). Use to write, update, audit, or drift-check AGENTS.md or CLAUDE.md. Defers net-new CLAUDE.md creation to native /init. Not prose docs — use `docit` (public) or `knowledge` (internal).
---

# agents-md — the agent behavioral-contract skill

A repo speaks to its AI contributors through two files:

- **`CLAUDE.md`** — read by Claude Code specifically. Full project context: repo
  map, commands, workflow, and the doctrine Claude must follow.
- **`AGENTS.md`** — the tool-agnostic companion. The same behavioral contract,
  restated so *any* AI coding agent absorbs it regardless of vendor.

This skill owns **both**. They share one behavioral contract and must stay in
sync; when a rule changes in one, it is reviewed in the other.

## Division with native `/init`

Claude Code's native `/init` already *creates* a first `CLAUDE.md` by scanning a
repo. **Do not reimplement that.** This skill's jobs are the ones `/init` does not
do:

- **Author `AGENTS.md`** — `/init` only writes `CLAUDE.md`; the tool-agnostic file
  has no native generator.
- **Maintain & audit** both files — patch missing sections, refresh stale content,
  inject Spark's required doctrine (attribution, GitHub guardrails, agent safety).
- **Sync-check** the two for drift.

For a brand-new `CLAUDE.md`, run `/init` first, then this skill to enforce the
Spark sections and generate the matching `AGENTS.md`.

## What both files carry

Both files share one **non-negotiable behavioral contract** — attribution,
branch/PR discipline, conventional commits, destructive-action confirmation, the
GitHub boundary, and scope discipline — and a **required-sections** layout (rich
for `CLAUDE.md`, scannable for `AGENTS.md`). The full contract and the per-file
section lists are in
[references/contract-and-sections.md](references/contract-and-sections.md);
consult it when authoring or auditing, and keep the two files in sync on it.

## Link the methodology, don't paste it

The Spark methodology lives in Spark and is edited once; a project repo carries
only its own product. When a contract file needs to say *how* the project is
built, **link Spark's doctrine instead of restating it** — never generate a
project-local copy of the process, and strip Spark-internal process framing
(`Phase N` headers, `/spark:` stage references) when auditing. The full rule and
the canonical "How this project is built" pointer are in
[references/methodology-boundary.md](references/methodology-boundary.md).

## How the skill behaves

1. **Read both files first.** Never overwrite blindly.
2. **Defer creation of `CLAUDE.md` to `/init`;** this skill maintains and audits it.
3. **Derive `AGENTS.md` from `CLAUDE.md`** — restate, don't duplicate verbatim; it
   must read as a standalone document.
4. **Prefer real commands over placeholders.** Read the repo for actual scripts and
   entrypoints; add a TODO marker when a value can't be verified.
5. **Add missing sections; remove vague content carefully.** When uncertain, keep it.
6. **Flag drift, don't silently resolve it.** If the two files contradict, surface
   the conflict. `CLAUDE.md` is authoritative for Claude Code; `AGENTS.md` for all
   other agents; update them together.
7. **Keep both tight.** A short accurate contract beats a long one. Present a diff
   and get a go-ahead before overwriting an existing file.

## Outputs

Full file (new `AGENTS.md`, or a `/init`-seeded `CLAUDE.md` brought up to standard);
section patches; a sync audit (drift between the two); or a diff review for human
approval. Ask which is wanted if unspecified.

## Non-goals

- Does **not** reimplement `/init`'s `CLAUDE.md` creation — it defers to it.
- Does **not** run as an automated CLI command, or modify any file unless invoked.
- Does **not** define project-specific commands — those come from reading the repo.
