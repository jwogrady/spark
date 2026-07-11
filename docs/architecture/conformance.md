# Architecture conformance — the shipped inventory against the carry model

> Developer reference — the audit required by the information architecture
> (ADR-0008). Every shipped component maps to a motion (carry-in /
> carry-through / carry-forward) or is explicit support with a rationale.
> This table is the test for future additions: anything new must name its
> layer, class, and motion before it ships. Attribution `jwogrady`.

## The test

For each component ask: which **motion** does it serve (carry-in,
carry-through, carry-forward), which **layer** does it touch
(Operator / Project / Session), and — if it is none of the three motions —
what is its explicit disposition (**support** with rationale, reclassify,
or deprecate)? "Neither, with no disposition" is a failing verdict.

## Skills (11)

| Skill | Motion | Layer touched | Verdict |
|---|---|---|---|
| `ideate` | carry-through (Ideate stage); carry-forward once the problem statement persists by default (#68) | Project | fits |
| `plan` | carry-through (Plan stage); writes the Project-layer backlog (GitHub) | Project | fits |
| `codify` | carry-through (Codify stage) | Project | fits |
| `validate` | carry-through (Validate stage) | Project / Session (findings promote to PR) | fits |
| `ship` | carry-through (Ship stage) | Project | fits |
| `bootstrap` | carry-in — applies the Operator standard at generation (completed by #61) | Operator → Project | fits |
| `connect` | carry-in — wires Operator-held services/secrets into Project configuration | Operator → Project | fits |
| `knowledge` | carry-forward — Project → Operator knowledge promotion (portability completed by #67) | Project → Operator | fits |
| `docit` | none | Project | **support** — materializes Project-layer knowledge outward as public docs; serves carry-through quality, is not itself a motion |
| `agents-md` | none | Project | **support** — maintains the Project-layer context files (CLAUDE.md / AGENTS.md) that brief any agent; adjacent to carry-in but scoped to one repo |
| `audit` | none | Project / Session | **support** — Validate-adjacent whole-project audit: assess promotes findings Session → Project via issues/PRs; purge enforces docs-describe-reality (truth hygiene) across the Project layer |

## CLI verbs (shipped)

| Verb | Motion | Verdict |
|---|---|---|
| `doctor` | none | **support** — the mechanical health gate; grows into the superset validator (#71, #72, #73) |
| `list-skills` | none | **support** — discovery |
| `new-skill` | none | **support** — contribution scaffolding (linted at scaffold time by #76) |
| `install-git-hooks` | none | **support** — installs Door 2 of the two-doors enforcement |
| `shred-env` | carry-forward hygiene (negative space) | fits — deliberate destruction of Session-layer secret material that must *not* carry forward |

Planned verbs map cleanly before they exist: `preferences` (#63) is carry-in,
`brief`/`status` (#62) is carry-in + carry-forward, `resume` (#66) is
carry-forward, `version` (#75) is support.

## Enforcement hooks

| Hook | Motion | Verdict |
|---|---|---|
| `guard-bash.sh` (PreToolUse) | none | **support** — Door 1; mechanically protects carry-through discipline on the Claude-driven path |
| `commit-msg`, `pre-commit` (git hooks) | none | **support** — Door 2; same intent on the human-driven path |

## Agent crews

| Crew | Motion | Verdict |
|---|---|---|
| `knowledge` (6 roles) | carry-forward | fits — the working crew behind the `knowledge` skill's promotion motion |
| `docit` (13 roles) | none | **support** — the working crew behind `docit`'s outward authorship |

## Result

**Clean pass.** Every shipped skill, verb, hook, and crew is either a motion or
explicit support with a stated rationale; nothing is "neither" without a
disposition, and nothing requires deprecation or reclassification.

**Declaration:** ADR-0008 is Accepted — **Spark Architecture v1.0 is
complete**. Subsequent milestones are implementation of the model, not
expansion of the design.
