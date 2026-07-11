# Problem statement — one command to arm a repo

> Authoritative — the problem this effort solves. Owner: `jwogrady`.

## Problem

Carrying the operator's standard into a repo takes three separately-discovered
commands — `spark install-git-hooks`, `spark apply-permissions`,
`spark preferences --apply` — documented across the install guide, the
preferences on-ramp, and the bootstrap flow. Nothing runs them together, so a
repo is easy to leave half-armed: hooks installed but no permission baseline,
or the standard applied but the human-driven enforcement door still open. The
operator must remember the full sequence in every new or existing repo, which
is exactly the re-loading cost Spark exists to remove.

## Outcome

One idempotent command arms a repo completely: run it in any git repository
and the git hooks, the permission baseline, and the resolved engineering
standard are all in place, with one consolidated report of what was created,
kept, and left for a human decision. Running it twice changes nothing.

## Success criteria

1. `spark setup` in a fresh repo installs both git hooks, applies the
   permission baseline, and materializes the resolved standard in one run.
2. A second `spark setup` run reports everything as already present and
   writes nothing (idempotent, create-only throughout).
3. `spark setup --yes` completes without prompting; without the flag, the
   existing permission-merge confirmation is preserved.
4. The three individual commands still work unchanged, and `spark help`
   lists the new verb.
5. `spark doctor` passes, and the install/preferences/bootstrap docs present
   the single command as the primary path.

## Prior art & reusable assets

- All three verbs exist in `bin/spark` and are already idempotent:
  `cmd_install_git_hooks` (skips non-Spark hooks), `cmd_apply_permissions`
  (append-only merge, `--yes`), and `apply_standard` (create-only engine).
  `setup` composes them; it reimplements nothing.
- `ROADMAP.md` v0.6 already names a `spark setup` flow — this is that item's
  mechanical half, brought forward.
- The verb table in `bin/spark` drives both dispatch and help, so the new
  verb self-documents.

## Constraints

- POSIX-friendly Bash, zero runtime dependencies, graceful degradation
  without `jq`/`python3` — the same rules as every shipped script.
- Composition only: the individual verbs remain the single implementation of
  each step; `setup` must not fork their logic.
- For a valid invocation, exit non-zero only when there is no git repo to
  arm; advisory items are decisions, not failures. Invalid arguments are
  usage errors and also exit non-zero.

## Non-goals

- No changes to what the hooks, baseline, or standard contain.
- No removal or deprecation of the three individual commands.
- No stack-aware baseline curation (the rest of ROADMAP v0.6) and no
  interactive wizard.
- No release; the change lands as one pull request and stops there.
