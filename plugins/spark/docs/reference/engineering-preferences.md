# Reference — engineering preferences

> *Authoritative — the engineering standard every Spark-generated project (Cosmic)
> conforms to. Owner: `jwogrady`. Single source of truth: edit here once; every
> Cosmic inherits it.*

This is the operator's standing engineering standard. It exists so preferences are
**loaded once, not re-stated per project**. `bootstrap` reads this at generation
and applies it to a new Cosmic.

This document is the canonical **prose** form — the *why* behind each
convention. The machine-resolvable form is decided in ADR-0010 *(proposed)*:
shipped defaults in `plugins/spark/preferences/defaults.json`, operator
overrides in `~/.config/spark/preferences.json`, per-project exceptions
committed as `.spark/preferences.json`, resolved in that order at apply time.
The JSON carries *what to apply*; this document carries *why it is the
standard*.

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
| Documentation describes reality | [honesty principle](../explanation/philosophy.md) · `docit` · `cleanup` |
| README says *what* before *how* · standard doc set | `docit` · this repo's own layout |
| Minimize dependencies · secrets via `op`, never committed | [zero-dependency principle](../explanation/philosophy.md) · [`connect`](../reference/skills.md) · `SECURITY.md` |

---

## The standard Spark applies at generation

The layer Spark does not yet carry. This is what makes a generated Cosmic
*yours* from commit one.

### Stack
- **Python + `uv`** is the default (runtime, dependencies, project management). — *ADR-0007*
- **TypeScript / Bun** only when a Cosmic needs a frontend.
- **OpenTofu / Terraform** for infrastructure.
- **API-first**, **CLI-first**, **WSL / Linux-first** development.

### Releases
- **Release Please** owns versioning, changelog, GitHub Releases, and annotated tags. — *ADR-0006*
- `ship` defers to it: `ship` does the commit + PR, Release Please does the release.

### CI & automation
- **GitHub Actions** scaffolded into every Cosmic — validation on every push. — *ADR-0005*
- Automate the repetitive: validation pipelines, dependency updates, doc generation.
- *(Spark itself stays CI-free; CI is a Cosmic default, not a Spark-self rule.)*

### Documentation
- Every Cosmic ships: `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`, `ROADMAP.md`.
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

### Branch hygiene
- Short-lived, focused feature branches. Delete merged branches. Keep history clean.

### Issue management
- Track work explicitly across: **features, bugs, documentation, chores, technical debt, research, infrastructure.**

### Architecture
- Favor systems that are **modular, loosely coupled, highly cohesive, API-first, reusable, evolvable.**
- Avoid premature abstraction; introduce complexity only when a real requirement demands it.

---

## Guiding principles

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

`bootstrap` reads this reference when it generates a Cosmic and materializes the
standard above — the doc set, the stack default, the CI workflow, the Release
Please config — so a new project starts already conforming.

> **Status:** this reference is the source of truth today. The `bootstrap`
> application step is **planned, not yet wired** — see the Cosmic-repo-standard
> milestone. Until then, this is the checklist a Cosmic is brought up to by hand.

## Related docs

- ADRs 0004 · 0005 · 0006 · 0007
- [philosophy](../explanation/philosophy.md) · [sdlc-doctrine](../explanation/sdlc-doctrine.md) · [hooks](../reference/hooks.md) · [codify-readiness](../reference/codify-readiness.md)
