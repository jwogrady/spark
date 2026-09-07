# Reference — freshness, invalidation and conflict

> Reference — information-oriented.

An operative fact ([fact-model.md](fact-model.md)) is only worth compiling if a
consumer can tell, mechanically, whether it is still true. This page defines
**when a fact is stale**, **what a consumer does when a source cannot be re-read**,
and **how conflicting evidence resolves** — by identity and version, never by
age or by judgment. The machine-readable authority is
`preferences/fact-freshness.tsv` (contract version 1, written against fact-model
schema version 1); this page renders it, never the other way round, and the
behavioral suite `tests/test-fact-freshness.sh` checks the page against the
authority, derives the matrix below from the event and class records, and
executes every scenario against Example 1 of the fact model. The contract is
**Experimental**, like the model it governs.

## Events

An event is a change at an authoritative source. Each event record names the
invalidator kinds it fires; a fact is stale exactly when an event fires a token
it carries (F2). Two events fire no token: a check run at the same HEAD, which
is re-read on observation (F10), and the two whose effect is UNKNOWN for every
fact — a schema change and an unreadable source.

| Event | Fires | Observed as | Meaning |
|---|---|---|---|
| `push` | `head` | the pull request's head commit differs from the head: token | A pull request's HEAD moves — a new commit, a rebase or a force-push. Every fact carrying head:<old> is stale; nothing judged on the old HEAD is reused for the new one. |
| `base-move` | `ref` | the base branch's target commit differs from the head fact's base | The base branch the work unit targets moves. Facts carrying ref:<repository>/<base_ref> are stale: the head fact's base commit and the merge picture change while the HEAD stands. |
| `metadata` | `issue,pull_request` | the node's updated_at is later than the fact's source.version, or the node is closed, reopened, transferred or deleted | An issue's or pull request's title, body, state, labels, assignees, milestone or native relationships change. Facts carrying issue:/pull_request:<that node> are stale. |
| `comment` | `comment` | the comment's updated_at is later than the fact's source.version, or the comment is gone | A comment that records a verdict or a decision is created, edited or deleted. Facts carrying comment:<that comment> are stale; a new comment is also a metadata event of its node. |
| `relationship` | `issue,pull_request,milestone` | a parent, child, blocker or milestone listed by the fact changes state or membership | A parent, child, blocker or milestone relationship changes. The graph and placement facts that list the related node or the milestone are stale. |
| `check-run` | `none` | the check-runs listing for the HEAD (latest per name) differs from results, or any result is non-terminal | A check run or workflow run at the HEAD completes, is re-run or is requested. No token changes — the HEAD is the same — so the checks fact is re-read on observation: a non-terminal result is never carried forward and a terminal one is re-read when a merge decision is derived. |
| `ruleset` | `ruleset` | the repository's rulesets or the required-check set differ from required | The repository's rulesets change which checks are required. The checks fact for every open work unit carries ruleset:<repository> and is stale. |
| `repository` | `repository` | the repository's updated_at, default branch, settings or the observing identity's permission differ from what was read | Repository settings, default branch or permissions change. Facts carrying repository:<repository> are stale; a permission loss also makes the next read of any node UNKNOWN (unreadable records). |
| `schema` | `none` | the snapshot's schema_version differs from the consumer's fact-model version, or the compiler that derived a fact changed its version | The fact model's schema version or the compiler's interpretation changes. Every fact of the snapshot is UNKNOWN to that consumer (R9); the snapshot is recompiled, never migrated in place. |
| `unreadable` | `none` | a read of the source fails: permission denied, not found, rate-limited, timed out, or malformed | An authoritative source cannot be re-read. The fact takes the status the unreadable record assigns, with detail.reason naming the failure; the previous value is never reused as authority. |

## What each class carries

The fact model states in R7 and R17 which tokens each class lists; this table
is that statement as data, so the matrix can be derived from it. Every fact on
the fact-model page carries only kinds its class declares, and every declared
kind appears on at least one fact there (the suite checks both).

| Class | Invalidator kinds | Why |
|---|---|---|
| `work_unit` | `issue,pull_request` | its own node, under the node's kind (R17) |
| `repository` | `repository` | the repository node it describes (R17) |
| `placement` | `issue,pull_request,milestone` | the work unit it was read from and the milestone it is placed in |
| `graph` | `issue,pull_request` | the node it was read from and every parent, child and blocker it represents, each under its kind (R17) |
| `authority` | `comment` | the decision record each grant and boundary rests on (R5, R17); permissions are not a source of authority |
| `acceptance` | `head,issue` | the exact HEAD it was judged on (R7) and the contract's node |
| `head` | `head,ref,issue` | the exact HEAD (R7), the base branch whose target the merge picture depends on, and — with no HEAD — the issue it was read from |
| `review` | `head,comment,issue` | the exact HEAD (R7), the verdict record (R17), and — with no HEAD — the issue |
| `checks` | `head,ruleset,issue` | the exact HEAD (R7), the rulesets that decide which checks are required, and — with no HEAD — the issue |
| `next_action` | `inputs` | derived: it may carry any token of its inputs' kinds — at least the HEAD it was derived at — and it re-derives when any input's version changes, because its own version binds every input's (R4, R15) |

## Effects

| Effect | Meaning |
|---|---|
| `stale` | an event fires a token the fact carries: the fact is not usable until re-read from its source |
| `re-read` | no token changes but the source can have changed at the same identity: the fact is re-read on observation |
| `derived` | an input of the derived fact is stale or re-read: the fact is re-derived from re-read inputs (R4, R15), never patched |
| `unknown` | the fact is UNKNOWN to the consumer until the source is re-read or the snapshot recompiled (R9, unreadable records) |
| `none` | the event cannot change the fact: no token it carries fires |

## The class × event matrix

Derived (F2): a cell is `stale` when the event fires a kind the class carries,
`re-read` for a check run against the checks fact, `derived` for `next_action`
whenever any input is stale or re-read, `unknown` for a schema change or an
unreadable source, `none` otherwise. The suite recomputes every cell from the
event and class records and fails on any hand edit.

| Class | `push` | `base-move` | `metadata` | `comment` | `relationship` | `check-run` | `ruleset` | `repository` | `schema` | `unreadable` |
|---|---|---|---|---|---|---|---|---|---|---|
| `work_unit` | `none` | `none` | `stale` | `none` | `stale` | `none` | `none` | `none` | `unknown` | `unknown` |
| `repository` | `none` | `none` | `none` | `none` | `none` | `none` | `none` | `stale` | `unknown` | `unknown` |
| `placement` | `none` | `none` | `stale` | `none` | `stale` | `none` | `none` | `none` | `unknown` | `unknown` |
| `graph` | `none` | `none` | `stale` | `none` | `stale` | `none` | `none` | `none` | `unknown` | `unknown` |
| `authority` | `none` | `none` | `none` | `stale` | `none` | `none` | `none` | `none` | `unknown` | `unknown` |
| `acceptance` | `stale` | `none` | `stale` | `none` | `stale` | `none` | `none` | `none` | `unknown` | `unknown` |
| `head` | `stale` | `stale` | `stale` | `none` | `stale` | `none` | `none` | `none` | `unknown` | `unknown` |
| `review` | `stale` | `none` | `stale` | `stale` | `stale` | `none` | `none` | `none` | `unknown` | `unknown` |
| `checks` | `stale` | `none` | `stale` | `none` | `stale` | `re-read` | `stale` | `none` | `unknown` | `unknown` |
| `next_action` | `derived` | `derived` | `derived` | `derived` | `derived` | `derived` | `derived` | `derived` | `unknown` | `unknown` |

## Conflicting and duplicate evidence

| Situation | Outcome | Detail | Rule |
|---|---|---|---|
| `disagreeing-authorities` | `CONFLICT` | reason names the disagreement; candidates list every record's identity | Two authoritative inputs disagree (two trusted verdict records for one HEAD, two decision records for one grant): CONFLICT with both named; no first-write, last-write or plausibility rule chooses (R8). |
| `malformed-beside-valid` | `CONFLICT` | reason names the malformation; candidates list the malformed and the valid record | A record that does not parse or does not canonicalize stands beside a valid one for the same fact: CONFLICT, because the model cannot know which the author meant (status CONFLICT). |
| `duplicates-agree` | `ESTABLISHED` | no detail; source.identity is the earliest record; every duplicate is listed as an invalidator | Two or more records for one fact say the same thing: ESTABLISHED from the earliest durable record, every duplicate carried as a comment: token so an edit to any of them fires. |
| `noncanonical-identity` | `canonicalized` | no detail; the fact carries the canonical spelling | A source spells an identity in a projection (upper-case owner, refs/heads/ prefix, .git suffix, a bare issue number): the compiler emits the one canonical representation (R1); a record whose identity does not canonicalize to one representation is malformed evidence. |
| `other-head` | `historical` | no fact of the current snapshot; the record stays reachable through provenance | Evidence judged on another HEAD (a PASS for head:A when the HEAD is B) is historical: its head: token names the other HEAD, it never enters the current fact and it never conflicts with current evidence (Example 3 of the fact model). |
| `other-work-unit` | `historical` | no fact of the current snapshot; the record stays reachable through provenance | Evidence that belongs to another work unit (a grant targeting another repository, a review on another pull request) is historical for this snapshot: it is distinguishable by its work-unit token and confers nothing here (Example 6 of the fact model). |

## Unreadable sources

| Failure | Status | detail.reason | Rule |
|---|---|---|---|
| `permission-denied` | `UNKNOWN` | HTTP 401 or 403 for the observing identity, with the endpoint | The observing identity may not read the source: UNKNOWN, never a permissive default and never the previous value (Example 7 of the fact model). |
| `not-found` | `UNKNOWN` | HTTP 404 with the node or record identity | The node or record is gone, transferred or never existed: UNKNOWN; a decision or verdict whose record is gone confers nothing. |
| `rate-limited` | `UNKNOWN` | HTTP 429, or 403 with a rate-limit header, with the reset time | The source refused the read for now: UNKNOWN until a later read; the consumer schedules the retry, the fact does not pretend. |
| `timeout` | `UNKNOWN` | the transport error, with the endpoint | The read did not complete: UNKNOWN; a partial response is no response. |
| `malformed-alone` | `UNKNOWN` | the parse or canonicalization failure, with the record identity in candidates | The only record for a fact does not parse or does not canonicalize: UNKNOWN with the record named, so an auditor can drill down; beside a valid record it is a CONFLICT instead. |

## Schema and compiler versions

| From | To | Rule |
|---|---|---|
| `1` | `1` | A consumer at fact-model schema version 1 reads only snapshots with schema_version 1. Any other version makes every fact UNKNOWN to it (R9). Nothing is migrated in place: a snapshot is recompiled by a compiler of the consumer's version. A compiler change that alters how a fact is interpreted is a new schema version, so the version string of every derived fact changes with it (R4). |

## Scenarios

Each scenario applies one fired token to Example 1 of the fact model — the
complete snapshot of a normal pull request — and lists the facts that become
stale, then the derived fact that follows because a stale fact is among its inputs. The suite executes them: it loads the
example, marks every fact carrying the fired token, checks the set against this
table, and checks it against the matrix column for the event.

| Scenario | Event | Fired token | Stale; derived | Note |
|---|---|---|---|---|
| `push` | `push` | `head:0123456789abcdef0123456789abcdef01234567` | `acceptance,head,review,checks;next_action` | Example 1 after a new commit: the four HEAD-bound facts are stale and next_action is re-derived; work_unit, repository, placement, graph and authority stand. |
| `verdict-edit` | `comment` | `comment:github.com/acme/widgets#42/comment/9100` | `review;next_action` | The verdict record is edited: only the review fact is stale (and the derived action); the HEAD, checks and acceptance stand. |
| `decision-edit` | `comment` | `comment:github.com/acme/widgets#7/comment/9001` | `authority;next_action` | The standing decision record is edited: the authority fact is stale and the derived action with it; nothing HEAD-bound moves. |
| `base-move` | `base-move` | `ref:github.com/acme/widgets/master` | `head;next_action` | master moves under the pull request: the head fact (its base commit) is stale; the review, checks and acceptance at the HEAD stand. |
| `gate-edit` | `metadata` | `issue:github.com/acme/widgets#41` | `placement,graph,acceptance;next_action` | The implemented issue's metadata changes: placement, graph and the acceptance contract read from it are stale. |
| `ruleset` | `ruleset` | `ruleset:github.com/acme/widgets` | `checks;next_action` | The repository's rulesets change: the checks fact is stale (which checks are required may have changed). |
| `repository` | `repository` | `repository:github.com/acme/widgets` | `repository;next_action` | Repository settings change: the repository fact is stale; authority stands (it rests on decision records, not permissions). |

## Rules

Rendered verbatim from the `rule` records of `preferences/fact-freshness.tsv`;
the behavioral suite checks the two never drift.

- **F1** Freshness is decided by identity, never by age. A fact is current while
  every token it carries names an unchanged node and its source.version is the
  source's current version; a time-based check may trigger a re-read but never
  keeps a fact current.
- **F2** An event fires the invalidator kinds its event record lists. A fact is
  stale exactly when an event fires a token it carries; the class × event matrix
  is derived from the class kinds and the event kinds and is never edited by
  hand.
- **F3** A stale fact is not usable as authority. It is re-read from its source,
  and the re-read yields ESTABLISHED, UNKNOWN, CONFLICT or NOT_APPLICABLE per
  the fact model; the previous value survives only as provenance.
- **F4** A derived fact is re-derived whenever any input is stale or re-read
  (R4, R15); it is never patched, and its version string changes with any
  input's version.
- **F5** A source that cannot be re-read yields the status its unreadable record
  assigns, with detail.reason naming the failure and detail.candidates naming
  what could be seen. The old value never survives as authority: there is no
  stale authoritative reuse.
- **F6** Conflicts resolve only by the conflict records: both candidates named,
  no first-write, no last-write, no plausibility (R8). A released contract may
  add a precedence rule; the model never infers one.
- **F7** Evidence for another HEAD or another work unit is historical,
  distinguishable by its head: or work-unit token; it never enters the current
  fact and never competes with current evidence.
- **F8** A schema or compiler version mismatch makes every fact UNKNOWN to the
  consumer (R9). There is no in-place migration in this version; a snapshot is
  recompiled.
- **F9** Provenance is a pointer (R2, R3, R16). Deciding freshness reads tokens
  and versions in the snapshot, never history; drill-down loads the source on
  demand.
- **F10** Checks are observation-fresh at a HEAD: a non-terminal result is never
  carried into a snapshot that decides an action, and a terminal result is
  re-read when a merge decision is derived, because a check can be re-run at the
  same HEAD without any token changing.
- **F11** Cached or inferred capability never becomes authority (R5). An
  authority fact changes only through its decision records; a permission change
  makes reads UNKNOWN, it grants nothing.

## Relation to the rest of the model

This contract adds no field to the envelope: it reads `invalidators`,
`source.version`, `observed_at`, `status` and `detail` as the fact model defines
them. It is versioned with the model — a new fact-model schema version is a new
contract version — and it changes how nothing is stored: `.spark/state.json`
stays the committed work state ([state.md](state.md)), and mutable GitHub truth
is re-read from its source (R10).
