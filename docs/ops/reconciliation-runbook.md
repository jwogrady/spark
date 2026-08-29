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

Without `--yes` you get a preview. Approving something that deletes a ref or
touches remote state additionally needs `--allow-destructive`, said out loud on
top of `--yes`:

```bash
spark reconcile --approve branch/spent-work --allow-destructive --yes
```

Two flags is not ceremony. Deleting a branch and closing a milestone are the
actions you cannot undo with `git revert`, so they are the ones that ask twice.

**Approve a few findings, not the whole slate.** The point of a group being one
finding is that you can change your mind about one of them.

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
- It will not propose dropping an **unmerged** branch. Only branches whose
  commits are already in trunk are proposed, so no history is lost.
- It will not propose dropping trunk, a release line, or `gh-pages`.
- It will not delete a record because it is old. A release record that has been
  `Blocked` keeps saying so in its history; only the current-state claim is
  corrected.

## 7. If an approval names something that has gone

```
release:v0.20.md — no such finding in the current slate
```

The slate is re-derived every run, so an id that named a finding an hour ago may
name nothing now — usually because someone else fixed it, or because an earlier
group in this run resolved it. Re-read the slate and approve from what it says
today.
