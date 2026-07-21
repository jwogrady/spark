# ADR: Orient first — classify a repo as new, existing, or ambiguous before setup

Date: 2026-07-21
Status: Accepted
Owner: jwogrady

## Context

Spark's onboarding assumed a new, empty project: `bootstrap` scaffolds a
runtime and `spark setup` carries the standard in. But the same operator also
brings Spark to repositories that already exist — a codebase with its own
conventions, tooling, and history. Applied blindly, new-project guidance would
scaffold over decisions the repository has already made.

`spark brief` and `spark resume` already inspect a repo non-destructively —
branch, working state, commit facts, `.spark/state.json`, and repo-shape
inference (#174–#176 also shipped `doctor --requirements` and `spark profiles`).
What was missing is an explicit *first* decision that names the situation:
**am I scaffolding a new project, or contributing to an existing one?** The
answer changes what Spark may safely create, which questions matter, and where
the lifecycle begins. Getting it wrong is not a cosmetic error — it is Spark
inferring authorization to write from sparse evidence.

`spark setup` is already create-only and refuses to overwrite committed project
facts, which is the "existing files are authoritative" half of the problem. The
genuinely new part is the explicit classification and its place at the front of
the flow.

## Decision

- **Classification is a three-band verdict**, produced by one inspect-only
  helper (`classify_repo`) that writes nothing:
  - **new** — no git repo, or a git repo with zero commits and none of the
    artifacts a real project carries (tracked source, a manifest/lockfile, CI,
    docs, `CLAUDE.md`/`AGENTS.md`, `.spark/`).
  - **existing** — real commit history plus tracked source or a project
    artifact; the repository's decisions are authoritative and are preserved.
  - **ambiguous** — sparse or conflicting signals (content present but no
    version control, or staged content with no commits). Spark stops and asks;
    it must never infer authorization from thin evidence.
- **One classifier, shared.** `classify_repo` emits tab-separated
  `signal<TAB>value` evidence lines, then `classification<TAB>{…}` and a plain
  confidence word. `spark orient`, and the setup/first-run/skill paths that
  build on this work, all read the same output so their behavior cannot drift.
- **`spark orient` is the operator-facing preflight.** Bare, it prints the
  evidence, the verdict, and the routing recommendation (new → `bootstrap` +
  the standards path; existing → discovery first, never scaffold; ambiguous →
  ask). `spark orient --set new|existing` records the human's decision.
- **The decision is a create-only project fact.** It is stored in
  `.spark/preferences.json` as `project.classification` (`new`|`existing`) and
  `project.classified` (ISO date), never in `.spark/state.json` (its schema is
  frozen). Recording never clobbers silently: the same value is a no-op, and a
  different value is treated as the explicit human re-set the flag names.

Why: the risk this addresses is asymmetric. Scaffolding over an established
repository destroys real work; asking one extra question in a genuinely
ambiguous case costs a moment. A single classifier — rather than each skill
re-inferring shape — is what makes "orient first" a guarantee instead of a
convention, and recording the answer as a committed fact means the whole
lifecycle shares one authorization rather than re-deciding it per session.

## Alternatives Considered

- **No explicit step — let each skill infer shape as needed.** Rejected: the
  inference would drift between `bootstrap`, `setup`, and the skills, and
  "never scaffold over an existing repo" would be a hope, not a mechanism.
- **A two-band new/existing verdict.** Rejected: it forces a guess on sparse or
  conflicting evidence, which is exactly where inferring authorization is most
  dangerous. The ambiguous band exists to stop and ask.
- **Record the classification in `.spark/state.json`.** Rejected: that schema
  is frozen at eight work-state keys (see `state.md`); a durable project fact
  belongs beside the other project facts in `.spark/preferences.json`.

## Consequences

- A new project fact class (`project.*`) now lives in `.spark/preferences.json`
  alongside the engineering standard; it resolves in the project tier only and
  is not part of the shipped-defaults bag.
- Downstream work (#182 generated conventions, #199 first-run flow, #200/#201)
  consumes `classify_repo`'s output and the recorded fact rather than
  re-deriving repo shape — the interface is the contract.
- The classifier's signal set is a heuristic; new manifest/lockfile kinds may
  need adding over time. Because the helper is inspect-only and its output is
  evidence + verdict, extending it never risks writing to a repo.

## Related Docs

- [0008-information-architecture.md](0008-information-architecture.md) — the three layers and the project-fact carry surface this extends
- [0010-preferences-source-model.md](0010-preferences-source-model.md) — the `.spark/preferences.json` project tier the fact is recorded in
- [0012-setup-is-the-one-command-carry-in.md](0012-setup-is-the-one-command-carry-in.md) — the create-only carry-in orientation now precedes
- `plugins/spark/docs/reference/cli.md` — `spark orient` usage
- `plugins/spark/docs/reference/engineering-preferences.md` — the `project.classification`/`project.classified` keys
- `plugins/spark/docs/reference/state.md` — the frozen work-state schema this deliberately does not touch
