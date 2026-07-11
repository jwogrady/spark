---
name: bootstrap
description: Scaffold a new project's runtime with config options — choose frontend/backend and framework, run the canonical scaffolder with Bun (TypeScript) or uv (Python) defaults, and wire it into the Spark lifecycle. Use when starting a new project, scaffolding a runtime, or setting up a frontend/backend stack. Not for wiring services or secrets (the spark-connect companion plugin), nor framing/planning the work (`ideate`/`plan`).
---

# bootstrap — runtime scaffold

`bootstrap` stands up a project's runtime by running the stack's **official
scaffolder** with the right flags — it does not hand-roll a directory tree. The
runtime/package-manager defaults are fixed; only the framework on top is a choice.

- **TypeScript / JavaScript → Bun** (runtime + package manager + test runner).
- **Python → uv** (runtime/version + dependency + project manager).

Concrete per-framework commands and quality-gate defaults live in
[references/profiles.md](references/profiles.md).

## Do this

1. **Decide the shape** — frontend, backend, or both. If a problem statement from
   [`ideate`](../ideate/SKILL.md) exists, infer from it; otherwise ask.
2. **Pick a framework** for each side (the only real config choice). The
   resolved standard names the default stack — `spark preferences` shows it
   (`stack.default` is Python + uv unless a tier overrides it):
   - TS frontend: Vite (SPA), Next.js (SSR/marketing), Astro (content).
   - TS backend: Hono (APIs), or `bun init` (lib/CLI).
   - Python backend: FastAPI (APIs), Django (full-stack), or `uv init` (lib/CLI).
3. **Run the scaffolder non-interactively** — flags *are* the config (see
   profiles). Always Bun for TS, uv for Python.
4. **Add the quality gates** for the profile (formatter/linter, test runner).
5. **Verify the scaffold runs** — build or boot it once (`bun run build` /
   `uv run …`) and confirm it works before moving on. If it fails, report the
   output plainly; don't paper over it.
6. **Carry the standard in.** Record deviations from the resolved defaults as
   committed project facts — e.g. a frontend Cosmic writes
   `.spark/preferences.json` with `{"stack.default": "typescript-bun"}` so the
   exception is visible in review. Then run `spark setup` — one run installs
   the git hooks, applies the permission baseline, and materializes the
   resolved standard — and relay its report verbatim (`+` created, `=` kept,
   `!` needs a decision). Resolve every `!` with the user — the LICENSE
   choice always is one.
7. **Layer Spark on top:**
   - Generate `CLAUDE.md` and `AGENTS.md` with [`agents-md`](../agents-md/SKILL.md).
   - Land at [`ideate`](../ideate/SKILL.md).

## Guardrails

- **Runtime/PM is fixed.** Default to Bun for TS and uv for Python — don't fall
  back to npm/pnpm/node or pip/poetry without an explicit reason.
- **Prefer the official scaffolder** over a bespoke tree; it stays current with
  the framework.
- **Commit the lockfile** (`bun.lock`, `uv.lock`) so the runtime is reproducible.
- **One concern.** bootstrap stands up the runtime; it does not start
  implementing features — that's `codify`, after planning.
- **The standard comes from the resolver, never from memory.** Doc set, CI
  workflow, and release config are materialized by `spark preferences --apply`
  (three-tier resolve, ADR-0010) — don't hand-roll them.
- Don't add dependencies the chosen profile doesn't need.

## Fits the lifecycle

`bootstrap` is the new-project path into Spark: scaffold the runtime, carry
the standard in with `spark setup`, then enter
`Ideate → Plan → Codify → Validate → Ship`. Service connectivity and secrets
are the spark-connect companion plugin's job.
