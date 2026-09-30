# #744 — obsolete scripts, config, dependencies and stale branches

Historical record. Evidence-first disposition of the repository's non-runtime support surfaces and its
branches, observed from `master` `cc9a672` and from GitHub on 2026-09-30 UTC. Nothing here is current
authority: the census is regenerable by the committed tool, and a later run supersedes these counts.

## Method

Every candidate carries evidence, confidence, risk and validation (the #729 contract). A candidate is
removed only when the evidence is mechanical — a reference search that finds no consumer, or the branch
rule below — and never because it is old, unfamiliar or large.

**Branch rule.** `tools/branch-census.sh` reads the remote's own heads (`git ls-remote`), every pull request
on every page (`gh api pulls?state=all`), and the pull refs GitHub still serves (`refs/pull/*/head`). A
remote branch is a **safe stale ref** only when all four hold, each from its own source:

1. its current SHA equals the head SHA of a **merged** pull request whose head ref is that branch;
2. it is not the default branch and not a release-please branch;
3. it is not the head of an open pull request;
4. it is recreatable from durable history — the SHA is an ancestor of `origin/master`, or GitHub still serves
   it as `refs/pull/<n>/head` (a squash landing keeps the head only there).

Anything else is kept or listed for review. The tool fails closed: a short read, a git failure or an API
error aborts the run rather than reporting a partial census as complete; with `--delete` each safe ref is
deleted through the API one at a time and the outcome is recorded per row.

## Branches

Census: `744-branch-census.tsv` (one row per remote head, with the evidence columns the rule reads).

| Disposition | Count | Action | Evidence |
|---|---:|---|---|
| safe stale ref | 161 | delete | merged PR head SHA = branch SHA; 135 also ancestors of `master`, all 161 served as `refs/pull/<n>/head` |
| active PR head | 2 | keep | open #806 (`chore/refresh-recorded-course`), open #798 (`feat/733-next-action-governed-v2`) |
| protected | 2 | keep | `master` (default), `release-please--branches--master` (release PR #618) |
| review — closed, unmerged PR | 14 | review | the branch's PR was closed without merging; not "merged/stale", so outside the approval |
| review — no PR | 6 | review | never had a pull request; nothing establishes what it holds |
| review — SHA moved after merge | 2 | review | `fix/628-existing-impl`, `refactor/614-plan-module`: commits after the merged head |
| **total remote heads** | **187** | | `git ls-remote --heads origin`, 2026-09-30T02:25:16Z; 423 pull requests read |

The 22 review rows are listed by name in the census. `add-claude-github-actions-1787957880410` (no PR,
2026-08-28) is the GitHub-generated branch of an abandoned app install; `worktree-feat-474-ownership-contract`
and `docs/north-star` predate the current lifecycle. None is deleted here: the owner's approval on #744
(2026-09-25) authorizes deletion only where the evidence establishes merged/stale, and these are not
established.

**Execution.** Deletion of the 161 safe refs is the recorded next step:
`bash docs/research/v0.23-cleanup/tools/branch-census.sh --delete > docs/research/v0.23-cleanup/744-branch-census.tsv`.
In the session that produced this record the deletion call was refused by the tool-permission layer, so the
committed census is the classify-only run (`deleted 0`) and every safe row carries `action=delete,
result=-`. The run that executes it replaces the census file with rows carrying `result=deleted`; the
after-count is then 187 − 161 = 26 remote heads, less whatever has merged since.

**Local branches.** Seven local branches before; the five whose pull requests had merged (#799, #802, #803,
#804, #808) and `chore/refresh-recorded-course` (#806) were removed with `git branch -d`, which refuses an
unmerged branch. After: `master` and the branch carrying this record.

## Scripts

Every script under `.github/scripts/` is referenced by a workflow, a test suite or both. Reference counts
are `git grep -l` over the tree excluding the file itself.

| Script | References | Consumer | Disposition |
|---|---:|---|---|
| `alpha-intake-check.sh` | 4 | `tests/test-alpha-intake.sh` | keep |
| `docs-truth.sh` | 13 | `docs-truth.yml`, tests | keep |
| `gate-runner.sh` | 6 | `milestone-gate.yml` | keep |
| `ledger-truth-check.sh` | 8 | `validate.yml` path, tests (#768 current input) | keep |
| `milestone-gate.sh` | 12 | `milestone-gate.yml`, tests | keep |
| `release-notes-check.sh` / `release-notes-runner.sh` | 12 / 17 | `milestone-gate.yml` advisory step (#787), tests | keep |
| `claude-lane/{lib,publish,resolve}.sh` | 123 / 5 / 5 | `claude.yml`, `tests/test-claude-lane.sh` | keep |
| `openai-review/lib.sh`, `reviewer-instructions.txt` | 123 / 4 | `openai-review.yml`, tests | keep |
| `plugins/spark/scripts/hooks/*` | — | shipped git hooks, installed by `spark install-git-hooks` | keep (runtime) |
| `docs/research/*/tools/*` | — | regenerate committed evidence; indexed in `docs/ops/evidence-index.tsv` | keep (evidence tooling) |

No script is unreferenced. Confidence: High (reference search plus the workflows that name them).

## Configuration

| Surface | Evidence | Disposition |
|---|---|---|
| `.vscode/{settings,extensions}.json` | tracked deliberately — `.gitignore` un-ignores it "as a template for downstream projects"; 4 references | keep |
| `.github/release-notes-carriers.tsv` | read by `release-notes-runner.sh` (2 references) | keep |
| `.github/spark-trunk-ruleset.json` | the trunk ruleset policy; 7 references, applied by `spark governance` | keep |
| `release-please-config.json`, `.release-please-manifest.json` | consumed by `release-please.yml` | keep |
| `.github/ISSUE_TEMPLATE/*`, `PULL_REQUEST_TEMPLATE.md` | used by the plan skill and GitHub | keep |
| `.spark/{state,preferences}.json` | committed work state and preference overrides; readers listed in the evidence index | keep |

No duplicate or stale configuration was established. Confidence: High.

## Dependencies

There is no dependency manifest at the root or under `plugins/` (`package.json`, `go.mod`,
`requirements.txt`, `pyproject.toml`, `Cargo.toml`, `Gemfile`: none exist). The runtime is Bash with
zero dependencies by contract; `jq`/`python3` degrade gracefully when absent. No dependency removal is
proposed because there is none to remove. Confidence: High.

## Generated, vendor and build artifacts

Nothing generated is tracked: `git ls-files` finds no `__pycache__`, `*.pyc`, `node_modules` or `dist`
entry; `.gitignore` covers Python caches, and the only such directory on disk
(`docs/research/v0.23-cleanup/tools/__pycache__/`) is ignored. The tracked `evaluations/**/build/`
paths are the *build* stage of the orchestration evaluation fixtures, not build output. Confidence: High.

## Comments, TODOs and figures

`TODO|FIXME|XXX` over `plugins/`, `tests/` and `.github/` finds only the `mktemp XXXXXX` templates and the
`TODO(decision)` markers the standards templates emit by design (a human decision Spark cannot make).
No comment describing behaviour that is no longer true was found in this audit's scope. Confidence: Medium —
a text search, not a semantic review; #745's before/after report is where figures are re-checked.

## Before / after

| Dimension | Before | After this record | After deletion executes |
|---|---:|---:|---:|
| remote heads | 187 | 187 | 26 |
| local branches (this clone) | 7 | 2 | 2 |
| scripts removed | — | 0 | 0 |
| configuration removed | — | 0 | 0 |
| dependencies removed | — | 0 (none exist) | 0 |
| generated artifacts removed | — | 0 (none tracked) | 0 |

## Acceptance, evaluated

- every candidate has evidence, confidence, risk and validation — the tables above and the census columns;
- generated/vendor/build artifacts identified before cleanup — none tracked;
- protected/default/release/active-PR branches never auto-deleted — excluded by the rule, rows 2–3;
- remote-branch and risky deletion stops for human approval — the owner's bounded approval is recorded on
  #744; the execution itself waits on the tool permission noted above;
- build/CI/release tooling remains functional — nothing under `.github/` is changed by this record;
  `spark doctor` and the full suite pass on the recording commit;
- before/after file, dependency and branch disposition recorded — the table above and the census.
