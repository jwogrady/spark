# Shape fixture — framing/planning task

**Group:** Shape (Ideate → Plan)
**What a candidate is given:** the vague request below, plus read access to the
Spark repository.
**What a candidate must produce:** a written problem statement with success
criteria and constraints, a short survey of existing assets/prior art, and a
decomposition into scoped GitHub-ready issues assigned to a milestone — the
normal output of `ideate` followed by `plan`.

---

## The request (verbatim, as an operator would phrase it)

> After I run `spark setup` on a repo, I honestly can't tell what it changed or
> what state my project is in. Sometimes I re-run things because I forget where I
> left off. Can we make it obvious what Spark did and where I am in the
> lifecycle? Something so I'm not guessing.

That is the entire input. It is deliberately underspecified: it names a felt
pain ("I'm guessing") but not a solution, a scope, or acceptance criteria.
The Shape work is to turn it into something buildable without inventing scope
the request does not support.

---

## Notes for the candidate

- The request conflates two things (what setup *changed* vs. where I *am* in the
  lifecycle). A good framing separates them.
- Spark already ships surfaces near this problem. Grounding the framing in what
  exists — rather than proposing a greenfield feature — is part of the job.
- Do not write code. The deliverable is a problem statement plus scoped issues,
  not an implementation.
