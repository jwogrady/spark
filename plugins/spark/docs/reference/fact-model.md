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
| `work_unit` | `work_unit.identity` | required | `{kind: issue\|pull_request, id: <work-unit>}` | Which task is being executed |
| `repository` | `repository.identity` | required | `{id: <repository>, default_branch: <ref>}` | Which repository owns it |
| `placement` | `placement.current` | required | `{milestone: <milestone>\|none, release: <release>\|none, gate: <work-unit>\|none}` | Where it sits in release, milestone and gate |
| `graph` | `graph.native` | required | `{parent: {id: <work-unit>, state: <issue-state>}\|none, children: [{id, state}], blocked_by: [{id, state}]}` | Its native parent, children and dependencies, each with its current state; a blocker is satisfied exactly when its state is `closed`; a work unit appears at most once per list |
| `authority` | `authority.standing` | required | `{grants: [{decision: <decision-record>, target: <repository>\|<work-unit>, scopes: [<scope>]}], human_boundaries: [{decision: <decision-record>, target: <repository>\|<work-unit>, boundary: <boundary>}]}` | Each grant and each reserved boundary names its durable decision record, the repository or work unit it applies to, and a closed token; the wording lives behind `provenance`; every `decision` inside the value is the fact's own `source.identity` (R5) |
| `acceptance` | `acceptance.contract` | required | `{contract: <work-unit>, head: <commit>, items: [{id: <item-id>, state: MET\|NOT_MET\|UNKNOWN}]}` | Which acceptance contract governs and how far it is satisfied, as judged on an exact HEAD; each item id is a scalar `item-id`, unique within the fact |
| `head` | `head.exact` | required | `{head: <commit>, base_ref: <ref>, base: <commit>, current: true\|false}` | The exact HEAD and base, and whether the HEAD is still current |
| `review` | `review.independent` | required | `{verdict: <verdict>, head: <commit>, reviewer: <login>, record: <comment>}` | The independent verdict, bound to the HEAD it judged |
| `checks` | `checks.required` | required | `{head: <commit>, required: [<text>], results: [{name, state: <check-state>}]}` | Required-check state on that exact HEAD: exactly one result per required name (R12); `merge` is derivable only when every state is `success` |
| `next_action` | `next_action.governed` | derived | `{action: <action>, because: [<fact-key>], boundary: <boundary>\|none}` | The next governed action, where it follows mechanically |

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
| `schema_version` | required | The schema version the fact conforms to (`"1"`) |
| `key` | required | the class's one canonical key (class table) — one representation per operative fact |
| `class` | required | One of the class names above |
| `status` | required | One of the four status tokens below |
| `value` | only when ESTABLISHED | The class's value shape |
| `source` | required | `{type, identity, version}` — what was read, its canonical identity in the grammar of that source type (below), and the version identity observed |
| `observed_at` | required | ISO-8601 UTC instant of the read |
| `invalidators` | required | Canonical tokens; a change to any one makes the fact stale |
| `provenance` | required | A pointer to the authoritative record, never the record itself |
| `inputs` | when derived | The keys of the facts this one was computed from |
| `inferred` | optional | the literal `true`, present only on a legitimately inferred fact — `false`, `"true"` or any other value is rejected; an inferred fact is never authority |
| `detail` | optional | Exact shape `{reason, candidates}`, present only when `status` is UNKNOWN or CONFLICT: `reason` is one non-empty line; `candidates` is a list (possibly empty) of canonical locators — a repository, work unit, comment, milestone or commit identifier, or a source identity in its grammar — never prose or a raw record |

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
seven-char SHA, a display title — is a projection and is never used to compare
or bind.

| Kind | Canonical form | Example |
|---|---|---|
| repository | `<host>/<owner>/<name>`, lower-case host, no scheme, no `.git` | `github.com/acme/widgets` |
| work-unit | `<repository>#<number>` | `github.com/acme/widgets#42` |
| comment | `<work-unit>/comment/<comment id>` | `github.com/acme/widgets#42/comment/9001` |
| milestone | `<repository>/milestone/<number>` | `github.com/acme/widgets/milestone/7` |
| commit | full 40-hex lower-case object id | `4f3d…` (40 characters) |
| ref | git ref name without `refs/heads/` | `master` |
| release | the tag as published | `v0.22.0` |
| login | `login:<name>` | `login:github-actions[bot]` — naming an actor never confers authority |
| verdict | the reviewer's closed vocabulary | `PASS`, `CHANGES REQUIRED`, `DECISION REQUIRED`, `NOT ASSESSED` |
| action | the closed next-action vocabulary — only actions this version can derive (R15); a new action is a new version | `wait-review`, `repair`, `merge`, `stop-decision-required` |
| item-id | a scalar acceptance item id: one token, no whitespace, unique within its fact | `a1`, `acceptance/3` |
| fact-key | the class's one canonical key (class table) | `review.independent` |
| issue-state | current state of a related work unit | `open`, `closed` |
| check-state | normalized state of one required check | `success`, `failure`, `pending`, `missing` (required but no run observed) |
| scope | what a standing grant permits | `merge:routine`, `close:issue`, `metadata:labels`, `metadata:hierarchy`, `evidence:publish`, `branch:push` |
| boundary | what a human reserves | `release:approve`, `authority:grant`, `settings:repository`, `action:destructive`, `placement:release`, `semantics:product` |
| decision-record | a durable human decision: a comment locator or `<repository>@<commit>` | `github.com/acme/widgets#7/comment/9001` |
| derived-version | `<schema version>;<input key>@<input source.version>;…`, one entry per input, sorted by key | `1;head.exact@4f3d…;review.independent@2026-09-06T11:58:00Z` |

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
| `github-api` | a repository, work-unit, comment or milestone locator — the node that was read | the node's `updated_at` (ISO-8601 `Z`), the 40-hex head it is keyed by, its numeric id, or its etag |
| `git` | `<repository>@<commit>` or `<repository>@ref/<ref>` | the 40-hex commit id observed (a ref target is recorded as the commit it pointed at) |
| `repository-file` | `<repository>@<commit>:<path>` | the 40-hex commit id the file was read at |
| `human-decision` | the decision record itself: a comment locator or `<repository>@<commit>` | the numeric comment id or the 40-hex commit id that records the decision |
| `derived` | `fact-model/<schema version>` | a `derived-version`: the schema version, then `<input key>@<that input's source.version>` for every input, sorted by key — so the version changes whenever any input's version does |

## Rules

- **R1** Canonical identifiers have one representation; labels, abbreviations
  and pretty names are projections. Each class has exactly one canonical fact
  key, so derived inputs and invalidation address a stable identity.
- **R2** Raw issue or comment bodies, timelines and explanatory prose are not
  fact values; a fact points at them through `provenance`.
- **R3** A fact states what is established now; provenance states why and how.
  Separate fields, never merged.
- **R4** A derived fact lists every fact key that decided it and records each
  input's `source.version` in its own `source.version`, so a change to any input
  changes and invalidates the conclusion.
- **R5** Human judgment is a `human-decision` source with a durable record
  identity. It is never inferred from capability, membership, labels or cached
  prose. Every `decision` an authority value names is that fact's own
  `source.identity`, so the envelope's provenance backs each grant and boundary
  the value carries; authority resting on several records is UNKNOWN in this
  version, its `detail` naming them as candidates.
- **R6** `value` is present only when `status` is ESTABLISHED. UNKNOWN,
  CONFLICT and NOT_APPLICABLE carry no value and cannot collapse into `false`,
  `null` or empty.
- **R7** A fact bound to a HEAD (`head`, `review`, `checks`, `acceptance`)
  carries that HEAD in its value and lists exactly that HEAD as a `head:`
  invalidator; it is stale the moment the HEAD changes.
- **R8** Two authoritative inputs that disagree are a CONFLICT naming both
  candidates; no first-write, last-write or plausibility rule resolves them.
- **R9** A consumer that meets an unknown `schema_version`, an unknown class or
  an unknown field treats the fact as UNKNOWN; it never reinterprets or ignores
  what it cannot judge.
- **R10** Nothing in this model is written to `.spark/state.json`. Mutable
  GitHub execution truth is read from its source and carried in a snapshot;
  the state file keeps holding only the two judgment values it holds today
  (see [state.md](state.md)).
- **R11** A snapshot carries every required class exactly once; a smaller set
  is a fragment and is never consumed as a snapshot.
- **R12** A `checks` fact carries exactly one result per required check name,
  each in the closed check-state vocabulary; `merge` is derivable only when
  every result is `success`.
- **R13** Authority scopes and human boundaries are closed tokens carried in
  source-backed, targeted records; explanatory wording is provenance, never a
  value a consumer must interpret.
- **R14** Every value has an exact shape: only the declared keys, recursively;
  `source.identity` and `source.version` each match the grammar of their source
  type; a grant names the repository or work unit it applies to. `detail` has
  the exact shape `{reason, candidates}` with canonical locators as candidates;
  acceptance item ids are scalar `item-id`s, unique within the fact; a work unit
  appears at most once per graph list.
- **R15** `next_action` is derived, never asserted, and every fact its
  derivation consulted is in its `inputs`, so R4 re-versions it when any of
  them changes. `merge` only when the review is PASS on the current HEAD, every
  required check is `success` on it, every acceptance item is MET on it, the
  HEAD is current, and a grant with scope `merge:routine` targets the repository
  or work unit (consults `review`, `checks`, `acceptance`, `head`, `authority`,
  `repository`, `work_unit`); `repair` only on CHANGES REQUIRED for the current
  HEAD (`review`, `head`); `wait-review` only when no verdict binds the current
  HEAD or a required check is pending, missing or UNKNOWN (`head`, `review`,
  `checks` as present); `stop-decision-required` only when an input is
  CONFLICT, the verdict is DECISION REQUIRED, or `boundary` names a reserved
  boundary that applies here: the authority fact is in `because` and carries
  that token with a target equal to the repository or work unit id (`authority`,
  `repository`, `work_unit`), and the boundary's evidence row holds on the fact
  it names, which is in `because`. `boundary` is `none` in every other case,
  and a token with no evidence row has no derivation in this version. The
  behavioral suite checks these conditions and the input coverage against every
  example.

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

Each example is a JSON array of facts. Example 1 is a **complete snapshot**
(every required class exactly once); Examples 2–7 are **fragments** that show
only the classes the situation turns on. The behavioral suite validates every
fact on this page against the machine-readable schema, enforces the
snapshot's cardinality and forbids duplicate classes within a fragment, so the
examples are fixtures, not illustrations. The repository, numbers and ids are
invented; the situations are the ones a governed work unit actually meets.

### Example 1 — a normal pull request (complete snapshot)

The straightforward case: every required class is ESTABLISHED, and the next
action follows mechanically from named inputs.

```json
[
  {"schema_version": "1", "key": "work_unit.identity", "class": "work_unit", "status": "ESTABLISHED",
   "value": {"kind": "pull_request", "id": "github.com/acme/widgets#42"},
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
   "value": {"parent": {"id": "github.com/acme/widgets#40", "state": "open"}, "children": [], "blocked_by": [{"id": "github.com/acme/widgets#39", "state": "closed"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/widgets#40", "issue:github.com/acme/widgets#39"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine", "close:issue"]}],
             "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "authority:grant"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "action:destructive"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "9001"},
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
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;acceptance.contract@2026-09-05T18:00:00Z;authority.standing@9001;checks.required@0123456789abcdef0123456789abcdef01234567;head.exact@0123456789abcdef0123456789abcdef01234567;repository.identity@2026-09-01T08:00:00Z;review.independent@2026-09-06T11:58:00Z;work_unit.identity@2026-09-06T12:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567"],
   "provenance": "preferences/fact-model.tsv",
   "inputs": ["review.independent", "checks.required", "head.exact", "authority.standing", "acceptance.contract", "repository.identity", "work_unit.identity"]}
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
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "provenance": "https://github.com/acme/widgets/pull/42/commits"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "ESTABLISHED",
   "value": {"verdict": "CHANGES REQUIRED", "head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "reviewer": "login:github-actions[bot]", "record": "github.com/acme/widgets#42/comment/9200"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42/comment/9200", "version": "2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "comment:github.com/acme/widgets#42/comment/9200"],
   "provenance": "https://github.com/acme/widgets/pull/42#issuecomment-9200"},
  {"schema_version": "1", "key": "checks.required", "class": "checks", "status": "ESTABLISHED",
   "value": {"head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "required": ["doctor", "tests"], "results": [{"name": "doctor", "state": "success"}, {"name": "tests", "state": "pending"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "provenance": "https://github.com/acme/widgets/commit/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/checks"},
  {"schema_version": "1", "key": "acceptance.contract", "class": "acceptance", "status": "ESTABLISHED",
   "value": {"contract": "github.com/acme/widgets#41", "head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "items": [{"id": "a1", "state": "MET"}, {"id": "a2", "state": "NOT_MET"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41", "head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "repair", "because": ["review.independent"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;checks.required@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;head.exact@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;review.independent@2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "provenance": "preferences/fact-model.tsv", "inputs": ["review.independent", "checks.required", "head.exact"]}
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
   "observed_at": "2026-09-06T14:00:00Z", "invalidators": ["head:cccccccccccccccccccccccccccccccccccccccc"],
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
   "value": {"kind": "pull_request", "id": "github.com/acme/widgets#42"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "2026-09-06T16:00:00Z"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["pull_request:github.com/acme/widgets#42"],
   "provenance": "https://github.com/acme/widgets/pull/42"},
  {"schema_version": "1", "key": "graph.native", "class": "graph", "status": "ESTABLISHED",
   "value": {"parent": {"id": "github.com/acme/program#42", "state": "open"}, "children": [], "blocked_by": [{"id": "github.com/acme/widgets#39", "state": "open"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-06T15:30:00Z"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/program#42", "issue:github.com/acme/widgets#39"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine"]}],
             "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "authority:grant"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "9001"},
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
   "value": {"kind": "pull_request", "id": "github.com/acme/widgets#43"},
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
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "9001"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001"],
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"},
  {"schema_version": "1", "key": "placement.current", "class": "placement", "status": "ESTABLISHED",
   "value": {"milestone": "github.com/acme/widgets/milestone/8", "release": "v1.2.0", "gate": "none"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#43", "version": "2026-09-06T16:50:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["pull_request:github.com/acme/widgets#43", "milestone:github.com/acme/widgets/milestone/8"],
   "provenance": "https://github.com/acme/widgets/pull/43"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "stop-decision-required", "because": ["authority.standing", "placement.current", "repository.identity", "work_unit.identity"], "boundary": "placement:release"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;authority.standing@9001;placement.current@2026-09-06T16:50:00Z;repository.identity@2026-09-01T08:00:00Z;work_unit.identity@2026-09-06T16:50:00Z"},
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
