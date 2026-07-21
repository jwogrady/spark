# Tutorial: adopt Spark in an existing repository

> Tutorial — learning-oriented. Follow every step in order against a repo that
> already has history and its own conventions. You'll watch Spark decide the
> repo is **existing**, then adopt it without overwriting a single decision it
> already made. We optimize for learning the adoption path, not the fastest one.

By the end you'll have brought Spark into an established repository the safe way:
oriented as an existing project, adopted create-only, and briefed — with proof
that nothing you already had was touched.

The commands and output below are from a real run in a throwaway repo seeded with
a `package.json`, a `src/` module, a `README.md`, a `.github/workflows/ci.yml`,
and two commits — a stand-in for a mature project. Your repo path will differ.

## The mental model, in one minute

An established repo's decisions are **authoritative**. Spark must never scaffold
over them. So the first onboarding motion is the same classifier the new-project
path runs ([orient reference](../reference/cli.md#spark-orient---set-newexisting)),
but here it lands on **existing** — and that verdict changes the rules: discover
first, adopt create-only, never generate over what's there. (Starting from an
empty repo instead? Follow
[scaffold-a-new-project.md](scaffold-a-new-project.md).)

## Before you start

- Spark installed (`/plugin install spark`) — see
  [../how-to/get-started.md](../how-to/get-started.md).
- An existing git repository with real history you can open a branch and PR in.
- The environment ready: `spark doctor --requirements`
  ([supported-environment matrix](../reference/compatibility.md)).

The guided **`/spark:onboard`** flow drives this whole path and stops at each
human decision. For an `existing` repo it skips the profile step — choosing a
stack is a new-project act — and goes straight to a create-only seed. This
tutorial runs the verbs by hand so you see each one.

## 1. Orient — confirm the repo is existing

```bash
spark orient
```

```text
Spark orient — /tmp/spark-existing-ggdeMg

Evidence
  git         present
  commits     2
  tracked     4
  manifests   package.json
  workflows   present
  docs        present
  contracts   —
  spark       absent

Verdict
  classification  existing (high confidence)

Recommendation
  Existing project — its decisions are authoritative. Begin with
  discovery (conventions, tooling, constraints); never scaffold over it.
  Adoption is create-only: 'spark setup' adds what is missing, keeps the rest.

  Record this as a project fact once confirmed: spark orient --set existing
```

Real commit history plus tracked source and a project artifact is the signature
of an established project. The recommendation is explicit: **discover first,
never scaffold over it, adopt create-only**.

> You learned: the verdict is not cosmetic — it rewrites what Spark is allowed
> to do. On `existing`, "carry in what's missing" replaces "scaffold".

## 2. Discovery-first

Before arming anything, read what the repo already declares about itself — its
manifest, its CI, its `README`, its own conventions. Spark adopts *around* those
decisions; it doesn't replace them. There's no profile step here: the stack is
already chosen, and the evidence above (a `package.json`, a workflow) is where
that discovery begins.

## 3. Adopt — create-only setup

Run the same one command as the new-project path. The difference is entirely in
what it does when it meets a file that already exists.

```bash
spark setup
```

```text
Spark setup — arming /tmp/spark-existing-ggdeMg

First run here? /spark:onboard guides orient → profile → seed → brief and stops at each decision.

[1/3] Git hooks (the human-driven enforcement door)
✓ installed commit-msg
✓ installed pre-commit

[2/3] Permission baseline
Permission preset: delivery
✓ created /tmp/spark-existing-ggdeMg/.claude/settings.json from Spark's permission baseline

[3/3] Engineering standard
Applying the engineering standard (three-tier resolve, ADR-0010):
  = README.md (exists — kept)
  + CHANGELOG.md
  + CONTRIBUTING.md
  ! LICENSE — pick one (MIT? Apache-2.0? proprietary?)
  + ROADMAP.md
  + CONVENTIONS.md
  + ENGINEERING-STANDARDS.md
  + release-please-config.json
  + .release-please-manifest.json
  + .github/workflows/release-please.yml
  + .github/workflows/validate.yml

Standard: 9 created, 1 kept, 1 need attention.
```

Read the three lanes closely — this is the whole promise of the `existing` path:

- **`= README.md (exists — kept)`** — the repo already had a `README.md`, so
  Spark left it **exactly as it was**. It did not overwrite, merge, or append.
- **`+ CONVENTIONS.md`**, **`+ CHANGELOG.md`**, … — artifacts the repo *didn't*
  have are added. Adoption fills gaps; it doesn't reopen settled choices.
- **`! LICENSE`** — a decision surfaced for you, never made for you.

The `[1/3]` hooks and `[2/3]` permission steps behave the same way: existing,
non-Spark git hooks are left untouched, and the permission baseline is merged
into `.claude/settings.json` without changing a rule you already had.

> You learned: on an established repo, `= exists, kept` is the load-bearing
> line. Every one of them is a decision Spark preserved rather than overrode.

### Prove it: the kept file is byte-for-byte yours

The `README.md` that was reported `= kept` is unchanged:

```bash
cat README.md
```

```text
# acme-widgets

Acme's widget service. Two years of history, its own conventions, already in production.
```

And because every artifact is create-only, re-running setup is a no-op — the
second run keeps everything it kept before and creates nothing new:

```bash
spark setup
```

```text
[3/3] Engineering standard
Applying the engineering standard (three-tier resolve, ADR-0010):
  = README.md (exists — kept)
  = CHANGELOG.md (exists — kept)
  = CONTRIBUTING.md (exists — kept)
  ! LICENSE — pick one (MIT? Apache-2.0? proprietary?)
  = ROADMAP.md (exists — kept)
  = CONVENTIONS.md (exists — kept)
  = ENGINEERING-STANDARDS.md (exists — kept)
  = release-please-config.json (exists — kept)
  = .release-please-manifest.json (exists — kept)
  = .github/workflows/release-please.yml (exists — kept)
  = .github/workflows/validate.yml (exists — kept)

Standard: 0 created, 10 kept, 1 need attention.
```

Idempotence by construction: an existing file is a project choice, so it is
kept and reported, never rewritten — which is what makes adoption safe to run
again any time. The full lane semantics are in the
[setup reference](../reference/cli.md#spark-setup---yes---profile-name).

## 4. Record the verdict, then brief

Record the classification you confirmed, so the whole lifecycle shares one
answer:

```bash
spark orient --set existing
```

```text
orient: recorded project.classification=existing in .spark/preferences.json
```

Then close the loop:

```bash
spark brief
```

```text
Spark brief — /tmp/spark-existing-ggdeMg

Orient
  branch    main
  tree      11 uncommitted file(s)
  upstream  none tracked
  class     existing (established 2026-07-21)

Locate
  Ideate (inferred) — no docs/problem-statement.md yet

Load
  13 preference key(s) resolved, 2 overridden (operator/project)
  stack.default      python-uv
  release.mechanism  release-please
  full resolution: spark preferences
  standards docs     CONVENTIONS.md ENGINEERING-STANDARDS.md
```

The brief now records `class existing` with the date it was established and
names the two standards docs that landed. That recorded classification is a
durable fact the brief keeps alive every session — and if the repo later grows
in a way that contradicts it, the brief flags it for re-orientation rather than
silently rewriting it.

> You learned: the new/existing decision is a project fact, carried forward, not
> a per-session guess.

## You're adopted

Spark is now armed in the repo without having touched a single decision it
already carried. The two seeded docs — `CONVENTIONS.md` and
`ENGINEERING-STANDARDS.md` — are yours to edit so they describe how *this*
repository actually works; the boundary between that prose and the machine facts
is in [reference/project-standards.md](../reference/project-standards.md). How
Spark governs issues and metadata in an adopted repo is in
[reference/metadata-governance.md](../reference/metadata-governance.md).

## Hand off to the lifecycle

The repo is oriented, adopted, and briefed. Run your next change through the five
stages:

```text
/spark:ideate → /spark:plan → /spark:codify → /spark:validate → /spark:ship
```

For the end-to-end walk through those stages, continue with
[build-your-first-project.md](build-your-first-project.md) — the
orientation-agnostic lifecycle tutorial this one hands off into.
