# bootstrap — runtime profiles

Concrete scaffold commands for the [`bootstrap`](../SKILL.md) skill. Runtime and
package manager are fixed (**Bun** for TS/JS, **uv** for Python); the framework is
the choice. All commands are non-interactive — the flags are the config.

Replace `app` with the project name.

---

## TypeScript / JavaScript — Bun

Bun is the runtime, package manager, test runner, and bundler. Use `bun add` /
`bun add -d` for deps, `bun run` for scripts, `bun test` for tests. Commit
`bun.lock`.

### Frontend — SPA (Vite)

```bash
bun create vite app --template react-ts     # or vue-ts / svelte-ts / solid
cd app && bun install
bun run build                                 # verify the scaffold builds
```

### Frontend — SSR / marketing site (Next.js)

```bash
bun create next-app app --ts --app --tailwind --eslint --use-bun
cd app && bun run build
```

### Frontend — content site (Astro)

```bash
bun create astro@latest app -- --template minimal --typescript strict
cd app && bun install && bun run build
```

### Backend — API (Hono)

```bash
bun create hono app                           # choose the `bun` runtime template
cd app && bun install && bun run dev          # verify it boots, then stop
```

### Library / CLI (bare)

```bash
mkdir app && cd app && bun init               # minimal TS, bun test ready
```

### Quality gates (TS default)

Default to **Biome** (one fast tool for lint + format, fits Bun's one-tool ethos):

```bash
bun add -d @biomejs/biome && bunx biome init
```

> Alternative if the team prefers it: ESLint + Prettier. Pick one per project and
> record it in the agent contract (`AGENTS.md`) — don't run both.

---

## Python — uv

uv manages the Python version, dependencies, and project. Use `uv add` /
`uv add --dev` for deps, `uv run` to execute. Commit `pyproject.toml`, `uv.lock`,
and `.python-version`.

### Project init

```bash
uv init app            # or: uv init --lib app  /  uv init --package app
cd app
```

### Backend — API (FastAPI)

```bash
uv add "fastapi[standard]"
uv run uvicorn app.main:app --reload          # verify it boots, then stop
```

### Backend — full-stack (Django)

```bash
uv run django-admin startproject app .
uv run python manage.py check                 # verify the project is valid
```

### Quality gates (Python default)

Default to **Ruff** for both lint and format (modern single tool):

```bash
uv add --dev ruff pytest
uv run ruff check . && uv run ruff format --check .
```

> `ruff format` covers what Black did. Keep Black only if a project already
> depends on it; record the choice in the agent contract (`AGENTS.md`).

---

## After scaffolding

Carry the standard in: record project facts in `.spark/preferences.json` when
this project deviates from the resolved defaults, then run
`spark preferences --apply` — it materializes the standard doc set, the
stack-aware CI workflow, and the Release Please config, create-only. Then hand
off to the rest of setup: generate `CLAUDE.md`/`AGENTS.md`, run
`spark install-git-hooks`, connect services with the `connect` skill, and begin
the lifecycle at `ideate`.
