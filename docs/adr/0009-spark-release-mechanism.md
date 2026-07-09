# ADR: Spark releases manually today, adopts Release Please once validation CI lands

Date: 2026-07-08
Status: Accepted
Owner: jwogrady

## Context

ADR-0006 settled releases for *generated Cosmics*: they use Release Please, and
`ship` defers to it. It explicitly left Spark's own release mechanism open
("Spark's *own* repository release flow is a separate question, not settled
here").

What Spark does today is a manual flow, run by hand at a version boundary:

1. A `chore: release vX.Y.Z` PR (see #54, #57) rolls the `[Unreleased]`
   CHANGELOG section into a dated `vX.Y.Z` entry and bumps `version` in
   `plugins/spark/.claude-plugin/plugin.json`.
2. After merge: an annotated tag `vX.Y.Z` and a GitHub Release with the
   CHANGELOG section as notes.
3. The bump size is derived from the commit types in the range per the ladder
   in `ship` (`feat:` → minor; `fix:`/`docs:`/`chore:` → patch; `!` → major).

This flow works — v0.2.0 through v0.3.1 shipped through it — but it is
incidental, not decided. It also cannot be automated yet for a structural
reason: Release Please runs as a GitHub Actions workflow, and Spark currently
has none. ADR-0005 declared Spark itself CI-free; issue #70 proposes amending
that with a validation workflow whose single step is `spark doctor`. Until a
workflow exists at all, adopting Release Please would mean introducing CI to
this repo solely for releasing.

## Decision

- **Adopt Release Please for Spark's own releases once validation CI (#70)
  lands.** The same commit-type conventions the `commit-msg` hook already
  enforces drive it; a `release-please` workflow maintains the release PR,
  and merging that PR produces the tag, the GitHub Release, and the CHANGELOG
  entry. The extra-files/updater config keeps
  `plugins/spark/.claude-plugin/plugin.json` `version` in sync.
- **Until then, the manual `chore: release vX` flow is the deliberate
  mechanism** — CHANGELOG roll + `plugin.json` bump in one release PR, then an
  annotated tag and a GitHub Release, always with explicit operator go-ahead.

Why sequence it behind #70: #70 is the decision that Spark's repo gets a
workflow surface at all (amending ADR-0005). Once that door is open, the
argument that carried ADR-0006 applies to Spark identically — Release Please
does mechanically and continuously what the manual flow does by hand, and the
operator's principle is to lean on great tools rather than re-run them
manually. Adopting it earlier would invert the dependency: release automation
would be the reason CI exists, rather than riding on CI that validation
already justified.

Why document the interim flow at all: an undocumented manual process is where
drift lives (release PRs already vary in what they touch — compare #54's
six-file diff against #57's two-file diff). Naming the three steps above as
*the* flow keeps releases uniform until automation replaces them.

## Alternatives Considered

- **Adopt Release Please now.** Rejected: it requires a GitHub Actions
  workflow, and Spark has none today (ADR-0005). Introducing CI just to
  release, ahead of the validation gate that actually motivates CI (#70), puts
  the cart before the horse and pre-empts the ADR-0005 amendment that #70 owns.
- **Keep the manual flow permanently.** Rejected: it duplicates by hand what a
  maintained tool does automatically — the exact overlap ADR-0006 removed for
  Cosmics. Spark not following its own doctrine once the CI prerequisite is
  gone would need a justification that no longer exists at that point.
- **Drive releases from `ship`'s bump mapping as the mechanism of record.**
  Rejected for the same reason ADR-0006 rejected it for Cosmics: hand-rolled
  logic that shadows a maintained tool drifts from it and is more surface to
  own.

## Consequences

- Release cadence stays manual (and release PRs must follow the three-step
  flow above) until #70 merges; #70 becomes a prerequisite for release
  automation, not just for validation.
- When adopted, the repo gains a `release-please` workflow and config as
  maintained files, and the manual flow retires — two release mechanisms at
  once is the ambiguity ADR-0006 exists to prevent.
- The `commit-msg` hook's conventional-commit enforcement becomes
  load-bearing for versioning: a mistyped commit type would mis-size a bump.
- Spark and its Cosmics converge on one release story, so the operator carries
  a single mental model.
- The `ship` skill is untouched by this decision; its release-step wording is
  governed by ADR-0006's consequence (defer to Release Please) and is a
  separate change.

## Open Questions

- Whether Release Please should also propagate the version into
  `.claude-plugin/marketplace.json` if a version field is ever added there.
  Owner: jwogrady.

## Related Docs

- [0006-cosmics-use-release-please.md](0006-cosmics-use-release-please.md) — the Cosmic-side decision this closes the open question of
- [0005-cosmics-ship-ci-spark-stays-ci-free.md](0005-cosmics-ship-ci-spark-stays-ci-free.md) — the CI-free stance #70 amends, which gates adoption
- [../../plugins/spark/docs/explanation/sdlc-doctrine.md](../../plugins/spark/docs/explanation/sdlc-doctrine.md) — the version ladder the bump mapping follows
