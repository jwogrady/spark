# Fixture: negative — expected release-train work

**Expected classification:** local (no promotion, no ceremony).

## What a candidate is given

A milestone completes. Release Please rolls the accumulated `feat`/`fix`
commits into a dated changelog section, bumps the version file, and opens its
release PR. A maintainer merges it — the release act (ADR-0006/0009).

## The deletion test, applied

> Would this still be useful and true if this particular implementation
> disappeared and were rebuilt?

**No.** The mechanics of *how a release was cut* (which commits rolled into
which changelog entry, which version number was minted) are process facts
about this spoke's release history — CHANGELOG.md and the GitHub Release
already preserve them durably, in the spoke, which is exactly where release
history belongs (ADR-0028's ownership boundary: "each spoke owns its
implementation truth... releases"). There is no cross-spoke meaning here
distinct from what shipped.

Note the distinction from the *positive* fixture: if the milestone's shipped
outcome itself revealed a durable architectural boundary (the Prime/Cosmos
case), *that* is a promotion candidate raised at the milestone-completion
boundary — but the release mechanics themselves never are.

## What a good candidate does

- Lets Release Please do its job untouched; asks the milestone-completion
  promotion question about the *work*, not the *release mechanics*, and only
  once per milestone (ship's references/release-please.md) — never a second
  time for the release act itself.
- Does not treat "a release happened" as inherently promotion-worthy; only
  the shipped outcome's content can be.
