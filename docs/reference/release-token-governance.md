# Reference — release-token governance

> Reference — information-oriented. Developer/operations doc for this
> repository; not shipped with the plugin. Owner: `jwogrady`. The shipped
> ownership model lives at
> `plugins/spark/docs/explanation/release-ownership.md`; this doc records the
> token identity behind `.github/workflows/release-please.yml` for *this*
> repo. Issue #185 owns this record.

## Wiring (done 2026-07-21)

`.github/workflows/release-please.yml` now passes
`token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}` to
`googleapis/release-please-action@v4`. With the secret **unset** it falls back
to the default `GITHUB_TOKEN`, so behavior is identical to before; once the
secret is added, the release PR is created by that identity and its `validate`
checks run without being held. The companion-tag step still runs on the default
token — it only pushes tags, which never need to trigger a downstream workflow.

The remaining step is **operator-only**: create the credential and store it as
the `RELEASE_PLEASE_TOKEN` repository secret (below). No code change is needed
after that — the next push to `master` uses it automatically.

Two consequences of the *default* token that this resolves:

1. **No downstream triggering.** Resources created with the default token do
   not trigger other workflows — a documented `GITHUB_TOKEN` limitation, not
   Spark-specific.
2. **Held release-PR checks.** The release PR's own `pull_request` runs land
   `action_required` and need a manual approve/rerun on every refresh
   (verified run `29167470940`: same-repo path, `github-actions[bot]` actor —
   not the fork-approval path, so a fork-policy change would not help).

## Recommended identity (for this solo repo)

A **least-privilege fine-grained PAT** — simpler than a GitHub App for a single
operator, and sufficient here:

- **Resource owner / repository access:** only `jwogrady/spark`.
- **Repository permissions:** `Contents: Read and write`, `Pull requests: Read
  and write`, `Workflows: Read and write` (so it may touch `.github/workflows/`
  if a future release ever does). Nothing else — never a classic broad PAT.
- **Expiry:** the shortest workable window (e.g. 90 days); rotation is a
  calendar reminder, re-mint with the same scopes, re-run `gh secret set`.
- **Storage:** `gh secret set RELEASE_PLEASE_TOKEN --repo jwogrady/spark`
  (paste the token when prompted). Never commit it.

A GitHub App is the better choice if this ever becomes multi-maintainer or
org-owned (no human-tied expiry, finer audit); revisit then.

### Verify after adding the secret

1. Push any conventional commit to `master` (or re-run the `release-please`
   workflow) so the release PR refreshes under the new identity.
2. Confirm the release PR now shows `doctor` + `tests` **running/passed** (not
   `action_required`), and that the `milestone-gate` status can reach *ready*
   once the mapped milestone is complete (#194).

## Failure behavior

A dead or revoked token has **no mechanical detection today**. `spark doctor
--requirements`'s `release` group checks only that the config and workflow
files are present — never token validity — so the observable symptom is the
release PR silently no longer refreshing after pushes to `master`. The
milestone-gate readiness signal (#194, shipped in v0.10.1) is the mechanical
surface here: once this token lets the release PR run CI, a dead token shows up
as the gate reporting validation not-green on an otherwise-complete milestone.

## See also

- `plugins/spark/docs/explanation/release-ownership.md` — the shipped
  ownership model this record backs.
- ADR-0009 (`../adr/0009-spark-release-mechanism.md`) — the release-mechanism
  decision.
- Issue #185 — boundary + token governance; issue #194 — readiness signal.
