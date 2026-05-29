# write-a-skill

Guides the creation of new agent skills with proper structure, progressive
disclosure, and bundled resources.

## When to use

Invoke when the user wants to create, write, or build a new skill.

## Behavior

1. Gathers requirements (domain, use cases, scripts needed, reference materials)
2. Drafts `SKILL.md` and any supporting files (`REFERENCE.md`, `EXAMPLES.md`,
   `scripts/`)
3. Reviews the draft with the user before finalizing

## Key rules

- Description field must include triggers ("Use when...")
- `SKILL.md` should stay under 100 lines; split into reference files if larger
- No time-sensitive information in skill files
- Add utility scripts for deterministic operations to save tokens and improve
  reliability

## Source

Originally published by Matt Pocock at
https://github.com/mattpocock/skills/blob/main/skills/productivity/write-a-skill/SKILL.md
