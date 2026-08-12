---
name: agents-md
description: Create, maintain, and audit a repo's AI-agent contract — one canonical AGENTS.md body plus a CLAUDE.md pointer stub that imports it. Use to write, update, audit, or drift-check AGENTS.md or CLAUDE.md, or to collapse a dual-body pair into the single-body model. Defers net-new repo scanning to native /init. Not for prose docs — use `docit` (public) or `knowledge` (internal).
---

# agents-md — the agent behavioral-contract skill

A repo speaks to its AI contributors through **one canonical contract body**:

- **`AGENTS.md`** — the contract. Tool-agnostic: repo map, commands, workflow,
  and the doctrine every AI agent must follow. Any agent reads it directly.
- **`CLAUDE.md`** — a pointer stub whose body is `@AGENTS.md`, so Claude Code
  imports the same contract other tools read. Claude-specific notes may follow
  the import, but only when genuinely tool-specific.

One body means the two files **cannot drift** — the dual-body model this skill
previously maintained required editing every rule twice, and the two paid a
truth-pass tax on every change. This skill owns both files.

## Division with native `/init`

Claude Code's native `/init` already *creates* a first `CLAUDE.md` by scanning a
repo. **Do not reimplement that.** This skill's jobs are the ones `/init` does
not do:

- **Author `AGENTS.md`** — the canonical body has no native generator. When
  `/init` produced a full `CLAUDE.md`, move its body into `AGENTS.md` and leave
  the `@AGENTS.md` stub behind.
- **Maintain & audit** the contract — patch missing sections, refresh stale
  content, inject Spark's required doctrine (attribution, GitHub guardrails,
  agent safety).
- **Migrate** a legacy dual-body pair (full `CLAUDE.md` + full `AGENTS.md`) to
  the single-body model: merge, dedupe, keep the stricter rule on conflict, and
  present the diff before writing.

## What the contract carries

The **non-negotiable behavioral contract** — attribution, branch/PR discipline,
conventional commits, destructive-action confirmation, the GitHub boundary, and
scope discipline — and a **required-sections** layout. The full contract and
section list are in
[references/contract-and-sections.md](references/contract-and-sections.md);
consult it when authoring or auditing.

## Link the methodology, don't paste it

The Spark methodology lives in Spark and is edited once; a project repo carries
only its own product. When the contract needs to say *how* the project is
built, **link Spark's doctrine instead of restating it** — never generate a
project-local copy of the process, and strip Spark-internal process framing
(`Phase N` headers, `/spark:` stage references) when auditing. The full rule and
the canonical "How this project is built" pointer are in
[references/methodology-boundary.md](references/methodology-boundary.md).

## How the skill behaves

1. **Read both files first.** Never overwrite blindly.
2. **`AGENTS.md` is the body; `CLAUDE.md` is the stub.** A repo with a full
   `CLAUDE.md` and no `AGENTS.md` gets the migration: body moves, stub stays.
3. **Prefer real commands over placeholders.** Read the repo for actual scripts
   and entrypoints; add a TODO marker when a value can't be verified.
4. **Add missing sections; remove vague content carefully.** When uncertain, keep it.
5. **Flag conflicts, don't silently resolve them.** If the stub has grown
   Claude-specific rules that contradict the body, surface it — the body wins
   unless the rule is genuinely tool-specific.
6. **Keep it tight.** A short accurate contract beats a long one. Present a diff
   and get a go-ahead before overwriting an existing file.

## Outputs

Full contract (new `AGENTS.md` + stub, or a legacy pair migrated); section
patches; an audit (stale claims, missing doctrine, stub drift); or a diff
review for human approval. Ask which is wanted if unspecified.

## Non-goals

- Does **not** reimplement `/init`'s repo scan — it defers to it for discovery.
- Does **not** run as an automated CLI command, or modify any file unless invoked.
- Does **not** define project-specific commands — those come from reading the repo.
