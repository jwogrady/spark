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
same applies to a class's governed paths.

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

#### `validate` — fails closed

Exits `1` when any `!` row is present, `3` when a surface could not be read, `0`
only when every required invariant holds. **It never reports PASS from a surface
it could not read**, and when a real finding coexists with an unread surface it
says both — a definite finding still fails, but the report admits the picture is
partial.

What counts as *required* is the schema's own `requirement` field, not a list in
the code. Adding a governed family as data brings it under validation with no
code change.

#### "Active execution issues"

A **required** family is demanded of work that has a release decision — a
milestone, or an explicit `backlog`. An issue nobody has scheduled has not been
planned yet, and demanding its documentation disposition before anyone decided
the work happens would report every idea as a defect.

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
combining it with any other value is invalid, not merely odd. A family may
declare **at most one** exclusive member: a consumer can act on only one, so a
second would validate and then be silently ignored, accepting a combination the
schema appears to forbid.

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

`--branch` unions rather than judging the branch alone because the evidence set
is **per issue, not per branch** — the documentation for an issue may already
have merged in an earlier PR while this branch carries only code. When that
lookup cannot be performed the verb says so, rather than reporting a FAIL the
agent has no way to satisfy.

Paths come from the **paginated** REST files endpoint, not `gh pr view --json
files`, which stops at 100 files without saying so — a documentation change at
position 140 of a 150-file PR was invisible and the verdict came back PASS.
Renames contribute **both** paths: a doc moved out of a governed tree reports
only its destination otherwise, so the tree it left would look untouched.

Without `--issue`, the number comes from the branch name (`feat/483-slug`), the
convention `codify` creates.

**NOT ASSESSED** covers: no issue number resolvable, no authenticated `gh`, an
unreadable issue, no linked implementation PR yet, an unresolvable diff or
evidence file, and an unresolvable governance model. None of them is ever
reported as a pass.

### Where it runs

```text
plan      → the issue declares its docs-impact
codify
validate  → spark docs-impact --branch, so the signal precedes the PR
PR        → merge
```

`--tsv` prints the same result as stable records (`issue`, `declared`,
`evidence`, `governed`, `verdict`) for CI and skills.

## `spark next [--milestone <title>]`

Names the one next eligible issue in a milestone, derived entirely from live
GitHub metadata, and explains why it was chosen. Read-only: it changes no
label, milestone, priority, dependency, issue state, or branch.

Two questions, two authorities, deliberately kept apart:

- **Hard prerequisites** come from GitHub's **native `blocked-by` graph**. An
  issue with an open native blocker is not eligible, whatever its priority.
- **Preferred delivery order** comes from the release-readiness gate's
  **native sub-issue order**. Free-form milestone prose is never parsed — it
  explains the order, it does not define it.

Collapsing the two is what makes a backlog lie: an ordering preference encoded
as a `blocked-by` edge becomes a false blocker that fails readiness closed,
and a real prerequisite demoted to "ordering" starts work too early.

Ranking is priority (`P0`→`P3`), then the explicit sub-issue order, then issue
number as a documented stable fallback. The gate itself is never selected — a
parent is a container and closes last.

Before selecting, the verb refuses to guess when the slate is not mechanically
interpretable. Missing or duplicated taxonomy categories, missing or duplicated
`P0`–`P3` labels, unreadable native blockers, a dependency cycle, or a missing
delivery-order record all report **not assessed** (exit 3) and name the issue
at fault. One uninterpretable issue stops the whole selection: picking around
it would mean choosing from a set that could not be fully read.

Three outcomes, and the middle one matters:

| Outcome | Exit | Meaning |
|---|---|---|
| a selection | 0 | this issue is next, with the reason |
| no eligible issue | 1 | **a known answer** — every candidate is genuinely blocked, or the milestone has no open leaf |
| not assessed | 3 | the slate could not be read; nothing is claimed |

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
guard, `brief --short`) against their budgets and exits non-zero when one is
exceeded. Doctor itself runs no timing — the aggregate context-footprint
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

## `spark version`

Prints the Spark plugin version, read from `.claude-plugin/plugin.json`.

## `spark help`

Prints usage.
