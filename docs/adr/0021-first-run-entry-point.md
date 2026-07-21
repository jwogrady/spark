# ADR: The first-run entry point is a hybrid — a guiding skill over mechanical verbs

Date: 2026-07-21
Status: Accepted
Owner: jwogrady

## Context

v0.11's product outcome is "a safe first-run experience." The pieces already
shipped: `spark orient` classifies a repo (ADR-0022), `spark setup` arms it in
one create-only run (ADR-0012), setup seeds `CONVENTIONS.md` /
`ENGINEERING-STANDARDS.md` (ADR-0020), and `spark brief` reads back the
classification and standards. What was missing (#199) is the *composed*
experience — orient → choose profile → seed standards → brief — as one guided
narrative with a defined order and clear human-decision stops, instead of four
motions an operator must know to sequence.

The open question was **where that narrative lives**. Two honest shapes:

- **Rewrite `spark setup` into an interactive first-run wizard** that prompts,
  branches on classification, and walks the operator through profile choice.
- **A new interactive surface** that sequences the existing, already-tested
  mechanical verbs and owns only the conversation.

`spark setup` is deliberately mechanical: composition-only, idempotent, safe to
call from `bootstrap` and from CI with `--yes`, exercised by behavioral tests
that assume a non-interactive contract. The human-decision stops the first run
needs — resolving an `ambiguous` verdict, choosing a profile, deciding each `!`
placeholder — are conversational judgment, which is what a skill is for.

## Decision

The first-run entry point is a **hybrid**, split along the line between
conversation and mechanism:

- **A new orchestrating skill, `/spark:onboard`,** owns the interactive guided
  narrative and every human-decision stop. It sequences four motions — ORIENT
  (`spark orient`), PROFILE (`spark profiles` → `spark setup --profile <name>`),
  SEED (`spark setup` composes hooks + permissions + the standards docs), and
  BRIEF (`spark brief`) — stopping at each ambiguous verdict, profile choice,
  and `!` needs-a-decision line rather than defaulting through it.
- **The mechanical steps stay in the CLI verbs the skill calls.** `spark setup`
  remains the create-only, idempotent, non-interactive seed it already is — it
  is *not* rewritten into a wizard. Every step is create-only, so rerunning the
  flow resumes or truthfully reports "already armed."
- **Lightweight routing hints, additive only.** `cmd_setup`, when run in an
  unarmed repo, names the guided flow (`/spark:onboard`) instead of silently
  arming as the only path; `cmd_brief`'s unclassified path (added by #201)
  points at the same guided flow. These are pointers, not behavior changes —
  setup still arms, brief still reports.

Why: the two concerns have different testability and different reuse. A skill is
prose Claude follows — it cannot be unit-tested, but it is exactly the right
home for judgment and dialogue. The verbs are deterministic Bash the behavioral
suites already cover, and `bootstrap` and CI depend on `setup` staying
non-interactive. Rewriting `setup` into a wizard would either break those
callers or grow a second, interactive code path that drifts from the mechanical
one. Keeping the narrative in a skill and the mechanism in the verbs gives one
guided experience without a second application engine — the same discipline
ADR-0012 applied to `setup` itself.

## Alternatives Considered

- **Rewrite `spark setup` as the interactive first-run wizard.** Rejected: it
  breaks `setup`'s non-interactive contract that `bootstrap` and CI (`--yes`)
  rely on, and it puts conversational judgment into tested mechanical Bash.
- **A new `spark first-run` CLI verb that prompts and branches.** Rejected:
  prompting, branching on classification, and adapting seeded prose to a project
  are judgment work, not mechanism — a skill does this natively, and a
  prompt-heavy Bash verb would be hard to test and easy to drift.
- **No new surface — document the four-command sequence in a how-to.** Rejected:
  the flow *is* the feature this release is named for; leaving it as prose the
  operator must assemble is precisely the gap #199 exists to close.

## Consequences

- The core plugin now ships nine skills, not eight; the skill count is bumped
  across `CLAUDE.md`, `AGENTS.md`, `README.md`, `get-started.md`, and the
  canonical taxonomy (`reference/skills.md`), and doctor's taxonomy-parity check
  keeps `onboard` registered.
- `onboard` is prose, so its correctness is verified indirectly: the behavioral
  suite (`tests/test-first-run.sh`) exercises the composed CLI sequence the
  skill drives — arm + seed + record on a fresh repo, brief reports them, a
  rerun is a no-op, a mature repo classifies `existing` and creates nothing.
- The routing hints add a second place the guided flow is named; as with all
  Spark redundancy that carries a small drift risk, held in check by keeping the
  hints to a single additive line each.
- `spark setup` keeps its exact mechanical contract, so `bootstrap` and CI are
  untouched.

## Related Docs

- [0012-setup-is-the-one-command-carry-in.md](0012-setup-is-the-one-command-carry-in.md) — the create-only carry-in `onboard` sequences, never forks
- [0022-orient-first-classification.md](0022-orient-first-classification.md) — the classification the flow orients on first
- [0020-project-local-prose-standards.md](0020-project-local-prose-standards.md) — the standards docs the seed motion composes
- `plugins/spark/skills/onboard/SKILL.md` — the guided narrative this decision creates
- `plugins/spark/docs/reference/skills.md` — the canonical taxonomy `onboard` is registered in
