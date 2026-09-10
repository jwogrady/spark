# Governance friction — guards scoped by shape, not effect

> **A governance-friction finding.** A dev-doc: it governs how Spark is built
> and reasoned about, and never ships. Owner: `jwogrady`.
>
> **Assessed master:** `35c506b7cd4020107852f0e498fa2c07ce3d2433`, 2026-08-31,
> the head of an isolated read-only audit worktree. No Spark code is changed by
> this record — it explains an issue and cites the fix that already exists.

The question that produced this doc was sharper than the audit that preceded it:
**is the governance useful, or slowing us down?** The honest answer is neither
"too much" nor "too little" — it is *mispriced*. The authority and security
guards are scoped by **effect** (what an action changes, how irreversible it is)
and they earn their cost. Some friction guards are scoped by **command shape**
(how a command is written) and over-block reversible, read-only work for no
safety gain. This doc names the pattern, records the one worked cure Spark
already shipped, and points at the one instance still outstanding — which lives
outside this repository.

Every observation below is `PASS` (the guard is correctly scoped), `CURED` (it
was mis-scoped and a landed change fixed it, with the issue named), or
`EXTERNAL` (real, but the code is not Spark's). There is no fourth disposition.

## The pattern

A guard decides whether to block by asking one of two questions:

| Scoping | Question it asks | Failure mode |
| --- | --- | --- |
| **By effect** | *Does this action write / merge / touch a protected surface?* | Rare false positives; a blocked command really could do the harm. |
| **By shape** | *Is this command complex / does it textually contain a dangerous token?* | Systematic false positives; a read-only command is refused for how it is written, not what it does. |

Scoping by effect is harder to implement (it must model what a command *does*)
and cheaper to live with. Scoping by shape is easy to implement and expensive to
live with, because the cost lands on every safe command that happens to share a
shape with a dangerous one. The doctrine on the wall — *never automate
inefficiency*, *measure before you optimise* — applies to the guards themselves:
a guard that fires on reversible, read-only work is paying a premium against a
risk that is not present.

## PASS — the guards that are scoped by effect

These are the ones the #672 review and this session's own guardrail catches
depended on, and they are correctly priced:

- **Trunk-push and force-push refusal** (`plugins/spark/hooks/guard-bash.sh`) —
  blocks the irreversible act, not the shape of the command.
- **The release gate holding a green PR** — CI green is not merge authority;
  the gate is scoped to the blast radius of a release.
- **"Cannot merge" must be mechanical** — the #583/#672 finding that a prompt
  instruction is not a control. Scoped by capability (token permissions,
  ruleset), never by what the prompt says.

The lesson these share: the cost of being wrong is high and hard to reverse, so
a false positive is cheap relative to a false negative. Keep them.

## CURED — the read-only over-block Spark already fixed (#526)

Spark's `guard-bash.sh` once scoped by shape: it replaced quotes with spaces and
walked every token, on the reasoning that an over-block is harmless. It is not.
Under that design these read-only commands were **refused**:

```
echo "do not git push origin master"
grep -r "git push origin master" docs/
```

and any heredoc whose body merely *mentioned* a push. The guarantee the docs
advertised — that the guard "tokenizes the command rather than substring-matching"
— would have shipped as false.

**#526 re-scoped it by effect while staying bypass-safe.** When no shell binary
is invoked, quoted spans and heredoc bodies are stripped before tokenising —
they are data, so a push named inside them is not an invocation. When a shell
*is* invoked (`sh -c '…'`, `bash <<EOF … EOF`), nothing is stripped, because then
quoted text genuinely can be a command. An unquoted `git push origin master`
anywhere still blocks. The result reads read-only commands as read-only without
opening a bypass — the exact move this whole doc argues for, already made, in
this repository, and worth citing as the template for the next one.

Disposition: **CURED (#526).** No further Spark change is warranted; stripping
more when a shell is invoked would reintroduce the bypass #526 closed.

## EXTERNAL — the instance still outstanding (Claude Code harness)

The friction observed repeatedly during the audit that produced this doc was
**not** Spark's guard. In an isolated worktree session, read-only commands were
refused with:

> This session is isolated in the worktree … but this command is too complex to
> verify that it stays inside the worktree. Refusing to run it — a
> worktree-isolated session's git operations must target its own worktree.

The refusal string appears nowhere in this repository. It is the Claude Code
**harness** worktree-isolation layer, and it scopes by shape: a compound
read-only command (a `for` loop over `ls`, a `python3` heredoc that only reads
files) is classed "too complex to verify" and refused, though it performs no
git operation and no write. Splitting it into single plain commands runs the
same work — so the guard adds round-trips without changing what the session can
do. Four such refusals occurred in one session, all read-only.

Disposition: **EXTERNAL.** The code is the host tool's, not Spark's; the
orchestrator that governs this repository cannot review or merge a harness
change. It has been routed as Claude Code product feedback, with #526 cited as a
worked example of scoping the same class of guard by effect. This doc records it
so the instance is tracked rather than lost, not because Spark can fix it.

## What this is not

- **Not a case against governance.** The `PASS` guards above just proved their
  worth on #672; a single held merge of a prompt-injectable, merge-capable lane
  pays for a great deal of process.
- **Not a measured baseline.** This records a pattern and four anecdotes, not a
  rate. Turning "is governance mispriced?" into a number — guard false positives,
  delegation round-trips, and hand-curation events per unit of shipped work — is
  a separate producer (the `bench.sh` analog for friction) and is not built here.
- **Not authority to retune anything.** Which friction guards to re-scope, and
  whether solo-operator work needs full delegation ceremony, are decisions the
  operator and orchestrator own. This doc is evidence for that decision, not the
  decision.
