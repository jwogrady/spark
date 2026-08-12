# Reference — the work state (`.spark/state.json`)

> Reference — information-oriented.

`.spark/state.json` records the two judgment values no repository can answer:
what to do next, and what is blocking. Everything else a session needs to
orient — current branch, its pull request, the issue, the lifecycle position —
is **derived live from git and GitHub** by `spark brief` and `spark resume`,
never stored. A stored copy of a derivable fact is a staleness generator: it is
written at one moment and trusted at a later one, and the v0.1.0 field test
proved it (a brief that opened every session with a stage the repo had left a
day earlier). Since v0.16 that failure is structurally unreproducible — nothing
reads a recorded stage, branch, issue, or PR, because none is written.

The file lives at the git root beside the project preferences
(`.spark/preferences.json`, ADR-0010) and is written by the lifecycle skills at
each stage's close-out via `spark state --set`.

## Schema

Flat JSON, one level deep, string values only — readable by the same
zero-dependency reader the preferences use (`read_flat_json`: `jq` fast-path,
awk fallback). An empty string means "nothing recorded"; a missing key means
the same; unknown keys are ignored on read.

| Key | Meaning | Format |
|---|---|---|
| `next_action` | The first thing the next session should do | one imperative sentence |
| `blockers` | What is stopping progress | one line; `""` when none; separate several with `; ` |
| `updated` | When the judgment was recorded | ISO date, `YYYY-MM-DD`, stamped on every write |

Every write sets `updated`. A value that stops applying is set to `""`, not
deleted — the key list stays stable.

## Example

```json
{
  "next_action": "Run /spark:validate on feat/resume-state",
  "blockers": "",
  "updated": "2026-08-11"
}
```

## Who writes it, who reads it

- **Written** by the five lifecycle skills at close-out through
  `spark state --set key=value …` — the skill supplies the judgment, the
  writer produces canonical JSON, merges into existing state, and stamps
  `updated`. `spark state` with no arguments prints the current values.
- **Read** as a *dated claim*, never as authority: `spark brief` shows
  `next_action`/`blockers` alongside its derived orientation, always with the
  recorded date; `spark resume` prints them under "Recorded intent" after the
  derived "Current reality" section and tells you to verify before acting.
- **Committed** by convention, so the judgment survives `/clear`, a new
  terminal, and a fresh clone. Because it holds only two slow-moving values,
  it no longer churns on every stage transition.

The state never tracks the backlog — GitHub owns issues, milestones, and PRs
(ADR-0008), and `brief`/`resume` read them live rather than mirroring them.

## The derived facts

What `brief`/`resume` derive instead of reading from a file:

| Fact | Source |
|---|---|
| branch, dirty count, ahead/behind | `git` |
| the branch's pull request and its state | `gh pr view` (skipped without `gh`; reported as unknown, never guessed) |
| lifecycle position | inference, positional evidence first: open PR → Validate/Ship; working (non-trunk) branch → Codify; then no `docs/problem-statement.md` → Ideate; else (on trunk with a statement) → Plan |
| trunk ancestry (commits on `origin/<trunk>` missing here) | `git rev-list` — surfaced by `resume` so a merged prerequisite is never silently missing (see the delivery ADR) |
| loop close | the current branch's PR reports `MERGED` — `resume` then refuses to replay a pre-merge `next_action` |

## Legacy files (pre-v0.16 schema)

Older Spark wrote `stage`, `problem_statement`, `issue`, `branch`, and `pr`
into this file. Those keys are **ignored on read** (resume flags them once),
**rejected on write** with a message naming the derived source, and the next
`spark state --set` migrates the file to the three-key schema. No manual
migration is needed.
