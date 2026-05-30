# Ground Truth — Spark

> The verified fact base. Every other docit note cites this file. No claim here
> ships without a file or command that proves it. Author/credit string is always
> `jwogrady`.

## What this is (one paragraph)

Spark is a portable project-inception and software-delivery system for
AI-assisted development, shipped as a Claude Code plugin. Installed once, it
carries one opinionated lifecycle — Ideate → Plan → Generate → Solve → Ship —
into every project, plus the skills, enforcement hooks, and a `spark` CLI that
make that lifecycle mechanical rather than aspirational. It is explicitly
*additive*: it builds on Anthropic's skill/plugin spec and reuses Claude Code's
built-in reviewers (`/code-review`, `/security-review`, `verify`) instead of
reinventing them. Source: `README.md`, `.claude-plugin/plugin.json`, `CLAUDE.md`.

## Verified capabilities (each cited)

### Plugin packaging
- Ships as a Claude Code plugin — manifest `.claude-plugin/plugin.json` (`"name": "spark"`, `"version": "0.2.0"`, `"license": "MIT"`, author `jwogrady`).
- Git-installable as a marketplace — `.claude-plugin/marketplace.json` declares the `spark` plugin with `"source": "./"`.

### Lifecycle skills (16 total under `skills/`, each with valid `name:`/`description:` frontmatter — verified by listing `skills/*/SKILL.md`)
- `ideate` — frame a problem into a written problem statement (`skills/ideate/SKILL.md`, "Stage 1").
- `plan` — decompose into GitHub issues + a milestone (`skills/plan/SKILL.md`, "Stage 2").
- `build` — implement one issue on a feature branch (`skills/build/SKILL.md`, "Stage 3").
- `fix-issue` — run built-in reviews, triage, fix to acceptance criteria (`skills/fix-issue/SKILL.md`, "Stage 4").
- `commit` — write a conventional commit (`skills/commit/SKILL.md`, "Stage 5a").
- `ship` — push branch + open a focused PR (`skills/ship/SKILL.md`, "Stage 5b").

### Setup / inception skills
- `bootstrap` — scaffold a project runtime, Bun (TypeScript) / uv (Python) defaults (`skills/bootstrap/SKILL.md`).
- `connect` — connectivity + secrets via 1Password (`op`): capture → ingest → verify → shred (`skills/connect/SKILL.md`).
- `fork-init` — clone Spark as an upstream seed for a new repo (`skills/fork-init/SKILL.md`).
- `claude-md` — generate/maintain CLAUDE.md (`skills/claude-md/SKILL.md`).
- `agents-md` — generate/maintain AGENTS.md (`skills/agents-md/SKILL.md`).
- `write-a-skill` — author new skills with progressive disclosure (`skills/write-a-skill/SKILL.md`).

### Review / knowledge skills
- `grill-me` — relentless plan/design interview (`skills/grill-me/SKILL.md`).
- `review` — multi-agent project audit, 8 specialist agents + Synthesis Lead (`skills/review/SKILL.md`).
- `docit` — multi-persona public-docs glow-up; 13 author personas as real subagents under `agents/docit/` (verified: 13 `.md` files), orchestrated by the skill, coordinating only through `.docit-notes/` (`skills/docit/SKILL.md`).
- `codify` — internal-knowledge crew (intake → specialist → editor + librarian); 6 agents under `agents/codify/` (verified: `00-intake`..`05-editor`) (`skills/codify/SKILL.md`).

### Enforcement (the guardrails are mechanical)
- PreToolUse Bash guard — `hooks/hooks.json` wires `hooks/guard-bash.sh`, which blocks `git push --force`/`-f` (allows `--force-with-lease`) and blocks pushes to `master`/`main`; exit code 2 feeds the reason back to Claude (`hooks/guard-bash.sh` lines 47-58).
- `commit-msg` git hook — enforces conventional type prefix (`feat|fix|docs|chore|refactor|test`), subject ≤ 72 chars, no trailing period, and blocks AI co-author trailers / AI attribution (`scripts/hooks/commit-msg`).
- `pre-commit` git hook — blocks direct commits on `master`/`main` (`scripts/hooks/pre-commit`).

### The `spark` CLI (`bin/spark`, dispatcher verified by reading the `case` block)
- `doctor` — validates plugin manifests are JSON, hooks JSON + guard executable, every skill's `name:`/`description:` frontmatter, every `agents/**/*.md` frontmatter, and whether git hooks are installed in the current repo. JSON validation degrades gracefully when `jq`/`python3` are absent (`bin/spark` `cmd_doctor`).
- `list-skills` — list skills with descriptions (`cmd_list_skills`).
- `new-skill <name>` — scaffold `skills/<name>/SKILL.md` (`cmd_new_skill`).
- `install-git-hooks` — copy `commit-msg`/`pre-commit` into the current repo's git hooks dir, refusing to overwrite a non-Spark hook (`cmd_install_git_hooks`).
- `shred-env <file>` — secure-delete a transient secrets file via `scripts/shred-env.sh` (`cmd_shred_env`; script present at `scripts/shred-env.sh`).
- `help` — prints the leading comment block.
- All four shell scripts pass `bash -n` syntax check (verified). Scripts use `set -euo pipefail`.

### Docs (Diátaxis, under `docs/` — verified by listing)
- Tutorial: `docs/tutorials/build-your-first-project.md`.
- How-to: install + one per stage (`docs/how-to/{install,ideate,plan,build,solve,ship,bootstrap,connect,review}.md`).
- Reference: `docs/reference/{skills,hooks,cli,plugin-manifest}.md`.
- Explanation: `docs/explanation/{sdlc-doctrine,scope-and-upstream,why-a-plugin}.md`; ADRs `docs/adr/0001..0003`; `docs/glossary.md`, `docs/architecture/spark-internals.md`.
- GitHub templates: `.github/PULL_REQUEST_TEMPLATE.md`, issue templates `bug.yml`/`feature.yml`/`skill.yml` + `config.yml`.

## Lifecycle / core workflow enforced

```
Ideate → Plan → Generate → Solve → Ship
```

One concern per unit: one problem per ideate, one feature per issue, one issue
per branch, one concern per PR (`README.md` Design principles). Each stage maps
to a slash command and hands output to the next:

| Stage | Command(s) |
|---|---|
| Ideate | `/spark:ideate` |
| Plan | `/spark:plan` |
| Generate | `/spark:build` |
| Solve | `/spark:fix-issue`, `/spark:review` |
| Ship | `/spark:commit`, `/spark:ship` |

Source: `README.md` lifecycle table, `CLAUDE.md` "The Lifecycle Skills".

## Exact install + first-use commands (traced)

Install (from `README.md` / `docs/how-to/install.md`):
```text
/plugin marketplace add jwogrady/spark
/plugin install spark
```

First use in a repo where you want the git-level guardrails:
```bash
spark install-git-hooks   # copies commit-msg + pre-commit into .git/hooks
spark doctor              # validates layout, manifests, skills, agents, hooks
```
Both subcommands are real `bin/spark` dispatch cases (verified). `install-git-hooks`
requires being inside a git repo; `doctor` returns non-zero if any error is found.

## Genuine differentiators (vs. the obvious alternative — loose prompts / a docs-only convention)

- **Guardrails are mechanical, not advisory.** A PreToolUse hook actively blocks
  force-pushes and trunk pushes *before* Claude runs them, and git hooks reject
  non-conforming commit messages — enforcement lives in `hooks/` and
  `scripts/hooks/`, not just in prose.
- **One installable, versioned lifecycle carried into every repo.** It's a
  marketplace-installable plugin (`marketplace.json`), so the same toolkit and
  version travel with you rather than being copy-pasted per project.
- **Additive by design.** Reuses Claude Code's built-in `/code-review`,
  `/security-review`, `verify` rather than shipping its own reviewers
  (`docs/explanation/scope-and-upstream.md`, ADR-0002).
- **Zero runtime dependencies.** Pure POSIX-friendly Bash that degrades
  gracefully without `jq`/`python3`, so it works in any forked project
  regardless of stack (ADR-0003, `bin/spark` `check_json`).
- **Multi-persona authorship crews.** `docit` (13 outward-facing personas) and
  `codify` (6 inward-facing) run as real plugin subagents coordinating through a
  shared notes directory — not a single prompt.
- **Honest-hype contract.** docit refuses to ship any claim not traceable to a
  ground-truth note (this file is its enforcement substrate).

## SHIPPED vs ROADMAP

### SHIPPED (present in the repo today)
- Plugin packaging + marketplace manifest (`.claude-plugin/`).
- All 16 skills with valid frontmatter.
- PreToolUse guard + `commit-msg`/`pre-commit` git hooks.
- `spark` CLI: `doctor`, `list-skills`, `new-skill`, `install-git-hooks`, `shred-env`, `help`.
- Diátaxis docs tree, ADRs, glossary, GitHub templates.
- `docit` (13 agents) and `codify` (6 agents) crews.

### ROADMAP (intent, not features — `ROADMAP.md`)
- v0.2 open item: validate install end-to-end from a *published* marketplace (unchecked box).
- v0.3: Plan ↔ GitHub — generate issues/milestone from a problem statement, keep drafts in sync, wire acceptance criteria into Solve.
- v0.4: bundled reusable subagents for review/exploration; optional bundled MCP servers (`.mcp.json`).
- v0.5: `spark setup` — curated per-stack permission baseline; stack-specific CLAUDE.md/AGENTS.md presets.
- Later: `fork-init` graduates into a guided "scaffold a new project from Spark" flow.

## Accuracy flags (for Phase 2 / Issue Council)
- **License mismatch.** `plugin.json` declares `"license": "MIT"` and the README
  badge says MIT, but the `LICENSE` file contains only "License TBD. Copyright
  belongs to the author." — the manifests overclaim a license the repo has not
  actually adopted. Verified by reading `LICENSE` and `.claude-plugin/plugin.json`.
- README "What's in the box" lists the CLI as `doctor, new-skill,
  install-git-hooks, shred-env, help` but omits `list-skills`, which is a real
  dispatch case in `bin/spark`. Minor undercount.
