# Reference — the work state (`.spark/state.json`)

> Reference — information-oriented.

`.spark/state.json` is the durable work state — the carry-forward artifact
(ADR-0008: Project layer, durable, small) that lets a new session answer
"where was I, what's next?" without rediscovery. It lives at the git root
beside the project preferences (`.spark/preferences.json`, ADR-0010), is
committed, and is written by the lifecycle skills at each stage's close-out.
`spark resume` renders it, cross-checked against the live repo; `spark brief`
reads it for the locate line of the session brief.

## Schema

Flat JSON, one level deep, string values only — readable by the same
zero-dependency reader the preferences use (`read_flat_json`: `jq` fast-path,
awk fallback). Numbers are digit strings (`"66"`, never `66`). An empty string
means "nothing recorded"; a missing key means the same; unknown keys are
ignored. Values are lowercase machine values — readers print them verbatim.

| Key | Meaning | Format |
|---|---|---|
| `stage` | The lifecycle stage whose close-out wrote this state | `ideate` \| `plan` \| `codify` \| `validate` \| `ship` |
| `problem_statement` | The active problem statement | repo-relative path, normally `docs/problem-statement.md` |
| `issue` | The active work item | GitHub issue number as digits, no `#` (e.g. `"66"`) |
| `branch` | The working branch | branch name (e.g. `feat/resume-state`) |
| `pr` | The open pull request, once `ship` opens one | PR number as digits, no `#` |
| `blockers` | What is stopping progress | one line; `""` when none; separate several with `; ` |
| `next_action` | The first thing the next session should do | one imperative sentence |
| `updated` | When the state was last written | ISO date, `YYYY-MM-DD` |

Every write sets `updated`. A value that stops applying is set to `""`, not
deleted — the key list stays stable.

## Example

```json
{
  "stage": "codify",
  "problem_statement": "docs/problem-statement.md",
  "issue": "66",
  "branch": "feat/resume-state",
  "pr": "",
  "blockers": "",
  "next_action": "Run /spark:validate on feat/resume-state",
  "updated": "2026-07-09"
}
```

## Who writes it, who reads it

- **Written** by the five lifecycle skills at close-out: `ideate` records the
  statement's path, `plan` the issue picked for codify, `codify` the branch,
  `validate` the blockers, `ship` the PR. Claude edits the file directly per
  each SKILL.md's carry-forward step; there is no CLI write verb — the state
  records judgment calls no script can infer.
- **Read** by `spark resume` (the full "where you were / what's next" view,
  every key) and `spark brief` (the locate line: `stage`, `issue`,
  `next_action`, `blockers`, `updated`).
- **Committed.** Carry-forward means surviving `/clear`, a new terminal, and
  a fresh clone; a gitignored file survives none of those.

The state tracks the one active work item, not the backlog — GitHub owns the
backlog (ADR-0008). `plan` leaves `issue` empty until one is picked for
codify.

## Staleness

The state is a claim; the repo is the truth. `spark resume` cross-checks every
fact it prints — branch existence and checkout via git, PR and issue state via
`gh` when available, problem-statement existence on disk — and flags what
drifted instead of trusting it. The schema is deliberately these eight keys
and no more: anything richer belongs to the knowledge layer, not work state.

## The loop close

A merged recorded PR means the state describes a **finished loop**: every
value in the file — stage, branch, `next_action` — predates the merge, so the
recorded next action would send the next session back into finished work.
When `gh` reports the recorded PR as merged, `spark resume` still prints the
drift notes but replaces the stale `next_action` with the loop restart:
start the next problem, or re-frame from `docs/problem-statement.md`. The
state file itself is not rewritten by `resume` — the next lifecycle stage's
close-out rewrites it, as always.
