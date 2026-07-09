# How to maintain CLAUDE.md and AGENTS.md

> How-to — task-oriented.

Use this to create, audit, or sync a repo's agent behavioral-contract files:
`CLAUDE.md` (read by Claude Code) and `AGENTS.md` (the tool-agnostic companion
any AI coding agent absorbs). They share one behavioral contract and must stay
in sync.

1. For a brand-new `CLAUDE.md`, run the native `/init` first — the skill
   deliberately does not reimplement it.
2. Invoke `/spark:agents-md`. It reads both files before touching anything —
   never overwriting blindly.
3. Say what you want: author `AGENTS.md` (derived from `CLAUDE.md`, restated as
   a standalone document), patch missing sections, refresh stale content, or
   run a sync audit. If you don't specify, it asks.
4. The skill enforces the shared contract in both files: attribution (credit
   the human author only, never an AI), branch and PR discipline, conventional
   commits, confirmation before destructive actions, the GitHub boundary, and
   scope discipline.
5. It links Spark's methodology instead of pasting it — a project repo carries
   only its own problem, decisions, and plan, with a short "How this project is
   built" pointer to Spark. It also strips residual process framing (`Phase N`
   headers, `/spark:` stage references) from the contract files.
6. If the two files contradict, the skill flags the drift rather than silently
   resolving it — `CLAUDE.md` is authoritative for Claude Code, `AGENTS.md` for
   all other agents; update them together.
7. Review the diff and give a go-ahead before any existing file is overwritten.

**Done when** both files carry the required sections, state real commands
instead of placeholders (TODO markers where a value can't be verified), and a
sync audit reports no drift. A short accurate contract beats a long one.
