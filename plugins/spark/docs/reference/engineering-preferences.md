# Reference — engineering preferences

> *Authoritative — the operator's rationale behind the engineering standard
> every Spark-generated project conforms to. Owner: `jwogrady`. Single source
> of truth for the *why*: edit here once. The machine-applied counterpart,
> `preferences/defaults.json`, is what a generated project actually inherits.*

This is the operator's standing engineering standard, in prose form. It exists
so preferences are **loaded once, not re-stated per project**. `bootstrap`
does not read this document at generation — it runs `spark setup`, whose
`spark preferences --apply` step resolves and materializes
`preferences/defaults.json` (plus any operator or project tier override)
into the new project.

This document is the canonical **prose** form — the *why* behind each
convention. The machine-resolvable form is decided in ADR-0010:
shipped defaults in `plugins/spark/preferences/defaults.json`, operator
overrides in `~/.config/spark/preferences.json`, per-project exceptions
committed as `.spark/preferences.json`, resolved in that order at apply time.
The JSON carries *what to apply*; this document carries *why it is the
standard*. Where a convention below has no matching key in
`defaults.json`, it is operator guidance, not a materialized guarantee —
Spark does not check for it.

It is written **link-don't-paste**: conventions Spark already enforces or codifies
are *pointed to*, not restated. Only the standard Spark does not yet carry is
spelled out here.

---

## Already enforced or codified in Spark

You never re-state these — Spark already holds them.

| Convention | Where it lives |
|---|---|
| GitHub Flow · never commit to `master` · PRs only | [`hooks/guard-bash.sh`](../reference/hooks.md) + `pre-commit` |
| Conventional Commits · subject ≤72 · one logical change | [`commit-msg`](../reference/hooks.md) |
| Never AI attribution | `commit-msg` + every skill |
| Semantic Versioning · bump from commit type | [`ship`](../reference/skills.md) |
| Design before code · acceptance criteria before dev | [`ideate`](../reference/skills.md) · [`plan`](../reference/skills.md) · [codify-readiness](../reference/codify-readiness.md) |
| One problem / one issue / one PR | [scope doctrine](../explanation/philosophy.md) |
| ADRs · decisions explicit and traceable | `docs/adr/` |
| Documentation describes reality | [honesty principle](../explanation/philosophy.md) · the spark-audit companion |
| README says *what* before *how* · standard doc set | the spark-docs companion · this repo's own layout |
| Minimize dependencies · secrets never committed (`op` is the spark-connect companion's optional tooling, not a core requirement) | [zero-dependency principle](../explanation/philosophy.md) · the spark-connect companion · `SECURITY.md` |

---

## The standard Spark applies at generation

The layer Spark does not yet carry. This is what makes a generated project
*yours* from commit one. Where a bullet below names a `preferences/defaults.json`
key, that setting is machine-applied; everything else in this section is
operator guidance Spark does not check or enforce.

### Stack
- **Python + `uv`** is the default (runtime, dependencies, project management) — `stack.default`. — *ADR-0007*
- **TypeScript / Bun** is the frontend default — `stack.frontend:
  typescript-bun` (Vite/Next.js/Astro) — and ships as one profile
  (`preferences/profiles/typescript-bun.json`) that can also serve as
  `stack.default` for backend APIs (Hono) or libraries/CLIs (`bun init`) —
  it is not frontend-only.
- **OpenTofu** for infrastructure — `stack.infra`. Terraform is not a shipped
  default or requirement; OpenTofu is the Terraform-compatible choice. What
  (if anything) materializes for infra is recorded in
  [compatibility.md](../reference/compatibility.md) — not duplicated here.
- **API-first**, **CLI-first**, **WSL / Linux-first** development.

### Releases
- **Release Please** owns versioning, changelog, GitHub Releases, and annotated tags — `release.mechanism`. — *ADR-0006*
- `ship` defers to it: `ship` does the commit + PR, Release Please does the release.

### CI & automation
- **GitHub Actions** scaffolded into every generated project — validation on every push — `ci.provider`. — *ADR-0005*
- Automate the repetitive: validation pipelines, dependency updates, doc generation.
- *(Spark's own repo runs its own development CI — `.github/workflows/validate.yml`
  runs `doctor` and the behavioral test suite on every PR — as a validation gate
  for this plugin, distinct from the stack-aware CI template
  `spark preferences --apply` materializes into a generated project's own
  `.github/workflows/`. Spark is not itself CI-free.)*

### Documentation
- Every generated project ships: `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`, `ROADMAP.md` — `docs.set`.
- When warranted: architecture docs, ADRs, API docs, deployment docs, onboarding.
- Documentation always reflects reality.

### Repository structure
- Keep the root clean. Create directories only when needed. No speculative trees.
- Favor simple, shallow layouts; let structure evolve.

### Code quality
- Consistent formatting, enforced linting, tests where they earn their keep.
- Keep the repository buildable; validate changes continuously.

### Dependencies
- Minimize them. Prefer standard libraries. Add only for meaningful value; remove unused promptly.

### Security & configuration
- Never commit secrets. Config lives outside source control, via environment variables.
- Principle of least privilege. Sensible defaults; required config documented; local dev stays simple.
- Permission trust tier — `permissions.preset` (default `delivery`) — resolves
  like every other setting across the three tiers and is materialized via
  `spark apply-permissions` (folded into `spark setup`), not this document.
  See [cli.md](../reference/cli.md) for the tiers and grants, and
  [compatibility.md](../reference/compatibility.md) for the degradation
  behavior when no JSON tool is available — not duplicated here.

### Branch hygiene
- **GitHub Flow** — `branch.model`. Trunk protection is hook-enforced (see the
  table above); the model itself is a machine default.
- Short-lived, focused feature branches. Delete merged branches. Keep history clean.

### Commits
- **Conventional Commits** with subjects ≤ 72 characters — `commit.convention`,
  `commit.subject-max` — hook-enforced by `commit-msg` (see the table above).

### Issue management
- Track work explicitly across: **features, bugs, documentation, chores, technical debt, research, infrastructure** — `issue.taxonomy`.

### Architecture
- Favor systems that are **modular, loosely coupled, highly cohesive, API-first, reusable, evolvable.**
- Avoid premature abstraction; introduce complexity only when a real requirement demands it.

---

## Guiding principles

These are advisory — operator guidance, not materialized guarantees Spark
checks or enforces.

1. Truth over aspiration.
2. Simplicity over cleverness.
3. Small changes over large rewrites.
4. Documentation describes reality.
5. Automation replaces repetitive manual work.
6. Every commit improves the repository.
7. Every release is reproducible.
8. Engineering decisions are explicit and documented.
9. Understandable before powerful.
10. Optimize for long-term maintainability over short-term convenience.

---

## How this gets applied

`bootstrap` carries the standard in at generation time: after the runtime
scaffold it runs `spark setup`, whose `spark preferences --apply` step
resolves the three ADR-0010 tiers and materializes the result — the standard doc set, a
stack-aware CI workflow selected by the resolved `stack.default`, and the
Release Please config — reporting what it created (`+`), kept (`=`), and left
for a decision (`!`). The same engine serves an existing repo on demand.
Application is create-only: an existing file is a project choice and is never
overwritten.

> **Status:** shipped. The machine form lives at
> `plugins/spark/preferences/defaults.json`; `spark preferences` shows the
> resolved standard with each value's source tier, and
> `spark preferences --apply` applies it.

## Related docs

- ADRs 0004 · 0005 · 0006 · 0007 · 0015 (0015 supersedes the vocabulary, not
  the decisions, of 0004–0007 — see its own entry in the glossary's
  "generated project")
- [philosophy](../explanation/philosophy.md) · [sdlc-doctrine](../explanation/sdlc-doctrine.md) · [hooks](../reference/hooks.md) · [codify-readiness](../reference/codify-readiness.md)
