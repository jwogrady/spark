---
name: plan
description: Turn a framed problem into an implementation approach (stack/architecture as ADRs), a feature breakdown, and GitHub issues plus a milestone. Use to decide the stack, break work into issues, or scope a milestone after `ideate`. Not for framing the problem (`ideate`) or implementing it (`codify`).
---

# plan — Stage 2 of the Spark lifecycle

`Ideate → Plan → Codify → Validate → Ship`

Plan converts a confirmed problem statement into a milestone `codify` can
execute. It reasons in a deliberate internal order — **model, then shape, then
design** — so technology is chosen as an answer to the domain and the shaped
outcome, never before them. The public lifecycle stays five stages; these are
reasoning steps inside Plan, not new verbs.

## Do this

1. **Read the problem statement.** Look at `docs/problem-statement.md` first —
   that's where `ideate` persists it. If it's not there and the user hasn't
   pointed at one, run [`ideate`](../ideate/SKILL.md) first.
2. **Model the domain — enough to name what is load-bearing.** Identify the
   concepts, roles, relationships, lifecycles, invariants, and ownership
   boundaries the implementation must satisfy ("a Zone exists independently of
   a VM"; "the serial must never regress"). Small projects may record "no
   deeper model needed" and move on — never force ceremony. Persist material
   invariants where later work will cite them (the problem statement, or the
   Context of the ADRs step 4 produces): later steps must be able to point at
   an invariant as the reason for a decision.
3. **Shape the milestone and its issues.** A milestone is a coherent working
   state good enough to ship, named by its observable outcome ("authoritative
   DNS survives one nameserver failing"), not a ticket bucket. Derive issues
   from the capabilities that outcome requires — not from framework or file
   structure. Prefer 3–7 features; more means the milestone is too big — cut
   scope. Express acceptance criteria as domain/product behavior where
   possible. **Capture dependencies now**: when issue B builds on issue A,
   record it — the manifest's `blockedby` records become GitHub blocked-by
   links, and `codify` refuses to start dependent work whose prerequisite
   isn't in its base. **Declare each issue's `docs-impact` disposition** now,
   while the reasoning is in hand — `docs-impact:none` is a first-class answer,
   silence is not.
4. **Design the implementation — last.** Now pick the stack the shaped outcome
   needs: language/runtime, top-level layout, key dependencies, deployment and
   security boundaries where relevant. Record each material choice as an ADR
   under `docs/adr/` (use the `0000-template.md` format) that says how it
   satisfies the model's invariants. Read the repo-root
   `ENGINEERING-STANDARDS.md` first — deviations belong in an ADR and its
   committed preference. If feasibility disproves a shaped assumption, loop
   back to steps 2–3 explicitly — never silently redefine the milestone
   around the tools. [`bootstrap`](../bootstrap/SKILL.md) materializes this
   accepted design; scaffolding before design is guessing.
5. **Give every feature a release decision.** Check roadmap completeness
   first (`bash scripts/roadmap-check.sh` from this skill's directory) and
   release-record truth (`bash scripts/release-plan-check.sh` — a plan names
   its milestone and never carries a tooling-limitation claim), then
   record one disposition per feature: a named milestone, **Backlog** with the
   written reason, or **Blocked** naming the exact missing decision — rules in
   [references/release-assignment.md](references/release-assignment.md). The
   milestone declares its intended version (see the version doctrine in
   [sdlc-doctrine.md](../../docs/explanation/sdlc-doctrine.md)). A roadmap gap
   is a planning blocker: report it with the smallest human decision needed;
   never guess a priority or version.
6. **Confirm before creating anything on GitHub.**
7. **Carry the state forward.** Record the close-out with
   `spark state --set next_action="<codify #<n>, or the next planning step — GitHub owns the backlog>"`
   (writes `.spark/state.json`, [schema](../../docs/reference/state.md); `updated` is stamped for you).

## Creating the issues

Draft first; create on GitHub only after explicit confirmation. Then create
and wire the whole approved slate — issues, sub-issues, and blocked-by
dependencies — with one deterministic helper: write a manifest, preview it
with `bash scripts/issue-manifest.sh --dry-run <file>` (run from this skill's
directory), and rerun without `--dry-run` to execute. Manifest format and
resume rules: [references/creating-issues.md](references/creating-issues.md).

## Guardrails

- Acceptance criteria must be verifiable — they become the `Validate` stage's
  definition of done.
- Technology answers the model and the shaped outcome, never the reverse. An
  issue with crisp acceptance criteria but no recorded stack is not
  [Codify-ready](../../docs/reference/codify-readiness.md).
- Do not create issues, milestones, labels, or projects without explicit
  instruction.
- Recommend with evidence; the human approves priority and release scope. Never
  silently retarget an existing issue's milestone, priority, or relationships —
  propose the change, don't apply it.
- Keep the milestone honest: if a feature can't be described in a paragraph,
  it's not understood well enough to plan.
- Do not write project-local copies of the Spark methodology. Link Spark's
  doctrine; the repo holds product, not process.
- Do not stamp issues, ADRs, or any doc with Spark-internal process framing —
  no `Phase N` / `Prompt NNN` status headers, no `/spark:` stage references, no
  "deferred to later Spark stages" as the way to say "not built yet." Status
  lines describe a doc's own authority and scope, not the lifecycle stage that
  produced it. Say "planned" or "not yet implemented," not "later Spark stages."

## Next

Pick an issue and hand it to [`codify`](../codify/SKILL.md).
