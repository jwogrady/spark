# Spark Alpha — testing guide

> For Alpha participants. This is what to do and what we need from you. The plan
> behind it is [alpha-program.md](alpha-program.md); you file evidence with
> [feedback-template.md](feedback-template.md).

## What we're asking

Use Spark on **a real project you care about** — not a toy — and let us watch
where it helps and where it fights you. We are testing the *product*, not you.
Every moment of confusion is a bug in Spark, not a failure on your part; the
confusions are the most valuable thing you can report.

**Do not** read the whole documentation set first. Start the way a real new user
would — from the README — and let us see what you can and can't discover on your
own. If you get stuck, log it *before* asking for help.

## Before you start

You need what the [supported-environment matrix](../../plugins/spark/docs/reference/compatibility.md)
lists: a Git repository, Claude Code, and an authenticated GitHub CLI (`gh`).

1. Install from the published path:
   ```
   /plugin marketplace add jwogrady/spark
   /plugin install spark
   ```
2. Run `spark doctor --requirements`. If it doesn't say *Ready*, log that as
   your first finding and note what you had to do.

That's the whole setup. Stop here if anything already felt unclear — that's a
finding.

## The core task: run one full lifecycle

Take one real unit of work and carry it end to end:

```
/spark:onboard        # arm the repo (or a new one)
/spark:ideate         # frame the problem
/spark:plan           # decompose into issues + a milestone
/spark:codify         # implement one issue
/spark:validate       # review and harden it
/spark:ship           # commit + open a PR
```

As you go, **think aloud** (in your notes, or on a recording if you agreed to
one). We especially want to hear:

- The moment you weren't sure *which command comes next* or *what a command
  does*.
- Any step that felt like busywork you'd skip if allowed.
- Any step that felt genuinely helpful or even magical.
- Anything that surprised you — good or bad.

Do this **at least twice**, ideally on two different projects. The second run
matters most: it tells us whether Spark is worth it once the novelty is gone.

## Things we specifically want you to try

- **Make a mistake on purpose** (or when you naturally do) and try to recover —
  wrong branch, a bad commit message, a push to the wrong place. Can Spark help
  you back out? Did a guard stop you, and was its message useful?
- **Ignore the docs** on the first run. Then, when stuck, note *which* doc you
  reached for and whether it answered you.
- **Try a companion** if it fits your work: `/spark-audit:audit`,
  `/spark-connect:connect`, or `/spark-docs:docit`. Did you know when to reach
  for it? Did you understand its boundary vs the core?
- **Use `spark brief` / `spark resume`** when returning after a break. Did they
  orient you, or add noise?

## What we do NOT want

- Don't fix Spark for us or read the source to figure out intended behavior — if
  you have to, that itself is the finding.
- Don't be polite at the expense of accuracy. "This step felt pointless" is more
  useful than "great job."
- Don't smooth over confusion in hindsight. Capture it in the moment, messy.

## After each lifecycle run

File one [feedback-template.md](feedback-template.md) entry per run (as a GitHub
issue labeled `alpha-feedback`, or wherever the program coordinator directs).
One entry per run, while it's fresh — not a weekly summary.

## At the end of your Alpha

We'll ask for 30 minutes to talk through the Value questions, above all: **would
you keep using Spark after this program ends, and why or why not?** An honest
"no, because…" is one of the most valuable outcomes this program can produce.
