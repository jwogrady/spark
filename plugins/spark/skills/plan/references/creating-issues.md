# Creating the issues on GitHub

> Reference for the `plan` skill's issue-creation step. Consulted only once the
> user has approved creating the slate — drafts always come first.

- Only call the GitHub API / `gh` after explicit user confirmation (per
  `AGENTS.md`). Default to producing the drafts first; create on approval.
- Compile the approved slate with `spark plan` rather than narrating `gh`
  calls. Write a tab-separated artifact (one body file per issue):

  Record types: `issue`, `milestone`, `subissue`, `blockedby`, `order`,
  `update`, `decision`. The script's header is the authoritative grammar —
  field order and rules live there, not restated here.

  Then `spark plan validate` (structure *and* schema), `diff` (against live
  state), `apply --yes` once the human approves, `verify`. Everything is
  validated before any call, so an invalid artifact changes nothing, and a
  rerun skips what `.issue-manifest.state` records. Full format and state
  semantics: the script's header and
  [`cli.md`](../../../docs/reference/cli.md).

- **The artifact may create its milestone**, more than one if needed. Labels
  must already exist (`spark governance apply`).
- **Preferred order goes in an `order` record, never `blockedby`** — an edge
  expressing sequence becomes a false prerequisite `codify` reports as a
  permanent blocker. It applies as sub-issue order under a parent, so the issue
  must also be a `subissue` here.
- **An existing issue is changed with an `update` record**, not by hand.
- **Never guess unresolved meaning** — a `decision` record refuses the run.
- If the user prefers, output the issues as markdown drafts they create
  themselves.
