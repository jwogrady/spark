# Philosophy

**AI-assisted dev is fast and loose by default. Spark calls that a bug, not a
feature — and answers it with a mechanical system that makes the right thing easy
and the wrong thing hard.**

> *The values layer. The ADRs (`docs/adr/`) are the decisions layer;
> every principle below ties back to a shipped feature — no untethered manifesto.*

## The problem Spark refuses to accept

AI-assisted development is powerful, fast, and loose by default. The default mode
is: a developer types a prompt, the model does something, the developer reviews
(maybe), ships (maybe), and the whole exchange evaporates. No lifecycle, no
guardrails, no durable artifact trail. The conventions that make a team coherent —
conventional commits, trunk discipline, scoped issues, focused PRs — are easy to
state and easy to skip when you are moving fast with an AI in the loop.

Spark refuses to accept that productivity and discipline are in tension. The
assumption it contests is that "moving fast" and "staying clean" are a trade-off.
They are not. They require the same thing: *a mechanical system that makes the
right thing easy and the wrong thing hard.* Spark is that system for AI-assisted
development.

## The doctrine

**1. Enforcement over aspiration.** A convention you can skip is a suggestion, not
a guardrail. Spark's rules are enforced by code that runs before Claude acts or
before a commit lands. The PreToolUse Bash guard blocks force-pushes and trunk
pushes before they execute, covering AI-mediated git actions. The `commit-msg` hook
rejects non-conforming messages before they land in history, covering all commits
once the hooks are installed via `spark install-git-hooks`. Aspiration lives in
READMEs; enforcement lives in `hooks/` and `scripts/hooks/`. Validation CI gates
every PR to the Spark repo by running `spark doctor` — the same command as the
local gate, so the two cannot drift. What remains unautomated is behavioral
regression on the skills themselves; their quality gate is use.

**2. One lifecycle, portable.** Every project deserves the same discipline — not a
copy-paste of conventions that drift per repo, but one versioned toolkit installed
once and carried everywhere. Install via Git URL is verified; one-click
public marketplace install is still an open item. The portability principle is
architecturally realized; the marketplace listing is in progress. This is a
single-developer toolkit today; team coordination is on the roadmap.

**3. Additive by design.** Spark does not reinvent what already exists. Claude Code
ships `/code-review`, `/security-review`, and `verify`; Spark routes to them.
Anthropic owns the skill/plugin spec; Spark builds on it. This is not modesty — it
is the correct architectural choice. The same logic governs contributions: a new
skill is additive, not a patch to the core lifecycle. Skills are self-contained by
design, with no cross-skill imports at runtime.

**4. Scoped work as the unit of discipline.** One problem per ideate, one feature
per issue, one issue per branch, one concern per PR. This is not bureaucracy — it
is the mechanism by which large ambitions become shippable increments. Scope
collapse is the most common cause of AI work going sideways; Spark makes scope a
first-class enforced concept. This operates on a single developer's context today;
the scope doctrine is valid and enforced within that boundary.

**5. Zero external dependencies.** A tool that requires a bespoke runtime fails
when the runtime breaks. Spark's CLI and hooks are pure POSIX-friendly Bash with
graceful degradation when optional tools (`jq`, `python3`) are absent. Any forked
project, any stack, any machine — the guardrails still hold.

**6. Honest attribution, honest hype.** The `commit-msg` hook blocks AI co-author
trailers mechanically, with exit code 2. The authorship crews' citation
discipline (the `spark-docs` companion) holds the other end: no claim ships
without evidence beneath it, and the author is the final gate. The first is a
deterministic code check; the second is a rigorous process with author review as
the final gate. Both reflect one belief: the author of the work is the author of
the work, and claims travel only as far as the evidence beneath them. An issue-first
gate reinforces this at the contribution level — new skills require a GitHub issue
and community feedback before any code is written.

**7. One canonical source per class of information.** Preferences, decisions,
knowledge, state — each kind of information Spark manages has exactly one place
its truth lives, and everything else points there. Two documents that must agree
will eventually disagree; a class with no decided home becomes a contradiction
waiting to be filed. The layers-and-classes model in ADR-0008 is this principle
made mechanical.

**8. Operator, Project, and Session are separate layers.** What travels with
the person, what belongs to the repo, and what dies with the conversation are
three different things, and every artifact belongs to exactly one. Movement
between layers is explicit — commit, PR, or deliberate promotion — never silent
copying. Blurring these layers is how preferences get re-typed per project and
work evaporates at session end.

**9. Carry context, don't recreate it.** The operator loads preferences once
and every project starts already carrying them; a new session resumes the work
instead of re-deriving it. Re-explaining your own standards to your own tooling
is waste, and Spark treats it as a defect, not a ritual. Carry-in,
carry-through, carry-forward — the three motions in the glossary — are this
principle in verb form.

## The future Spark argues for

The future Spark is building toward is one where AI-assisted development is
*indistinguishable from disciplined development* — where the speed and the rigor
are the same thing, not alternatives. The lifecycle does not slow you down; it is
the track that makes the speed safe. That future is not guaranteed by capability
alone. It requires tooling that encodes the right habits mechanically. The current
release line is the proof of concept; the architecture is set, the gaps are
documented.

## See also

- [`enforcement-model.md`](enforcement-model.md) — *why* mechanical enforcement was
  chosen over advisory rules (the rationale behind Principle 1).
- [`sdlc-doctrine.md`](sdlc-doctrine.md), [`additive.md`](additive.md),
  and the ADRs under `docs/adr/`.
