# Creating the issues on GitHub

> Reference for the `plan` skill's issue-creation step. Consulted only once the
> user has approved creating the slate — drafts always come first.

- Only call the GitHub API / `gh` after explicit user confirmation (per
  `AGENTS.md`). Default to producing the drafts first; create on approval.
- Create and wire the approved slate with `scripts/issue-manifest.sh` instead
  of narrating `gh` calls. Write a tab-separated manifest (one body file per
  issue), preview with `--dry-run`, then run it live:

  ```
  issue      KEY  title  labels,csv  milestone-title  body-file
  subissue   PARENT  CHILD      # refs: a KEY above, or #N for an existing issue
  blockedby  ISSUE   BLOCKER
  ```

  It validates everything before any call (an invalid manifest changes
  nothing), batches lookups, appends `.issue-manifest.state` as each mutation
  lands, and skips already-created work on rerun — resume a failed run by
  rerunning the same command. Full format, plan output, and state semantics
  are documented in the script's header.
- The milestone and every label must already exist: the helper assigns, it
  never creates them — create a wanted milestone first (`gh api` on approval).
- If the user prefers, output the issues as markdown drafts they create
  themselves.
