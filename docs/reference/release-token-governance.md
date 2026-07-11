# Reference — release-token governance

> Reference — information-oriented. Developer/operations doc for this
> repository; not shipped with the plugin. Owner: `jwogrady`. The shipped
> ownership model lives at
> `plugins/spark/docs/explanation/release-ownership.md`; this doc records the
> token identity behind `.github/workflows/release-please.yml` for *this*
> repo. Issue #185 owns this record.

## Current state (verified 2026-07-11)

`.github/workflows/release-please.yml` passes no `with: token:` — the
`googleapis/release-please-action@v4` step and the companion-tag step both
run on the default, implicitly-injected `GITHUB_TOKEN` granted by the
workflow's `permissions:` block (`contents: write`, `pull-requests: write`).

Two verified consequences:

1. **No downstream triggering.** Resources created with the default token do
   not trigger other workflows — a documented `GITHUB_TOKEN` limitation, not
   Spark-specific.
2. **Held release-PR checks.** The release PR's own `pull_request` runs land
   `action_required` and need a manual approve/rerun on every refresh.
   Verified on run `29167470940`: `event: pull_request`,
   `head_repo: jwogrady/spark` (same-repo path — explicitly *not* the
   fork-approval path, so changing the fork-PR approval policy would not
   help), `actor`/`triggering_actor: github-actions[bot]`. That run later
   shows green jobs — evidence of a manual approve/rerun, not of a fix.

## Pending decision (human-blocked)

- **Identity** — a dedicated GitHub App (preferred) or a least-privilege
  fine-grained PAT. Scope either to `contents` + `pull-requests` on this
  repository only; never a broad personal token. **Not decided.**
- **Ownership, rotation cadence, storage** — to be recorded here once the
  identity is chosen. Storage via `gh secret set` on this repo.
- **Wiring + verification** — point `release-please-action` (and the
  companion-tag step's checkout, if needed) at the chosen credential, then
  verify a release-PR refresh runs its checks unheld end to end.

## Failure behavior

A dead or revoked token has **no mechanical detection today**. `spark doctor
--requirements`'s `release` group checks only that the config and workflow
files are present — never token validity — so the observable symptom is the
release PR silently no longer refreshing after pushes to `master`. The
planned milestone-gate readiness signal (issue #194) is the intended
mechanical surface for this; until it ships, detection relies on a human
noticing a stale release PR.

## See also

- `plugins/spark/docs/explanation/release-ownership.md` — the shipped
  ownership model this record backs.
- ADR-0009 (`../adr/0009-spark-release-mechanism.md`) — the release-mechanism
  decision.
- Issue #185 — boundary + token governance; issue #194 — readiness signal.
