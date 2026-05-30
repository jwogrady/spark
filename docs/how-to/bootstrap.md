# How to bootstrap a project runtime

> How-to — task-oriented.

Use this to stand up a new project's runtime. Runtime/package-manager is fixed —
**Bun** for TypeScript, **uv** for Python; you choose the framework. Full
commands: [../../skills/bootstrap/references/profiles.md](../../skills/bootstrap/references/profiles.md).

## 1. Choose the shape

Frontend, backend, or both. Then a framework per side:

- TS frontend: Vite (SPA) · Next.js (SSR/marketing) · Astro (content)
- TS backend: Hono (API) · `bun init` (lib/CLI)
- Python backend: FastAPI (API) · Django (full-stack) · `uv init` (lib/CLI)

## 2. Scaffold (Bun / uv)

Invoke `/spark:bootstrap`. It runs the official scaffolder non-interactively, e.g.:

```bash
bun create next-app app --ts --app --tailwind --use-bun   # TS frontend
bun create hono app                                        # TS backend (bun template)
uv init app && uv add "fastapi[standard]"                  # Python backend
```

## 3. Add quality gates

- TS → Biome (`bun add -d @biomejs/biome && bunx biome init`)
- Python → Ruff (`uv add --dev ruff pytest`)

Record the choice in `CLAUDE.md`; don't run two formatters.

## 4. Verify it runs

Build or boot once before going further:

```bash
bun run build           # or bun run dev, then stop
uv run uvicorn app.main:app --reload
```

If it fails, report the output — don't proceed on a broken scaffold.

## 5. Layer Spark on top

- Generate `CLAUDE.md` + `AGENTS.md` (the `agents-md` skill).
- `spark install-git-hooks`.
- Connect services + secrets with `/spark:connect`.
- Start the lifecycle at `/spark:ideate`.

**Done when** the scaffold builds/boots clean, the lockfile is committed, and the
project is wired into Spark (CLAUDE.md, hooks, connections).
