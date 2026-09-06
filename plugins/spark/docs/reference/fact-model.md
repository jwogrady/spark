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

Every governed work unit is described by one fact per class. `required`
classes must be present in a snapshot (as ESTABLISHED, UNKNOWN, CONFLICT or
NOT_APPLICABLE — never silently absent); `derived` classes are computed from
other facts and name their inputs.

| Class | Required | Value shape when ESTABLISHED | What it answers |
|---|---|---|---|
| `work_unit` | required | `{kind: issue\|pull_request, id: <work-unit>}` | Which task is being executed |
| `repository` | required | `{id: <repository>, default_branch: <ref>}` | Which repository owns it |
| `placement` | required | `{milestone: <milestone>\|none, release: <release>\|none, gate: <work-unit>\|none}` | Where it sits in release, milestone and gate |
| `graph` | required | `{parent: <work-unit>\|none, children: [<work-unit>], blocked_by: [<work-unit>]}` | Its native parent, children and dependencies |
| `authority` | required | `{grants: [{decision: <comment>\|<work-unit>, scope: <text>}], human_boundaries: [<text>]}` | What standing authority applies and what is reserved for a human |
| `acceptance` | required | `{contract: <work-unit>, items: [{id, state: MET\|NOT_MET\|UNKNOWN}]}` | Which acceptance contract governs and how far it is satisfied |
| `head` | required | `{head: <commit>, base_ref: <ref>, base: <commit>, current: true\|false}` | The exact HEAD and base, and whether the HEAD is still current |
| `review` | required | `{verdict: <verdict>, head: <commit>, reviewer: <login>, record: <comment>}` | The independent verdict, bound to the HEAD it judged |
| `checks` | required | `{head: <commit>, required: [<text>], results: [{name, conclusion}]}` | Required-check state on that exact HEAD |
| `next_action` | derived | `{action: <action>, because: [<fact-key>]}` | The next governed action, where it follows mechanically |

Three further concerns are **facets of the envelope**, not separate facts:
provenance (`source`, `provenance`), freshness (`source.version`,
`observed_at`, `invalidators`) and certainty (`status`, `detail`).

## The envelope

Every fact, whatever its class, has exactly this shape:

| Field | Required | Meaning |
|---|---|---|
| `schema_version` | required | The schema version the fact conforms to (`"1"`) |
| `key` | required | `<class>.<name>` — one representation per operative fact |
| `class` | required | One of the class names above |
| `status` | required | One of the four status tokens below |
| `value` | only when ESTABLISHED | The class's value shape |
| `source` | required | `{type, identity, version}` — what was read, its canonical locator, and the version identity observed |
| `observed_at` | required | ISO-8601 UTC instant of the read |
| `invalidators` | required | Canonical tokens; a change to any one makes the fact stale |
| `provenance` | required | A pointer to the authoritative record, never the record itself |
| `inputs` | when derived | The keys of the facts this one was computed from |
| `inferred` | optional | `true` only for a legitimately inferred fact; an inferred fact is never authority |
| `detail` | optional | Machine-shaped explanation for UNKNOWN or CONFLICT: `{reason, candidates}` |

Optional means *absent*. A missing `value` is the statement "no value is
established"; the model never uses `null`, `false` or `""` to mean that, so a
consumer cannot mistake absence for an affirmative empty answer.

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
| action | the closed next-action vocabulary | `wait-review`, `repair`, `merge`, `close`, `stop-decision-required`, `stop-crossroad`, `none` |
| fact-key | `<class>.<name>` | `review.independent` |

## Sources and their version identity

| Source type | Version identity a fact must record |
|---|---|
| `github-api` | the node's `updated_at`, its etag, or the head/id the record is keyed by |
| `git` | the commit id or ref target observed |
| `repository-file` | the commit id the file was read at |
| `human-decision` | the comment id or commit id that records the decision — never a role, label or summary |
| `derived` | the schema version plus the input facts' versions |

## Rules

- **R1** Canonical identifiers have one representation; labels, abbreviations
  and pretty names are projections.
- **R2** Raw issue or comment bodies, timelines and explanatory prose are not
  fact values; a fact points at them through `provenance`.
- **R3** A fact states what is established now; provenance states why and how.
  Separate fields, never merged.
- **R4** A derived fact lists every fact key that decided it, so invalidating an
  input invalidates the conclusion.
- **R5** Human judgment is a `human-decision` source with a durable record
  identity. It is never inferred from capability, membership, labels or cached
  prose.
- **R6** `value` is present only when `status` is ESTABLISHED. UNKNOWN,
  CONFLICT and NOT_APPLICABLE carry no value and cannot collapse into `false`,
  `null` or empty.
- **R7** A fact bound to a HEAD (`head`, `review`, `checks`, `acceptance`)
  lists that HEAD among its `invalidators` and is stale the moment the HEAD
  changes.
- **R8** Two authoritative inputs that disagree are a CONFLICT naming both
  candidates; no first-write, last-write or plausibility rule resolves them.
- **R9** A consumer that meets an unknown `schema_version` treats the fact as
  UNKNOWN; it never reinterprets fields.
- **R10** Nothing in this model is written to `.spark/state.json`. Mutable
  GitHub execution truth is read from its source and carried in a snapshot;
  the state file keeps holding only the two judgment values it holds today
  (see [state.md](state.md)).

## Versioning

`schema_version` is the `version` record of `preferences/fact-model.tsv`.
Adding an optional field or a new class is a minor change under the same
version. Changing the meaning, type or requiredness of an existing field,
renaming a class, or altering a status token is a new version, and consumers
apply R9 to anything they do not recognise. The invalidation and migration
rules that follow from a version change belong to the freshness contract that
builds on this page.

## Examples

Each example is a snapshot: a JSON array of facts. The behavioral suite
validates every example on this page against the machine-readable schema, so
the examples are fixtures, not illustrations. The repository, numbers and ids
are invented; the situations are the ones a governed work unit actually meets.

### Example 1 — a normal pull request

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
  {"schema_version": "1", "key": "placement.release", "class": "placement", "status": "ESTABLISHED",
   "value": {"milestone": "github.com/acme/widgets/milestone/7", "release": "none", "gate": "github.com/acme/widgets#40"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "milestone:github.com/acme/widgets/milestone/7"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "graph.native", "class": "graph", "status": "ESTABLISHED",
   "value": {"parent": "github.com/acme/widgets#40", "children": [], "blocked_by": []},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/widgets#40"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "scope": "routine merge of a green, reviewed, current PR in this repository"}],
             "human_boundaries": ["release approval", "new authority", "destructive action"]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "9001"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001"],
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"},
  {"schema_version": "1", "key": "acceptance.contract", "class": "acceptance", "status": "ESTABLISHED",
   "value": {"contract": "github.com/acme/widgets#41", "items": [{"id": "a1", "state": "MET"}, {"id": "a2", "state": "MET"}]},
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
   "value": {"head": "0123456789abcdef0123456789abcdef01234567", "required": ["doctor", "tests"], "results": [{"name": "doctor", "conclusion": "success"}, {"name": "tests", "conclusion": "success"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "0123456789abcdef0123456789abcdef01234567"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567", "ruleset:github.com/acme/widgets"],
   "provenance": "https://github.com/acme/widgets/commit/0123456789abcdef0123456789abcdef01234567/checks"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "merge", "because": ["review.independent", "checks.required", "head.exact", "authority.standing", "acceptance.contract"]},
   "source": {"type": "derived", "identity": "fact-model", "version": "1"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567"],
   "provenance": "preferences/fact-model.tsv",
   "inputs": ["review.independent", "checks.required", "head.exact", "authority.standing", "acceptance.contract"]}
]
```

### Example 2 — exact-HEAD review, acceptance and check state

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
   "value": {"head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "required": ["doctor", "tests"], "results": [{"name": "doctor", "conclusion": "success"}, {"name": "tests", "conclusion": "success"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "provenance": "https://github.com/acme/widgets/commit/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/checks"},
  {"schema_version": "1", "key": "acceptance.contract", "class": "acceptance", "status": "ESTABLISHED",
   "value": {"contract": "github.com/acme/widgets#41", "items": [{"id": "a1", "state": "MET"}, {"id": "a2", "state": "NOT_MET"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41", "head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "repair", "because": ["review.independent"]},
   "source": {"type": "derived", "identity": "fact-model", "version": "1"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "provenance": "preferences/fact-model.tsv", "inputs": ["review.independent", "checks.required", "head.exact"]}
]
```

### Example 3 — a stale HEAD invalidates only HEAD-bound facts

A new push moved the HEAD. The head fact records `current: false` against the
old HEAD; the review that judged the old HEAD is still a true statement about
that HEAD — it is simply no longer the review of the work unit's current
change, so the next action is to wait for a fresh one. Repository, placement
and graph facts carry no HEAD invalidator and remain established.

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
   "value": {"action": "wait-review", "because": ["head.exact", "review.independent"]},
   "source": {"type": "derived", "identity": "fact-model", "version": "1"},
   "observed_at": "2026-09-06T14:00:00Z", "invalidators": ["head:cccccccccccccccccccccccccccccccccccccccc"],
   "provenance": "preferences/fact-model.tsv", "inputs": ["head.exact", "review.independent"]}
]
```

### Example 4 — conflicting authoritative evidence

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
   "value": {"action": "stop-decision-required", "because": ["review.independent"]},
   "source": {"type": "derived", "identity": "fact-model", "version": "1"},
   "observed_at": "2026-09-06T15:00:00Z", "invalidators": ["head:dddddddddddddddddddddddddddddddddddddddd"],
   "provenance": "preferences/fact-model.tsv", "inputs": ["review.independent"]}
]
```

### Example 5 — a cross-repository parent

The work unit lives in one repository and its parent in another. Because every
work-unit identity is fully qualified, the two never compare equal on a bare
number, and the authority fact names the repository the grant applies to.

```json
[
  {"schema_version": "1", "key": "work_unit.identity", "class": "work_unit", "status": "ESTABLISHED",
   "value": {"kind": "pull_request", "id": "github.com/acme/widgets#42"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "2026-09-06T16:00:00Z"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["pull_request:github.com/acme/widgets#42"],
   "provenance": "https://github.com/acme/widgets/pull/42"},
  {"schema_version": "1", "key": "graph.native", "class": "graph", "status": "ESTABLISHED",
   "value": {"parent": "github.com/acme/program#42", "children": [], "blocked_by": ["github.com/acme/widgets#39"]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-06T15:30:00Z"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/program#42", "issue:github.com/acme/widgets#39"],
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "scope": "routine merge in github.com/acme/widgets only; a grant recorded in github.com/acme/program confers nothing here"}],
             "human_boundaries": ["release approval", "cross-repository authority"]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "9001"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001"],
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"}
]
```

### Example 6 — a reserved human boundary

Every mechanical condition holds, but the change touches release placement,
which the standing grant reserves for a human. The authority fact says so from
its durable record, and the derived action stops; nothing infers permission
from the actor's role or from the fact that the merge is technically possible.

```json
[
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "scope": "routine merge of a green, reviewed, current PR"}],
             "human_boundaries": ["release placement", "release approval", "repository settings"]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "9001"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001"],
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"},
  {"schema_version": "1", "key": "placement.release", "class": "placement", "status": "ESTABLISHED",
   "value": {"milestone": "none", "release": "none", "gate": "none"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#43", "version": "2026-09-06T16:50:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["issue:github.com/acme/widgets#43"],
   "provenance": "https://github.com/acme/widgets/issues/43"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "stop-decision-required", "because": ["authority.standing", "placement.release"]},
   "source": {"type": "derived", "identity": "fact-model", "version": "1"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001", "issue:github.com/acme/widgets#43"],
   "provenance": "preferences/fact-model.tsv", "inputs": ["authority.standing", "placement.release"]}
]
```

### Example 7 — a fact that is UNKNOWN because the source cannot be read

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
   "value": {"action": "wait-review", "because": ["checks.required"]},
   "source": {"type": "derived", "identity": "fact-model", "version": "1"},
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
