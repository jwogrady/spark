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

A third, project-facing layer sits below this one: `spark setup` seeds
`CONVENTIONS.md` and `ENGINEERING-STANDARDS.md` at a repo's root as its
editable, readable working contract. Those docs are prose the project owns —
never a fact store — and mark their machine-backed lines with a `spark:pref`
comment so the prose/configuration boundary stays explicit. See
[project-standards.md](project-standards.md).

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
| Semantic Versioning · milestone declares the version (`Release-As`), day-to-day merges bump the patch line (`always-bump-patch`), first release starts at `initial-version` | Release Please (scaffolded by [`preferences`](../reference/cli.md); `ship` defers — see [Releases](#releases) below) |
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
- `ship` defers to it: `codify`/`validate` make the commits, `ship` pushes and opens the PR, Release Please does the release.
- See [release-ownership](../explanation/release-ownership.md) for how this plays out in Spark's own repo — the root package plus three independently versioned companions.

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
- Name the governance model whose label families, cardinality rules, and
  documentation path classes this project is held to — `governance.model`. It
  resolves to a model under `preferences/governance-models/`; `spark governance`
  renders, diffs, and validates the repository against it, and `spark plan`
  mutates only the families that model declares.

### Architecture
- Favor systems that are **modular, loosely coupled, highly cohesive, API-first, reusable, evolvable.**
- Avoid premature abstraction; introduce complexity only when a real requirement demands it.

### Project orientation
Two **project-tier-only** facts record Spark's first onboarding decision — is
this a project being scaffolded, or one being contributed to? They are not part
of the shipped-defaults bag; they exist only when `spark orient --set` writes
them to a repo's `.spark/preferences.json`. — *ADR-0022*
- `project.classification` — `new` or `existing`, the recorded verdict of the
  orientation classifier. `new` authorizes scaffolding (`bootstrap` + the
  standards carry-in); `existing` means the repository's decisions are
  authoritative and adoption stays create-only. An `ambiguous` inspection is
  never recorded — it is the prompt to ask a human, then `--set` the answer.
- `project.classified` — the ISO date the decision was recorded.

Recording is create-only: a same-value `--set` is a no-op, and a changed value
is treated as an explicit human re-set. See
[cli.md](../reference/cli.md) for `spark orient` and its inspect-only classifier.

### Cross-project memory
One optional **project-tier** fact points at the repository that owns this
project's cross-project provenance — the memory-hub/spoke model is decided in
ADR-0028, not restated here.
- `project.memory-hub` — a provider-neutral repository locator (`owner/repo`,
  a URL, or an scp-style git address), or the literal `none` to declare the
  project standalone explicitly. Absent means standalone by default. The value
  is a pointer, never a mirror of the hub's contents, and Spark never guesses
  one. Recorded by `spark hub --set`, resolved and reported (value + source
  tier) by `spark hub`; it is not part of the shipped-defaults bag, though a
  human may deliberately place it in the operator tier.

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
