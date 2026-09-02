# Reference — the `spark` CLI

> Reference — information-oriented.

`bin/spark` is added to `$PATH` while the Spark plugin is active. It resolves its
own location (following symlinks), so subcommands work from any directory.

## `spark doctor`

Validates the whole marketplace and reports health. Checks:

- `.claude-plugin/plugin.json` and `marketplace.json` are valid JSON
- `hooks/hooks.json` is valid JSON and `guard-bash.sh` is executable
- the **tier boundary** holds: no development-only material (ADRs, release
  records, governance, research) under `plugins/`, which would ship this
  repository's internal history to anyone who installs the plugin. It also
  warns when a shipped surface cites this repo's issue numbers (`#NNN`), which
  a downstream reader cannot resolve; ADR references are deliberately not
  flagged, since they read as shared vocabulary and the shipped glossary says
  where ADRs live
- `preferences/defaults.json` is valid JSON and the templates carry the full
  standard set
- every directory under `skills/` has a `SKILL.md` with `name:` and
  `description:` frontmatter, and every agent file carries frontmatter too
- taxonomy parity: every shipped skill appears in the canonical
  [skills.md](skills.md) tables
- every companion plugin listed in the marketplace catalog passes the same
  manifest and skill checks as the core
- shell syntax: `bash -n` over `bin/spark`, the guard, and both git hooks
- doc links: every relative Markdown link in the shipped docs resolves
- enforcement lockstep: the enumerable vocabularies agree list-vs-list — the
  commit types across the `commit-msg` hook, `AGENTS.md`, and `hooks.md`; the
  changelog sections against the committed vocabulary and the release-notes
  checker; the release components against Release Please's packages. (The
  hooks' *behavior* is pinned by the behavioral suites, not by doctor.)
- standards boundary: in a project with the generated `CONVENTIONS.md` /
  `ENGINEERING-STANDARDS.md`, every `<!-- spark:pref key=value -->` marker names
  a real preference key and asserts the value it resolves to (drift and dangling
  references are errors); the docs are optional, so their absence is reported,
  not failed
- whether Spark's git hooks are installed in the current repo

Exit code is non-zero if any error is found. JSON validation uses `jq` or
`python3` if present, and is skipped (not failed) if neither is available.

### Governance readiness

Doctor consumes the **same row generators** as `spark governance` rather than
restating their rules, and distinguishes every state that matters:

| State | Meaning |
| --- | --- |
| model valid | the resolved governance model parses and is closed |
| model unresolvable | an **error** — every check below it is unassessable |
| surfaces present | every declared governance file exists |
| surfaces need a decision | a human-owned surface is missing; Spark will not write it |
| remote NOT ASSESSED | no authenticated `gh` — **explicitly not a pass** |
| remote MISSING | declared labels do not exist; `spark governance apply --yes` |
| remote DRIFTED | labels differ from the model; reported only, since an existing label is the project's decision |

**What doctor deliberately does not assess, and says so.** Issue metadata, the
prerequisite graph, and the trunk policy cost an API call per issue, and doctor
runs on a latency budget and must work offline. It names
`spark governance validate` as the verb that owns them. That is a *stated
deferral*, not a silent skip — a green doctor never means a remote surface was
quietly passed over.

The issue-form parity check reads the resolved model's category family, so it
and the governance commands cannot disagree about which categories exist.

### `spark doctor --requirements [--json]`

Environment readiness, grouped by the capability each dependency serves —
the structural checks above prove the plugin is intact; this answers whether
the *environment* can perform each Spark capability:

| Group | Dependencies | When it matters |
| --- | --- | --- |
| Core local workflow | `bash`, `git` | Everything — required |
| GitHub delivery | `gh`, authenticated | `plan`/`ship`/`validate` create issues and PRs |
| JSON tooling | `jq` or `python3` | Merging the permission baseline into an existing `.claude/settings.json`; everything else degrades gracefully |
| Release pipeline | repo wiring | `release-please-config.json` + workflow present when the resolved `release.mechanism` is `release-please`; other mechanisms are the operator's own |
| Remote enforcement | `gh`, authenticated | The third door: the default branch's effective rules — including the specific required-check contexts — compared against the repo's trunk policy file (`.github/spark-trunk-ruleset.json` when present, else the shipped `settings/github-ruleset-trunk.json`) — inspect-and-report only, drift degrades the summary, applying is always an explicit human act; unreachable/unreadable evidence reports "not assessed", never healthy |

Each missing or unauthenticated dependency prints one remediation line
(`gh auth login`, `spark preferences --apply`, …). The exit code is non-zero
only when a *core* tool is missing: optional integrations never fail the run,
so a conservative local-only environment stays healthy. `--json` emits the
same facts as one machine-readable object (built without any JSON parser)
for CI gates and troubleshooting. The human-readable contract behind this
check is the [supported-environment matrix](compatibility.md).

## `spark list-skills`

Lists every available skill with its one-line description, read from each
`skills/<name>/SKILL.md` frontmatter — a quick inventory of what the plugin
provides.

## `spark new-skill <name>`

Scaffolds `skills/<name>/SKILL.md` with a frontmatter stub. Refuses to overwrite
an existing skill. The name must be a plain slug — lowercase letters, digits,
and hyphens, not leading with a hyphen; anything else (path separators, `..`,
whitespace) is rejected with no filesystem change, since the name becomes a
path segment under `skills/`.

## `spark orient [--set new|existing]`

The orientation preflight (ADR-0022): Spark's first onboarding decision, before
it may scaffold, run `setup`, or generate conventions. Bare, it runs an
**inspect-only** classifier over the repo (the git root when inside one, else
the current directory) and prints three things: the **evidence** (git presence,
commit count, tracked-file count, source-file count, manifests/lockfiles,
`.github/workflows`, docs, `CLAUDE.md`/`AGENTS.md`, `.spark/`), the **verdict**
with a confidence word, a **routing recommendation**, and the **next verb** to
run. It writes nothing — orientation must precede any file creation.

The **Next** section answers the one question that separates Spark's two front
doors: *is there a runtime to scaffold?* Both `/spark:onboard` and
`/spark:bootstrap` end by calling `spark setup`, so choosing wrong costs a
second `setup` run and a repo history that matches neither documented path.
orient already holds the deciding evidence — the manifest line — so it names
the verb: no manifest or lockfile → `bootstrap` (scaffold, then it carries the
standard in); a manifest already present, or an `existing` verdict → `onboard`
(arm the repo as it stands). On an `ambiguous` verdict the recommendation is
stated conditionally, behind the stop-and-ask rule.

Two pieces of evidence are deliberately weighted below the rest. A **README**
is present in virtually every repository — GitHub writes one at `repo create` —
so it is reported but never counted as a content signal; a `docs/` tree, which
somebody had to make, is counted. And the **source** count is the tracked files
that are not pure repository metadata (`README`, `LICENSE`, `CHANGELOG`,
`CONTRIBUTING`, `.gitignore`, and the like), so repository boilerplate cannot
stand in for a codebase. A repo whose commits contain nothing but that
boilerplate is a repository, not yet a project, and lands in `ambiguous`.

The verdict is one of three bands:

| Band | Meaning | Routing |
| --- | --- | --- |
| `new` | No git repo, or a repo with zero commits and none of the artifacts a real project carries | Safe to scaffold — `/spark:bootstrap`, then `spark setup` |
| `existing` | Real commit history plus tracked source or a project artifact (a bare README is neither) | The repo's decisions are authoritative — discover first, never scaffold; adoption stays create-only |
| `ambiguous` | Sparse or conflicting signals (content but no version control, staged content with no commits, or commits holding only repository boilerplate) | Do not infer authorization — ask a human, then record with `--set` |

`--set new|existing` records the human's decision as a create-only project
fact — `project.classification` and `project.classified` (ISO date) — in
`.spark/preferences.json`, merged with the same jq→python3 graceful degradation
`apply-permissions` uses so no other committed fact is disturbed. Recording is
create-only: a same-value `--set` is a no-op (`kept`), and a different value is
treated as the explicit human re-set the flag names. Without `jq` or `python3`,
merging into an existing file prints the keys to add by hand. An `ambiguous`
inspection is never recorded automatically — the `--set` is the human's call.

## `spark triage [--tsv]`

The existing-repository entry motion, first arrow only: **establish what is true,
read-only, and stop before anything mutates.**

Read-only means read-only at the repository boundary. A project's own validation
command is treated as **mutation-capable** until observed otherwise — a script
named `validate`, `test`, `build`, `lint` or `check` says nothing about its side
effects, and one found in the field ran a build that rewrote a tracked file. Such
a command is therefore never run in place: it runs in a disposable worktree and
the source is proven unchanged afterwards, covering refs, the index, and
untracked output as well as tracked content. Where that isolation cannot be
established the result is reported **NOT ASSESSED with the risk named**, never
run anyway. A genuine failure from a safe command remains ordinary evidence and
is not hidden by the rule.

```
existing repository
  → establish truth read-only
  → sort it into known / mechanically wrong / judgment-bearing / unknown
  → stop
```

Reconciling what it finds, and deciding the resulting course, are separate
capabilities. `triage` does neither, and says so in its own output.

### An orchestrator, not a collector

Every fact in the report is produced by the authority that already owns it.
`triage` arranges and renders; it derives nothing itself.

| Fact | Authority it calls |
| --- | --- |
| recorded classification, live verdict, drift | `repo_classification` — the same producer `brief` reads, over `classify_repo` |
| branch, dirty count, ahead/behind | `repo_git_facts` — shared with `brief` |
| local trunk and how it was determined | `repo_trunk` |
| recorded next action and blockers | `repo_recorded_intent` — `.spark/state.json`, as recorded intent only |
| governed labels, issue metadata, dependency graph, file surfaces, ruleset | `gov_collect` — the governance engine, unchanged |
| what kind of finding a `!` is | the governance verdict partition, unchanged |

Those first four were inline in `brief` before this verb existed; they were
lifted into named producers so both verbs read one authority rather than two
implementations of "which branch is this". `brief`'s output is unchanged.

It is **not** `audit assess`. It runs no deep assessment, and the core plugin
does not depend on the optional `spark-audit` companion — `triage` works with
only the core installed. Audit may later deepen Triage's evidence; Triage stands
alone.

### The four truth states

Reported with the same row alphabet the governance engine uses, so the two
cannot disagree about what a finding is:

| Status | State | Meaning |
| --- | --- | --- |
| `=` | **KNOWN / coherent** | evidence exists and agrees |
| `!` | **MECHANICAL PROBLEM** | a contradiction no decision resolves |
| `!` | **HUMAN DECISION REQUIRED** | evidence is sufficient; the authority is not Spark's |
| `?` | **UNKNOWN / NOT ASSESSED** | the surface could not be read |

They never collapse into each other. Two consequences worth stating plainly:

- **An unread surface is not a negative fact.** If `gh` is absent, the report
  says the issue graph was not assessed — never that there are no issues.
- **A known negative is not unknown.** "No upstream is tracked" and "no intent
  is recorded" are established facts, reported `=`.

Which `!` rows are judgment is decided by `GOV_JUDGMENT_SURFACES`, the single
list the governance verdict partition reads. `triage` adds two surfaces to it:
`class`, because reclassification is the human's call under ADR-0022, and
`intent`, because the next action is the judgment no repository can answer for
itself.

### Issue references in recorded intent are explicit

Triage reads `.spark/state.json`'s recorded next action to ask whether it is
still live, which means finding the issues it names. A reference is `#`
immediately followed by digits, with a word boundary on both sides — the sigil
is the whole distinction, and one extractor owns that syntax for the CLI.

| Text | Reads as |
| --- | --- |
| `v0.22`, `v0.21.0` | nothing — a version, not a reference |
| `2026-09-01`, `port 8080`, `95%` | nothing — dates, ports and counts are numbers |
| `abc#12`, `#12abc` | nothing — no word boundary |
| `finish #42` | issue 42 |

Without the sigil requirement every number in ordinary prose became a
reference: a recorded intent mentioning `v0.22` and `v0.21.0` had `22` and `21`
looked up as issues, manufacturing evidence about a decision out of a version
string.

Three outcomes, kept apart:

- **references, at least one open** — the intent still names live work;
- **references, all closed** — the intent is spent, and choosing the next action
  is a human decision;
- **no references at all** — reported as exactly that. It is neither spent nor
  still-live, because issue state cannot speak to it either way.

A reference whose state cannot be read stays **not assessed** — an absent `gh`
and an unanswered API are reported differently, since an operator fixes them
differently, but neither becomes a negative fact.

### Read-only, and mechanically so

`triage` creates and modifies nothing: no files, no labels, no priority, no
milestone, no backlog disposition, no issues or PRs, no dependency edges, no
governance provisioning, no `.spark/state.json` write. It never invokes
`governance apply`. Remote state is read through read-only APIs only.
`tests/test-triage-truth.sh` snapshots the tree, the git object store, `.spark/`
and the remote-facing surfaces before and after a run and asserts nothing moved.

### Exit codes

| Exit | Verdict | Meaning |
| --- | --- | --- |
| `0` | `COHERENT` | no truth conflict; ready for reconciliation or course derivation |
| `1` | `FAIL` | a mechanically invalid state — no decision resolves it |
| `5` | `DECISION REQUIRED` | a durable value is owed and only a human may supply it |
| `3` | `NOT ASSESSED` | a surface could not be read; never assumed healthy |

The most severe present state wins, and every lesser one is still named.

### Reconciliation required

One field answers whether anything must be reconciled *before* proceeding:

- **no** — no mechanical problem and no owed decision. This is deliberately not
  a claim that all future work is known; it means Triage found nothing that must
  be resolved first.
- **yes** — findings exist; route them through reconciliation.
- **undetermined** — a surface could not be read, so the answer is not negative
  and not a pass.

`--tsv` emits the rows plus a `reconciliation` and a `verdict` line for
mechanical consumption.

## `spark reconcile [--tsv]`

The reconciliation slice of Triage: turn the evidence `triage` established into a
**reviewable slate**. It proposes, and applies nothing.

```
observe → classify → propose → [ approve → mutate ]
                              ^ this verb stops here
```

### Two axes, deliberately separate

Every finding carries an **evidence** state and a **disposition**, and they are
different questions:

| Column | Values | Asks |
| --- | --- | --- |
| `evidence` | `known`, `unread` | what could Spark actually read? |
| `disposition` | `KEEP`, `REWRITE-COLLAPSE`, `DROP-ARCHIVE`, `DECISION-REQUIRED`, `-` | what is proposed? |
| `authority` | `deterministic`, `human` | whose call is it? |

**A row whose evidence is `unread` carries no disposition at all** — the column
is `-`. Not `DECISION-REQUIRED`, which is a claim about authority; not `KEEP`,
which is a claim about the artifact. Proposing a disposition for something Spark
could not read is exactly the collapse this design exists to prevent: unknown is
an evidence state, decision required is an authority state, and turning the
first into the second is how missing evidence becomes a guessed decision.

`deterministic` means an already-approved policy supplies the value, so Spark may
act under its normal mutation contract. `human` means it may not.
`DECISION-REQUIRED` narrows that further: not merely "a person must act" but
"a person must **choose**".

### What the slate reports

`area | evidence | disposition | id | finding | action | risk | validation | authority`

Findings are drawn from the authorities that already own them — the recorded
intent, the governance engine's own rows, the merge graph, and milestone state.
Nothing is re-derived here.

- **recorded intent** — still names open work (`KEEP`), names only closed issues
  (`DECISION-REQUIRED`: what comes next is yours), or names none explicitly.
- **governance** — drift and missing declared surfaces are `REWRITE-COLLAPSE`
  under `deterministic` authority, carried by the existing governance path
  rather than reimplemented; judgment gaps are `DECISION-REQUIRED`.
- **branch residue** — a branch **fully merged into trunk** is `DROP-ARCHIVE`:
  its commits are in trunk, so the branch is a pointer and dropping it erases no
  history. Unmerged work is never proposed, and trunk, release lines and
  `gh-pages` are never proposed whatever the merge graph says.
- **milestone residue** — an open milestone with no open issues.

Every proposed removal or rewrite cites its evidence and names how to validate
the result. **Cleanup never erases history merely because it is no longer
current**, which is why a merged branch is proposed and an unmerged one is not.

### Read-only

`reconcile` deletes nothing, closes nothing, relabels nothing, assigns no
priority, milestone or disposition, provisions nothing and commits nothing. The
behavioural suite snapshots the working tree, every ref and the git object store
across a real run, and separately proves no write-shaped GitHub call is made.

### Approving part of the slate

An approval names one finding, `area:id`, and one approved finding is one group:

```
spark reconcile --approve release:v0.20.md            # preview; changes nothing
spark reconcile --approve release:v0.20.md --yes      # apply it
```

| Flag | Effect |
| --- | --- |
| *(none)* | preview — reports what each approved finding would do |
| `--yes` | apply the approved findings that edit files |

**Only file edits are applied automatically**, because they are the only kind
that can land as one revertible commit. Everything else is reported with the
exact command to run yourself:

| Kind | Areas | Applied by `--yes`? |
| --- | --- | --- |
| `tree` | `release` | yes — one commit each |
| `manual` | `branch`, `milestone`, `governance` | **no** — reported with the command |
| `none` | `KEEP`, `DECISION-REQUIRED` | never |

Deleting a ref, closing a milestone and provisioning a label are not commits;
nothing about them reverts with `git revert`. Automating them would mean
quietly weakening the one-group/one-commit guarantee to fit operations that
cannot satisfy it, so **there is deliberately no flag that promotes a `manual`
finding to an applied one** — an unrecognised flag is rejected rather than
ignored. Automating irreversible reconciliation needs a compensating contract
this release does not have.

Governance is delegated rather than invoked, and the reason is specific:
`governance apply` acts on a **whole family**. Driving it from one approved
finding could provision surfaces the operator never approved, and re-deriving
the slate would not notice — the approved finding would be gone and so would the
others, which reads as success. One approved finding means one mutation and
nothing else, so reconciliation points at the governance command until that
command can act on exactly one finding.

**A `DECISION-REQUIRED` finding is never carried out**, with any flags. A
judgment is not one permission away from being Spark's to make — record the
decision in the governed field yourself and the finding clears on the next run.

Per approved group, in the order given: the change is made; if it touched the
tree it lands as **exactly one commit**; then the slate is **re-derived** and the
finding must be gone. That last step is the validation, and it re-runs the
producer rather than trusting an exit code — a check that asks "did the command
succeed?" passes when the command succeeded and did the wrong thing.

A failing group **stops the run**, leaving earlier groups applied and validated
and attempting nothing later.

Each selector is resolved against a **freshly derived slate immediately before
acting**, never against the slate read at the start of the run. Approving one
finding twice therefore does not make it two groups, and neither does an earlier
group that happens to clear a later selected finding: a stale row never
authorises a mutation. **`Applied N group(s)` always equals the number of commits
made** — a group that turns out to change nothing is refused rather than
counted.

One group being one commit is what makes an approval recoverable: `git revert` on
a group in the middle of a run leaves the others applied, and the next
`reconcile` shows the reverted finding back on the slate because the slate is
derived from the repository rather than remembered.

`--yes` refuses on a dirty working tree. "One commit per group" would be untrue
if unrelated work rode along, and reverting the group would then take that work
with it.

The operator procedure — reading a slate, approving part of it, and recovering
from a failure mid-run — is the
[reconciliation runbook](https://github.com/jwogrady/spark/blob/master/docs/ops/reconciliation-runbook.md)
(developer-only).

### Exit codes

| Exit | Meaning |
| --- | --- |
| `0` | nothing requires reconciliation |
| `5` | at least one `DECISION-REQUIRED` item awaits human authority, or an approval was refused as not automatically appliable |
| `3` | some evidence could not be read; never a pass |
| `1` | not inside a git repository, or a group failed while applying |

`--tsv` emits the header, every row, and a summary line that counts proposals
and decisions **apart** — they are different asks.

### Where the vocabulary lives

The four dispositions, the unread evidence state and the approval boundary are
**core Spark's**. The audit companion may consume and extend them; core never
depends on it, and a repository with only the core plugin installed produces a
slate.

## `spark course [--tsv]`

Which objective is coherent to pursue next.

### Three questions, three owners

The blur between these is the defect this verb exists to avoid, so it is stated
rather than implied — and `course` says so in its own output:

| Verb | Question |
| --- | --- |
| `spark brief` | where did the lifecycle leave off? (stage, recorded intent) |
| **`spark course`** | **which objective is coherent to pursue?** |
| `spark next` | which issue inside that objective? |

`course` never recomputes the lifecycle position and never selects an issue.

### It consumes, it does not rediscover

The evidence comes from the truth pass and the reconciliation slate, and the
current milestone comes from the same selector `next` uses. A third reading of
the same repository would be a third opinion about it.

| Fact | Owner |
| --- | --- |
| contradictions, decisions owed, unread surfaces | the truth pass |
| outstanding dispositions | the reconciliation slate |
| which milestone is running | the selector shared with `next` |

### Five outcomes

| Outcome | When |
| --- | --- |
| `CONTINUE CURRENT COURSE` | an active milestone holds open work and nothing contradicts it |
| `REPAIR CURRENT COURSE` | the course exists but truth contradicts it — its release boundary does not hold, a mechanically invalid finding, or a recorded intent naming only closed work |
| `CLOSE / RELEASE COMPLETED COURSE` | the running course has no work left to do — either nothing at all, or only its release gate |
| `PLAN A NEW COURSE` | no open milestone holds work and none waits to be closed |
| `HUMAN DECISION REQUIRED` | materially different directions are plausible |

### A release gate is not work

The milestone's release-readiness gate is an open issue, and GitHub counts it in
`open_issues` like any other. It is not work: it is what remains once the work
is done, and `next` has always refused to select it because a parent closes
last.

Counting it as work made the finished state indistinguishable from the working
one. Every Spark milestone ends with its gate open and every leaf closed, so
`course` said `CONTINUE` and routed to `spark next` — which then reported there
was no leaf to select. Two authorities, one question, two answers. Both
verbs now read one projection over one snapshot of the milestone hierarchy, so
they cannot disagree about whether work remains.

**Which issue that gate is comes from the governed role**, not from the shape
of the hierarchy — the same fact `spark governance` reports and `spark next`
selects against, read from the same snapshot (see
[metadata-governance](metadata-governance.md)). A milestone may hold ordinary
parents; they are containers, they close with their children, and they are not
release boundaries. Recognising the boundary by its shape here would name an
ordinary parent as one, and recommend a release across a milestone that
declares no boundary at all.

And a boundary is only a boundary while it holds. When the projection reports
the running course's gate broken — two of them, one that closed before its
work, or open work outside its hierarchy — there is nothing to certify across
it, and the course is `REPAIR`, never a closure. That is a known bad state, not
an unreadable one.

The consequence worth stating: a milestone whose leaves are all closed is still
**the running course** until its release boundary closes, and its certification
outranks work queued under a later version. A later milestone holding open
issues is a plan, not a competing direction — so this is a closure course, not
`HUMAN DECISION REQUIRED`.

An unread hierarchy is never read as "no work left". A truncated page and an
empty one are different answers, and reading the second from the first is how a
partial read would become a release recommendation.

**`UNKNOWN / NOT ASSESSED` is not a sixth outcome.** It is an evidence state,
reported beside whichever course the readable evidence supports — or, when the
essential inputs cannot be read at all, as the verdict in its own right. An
unreadable milestone surface is never read as *having no milestones*: a negative
fact and an unread one are different answers.

### Read-only, and narrowly

It creates no milestone, assigns no priority or disposition, and records no
product direction. A repository is not made coherent by writing something that
says it is. It recommends and routes; that is the whole of its authority.

### Exit codes

| Exit | Meaning |
| --- | --- |
| `0` | a course was derived — `CONTINUE`, `REPAIR`, `CLOSE / RELEASE`, or `PLAN` |
| `5` | `HUMAN DECISION REQUIRED` — two or more materially different directions |
| `3` | `NOT ASSESSED` — the essential evidence could not be read |
| `1` | not inside a git repository |

`--tsv` emits the gathered evidence plus a `course` and a `route` line.

## `spark crossroad <kind> [authority] [surface]`

Classify a proposed stop before handing off to the human. The autonomous
orchestrator's costliest stop mistake is not running past a real boundary — it
is inventing one. A genuine Crossroad exists only when the next motion
needs an authority a durable surface reserves to the human.

`crossroad` admits a stop **only** for a recognised boundary kind that also
**names** the missing authority and **cites** the durable surface reserving it.
Everything else continues. It exits `0` to continue and `3` at a genuine
`DECISION REQUIRED`.

| Kind | Verdict |
| --- | --- |
| `new-authority`, `product-governance-semantics`, `release-policy`, `destructive-external`, `decision-required` | **`DECISION REQUIRED`** — but only when both `authority` and `surface` are named |
| `activate-authorized`, `evidence-substitution`, `co-authorship`, `operator-courtesy`, `presumptuousness`, `consequentiality`, `general-caution` | **`CONTINUE`** — never an authority boundary |

Activating a capability the owning issue already authorized is not a new grant
merely because it goes live on merge. Substituting one form of evidence for
another — an independent exact-HEAD review standing in for a bootstrap that
cannot self-review — is a verification question, not a governance decision. And
co-authorship, operator courtesy, perceived presumptuousness, or general caution
are never authority.

A boundary kind with no named authority or cited surface **continues**: you must
be able to name the exact reserved authority, and point at the durable surface
that reserves it, before you stop. This changes nothing about `UNKNOWN` / `NOT
ASSESSED`, stale-head protection, review, or CI — those stop work on their own
evidence; `crossroad` governs only the human-handoff decision.

```
$ spark crossroad activate-authorized
CONTINUE                                    # exit 0
$ spark crossroad new-authority "a write-capable deploy key" "AGENTS.md guardrails"
DECISION REQUIRED                           # exit 3
```

## `spark hub [--set <owner/repo|url|none>]`

Reports the memory hub this project declares — the one repository designated
as the durable authority for its cross-project provenance — and the preference
tier the value came from. The model behind the pointer (hub/spoke ownership,
the promotion chain, what may and may not live in a hub) is decided in
ADR-0028; this verb only records and resolves the pointer.

Bare, it resolves `project.memory-hub` through the normal three-tier
preference resolution and prints one of four truthful states:

| State | Meaning | Exit |
| --- | --- | --- |
| configured | A well-formed locator plus its source tier | 0 |
| `none` | The human explicitly declared this project standalone | 0 |
| not configured | No declaration anywhere — the normal standalone default | 0 |
| malformed | A configured value that names no repository | 1 |

Spark never guesses a hub from repository naming, siblings, or history — a
missing or malformed pointer is reported as exactly that.

`--set` records the declaration as a project fact in
`.spark/preferences.json`, merged with the same jq→python3 graceful
degradation `orient --set` uses so no other committed fact is disturbed. A
locator is provider-neutral: `owner/repo` shorthand, a URL, or an scp-style
git address — the value identifies a repository; it never mirrors that
repository's contents. A same-value `--set` is a no-op (`kept`), a different
value is named as the explicit human re-set, and the literal `none` records
the standalone decision explicitly. `setup` and onboarding preserve an
existing declaration but never choose one — declaring a hub is always the
human's call.

## `spark labels [--apply] [--prune-deprecated]`

Reconciles **every governed label family** — the issue taxonomy plus the
priority, theme, disposition, and `docs-impact` families the governance model
declares — with the labels that actually exist on the remote.

Reconciling only the taxonomy left a real gap: `docs-impact` ships as a
*required* family, `plan` instructs the agent to declare a disposition, and the
issue manifest hard-fails on a label the repo does not have — so a family
nothing provisioned took the lifecycle down with it. The same omission had left
`decision` and `human-approval` unprovisioned in repos where `spark next`
routes on them.

Category **names** still come from `issue.taxonomy`; every other family's
members come from the governance model, which is their only authority. Spark declares a seven-category taxonomy (`issue.taxonomy`), writes
it into every onboarded repo's `CONVENTIONS.md`, and builds
[metadata governance](metadata-governance.md) on top of it — but labels live on
GitHub, and `setup` is an offline, create-only pass, so provisioning them is
this verb's job rather than setup's.

The taxonomy resolves through the normal tiers, falling back to the
`<!-- spark:pref issue.taxonomy=… -->` marker in `CONVENTIONS.md` so a
collaborator without Spark installed still reads the categories the project
declares — prose and labels cannot drift apart.

**Reports by default; writes only with `--apply`** — the same shape as every
other remote-touching capability. Each declared category is reported as
`= exists, kept` or `+ missing`, and creation is **create-only**: an existing
label is the project's own decision and is never recoloured or re-described.
Theme labels the taxonomy does not name (`good first issue`, `help wanted`, …)
are never touched. A category with no shipped colour gets neutral grey, so
extending `issue.taxonomy` is always safe.

`enhancement` — GitHub's default label and the deprecated alias for `feature` —
is reported with the number of issues **and pull requests** still carrying it
(a labelled PR is invisible to an issue-only query, yet `gh label delete`
strips the label from it too, so the gate has to see it). Deleting it is
destructive, so it requires both `--apply` and `--prune-deprecated`, **and**
proof that nothing in any state carries it; otherwise the verb refuses and
says to relabel first. Spark will not silently drop an issue's category. If
that count cannot be obtained, the verb says so and leaves the label alone —
it never infers "unused" from a failed probe.

Without an authenticated `gh`, or when GitHub is unreachable, the verb reports
**not assessed** and exits 0 — never "healthy" by assumption. The label
listing is paginated, so a repository with more than one page of labels cannot
have an existing category misreported as missing.

## `spark governance [--tsv] | inspect | diff | apply | validate`

Renders the **resolved governance model** — Spark's one machine-readable
authority for the *allowed shapes* of a Spark-managed repository's GitHub
governance. It is read-only and deterministic: three local artifacts, no
network, no remote state, no writes.

What the model represents:

| Part | What it declares |
| --- | --- |
| Label families | Each governed family, its cardinality (`exactly-one`, `at-most-one`, `any`), whether it is `required`, and every member's label, colour, and description |
| Execution structure | Which GitHub surface is `authoritative` for scope, hierarchy, dependency, order, and implementation linkage — and which readings are merely `derived` |
| Separations | The pairs that must never be collapsed: order is never derived from blocked-by or priority; a theme or disposition label never satisfies the one-category requirement |
| Surfaces | Governance surfaces and who provisions each (`spark-provisions`, `human-provisions`, `assessed-only`) |
| Enforcement | The enforcement requirements that can be assessed mechanically, local and remote |

The model is the authority for allowed shapes **only**. Which issue is `P0`,
and what blocks what, is project-specific judgment: it stays the human's call
and lives on GitHub.

### The artifact and its tiers

The model is its own versioned, line-oriented, tab-separated artifact — not
flat JSON through the preference resolver, and not nested JSON. The reason is
recorded in [ADR-0030](https://github.com/jwogrady/spark/blob/master/docs/adr/0030-governance-model-representation.md)
(developer-only): the preference resolver is deliberately flat and drops every
non-scalar member, and Spark's zero-dependency rule means a nested-JSON
authority would be unreadable wherever `jq` is absent — "degrades gracefully"
cannot mean "degrades to no governance model at all".

Resolution keeps the same three tiers as every other Spark standard, later
winning, and every rendered record names the tier it came from:

| Tier | Location |
| --- | --- |
| `default` | `preferences/governance-models/<governance.model>.tsv` in the plugin |
| `operator` | `$XDG_CONFIG_HOME/spark/governance.tsv` |
| `project` | `.spark/governance.tsv` in the repo |

The `governance.model` scalar preference selects which shipped model is the
base (default `spark-default`); it must be a bare model id, and a value
containing a path separator fails closed rather than reading an arbitrary file
as governance authority.

A later tier overrides a record by key. **A tier that declares any member of a
family replaces that family's whole member set** — so an overlay can remove a
member and not only add one, which a per-member merge could never express. The
same applies to a class's governed paths, and to a **structure aspect**: a tier
that declares any fact about an aspect replaces that aspect's whole set of
lower-tier facts.

An aspect can state more than one fact, and those stay together when their tier
wins. `dependency` is the example: the shipped model declares native blocked-by
as its **authoritative** form and an issue-body `Blocked by #N` sentence as a
**derived** one, and replacing that aspect means replacing both — not merging
one new fact in beside them. Records still key per `(aspect, fact)`, which is
what lets the winning tier declare several; replacement is per aspect, which is
what lets a project restate what an aspect means rather than only adding a
rival claim beside the shipped one.

Removing a member leaves the lower tiers' rules about it — its exclusivity, its
governed paths — pointing at nothing. Those rules are **pruned**, not treated as
errors, or narrowing would make the model permanently unresolvable: declaring a
replacement rule for a member that no longer exists is itself unclosed. Pruning
applies only to a **strictly lower** tier. A rule declared at or above the tier
that owns the member set is naming a member that tier can see does not exist,
which is a typo, and still fails closed.
Member blocks stay anchored where the base first declared them, and within a
block the winning tier's own order holds: priority ordering is the member
declaration order, stated as data rather than inferred from the label spelling.

### Category names stay with the preference

`issue.taxonomy` already owned the category **name set** across all three
tiers, and keeps owning it. The model owns each category's **colour,
description, cardinality, and requirement** — the values that used to be
hard-coded in `bin/spark`. That is one authority per fact, and `spark doctor`
holds the two shipped files in parity — compared as **sets**, since the
question is which categories exist — so they cannot drift into two answers.

Because the two are independent, a *resolved* model can be valid and still
contradict the taxonomy, and the two cases mean different things:

- **A category `issue.taxonomy` names that the shipped member set does not.**
  It was added — the supported extension path. It resolves to neutral grey
  with a generic description, and `spark labels` says so.
- **An overlay tier replaced the category family and left categories
  undeclared.** Now two of the operator's own declarations disagree. `spark
  labels` reports which tier replaced the family and which categories are
  undeclared, and **refuses to create them** under `--apply`: they have no
  declared colour, the verb is create-only, so a guess written once is never
  corrected.

A model that cannot be resolved at all blocks label **creation** only.
`--prune-deprecated` reads no colour and no description, so it is unaffected.

### Adding a governed label family

A new family is **data**. Add a `family` record and its `member` records to any
tier's artifact and every generic consumer picks it up — no schema code
changes.

### Failure behaviour

Fails **closed**. Any tier that is syntactically invalid, or a resolved model
that is not closed (a member whose family nobody declared, a separation naming
neither a declared family nor a declared structure aspect), is reported as one
precise `<file>:<line>: <problem>` per finding and the verb exits non-zero. An
unreadable governance model never degrades to a partial one. `spark doctor`
validates the shipped artifact for the same reason it validates
`preferences/defaults.json`: it is load-bearing shipped source.

### Output

Bare, the verb groups the records for a human and names each one's tier.
`--tsv` prints the **stable machine-readable render** other commands and the
behavioural suites consume — one record per line, exactly the artifact grammar
plus a trailing source column:

```
version	1	default
family	category	exactly-one	required	Primary work category — exactly one per issue	default
member	category	feature	0e8a16	New capability or user-visible behaviour	default
structure	order	gate-sub-issue-order	authoritative	Preferred delivery order is …	default
separation	order	priority	Delivery order is never manufactured from priority; …	default
```

Diffing the model against live GitHub state, and provisioning it there, are the
subcommands below — they build on this render rather than restating it.

### `spark governance inspect | diff | apply | validate`

Four distinct responsibilities over the resolved model, all reading **one row
generator** — so a rule cannot end up with two authorities and the four
subcommands cannot disagree about what the repository looks like.

Every row is `<surface> <status> <id> <detail>`:

| Status | Meaning |
| --- | --- |
| `=` | correct |
| `+` | missing and safe to create |
| `~` | drifted and mechanically repairable |
| `!` | **requires human judgment — reported, never guessed** |
| `-` | obsolete candidate, never automatically destructive |
| `?` | **not assessed** — the surface could not be read, never assumed healthy |

Surfaces covered: `label` (every governed family), `metadata` (per-issue
invariants), `dependency` (cycle detection), `ruleset` (server-side policy
presence), `file` (declared governance files).

#### The safety boundary

This is the point of the design, not a caveat on it. Spark may report that #12
lacks a priority; it must **not** guess `P1`. It may create the standard `P1`
label. It may report that an issue carries two category labels; it must **not**
choose which one is meant. A `!` row is never applied.

#### `inspect` and `diff` — read-only

Neither writes anything, local or remote. `inspect` reports state; `diff`
reports the proposed reconciliation. They read the same rows, so they cannot
disagree. `--tsv` gives the stable machine form for CI and skills.

#### `apply` — create-only by default, idempotent

Applies only `+` rows: labels the model declares that the remote lacks. A
preview unless `--yes`.

`~` drift is an **overwrite of something the project already chose**, so it
needs `--repair-drift` said out loud. That keeps Spark's create-only default
intact — an existing label is the project's decision — while still making drift
mechanically repairable when the operator wants it. `-` obsolete candidates and
`!` judgment rows are never applied at all; removing the deprecated
`enhancement` alias stays with [`spark labels --apply
--prune-deprecated`](#spark-labels---apply---prune-deprecated), which proves
nothing carries it first.

Idempotent by construction: every create is guarded by what already exists, so
a second run is a no-op rather than a duplicate-label error.

#### `validate` — fails closed, and separates broken state from owed decisions

Four outcomes, because three were not enough:

| Exit | Verdict | Meaning |
| --- | --- | --- |
| `0` | `PASS` | every required invariant holds |
| `1` | `FAIL` | **mechanically invalid** — no decision resolves it. A cycle in the native blocked-by graph is the case: whichever issue you start, the graph forbids it |
| `5` | `DECISION REQUIRED` | a `!` row names a value **only a human has the authority to choose** — which category an issue means, which `docs-impact` class applies, whether work is milestoned or backlogged, what belongs in a surface the model says only a human provisions |
| `3` | `NOT ASSESSED` | a surface could not be read; never assumed healthy |

The most severe present outcome wins, and every lesser state that coexists is
still named. **It never reports PASS from a surface it could not read**, and when
a real finding coexists with an unread surface it says both — a definite finding
still fails, but the report admits the picture is partial.

The split matters because of what an orchestrator does with the exit code. When
every `!` collapsed into `FAIL`, the only mechanical route from a red gate to a
green one was to write the missing judgment — and an autonomous run took exactly
that route, assigning a priority and a release disposition so a certification
could continue. `DECISION REQUIRED` is the outcome that says *stop and ask*,
distinct from *something is broken and you should fix it*.

Under `DECISION REQUIRED`, `validate` prints the admissible values for every
governed family, read from the model. It reports the choice **set** and chooses
nothing: it never ranks the values and never marks one as a default.

**A recommendation is not authority.** An agent may propose a value with its
evidence, but the gap clears only when the governed field itself carries the
decision. A comment, a report, an agent's reasoning, or a sentence in the issue
body does not clear it. Once a human records the decision, deterministic checks
consume it normally on the next run.

The row alphabet is unchanged by this: `!` still means *requires human judgment
— reported, never guessed*. What changed is the verdict that reads it.

What counts as *required* is the schema's own `requirement` field, not a list in
the code. Adding a governed family as data brings it under validation with no
code change.

#### "Active execution issues"

A **required** family is demanded of work with a **milestone**. `backlog` is a
release decision, but it is the decision *not* to execute yet, so a deferred
issue is not active execution work and is not held to it either. An issue
nobody has scheduled has not been planned, and demanding its documentation
disposition before anyone decided the work happens would report every idea as a
defect.

A **cardinality** violation is reported either way: two category labels is wrong
whether or not the work is scheduled.

#### Dependency cycles

A cycle in the native blocked-by graph makes every issue in it permanently
unstartable, and the codify preflight would report each one blocked forever
without naming the cause. Detection peels off whatever has no open prerequisite;
anything left is in, or behind, a cycle — and work *behind* one is reported with
it, because it is equally stuck.


## `spark docs-impact [--issue <n>] [--branch] [--paths <file>] [--tsv]`

Verifies that an issue's **declared** documentation impact matches what its
implementation actually changed. Read-only: it reads labels, a diff, and the
governance model, and writes nothing.

Spark used to *remind* you to check documentation; it could not *prove* you
had. The failure mode it closes is not "this PR changed no docs" — very often
that is the correct outcome. It is **silent docs impact**: work lands, nobody
declares whether documentation was affected, and that omission is
indistinguishable from a deliberate "none".

> The agent decides the semantic impact. Spark verifies that the decision was
> satisfied.

### The declaration

A `docs-impact:*` label on the GitHub issue, so GitHub stays the durable
authority and the value is queryable. The family, its members, and everything
below are **schema data** in the governance model — see
[`spark governance`](cli.md#spark-governance---tsv).

| Value | Governs |
| --- | --- |
| `docs-impact:none` | nothing — a first-class, respectable answer |
| `docs-impact:public` | shipped user-facing prose: README, explanation, how-to, tutorials |
| `docs-impact:reference` | shipped reference contracts |
| `docs-impact:operator` | runbooks and operational procedure |
| `docs-impact:architecture` | decision records and the internals map |
| `docs-impact:roadmap` | the product roadmap |
| `docs-impact:release` | release records and release documentation |
| `docs-impact:companion` | a companion plugin's shipped documentation |

Multiple non-`none` values are valid and expected. `none` is **exclusive** —
combining it with any other value is invalid, not merely odd.

**Exclusivity is one overridable fact per family.** A tier declares at most one
exclusive member, and a later tier *replaces* it through the ordinary
shipped → operator → project precedence — so the resolved model always carries
**exactly one** exclusive row for a family, or none. That single row is what
every consumer reads.

Two consequences worth stating, because they are what make the rule trustworthy:

- **Two exclusive members in the same tier fail closed.** That is incoherent
  rather than something to resolve, and it is rejected where it is written.
- **Narrowing a member set prunes an obsolete rule** — but only across tiers. If
  an overlay replaces the family's members and a **lower** tier's exclusive
  member is no longer among them, that lower rule is dropped rather than left
  pointing at nothing. A tier that narrows the members *and* names a dropped
  member in its **own** `exclusive` row is incoherent with itself and **fails
  closed**: pruning is not an amnesty for a rule pointing at nothing.

Before this was resolved per family, an override left the old and new rules both
standing, and consumers reading in different orders enforced different members —
one rule with two answers.

`CHANGELOG.md` files are deliberately **not** governed: Release Please
generates them and hand-editing them is forbidden, so they can never be a
declarable impact.

### The grammar

| Declared | Governed change | Verdict |
| --- | --- | --- |
| no `docs-impact` label | — | **FAIL** — silence is never `none` |
| `docs-impact:none` **and** any other value | — | **FAIL** (invalid) |
| `docs-impact:none` | none | **PASS** |
| `docs-impact:none` | any governed class changed | **FAIL** |
| one or more non-`none` | every declared class has evidence | **PASS** |
| one or more non-`none` | a declared class has no evidence | **FAIL** |
| one or more non-`none` | an **additional** class changed | **WARN** |
| any | evidence cannot be assessed | **NOT ASSESSED** |

Two rows carry the weight. **Zero disposition always fails** — an issue that
declares nothing fails whether or not documentation changed, because the
omission is the defect. And **WARN applies only to an additional class beyond
an otherwise valid non-`none` declaration**; it is not a general "docs changed
but nothing was declared" escape hatch, since that case is an undeclared issue,
which fails.

Exit codes: `0` PASS and WARN (a warning is reported, never silent, but does
not fail a build), `1` FAIL, `3` NOT ASSESSED — **never** `0`.

### Core and companion are distinct surfaces

Each governed path carries a surface — `core`, `repo`, or `companion`. A change
under a companion plugin's docs never satisfies a core declaration, and a core
change never satisfies `docs-impact:companion`. That distinction is mechanical,
held by the surface column rather than by convention.

### The evidence set

A single closing PR is the common case, not the model. The evidence set is the
**union of changed paths across every linked implementation PR**, aggregated
and *then* judged — so documentation that landed in an earlier PR of the same
issue does not false-fail.

| Mode | Evidence |
| --- | --- |
| default | every **merged or open** PR linked to the issue as a closer, aggregated |
| `--branch` | the branch's diff against the remote trunk, **unioned** with the issue's linked PRs — the pre-PR signal `validate` uses |
| `--paths <file>` | repo-relative paths, one per line; deterministic and offline |

A **closed-unmerged** PR is deliberately excluded: its paths never reached the
trunk, so counting them would pass a declaration that nothing satisfies.

**Release-automation PRs are excluded too**, because this is an *implementation*-
evidence set. GitHub reports the Release Please PR as a closing reference for
every issue in the release — its generated body repeats each `Closes #NNN` — so it
entered the set and was graded as though a human had written it. Its file list is
decided by the release tool, carries no author intent about documentation, and
changes with release timing.

The signal is **durable configuration, and it takes two facts**, both read from
`release-please-config.json`:

| Fact | Key | Default |
| --- | --- | --- |
| the head-branch prefix it opens its PR from | `branch-prefix` | `release-please` |
| the label it puts on that PR | `label` | `autorelease: pending` (and `autorelease: tagged` after release) |

**The prefix alone is not sufficient.** Branch names are user-controlled and
`release-please--branches--` is not reserved, so a human PR called
`release-please--branches--manual-doc-fix` would have its evidence silently
dropped — and if another PR still carried code, the declaration could then PASS on
an incomplete set.

Author is not usable as the corroborating fact: Release Please is commonly run
with a token, so its PRs are authored by a human account. What it always applies —
and re-applies — is its label, and a human branch collision does not carry it.

A title pattern would be worse than either: the configured title pattern is free
text a human can edit, and an implementation PR may mention a release in its own
title. Where release automation is not configured, nothing is excluded.

The exclusion is **reported, not silent** — an exclusion nobody can see is
indistinguishable from a PR that was never linked:

```text
evidence-excluded	release-automation	<release-pr>
evidence	PR(s) #<a> #<b>	10
```

And if **every** linked reference is release automation, the verdict is
**NOT ASSESSED**: that is not "no PR is linked yet" — which is a complete answer
graded on the branch — it is "no implementation evidence could be read", which is
never a pass.

`--branch` unions rather than judging the branch alone because the evidence set
is **per issue, not per branch** — the documentation for an issue may already
have merged in an earlier PR while this branch carries only code.

**An evidence layer that did not answer is not an answer that there was nothing
there.** Each layer has two distinct outcomes and they are never merged:

| Layer | It answered | It failed |
| --- | --- | --- |
| linked-PR lookup | no PR is linked yet → the branch diff is the whole set, and is graded | **NOT ASSESSED**, layer `linked-pr-lookup` |
| a linked PR's file list | the paths join the union | **NOT ASSESSED**, layer `pr-files` |
| repository identity | owner/name resolved | **NOT ASSESSED**, layer `repo-identity` |

The distinction is the point. "This issue has no linked PR yet" is a complete
answer that the verb must grade, or it would be unusable before the first PR
exists. "The lookup did not come back" is no answer, and grading the branch diff
alone against it turns a FAIL into a PASS — precisely the *absence of evidence
is not evidence of absence* failure this verb exists to prevent.

Under `--tsv` a failure emits an `evidence-note` row carrying the **layer name**
in its own column, so a consumer can branch on which layer failed — retry a
lookup, or open a PR — without parsing prose:

```text
evidence-note	linked-pr-lookup	the linked-PR lookup for #77 failed — earlier merged evidence is unknown, never assumed absent
verdict	NOT ASSESSED	the linked-PR lookup for #77 failed — earlier merged evidence is unknown, never assumed absent
```

**The linked-PR connection is exhausted, not sampled.** It is read page by page
until `hasNextPage` is false, because "the union across every linked
implementation PR" has to mean every one. A single `first: 50` request treated a
successful first page as the complete answer, so an issue with 51 linked PRs
could be graded on 50 of them — and the evidence that contradicted the
declaration sat on the page nobody asked for.

That failure is invisible without pagination: the request *succeeds*, so there is
no error to report. A **continuation page that fails is NOT ASSESSED** at the
`linked-pr-lookup` layer — the partial set is never graded — and a `hasNextPage`
with no cursor is refused for the same reason rather than silently stopping.

Paths come from the **paginated** REST files endpoint, not `gh pr view --json
files`, which stops at 100 files without saying so — a documentation change at
position 140 of a 150-file PR was invisible and the verdict came back PASS.
Renames contribute **both** paths: a doc moved out of a governed tree reports
only its destination otherwise, so the tree it left would look untouched.

Without `--issue`, the number comes from the branch name (`feat/483-slug`), the
convention `codify` creates.

**NOT ASSESSED** covers: no issue number resolvable, no authenticated `gh`, an
unreadable issue, no linked implementation PR yet, an unresolvable diff or
evidence file, an unresolvable governance model, and **any evidence layer that
failed to answer** — an unidentifiable repository, a failed linked-PR lookup, or
a PR whose file list could not be read. None of them is ever reported as a pass.

The last group is worth stating separately: a *failed* linked-PR lookup and a
lookup that *successfully* found none are both non-pass in the default mode but
differ in `--branch`, and they always differ in what they report. Telling an
author "this issue has no implementation PR" when the query simply failed sends
them to open a PR that already exists.

### Where it runs

```text
plan      → the issue declares its docs-impact
codify
validate  → spark docs-impact --branch, so the signal precedes the PR
PR        → merge
```

`--tsv` prints the same result as stable records (`issue`, `declared`,
`evidence`, `governed`, `verdict`) for CI and skills.

### Selection is not a licence to start

After naming the next issue, `spark next` checks that issue's **execution
metadata** against the schema and **refuses** if it is mechanically invalid —
two categories, or a required family undeclared on scheduled work. It exits
non-zero and names each problem.

It exits **4**, distinct from exit 1's "no eligible issue", and reports before
printing the route — reading a lane and then "not ready" invites acting on the
first half.

It does not fix anything. Which category was meant, or which disposition
applies, is a human decision and never a default. And when the governance model
does not resolve, the check is reported as **NOT ASSESSED** rather than skipped:
a clean-looking selection with no hint that governance was unassessable is the
failure this check exists to prevent.

Both the priority *set* and its *ranking* come from the model's `priority`
family, so a project that extends or renames it is understood.

## `spark plan validate|diff|apply|verify <artifact>`

Compiles an **approved** plan artifact into GitHub state:

```text
agent/human intent → structured plan → validate → diff → approve → apply → verify
```

There is exactly **one** compiler, and this is its command surface. The
[plan skill's](../../skills/plan/SKILL.md) `issue-manifest.sh` owns the
manifest's **structure** — record shapes, refs, duplicates, cycles — and owns
creating, updating and wiring with its resumable state and its shared
dry-run/live analyzer. This surface owns **meaning**: it resolves categories and
priorities against the [governance model](#spark-governance---tsv-inspect-diff-apply-validate),
compares the artifact to live GitHub state, and verifies the result afterwards.
Neither restates the other.

### The artifact

Line-oriented and tab-separated, the format `issue-manifest.sh` already
documents, extended with four record types:

| Record | Shape |
| --- | --- |
| `issue` | `KEY`, title, `labels,csv`, milestone, body-file |
| `milestone` | `KEY`, title, description |
| `subissue` | `PARENT_REF`, `CHILD_REF` |
| `blockedby` | `ISSUE_REF`, `BLOCKER_REF`, *optional* reason |
| `order` | `REF`, position |
| `update` | `#N`, `title`\|`labels`\|`milestone`\|`body-file`, value |
| `decision` | `REF`, question |

Each new type exists because its absence was where drift entered:

- **`milestone`** — milestones used to be lookup-only, and a missing one was a
  hard error, so a slate could not bring its own release scope. It can now be
  created, and **more than one milestone per artifact** is representable.
- **`order`** — preferred delivery order needs its own home. Without one it gets
  encoded as `blockedby`, and an edge added to express sequence becomes a false
  prerequisite the codify preflight then reports as a permanent blocker. A
  `blockedby` whose reason mentions order, sequence, preference or priority is
  **refused outright**, matched loosely and case-insensitively.

  Order is *applied*, not merely recorded: GitHub holds preferred order as the
  **sub-issue order under a parent**, which is the authority `spark next` reads
  to break a priority tie. An `order` record therefore needs its issue to be a
  sub-issue of something in the same artifact — if it is not, the plan says the
  placement **cannot be applied** and why, rather than reporting success with
  the data dropped.

  Because GitHub holds it under a parent, order is **scoped to that parent**:

  - positions are unique **within a parent**, so two independent gates may each
    declare a first child. An artifact that can carry several milestones and
    hierarchies has to be able to say what order each one wants;
  - placement chains reset at each parent — a child is placed after its own
    **sibling**, never after a child of a different parent, which GitHub cannot
    do;
  - a child attached to **more than one** parent cannot be ordered, because its
    order parent is undecidable. Two parents with no `order` record between them
    stay legal; the ambiguity is about ordering, not about hierarchy.
- **`update`** — an existing issue could only ever be a link target, so every
  restructuring had to be applied by hand.

  An `update … labels` record declares **family-scoped intent**, not the whole
  label set. Applying it removes the current members of the families the record
  names and preserves every other label, including project-local ones no
  governed family claims — the contract and its worked example live in
  [metadata-governance.md](metadata-governance.md#the-governed-label-families).
  The families are resolved against live state *before* anything is written, so
  an issue whose labels cannot be read fails the run rather than being
  overwritten with a guess.

  Its target is a **positive** `#N`, validated by the same canonical rule as
  every other issue reference: not empty, all digits, and not zero. That
  matters more here than elsewhere because creates and milestone creates
  execute *before* updates — a target rejected only at call time would mean
  remote state had already landed, leaving a partial run to reconcile. A
  zero-padded number is accepted and means the number it denotes; a value that
  is actually zero is not a valid target.
- **`decision`** — unresolved meaning has to be representable, and it **refuses
  the run** rather than being applied around.

  The refusal is **local**, and happens before `gh` is required and before
  anything is written. Detecting an unresolved decision needs no network, so
  demanding an authenticated `gh` to reach that answer reported the wrong problem
  on a machine without one — the run failed with "gh was not found" and the
  blocking human decision was never surfaced. `--fresh` waits for the same
  reason: it truncates the state file, so a refused run must not already have
  forgotten prior landings.

### `validate` — read-only, two layers

Structure first, from the script that owns it: record shapes, refs — including
every `update` target — duplicate keys, self-links, duplicate links, duplicate
order positions, and **dependency cycles**. A cycle is structural — every issue in one is permanently unstartable,
and the preflight would otherwise report each as blocked forever without naming
the cause.

Then meaning, from the schema: every label must be declared by a governed
family, and every family's cardinality and requirement must hold. The manifest
treats labels as an opaque CSV, so before this an invalid category, two
categories, a missing priority, or a plain typo passed validation and reached
GitHub.

Nothing is contacted and nothing is written.

### `diff` — read-only, against live state

The structural plan says what *would* be called. The live rows say what already
matches, so an `update` that has already been applied is distinguishable from
one that never ran — `--dry-run` alone could only ever compare against the empty
case. A value that cannot be read is reported `?`, never assumed to match.

### `apply` — approved, idempotent

Refuses without `--yes`: this is a remote mutation. Re-validates meaning before
writing anything, then hands execution to the script, which skips exactly what
its state file records. A second run over the same artifact is a no-op rather
than a duplicate.

An unresolved `decision` refuses the whole run **before the first call** —
applying around it would commit Spark to a meaning nobody chose, and doing it
part-way would leave the slate half-applied on top of that.

### `verify` — after the fact

Confirms GitHub holds what the artifact says, rather than trusting the apply
report: a run that reported success can still have been followed by someone
editing the issue.

**Every mutation-bearing record is checked**, because a verification gate that
covers a subset certifies the whole:

| Row | What it compares |
| --- | --- |
| `live` | each `update` record — title, labels, milestone, and **body** — against the existing issue |
| `created` | each created issue's title, labels, **milestone assignment**, and **body**, via the state file that records which `KEY` became which number |
| `milestone` | each `milestone` record exists on the remote, with the description the artifact declares |
| `hierarchy` | each `subissue` record is actually wired as a sub-issue |
| `dependency` | each `blockedby` record exists in the native blocked-by graph |
| `order` | the declared children appear under their parent in declared-position order |

Order is compared as **relative** placement, which is how it is applied: the
declared children are placed one after another, so a parent may also hold
sub-issues the artifact never mentions without that reading as drift.

**An empty milestone field asserts nothing.** A create leaves the milestone unset
when the field is empty, rather than setting it to none, so `verify` makes no
claim about it either — a milestone added on GitHub afterwards is not reported as
drift. The field says *"do not set this"*, not *"this must be absent"*. Give the
record a milestone to have it verified.

That symmetry is the point: `apply` and `verify` must read one field the same way,
or the verb reports drift against a state `apply` never intended to create.

Bodies are compared after normalising line endings and trailing blank lines.
GitHub returns CRLF for bodies submitted with LF, and a check that reported every
correct body as drifted would be worse than no check at all — one that always
fails gets switched off.

Exits `1` on a mismatch, `3` when any surface could not be read, `0` only when
everything checked agreed. **An empty result is `3`, never `0`**: having nothing
to check is not the same as having checked and found agreement, and reporting a
pass there would be a confirmation of nothing. The same holds per surface — an
unreadable sub-issue list is `?`, never assumed wired.

### What the compiler will not do

It does not choose an ambiguous category, priority, or dependency meaning; it
does not approve its own mutations; and it does not create a milestone the
artifact did not ask for. Ambiguity is what the `decision` record is for.


## `spark next [--milestone <title>]`

Names the one next eligible issue in a milestone, derived entirely from live
GitHub metadata, and explains why it was chosen. Read-only: it changes no
label, milestone, priority, dependency, issue state, or branch.

### Existing implementation

Before the handoff says "start coding", it reports whether someone already did.
Any **open** PR that declares a closing reference (`Closes`/`Fixes`/`Resolves
#N`) is surfaced with its number, branch and exact HEAD SHA. A PR that merely
*mentions* the issue is reported separately as **heuristic** and never promoted:
the release PR lists every issue in its changelog, so treating mentions as
implementations would report work in flight for an entire milestone.

An open PR is **evidence to inspect, never approval**, correctness, merge
readiness, or a claim on ownership. When two PRs both declare they close the
issue, both are reported and neither is chosen — competing implementations are a
person's decision.

Absence is claimed only after a complete bounded read. A failed query, or a list
that reaches its scan bound, reports **NOT ASSESSED** rather than "none found".
Discovery is read-only and issues no mutating call.

Two questions, two authorities, deliberately kept apart:

- **Hard prerequisites** come from GitHub's **native `blocked-by` graph**. An
  issue with an open native blocker is not eligible, whatever its priority.
- **Preferred delivery order** comes from the release-readiness gate's
  **native sub-issue order**. Free-form milestone prose is never parsed — it
  explains the order, it does not define it.

**Which issue is the gate is a governed fact, not an inference.** It is the
issue carrying the `release-gate` role, and the model declares that binding
(`structure release-gate role:release-gate`) so the locator is read rather than
spelled a second time here. Parenthood does not make a gate: a milestone may
hold ordinary parents, and reading "the first open issue with sub-issues" as
the gate made an ordinary parent the delivery-order authority, decided by
whatever order GitHub returned issues in.

**And it is the same fact `spark governance` reports** — one projection, read
by both, rather than each verb working it out from whatever it happened to have
loaded. Searching the open issue list for the marker was a second
implementation of that question, and it disagreed with the first in exactly the
states that matter: a gate that has closed is absent from the open list, so a
milestone whose gate closed before its work read as a milestone that never had
one. So the gate's state decides what selection does:

| Gate state | `next` |
|---|---|
| no issue carries the role | ranks by priority and says the milestone declares no gate |
| one does, and it carries the milestone | follows that issue's sub-issue order |
| more than one, or the gate closed before its work, or open work sits outside it | refuses as **mechanically invalid** (exit 4) — the same verdict `governance` gives |
| the evidence could not be read | **not assessed** (exit 3) |

A milestone with no gate is a known state, not an unreadable one. A milestone
whose gate contradicts itself is a known *bad* state — not an unknown one, and
not one selection may proceed past: there is no ordering left to select
against, and reporting it as merely unread would suggest that looking again
might help.

Collapsing the two is what makes a backlog lie: an ordering preference encoded
as a `blocked-by` edge becomes a false blocker that fails readiness closed,
and a real prerequisite demoted to "ordering" starts work too early.

### Ranking — the authoritative order decides, not priority

**When the milestone has a release gate, that gate's sub-issue order ranks the
slate.** Priority does not override a recorded position. It ranks only the work
the order does not position — issues absent from the record, which all share the
last place — and that is the governed fallback, not a second sequencing
authority. Issue number is the final stable tiebreak.

**When the milestone has no gate there is no order to follow**, and priority
ranks the whole slate. Absence is a known, valid state rather than a fallback
from a failure.

| The milestone | Ranked by | The `reason` line says |
|---|---|---|
| has a gate, and the pick has a position | the gate's sub-issue order | `first eligible issue in the release-gate sub-issue order` |
| has a gate, and no eligible issue has a position | priority, among unpositioned work | `no eligible issue carries a recorded position` |
| has no gate | priority | `highest-priority eligible issue` |

The reason names **which authority decided**, because an operator who cannot
tell them apart cannot tell whether the recorded course was followed.

Ranking priority-first was a defect (#611). The model declares the gate's
sub-issue order the delivery-order authority *and* declares that delivery order
is never manufactured from priority (`separation order priority`); ranking
priority ahead of the order honoured neither. A `P2` recorded second was
delivered after every `P1`, so the recorded course was reported as followed
while being inverted — and the operator's only correction was to distort
`P0`-`P3` to express sequence, the exact act the model forbids.

Priority ranks by the **declaration order of the model's `priority` family** —
not by the label spelling — so a project that renames the family is ranked as it
declared it, rather than alphabetically.

**The order projects through nested containers.** The gate carries its scope
through ordinary containers of its own, so the order record is *walked*, not
listed: leaves are emitted in preorder and a container occupies the position it
sat in, its children taking the places it would have held. Wrapping existing work
in a container therefore does not renumber the work around it. Reading only the
gate's direct children left every nested leaf with no position at all, in a
hierarchy the gate validator calls valid (#611).

Parenthood is read from the sub-issue links rather than from open-issue
containment, so a **closed** container still projects its children rather than
stranding them. A hierarchy that reaches itself has no delivery order: the
projection stops rather than looping, and invents no sequence.

The gate itself is never selected — and neither is any other parent: a container
has no branch and no PR of its own, so it is never offered as work.

### Priority is optional, and optional means optional

The `priority` family is declared `exactly-one optional`. **Cardinality and
requiredness are two different facts**: `exactly-one` bounds how many labels may
be carried, `required`/`optional` says whether one must be. An issue carrying no
priority is valid, is selectable, and reports its priority as
`not recorded (optional)`.

Where a model declares the family **required**, absence is still a gap and the
diagnostic says which model rule it violates. Where the requiredness cannot be
read at all, it is **not** assumed required — absence of evidence never becomes a
gap.

Treating a missing optional priority as an uninterpretable slate was the other
half of #611: one unlabelled issue made every other issue in the milestone
unselectable, so the operator's only route to a selection was to invent a
priority — manufacturing the fact the model calls optional to satisfy a rule it
never stated.

Before selecting, the verb refuses to guess when the slate is not mechanically
interpretable. Missing or duplicated taxonomy categories, **more than one**
priority label, a priority absent where the model requires one, unreadable native
blockers, a dependency cycle, or a missing delivery-order record all report **not
assessed** (exit 3) and name the issue at fault. One uninterpretable issue stops
the whole selection: picking around it would mean choosing from a set that could
not be fully read.

**An unresolvable governance model stops the verb before it selects anything**,
with the findings and exit 3. Every judgment here depends on the model — which
labels are priorities, whether the selected issue's metadata is valid, what the
taxonomy is — so there is nothing to report and no route to print. In particular
there is no fallback priority set: a hard-coded `P0`–`P3` would be a second copy
of a rule the schema owns, taking over at exactly the moment the schema was
unusable.

Five outcomes, and the middle three matter:

| Outcome | Exit | Meaning |
|---|---|---|
| a selection | 0 | this issue is next, with the reason |
| no eligible issue | 1 | **a known answer** — every candidate is genuinely blocked, or the milestone has no open leaf |
| not assessed | 3 | the slate could not be read, **or the governance model does not resolve**; nothing is claimed and nothing is routed |
| selected but not ready | 4 | the **release gate for the milestone, or the selected issue's own execution metadata, is mechanically invalid** — no decision resolves it. Reported before the route, never routed |
| selected but awaiting a decision | 5 | an issue was selected and its metadata has a gap **only a human may fill** — reported with the admissible values, before the route, never routed |

Exit 4 is separate from exit 1 on purpose: "everything is blocked" and "this one
was chosen but contradicts itself" are different facts, and a caller has to be
able to act differently on them.

Exit 5 is separate from exit 4 for the same reason, one level up. "This metadata
is impossible" invites a fix; "this metadata is missing a judgment" invites a
question. Collapsing them is what let an autonomous run answer the question
itself in order to clear the gate. `next` prints the admissible values from the
model and stops — proposing one is allowed, persisting one to make this check
pass is the defect the stop exists to prevent. Both 4 and 5 are decided by the
same partition `spark governance validate` uses, so selection and validation
cannot disagree about which kind of gap they are looking at.

"Everything is blocked" is a determinate result and is reported as one. It is
never folded into "could not tell" — a known negative and an unknown are
different facts, and a tool that confuses them teaches its reader to distrust
both.

With no `--milestone`, the target is the open milestone with open issues whose
title sorts first by version. Without an authenticated `gh`, the verb reports
not assessed rather than guessing.

### The route

Knowing *which* issue is next is not enough if the answer is then always handed
to `codify`. After a selection, the verb names the Spark lane that owns the
work and any mandatory human gate — before anything mutates.

Two signal kinds, and they never merge:

- The **category** — the one `issue.taxonomy` label — decides the **lane**.
- **Theme** labels (`decision`, `human-approval`) decide where that lane must
  **stop**. A theme never replaces a category: `decision` on a `feature` still
  routes through the feature lane, it just cannot end in a merge without a
  human.

| Category | Lane |
|---|---|
| `bug`, `feature`, `infrastructure`, `tech-debt`, `chore` | `codify → validate → ship` |
| `documentation` | `knowledge/audit → validate → ship` |
| `research` | `ideate/knowledge → validate → ship` |

A `documentation` issue is never sent to `codify` — that skill's own contract
says it does not write documentation, so routing docs there would hand work to
a skill that refuses it. *Which* docs lane is a second question: internal
truth, audit, runbook, and ADR work belongs to `knowledge`, outward-facing
documentation belongs to `docit`, and no label distinguishes them. The verb
states the internal default and discloses the fork on an `audience` line
rather than silently guessing an audience.

`research` produces evidence and a durable record. It does **not** imply a
human-decision gate — that gate belongs to the `decision` theme. Binding it to
a category instead would collapse the two signal kinds this router exists to
keep apart.

`issue.taxonomy` is a project preference, so the lane table above is **not** a
second taxonomy. A category the project has not declared and a category it has
declared but Spark maps no lane for are different answers with different
corrections, and the verb says which one it hit.

| Theme | Effect |
|---|---|
| `decision` | The lane stops at a human decision. Spark may gather evidence, compare options, and prepare the durable record; the decision is not Spark's to make. |
| `human-approval` | Preparation, tests, rollback, and verification may proceed. The live, destructive, or credential-touching action does not, until a human authorizes it. |

Both may apply at once, and each gate is stated separately.

A category that is missing or outside the declared taxonomy is **not assessed**:
the verb names the smallest correction and refuses to guess a lane. Routing is
composition, not a new lifecycle stage — it selects among the existing skills
and owns none of their work.

## `spark profiles`

Lists the shipped setup profiles — small, flat-JSON sets of project facts
under `preferences/profiles/` — so the choice is inspectable *before* any
file is created. Each profile prints its facts with provenance against the
shipped defaults (`(the shipped default)` or `(overrides default: …)`), and a
profile whose stack has no shipped CI template is marked unsupported.

A profile is not a second configuration system: selecting one
(`spark setup --profile <name>`) just writes those facts to
`.spark/preferences.json` — the same committed file a user would write by
hand — and the ordinary three-tier resolution applies them. There is no
separate application engine to drift.

## `spark setup [--yes] [--profile <name>]`

The one-command carry-in (ADR-0012): arms the current repo in one run by
composing the three arming steps in order — `install-git-hooks`, then
`apply-permissions`, then the `preferences --apply` engine — and ending with
one aggregate line across all three steps:
`Setup: N created, N kept, N need attention.` (green only when nothing needs
attention). Skipped conflicting hooks, a declined or impossible permission
merge, and every `!` item from the standard all land in the attention count.
Each step is the same function its own verb dispatches to, so `setup` and the
granular commands cannot drift. Re-running is a no-op: hooks report as
already installed, the baseline as already applied, and the standard as kept.

Among the standard's artifacts are two repo-root docs — `CONVENTIONS.md` and
`ENGINEERING-STANDARDS.md`, the project's editable, readable working contract
(see [project-standards.md](project-standards.md)). Both are seeded create-only
and reported in the same lanes; an existing copy is the project's own and is
kept.

### What setup provisions, and what it deliberately does not

The governance model marks every surface with **who provisions it**, and `setup`
acts on exactly one of those classes:

| Class | Who acts | After `setup` |
| --- | --- | --- |
| `spark-provisions` | Spark, create-only | present, or reported as provisionable |
| `human-provisions` — issue forms, pull-request templates | a human, deliberately | **absent, and reported explicitly** |

**A freshly set-up repository therefore reports its missing issue forms and
pull-request template, and `spark governance validate` does not pass while they
are absent** — it reports `DECISION REQUIRED` (exit `5`), because only a human
provisions those surfaces. That is the intended signal, not a defect: Spark
defines and validates the *shape* of those surfaces and refuses to invent
project-specific content for them, so the honest thing it can do is name what is
still needed.

Whether an absent human-provisioned surface should carry a *row status* of its
own — distinct from both "missing" and "needs judgment" — is a separate open
question about the schema's alphabet, not settled here.

`setup` is also offline and create-only, and labels live on GitHub — so the label
families are reconciled by [`spark labels`](#spark-labels---apply---prune-deprecated)
rather than by `setup`.

`--profile <name>` commits a [setup profile](#spark-profiles)'s facts to
`.spark/preferences.json` before anything materializes, so the standard that
applies is the selected one. Selection is all-or-nothing: an unknown profile,
an unsupported combination (a stack with no shipped CI template), or a
conflict with existing committed project facts refuses the whole run with
nothing written — a repo is never partially armed against facts that were
about to be rejected. Re-running with the same profile is a no-op (`kept`),
and without `--profile` behavior is exactly the shipped defaults, unchanged.

`--yes` forwards to the permission-merge confirmation; without it, merging
into an existing `.claude/settings.json` still prompts. The exit code
distinguishes decisions from failures: operator decisions — a declined merge,
a pending LICENSE choice, a merge no available tool can perform — are
reported, counted as attention, and exit `0`; **mechanical failures** — a
file that could not be written, an uncreatable hooks directory, broken
tooling — are counted separately, the summary says the repo is not fully
armed, and the exit is non-zero. Outside a git repo, and for invalid options
or excess arguments, the exit is also non-zero. The granular verbs below
remain the supported path for partial application.

## `spark install-git-hooks`

Copies `scripts/hooks/{commit-msg,pre-commit}` into the current repo's
`.git/hooks/` and marks them executable. A hook that is already Spark's and
current is reported and left as-is; if a hook exists and is not a Spark hook,
it is left untouched and a warning is printed — move it aside first if you
want Spark's (a decision, exit `0`). The exit is non-zero on a mechanical
failure: a hook source missing from the plugin, an uncreatable hooks
directory, or a copy that could not be written.

## `spark apply-permissions [--yes] [--preset delivery|conservative]`

Merges the selected permission baseline into the current project's
`.claude/settings.json` (anchored at the git repo root when inside one).
Copies the baseline as-is when no settings file exists; otherwise lists the
missing rules and appends them only after confirmation (`--yes` skips the
prompt). Existing entries are never changed, removed, or reordered, so
re-running is a no-op once every rule is present — and switching presets never
narrows an armed repo; removing rules is always a manual act. Merging into an
existing file requires `jq` or `python3`; without either, it prints the
baseline's path for a manual merge.

Two trust tiers ship as presets:

| Preset | Baseline | Grants |
| --- | --- | --- |
| `delivery` (default) | `settings/permission-baseline.json` | The full shipping loop: read commands plus `git add`/`commit`/`push`, `gh pr create`, `spark setup`. Push access is deliberately broad because the `PreToolUse` guard blocks the disallowed subset — force-pushes and pushes to trunk — including option, refspec, and compound-command forms (see [hooks.md](hooks.md#the-permission--guard-trust-boundary)). |
| `conservative` | `settings/permission-baseline-conservative.json` | Read-only inspection: `git status`/`log`/`diff`/`show`/`rev-parse`/`fetch`, `gh` views and lists, `spark doctor`, `bash -n`. Nothing that writes the repo or GitHub runs without a per-command prompt. |

The tier resolves like every other standard — an explicit `--preset` wins,
then the three-tier `permissions.preset` preference, then the shipped default
(`delivery`). Committing `{"permissions.preset": "conservative"}` to
`.spark/preferences.json` makes a project's posture a durable, reviewable
fact; the applied `.claude/settings.json` is itself the reviewable artifact.

## `spark preferences [--show | --apply]`

The carry-in verb for the engineering standard. Bare (or with `--show`) it
prints the standard resolved across the three tiers of ADR-0010 — shipped
defaults (`preferences/defaults.json` in the plugin), operator overrides
(`~/.config/spark/preferences.json`, honoring `XDG_CONFIG_HOME`), and project
facts (`<repo>/.spark/preferences.json`) — first a header listing each tier's
path and whether it exists, then one line per key: the key, its resolved
value, and the winning source (`[default]`, `[operator]`, or `[project]`;
later tiers win). It works outside a git repo too: the project tier is
reported as absent and the standard resolves from defaults plus operator
overrides alone.

`--apply` carries the resolved standard into the current repo through the
same create-only engine `bootstrap` uses, reporting each item as `+ created`,
`= exists, kept`, or `! needs a manual decision`, with a summary line. An
existing file is a project choice and is never overwritten, so re-running is
a no-op once everything is in place; attention items are advisory and do not
fail the run. The exit is non-zero outside a git repo (no project to carry
into) and on a mechanical failure — an artifact that could not be written or
a template missing from the plugin.

Among the artifacts it carries in is a **`.gitattributes`** normalizing text
to LF, marking common binary types, and pinning shebang scripts to LF and
Windows scripts to CRLF. A repo without one has no opinion about line endings,
so the first third-party source carried in — a template, a vendored library,
anything authored on Windows — makes every `git add` emit a CRLF warning per
file and bury the output that mattered. It is create-only like everything
else: a repo that already has one has made its decision.

The machine source carries *what to apply*; the *why* stays in the prose
standard, [engineering-preferences.md](engineering-preferences.md).

## `spark resume`

Rebuilds "where you are / what's next" derive-first ([state.md](state.md)):
**Current reality** is read live — branch and tree from git, the branch's PR
and its state via `gh` when available, the problem statement's presence on
disk, and the trunk-ancestry check (commits on `origin/<trunk>` missing from
this branch are flagged, since a merged prerequisite may be among them —
reported, never silently repaired). **Recorded intent** then shows what the
state file claims — `next_action`/`blockers` with their recorded date — and
"What's next" tells you to verify the claim against the reality above. When
the current branch's PR reports `MERGED`, the loop is declared closed and a
pre-merge `next_action` is never replayed. Legacy pre-v0.16 keys found in the
file are flagged and ignored; a malformed file degrades to "no facts could be
read", never an invented answer. Exits 1 only outside a git repo. For the
three-line automatic version at session start, see `spark brief`.

## `spark brief [--short]`

Prints the session brief in three sections. **Orient** — current branch,
uncommitted-file count, ahead/behind the tracked upstream, (full mode only)
the open PR for the branch via a `gh` fast-path, skipped when `gh` is absent,
and the recorded new/existing **classification** with the date it was
established (`spark orient`, [state.md](state.md)); an unclassified repo is
reported as such with a pointer to the first-run flow rather than a guess.
Because the classification is a durable fact that can go stale, the brief
re-runs the inspect-only classifier and flags a repo recorded `new` that has
since grown real sources (now classifying `existing`) for re-orientation — a
flag only, never a silent rewrite. The live verdict alone does not trigger it:
arming a repo is what makes it look provisioned, so the flag also requires
content Spark did not create — a dependency manifest, a `docs/` tree, a CI
workflow that is not one of the two the standard seeds, or a tracked file that
is neither repository metadata nor a seeded artifact. Being armed is the
expected outcome of onboarding, not drift, and a warning that fires on every
healthy repo cannot do its job on the day the fact genuinely is stale. **Locate** — the lifecycle position,
always derived from repo shape with positional evidence first (open PR →
Validate/Ship, working branch → Codify, then problem-statement presence on
the trunk), never read from a recorded stage; the recorded
`next_action`/`blockers` are appended with their recorded date as intent to
verify (see [state.md](state.md)); `spark resume` gives the full derived
view. **Load** — the resolved standard bag summarized: how many
preference keys resolved, how many the operator or project tiers override, the
`stack.default` and `release.mechanism` headlines, and which project-local
standards docs (`CONVENTIONS.md`, `ENGINEERING-STANDARDS.md`) exist; `spark
preferences` prints the complete resolution table.

`--short` is the SessionStart hook path (see [hooks.md](hooks.md)): at most
three plain-text lines, no color codes, no network calls, plus a single
stale-orientation warning line when the recorded classification has drifted.
Outside a git repo it prints nothing and exits `0`, so non-project sessions
start clean.

## `spark state [--set key=value ...]`

Shows the committed work state at `.spark/state.json` ([schema](state.md)), or
writes it: `--set key=value` records a stage close-out (e.g. `spark state
--set next_action="codify #42"`), stamping `updated` for you. Only the two
judgment keys (`next_action`, `blockers`) are accepted — derivable facts like
stage, issue, branch, and PR are rejected with a message naming their live
source, because `brief`/`resume` derive them from git and GitHub at read time.
The file is created on first write; a write migrates a legacy-schema file to
the current key set. This is the mechanical writer the lifecycle skills call
at each stage's close-out. Exits 1 outside a git repo.

## `spark footprint [--json] [--timing] [--root <marketplace-dir>]`

Measures Spark's context footprint — the bytes each always-loaded surface
(marketplace catalog, skill descriptions, hook output) costs a session — and
reports per surface, with `--json` for the machine-readable shape. `--timing`
is the opt-in hard latency gate: it measures the hot paths (the PreToolUse
guard, `brief --short`, `doctor`, and `governance validate`) against their
budgets and exits non-zero when one is exceeded. `governance validate` is gated
because an autonomous loop calls it repeatedly, and a path nobody measures is a
path nobody notices getting slower; its budget carries deliberate headroom over
the measured figure rather than pinning today's number as a target. Doctor itself runs no timing — the aggregate context-footprint
total it reports is advisory (warn-only), and this gate is the only latency
enforcement.

`--root <dir>` measures a different checkout instead of the installed one,
treating its argument as a marketplace root and measuring every `<dir>/plugins/*/`
it finds (falling back to `<dir>` itself when there are none). It exits
non-zero if the directory does not exist. With no `--root`, the installed
marketplace is measured — or the core plugin alone when Spark is installed
standalone. The flag exists so the budget ratchet can be exercised against a
fixture layout of known sizes, which is how `tests/test-footprint.sh` and
`tests/test-footprint-budget.sh` use it; it is not needed for ordinary
reporting.

## `spark telemetry [record|show|relay|compare|list] [--run <id>] [--head <sha>] [--json] [--timing]`

Records and renders the facts of one automated run — cost, latency, tokens,
cache behaviour, tool and API counts, convergence and outcome — bound to an
exact PR HEAD SHA. It is deterministic: every value is supplied by the process
that already knew it, so producing routine telemetry never costs a model call
and never reads the network. Records live at `.spark/telemetry/<run>.tsv`.

The run a command addresses is `--run`, else `$SPARK_RUN_ID`, else `current`,
so a workflow can export the id once instead of threading it through each call.

| Action | What it does |
|---|---|
| `record key=value ...` | Merge facts into the run's record. Every pair is validated **before any is written**, so a rejected value never leaves a half-written record behind. Re-recording a field supersedes it. |
| `show` | The compact human summary; `--json` for the machine shape. |
| `relay` | A Markdown projection for the Agent Relay discussion — it links its evidence and states that it is not itself authority. |
| `compare <a> <b>` | Two runs side by side with signed deltas on every counter. |
| `list` | Every recorded run with its verdict and head SHA. |

`--timing` measures the overhead of observability itself: the median of three
`record`+`show` cycles against `TELEMETRY_OVERHEAD_MS` (default 400), exiting
non-zero when over budget, in the same spirit as `footprint --timing`.

`full_suite_runs` and `targeted_checks` have a producer: when `SPARK_RUN_ID` is
set, the repository's test runner increments one of them per invocation — the
full field for a whole run, the targeted field for a subset. **One invocation is
one execution however many summaries are read from it**, so these fields
distinguish a single run projected several ways from several actual runs, which
is the difference a convergence budget needs in order to see repeated expensive
verification for what it is.

### The field schema

`run_id`, `attempt`, `trigger`, `pr`, `head_sha`, `actions_run`; `provider`,
`model`, `routing_reason`, `effort`; `preflight_tokens`, `input_tokens`,
`output_tokens`, `cache_write_tokens`, `cache_read_tokens`, `cache_reason`,
`tool_schema_tokens`; `cost_usd`, `wall_seconds`; `tool_calls`,
`api_requests`, `full_suite_runs`, `targeted_checks`, `iterations`,
`batch_usage`; `compaction_events`, `context_before`, `context_after`;
`failing_before`, `failing_after`; `verdict`, `overhead_ms`.

`verdict` is closed: `PASS`, `CHANGES REQUIRED`, `DECISION REQUIRED`,
`NOT ASSESSED`, `FAIL`. Counters must be whole numbers and `cost_usd` decimal —
a field that cannot be measured is left **unrecorded**, never zeroed.

These are derived at read time and never stored, so they cannot go stale
against the facts they summarize:

| Derived | Rule |
|---|---|
| `cache hit ratio` | `read ÷ (read + write)`. Requires **both** halves — a ratio from one side is invention, and the field exists precisely to tell a cached loop from one rebuilding the cache. A cold run is a real `0.0%`, which is not the same answer as unknown. |
| `context change`, `failing change` | Signed deltas; `NOT ASSESSED` without both ends. |
| `repeated, no progress` | `yes` when two or more full-suite runs left the failing set unchanged — the signal a convergence budget acts on. Missing evidence reports `NOT ASSESSED`, never "fine". |
| `binding status` | `current` when the recorded `head_sha` matches the PR's live head, `superseded` when it moved, `NOT ASSESSED` when the live head could not be read. An unreadable head never resolves to `current`. |

### The observability cost contract

Observability that costs what it measures is the inefficiency it was meant to
expose. Three rules make that contract mechanical rather than advisory, and
`spark telemetry record` refuses anything that breaks them:

1. **The schema is an allowlist.** A raw prompt, transcript, hidden reasoning,
   full diff or test log has no key to live under.
2. **Values are one short line** (`TELEMETRY_MAX_VALUE`, default 200
   characters). An Actions URL fits; a pasted log does not. Deep evidence stays
   in GitHub and Actions and is linked.
3. **Credential-shaped values are refused** whatever key they claim, because
   telemetry is a surface that gets published.

Telemetry is evidence, never authority: it cannot resolve a DECISION REQUIRED
or change governance metadata. Exits 1 outside a git repo, on an unknown key or
action, on a malformed value, and on an invalid run id (the id becomes a
filename).

## `spark budget [declare|record|check|status|reopen] --run <id>`

Bounds one autonomous run. A repository can be fully deterministic and the run
inside it still unbounded — expensive certification bought again and again,
findings rediscovered rather than carried as a shrinking failing set. This makes
the boundary external and declared, and stores it at `.spark/budgets/<run>.tsv`.

The run id resolves as it does for `telemetry`: `--run`, else `$SPARK_RUN_ID`,
else `current`. The budget holds only the **bounds**; the facts it checks
against — iterations, tool calls, API requests, wall seconds, cost — come from
the `telemetry` record for the same run id. Two files, one run: what happened,
and what was permitted.

| Action | What it does |
|---|---|
| `declare --convergence <text> [--max-… <n>]` | Names what finishing means, plus an optional envelope. Required before any spend can be authorized. |
| `record --failing <n>` | Records the known failing-set size, so "is it shrinking?" is answerable without re-deriving it. |
| `check --kind full\|targeted` | Asks whether the next expensive act is permitted. |
| `status [--json]` | The envelope, the routing inputs, and the progress so far. |
| `reopen --reason <text>` | Deliberately admits new release-critical evidence to a stopped or converged run. |

Bounds available to `declare`: `--max-iterations`, `--max-full-suite`,
`--max-targeted`, `--max-tool-calls`, `--max-api-requests`,
`--max-wall-seconds`, `--max-cost-usd`, `--max-no-progress`. Routing inputs
(recorded, never treated as bounds): `--model`, `--effort`,
`--preflight-tokens`, `--per-request-output-cap`.

### The five answers

`check` returns one of five as text **and** as an exit code, so a loop reading
only the status still terminates:

| Verdict | Exit | Meaning |
|---|---|---|
| `PROCEED` | 0 | Inside the envelope, and something material changed |
| `STOP` | 2 | A hard bound was reached, or a soft one with no movement |
| `ESCALATE` | 3 | The same expensive work repeated with no material change |
| `CONVERGED` | 4 | The declared condition is met; the loop is finished |
| error | 1 | Usage — including a run that never declared convergence |

**Hard bounds** stop the run. The **soft signal** (targeted checks) behaves
differently on purpose: targeted checks are the cheap half of verification, and
a run still shrinking its failing set is doing what the contract wants, so
crossing it while converging continues with a warning. Movement is measured
against the failing set at the *last targeted check*, not the last recorded one
— otherwise a run banks one improvement and coasts on it indefinitely.

The **no-progress boundary** allows one unchanged repeat, then escalates.
Its point is that a stalled run stops *with resource budget to spare*:
convergence, not spend, ends it.

An undeclared bound is not a bound of zero — absence is simply absence, and
treating it as a limit would stop every run that declined to guess a number.

### A budget is never authority

Reaching a boundary stops work; it can never drop a blocker, mark a failing set
clean, or resolve a DECISION REQUIRED. Every stop reports the failing set it is
stopping on, and no stop can read as success.

A provider's `max_tokens` or effort class bounds **one request**; an episode is
many requests and many tool calls, so `status` prints those apart from the
envelope under "routing inputs (not budgets)".

`reopen` is announced and its reason recorded. It clears the no-progress
escalation and buys one more verification — it never clears the failing set.
New evidence admits new work; it does not absolve old findings.

## `spark evidence [put|get|preflight|status|forget] --key <name>`

Captures an authoritative fact once so several consumers can share it, with
explicit completeness bounds and invalidation by named inputs. Captures live at
`.spark/evidence/<key>.tsv` beside their payload.

```text
capture once -> project -> many consumers -> invalidate on named inputs
```

| Action | What it does |
|---|---|
| `put --key K [invalidators] [--bound n --count n]` | Stores a projection read from stdin (or `--from <file>`). A `put` over an already-fresh capture is reported as duplicate collection and reuses it; `--force` recaptures deliberately. |
| `get --key K [invalidators]` | Writes the payload to **stdout and nothing else**, so it can be piped straight into whatever needed the fact. |
| `preflight [--budget n] <file…>` | Estimates a bundle before dispatch. |
| `status [--json]` | Every capture, its consumer count, and whether it is complete. |
| `forget --key K` | Drops a capture. |

### Invalidation

Invalidators are `--head`, `--contract`, `--model`, `--effort` and `--tools`.
A capture is reusable only while every **stated** invalidator matches, and the
refusal names the one that moved:

```
STALE — the model changed (claude-opus-5 -> claude-sonnet-5)
```

An invalidator the caller does not state cannot invalidate — otherwise every
consumer would have to restate the whole fingerprint to read anything.

Exit codes: `0` fresh, `1` no such capture, `2` stale (the payload is **not**
returned — a reused capture must never make an old verdict valid), `4`
complete-but-bounded.

### Bounds and preflight

`--bound` with `--count` marks a capture that reached its limit as NOT ASSESSED
— at capture time and on every read after it. The payload is still returned,
always with the warning, because partial evidence presented as whole evidence is
how a run concludes something false cheaply.

`preflight` estimates with the same bytes-per-token heuristic as `footprint`,
exiting `2` when over `--budget` so a caller reroutes *before* generation rather
than discovering the excess after paying for it. With no `--budget` the verdict
is NOT ASSESSED, never "fits".

Every mechanism here reduces repetition, never evidence: a smaller answer that
might be wrong is not an optimization.

## `spark route [policy|select|escalate|attempt|benchmark]`

Selects the lowest-cost adequate execution class for a task, and escalates
deliberately when evidence shows the cheaper path was insufficient.

The policy is **data**: `preferences/routing-classes.tsv`, replaced wholesale by
a project's `.spark/routing-classes.tsv`. Nothing in the CLI names a provider
model — ids, effort levels, availability and prices are configuration that
changes underneath a stable semantics.

| Action | What it does |
|---|---|
| `policy [--json]` | Renders the resolved classes, task routes and escalation rules |
| `select --task <kind> [--run <id>]` | Picks the class, model and effort, and records the route in the run's telemetry |
| `escalate --run <id> --reason <text>` | Moves up exactly one rank, recording the evidence |
| `attempt --run <id> --outcome pass\|fail` | Adds the attempt to the routing ledger, taking cost and wall time from telemetry |
| `benchmark [--json]` | Cost per **completed** task per route |

Classes ship as `deterministic` (0), `routine` (1), `normal` (2), `complex` (3)
and `human` (9). Rank 9 is not a strength tier — it is where routing stops.

### The human boundary is not escalatable

`select` on a human-class task names no model and exits `5`; `escalate` refuses
both from and to that class. A DECISION REQUIRED that could be escalated into an
autonomous attempt is not a boundary. Escalation otherwise moves one rank at a
time and requires `--reason`: an unexplained escalation is just starting at the
top one step later.

### A failed cheap attempt is still spend

`benchmark` reports cost per completed task and charges the wasted attempt to
the two-stage path, so a route that is cheaper per token can be shown to be
dearer per result. A class with attempts but no successes reports NOT ASSESSED,
not zero.

### Effort is a cache invalidator

`select --run` refuses to move a run's effort mid-conversation, because the
rebuilt prefix is a cost that never appears on the line item that motivated the
change. Pass `--rebuild-cache` to accept it, or route between work units. This
is the same invalidator `evidence` tracks.

Exit codes: `0` routed, `1` usage or unknown task kind, `2` refused (effort
churn, or nothing above the strongest class), `5` human decision boundary.

## `spark ci [handoff|status|resume] --run <id>`

Records the boundary where local work is finished and only GitHub is still
changing, so a run can stop there instead of polling, and resume without
replaying the episode.

| Action | What it does |
|---|---|
| `handoff --pr <n> --head <sha>` | Records the PR, the exact certified HEAD, the required checks and their state; writes `pr`, `head_sha`, `certified_at` and `ci_state` into the run's telemetry |
| `status` | One read, compared against the recorded snapshot |
| `resume` | What to do next, from live check state |

`--head` is mandatory on `handoff`. Without it a later resume cannot tell
whether CI answered about the certified work or about something pushed since,
and a green rollup for a newer commit is not evidence about an older one.

### Verdicts

| Verdict | Exit | Meaning |
|---|---|---|
| `READY` | 0 | Every required check passed on the certified head — do not re-run local certification |
| `CHANGES REQUIRED` | 2 | CI failed; the failing set is printed from GitHub, not rediscovered by replay |
| `PENDING` | 4 | CI has not answered yet |
| `NOT ASSESSED` | 1 | The rollup could not be read |

**Pending is not a failure.** Reporting one would send someone to debug work
that is correct and merely unfinished elsewhere. **An unreadable rollup is an
unknown, never a pass** — resolving it to "nothing is failing" is how an
unchecked commit gets merged. A PR with **no checks registered** is reported
separately from one that could not be read: both refuse to become a pass, but
they send an operator to different places.

### Polling is counted, not forbidden

Every live read goes through one counted path, whichever verb asked for it —
`resume` is the default action, so a guarantee that held only for `status` would
be one nobody reached. `status` exits `3` and reports `NO TRANSITION` when the
rollup is unchanged (that read produced no new information), and both verbs keep
the poll and unchanged counts and record the read as a remote request in the
run's telemetry. A poll loop therefore appears as spend where `budget` already
watches for it, rather than needing an alarm of its own.

## Runtime layout and the extension boundary

You do not need this to *use* Spark. You need it to add to it.

```
bin/spark          the dispatcher: the verb table, and the primitives every verb
                   needs — colour, git root, JSON validity, preferences,
                   governance model resolution
lib/execution.sh   telemetry, budget, evidence, route, ci
lib/planning.sh    plan
```

**There is no build step.** `lib/*.sh` is the shipped implementation, not a
generated artifact, so source and behaviour cannot drift apart and there is
nothing to regenerate after an edit.

Executing `spark` loads only the module the chosen verb needs; **sourcing** it
loads every module, so a consumer of the runtime never has to know which file
owns which function. A module that is declared but missing or unparseable is an
error, not a quiet partial load.

With `SPARK_RUN_ID` set, each invocation records `runtime_source_bytes` and
`runtime_modules_loaded` into the run's telemetry — the source it actually read,
in bytes, and which modules. **Bytes are reported as bytes**: no token figure is
derived from them, because that is a different measurement and a constant
divisor would turn a filesystem number into a cost claim.

Two rules govern where new code goes, and both exist to stop a split from
becoming decoration:

1. **A module is earned, not declared.** It exists because a cluster of helpers
   is genuinely used by one group of verbs and nothing else — a fact the
   reference graph shows, not a directory someone thought looked tidy. A new
   verb starts in the dispatcher and moves out when its helpers cluster.
2. **One canonical implementation per fact.** A module may own a producer; it
   may never restate one. A module that copied a shared primitive so it could
   stand alone would have traded a large file for a duplication problem, which
   is the worse of the two.

## `spark repo [status|bind|handoff] [--to <owner/name>] [--yes] [--json]`

Reports the repository identity Spark's mutation authority is bound to, and
performs an explicit handoff to another repository.

Identity is built from canonical git facts — root, normalized origin locator,
HEAD and branch — so an SSH and an HTTPS remote for the same repository compare
equal, because they are one repository.

| Action | What it does |
|---|---|
| `status` | The resolved identity and the binding; exits `4` when this repository is not the bound one |
| `bind` | Records the binding for this project |
| `handoff --to <owner/name> --yes` | Rebinds authority, re-resolving root, locator, HEAD and branch afterwards |

### Discovery is not authorization

Finding a prompt's issue numbers in another repository is evidence about what
the prompt refers to. It is **not** permission to write there. The `PreToolUse`
guard resolves the repository a command would actually change — through
`git -C`, `--git-dir`, an absolute path, or `gh --repo` — and refuses a mutation
aimed at any repository other than the bound one.

It fails closed by recognising **read-only** shapes and treating everything else
as mutation-capable: a deny-list of write verbs is only as complete as its
author's imagination. Reads across repositories stay allowed, because evidence
gathering is not mutation.

`handoff` requires `--yes`. Without it the command refuses and says so —
a rebind is a human act, and its absence is what allowed the original incident.

This is an additional authority dimension, not a replacement: force-push and
trunk-push protections are unchanged.

## `spark version`

Prints the Spark plugin version, read from `.claude-plugin/plugin.json`.

## `spark help`

Prints usage.
