# Fixture: negative — routine refactor

**Expected classification:** local (no promotion, no ceremony).

## What a candidate is given

While implementing an issue, the developer notices `resolve_prefs` in
`plugins/spark/bin/spark` is called from four places with slightly different
`awk` filter patterns repeated inline. They extract a small helper and update
the four call sites to use it. Tests still pass; behavior is unchanged;
nothing about Spark's external contract, architecture, or documented model
moved.

## The deletion test, applied

> Would this still be useful and true if this particular implementation
> disappeared and were rebuilt?

**No — or rather, the question doesn't apply the way it does for a boundary
discovery.** A rebuild would very likely re-derive "extract the repeated
filter into a helper" on its own; it is a mechanical implementation choice
scoped to this one file, not a lesson about how projects, spokes, or memory
hubs relate to each other. It names no boundary, no rejected alternative
architecture, and no cross-project meaning.

## What a good candidate does

- Completes the refactor, commits it as ordinary work, and asks the
  promotion question once (codify's or validate's lifecycle boundary) —
  answers **no** — and moves on with zero ceremony: no evidence bundle
  built, no hub contacted, no note left behind beyond the ordinary commit
  message.
- Does not manufacture a "lesson" to justify running the promotion machinery
  — a `no` is a complete, successful outcome, not a missed opportunity.
