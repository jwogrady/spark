---
name: commit
description: Stage and write a conventional commit that follows Spark's rules — imperative subject under 72 chars, why-not-what body, and no AI attribution. Use when the user wants to commit, write a commit message, or save work to git.
---

# commit — Stage 5a of the Spark lifecycle

`Ideate → Plan → Generate → Solve → Ship`

A commit is one logical change with a message that explains *why*. Spark's
`commit-msg` git hook enforces these rules mechanically; this skill produces a
message that passes the first time.

## Do this

1. **Confirm the branch.** Never commit on `master`/`main` — if you're on it,
   branch first.
2. **Review what's staged.** `git status` then `git diff --staged`. Stage only
   what belongs in this one logical change.
3. **Write the message:**
   ```
   <type>: <imperative subject, under 72 chars, no trailing period>

   <body: why this change exists, not a restatement of the diff>
   ```
   - Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.
   - Subject in imperative mood (`add`, not `added`/`adds`).
   - Body explains the reason; reference issues (`Refs #12`) when relevant.
4. **Commit.**

## Hard rules (the hook will reject violations)

- **No AI attribution anywhere** — no `Co-Authored-By` for AI tools, no mention
  of Claude/Anthropic/Copilot/ChatGPT. Credit belongs to the author only.
- Conventional type prefix required.
- Subject ≤ 72 characters, no trailing period.
- One logical change per commit. If the diff spans two concerns, make two
  commits.

## Next

When the branch is ready, hand off to [`ship`](../ship/SKILL.md).
