# Read-only assessment and mutation-capable validation

Development-only prose. Not shipped with the plugin.

## The hazard

Dogfooding released v0.22 against a downstream repository found a `validate`
script that was not observational:

```text
bun run validate
  -> build
  -> scripts/build-lastmod.mjs
  -> writes tracked src/data/lastmod.json
```

A read-only assessment that ran it would have **mutated the repository it was
only supposed to describe**. The operator noticed and declined; that is the part
worth fixing. Safety that depends on someone recognising the hazard in the
moment is not a contract.

## The rule

> A project script is untrusted with respect to mutation until observed
> otherwise, and the observation happens somewhere disposable.

Crucially, it is **not** distrusted by name. `test`, `build`, `lint`, `check`
and `validate` carry no information about side effects. A name allowlist would
be the original mistake written down — the downstream script was called
`validate` and wrote a tracked file.

## How it works

```text
snapshot source -> isolate at HEAD -> run there -> re-snapshot -> compare
```

The command runs in a detached, disposable git worktree. Its exit status is real
evidence; its side effects are confined to a directory that is about to be
deleted. Afterwards the source fingerprint must be **byte-for-byte identical**.

The snapshot deliberately covers more than tracked content — `HEAD`, every ref,
and `status --porcelain --untracked-files=all`. A build that leaves only
untracked artefacts has still changed what the next reader observes, so absence
of a tracked diff is not the whole test.

## Three outcomes

| Verdict | Exit | Meaning |
|---|---|---|
| `PASS` | 0 | The command succeeded and the source is unchanged. The report says whether it was mutation-capable |
| `FAIL` | 1 | The command genuinely failed. Ordinary evidence |
| `NOT ASSESSED` | 3 | Isolation could not be established, or the source changed anyway |

The third is what makes it honest. When a disposable worktree cannot be created,
the answer is NOT ASSESSED **with the risk named** — never a quiet in-place run
because isolation was inconvenient. An unverifiable command is not a passing one.

Equally, a genuine failure stays a failure. The rule exists to prevent mutation,
never to soften a real red result, and the report says so in the verdict text so
nobody mistakes a failing build for a safety refusal.

## What this does not cover

Isolation preserves the repository, not the environment. A command needing
installed dependencies may fail in a fresh worktree for reasons unrelated to the
code. That failure is reported as a failure — which is honest but blunt, and an
operator reading a red result should check whether the isolated run simply
lacked what it needed before treating it as a defect in the repository.

Cross-repository mutation authority is a separate concern and is owned
elsewhere; this covers side effects inside the correctly bound repository.
