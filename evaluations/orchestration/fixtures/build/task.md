# Build fixture — scoped implementation task

**Group:** Build (Codify)
**What a candidate is given:** the scoped issue below, plus read/write access to
a checkout of the Spark repository on a feature branch.
**What a candidate must produce:** a focused implementation on a feature branch
that satisfies every acceptance criterion, with local verification evidence
(`bash -n`, a targeted manual run) — the normal output of `codify`.

---

## Issue: add `spark doctor --quiet`

### Context

`spark doctor` prints a per-check report followed by a final summary line
(`Healthy — N errors, M warnings` or similar). In CI and in scripts, the
per-check output is noise; callers want only the verdict and the exit code.

### Requested change

Add a `--quiet` flag to the `doctor` subcommand of `plugins/spark/bin/spark`
that suppresses the per-check lines and prints only the final summary line.
The exit code must be unchanged from a normal `doctor` run.

### Acceptance criteria

- [ ] `spark doctor --quiet` prints only the final summary line, nothing else on stdout.
- [ ] The exit code of `spark doctor --quiet` is identical to `spark doctor` for the same repository state (0 when healthy, non-zero on errors).
- [ ] `--quiet` composes with the existing option surface (it does not break `spark doctor --requirements` or `spark doctor -h`).
- [ ] An unknown flag still errors with the usage line (the flag parser is not loosened into accepting anything).
- [ ] The implementation stays zero-dependency POSIX-friendly bash with `set -euo pipefail`, consistent with the rest of `bin/spark`.
- [ ] `bash -n plugins/spark/bin/spark` is clean and a manual `spark doctor --quiet; echo $?` in this repo shows one summary line plus the exit code.

### Explicitly out of scope

- Changing what the checks do or their pass/fail thresholds.
- Adding a JSON output mode (that is a separate issue).
- Touching any companion plugin.
