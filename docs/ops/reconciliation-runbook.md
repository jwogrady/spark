# Runbook — reconciling an existing repository

> Development-only record. Not shipped. The operator procedure for
> `spark reconcile`: how to read a slate, how to approve part of it, and what to
> do when something goes wrong mid-run.

Triage establishes what is true. Reconciliation turns that evidence into a slate
and, on your explicit approval, carries out the parts you selected. The verb
proposes; you decide; it applies one group at a time and checks its own work.

```
observe → classify → propose → approve → mutate → validate
                              ^ you are here, and nothing moves until you are
```

## 1. Read the slate

```bash
spark reconcile
```

Read the two columns that are easy to conflate, because the whole design rests
on them being different questions:

| Column | Question |
| --- | --- |
| `evidence` | what could Spark actually read? |
| `disposition` | what is proposed? |
| `authority` | whose call is it? |

**A row whose evidence is `unread` has no disposition at all.** That is not an
omission. Spark could not read the surface, so it has nothing to propose — and
inventing one would turn missing evidence into a guessed decision.

**`DECISION-REQUIRED` is not a queue of work for Spark.** It is the list of
things only you can settle. No flag makes those applicable, and the exit code
says so: `5` means a decision is outstanding, `3` means something could not be
read, `0` means nothing needs reconciling.

Use `--tsv` when you want the whole slate rather than the capped human view, or
when something downstream is going to read it.

## 2. Approve deliberately, one finding at a time

An approval names a specific finding, `area:id`:

```bash
spark reconcile --approve release:v0.20.md            # preview, changes nothing
spark reconcile --approve release:v0.20.md --yes      # actually apply it
```

Without `--yes` you get a preview.

**`--yes` applies file edits and nothing else.** Deleting a branch, closing a
milestone and provisioning governance are reported with the exact command, and
you run it:

```
branch:spent-work — DROP-ARCHIVE, and reconcile does not carry this out.
    run yourself: git branch -d spent-work
    It deletes a ref or changes remote state, so it cannot land as
    one revertible commit. No flag changes that.
```

That is not caution for its own sake. Every automatically applied group is one
commit you can revert; a deleted ref and a closed milestone are not commits, and
letting them ride under `--yes` would mean the guarantee no longer held for
everything it covers. There is no flag that overrides this, and an invented one
is rejected rather than ignored.

**Approve a few findings, not the whole slate.** The point of a group being one
finding is that you can change your mind about one of them.

### Governance is delegated, not driven

A governance finding always reports rather than acts, even though Spark has a
perfectly good `governance apply`. The reason is that `apply` works on a **whole
family**: driving it from one approved finding could provision surfaces you
never approved, and re-deriving the slate would not catch it — your finding
would be gone and so would the others, which looks like success.

One approved finding has to mean one mutation and nothing else. Run
`spark governance apply` yourself, where its own preview and `--repair-drift`
gate show you the full set you are agreeing to.

## 3. What happens per group

For each approved finding, in the order you gave them:

1. the change is made;
2. if it touched the tree, it lands as **exactly one commit**;
3. the slate is **re-derived** and the finding must be gone.

Step 3 is the validation, and it deliberately re-runs the producer rather than
trusting the command's exit code. A check that asks "did the command succeed?"
passes when the command succeeded and did the wrong thing.

If a group fails, the run **stops there**. Earlier groups stay applied — they
were each validated — and nothing later is attempted.

## 3b. Approving the same thing twice

Each selector is resolved against a **freshly derived slate immediately before
acting**, not against the slate you read at the start. So approving one finding
twice does not make it two groups — the second is refused, because by then it is
no longer a finding:

```
release:v0.2.md — no such finding in the current slate
    The slate is re-derived before every group, so this covers both the
    case where you approved it twice and the case where an earlier group
    cleared it.
```

The same rule covers the case you did not intend: an earlier approved group that
happens to clear a later selected finding. A stale row never authorises a
mutation.

**`Applied N group(s)` always equals the number of commits made.** A group that
turns out to change nothing is refused rather than counted, so the number you
read and the number of things you can revert are the same number.

## 4. Undoing one group

Because each group is its own commit, reverting one leaves the rest alone:

```bash
git log --oneline            # find the group's commit
git revert <sha>             # the others stay applied
spark reconcile              # the reverted finding is back on the slate
```

That last line matters: the slate is re-derived from the repository every run,
so it tells you the truth after a revert without any bookkeeping.

## 5. When the tree is dirty

`reconcile --yes` refuses to apply anything while there are uncommitted changes.
That is not fussiness — "one commit per group" would be a lie if unrelated work
rode along in the same commit, and reverting the group would then take that work
with it. Commit or set aside your changes and re-run.

## 6. What it will not do

- It will not settle a `DECISION-REQUIRED` finding. Record the decision in the
  governed field yourself; the finding clears on the next run.
- It will not delete a ref, close a milestone, or provision governance. Those
  are reported with the command to run. A later release may automate them, but
  only behind a real compensating contract — an "undo" that works — rather than
  behind a flag.
- It will not propose dropping an **unmerged** branch. Only branches whose
  commits are already in trunk are proposed, so no history is lost.
- It will not propose dropping trunk, a release line, or `gh-pages`.
- It will not delete a record because it is old. A release record that has been
  `Blocked` keeps saying so in its history; only the current-state claim is
  corrected.

## 7. When the slate is clear: deciding the course

Reconciliation ends when nothing material is left to reconcile. It does not tell
you *what to do next* — that is a different question with a different verb:

```bash
spark course
```

It reads the truth pass and this slate rather than the repository again, and
answers with one of five courses: continue the active milestone, repair it,
close out a finished one, plan a new one, or stop because two directions are
genuinely open. That last one is the only outcome that needs you, and it exits
`5` so a script can tell.

Three verbs, three questions, and it is worth keeping them apart in your head:

| `spark brief` | where the lifecycle left off |
| `spark course` | which objective is coherent next |
| `spark next` | which issue inside that objective |

`course` records nothing. It will not create a milestone, set a priority or a
disposition, or write down a direction — a repository is not made coherent by
writing something that says it is.

## 8. If an approval names something that has gone

```
release:v0.20.md — no such finding in the current slate
```

The slate is re-derived every run, so an id that named a finding an hour ago may
name nothing now — usually because someone else fixed it, or because an earlier
group in this run resolved it. Re-read the slate and approve from what it says
today.
