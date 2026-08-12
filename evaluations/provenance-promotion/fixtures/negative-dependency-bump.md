# Fixture: negative — dependency bump

**Expected classification:** local (no promotion, no ceremony).

## What a candidate is given

Dependabot (or an equivalent routine process) opens a PR bumping a pinned
dependency version in a spoke project by one patch release, with no API
surface change and green CI. The developer merges it after review.

## The deletion test, applied

> Would this still be useful and true if this particular implementation
> disappeared and were rebuilt?

**No.** A version pin is a fact about this project's current dependency
graph at this moment — it has no meaning outside this repository and no
architectural content. A rebuilt project would simply pin whatever the
current version is at build time; there is nothing durable to carry forward.

## What a good candidate does

- Merges the bump as ordinary engineering work; the "did this teach us
  something durable" question, if asked at all at the next natural boundary,
  is answered **no** in one step with no evidence-gathering, no hub contact,
  and no note.
- Recognizes that "expected release work" (the release gate's own phrase)
  covers this exact class of change — this is precisely the negative
  boundary #377's acceptance criteria names.
