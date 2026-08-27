# Creating the issues on GitHub

> Reference for the `plan` skill's issue-creation step. Consulted only once the
> user has approved creating the slate — drafts always come first.

- Only call the GitHub API / `gh` after explicit user confirmation (per
  `AGENTS.md`). Default to producing the drafts first; create on approval.
- Compile the approved slate with `spark plan` rather than narrating `gh`
  calls. Write a tab-separated artifact (one body file per issue):

  ```
  issue      KEY     title  labels,csv  milestone  body-file
  milestone  KEY     title  description
  subissue   PARENT  CHILD          # refs: a KEY above, or #N for an existing issue
  blockedby  ISSUE   BLOCKER  [reason]
  order      REF     position
  update     #N      title|labels|milestone|body-file  value
  decision   REF     question
  ```

  Then `spark plan validate` (structure *and* schema, read-only), `diff`
  (against live state), `apply --yes` once the human approves, `verify`.
  Everything is validated before any call, so an invalid artifact changes
  nothing; a rerun skips exactly what `.issue-manifest.state` records. Format
  and state semantics: the script's header and
  [`cli.md`](../../../docs/reference/cli.md).

- **The artifact may create its milestone** — a `milestone` record, referenced
  by KEY; more than one is allowed. Labels must already exist (`spark
  governance apply`).
- **Preferred order goes in an `order` record, never `blockedby`** — an edge
  expressing sequence becomes a false prerequisite `codify` reports as a
  permanent blocker. It applies as sub-issue order under a parent, the
  authority `spark next` reads, so the issue must also be a `subissue` here.
- **An existing issue is changed with an `update` record**, not by hand.
- **Never guess at unresolved meaning** — a `decision` record refuses the run
  until it is answered.
- If the user prefers, output the issues as markdown drafts they create
  themselves.
