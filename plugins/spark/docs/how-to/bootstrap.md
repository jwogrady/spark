# How to bootstrap a project runtime

> How-to — task-oriented.

`/spark:bootstrap` is the new-project path into Spark: it stands up the
runtime, then ends by running `spark setup` so the fresh repo enters the
lifecycle already armed. Runtime/package-manager is fixed — **Bun** for
TypeScript, **uv** for Python; you choose the framework. Full commands:
[../../skills/bootstrap/references/profiles.md](../../skills/bootstrap/references/profiles.md).
(For an existing repo, skip this and run `spark setup` directly — see
[get-started.md](get-started.md).)

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

Record the choice in the agent contract (`AGENTS.md`); don't run two formatters.

## 4. Verify it runs

Build or boot once before going further:

```bash
bun run build           # or bun run dev, then stop
uv run uvicorn app.main:app --reload
```

If it fails, report the output — don't proceed on a broken scaffold.

## 5. Enter the lifecycle

- `spark setup` — bootstrap runs this for you at the end: one run arms the
  repo with git hooks, the permission baseline, and your resolved standard.
- Generate `CLAUDE.md` + `AGENTS.md` (the `agents-md` skill).
- Start the lifecycle at `/spark:ideate`.

Need external services and secrets (API keys, 1Password)? That lives in the
`spark-connect` companion plugin, installable from the same marketplace.

**Done when** the scaffold builds/boots clean, the lockfile is committed, and
`spark setup` reports the repo armed (hooks, permissions, standard).
