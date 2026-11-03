# Archiving Spark

> Status: **archived, 2026-11-03.** The repository is read-only. `v0.22.0` is
> the final release. Open issues, pull requests and milestones were closed as
> not planned. Nothing was deleted from `master`.

Today I archived Spark. I built it. Here's why I stopped.

Spark was a Claude Code plugin with a big promise: take one developer, a
Claude subscription and a GitHub subscription, and turn them into a software
delivery system. Your engineering standards would load into every project
automatically. Every piece of work would follow the same five steps, *ideate →
plan → codify → validate → ship*. Plans would become GitHub issues, and issues
would become branches and pull requests. Hooks (small scripts that run before
the AI is allowed to act) would make sure nothing pushed straight to the main
branch.

I started it on 28 May. Here's what was in the repository when I stopped:

```
1,195 commits
   34 architecture decision records
  100 behavioural test suites
~48,000 lines of shell
~28,000 lines of markdown
  826 issues and pull requests
   75 of them still open
```

That's a lot of work, and I'd like to tell you every bit of it was necessary.

## What I believed

For five months I believed one thing. The AI writes the code, GitHub stores it,
and *nobody* supplies the engineering discipline in between. That gap was the
product.

It was true in May.

Then the gap started to close, and it wasn't me closing it. Claude Code and
Codex kept shipping, release after release, the things Spark had been bolting
on: skills and plugins, hooks, subagents, built-in review commands, project
memory, project instruction files. Each release made one
more piece of Spark redundant, and I could have made a cheap habit of noticing.
I noticed, and then I did something else.

## The wrong theory

My reasoning was that Spark wasn't failing because it was redundant. It was
failing because it wasn't rigorous enough yet. If the governance were tighter,
if the provenance were cleaner, if the reviews were more independent, the value
would become obvious.

Reasonable, and completely wrong.

The record shows it. The milestone I was working on when I stopped was called
**v0.23: Never automate inefficiency.** Its whole job was to cut the cost
that Spark *itself* added to every change. Before optimising, I measured that
cost. One pull request, 2,314 changed lines, went through **35 review
attempts**. Another fetched the same pull-request conversation **51 times** to
collect 32 verdicts. The system I'd built to make delivery efficient had become
the main source of inefficiency, and the plan for fixing that was more system.

The next milestone was called *Trustworthy autonomous execution*. It held 43
open issues, and most of them were Spark guarding against Spark.

## The test it never passed

This is the part that's hard to write.

Spark had an Alpha program. I wrote it myself, and it set out the only
question that mattered before a 1.0: *is this the right product?* It also said
how that would be answered: with evidence from people who aren't the author.
At least five distinct users, real projects, finished without me helping.

Here's how many `alpha-feedback` issues were ever filed:

```
$ gh issue list --state all --label alpha-feedback --json number --jq length
0
```

Every claim Spark made about saving time rested on one user, and that user
was the person most motivated to believe it.

Sample size: one.

I could prove it worked mechanically. A hundred test suites passed and the
hooks held. I could never prove it worked in the sense that matters, meaning
somebody else shipped more because it existed. A tool built on "claims follow
evidence" couldn't produce the evidence for its own core claim.

Sample size: one.

## What I'm keeping

I'll be straight about the part that costs something. Five months is a long
time, and most of the urge to keep going was ego. Archiving reads as admitting
the time was wasted, and nobody wants to put that in a public repository with
their name on it.

I don't think the time was wasted, though, and I'm still working out how to put
that. The habits are the part that lasts. I write the problem down before the
code. Every change gets its own issue. I measure before I optimise, and I keep
separate the things I've checked from the things I only hope are true. None of
that needed 48,000 lines of shell. It needed me to keep doing it. Most of what
Spark enforced, the host tools now give you for free, and the rest is
discipline you can't install.

Here's the reflex I'm taking away, and it applies well outside software. Keep
checking whether the job you built something for still exists. A project can
outlive its use case and keep growing anyway, because there's always one more
feature that will finally make it obvious. The way to catch that is to ask
the question the project was built to answer, and accept the answer.

Mine was zero.

Archiving doesn't delete anything. The code, the decisions and the history are
all still there, read-only, at
[github.com/jwogrady/spark](https://github.com/jwogrady/spark). v0.22.0 is the
last release, and every open issue was closed with a note saying why.

What it does give back is the next five months.
