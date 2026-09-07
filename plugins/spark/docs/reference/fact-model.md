# Reference — the operative fact model

> Reference — information-oriented.

An **operative fact** is the smallest machine-readable statement an agent needs
in order to execute a governed work unit without reconstructing current truth
from issue history. This page defines the fact classes, the envelope every fact
is carried in, the closed status vocabulary, and the canonical identifier forms.

The machine-readable authority is `preferences/fact-model.tsv` (schema
version 1); this page renders it and is checked against it by the behavioral
suite, never the other way round. The model is **Experimental**: it is the
contract between the fact sources and their consumers, and it may still change
while the snapshot work that consumes it is validated.

Two things the model is not. It is not a second authority system: a fact says
what a source currently establishes and points at that source; it never
decides what *should* be true. And it is not a dump of GitHub: raw bodies,
timelines and prose are provenance, reached through a pointer, never carried as
values.

## Fact classes

Every governed work unit is described by one fact per class. A **snapshot** is
the complete set: every `required` class exactly once (as ESTABLISHED, UNKNOWN,
CONFLICT or NOT_APPLICABLE — never silently absent) plus any `derived` classes,
which are computed from other facts and name their inputs. Anything smaller is
a **fragment**: useful to show one situation, never consumed as a snapshot
(R11).

| Class | Canonical key | Required | Value shape when ESTABLISHED | What it answers |
|---|---|---|---|---|
| `work_unit` | `work_unit.identity` | required | `{kind: issue\|pull_request, id: <work-unit>, implements: <work-unit>\|none}` | Canonical identity of the task being executed; implements is the issue a pull request closes (GitHub's closing reference), none for an issue, so facts read from that issue are bound to this work unit by a declared relationship |
| `repository` | `repository.identity` | required | `{id: <repository>, default_branch: <ref>}` | Canonical identity of the repository the work unit belongs to |
| `placement` | `placement.current` | required | `{milestone: <milestone>\|none, release: <release>\|none, gate: <work-unit>\|none}` | Release / milestone / gate placement |
| `graph` | `graph.native` | required | `{parent: {kind: issue\|pull_request, id: <work-unit>, state: <issue-state>}\|none, children: [{kind: issue\|pull_request, id: <work-unit>, state: <issue-state>}], blocked_by: [{kind: issue\|pull_request, id: <work-unit>, state: <issue-state>}]}` | Native parent / child / dependency relationships, each with its current state (a blocker is satisfied when its state is closed); a work unit appears at most once in each list, so one relationship can never carry two states |
| `authority` | `authority.standing` | required | `{grants: [{decision: <decision-record>, target: <repository>\|<work-unit>, scopes: [<scope>]}], human_boundaries: [{decision: <decision-record>, target: <repository>\|<work-unit>, boundary: <boundary>}]}` | Standing authority: each grant and each reserved boundary names its durable decision record, the repository or work unit it applies to, and a closed token; wording lives behind provenance Every decision named inside the value is the fact's own source.identity: one authority fact carries one durable decision record; authority resting on several records is UNKNOWN in this version, its detail naming them as candidates |
| `acceptance` | `acceptance.contract` | required | `{contract: <work-unit>, head: <commit>, items: [{id: <item-id>, state: MET\|NOT_MET\|UNKNOWN}]}` | Acceptance contract identity and its satisfaction as judged on an exact HEAD; each item id is a scalar item-id, unique within the fact, so one item can never be both MET and NOT_MET |
| `head` | `head.exact` | required | `{head: <commit>, base_ref: <ref>, base: <commit>, current: true\|false}` | Exact HEAD, base and staleness of the work unit's change |
| `review` | `review.independent` | required | `{verdict: <verdict>, head: <commit>, reviewer: <login>, record: <comment>}` | Independent review verdict bound to an exact HEAD |
| `checks` | `checks.required` | required | `{head: <commit>, required: [<text>], results: [{name: <text>, state: <check-state>}]}` | Required-check state on the exact HEAD: exactly one result per required name, each in the closed check-state vocabulary |
| `next_action` | `next_action.governed` | derived | `{action: <action>, because: [<fact-key>], boundary: <boundary>\|none}` | The next governed action where it is mechanically derivable |

Each class has exactly one canonical key. `review.cached`, `review.foo` or a
second `review.*` key is not a fact of the model: a derived fact's `inputs` and
a consumer's invalidation must address one stable identity per class (R1).

Three further concerns are **facets of the envelope**, not separate facts:
provenance (`source`, `provenance`), freshness (`source.version`,
`observed_at`, `invalidators`) and certainty (`status`, `detail`).

## The envelope

Every fact, whatever its class, has exactly this shape:

| Field | Required | Meaning |
|---|---|---|
| `schema_version` | required | The schema version the fact conforms to (this file's `version`) |
| `key` | required | The class's one canonical fact key (the key records); one representation per operative fact, so inputs and invalidators address a stable identity |
| `class` | required | One of the class names above |
| `status` | required | One of the status tokens below |
| `value` | optional | Present only when status is ESTABLISHED; its shape is the class's value-shape |
| `source` | required | The source shape below: what was read, its canonical identity in the grammar of that source type, and the version identity observed |
| `observed_at` | required | ISO-8601 UTC instant the source was read |
| `invalidators` | required | Canonical invalidator tokens, each in one of the invalidator grammars and unique within the fact; a change to any one makes the fact stale |
| `provenance` | required | Pointer to the authoritative record in the provenance grammar (an https URL or a repository-relative path, no whitespace); never the record itself |
| `inputs` | optional | Fact keys this fact was derived from; required when source.type is derived |
| `inferred` | optional | The literal true, present only on a legitimately inferred fact (any other value is rejected); an inferred fact is never authority |
| `detail` | optional | The detail shape below, present only when status is UNKNOWN or CONFLICT: reason is one non-empty line, candidates is a list (possibly empty) of canonical locators — never prose or a raw record |

The two envelope objects have exact shapes, in the same grammar as a class's value
shape:

| Object | Shape |
|---|---|
| `source` | `{type: <source-type>, identity: <text>, version: <text>}` |
| `detail` | `{reason: <text>, candidates: [<locator>]}` |

Optional means *absent*. A missing `value` is the statement "no value is
established"; the model never uses `null`, `false` or `""` to mean that, so a
consumer cannot mistake absence for an affirmative empty answer. Every value
has an exact shape: only the declared keys, recursively (R14). A `body`, a
`summary` or a `conclusion` slipped into a nested object is rejected the same
way it would be at the top level.

## Status vocabulary

| Status | `value` allowed | Meaning |
|---|---|---|
| `ESTABLISHED` | yes | The source was read and yields one value |
| `UNKNOWN` | no | The source could not be read, or the fact lies outside what was observed. Never a permissive default |
| `CONFLICT` | no | Two authoritative inputs disagree, or malformed evidence sits beside valid evidence. A human or a released contract resolves it; a model never does |
| `NOT_APPLICABLE` | no | The class does not apply to this work unit (an issue has no HEAD; a repository has no milestone) |

## Canonical identifiers

One representation per identity. Everything else — a bare issue number, a
seven-char SHA, a display title, a differently-cased owner or repository name —
is a projection and is never used to compare or bind.

| Kind | Canonical form | Example |
|---|---|---|
| repository | <host>/<owner>/<name>, all lower-case (GitHub compares owner and name case-insensitively, so one spelling is the identity), no scheme, and the name never ends in .git — that is the clone URL's spelling, a projection | `github.com/acme/widgets` |
| work-unit | <repository>#<number>; a bare #<number> is a projection, never an identity | `github.com/acme/widgets#42` |
| comment | <work-unit>/comment/<comment id> | `github.com/acme/widgets#42/comment/9001` |
| milestone | <repository>/milestone/<number> | `github.com/acme/widgets/milestone/7` |
| commit | Full 40-hex lower-case object id; abbreviations are projections | `4f3d…` (40 characters) |
| ref | A branch name over Git's full ref domain, without the refs/heads/ prefix: slash-separated components, none empty or dot-led, no whitespace or ASCII control characters, no ~ ^ : ? * [ or backslash, no .. or @{, never the single name @, no component ending in .lock, never ending in / or .; refs/… and any other spelling of the same branch are projections | `master`, `release/v1.2.x`, `feat/x+y` |
| release | A release tag as published | `v0.22.0` |
| login | An actor identity; naming an actor never confers authority | `login:github-actions[bot]` — naming an actor never confers authority |
| verdict | The independent reviewer's closed vocabulary | `PASS`, `CHANGES REQUIRED`, `DECISION REQUIRED`, `NOT ASSESSED` |
| action | The closed next-action vocabulary: only actions whose derivation rule (R15) this version defines; a new action is a new version | `wait-review`, `repair`, `merge`, `stop-decision-required` |
| item-id | A scalar acceptance item id: one token, no whitespace, unique within its fact | `a1`, `acceptance/3` |
| provenance | A pointer: an https URL, or a normalized repository-relative path (slash-separated components, none empty, none . or .., no leading slash); never the record itself | `https://github.com/acme/widgets/pull/42#issuecomment-9100`, `preferences/fact-model.tsv` |
| fact-key | the class's one canonical key (the key records) | `review.independent` |
| issue-state | Current state of a related work unit; a blocked_by entry is satisfied exactly when closed | `open`, `closed` |
| check-state | Normalized state of one required check on the exact HEAD: missing = required but no run observed | `success`, `failure`, `pending`, `missing` (required but no run observed) |
| scope | What a standing grant permits; the closed scope vocabulary | `merge:routine`, `close:issue`, `metadata:labels`, `metadata:hierarchy`, `evidence:publish`, `branch:push` |
| boundary | What a human reserves; the closed boundary vocabulary | `release:approve`, `authority:grant`, `settings:repository`, `action:destructive`, `placement:release`, `semantics:product` |
| derived-version | <schema version>;<input key>@<input source.version>;… — one entry per input, sorted by key | `1;head.exact@4f3d…;review.independent@2026-09-06T11:58:00Z` |
| decision-record | A durable human decision: a <comment> locator or <repository>@<commit>; never a role, label or summary | `github.com/acme/widgets#7/comment/9001` |

## Constraints

A grammar alone cannot exclude every non-canonical spelling (`.git`, `refs/`, `..`,
`@{`, a `.lock` suffix, a `.` path component). Those exclusions are **constraint
records**: extended regular expressions with no lookaround, scoped to an identifier
kind, to every invalidator, to one invalidator kind, or to one source type's identity. A value is canonical only
when it matches its grammar *and* none of its constraints (R1). They are data, so a
consumer applies them rather than reconstructing them from prose.

| Scope | Forbidden (ERE) | Meaning |
|---|---|---|
| `repository` | `\.git$` | the name never carries the clone URL's .git suffix |
| `work-unit` | `\.git#` | the repository name inside a work-unit locator never carries .git |
| `comment` | `\.git#` | the repository name inside a comment locator never carries .git |
| `milestone` | `\.git/` | the repository name inside a milestone locator never carries .git |
| `decision-record` | `\.git(#\|@)` | the repository name inside a decision record never carries .git |
| `ref` | `^refs/` | a ref is the branch name, never the refs/ path |
| `ref` | `\.\.` | no .. anywhere in a ref |
| `ref` | `@\{` | no @{ (reflog syntax) in a ref |
| `ref` | `\.lock(/\|$)` | no component of a ref ends in .lock (Git reserves the suffix for lock files) |
| `ref` | `\.$` | a ref never ends in a dot |
| `ref` | `^@$` | the single name @ is not a branch (Git reserves it for HEAD) |
| `provenance` | `(^\|/)\.\.?(/\|$)` | a path is normalized: no . or .. components |
| `source-identity/repository-file` | `(:\|/)\.\.?(/\|$)` | the path after the commit is normalized: no . or .. components |
| `source-identity/git` | `\.git(@\|$)` | the repository name never carries .git |
| `source-identity/github-api` | `\.git(#\|/\|$)` | the repository name never carries .git |
| `source-identity/repository-file` | `\.git@` | the repository name never carries .git |
| `source-identity/human-decision` | `\.git(#\|@)` | the repository name never carries .git |
| `invalidator` | `\.git(#\|/\|$)` | the repository name inside any invalidator never carries .git |
| `invalidator/ref` | `\.\.` | the embedded ref has no .. |
| `invalidator/ref` | `@\{` | the embedded ref has no @{ |
| `invalidator/ref` | `\.lock(/\|$)` | no component of the embedded ref ends in .lock |
| `invalidator/ref` | `\.$` | the embedded ref never ends in a dot |
| `invalidator/ref` | `/@$` | the embedded ref is never the single name @ |
| `invalidator/ref` | `^ref:[a-z0-9.-]+/[a-z0-9_.-]+/[a-z0-9_.-]+/refs/` | the embedded ref is the branch name, never the refs/ path |
| `source-identity/git` | `@ref/.*\.\.` | the embedded ref has no .. |
| `source-identity/git` | `@ref/.*@\{` | the embedded ref has no @{ |
| `source-identity/git` | `@ref/.*\.lock(/\|$)` | no component of the embedded ref ends in .lock |
| `source-identity/git` | `@ref/.*\.$` | the embedded ref never ends in a dot |
| `source-identity/git` | `@ref/@$` | the embedded ref is never the single name @ |
| `source-identity/git` | `@ref/refs/` | the embedded ref is the branch name, never the refs/ path |

## Invalidators

`invalidators` names what makes a fact stale, as closed tokens — one grammar per kind,
each token at most once per fact (R16). A change to any named node invalidates the
fact; prose can never be an invalidator.

| Kind | Token form and meaning |
|---|---|
| `head` | head:<commit> — the exact HEAD a HEAD-bound fact was judged on (ESTABLISHED) or observed against (UNKNOWN, CONFLICT) |
| `pull_request` | pull_request:<work-unit> — the pull request whose metadata or head the fact was read from |
| `issue` | issue:<work-unit> — the issue whose metadata or relationships the fact was read from |
| `comment` | comment:<comment> — the comment that records the verdict or decision |
| `milestone` | milestone:<milestone> — the milestone the placement was read from |
| `repository` | repository:<repository> — the repository node (default branch, settings) |
| `ref` | ref:<repository>/<ref> — the branch whose target the fact depends on |
| `ruleset` | ruleset:<repository> — the repository's rulesets (which checks are required) |

## Reserved boundaries the model can derive a stop from

`next_action.boundary` names the reserved boundary a `stop-decision-required`
rests on, or `none`. Naming one is not enough: the authority fact must carry
that token with a target equal to the repository or work unit id, and the
evidence below must hold on the fact it names. A boundary token without a row
here has no derivation in this version — a stop on it needs a DECISION REQUIRED
verdict or a CONFLICT input, otherwise `next_action` is UNKNOWN.

| Boundary | Evidence fact | Field | Condition | Why it applies |
|---|---|---|---|---|
| `placement:release` | `placement.current` | `release` | not `none` | the work unit is placed in a release, so a routine merge would change what that release ships |

## Sources: identity grammar and version identity

`source.identity` and `source.version` are each validated against the grammar
of the source type; a role name, a label, a summary, or a word such as
`latest` can never stand as the identity or the version of a source.

| Source type | Canonical `source.identity` | `source.version` grammar |
|---|---|---|
| `github-api` | a repository, work-unit, comment or milestone locator — the node that was read | the node's `updated_at` (ISO-8601 `Z`) or its etag in a delimiter-safe form (letters, digits, `. _ : / -`; never `;` or whitespace, so it can be carried inside a derived-version); the 40-hex head only on a HEAD-bound class, where it is that fact's own HEAD — never a numeric node id, which does not change when the node does |
| `git` | `<repository>@<commit>` or `<repository>@ref/<ref>` | the 40-hex commit id observed (a ref target is recorded as the commit it pointed at) |
| `repository-file` | `<repository>@<commit>:<path>` — a normalized repository-relative path (slash-separated components, none empty, none `.` or `..`, no leading slash) | the 40-hex commit id the file was read at |
| `human-decision` | the decision record itself: a comment locator or `<repository>@<commit>` | the recording comment's `updated_at` (ISO-8601 `Z`) — a comment can be edited, so its id alone cannot version the decision — or the 40-hex commit id that records it |
| `derived` | `fact-model/<schema version>` | a `derived-version`: the schema version, then `<input key>@<that input's source.version>` for every input, sorted by key — so the version changes whenever any input's version does |

## Rules

Rendered verbatim from the `rule` records of `preferences/fact-model.tsv`; the
behavioral suite checks the two never drift.

- **R1** Canonical identifiers have one representation; labels, abbreviations
  and pretty names are projections. Each class has exactly one canonical fact
  key, so derived inputs and invalidation address a stable identity. A value is
  canonical only when it matches its grammar and none of the constraint records
  for its scope; the constraints are data, so no consumer reconstructs them from
  prose. A ref embedded in an invalidator or a git identity is held to the ref
  grammar and constraints like a bare one.
- **R2** Raw issue or comment bodies, timelines and explanatory prose are not
  fact values; a fact points at them through provenance.
- **R3** A fact states what is established now; provenance states why and how.
  The two are separate fields, never merged.
- **R4** A derived fact lists the keys of every fact that decided it and records
  each input's source.version in its own source.version, so a change to any
  input changes and invalidates the conclusion. A class declared derived always
  carries a derived source, and only a derived class does: a conclusion asserted
  from a raw read would carry no input versions and never re-version.
- **R5** Human judgment is a human-decision source with a durable record
  identity; it is never inferred from capability, membership, labels or cached
  prose. Every decision an authority value names is that fact's source.identity,
  so the envelope's provenance backs each grant and boundary the value carries.
  An authority fact is never inferred and always human-decision-sourced,
  whatever its status.
- **R6** value is present only when status is ESTABLISHED; UNKNOWN, CONFLICT and
  NOT_APPLICABLE carry no value and cannot collapse into false, null or empty.
- **R7** A HEAD-bound class (head, review, checks, acceptance) that is
  ESTABLISHED carries its HEAD in the value and lists exactly that HEAD as its
  one head: invalidator; UNKNOWN or CONFLICT in a HEAD-bound class lists exactly
  one head: invalidator, the HEAD it was observed against; NOT_APPLICABLE lists
  none, because there is no HEAD to be stale against, and is invalidated by its
  work unit. A HEAD-bound fact is stale the moment its HEAD changes.
- **R8** Two authoritative inputs that disagree are a CONFLICT with both
  candidates named; no first-write, last-write or plausibility rule resolves
  them.
- **R9** A consumer that meets an unknown schema_version, an unknown class or an
  unknown field treats the fact as UNKNOWN; it never reinterprets or ignores
  what it cannot judge.
- **R10** Nothing here is written to .spark/state.json; mutable GitHub execution
  truth is read from its source and carried in a snapshot, not stored as state.
- **R11** A snapshot carries every required class exactly once; a smaller set is
  a fragment and is never consumed as a snapshot.
- **R12** A checks fact carries exactly one result per required check name, each
  in the closed check-state vocabulary; merge is derivable only when every
  result is success.
- **R13** Authority scopes and human boundaries are closed tokens carried in
  source-backed, targeted records; explanatory wording is provenance, never a
  value a consumer must interpret.
- **R14** Every value has an exact shape: only the declared keys, recursively;
  source.identity and source.version each match the grammar of their source
  type; a grant names the repository or work unit it applies to. detail has the
  exact shape {reason, candidates} with canonical locators as candidates — each
  in a grammar and free of that grammar's constraints; acceptance item ids are
  scalar item-ids, unique within the fact; a work unit appears at most once per
  graph list. Every envelope field has the type its field record declares. Where
  a source identity embeds the commit observed — <repository>@<commit> or
  <repository>@<commit>:<path> — source.version equals it; a decision recorded
  in a comment is versioned by that comment's updated_at, never by its id. A
  github-api version that is a commit is allowed only on a HEAD-bound class and
  is that fact's HEAD; a derived identity's schema version equals the fact's
  schema_version and its derived-version prefix. Every grammar is matched
  against the whole string, and whitespace of any kind is outside every locator.
- **R15** next_action is derived, never asserted, and its inputs are exactly the
  facts its derivation consulted — nothing omitted, nothing extra — so R4
  re-versions it when any of them changes and one conclusion has one
  representation: merge only when the review is PASS on the current HEAD, every
  required check is success on it, every acceptance item is MET on it, the HEAD
  is current, a grant with scope merge:routine targets the repository or work
  unit, every blocker in the native graph is closed (the graph fact must be
  ESTABLISHED), and no reserved boundary targeting the repository or work unit
  applies — for every boundary-evidence record the fact it names is consulted,
  must be ESTABLISHED, and must not satisfy the condition (review, checks,
  acceptance, head, authority, repository, work_unit, graph and every
  boundary-evidence fact are consulted); repair only on CHANGES REQUIRED for the
  current HEAD (review, head); wait-review only when no verdict binds the
  current HEAD or a required check is pending, missing or UNKNOWN (head, review,
  checks as present); stop-decision-required only when a fact in the set is
  CONFLICT (every CONFLICT fact is consulted and nothing else), the verdict is
  DECISION REQUIRED (review consulted), or boundary names a reserved boundary
  that applies here: the authority fact is in because and carries that boundary
  token with a target equal to the repository or work unit id (authority,
  repository, work_unit consulted), and the boundary-evidence record for that
  token holds on the fact it names, which is in because. boundary is none in
  every other case; a boundary token with no boundary-evidence record has no
  derivation in this version.
- **R16** Every invalidator is a token in one of the invalidator grammars and
  appears once per fact; provenance is a pointer in the provenance grammar.
  Neither carries prose, so freshness and drill-down are machine-normalized.
- **R17** A fact's source identity is the node its value describes: work_unit
  and repository name their own id; review names its record and lists it as a
  comment: invalidator; any fact whose source is a comment lists that comment as
  a comment: invalidator, and a CONFLICT lists every comment it names as a
  candidate, so an edited record goes stale; acceptance read from GitHub names
  its contract — a work-unit node, listed once as an invalidator whatever the
  status — and within one set that contract (the value's when ESTABLISHED, the
  source node otherwise) is the work unit itself or the issue it implements; the
  work unit belongs to the set's repository; placement and graph name the
  work-unit node they were read from — within one set, the work unit itself or
  the issue it implements, never an unrelated node — and list it as an
  invalidator; head read from GitHub names a work unit and checks name a
  repository and list ruleset:<repository> — within one set, the work unit's own
  node and the repository's — except when NOT_APPLICABLE: a NOT_APPLICABLE
  HEAD-bound fact of any class (head, review, checks, acceptance) names the work
  unit it was read from and lists it as an invalidator, since with no HEAD there
  is no required check, verdict or judged contract to name. A work-unit
  invalidator has one canonical form — issue: for an issue, pull_request: for a
  pull request — and never both. A graph lists every parent, child and blocker
  whose state it represents as an invalidator of that relationship's kind; head
  lists its base as ref:<repository>/<base_ref>; checks list
  ruleset:<repository> for the repository whose rulesets require them (unless
  NOT_APPLICABLE). inputs and because list each key once. These source and
  invalidator requirements hold for every status; only the value-dependent ones
  wait for ESTABLISHED.

## Versioning

`schema_version` is the `version` record of `preferences/fact-model.tsv`.
Nothing is added, removed or changed under an existing version: any new field,
class, status token or vocabulary member, and any change to the meaning, type
or requiredness of an existing one, is a new version. A consumer therefore
rejects every field and class it does not know for the version it reads (R9
applies to the whole fact), which is exactly what the behavioral suite's
validator does, and an older consumer can never accept a snapshot it cannot
judge complete. The invalidation and
migration rules that follow from a version change belong to the freshness
contract that builds on this page.

## Examples

Each example is a JSON array of facts. Examples 1 and 9 are **complete
snapshots** (every required class exactly once — a pull request, and an issue
with no HEAD); Examples 2–8 are **fragments** that show only the classes the
situation turns on. The behavioral suite validates every
fact on this page against the machine-readable schema, enforces the
snapshot's cardinality and forbids duplicate classes within a fragment, so the
examples are fixtures, not illustrations. The repository, numbers and ids are
invented; the situations are the ones a governed work unit actually meets.

### Example 1 — a normal pull request (complete snapshot)

The pull request `github.com/acme/widgets#42` implements the issue
`github.com/acme/widgets#41` (its closing reference), which is why the
placement, graph and acceptance facts are read from that issue: the work unit
declares the relationship in `implements`, and R17 binds those reads to it.

The straightforward case: every required class is ESTABLISHED, and the next
action follows mechanically from named inputs.

```json
[
  {"schema_version": "1", "key": "work_unit.identity", "class": "work_unit", "status": "ESTABLISHED",
   "value": {"kind": "pull_request", "id": "github.com/acme/widgets#42", "implements": "github.com/acme/widgets#41"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "2026-09-06T12:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["pull_request:github.com/acme/widgets#42"],
   "provenance": "https://github.com/acme/widgets/pull/42"},
  {"schema_version": "1", "key": "repository.identity", "class": "repository", "status": "ESTABLISHED",
   "value": {"id": "github.com/acme/widgets", "default_branch": "master"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "2026-09-01T08:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["repository:github.com/acme/widgets"],
   "provenance": "https://github.com/acme/widgets"},
  {"schema_version": "1", "key": "placement.current", "class": "placement", "status": "ESTABLISHED",
   "value": {"milestone": "github.com/acme/widgets/milestone/7", "release": "none", "gate": "github.com/acme/widgets#40"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "milestone:github.com/acme/widgets/milestone/7"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "graph.native", "class": "graph", "status": "ESTABLISHED",
   "value": {"parent": {"kind": "issue", "id": "github.com/acme/widgets#40", "state": "open"}, "children": [], "blocked_by": [{"kind": "issue", "id": "github.com/acme/widgets#39", "state": "closed"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/widgets#40", "issue:github.com/acme/widgets#39"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine", "close:issue"]}],
             "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "authority:grant"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "action:destructive"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "2026-09-01T09:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001"],
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"},
  {"schema_version": "1", "key": "acceptance.contract", "class": "acceptance", "status": "ESTABLISHED",
   "value": {"contract": "github.com/acme/widgets#41", "head": "0123456789abcdef0123456789abcdef01234567", "items": [{"id": "a1", "state": "MET"}, {"id": "a2", "state": "MET"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "head:0123456789abcdef0123456789abcdef01234567"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "ESTABLISHED",
   "value": {"head": "0123456789abcdef0123456789abcdef01234567", "base_ref": "master", "base": "89abcdef0123456789abcdef0123456789abcdef", "current": true},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "0123456789abcdef0123456789abcdef01234567"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567", "ref:github.com/acme/widgets/master"],
   "provenance": "https://github.com/acme/widgets/pull/42/commits"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "ESTABLISHED",
   "value": {"verdict": "PASS", "head": "0123456789abcdef0123456789abcdef01234567", "reviewer": "login:github-actions[bot]", "record": "github.com/acme/widgets#42/comment/9100"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42/comment/9100", "version": "2026-09-06T11:58:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567", "comment:github.com/acme/widgets#42/comment/9100"],
   "provenance": "https://github.com/acme/widgets/pull/42#issuecomment-9100"},
  {"schema_version": "1", "key": "checks.required", "class": "checks", "status": "ESTABLISHED",
   "value": {"head": "0123456789abcdef0123456789abcdef01234567", "required": ["doctor", "tests"], "results": [{"name": "doctor", "state": "success"}, {"name": "tests", "state": "success"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "0123456789abcdef0123456789abcdef01234567"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567", "ruleset:github.com/acme/widgets"],
   "provenance": "https://github.com/acme/widgets/commit/0123456789abcdef0123456789abcdef01234567/checks"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "merge", "because": ["review.independent", "checks.required", "head.exact", "authority.standing", "acceptance.contract"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;acceptance.contract@2026-09-05T18:00:00Z;authority.standing@2026-09-01T09:00:00Z;checks.required@0123456789abcdef0123456789abcdef01234567;graph.native@2026-09-05T18:00:00Z;head.exact@0123456789abcdef0123456789abcdef01234567;placement.current@2026-09-05T18:00:00Z;repository.identity@2026-09-01T08:00:00Z;review.independent@2026-09-06T11:58:00Z;work_unit.identity@2026-09-06T12:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567"],
   "provenance": "preferences/fact-model.tsv",
   "inputs": ["review.independent", "checks.required", "head.exact", "authority.standing", "acceptance.contract", "repository.identity", "work_unit.identity", "placement.current", "graph.native"]}
]
```

### Example 2 — exact-HEAD review, acceptance and check state (fragment)

The three HEAD-bound classes share one invalidator, the HEAD they were
observed on. Nothing here can be reused for another HEAD.

```json
[
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "ESTABLISHED",
   "value": {"head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "base_ref": "master", "base": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "current": true},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "ref:github.com/acme/widgets/master"],
   "provenance": "https://github.com/acme/widgets/pull/42/commits"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "ESTABLISHED",
   "value": {"verdict": "CHANGES REQUIRED", "head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "reviewer": "login:github-actions[bot]", "record": "github.com/acme/widgets#42/comment/9200"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42/comment/9200", "version": "2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "comment:github.com/acme/widgets#42/comment/9200"],
   "provenance": "https://github.com/acme/widgets/pull/42#issuecomment-9200"},
  {"schema_version": "1", "key": "checks.required", "class": "checks", "status": "ESTABLISHED",
   "value": {"head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "required": ["doctor", "tests"], "results": [{"name": "doctor", "state": "success"}, {"name": "tests", "state": "pending"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "ruleset:github.com/acme/widgets"],
   "provenance": "https://github.com/acme/widgets/commit/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/checks"},
  {"schema_version": "1", "key": "acceptance.contract", "class": "acceptance", "status": "ESTABLISHED",
   "value": {"contract": "github.com/acme/widgets#41", "head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "items": [{"id": "a1", "state": "MET"}, {"id": "a2", "state": "NOT_MET"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41", "head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "repair", "because": ["review.independent"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;head.exact@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;review.independent@2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "provenance": "preferences/fact-model.tsv", "inputs": ["review.independent", "head.exact"]}
]
```

### Example 3 — a stale HEAD invalidates only HEAD-bound facts (fragment)

A new push moved the HEAD. The head fact records the new HEAD as current; the
review still names the old HEAD it judged, so it is a true statement about that
HEAD but no longer a review of the work unit's current change, and the derived
action is to wait for a fresh one. Repository, placement and graph facts carry
no HEAD invalidator and remain established.

```json
[
  {"schema_version": "1", "key": "repository.identity", "class": "repository", "status": "ESTABLISHED",
   "value": {"id": "github.com/acme/widgets", "default_branch": "master"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "2026-09-01T08:00:00Z"},
   "observed_at": "2026-09-06T14:00:00Z", "invalidators": ["repository:github.com/acme/widgets"],
   "provenance": "https://github.com/acme/widgets"},
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "ESTABLISHED",
   "value": {"head": "cccccccccccccccccccccccccccccccccccccccc", "base_ref": "master", "base": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "current": true},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "cccccccccccccccccccccccccccccccccccccccc"},
   "observed_at": "2026-09-06T14:00:00Z", "invalidators": ["head:cccccccccccccccccccccccccccccccccccccccc", "ref:github.com/acme/widgets/master"],
   "provenance": "https://github.com/acme/widgets/pull/42/commits"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "ESTABLISHED",
   "value": {"verdict": "CHANGES REQUIRED", "head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "reviewer": "login:github-actions[bot]", "record": "github.com/acme/widgets#42/comment/9200"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42/comment/9200", "version": "2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T14:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "comment:github.com/acme/widgets#42/comment/9200"],
   "provenance": "https://github.com/acme/widgets/pull/42#issuecomment-9200"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "wait-review", "because": ["head.exact", "review.independent"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;head.exact@cccccccccccccccccccccccccccccccccccccccc;review.independent@2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T14:00:00Z", "invalidators": ["head:cccccccccccccccccccccccccccccccccccccccc"],
   "provenance": "preferences/fact-model.tsv", "inputs": ["head.exact", "review.independent"]}
]
```

### Example 4 — conflicting authoritative evidence (fragment)

Two markers for the same HEAD disagree, and both come from a source the
contract trusts. The fact is a CONFLICT that names both candidates; it carries
no value, and the derived next action stops for a decision rather than picking
the newer or the more plausible one.

```json
[
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "CONFLICT",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "dddddddddddddddddddddddddddddddddddddddd"},
   "observed_at": "2026-09-06T15:00:00Z", "invalidators": ["head:dddddddddddddddddddddddddddddddddddddddd", "comment:github.com/acme/widgets#42/comment/9300", "comment:github.com/acme/widgets#42/comment/9301"],
   "provenance": "https://github.com/acme/widgets/pull/42",
   "detail": {"reason": "two trusted verdict records for the same HEAD disagree", "candidates": ["github.com/acme/widgets#42/comment/9300", "github.com/acme/widgets#42/comment/9301"]}},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "stop-decision-required", "because": ["review.independent"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;review.independent@dddddddddddddddddddddddddddddddddddddddd"},
   "observed_at": "2026-09-06T15:00:00Z", "invalidators": ["head:dddddddddddddddddddddddddddddddddddddddd"],
   "provenance": "preferences/fact-model.tsv", "inputs": ["review.independent"]}
]
```

### Example 5 — a cross-repository parent (fragment)

The work unit lives in one repository and its parent in another. Because every
work-unit identity is fully qualified, the two never compare equal on a bare
number, and the grant's `target` says mechanically which repository it applies
to — a grant recorded in the parent's repository would carry that repository as
its target and confer nothing here, without anyone reading the decision record.

```json
[
  {"schema_version": "1", "key": "work_unit.identity", "class": "work_unit", "status": "ESTABLISHED",
   "value": {"kind": "pull_request", "id": "github.com/acme/widgets#42", "implements": "github.com/acme/widgets#41"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "2026-09-06T16:00:00Z"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["pull_request:github.com/acme/widgets#42"],
   "provenance": "https://github.com/acme/widgets/pull/42"},
  {"schema_version": "1", "key": "graph.native", "class": "graph", "status": "ESTABLISHED",
   "value": {"parent": {"kind": "issue", "id": "github.com/acme/program#42", "state": "open"}, "children": [], "blocked_by": [{"kind": "issue", "id": "github.com/acme/widgets#39", "state": "open"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-06T15:30:00Z"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/program#42", "issue:github.com/acme/widgets#39"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine"]}],
             "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "authority:grant"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "2026-09-01T09:00:00Z"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001"],
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"}
]
```

### Example 6 — a reserved human boundary (fragment)

Every mechanical condition holds, but the work unit is placed in release
`v1.2.0`, and the standing decision reserves release placement for a human. The
derived action stops and names the boundary it rests on; nothing infers
permission from the actor's role or from the fact that the merge is technically
possible. Naming a boundary is not enough: the authority fact must carry that
token with a target equal to this repository or work unit — so a boundary
recorded for another repository reserves nothing here — and the boundary's
evidence row must hold on the fact it names (`placement.current.release` is not
`none`). The `repository` and `work_unit` facts are therefore inputs of the
derivation, and it re-versions if any of them changes.

```json
[
  {"schema_version": "1", "key": "work_unit.identity", "class": "work_unit", "status": "ESTABLISHED",
   "value": {"kind": "pull_request", "id": "github.com/acme/widgets#43", "implements": "none"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#43", "version": "2026-09-06T16:50:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["pull_request:github.com/acme/widgets#43"],
   "provenance": "https://github.com/acme/widgets/pull/43"},
  {"schema_version": "1", "key": "repository.identity", "class": "repository", "status": "ESTABLISHED",
   "value": {"id": "github.com/acme/widgets", "default_branch": "master"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "2026-09-01T08:00:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["repository:github.com/acme/widgets"],
   "provenance": "https://github.com/acme/widgets"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine"]}], "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "placement:release"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "settings:repository"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "2026-09-01T09:00:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001"],
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"},
  {"schema_version": "1", "key": "placement.current", "class": "placement", "status": "ESTABLISHED",
   "value": {"milestone": "github.com/acme/widgets/milestone/8", "release": "v1.2.0", "gate": "none"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#43", "version": "2026-09-06T16:50:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["pull_request:github.com/acme/widgets#43", "milestone:github.com/acme/widgets/milestone/8"],
   "provenance": "https://github.com/acme/widgets/pull/43"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "stop-decision-required", "because": ["authority.standing", "placement.current", "repository.identity", "work_unit.identity"], "boundary": "placement:release"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;authority.standing@2026-09-01T09:00:00Z;placement.current@2026-09-06T16:50:00Z;repository.identity@2026-09-01T08:00:00Z;work_unit.identity@2026-09-06T16:50:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001", "pull_request:github.com/acme/widgets#43", "milestone:github.com/acme/widgets/milestone/8", "repository:github.com/acme/widgets"],
   "provenance": "preferences/fact-model.tsv",
   "inputs": ["authority.standing", "placement.current", "repository.identity", "work_unit.identity"]}
]
```

### Example 7 — a fact that is UNKNOWN because the source cannot be read (fragment)

The required-check source answered with a permission error. The fact is
UNKNOWN with the reason recorded; it carries no value, so nothing downstream
can read "no failing checks" into it, and the derived action waits instead of
merging.

```json
[
  {"schema_version": "1", "key": "checks.required", "class": "checks", "status": "UNKNOWN",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"},
   "observed_at": "2026-09-06T18:00:00Z", "invalidators": ["head:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "ruleset:github.com/acme/widgets"],
   "provenance": "https://github.com/acme/widgets/commit/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee/checks",
   "detail": {"reason": "check-runs endpoint returned HTTP 403 for the observing identity", "candidates": []}},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "wait-review", "because": ["checks.required"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;checks.required@eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"},
   "observed_at": "2026-09-06T18:00:00Z", "invalidators": ["head:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"],
   "provenance": "preferences/fact-model.tsv", "inputs": ["checks.required"]}
]
```

### Example 8 — a work unit with no HEAD (fragment)

The work unit is an issue: there is no branch, no HEAD, and so nothing for a
review or a check run to bind to. The HEAD-bound classes are NOT_APPLICABLE —
an explicit status, never an absent fact and never an invented HEAD. Because
there is no HEAD to be stale against, these facts carry no `head:` invalidator;
they are invalidated by the issue itself (a pull request opened for it makes
them applicable again) (R7).

```json
[
  {"schema_version": "1", "key": "work_unit.identity", "class": "work_unit", "status": "ESTABLISHED",
   "value": {"kind": "issue", "id": "github.com/acme/widgets#41", "implements": "none"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "provenance": "https://github.com/acme/widgets/issues/41"}
]
```

### Example 9 — an issue with no HEAD (complete snapshot)

The complete snapshot of an issue that no pull request implements yet. Every
HEAD-bound class is NOT_APPLICABLE and is read from — and invalidated by — the
issue itself, `checks` included: with no HEAD there is no required check to name,
so the repository-and-ruleset form belongs only to a fact that has one (R7,
R17). The derived action is UNKNOWN, with its reason recorded, because this
version defines no derivation for a work unit without a HEAD; a pull request
opened for the issue makes every one of these facts applicable again.

```json
[
  {"schema_version": "1", "key": "work_unit.identity", "class": "work_unit", "status": "ESTABLISHED",
   "value": {"kind": "issue", "id": "github.com/acme/widgets#41", "implements": "none"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "repository.identity", "class": "repository", "status": "ESTABLISHED",
   "value": {"id": "github.com/acme/widgets", "default_branch": "master"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "2026-09-01T08:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["repository:github.com/acme/widgets"],
   "provenance": "https://github.com/acme/widgets"},
  {"schema_version": "1", "key": "placement.current", "class": "placement", "status": "ESTABLISHED",
   "value": {"milestone": "github.com/acme/widgets/milestone/7", "release": "none", "gate": "github.com/acme/widgets#40"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41", "milestone:github.com/acme/widgets/milestone/7"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "graph.native", "class": "graph", "status": "ESTABLISHED",
   "value": {"parent": {"kind": "issue", "id": "github.com/acme/widgets#40", "state": "open"}, "children": [], "blocked_by": [{"kind": "issue", "id": "github.com/acme/widgets#39", "state": "closed"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/widgets#40", "issue:github.com/acme/widgets#39"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine"]}], "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "2026-09-01T09:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001"],
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"},
  {"schema_version": "1", "key": "acceptance.contract", "class": "acceptance", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "checks.required", "class": "checks", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "UNKNOWN",
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;head.exact@2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "provenance": "preferences/fact-model.tsv",
   "inputs": ["head.exact"],
   "detail": {"reason": "no next action is derivable for a work unit without a HEAD in this version", "candidates": []}}
]
```

## What is deliberately not a fact

- The text of an issue, a comment or a review. A fact carries a pointer to it.
- The order in which things happened. Chronology is provenance, and Git and
  GitHub already hold it.
- Anything a model summarised. A summary can be an *inferred* fact at most,
  and an inferred fact is never authority.
- Anything about who *could* do something. Capability is not authority; only
  a `human-decision` source establishes a grant.

## Relationship to other contracts

The work state file keeps its two judgment values and nothing else
([state.md](state.md)); this model reads execution truth from its sources and
never mirrors it there. The governance model
([metadata-governance.md](metadata-governance.md)) defines which label
families and structures a repository may carry; a `placement` or `graph` fact
reports what the repository currently has under that model. The freshness,
invalidation and conflict contract that builds on this envelope is documented
separately when it lands.
