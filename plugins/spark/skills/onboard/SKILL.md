---
name: onboard
description: Guide a repository's first run as one narrative — orient, choose a setup profile, seed hooks + permissions + standards docs, and close with a brief. Stops at each human decision. Use when arming a repo for the first time or when a brief reports it unclassified/unarmed. Not for scaffolding a new runtime (`bootstrap`) and not the mechanical seed itself (`spark setup`, the one-command carry-in).
---

# onboard — the guided first run

Own the *narrative* of a repository's first run. Each motion is a create-only
CLI verb; you supply the sequencing and stop at every human decision rather
than defaulting through it. Every step is idempotent — rerunning resumes or
truthfully reports "already armed," so a run halted at a decision picks up
without repeating finished work.

## The four motions

### 1. ORIENT — establish context first
Run `spark orient`. It classifies the repo and writes nothing (ADR-0022).
Confirm the verdict with the operator; it governs everything below. Defer
*recording* it (`spark orient --set …`) to SEED, so a chosen profile lands
before the classification fact and setup never refuses over it.

- **`ambiguous`** → **stop and ask.** Signals are sparse or conflicting; never
  infer authorization. Do not proceed until the human names the verdict.
- **`existing`** → **discovery-first, never scaffold.** Inspect the repo's real
  conventions, tooling, and constraints; adopt create-only. Skip PROFILE
  (choosing a stack profile is a new-project act) and go to SEED — setup only
  adds what is missing and keeps everything else.
- **`new`** → proceed to PROFILE.

### 2. PROFILE — choose the standard (new projects)
Show the shipped options with `spark profiles` and let the operator pick — do
not choose for them. Selecting a profile just commits its facts to
`.spark/preferences.json`; with no profile, setup applies the shipped defaults
(Python + uv) unchanged. The choice is applied in SEED via
`spark setup --profile <name>` (the `--profile` flag names a file under the
shipped profiles). If a repo already carries committed project facts, setup
refuses to overwrite them — surface that and let the human reconcile.

### 3. SEED — arm the repo, then record the verdict
Run `spark setup` (add `--profile <name>` if PROFILE chose one). One run
composes the three arming steps: git hooks, the permission baseline, and the
resolved standard — including the two repo-root docs `CONVENTIONS.md` and
`ENGINEERING-STANDARDS.md` (#182). Relay its report **verbatim**:

- `+ created` — a new artifact.
- `= exists, kept` — a project decision, preserved untouched.
- `! needs a decision` — **stop on every one.** The LICENSE choice always is
  one; resolve each with the operator before moving on. Attention items are
  decisions, not failures — the run still exits 0.

Then record the confirmed verdict as a durable project fact:
`spark orient --set <verdict>`. It merges into the committed facts without
clobbering the profile, so the whole lifecycle shares one answer.

### 4. BRIEF — close the loop
Run `spark brief` as the closing summary: what was created, what was kept, the
classification now recorded, the standards docs present, and any decision still
open. When `gh` is authenticated, also relay the **Remote enforcement** line
from `spark doctor --requirements` as one readiness item: the local doors are
armed by SEED, and a trunk without server-side protection is a
`! needs attention` fact the operator should know — offer the policy
(`settings/github-ruleset-trunk.json`), never apply it; changing remote
protection is always the operator's explicit act. This is the honest statement
of where the repo landed.

## Guardrails

- **Orient before anything is written.** No profile, no seed, no scaffold until
  the classification is established and confirmed.
- **Never scaffold over an `existing` repo.** Its decisions are authoritative;
  adopt create-only.
- **Compose, never fork.** Drive the real verbs (`orient`, `profiles`, `setup`,
  `brief`); do not reimplement their mechanics here — that is why rerunning is
  safe (ADR-0021).
- **Stop at every human decision** — ambiguous verdict, profile choice, each `!`
  placeholder. Do not default through a judgment call.
- Starting a brand-new runtime from nothing? Run [`bootstrap`](../bootstrap/SKILL.md)
  first; it scaffolds the stack and ends by calling `spark setup`.

## Fits the lifecycle

`onboard` is the front door: it leaves the repo armed, classified, and briefed,
ready for `Ideate → Plan → Codify → Validate → Ship`. See
[../../docs/reference/cli.md](../../docs/reference/cli.md) for the verbs it drives.
