# Tutorial: scaffold a new project with Spark

> Tutorial — learning-oriented. Follow every step in order against a repo with
> no history yet. You'll watch Spark decide the repo is **new**, then arm it —
> and end with a working contract you own. We optimize for learning the first
> run, not the fastest path.

By the end you'll have taken an empty repository through Spark's guided first
run: oriented as a new project, armed with hooks, a permission baseline, and two
editable standards docs — ready to hand off to the lifecycle.

The commands and output below are from a real run in a throwaway repo; your repo
path will differ, and the ISO date on the recorded classification will be
today's.

## The mental model, in one minute

Spark's first onboarding decision is **which journey you're on**. A brand-new
repo is safe to scaffold into; an established one is not. So before anything is
written, Spark classifies the repo as **new**, **existing**, or **ambiguous**
([orient reference](../reference/cli.md#spark-orient---set-newexisting)). This
tutorial is the **new** path — you'll see the classifier confirm it, then carry
your standard in. (On an established repo, follow
[adopt-an-existing-repo.md](adopt-an-existing-repo.md) instead.)

## Before you start

- Spark installed (`/plugin install spark`) — see
  [../how-to/get-started.md](../how-to/get-started.md).
- A new, empty git repository (`git init`), no commits yet.
- The environment ready: run `spark doctor --requirements` and clear anything it
  flags (the [supported-environment matrix](../reference/compatibility.md) is
  the contract behind it).

The canonical first run is the guided **`/spark:onboard`** flow. It sequences
four motions — orient → profile → seed → brief — and stops at every human
decision rather than guessing. It drives the same CLI verbs shown below, so you
can run either; this tutorial follows the verbs by hand so you see each one.

## 1. Orient — confirm the repo is new

```bash
spark orient
```

```text
Spark orient — /tmp/spark-new-qyTZwF

Evidence
  git         present
  commits     0
  tracked     0
  manifests   —
  workflows   absent
  docs        absent
  contracts   —
  spark       absent

Verdict
  classification  new (high confidence)

Recommendation
  New project — safe to scaffold. Run /spark:bootstrap to stand up the
  runtime; 'spark setup' then carries the engineering standard in.

  Record this as a project fact once confirmed: spark orient --set new
```

Orient **writes nothing** — it inspects and reports, so orientation always
precedes the first file created. Zero commits and none of the artifacts a real
project carries (a manifest, CI, docs, a contract file) is the signature of a
new repo, and it says so with high confidence.

> You learned: Spark reads the ground truth before it acts. The verdict is
> evidence-backed, not a guess — and it's the fork in the road for everything
> that follows.

## 2. Profile — choose the standard

A new project gets to pick its stack. See the shipped options:

```bash
spark profiles
```

```text
Setup profiles — inspect here, select with: spark setup --profile <name>

  python-uv
    stack.default              python-uv            (the shipped default)
  typescript-bun
    stack.default              typescript-bun       (overrides default: python-uv)

Selecting a profile writes its facts to .spark/preferences.json — a
committed, reviewable project file — before anything materializes.
With no profile, setup applies the shipped defaults unchanged.
```

Selecting a profile just commits its facts to `.spark/preferences.json` — the
same file you'd write by hand — and the ordinary three-tier resolution applies
them ([profiles reference](../reference/cli.md#spark-profiles)). This run keeps
the shipped Python + uv default, so no `--profile` flag is needed.

## 3. Seed — arm the repo

One command composes the whole carry-in: git hooks, the permission baseline, and
the resolved engineering standard.

```bash
spark setup
```

```text
Spark setup — arming /tmp/spark-new-qyTZwF

First run here? /spark:onboard guides orient → profile → seed → brief and stops at each decision.

[1/3] Git hooks (the human-driven enforcement door)
✓ installed commit-msg
✓ installed pre-commit

[2/3] Permission baseline
Permission preset: delivery
✓ created /tmp/spark-new-qyTZwF/.claude/settings.json from Spark's permission baseline

[3/3] Engineering standard
Applying the engineering standard (three-tier resolve, ADR-0010):
  + README.md
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

Standard: 10 created, 0 kept, 1 need attention.

Setup: 13 created, 0 kept, 1 need attention.
```

Every artifact is written create-only and reported in one of three lanes:
`+ created`, `= exists, kept`, `! needs a manual decision`. On an empty repo
almost everything is `+ created`. The one `!` is the **LICENSE** — a legal
judgment call Spark never makes for you, so it surfaces it and moves on. That's
a *decision*, not a failure: setup still exits 0.

> You learned: arming is one explicit motion, and it reports exactly what it
> did. The `!` line is Spark stopping at a call that's yours to make.

Now record the classification you confirmed in step 1 as a durable project fact:

```bash
spark orient --set new
```

```text
orient: recorded project.classification=new in .spark/preferences.json
```

This writes `project.classification` and `project.classified` (today's date)
into `.spark/preferences.json`, so the whole lifecycle shares one answer instead
of re-guessing each session.

## 4. Brief — close the loop

```bash
spark brief
```

```text
Spark brief — /tmp/spark-new-qyTZwF

Orient
  branch    main
  tree      11 uncommitted file(s)
  upstream  none tracked
  class     new (established 2026-07-21)

Locate
  Ideate (inferred) — no docs/problem-statement.md yet

Load
  13 preference key(s) resolved, 2 overridden (operator/project)
  stack.default      python-uv
  release.mechanism  release-please
  full resolution: spark preferences
  standards docs     CONVENTIONS.md ENGINEERING-STANDARDS.md
```

The brief is the honest statement of where the repo landed: classified `new`
with the date it was established, the standard resolved, and both standards docs
present. `Locate` reads `Ideate` because there's no problem statement yet — which
is exactly the next step.

## You're armed

The two repo-root docs are your working contract — prose you own and edit:

- **`CONVENTIONS.md`** — how this repo actually works day to day.
- **`ENGINEERING-STANDARDS.md`** — the standard the automation enforces.

Machine-backed lines carry a `<!-- spark:pref key=value -->` marker that mirrors
a fact in `.spark/preferences.json`; change automation by changing the
preference, not just the prose. The full boundary is in
[reference/project-standards.md](../reference/project-standards.md), and the
rationale behind the shipped defaults is in
[reference/engineering-preferences.md](../reference/engineering-preferences.md).

## Hand off to the lifecycle

The repo is oriented, armed, and briefed — the front door is done. Take your
first idea through the five stages next:

```text
/spark:ideate → /spark:plan → /spark:codify → /spark:validate → /spark:ship
```

For that end-to-end walk, continue with
[build-your-first-project.md](build-your-first-project.md) — the
orientation-agnostic lifecycle tutorial this one hands off into.
