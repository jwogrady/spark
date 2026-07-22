# Creating the issues on GitHub

> Reference for the `plan` skill's issue-creation step. Consulted only once the
> user has approved creating the slate — drafts always come first.

- Only call the GitHub API / `gh` after explicit user confirmation (per
  `AGENTS.md`). Default to producing the drafts first; create on approval.
- Use `gh issue create` with the template body, and `gh api` for the milestone
  if the user wants it.
- If the user prefers, output the issues as markdown drafts they create
  themselves.
