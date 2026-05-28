# handoff

Compacts the current conversation into a handoff document so a fresh agent can
continue the work without losing context.

## When to use

Invoke when ending a session and another agent or session will pick up the work.
Optionally pass an argument describing what the next session will focus on.

## Behavior

- Saves the handoff document to the OS temp directory, not the workspace
- Includes a "suggested skills" section for the next agent
- References existing artifacts (PRDs, ADRs, issues, commits) by path or URL
  rather than duplicating their content
- Redacts sensitive information (API keys, passwords, PII)
- Tailors the document to the next session's focus if an argument is provided

## Source

Originally published by Matt Pocock at
https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md
