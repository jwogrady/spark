# Codify-readiness

> Reference — the gate between **Plan** and **Codify**.

Spark's hooks verify *form*: conventional commit messages, one concern per
commit, no pushes to trunk, no force-push without a lease. Codify-readiness
verifies *substance*: whether a plan is actually buildable. A change can pass
every form check and still be unbuildable — perfect acceptance criteria, no
stack. This gate closes that gap.

## The checklist

A change is **Codify-ready** when all of these hold:

- [ ] Problem statement exists and is confirmed (`ideate`).
- [ ] Prior art / existing assets surveyed.
- [ ] Stack / architecture recorded as ADRs under `docs/adr/` (`plan`).
- [ ] Each issue has verifiable acceptance criteria (`plan`).
- [ ] A scaffold exists, or `bootstrap` is queued.

[`plan`](../../skills/plan/SKILL.md) produces these;
[`codify`](../../skills/codify/SKILL.md)'s preflight refuses to start until they
hold and sends an unready plan back to `plan` rather than guessing a stack.

## Optional health signal

At the Plan→Codify boundary, three numbers expose "planning ceremony, zero
product":

| Signal | What it measures | Healthy | Red flag |
|---|---|---|---|
| commits-to-first-code | commits before the first code file lands | low | high / never |
| doc:code byte ratio | markdown bytes ÷ code bytes | balanced | docs only |
| deferral density | "deferred / no mechanism" statements in the plan | few | many |

The case study that motivated this gate read **15 / ∞ / 64** — fifteen commits,
no code file ever, sixty-four deferrals: a glaring all-docs, zero-code plan that
still passed every form check. Computing these automatically is a candidate for a
future `spark` subcommand; today they are a manual sanity check.

## See also

- [explanation/enforcement-model.md](../explanation/enforcement-model.md) — why
  form is enforced mechanically, and where readiness picks up.
- [reference/skills.md](skills.md) — `plan` and `codify` in the lifecycle.
