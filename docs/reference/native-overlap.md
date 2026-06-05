# Reference — native built-in overlap audit

> Reference — information-oriented. Proves the claim in
> [../explanation/scope-and-upstream.md](../explanation/scope-and-upstream.md):
> no Spark skill reimplements a Claude Code built-in. It either **delegates to**
> one, deliberately **stays out of** its lane, or has **no** relationship.

## Scope

The dedup target is **Claude Code native built-ins only** — the skills and slash
commands that ship with every Claude Code install and are therefore guaranteed
present (`/code-review`, `/security-review`, `/review`, `/init`, `grill-me`,
`verify`, `run`, `simplify`, `deep-research`, …). Third-party and marketplace
plugins are **out of scope**: Spark cannot assume any given user has them
installed, so it never designs around them.

Relationship vocabulary:

- **delegates-to** — the skill invokes the built-in instead of duplicating it.
- **stays-out-of-lane** — the skill is adjacent to a built-in but deliberately
  scoped differently, so the two do not compete.
- **none** — the skill touches no native built-in (it wraps `git`/`gh`/a
  scaffolder, or owns a job the built-ins don't cover).

## Audit table

| Skill | Native built-in(s) touched | Relationship | How |
|---|---|---|---|
| `ideate` | `grill-me` | delegates-to | Invokes `grill-me` to pressure-test the problem statement; owns the framing, not the interview. |
| `plan` | — | none | Wraps `gh` to draft issues + a milestone. No built-in covers issue decomposition. |
| `codify` | `verify`, `run` | stays-out-of-lane | Owns implementing one issue; `verify`/`run` confirm behavior afterward. Complementary, not overlapping. |
| `fix-issue` | `/code-review`, `/security-review` | delegates-to | Orchestrates both built-ins on the branch diff, then triages and fixes. Ships no reviewer of its own. |
| `ship` | — | none | Wraps `git` (conventional commit) + `gh` (one PR). No built-in covers this. |
| `docit` | — | none | Multi-persona crew for public docs. No built-in generates docs. |
| `knowledge` | — | none | Internal-knowledge crew (ADRs, SOPs, specs). No built-in generates docs. |
| `bootstrap` | — | none | Wraps the official runtime scaffolder (Bun / uv). No built-in scaffolds runtimes. |
| `connect` | — | none | Secrets + service connectivity via `op` (1Password). No built-in covers this. |
| `agents-md` | `/init` | delegates-to | Defers net-new `CLAUDE.md` creation to `/init`; owns maintenance, audit, drift-check, and `AGENTS.md` (which `/init` never writes). |
| `review` | `/review`, `/code-review`, `/security-review` | stays-out-of-lane | Whole-**project** audit by specialist agents. The built-ins review **one diff/PR**. Different unit of work — see finding F1. |

## Findings to resolve

These are the only items where the boundary is real but not yet visible at skill
selection time (Claude sees only the `description` frontmatter). They are
resolved by clarifying descriptions in **#29**, not by changing behavior.

- **F1 — `review` name collision.** Spark's `review` shares the word "review"
  with native `/review` and `/code-review`. The scope differs cleanly
  (whole codebase across 8 dimensions vs. a single diff/PR), but a user picking
  a skill can't see that. Resolution: the `review` description must point
  single-diff/PR users to the native review tools (and to `fix-issue` for one
  branch). No rename (per the clarify-only constraint).
- **F2 — `codify` under-leverage (opportunity, not overlap).** `codify` does not
  currently invoke `verify`/`run` to confirm the change behaves. This is a
  complement, not a duplication; noted here so it isn't mistaken for a gap.
  Out of scope for this milestone.

No Spark skill reimplements a native built-in.
