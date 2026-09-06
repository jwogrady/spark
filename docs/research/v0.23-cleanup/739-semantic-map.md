# Duplicate runtime semantics — the semantic map (v0.23 cleanup)

**Scope.** The shipped runtime: `plugins/spark/bin/spark` and `plugins/spark/lib/*.sh`,
with the skill scripts and hooks read for evidence. CI (`.github/`) and repository
settings are *mapped* where they carry the same concept but are **not changed** here:
editing CI or applying repository policy is a human-approved act.

**Method.** Every row below was established by `grep`/`sed` over the frozen master
(`62488fe0a76b6eaebb66313850e2c588bd08d096`, the state after the dead-code removal),
not from names. Line numbers are on that revision. The leads came from the baseline's
duplicate audit (`../v0.23-optimization-baseline/raw/agent-duplicate-truth-code.md`);
each lead was confirmed or dismissed by reading the code.

## Map

| Invariant / fact | Implementations (before) | Consumers | Differences found | Canonical primitive / source | Action |
|---|---|---|---|---|---|
| **Native dependency graph** — which issues block an issue | `bin/spark:4535` (governance validate: `select(.state=="open")`, same-repo filter on `.repository.full_name`, **not paginated**); `bin/spark:8693` (next: count of open, **not paginated**, no repo filter); `lib/planning.sh:298` (plan verify: paginated, numbers only, any state); `skills/codify/scripts/check-prereqs.sh:229` (self-contained skill: `.repository_url`, not paginated) | governance validate (cycle detection), next (selection), plan verify (edge membership), codify preflight | Only one of three runtime readers paginated (an issue with more than one page of blockers gave three different answers); two filtered state in jq, one did not; the same-repo test used `repository.full_name` in one place and `repository_url` in another | **`gh_blocked_by <issue>`** (`bin/spark`): one paginated read emitting `number\tstate\towner/name` per blocker; fails non-zero and empty when unreadable | Consolidated (3 → 1 in the runtime). Each consumer keeps its own *stated* filter over the same rows: validate keeps open + same-repo edges (unknown repo or unknown own identity keeps the edge, so a cycle is never hidden); next counts open blockers in any repository; verify matches the declared blocker by number **and** repository in any state (a foreign same-numbered issue is `~`, an unknown repository or an unreadable own identity is `?`). The skill script stays self-contained (skills import nothing at runtime) — **justified exception**, recorded below |
| **Sub-issue list of a parent** | `lib/planning.sh:277` and `:328` (two verbatim REST loops in one function) | plan verify (hierarchy check, order check) | none — verbatim duplicates | **`plan_sub_issues <parent>`** (`lib/planning.sh`; module-owned, only plan verify reads it) | Consolidated (2 → 1) |
| **Repository identity (owner/name) for API calls** | `bin/spark:3407 di_repo_nwo`; `bin/spark:3144` (labels gate, `\|\| true` fallback); `bin/spark:5398` (milestone snapshot, `\|\| return 1`) — three verbatim `gh repo view --json nameWithOwner --jq .nameWithOwner` | docs-impact, governance validate, labels, next/course (milestone snapshot) | Same read; two different call-site fallbacks (empty vs fail) | **`di_repo_nwo`** — fails non-zero and empty when gh cannot answer; the caller decides whether that is fatal or "not assessed" (the primitive never guesses) | Consolidated (3 → 1; both call sites keep their existing fallback, now visible at the call site) |
| Repository identity — other senses | `lib/repository.sh:35 repo_locator_normalize` (git remote → `host/owner/name`, the mutation boundary); `bin/spark:6500` `hub_locator_valid` (memory-hub locator grammar); `hooks/guard-bash.sh:420` (`gh --repo` shorthand); `check-prereqs.sh:228` (`gh api repos/{owner}/{repo} --jq .full_name`) | mutation boundary, memory hub, bash guard, codify preflight | Three *different facts* (git remote identity, a hub locator, GitHub's owner/name); the skill script's read is the same fact as `di_repo_nwo` | `repo_locator_normalize` for git-remote identity; `di_repo_nwo` for GitHub owner/name | **No change.** Different facts are not forced through one function (non-goal). The skill script is the self-containment exception |
| Issue / work-unit identity and closing references | `bin/spark:1933 issue_refs` (the one `#N` syntax); `bin/spark:3662` (branch `^[a-z]+/<n>-`); `bin/spark:8311` (next: text heuristic `close/fix/resolve … #n`, emitted *as* `heuristic` beside the native `closedByPullRequestsReferences` read at `:3496`); `.github/scripts/openai-review/lib.sh:31 orl_closing_issues` (CI) | next, docs-impact, CI review lane | The runtime labels its text match a heuristic and ranks the native GraphQL relationship above it; the CI regex differs (` #` vs `[: ]*#`) | Native `closedByPullRequestsReferences` (GraphQL) is the runtime's source of truth; text is secondary and labelled | **No runtime change.** CI regex drift is a CI-surface finding — needs approval to touch; recorded |
| SHA canonicalization | `lib/execution.sh:196 tm_binding_status` (string compare of recorded vs live head); no 40-hex validation in the runtime; `.github/scripts/claude-lane/lib.sh:39` validates (CI) | telemetry binding, CI lane | Not duplicated in the runtime — absent | The fact model's `commit` identifier (`preferences/fact-model.tsv`, in review) is the canonical grammar | **No change**; a gap for the freshness contract, not a duplicate |
| Reviewer / acceptance marker identity and parsing | none in the runtime (`spark-openai-review` appears only under `.github/`) | CI review lane, gate | n/a | CI lane (`orl_marker`, `orl_has_final_marker`) | **Not a runtime duplicate.** CI-only; out of scope here |
| GitHub comment transport / escaping | none in the runtime (the runtime posts no comments) | CI lanes | n/a | — | Nothing to consolidate |
| Pagination / exhaustion semantics | REST `--paginate` (`gov_collect` issues `:4472`, plan verify, now the two primitives); GraphQL bounded `first:N` + `hasNextPage → unread` (`milestone_snapshot :5396`, `gov_gate_capture :4126`); manual cursor loop with fail-closed cursor handling (`di_linked_prs :3506`) | governance, next/course, plan verify, docs-impact | Three transports; every one honours the same invariant — a truncated read is `unread`/`?`, never "empty". The two REST readers that did **not** paginate were the dependency readers above | The invariant is shared; the transports differ by API shape | **Consolidated where it was a defect** (0 non-paginated REST list readers remain). Transports are not forced into one function (non-goal) |
| Actor permission / authority classification | none in the runtime (no collaborator-permission call anywhere in shipped code; authority is the governance model + human decisions) | — | n/a | — | Nothing to consolidate (matches audit row 6b) |
| Stale-HEAD / source invalidation | `lib/execution.sh:196` (telemetry: recorded vs live head); `check-prereqs.sh` (base proof: HEAD exactly at fresh `origin/<trunk>`); CI claude-lane | telemetry, codify preflight, CI | Different facts (a run's binding, a branch's base freshness) | — (the freshness contract owns the fact-level rule) | **No change** |
| Verdict / state vocabularies | `lib/execution.sh:51 TELEMETRY_VERDICTS` = `PASS\|CHANGES REQUIRED\|DECISION REQUIRED\|NOT ASSESSED\|FAIL`; course verdicts `:5964` (`COHERENT\|DECISION REQUIRED\|NOT ASSESSED`); governance validate `:6102` (`PASS\|DECISION REQUIRED\|NOT ASSESSED`); the fact model's `verdict` identifier (`PASS\|CHANGES REQUIRED\|DECISION REQUIRED\|NOT ASSESSED`, in review) | telemetry, course, governance, compiled facts | `FAIL` exists only in telemetry; `COHERENT` only in course | Each surface's answer set is its own product contract | **No change** (product semantics). For the compiled facts: each surface's vocabulary must be mapped explicitly to the fact model's, never by precedence guess — see the integration rule below |
| Parent / child hierarchy | GraphQL `subIssues`/`parent` in `milestone_snapshot :5396` and `gov_gate_capture :4126` (bounded `first:50`, `unread` on `hasNextPage`); REST `sub_issues` in plan verify (paginated) | next/course (a milestone's whole snapshot), governance gate rows, plan verify (one parent) | Two API shapes for one graph, in different verbs; the REST side had two copies | `plan_sub_issues` for one parent's list; the GraphQL snapshot for a milestone's whole hierarchy | REST copies consolidated. GraphQL vs REST **kept**: a milestone snapshot and one parent's list are different queries; forcing one transport is a non-goal. Flagged for the compiled `graph` fact (below) |
| Trunk resolution | `bin/spark:2039 repo_trunk` (local: `origin/HEAD`, then local `master`/`main`; network-free by design, see its comment); `:3297 di_trunk` (remote diff base: `origin/HEAD`, then `origin/master`/`origin/main`); `:810` doctor `default_branch` via the API (the server-side fact a ruleset is judged against); `:2108` brief's `master`/`main` literal; `hooks/guard-bash.sh:149`, `scripts/hooks/pre-commit:11` (hook literals) | triage, course, docs-impact, doctor, brief, hooks | Three facts (local trunk, remote diff base, server default branch) with one shared first step; brief and the hooks restate the naming convention | `repo_trunk` (local), `di_trunk` (remote base), the API for the server fact | **No change, justified.** Unifying the fallbacks would change what an offline triage or an unborn repository reads (brief's Ideate read depends on it) — product semantics without an owning contract. Brief's literal is the one candidate worth a follow-up **with** a brief-stage contract; recorded as a finding, not changed |
| Release / milestone / gate placement | the gate role is resolved once (`release_gate_label`) and passed in; readers are the two GraphQL snapshots above; CI `milestone-gate.sh:87` maps version → milestone (CI) | governance gate rows, next/course, CI | none in the runtime beyond the snapshot readers | `release_gate_label` + `gov_gate_capture` | **No change** |
| Ruleset / check / workflow requirement normalization | doctor reads the default branch's rules against `settings/github-ruleset-trunk.json` (`validate` context); the live ruleset and the workflows require `doctor` and `tests`; CI scripts carry their own name sets (audit row 13: four disagreeing copies) | doctor, CI, repository settings | the shipped template names `validate`; the live policy names `doctor`, `tests` | the live ruleset is the authority; the template is a starting point | **No change here** — CI and repository settings are human-owned surfaces. Recorded as an open drift for the release gate's final validation |

## What changed, exactly

| | Before | After |
|---|---|---|
| Readers of `…/dependencies/blocked_by` in the runtime | 3 (`bin/spark:4535`, `bin/spark:8693`, `planning.sh:298`) | 1 (`gh_blocked_by`) |
| Readers of `…/sub_issues` in the runtime | 2 (`planning.sh:277`, `:328`) | 1 (`plan_sub_issues`) |
| `gh repo view --json nameWithOwner` reads in the runtime | 3 | 1 (`di_repo_nwo`) |
| Non-paginated readers of paginated REST lists | 2 | 0 |
| Call sites changed (fanout) | — | 7: `bin/spark` ×4 (labels gate, milestone snapshot, governance validate, next), `planning.sh` ×3 |
| Functions | `bin/spark` 147, `planning.sh` 15 | 148, 16 |
| Lines | `bin/spark` 8,865, `planning.sh` 801 | 8,886, 808 (comments state each contract) |

**Defect found and fixed while consolidating.** `gov_collect`'s probe loop read the issue
stream with `IFS=$'\t' read -r kind n ms blk_n`. Tab is IFS *whitespace*, so an
unmilestoned issue's empty milestone field collapsed and its blocked-by count landed in
`ms`; `blk_n` was empty and the issue was **never probed** — a dependency cycle through
an unmilestoned issue was invisible to `governance validate`. Reproduction:

```
$ printf 'issue\t1\t\t1\n' | while IFS=$'\t' read -r k n ms b; do echo "n=$n ms='$ms' blk_n='$b'"; done
n=1 ms='1' blk_n=''
```

The loop now projects the issues to probe with `awk` (field-exact) before iterating.
`tests/test-canonical-primitives.sh` drives the fixture with an empty milestone on purpose.

## Contract of each primitive (fallback and default behaviour)

- `gh_blocked_by <issue>` — paginated and **buffered** (rows are emitted only after every
  page was read, so a failure on a later page never leaves a partial list on stdout); one
  row per blocker `number\tstate\towner/name`, **validated before anything is emitted**: the
  number is a positive integer and the state is `open` or `closed`, or the whole read fails,
  so a consumer keeping only open blockers can never read a malformed row as "not
  blocking"; the repository may be empty (GitHub omitted it) and consumers treat that as
  unknown, never local; **non-zero exit and no rows** when the graph could not be read. No consumer may read a failed probe as "no
  prerequisite": validate emits `dependency ? all … probe failed`, next records `?`,
  verify emits `dependency ? #n … could not be read`.
- `plan_sub_issues <parent>` — paginated and buffered; positive issue numbers in GitHub's
  own order, or the whole read fails; non-zero exit and no rows when unreadable (verify
  reports `?`, never "not wired").
- `di_repo_nwo` — the owner/name exactly as GitHub spells it, buffered and validated:
  output beside a failure, an empty success, or anything that is not `owner/name` is a
  failed read; non-zero exit and empty output when gh cannot answer. Callers state their own fallback at the call site
  (`|| repo_nwo=""` where "unknown" is survivable, `|| return 1` where it is not).

## Removed implementations → surviving tests

| Removed | Behaviour / invariant | Proven by |
|---|---|---|
| `bin/spark:4535` inline blocked-by read (validate) | open + same-repo edges; foreign numbers never fuse; failed probe → `?`; unknown own identity keeps the edge | `tests/test-canonical-primitives.sh` (six stubbed scenarios over `gov_collect`); `tests/test-governance-engine.sh` (cycle detection over edges) |
| `bin/spark:8693` inline open-count (next) | count of open blockers, any repository; unreadable or malformed → `?` | `tests/test-canonical-primitives.sh` (projection, malformed rows); `tests/test-next-governance-gate.sh` (selection with the endpoint stubbed); `tests/test-course-derivation.sh`, `tests/test-member-identity.sh` and `tests/test-release-gate-role.sh` — whose stubs had answered the endpoint with a pre-shaped count `0` that assumed the old consumer's jq, wrong-layer mocks the validated reader exposed; they now answer with no rows |
| `planning.sh:298` inline blocked-by read (verify) | the declared blocker by number and repository; foreign same-numbered issue → `~`; unknown repository or unreadable identity → `?`; unreadable graph → `?` | `tests/test-plan-verify-coverage.sh` (`unread:blockedby`, `no-dependency`, `foreign-number`, `unknown-repo`, `unread:identity`, wired) |
| `planning.sh:277`, `:328` inline sub-issue reads | hierarchy and relative order; unreadable → `?` | `tests/test-plan-verify-coverage.sh` (`unread:subissues`, `no-hierarchy`, `bad-order`, the unmentioned `999` child) |
| `bin/spark:3144`, `:5398` inline identity reads | labels gate counts via `search/issues` only with an identity; milestone snapshot fails without one | `tests/test-labels*.sh`, `tests/test-course*.sh`, `tests/test-next*.sh` (green after the change) |

## Integration rule for the compiled facts (#728 side)

Two concepts the stable compiled facts will expose still have **more than one live
source** in the runtime, by design, and must not be reconciled by precedence guesses:

1. **Hierarchy (`graph` parent/children).** GraphQL milestone snapshot (bounded, `unread`
   on overflow) and REST per-parent list (paginated). Recommendation: the compiled fact
   for *one work unit* reads the REST per-issue list (`plan_sub_issues` and the parent
   from the issue itself), and the milestone-level snapshot stays a course/next
   concern. The freshness contract should say so explicitly.
2. **Verdict vocabularies.** Telemetry (`FAIL`), course (`COHERENT`) and governance
   answer sets each differ from the fact model's closed `verdict` vocabulary; a
   compiled `review` fact maps *only* the reviewer lane's verdicts and never widens.

Dependency state now has one runtime source (`gh_blocked_by`) and needs no
reconciliation rule.

## Findings recorded, not changed (need their own authority)

- CI closing-reference regex (`orl_closing_issues`) differs from the runtime heuristic
  and from GitHub's own closing-keyword grammar — CI surface.
- Four required-check name sets across workflows, the shipped ruleset template and the
  live ruleset — CI and repository-settings surfaces.
- Brief's `master`/`main` literal restates the trunk convention `repo_trunk` already
  encodes; unifying changes the Ideate read for unborn and origin-less repositories —
  needs a brief-stage contract.
- The codify preflight (`check-prereqs.sh`) is a self-contained skill script and
  therefore carries its own dependency and identity reads; it is the one place the
  same-repo test uses `repository_url` rather than `repository.full_name`. Both are
  canonical owner/name after normalization; recorded so the skill can adopt the
  primitive's row shape if skills ever gain a runtime import path.
