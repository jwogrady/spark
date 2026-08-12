# How to maintain the agent contract (AGENTS.md + CLAUDE.md)

> How-to — task-oriented.

Use this to create, audit, or migrate a repo's agent behavioral contract. The
model is **one canonical body plus a pointer**: `AGENTS.md` carries the full
contract (any AI coding agent reads it directly), and `CLAUDE.md` is a stub
whose body is the `@AGENTS.md` import, so Claude Code loads the identical
contract. One body means the two files cannot drift.

1. For a brand-new repo, run the native `/init` first for discovery — the
   skill deliberately does not reimplement the repo scan.
2. Invoke `/spark:agents-md`. It reads both files before touching anything —
   never overwriting blindly.
3. Say what you want: author the canonical `AGENTS.md` (moving a
   `/init`-seeded `CLAUDE.md` body into it and leaving the import stub
   behind), patch missing sections, refresh stale content, run an audit, or
   **migrate a legacy dual-body pair** (a full `CLAUDE.md` and a parallel
   `AGENTS.md`) into the single-body model — merged, deduped, stricter rule
   winning on conflict, diff shown first. If you don't specify, it asks.
4. The skill enforces the behavioral contract in the body: attribution
   (credit the human author only, never an AI), branch and PR discipline,
   conventional commits, confirmation before destructive actions, the GitHub
   boundary, and scope discipline.
5. It links Spark's methodology instead of pasting it — a project repo carries
   only its own problem, decisions, and plan, with a short "How this project is
   built" pointer to Spark. It also strips residual process framing (`Phase N`
   headers, `/spark:` stage references) from the contract.
6. If the stub has grown Claude-specific rules that contradict the body, the
   skill flags the conflict rather than silently resolving it — the body wins
   unless the rule is genuinely tool-specific.
7. Review the diff and give a go-ahead before any existing file is overwritten.

**Done when** `AGENTS.md` carries the required sections with real commands
instead of placeholders (TODO markers where a value can't be verified), and
`CLAUDE.md` is the `@AGENTS.md` stub (plus any genuinely Claude-specific
notes). A short accurate contract beats a long one.
