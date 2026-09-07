# Reference — the operative fact model

> Reference — information-oriented.

An **operative fact** is the smallest machine-readable statement an agent needs
in order to execute a governed work unit without reconstructing current truth
from issue history. This page defines the fact classes, the envelope every fact
is carried in, the closed status vocabulary, and the canonical identifier forms.

The machine-readable authority is `preferences/fact-model.tsv` (schema
version 1); this page renders it, never the other way round, and the behavioral
suite `tests/test-fact-model.sh` checks the page against the authority. The
model is **Experimental**: it is the
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

| Facet | Fields | Meaning |
|---|---|---|
| `provenance` | `source`, `provenance` | Source identity and the pointer that lets an auditor drill down |
| `freshness` | `source.version`, `observed_at`, `invalidators` | What was observed, when, and what makes the fact stale |
| `certainty` | `status`, `detail` | UNKNOWN / CONFLICT / NOT_APPLICABLE are explicit statuses, never empty values |

## The envelope

Every fact, whatever its class, has exactly this shape:

| Field | Required | Type | Meaning |
|---|---|---|---|
| `schema_version` | required | `schema-version` | The schema version the fact conforms to (this file's `version`), in the schema-version grammar |
| `key` | required | `fact-key` | The class's one canonical fact key (the key records); one representation per operative fact, so inputs and invalidators address a stable identity |
| `class` | required | `string` | One of the class names above |
| `status` | required | `string` | One of the status tokens below |
| `value` | optional | `any` | Present only when status is ESTABLISHED; its shape is the class's value-shape |
| `source` | required | `object` | The source shape below: what was read, its canonical identity in the grammar of that source type, and the version identity observed |
| `observed_at` | required | `timestamp` | The instant the source was read, in the timestamp grammar (ISO-8601 UTC, second precision, Z) |
| `invalidators` | required | `list` | Canonical invalidator tokens, each in one of the invalidator grammars and unique within the fact; a change to any one makes the fact stale |
| `versions` | required | `object` | The version observed for every invalidator token when the fact was read — token → version, a commit for head: and ref:, the node's updated_at for every other kind (each invalidator record names its version form); a fact is current only while every observed version equals the source's current version (freshness contract F1), and within one set a node has one observed version |
| `provenance` | required | `provenance` | Pointer to the authoritative record in the provenance grammar (an https URL or a repository-relative path, no whitespace); never the record itself |
| `inputs` | optional | `list` | Fact keys this fact was derived from; required when source.type is derived |
| `inferred` | optional | `boolean` | The literal true, present only on a legitimately inferred fact (any other value is rejected); an inferred fact is never authority |
| `detail` | optional | `object` | The detail shape below, present only when status is UNKNOWN or CONFLICT: reason is one non-empty line, candidates is a list (possibly empty) of canonical locators — never prose or a raw record |

The two envelope objects have exact shapes, in the same grammar as a class's value
shape:

| Object | Shape |
|---|---|
| `source` | `{type: <source-type>, identity: <text>, version: <text>}` |
| `detail` | `{reason: <text>, candidates: [<locator>]}` |
| `observer` | `{login: <login>, permission: <permission>, checked_at: <timestamp>}` |

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
| `UNKNOWN` | no | The source could not be read or the fact is outside the observed snapshot; never a permissive default |
| `CONFLICT` | no | Two authoritative inputs disagree or evidence is malformed beside valid evidence; a human or a released contract resolves it, never the model |
| `NOT_APPLICABLE` | no | The fact class does not apply to this work unit: a HEAD-bound class for a work unit that has no HEAD (an issue no pull request implements yet); every other class always applies |

## Statuses per class

Not every status is meaningful for every class. A work unit, its repository, its
placement, its graph and the standing authority always apply, so they are ESTABLISHED,
UNKNOWN or CONFLICT; the HEAD-bound classes add NOT_APPLICABLE for a work unit with
no HEAD; the derived class is ESTABLISHED or UNKNOWN (R18). The behavioral suite builds
one canonical fact for every class × admitted status and proves it validates, and one
for every class × excluded status and proves it is rejected, so the matrix is not a
table of intentions.

| Class | Admitted statuses |
|---|---|
| `work_unit` | `ESTABLISHED`, `UNKNOWN`, `CONFLICT` |
| `repository` | `ESTABLISHED`, `UNKNOWN`, `CONFLICT` |
| `placement` | `ESTABLISHED`, `UNKNOWN`, `CONFLICT` |
| `graph` | `ESTABLISHED`, `UNKNOWN`, `CONFLICT` |
| `authority` | `ESTABLISHED`, `UNKNOWN`, `CONFLICT` |
| `acceptance` | `ESTABLISHED`, `UNKNOWN`, `CONFLICT`, `NOT_APPLICABLE` |
| `head` | `ESTABLISHED`, `UNKNOWN`, `CONFLICT`, `NOT_APPLICABLE` |
| `review` | `ESTABLISHED`, `UNKNOWN`, `CONFLICT`, `NOT_APPLICABLE` |
| `checks` | `ESTABLISHED`, `UNKNOWN`, `CONFLICT`, `NOT_APPLICABLE` |
| `next_action` | `ESTABLISHED`, `UNKNOWN` |

## Canonical identifiers

One representation per identity. Everything else — a bare issue number, a
seven-char SHA, a display title, a differently-cased owner or repository name —
is a projection and is never used to compare or bind.

Every grammar on this page — identifier, invalidator, constraint, source identity
and source version — is a **portable ERE**: a POSIX extended regular expression with
no lookaround, no backslash-letter escape (`\s`, `\d`, `\x..`), no backslash inside a
bracket expression and no POSIX character class, so `awk`, `grep -E` and every modern
engine read it identically. Every class is positive — letters, digits and enumerated
punctuation — so whitespace and control characters are outside every grammar by
construction. The behavioral suite lints every grammar against this dialect and runs
each example below through both `grep -E` and a second engine.

| Kind | Canonical form | Grammar (ERE) | Example |
|---|---|---|---|
| repository | <host>/<owner>/<name>, all lower-case (GitHub compares owner and name case-insensitively, so one spelling is the identity), no scheme: the host is DNS labels (letters, digits, inner hyphens; each at most 63 characters and the whole at most 253, by constraint) with at least one dot and no trailing dot; the owner is a GitHub login (alphanumerics joined by single hyphens, at most 39 characters by constraint); the name is GitHub's (letters, digits, . _ -; never exactly . or ..; at most 100 characters by constraint) and never ends in .git — that is the clone URL's spelling, a projection | `^(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)$` | `github.com/acme/widgets` |
| work-unit | <repository>#<number>; a bare #<number> is a projection, never an identity | `^(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)#[1-9][0-9]*$` | `github.com/acme/widgets#42` |
| comment | <work-unit>/comment/<comment id> | `^(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)#[1-9][0-9]*/comment/[1-9][0-9]*$` | `github.com/acme/widgets#42/comment/9001` |
| milestone | <repository>/milestone/<number> | `^(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)/milestone/[1-9][0-9]*$` | `github.com/acme/widgets/milestone/7` |
| commit | Full 40-hex lower-case object id; abbreviations are projections | `^[0-9a-f]{40}$` | `4f3d2c1b0a9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c` (40 characters) |
| ref | A branch name without the refs/heads/ prefix, in printable ASCII: slash-separated components of letters, digits and the punctuation Git allows, none empty or dot-led; no space or control character, no ~ ^ : ? * [ or backslash, no .. or @{, never the single name @, no component ending in .lock, never ending in / or .; refs/… and any other spelling of the same branch are projections; a branch name outside printable ASCII is not representable in this version | ``^[]!"#$%&'()+,0-9;<=>@A-Z_`a-z{\|}-][]!"#$%&'()+,.0-9;<=>@A-Z_`a-z{\|}-]*(/[]!"#$%&'()+,0-9;<=>@A-Z_`a-z{\|}-][]!"#$%&'()+,.0-9;<=>@A-Z_`a-z{\|}-]*)*$`` | `master`, `release/v1.2.x`, `feat/x+y` |
| release | A release tag as published | `^v[0-9]+\.[0-9]+\.[0-9]+$` | `v0.22.0` |
| login | An actor identity: the GitHub login lower-cased (GitHub compares logins case-insensitively, so one representation per actor, R1), alphanumerics joined by single hyphens, never starting or ending with a hyphen, at most 39 characters (the login constraint), with the [bot] suffix for an app; naming an actor never confers authority | `^login:[a-z0-9]+(-[a-z0-9]+)*(\[bot\])?$` | `login:github-actions[bot]` — naming an actor never confers authority |
| verdict | The independent reviewer's closed vocabulary | `^(PASS\|CHANGES REQUIRED\|DECISION REQUIRED\|NOT ASSESSED)$` | `PASS`, `CHANGES REQUIRED`, `DECISION REQUIRED`, `NOT ASSESSED` |
| action | The closed next-action vocabulary: only actions whose derivation rule (R15) this version defines; a new action is a new version | `^(wait-review\|repair\|merge\|stop-decision-required)$` | `wait-review`, `repair`, `merge`, `stop-decision-required` |
| item-id | A scalar acceptance item id: one token, no whitespace, unique within its fact | `^[A-Za-z0-9][A-Za-z0-9._:/-]{0,79}$` | `a1`, `acceptance/3` |
| provenance | A pointer: an https URL in RFC 3986 characters (anything beyond them percent-encoded), or a normalized repository-relative path (slash-separated components, none empty, none . or .., no leading slash); never the record itself | `^(https://[A-Za-z0-9._~:/?#@!$&'()*+,;=%-]+\|[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*)$` | `https://github.com/acme/widgets/pull/42#issuecomment-9100`, `preferences/fact-model.tsv` |
| timestamp | An ISO-8601 UTC instant at second precision with Z suffix whose grammar encodes the calendar itself — 31-day and 30-day months, February to the 28th and the 29th only in a leap year (divisible by 4, or by 400 among century years; year 0000 is a leap year, as ISO 8601 has it), hours 00–23, minutes and seconds 00–59 — so a consumer needs nothing beyond the regex; the type of observed_at and the one form every timestamp-bearing source version takes | `^([0-9]{4}-((0[13578]\|1[02])-(0[1-9]\|[12][0-9]\|3[01])\|(0[469]\|11)-(0[1-9]\|[12][0-9]\|30)\|02-(0[1-9]\|1[0-9]\|2[0-8]))\|([0-9]{2}(0[48]\|[2468][048]\|[13579][26])\|([02468][048]\|[13579][26])00)-02-29)T([01][0-9]\|2[0-3]):[0-5][0-9]:[0-5][0-9]Z$` | `2026-09-06T12:00:05Z` |
| schema-version | A schema version: a positive integer; the type of schema_version | `^[1-9][0-9]*$` | `1` |
| fact-key | the class's one canonical key (the key records) | `^(work_unit\.identity\|repository\.identity\|placement\.current\|graph\.native\|authority\.standing\|acceptance\.contract\|head\.exact\|review\.independent\|checks\.required\|next_action\.governed)$` | `review.independent` |
| permission | The observing identity's repository permission, GitHub's closed vocabulary; recorded by a complete snapshot's observer | `^(admin\|maintain\|write\|triage\|read\|none)$` | `write` |
| issue-state | Current state of a related work unit; a blocked_by entry is satisfied exactly when closed | `^(open\|closed)$` | `open`, `closed` |
| check-state | Normalized state of one required check on the exact HEAD: missing = required but no run observed | `^(success\|failure\|pending\|missing)$` | `success`, `failure`, `pending`, `missing` (required but no run observed) |
| scope | What a standing grant permits; the closed scope vocabulary | `^(merge:routine\|close:issue\|metadata:labels\|metadata:hierarchy\|evidence:publish\|branch:push)$` | `merge:routine`, `close:issue`, `metadata:labels`, `metadata:hierarchy`, `evidence:publish`, `branch:push` |
| boundary | What a human reserves; the closed boundary vocabulary | `^(release:approve\|authority:grant\|settings:repository\|action:destructive\|placement:release\|semantics:product)$` | `release:approve`, `authority:grant`, `settings:repository`, `action:destructive`, `placement:release`, `semantics:product` |
| derived-version | <schema version>;<input key>@<input source.version>;… — one entry per input, sorted by key; a source version is written in the characters of the source version grammars | `^[1-9][0-9]*(;[a-z_]+\.[a-z_]+@[A-Za-z0-9._:/"-]+)+$` | `1;head.exact@4f3d2c1b0a9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c;review.independent@2026-09-06T11:58:00Z` |
| decision-record | A durable human decision: a <comment> locator or <repository>@<commit>; never a role, label or summary | `^((([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)#[1-9][0-9]*/comment/[1-9][0-9]*\|(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)@[0-9a-f]{40})$` | `github.com/acme/widgets#7/comment/9001` |

## Constraints

A grammar alone cannot exclude every non-canonical spelling (`.git`, `refs/`, `..`,
`@{`, a `.lock` suffix, a `.` path component). Those exclusions are **constraint
records**: portable extended regular expressions (the dialect above), scoped to an identifier
kind, to every invalidator, to one invalidator kind, or to one source type's identity. A value is canonical only
when it matches its grammar *and* none of its constraints (R1). They are data, so a
consumer applies them rather than reconstructing them from prose.

| Scope | Forbidden (ERE) | Meaning |
|---|---|---|
| `repository` | `\.git$` | the name never carries the clone URL's .git suffix |
| `repository` | `^([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `work-unit` | `\.git#` | the repository name inside a work-unit locator never carries .git |
| `work-unit` | `^([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `comment` | `\.git#` | the repository name inside a comment locator never carries .git |
| `comment` | `^([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `milestone` | `\.git/` | the repository name inside a milestone locator never carries .git |
| `milestone` | `^([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `decision-record` | `\.git(#\|@)` | the repository name inside a decision record never carries .git |
| `decision-record` | `^([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `login` | `^login:[a-z0-9-]{40}` | a GitHub login is at most 39 characters |
| `ref` | `^refs/` | a ref is the branch name, never the refs/ path |
| `ref` | `\.\.` | no .. anywhere in a ref |
| `ref` | `@\{` | no @{ (reflog syntax) in a ref |
| `ref` | `\.lock(/\|$)` | no component of a ref ends in .lock (Git reserves the suffix for lock files) |
| `ref` | `\.$` | a ref never ends in a dot |
| `ref` | `^@$` | the single name @ is not a branch (Git reserves it for HEAD) |
| `provenance` | `(^\|/)\.\.?(/\|$)` | a path is normalized: no . or .. components |
| `source-identity/repository-file` | `(:\|/)\.\.?(/\|$)` | the path after the commit is normalized: no . or .. components |
| `source-identity/git` | `\.git(@\|$)` | the repository name never carries .git |
| `source-identity/git` | `^([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `source-identity/github-api` | `\.git(#\|/\|$)` | the repository name never carries .git |
| `source-identity/github-api` | `^([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `source-identity/repository-file` | `\.git@` | the repository name never carries .git |
| `source-identity/repository-file` | `^([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `source-identity/human-decision` | `\.git(#\|@)` | the repository name never carries .git |
| `source-identity/human-decision` | `^([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `invalidator` | `\.git(#\|/\|$)` | the repository name inside any invalidator never carries .git |
| `invalidator` | `^[a-z_]+:([a-z0-9.-]{254}\|([a-z0-9-]+\.)*[a-z0-9-]{64}\|[a-z0-9.-]+/([a-z0-9-]{40}\|[a-z0-9-]+/[a-z0-9_.-]{101}))` | a host label is at most 63 characters and a host 253 (DNS); an owner is at most 39 and a name 100 (GitHub) |
| `invalidator/ref` | `\.\.` | the embedded ref has no .. |
| `invalidator/ref` | `@\{` | the embedded ref has no @{ |
| `invalidator/ref` | `\.lock(/\|$)` | no component of the embedded ref ends in .lock |
| `invalidator/ref` | `\.$` | the embedded ref never ends in a dot |
| `invalidator/ref` | `/@$` | the embedded ref is never the single name @ |
| `invalidator/ref` | `^ref:(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)/refs/` | the embedded ref is the branch name, never the refs/ path |
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

| Kind | Grammar (ERE) | Token form and meaning | Observed version |
|---|---|---|---|
| `head` | `^head:[0-9a-f]{40}$` | head:<commit> — the exact HEAD a HEAD-bound fact was judged on (ESTABLISHED) or observed against (UNKNOWN, CONFLICT) | `commit` |
| `pull_request` | `^pull_request:(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)#[1-9][0-9]*$` | pull_request:<work-unit> — the pull request whose metadata or head the fact was read from | `timestamp` |
| `issue` | `^issue:(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)#[1-9][0-9]*$` | issue:<work-unit> — the issue whose metadata or relationships the fact was read from | `timestamp` |
| `comment` | `^comment:(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)#[1-9][0-9]*/comment/[1-9][0-9]*$` | comment:<comment> — the comment that records the verdict or decision | `timestamp` |
| `milestone` | `^milestone:(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)/milestone/[1-9][0-9]*$` | milestone:<milestone> — the milestone the placement was read from | `timestamp` |
| `repository` | `^repository:(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)$` | repository:<repository> — the repository node (default branch, settings) | `timestamp` |
| `ref` | ``^ref:(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)/[]!"#$%&'()+,0-9;<=>@A-Z_`a-z{\|}-][]!"#$%&'()+,.0-9;<=>@A-Z_`a-z{\|}-]*(/[]!"#$%&'()+,0-9;<=>@A-Z_`a-z{\|}-][]!"#$%&'()+,.0-9;<=>@A-Z_`a-z{\|}-]*)*$`` | ref:<repository>/<ref> — the branch whose target the fact depends on | `commit` |
| `ruleset` | `^ruleset:(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)$` | ruleset:<repository> — the repository's rulesets (which checks are required) | `timestamp` |

## Reserved boundaries the model can derive a stop from

`next_action.boundary` names the reserved boundary a `stop-decision-required`
rests on, or `none`. Naming one is not enough: the authority fact must carry
that token with a target equal to the repository or work unit id, and the
evidence below must hold on the fact it names. A boundary token without a row
here has no derivation in this version — a stop on it needs a DECISION REQUIRED
verdict or a CONFLICT input, otherwise `next_action` is UNKNOWN.

| Boundary | Evidence fact | Field | Condition | Why it applies |
|---|---|---|---|---|
| `placement:release` | `placement.current` | `release` | `not-none` | The work unit is placed in a release, so a routine merge would change what that release ships |

## Sources: identity grammar and version identity

`source.identity` and `source.version` are each validated against the grammar
of the source type; a role name, a label, a summary, or a word such as
`latest` can never stand as the identity or the version of a source.

| Source type | What it is | Version identity | Canonical `source.identity` | Identity grammar (ERE) | `source.version` form | Version grammar (ERE) |
|---|---|---|---|---|---|---|
| `github-api` | A GitHub REST or GraphQL read | node updated_at, etag, or the observed head the record is keyed by — never a node id, which does not change when the node does | A <repository>, <work-unit>, <comment> or <milestone> locator — the GitHub node that was read | `^(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)(#[1-9][0-9]*(/comment/[1-9][0-9]*)?\|/milestone/[1-9][0-9]*)?$` | The node's updated_at (ISO-8601 Z), the head it is keyed by (40-hex), or its etag in a delimiter-safe form (letters, digits, . _ : / -; never ; or whitespace, so it can be carried inside a derived-version); a numeric node id never versions a mutable node | `^(([0-9]{4}-((0[13578]\|1[02])-(0[1-9]\|[12][0-9]\|3[01])\|(0[469]\|11)-(0[1-9]\|[12][0-9]\|30)\|02-(0[1-9]\|1[0-9]\|2[0-8]))\|([0-9]{2}(0[48]\|[2468][048]\|[13579][26])\|([02468][048]\|[13579][26])00)-02-29)T([01][0-9]\|2[0-3]):[0-5][0-9]:[0-5][0-9]Z\|[0-9a-f]{40}\|W/"[A-Za-z0-9._:/-]+"\|"[A-Za-z0-9._:/-]+")$` |
| `git` | A read of the local or remote git object store | the commit id or ref target observed | <repository>@<commit> or <repository>@ref/<ref> | ``^(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)@([0-9a-f]{40}\|ref/[]!"#$%&'()+,0-9;<=>@A-Z_`a-z{\|}-][]!"#$%&'()+,.0-9;<=>@A-Z_`a-z{\|}-]*(/[]!"#$%&'()+,0-9;<=>@A-Z_`a-z{\|}-][]!"#$%&'()+,.0-9;<=>@A-Z_`a-z{\|}-]*)*)$`` | The commit id observed (a ref target is recorded as the commit it pointed at) | `^[0-9a-f]{40}$` |
| `repository-file` | A committed file in the repository tree | the commit id the file was read at | <repository>@<commit>:<path> — a normalized repository-relative path: slash-separated components, none empty, none . or .., no leading slash | `^(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)@[0-9a-f]{40}:[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$` | The commit id the file was read at | `^[0-9a-f]{40}$` |
| `human-decision` | A durable, source-backed human decision; never a role, label or summary | the recording comment's updated_at (a comment can be edited, so its id alone cannot version the decision) or the commit id that records it | The <decision-record> itself | `^((([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)#[1-9][0-9]*/comment/[1-9][0-9]*\|(([a-z0-9][a-z0-9-]*)?[a-z0-9]\.)+([a-z0-9][a-z0-9-]*)?[a-z0-9]/[a-z0-9]+(-[a-z0-9]+)*/([a-z0-9_-][a-z0-9_.-]*\|\.[a-z0-9_-][a-z0-9_.-]*\|\.\.[a-z0-9_.-]+)@[0-9a-f]{40})$` | The recording comment's updated_at (ISO-8601 Z) for a comment locator, or the commit id for a <repository>@<commit> record — edit-sensitive, so an edited decision re-versions everything derived from it | `^(([0-9]{4}-((0[13578]\|1[02])-(0[1-9]\|[12][0-9]\|3[01])\|(0[469]\|11)-(0[1-9]\|[12][0-9]\|30)\|02-(0[1-9]\|1[0-9]\|2[0-8]))\|([0-9]{2}(0[48]\|[2468][048]\|[13579][26])\|([02468][048]\|[13579][26])00)-02-29)T([01][0-9]\|2[0-3]):[0-5][0-9]:[0-5][0-9]Z\|[0-9a-f]{40})$` |
| `derived` | A conclusion computed from other facts (requires inputs); the version changes whenever any input's version does | <derived-version>: the schema version, then <input key>@<that input's source.version> for every input, sorted by key | fact-model/<schema version> | `^fact-model/[1-9][0-9]*$` | The derived-version (schema version, then <input key>@<input source.version> for every input, sorted) | `^[1-9][0-9]*(;[a-z_]+\.[a-z_]+@[A-Za-z0-9._:/"-]+)+$` |

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
  A record that carries the same field twice is malformed and is rejected before
  parsing; a consumer that keeps the first or the last duplicate is not
  conforming.
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
  wait for ESTABLISHED. A fact whose value depends on which records a node
  carries lists that node too — a review lists the work unit whose comments hold
  the verdicts, an authority fact lists the node of every decision record it
  names or considers, a head fact lists the pull request it was read from —
  under the node's kind, so a record created after the fact was read, or a
  base-branch switch, fires a token the fact already carries.
- **R18** Each class admits exactly the statuses its class-status record lists:
  work unit, repository, placement, graph and authority are always applicable
  (ESTABLISHED, UNKNOWN or CONFLICT); the HEAD-bound classes add NOT_APPLICABLE
  for a work unit with no HEAD; a derived class is ESTABLISHED or UNKNOWN. Every
  envelope field whose type is an identifier kind is a string in that grammar,
  so no field's canonical form lives only in prose. A timestamp anywhere in a
  fact — observed_at, a GitHub node's updated_at, a decision comment's
  updated_at — is the one timestamp grammar, whose regex encodes the calendar
  itself (month lengths and leap years), so an impossible instant is outside the
  schema with no validator beyond the regex.
- **R19** A schema version identifies a shipped contract. Once a Spark release
  ships a version, any change to a rule, shape, grammar, constraint or
  vocabulary that alters which facts are valid is a new version, and a consumer
  treats another version as UNKNOWN (R9). Until a version ships, its rules may
  be corrected in place and the release that ships it fixes them; the stability
  register marks the model Experimental while that is so.
- **R20** Every fact carries versions: for each invalidator token, the version
  observed for that node when the fact was read — the commit itself for head:,
  the branch's target commit for ref:, the node's updated_at for every other
  kind — and no other key. The source node's observed version is the fact's
  source.version where that is a timestamp, and within one set a node has one
  observed version. The tokens say what a fact depends on; the versions say as
  of when, so freshness is a comparison of versions, never a judgment of age.
- **R21** A complete snapshot records its observer: the login that read it, that
  login's repository permission in GitHub's closed vocabulary, and when the
  permission was checked. Readability is a property of the snapshot: before a
  cached snapshot is used, the observer's permission is re-read and compared,
  and a difference is a repository event of the freshness contract.

## Versioning

`schema_version` is the `version` record of `preferences/fact-model.tsv`.
Nothing is added, removed or changed under an existing version: any new field,
class, status token or vocabulary member, and any change to the meaning, type
or requiredness of an existing one, is a new version — once the version has
shipped in a Spark release (R19); until then its rules may be corrected in
place, and the release that ships it fixes them. A consumer therefore
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

A complete snapshot is an object: `observer` — the login that read it, its
repository permission and when that was checked (R21) — and `facts`; a fragment
is a bare list of facts. Every fact carries `versions`, the version it observed
for each of its invalidator tokens (R20); the freshness contract compares them
with the sources' current versions.

### Example 1 — a normal pull request (complete snapshot)

The pull request `github.com/acme/widgets#42` implements the issue
`github.com/acme/widgets#41` (its closing reference), which is why the
placement, graph and acceptance facts are read from that issue: the work unit
declares the relationship in `implements`, and R17 binds those reads to it.

The straightforward case: every required class is ESTABLISHED, and the next
action follows mechanically from named inputs.

```json
{"observer": {"login": "login:acme-orchestrator[bot]", "permission": "write", "checked_at": "2026-09-06T12:00:05Z"},
 "facts": [
  {"schema_version": "1", "key": "work_unit.identity", "class": "work_unit", "status": "ESTABLISHED",
   "value": {"kind": "pull_request", "id": "github.com/acme/widgets#42", "implements": "github.com/acme/widgets#41"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "2026-09-06T12:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["pull_request:github.com/acme/widgets#42"],
   "versions": {"pull_request:github.com/acme/widgets#42": "2026-09-06T12:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/42"},
  {"schema_version": "1", "key": "repository.identity", "class": "repository", "status": "ESTABLISHED",
   "value": {"id": "github.com/acme/widgets", "default_branch": "master"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "2026-09-01T08:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["repository:github.com/acme/widgets"],
   "versions": {"repository:github.com/acme/widgets": "2026-09-01T08:00:00Z"},
   "provenance": "https://github.com/acme/widgets"},
  {"schema_version": "1", "key": "placement.current", "class": "placement", "status": "ESTABLISHED",
   "value": {"milestone": "github.com/acme/widgets/milestone/7", "release": "none", "gate": "github.com/acme/widgets#40"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "milestone:github.com/acme/widgets/milestone/7"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z", "milestone:github.com/acme/widgets/milestone/7": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "graph.native", "class": "graph", "status": "ESTABLISHED",
   "value": {"parent": {"kind": "issue", "id": "github.com/acme/widgets#40", "state": "open"}, "children": [], "blocked_by": [{"kind": "issue", "id": "github.com/acme/widgets#39", "state": "closed"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/widgets#40", "issue:github.com/acme/widgets#39"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z", "issue:github.com/acme/widgets#40": "2026-09-05T18:00:00Z", "issue:github.com/acme/widgets#39": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine", "close:issue"]}],
             "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "authority:grant"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "action:destructive"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "2026-09-01T09:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001", "issue:github.com/acme/widgets#7"],
   "versions": {"comment:github.com/acme/widgets#7/comment/9001": "2026-09-01T09:00:00Z", "issue:github.com/acme/widgets#7": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"},
  {"schema_version": "1", "key": "acceptance.contract", "class": "acceptance", "status": "ESTABLISHED",
   "value": {"contract": "github.com/acme/widgets#41", "head": "0123456789abcdef0123456789abcdef01234567", "items": [{"id": "a1", "state": "MET"}, {"id": "a2", "state": "MET"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "head:0123456789abcdef0123456789abcdef01234567"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z", "head:0123456789abcdef0123456789abcdef01234567": "0123456789abcdef0123456789abcdef01234567"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "ESTABLISHED",
   "value": {"head": "0123456789abcdef0123456789abcdef01234567", "base_ref": "master", "base": "89abcdef0123456789abcdef0123456789abcdef", "current": true},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "0123456789abcdef0123456789abcdef01234567"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567", "ref:github.com/acme/widgets/master", "pull_request:github.com/acme/widgets#42"],
   "versions": {"head:0123456789abcdef0123456789abcdef01234567": "0123456789abcdef0123456789abcdef01234567", "ref:github.com/acme/widgets/master": "89abcdef0123456789abcdef0123456789abcdef", "pull_request:github.com/acme/widgets#42": "2026-09-06T12:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/42/commits"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "ESTABLISHED",
   "value": {"verdict": "PASS", "head": "0123456789abcdef0123456789abcdef01234567", "reviewer": "login:github-actions[bot]", "record": "github.com/acme/widgets#42/comment/9100"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42/comment/9100", "version": "2026-09-06T11:58:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567", "comment:github.com/acme/widgets#42/comment/9100", "pull_request:github.com/acme/widgets#42"],
   "versions": {"head:0123456789abcdef0123456789abcdef01234567": "0123456789abcdef0123456789abcdef01234567", "comment:github.com/acme/widgets#42/comment/9100": "2026-09-06T11:58:00Z", "pull_request:github.com/acme/widgets#42": "2026-09-06T12:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/42#issuecomment-9100"},
  {"schema_version": "1", "key": "checks.required", "class": "checks", "status": "ESTABLISHED",
   "value": {"head": "0123456789abcdef0123456789abcdef01234567", "required": ["doctor", "tests"], "results": [{"name": "doctor", "state": "success"}, {"name": "tests", "state": "success"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "0123456789abcdef0123456789abcdef01234567"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567", "ruleset:github.com/acme/widgets"],
   "versions": {"head:0123456789abcdef0123456789abcdef01234567": "0123456789abcdef0123456789abcdef01234567", "ruleset:github.com/acme/widgets": "2026-09-01T08:00:00Z"},
   "provenance": "https://github.com/acme/widgets/commit/0123456789abcdef0123456789abcdef01234567/checks"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "merge", "because": ["review.independent", "checks.required", "head.exact", "authority.standing", "acceptance.contract"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;acceptance.contract@2026-09-05T18:00:00Z;authority.standing@2026-09-01T09:00:00Z;checks.required@0123456789abcdef0123456789abcdef01234567;graph.native@2026-09-05T18:00:00Z;head.exact@0123456789abcdef0123456789abcdef01234567;placement.current@2026-09-05T18:00:00Z;repository.identity@2026-09-01T08:00:00Z;review.independent@2026-09-06T11:58:00Z;work_unit.identity@2026-09-06T12:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["head:0123456789abcdef0123456789abcdef01234567"],
   "versions": {"head:0123456789abcdef0123456789abcdef01234567": "0123456789abcdef0123456789abcdef01234567"},
   "provenance": "preferences/fact-model.tsv",
   "inputs": ["review.independent", "checks.required", "head.exact", "authority.standing", "acceptance.contract", "repository.identity", "work_unit.identity", "placement.current", "graph.native"]}
]}
```

### Example 2 — exact-HEAD review, acceptance and check state (fragment)

The three HEAD-bound classes share one invalidator, the HEAD they were
observed on. Nothing here can be reused for another HEAD.

```json
[
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "ESTABLISHED",
   "value": {"head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "base_ref": "master", "base": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "current": true},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "ref:github.com/acme/widgets/master", "pull_request:github.com/acme/widgets#42"],
   "versions": {"head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "ref:github.com/acme/widgets/master": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "pull_request:github.com/acme/widgets#42": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/42/commits"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "ESTABLISHED",
   "value": {"verdict": "CHANGES REQUIRED", "head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "reviewer": "login:github-actions[bot]", "record": "github.com/acme/widgets#42/comment/9200"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42/comment/9200", "version": "2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "comment:github.com/acme/widgets#42/comment/9200", "pull_request:github.com/acme/widgets#42"],
   "versions": {"head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "comment:github.com/acme/widgets#42/comment/9200": "2026-09-06T12:59:00Z", "pull_request:github.com/acme/widgets#42": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/42#issuecomment-9200"},
  {"schema_version": "1", "key": "checks.required", "class": "checks", "status": "ESTABLISHED",
   "value": {"head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "required": ["doctor", "tests"], "results": [{"name": "doctor", "state": "success"}, {"name": "tests", "state": "pending"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "ruleset:github.com/acme/widgets"],
   "versions": {"head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "ruleset:github.com/acme/widgets": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/commit/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/checks"},
  {"schema_version": "1", "key": "acceptance.contract", "class": "acceptance", "status": "ESTABLISHED",
   "value": {"contract": "github.com/acme/widgets#41", "head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "items": [{"id": "a1", "state": "MET"}, {"id": "a2", "state": "NOT_MET"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41", "head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z", "head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "repair", "because": ["review.independent"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;head.exact@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;review.independent@2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T13:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
   "versions": {"head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
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
   "versions": {"repository:github.com/acme/widgets": "2026-09-01T08:00:00Z"},
   "provenance": "https://github.com/acme/widgets"},
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "ESTABLISHED",
   "value": {"head": "cccccccccccccccccccccccccccccccccccccccc", "base_ref": "master", "base": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "current": true},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42", "version": "cccccccccccccccccccccccccccccccccccccccc"},
   "observed_at": "2026-09-06T14:00:00Z", "invalidators": ["head:cccccccccccccccccccccccccccccccccccccccc", "ref:github.com/acme/widgets/master", "pull_request:github.com/acme/widgets#42"],
   "versions": {"head:cccccccccccccccccccccccccccccccccccccccc": "cccccccccccccccccccccccccccccccccccccccc", "ref:github.com/acme/widgets/master": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "pull_request:github.com/acme/widgets#42": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/42/commits"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "ESTABLISHED",
   "value": {"verdict": "CHANGES REQUIRED", "head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "reviewer": "login:github-actions[bot]", "record": "github.com/acme/widgets#42/comment/9200"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#42/comment/9200", "version": "2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T14:00:00Z", "invalidators": ["head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "comment:github.com/acme/widgets#42/comment/9200", "pull_request:github.com/acme/widgets#42"],
   "versions": {"head:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "comment:github.com/acme/widgets#42/comment/9200": "2026-09-06T12:59:00Z", "pull_request:github.com/acme/widgets#42": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/42#issuecomment-9200"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "wait-review", "because": ["head.exact", "review.independent"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;head.exact@cccccccccccccccccccccccccccccccccccccccc;review.independent@2026-09-06T12:59:00Z"},
   "observed_at": "2026-09-06T14:00:00Z", "invalidators": ["head:cccccccccccccccccccccccccccccccccccccccc"],
   "versions": {"head:cccccccccccccccccccccccccccccccccccccccc": "cccccccccccccccccccccccccccccccccccccccc"},
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
   "observed_at": "2026-09-06T15:00:00Z", "invalidators": ["head:dddddddddddddddddddddddddddddddddddddddd", "comment:github.com/acme/widgets#42/comment/9300", "comment:github.com/acme/widgets#42/comment/9301", "pull_request:github.com/acme/widgets#42"],
   "versions": {"head:dddddddddddddddddddddddddddddddddddddddd": "dddddddddddddddddddddddddddddddddddddddd", "comment:github.com/acme/widgets#42/comment/9300": "2026-09-05T18:00:00Z", "comment:github.com/acme/widgets#42/comment/9301": "2026-09-05T18:00:00Z", "pull_request:github.com/acme/widgets#42": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/42",
   "detail": {"reason": "two trusted verdict records for the same HEAD disagree", "candidates": ["github.com/acme/widgets#42/comment/9300", "github.com/acme/widgets#42/comment/9301"]}},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "stop-decision-required", "because": ["review.independent"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;review.independent@dddddddddddddddddddddddddddddddddddddddd"},
   "observed_at": "2026-09-06T15:00:00Z", "invalidators": ["head:dddddddddddddddddddddddddddddddddddddddd"],
   "versions": {"head:dddddddddddddddddddddddddddddddddddddddd": "dddddddddddddddddddddddddddddddddddddddd"},
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
   "versions": {"pull_request:github.com/acme/widgets#42": "2026-09-06T16:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/42"},
  {"schema_version": "1", "key": "graph.native", "class": "graph", "status": "ESTABLISHED",
   "value": {"parent": {"kind": "issue", "id": "github.com/acme/program#42", "state": "open"}, "children": [], "blocked_by": [{"kind": "issue", "id": "github.com/acme/widgets#39", "state": "open"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-06T15:30:00Z"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/program#42", "issue:github.com/acme/widgets#39"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-06T15:30:00Z", "issue:github.com/acme/program#42": "2026-09-05T18:00:00Z", "issue:github.com/acme/widgets#39": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine"]}],
             "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "authority:grant"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "2026-09-01T09:00:00Z"},
   "observed_at": "2026-09-06T16:00:05Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001", "issue:github.com/acme/widgets#7"],
   "versions": {"comment:github.com/acme/widgets#7/comment/9001": "2026-09-01T09:00:00Z", "issue:github.com/acme/widgets#7": "2026-09-05T18:00:00Z"},
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
   "versions": {"pull_request:github.com/acme/widgets#43": "2026-09-06T16:50:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/43"},
  {"schema_version": "1", "key": "repository.identity", "class": "repository", "status": "ESTABLISHED",
   "value": {"id": "github.com/acme/widgets", "default_branch": "master"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "2026-09-01T08:00:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["repository:github.com/acme/widgets"],
   "versions": {"repository:github.com/acme/widgets": "2026-09-01T08:00:00Z"},
   "provenance": "https://github.com/acme/widgets"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine"]}], "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "placement:release"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}, {"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "settings:repository"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "2026-09-01T09:00:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001", "issue:github.com/acme/widgets#7"],
   "versions": {"comment:github.com/acme/widgets#7/comment/9001": "2026-09-01T09:00:00Z", "issue:github.com/acme/widgets#7": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"},
  {"schema_version": "1", "key": "placement.current", "class": "placement", "status": "ESTABLISHED",
   "value": {"milestone": "github.com/acme/widgets/milestone/8", "release": "v1.2.0", "gate": "none"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#43", "version": "2026-09-06T16:50:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["pull_request:github.com/acme/widgets#43", "milestone:github.com/acme/widgets/milestone/8"],
   "versions": {"pull_request:github.com/acme/widgets#43": "2026-09-06T16:50:00Z", "milestone:github.com/acme/widgets/milestone/8": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/pull/43"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "stop-decision-required", "because": ["authority.standing", "placement.current", "repository.identity", "work_unit.identity"], "boundary": "placement:release"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;authority.standing@2026-09-01T09:00:00Z;placement.current@2026-09-06T16:50:00Z;repository.identity@2026-09-01T08:00:00Z;work_unit.identity@2026-09-06T16:50:00Z"},
   "observed_at": "2026-09-06T17:00:00Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001", "pull_request:github.com/acme/widgets#43", "milestone:github.com/acme/widgets/milestone/8", "repository:github.com/acme/widgets"],
   "versions": {"comment:github.com/acme/widgets#7/comment/9001": "2026-09-01T09:00:00Z", "pull_request:github.com/acme/widgets#43": "2026-09-06T16:50:00Z", "milestone:github.com/acme/widgets/milestone/8": "2026-09-05T18:00:00Z", "repository:github.com/acme/widgets": "2026-09-01T08:00:00Z"},
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
   "versions": {"head:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "ruleset:github.com/acme/widgets": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/commit/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee/checks",
   "detail": {"reason": "check-runs endpoint returned HTTP 403 for the observing identity", "candidates": []}},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "ESTABLISHED",
   "value": {"action": "wait-review", "because": ["checks.required"], "boundary": "none"},
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;checks.required@eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"},
   "observed_at": "2026-09-06T18:00:00Z", "invalidators": ["head:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"],
   "versions": {"head:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"},
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
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T12:00:05Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z"},
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
{"observer": {"login": "login:acme-orchestrator[bot]", "permission": "write", "checked_at": "2026-09-06T19:00:00Z"},
 "facts": [
  {"schema_version": "1", "key": "work_unit.identity", "class": "work_unit", "status": "ESTABLISHED",
   "value": {"kind": "issue", "id": "github.com/acme/widgets#41", "implements": "none"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "repository.identity", "class": "repository", "status": "ESTABLISHED",
   "value": {"id": "github.com/acme/widgets", "default_branch": "master"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets", "version": "2026-09-01T08:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["repository:github.com/acme/widgets"],
   "versions": {"repository:github.com/acme/widgets": "2026-09-01T08:00:00Z"},
   "provenance": "https://github.com/acme/widgets"},
  {"schema_version": "1", "key": "placement.current", "class": "placement", "status": "ESTABLISHED",
   "value": {"milestone": "github.com/acme/widgets/milestone/7", "release": "none", "gate": "github.com/acme/widgets#40"},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41", "milestone:github.com/acme/widgets/milestone/7"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z", "milestone:github.com/acme/widgets/milestone/7": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "graph.native", "class": "graph", "status": "ESTABLISHED",
   "value": {"parent": {"kind": "issue", "id": "github.com/acme/widgets#40", "state": "open"}, "children": [], "blocked_by": [{"kind": "issue", "id": "github.com/acme/widgets#39", "state": "closed"}]},
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41", "issue:github.com/acme/widgets#40", "issue:github.com/acme/widgets#39"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z", "issue:github.com/acme/widgets#40": "2026-09-05T18:00:00Z", "issue:github.com/acme/widgets#39": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "authority.standing", "class": "authority", "status": "ESTABLISHED",
   "value": {"grants": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "scopes": ["merge:routine"]}], "human_boundaries": [{"decision": "github.com/acme/widgets#7/comment/9001", "target": "github.com/acme/widgets", "boundary": "release:approve"}]},
   "source": {"type": "human-decision", "identity": "github.com/acme/widgets#7/comment/9001", "version": "2026-09-01T09:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["comment:github.com/acme/widgets#7/comment/9001", "issue:github.com/acme/widgets#7"],
   "versions": {"comment:github.com/acme/widgets#7/comment/9001": "2026-09-01T09:00:00Z", "issue:github.com/acme/widgets#7": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/7#issuecomment-9001"},
  {"schema_version": "1", "key": "acceptance.contract", "class": "acceptance", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "head.exact", "class": "head", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "review.independent", "class": "review", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "checks.required", "class": "checks", "status": "NOT_APPLICABLE",
   "source": {"type": "github-api", "identity": "github.com/acme/widgets#41", "version": "2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z"},
   "provenance": "https://github.com/acme/widgets/issues/41"},
  {"schema_version": "1", "key": "next_action.governed", "class": "next_action", "status": "UNKNOWN",
   "source": {"type": "derived", "identity": "fact-model/1", "version": "1;head.exact@2026-09-05T18:00:00Z"},
   "observed_at": "2026-09-06T19:00:00Z", "invalidators": ["issue:github.com/acme/widgets#41"],
   "versions": {"issue:github.com/acme/widgets#41": "2026-09-05T18:00:00Z"},
   "provenance": "preferences/fact-model.tsv",
   "inputs": ["head.exact"],
   "detail": {"reason": "no next action is derivable for a work unit without a HEAD in this version", "candidates": []}}
]}
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
