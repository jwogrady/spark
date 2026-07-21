# Release assignment — every feature gets a release decision

No feature enters `codify` without one of three dispositions, made from
evidence and recorded on the issue:

1. **A named target release/milestone** — the feature serves a roadmap line in
   that release's scope.
2. **Backlog / unassigned, with the reason** — nothing on the roadmap claims
   it yet; the reason is written down, not implied.
3. **Blocked pending a roadmap decision, naming the exact missing decision** —
   the smallest question a human must answer before the feature can be placed.

The human approves priority and release scope; the plan skill recommends with
evidence and never invents either. Preserving existing facts is part of the
contract: never silently retarget an issue's milestone, priority, or
relationships — propose the change and let the human apply or approve it.

## Check the roadmap before assigning

An assignment is only defensible if the roadmap can support it. Before
classifying features, run the deterministic check:

```bash
bash scripts/roadmap-check.sh            # from this skill's directory
# or point it at fixtures / another repo:
bash scripts/roadmap-check.sh --roadmap ROADMAP.md --issues issues.json
```

It verifies mechanically: a current (shipped) release is named; a next planned
release exists; every open `feature` issue has one of the three dispositions;
unshipped roadmap sections link real issues or are explicitly deferred. Exit
`0` means complete, `1` lists `GAP:` lines, `3` means it could not assess
(missing `jq`/`python3`).

**A roadmap gap is a planning blocker, not an invitation to guess.** When the
check reports gaps, stop and hand the human a concise report: each gap, the
evidence, and the smallest decision that resolves it (for example: "does
v0.11 include X, or does X go to backlog?"). Resume assignment after the
answer.

## What counts as evidence

- The roadmap line the feature serves (quote it), and that release's status.
- Open milestones and how full they are — issue ordering within a milestone
  is the delivery priority.
- Native dependencies: what this feature blocks or is blocked by.
- Current release state (what actually shipped last — not what the roadmap
  hoped).

## Category rules differ

Release assignment is a **feature** rule. The other taxonomy categories carry
lighter defaults:

| Category | Release rule |
|---|---|
| `feature` | Must have a disposition (milestone / backlog+reason / blocked+decision) before codify |
| `bug` | Rides the current or next milestone by severity; a P0 bug does not wait for planning |
| `documentation`, `chore` | Attach to the milestone whose work they serve; standalone ones may stay unmilestoned |
| `tech-debt`, `research` | Default backlog unless a milestone's acceptance criteria depend on them |
| `infrastructure` | Treated like features when they change what ships; like chores when purely internal |

## Keeping the roadmap synchronized

When an accepted assignment changes planned release scope (a feature enters
or leaves a milestone), the roadmap line changes in the same PR or is called
out for the human — the roadmap links milestones and issues; it never
duplicates their fields.
