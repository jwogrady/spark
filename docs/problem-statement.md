# Problem statement — the plugin ships more than its identity claims

> Authoritative — the problem this effort solves. Owner: `jwogrady`.

## Problem

Spark's identity is one thing: the operator's standards, loaded once and
carried into every project. The plugin ships twelve skills, but the
architecture conformance audit classifies four of them — the whole-project
reviewer, the cleanup generator, the public-docs crew, and the secrets
bootstrap — as support that serves none of the three carry motions. Those
four bring nineteen subagent definitions, three near-duplicate orchestration
protocols, a skill that emits a prompt instead of acting, dead reference
files from a pre-plugin era, and an operator decisions store nothing reads.
Every one of them is surface the operator must understand, doctor must
validate, and the docs must explain — dilution that makes the core promise
harder to see and costlier to maintain.

## Outcome

The plugin contains only what carries the standard: the five lifecycle
skills, project inception, internal knowledge capture, the agent-contract
maintainer, and one evidence-based audit capability that acts directly.
Everything removed is deliberate, recorded, and recoverable from history.
The remaining surfaces are truthful: the work state defines its own loop
close, and the one-command carry-in covers the whole permission baseline.

## Success criteria

1. One `audit` skill replaces `review` and `cleanup`, keeps the evidence
   table and deletion-safety discipline, and performs its audit directly —
   no copy-paste orchestrator prompt.
2. The public-docs crew and the secrets bootstrap are out of the plugin;
   `shred-env` remains; the skill taxonomy, doctor, and every doc surface
   agree on the reduced inventory.
3. The unread operator decisions store is deferred out of the shipped
   docs/protocol until a reader exists; glossary promotion is unaffected.
4. The agent-contract skill carries no dead reference files, and no repo
   template demands artifacts that skills do not ship.
5. Work state has a defined close: after the recorded pull request merges,
   the next brief/resume names the loop restart instead of a stale action.

## Prior art & reusable assets

- The architecture map's conformance test (ADR-0008, now enforced
  mechanically by doctor's taxonomy parity check) already classifies every
  component; this effort implements its verdicts.
- Precedent: `caveman`, `handoff`, and `commit` were removed or folded in
  earlier releases — dropping skills is an established, changelogged move.
- The cleanup skill's evidence table, confidence levels, and deletion-safety
  categories carry into the new audit skill; the reviewer's dimension list
  informs its assess mode.
- Extraction is removal-with-record: extracted skills' new homes are
  separate products seeded from this repo's git history.
- The one-command carry-in and its composition pattern (result counters,
  create-only application) are the model for any new CLI behavior.

## Constraints

- POSIX-friendly Bash, zero runtime dependencies; skills are Markdown.
- One concern per branch and pull request; every removal lands reviewable.
- Doctor stays the single validation gate and must pass after every change.
- Nothing already merged regresses: setup, preferences, brief, resume, and
  the enforcement doors keep their behavior.

## Non-goals

- No new homes built here for the extracted products — separate repos,
  separate efforts.
- No changes to the five lifecycle skills' behavior or the enforcement
  rules.
- No team-coordination features, no bundled MCP servers.
- No release; the milestone ships as reviewed pull requests, and the
  release mechanism rolls them up on its own.
