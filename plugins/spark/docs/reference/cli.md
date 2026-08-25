# Reference — the `spark` CLI

> Reference — information-oriented.

`bin/spark` is added to `$PATH` while the Spark plugin is active. It resolves its
own location (following symlinks), so subcommands work from any directory.

## `spark doctor`

Validates the whole marketplace and reports health. Checks:

- `.claude-plugin/plugin.json` and `marketplace.json` are valid JSON
- `hooks/hooks.json` is valid JSON and `guard-bash.sh` is executable
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
with a confidence word, and a **routing recommendation**. It writes nothing —
orientation must precede any file creation.

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
flag only, never a silent rewrite. **Locate** — the lifecycle position,
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

## `spark footprint [--json] [--timing]`

Measures Spark's context footprint — the bytes each always-loaded surface
(marketplace catalog, skill descriptions, hook output) costs a session — and
reports per surface, with `--json` for the machine-readable shape. `--timing`
is the opt-in hard latency gate: it measures the hot paths (the PreToolUse
guard, `brief --short`) against their budgets and exits non-zero when one is
exceeded. Doctor itself runs no timing — the aggregate context-footprint
total it reports is advisory (warn-only), and this gate is the only latency
enforcement.

## `spark version`

Prints the Spark plugin version, read from `.claude-plugin/plugin.json`.

## `spark help`

Prints usage.
