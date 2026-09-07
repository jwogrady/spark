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
fact — a schema change and an unreadable source. A record lists the *kinds* an
event can fire; the observation decides which tokens fire (F1, F2).

| Event | Fires | Observed as | Meaning |
|---|---|---|---|
| `push` | `head` | the pull request's current head commit differs from the recorded head: token (its version is the commit itself) | A pull request's HEAD moves — a new commit, a rebase or a force-push. Every fact carrying head:<old> is stale; nothing judged on the old HEAD is reused for the new one. |
| `base-move` | `ref` | the base branch's current target commit differs from versions[ref:…], the target recorded when the fact was read | The base branch the work unit targets moves. Facts carrying ref:<repository>/<base_ref> are stale: the head fact's base commit and the merge picture change while the HEAD stands. |
| `metadata` | `issue,pull_request` | the node's current updated_at differs from versions[issue:…] or versions[pull_request:…], or the node is gone | An issue's or pull request's title, body, state, labels, assignees, milestone or native relationships change. Facts carrying issue:/pull_request:<that node> are stale. |
| `comment-edit` | `comment` | the comment's current updated_at differs from versions[comment:…], or the comment is gone | A comment that records a verdict or a decision is edited or deleted: comment:<that comment> fires for every fact that recorded it. |
| `comment-created` | `issue,pull_request` | the node's current updated_at differs from versions[issue:…] or versions[pull_request:…] because a comment was added | A comment is created on an issue or pull request. No fact can carry the new comment's token, so the node's own token fires — a fact whose value depends on which records a node carries lists that node (fact model R17), and reads it again to find the new record. |
| `relationship` | `issue,pull_request,milestone` | the current updated_at of a listed node or milestone differs from the version recorded for its token | A parent, child, blocker or milestone relationship changes. The graph and placement facts that list the related node or the milestone are stale. |
| `check-run` | `none` | the check-runs listing for the HEAD (latest per name) differs from results, or any result is non-terminal | A check run or workflow run at the HEAD completes, is re-run or is requested. No token changes — the HEAD is the same — so the checks fact is re-read on observation: a non-terminal result is never carried forward and a terminal one is re-read when a merge decision is derived. |
| `ruleset` | `ruleset` | the digest of the repository's current rulesets — sorted lines <ruleset id>@<updated_at>, newline-terminated, SHA-256 — differs from versions[ruleset:…] (the collection record); creating or deleting a ruleset changes it even when every remaining ruleset's updated_at stands | The repository's rulesets change which checks are required. The checks fact for every open work unit carries ruleset:<repository> and is stale. |
| `repository` | `repository` | the repository's current updated_at differs from versions[repository:…], or the observer's permission, re-read before the snapshot is used, differs from the snapshot's observer record (fact model R21) | Repository settings, the default branch or the observing identity's permission change. Facts carrying repository:<repository> are stale, and every other source-read fact of the set is re-read (F13): readability was a property of the snapshot, and after a permission loss each re-read yields UNKNOWN (unreadable records). |
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
| `authority` | `comment,issue,pull_request` | the decision record each grant and boundary rests on and the node carrying it, so a record posted later reaches the fact (R5, R17); permissions are not a source of authority |
| `acceptance` | `head,issue` | the exact HEAD it was judged on (R7) and the contract's node |
| `head` | `head,ref,pull_request,issue` | the exact HEAD (R7), the base branch whose target the merge picture depends on, the pull request whose base selection it read (a base-branch switch moves no tip), and — with no HEAD — the issue it was read from |
| `review` | `head,comment,pull_request,issue` | the exact HEAD (R7), the verdict record and the pull request whose comments hold the verdicts, so a verdict posted later reaches the fact (R17), and — with no HEAD — the issue |
| `checks` | `head,ruleset,issue` | the exact HEAD (R7), the rulesets that decide which checks are required, and — with no HEAD — the issue |
| `next_action` | `inputs` | derived: it may carry any token of its inputs' kinds — at least the HEAD it was derived at — and it re-derives when any input's version changes, because its own version binds every input's (R4, R15) |

## Collection versions

GitHub versions each ruleset, never the set a repository carries, so the
`ruleset:` token cannot record a node's `updated_at`. It records the digest of
the membership with each member's version (F14); the fact model's `digest`
identifier is its grammar. A ruleset created or deleted changes the digest even
when every remaining ruleset's timestamp stands — the failure a "latest
timestamp" rule would miss. Example 1 records the digest of the membership
below; the suite recomputes it.

| Token kind | Algorithm | Example 1 membership | Why |
|---|---|---|---|
| `ruleset` | SHA-256, hex-encoded, over the sorted lines <ruleset id>@<updated_at>, each newline-terminated (printf '%s\n' … \| sort \| sha256sum) | `1001@2026-09-01T08:00:00Z;1002@2026-08-15T09:00:00Z` | GitHub versions each ruleset, never the set; a digest of the membership with each member's version changes when a ruleset is created, deleted or edited, even when every remaining timestamp stands |

## What can change each fact

Each class names the events that can change its value. The suite checks that
every one of them reaches the class in the matrix below — as `stale` or
`re-read`, `derived` for the derived class — so no change a fact depends on can
leave a cached fact authoritative (F12). This is why a review lists its pull
request and an authority fact the node of its decision records: a record
created after the fact was read fires a token the fact already carries.

| Class | Value changes on | Why |
|---|---|---|
| `work_unit` | `metadata` | its kind, id and what it implements are pull-request metadata |
| `repository` | `repository` | its default branch and identity are repository settings |
| `placement` | `metadata,relationship` | milestone, release and gate placement are node metadata and relationships |
| `graph` | `metadata,relationship` | parents, children and blockers are relationships; their states are node metadata |
| `authority` | `comment-edit,comment-created` | grants and boundaries are decision records: comments edited or deleted, or a new decision comment on the node |
| `acceptance` | `push,metadata` | the judged HEAD moves, or the contract's criteria are edited on the issue |
| `head` | `push,base-move,metadata` | the HEAD moves, the base tip moves, or the pull request's base branch is switched |
| `review` | `push,comment-edit,comment-created` | the judged HEAD moves, a verdict record is edited or deleted, or a new verdict comment appears on the pull request |
| `checks` | `push,check-run,ruleset` | the HEAD moves, a check runs or re-runs at the HEAD, or the required set changes |
| `next_action` | `push,base-move,metadata,comment-edit,comment-created,relationship,check-run,ruleset,repository` | derived from every required class: any event that moves an input re-derives it |

## Effects

| Effect | Meaning |
|---|---|
| `stale` | an event fires a token the fact carries: the fact is not usable until re-read from its source |
| `re-read` | no token of the fact fires, but the source can have changed at the same identity (a check run at the HEAD) or the set's readability has changed (a repository event, F13): the fact is re-read before it is used |
| `derived` | an input of the derived fact is stale or re-read: the fact is re-derived from re-read inputs (R4, R15), never patched |
| `unknown` | the fact is UNKNOWN to the consumer until the source is re-read or the snapshot recompiled (R9, unreadable records) |
| `none` | the event cannot change the fact: no token it carries fires |

## The class × event matrix

The matrix states **reachability** (F2): a cell is `stale` when the event fires a
kind the class carries, so the event *can* reach the class — which facts of that
class are actually stale is decided by the observation, token by token (the
scenarios below show `metadata` on the implemented issue reaching placement,
graph and acceptance while the same event on the pull request reaches
work_unit, head and review). A cell is
`re-read` for a check run against the checks fact and, under F13, for every
source-read class on a repository event; `derived` for `next_action` whenever
any input is stale or re-read; `unknown` for a schema change or an unreadable
source; `none` otherwise. The suite recomputes every cell from the
event and class records and fails on any hand edit.

| Class | `push` | `base-move` | `metadata` | `comment-edit` | `comment-created` | `relationship` | `check-run` | `ruleset` | `repository` | `schema` | `unreadable` |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `work_unit` | `none` | `none` | `stale` | `none` | `stale` | `stale` | `none` | `none` | `re-read` | `unknown` | `unknown` |
| `repository` | `none` | `none` | `none` | `none` | `none` | `none` | `none` | `none` | `stale` | `unknown` | `unknown` |
| `placement` | `none` | `none` | `stale` | `none` | `stale` | `stale` | `none` | `none` | `re-read` | `unknown` | `unknown` |
| `graph` | `none` | `none` | `stale` | `none` | `stale` | `stale` | `none` | `none` | `re-read` | `unknown` | `unknown` |
| `authority` | `none` | `none` | `stale` | `stale` | `stale` | `stale` | `none` | `none` | `re-read` | `unknown` | `unknown` |
| `acceptance` | `stale` | `none` | `stale` | `none` | `stale` | `stale` | `none` | `none` | `re-read` | `unknown` | `unknown` |
| `head` | `stale` | `stale` | `stale` | `none` | `stale` | `stale` | `none` | `none` | `re-read` | `unknown` | `unknown` |
| `review` | `stale` | `none` | `stale` | `stale` | `stale` | `stale` | `none` | `none` | `re-read` | `unknown` | `unknown` |
| `checks` | `stale` | `none` | `stale` | `none` | `stale` | `stale` | `re-read` | `stale` | `re-read` | `unknown` | `unknown` |
| `next_action` | `derived` | `derived` | `derived` | `derived` | `derived` | `derived` | `derived` | `derived` | `derived` | `unknown` | `unknown` |

## Conflicting and duplicate evidence

| Situation | Outcome | Detail | Rule |
|---|---|---|---|
| `disagreeing-authorities` | `CONFLICT` | reason names the disagreement; candidates list every record's identity | Two authoritative inputs disagree (two trusted verdict records for one HEAD, two decision records for one grant): CONFLICT with both named; no first-write, last-write or plausibility rule chooses (R8). |
| `malformed-beside-valid` | `CONFLICT` | reason names the malformation; candidates list the malformed and the valid record | A record that does not parse or does not canonicalize stands beside a valid one for the same fact: CONFLICT, because the model cannot know which the author meant (status CONFLICT). |
| `duplicates-agree` | `ESTABLISHED` | no detail; source.identity is the earliest record; every duplicate is listed as an invalidator | Two or more records for one fact say the same thing: ESTABLISHED from the earliest durable record, every duplicate carried as a comment: token so an edit to any of them fires. |
| `noncanonical-identity` | `canonicalized` | no detail; the fact carries the canonical spelling | A source spells an identity in a projection (upper-case owner, refs/heads/ prefix, .git suffix, a bare issue number): the compiler emits the one canonical representation (R1); a record whose identity does not canonicalize to one representation is malformed evidence. |
| `other-head` | `historical` | no fact of the current snapshot; the record stays reachable through provenance | Evidence judged on another HEAD (a PASS for head:A when the HEAD is B) is historical: its head: token names the other HEAD, it never enters the current fact and it never conflicts with current evidence (Example 3 of the fact model). |
| `duplicate-fields` | `malformed` | alone: UNKNOWN with the record in candidates; beside a valid record: CONFLICT | A record that carries the same field twice (two id fields, two status fields) is malformed before parsing, whatever the values: alone it follows the malformed-alone unreadable record, beside a valid record the malformed-beside-valid conflict record. A consumer that keeps the first or the last duplicate is not conforming (fact model R14). |
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
| `1` | `1` | A consumer at fact-model schema version 1 reads only snapshots with schema_version 1. Any other version makes every fact UNKNOWN to it (R9). Nothing is migrated in place: a snapshot is recompiled by a compiler of the consumer's version. Once a version has shipped in a Spark release, a compiler change that alters how a fact is interpreted is a new schema version, so the version string of every derived fact changes with it (R4); until it ships, the version is corrected in place and the release that ships it fixes it (fact model R19). |

## The observer

A complete snapshot records who read it: `observer` — the login, its
repository permission in GitHub's closed vocabulary (`admin`, `maintain`,
`write`, `triage`, `read`, `none`) and when the permission was checked (fact
model R21). Readability is a property of the snapshot (F13): before a cached
snapshot is used, the observer's permission is re-read and compared with the
record, and a difference is a `repository` event. That is the one mechanical
check that turns "permission differs from what was read" into a comparison the
consumer can make from the cached snapshot alone.

## Scenarios

Each scenario is an **observation** against Example 1 of the fact model — the
complete snapshot of a normal pull request: the current version of one or more
nodes (`token=version`) and, where it matters, the observer's re-read permission.
The fired tokens are **derived** from the observation and the versions Example 1
recorded (F1, F13), never handed to the check; the table then lists the facts
that become stale, the facts re-read under F13, and the derived fact that
follows because a moved fact is among its inputs. The `unchanged` row is the
control: an observation equal to the record fires nothing. The suite derives
every row again from the page's own example; the stale sets here are computed
when the page is built, never typed. The suite executes them: it loads the
example, marks every fact carrying the fired token, checks the set against this
table, and checks it against the matrix column for the event.

| Scenario | Event | Observation | Stale; re-read; derived | Note |
|---|---|---|---|---|
| `push` | `push` | `head:0123456789abcdef0123456789abcdef01234567=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` | `acceptance,head,review,checks;;next_action` | The pull request's head is now another commit: the recorded head: token no longer names it, so the four HEAD-bound facts are stale and next_action is re-derived; work_unit, repository, placement, graph and authority stand. |
| `verdict-edit` | `comment-edit` | `comment:github.com/acme/widgets#42/comment/9100=2026-09-06T12:10:00Z` | `review;;next_action` | The verdict record's updated_at moved: the review fact is stale and the derived action with it; HEAD, checks and acceptance stand. |
| `verdict-created` | `comment-created` | `pull_request:github.com/acme/widgets#42=2026-09-06T12:10:00Z` | `work_unit,head,review;;next_action` | A new verdict comment on the pull request moved the pull request's updated_at: no fact carries the new comment's token, but every fact that recorded the pull request's version — the review among them — sees the difference and is stale. |
| `decision-edit` | `comment-edit` | `comment:github.com/acme/widgets#7/comment/9001=2026-09-06T12:20:00Z` | `authority;;next_action` | The standing decision record's updated_at moved: the authority fact is stale and the derived action with it; nothing HEAD-bound moves. |
| `grant-created` | `comment-created` | `issue:github.com/acme/widgets#7=2026-09-06T12:20:00Z` | `authority;;next_action` | A new decision comment moved the decision issue's updated_at: the authority fact recorded that issue's version and is stale; nothing else in the snapshot reads that issue. |
| `base-move` | `base-move` | `ref:github.com/acme/widgets/master=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb` | `head;;next_action` | master's target is another commit than the one recorded for ref:…/master: the head fact (its base commit) is stale; review, checks and acceptance at the HEAD stand. |
| `base-switch` | `metadata` | `pull_request:github.com/acme/widgets#42=2026-09-06T12:15:00Z` | `work_unit,head,review;;next_action` | The pull request's base branch was switched while both tips stand: its updated_at moved, and the head fact recorded the pull request's version. |
| `issue-comment-created` | `comment-created` | `issue:github.com/acme/widgets#41=2026-09-06T12:25:00Z` | `placement,graph,acceptance;;next_action` | A comment is created on the implemented issue: its updated_at moved, so placement, graph and the acceptance contract read from it are stale — the reads find no new decision or verdict, and re-establish. |
| `parent-changed` | `relationship` | `issue:github.com/acme/widgets#41=2026-09-06T12:35:00Z` | `placement,graph,acceptance;;next_action` | The implemented issue's parent or a child changes: its updated_at moved; placement, graph and acceptance read from it are stale. |
| `blocker-closed` | `relationship` | `issue:github.com/acme/widgets#39=2026-09-06T12:40:00Z` | `graph;;next_action` | The blocker the graph represents is closed: only the graph fact carries that issue, so only it is stale. |
| `pr-relationship` | `relationship` | `pull_request:github.com/acme/widgets#42=2026-09-06T12:45:00Z` | `work_unit,head,review;;next_action` | A relationship of the pull request itself changes: work_unit, head and review, which recorded the pull request's version, are stale. |
| `milestone-edit` | `relationship` | `milestone:github.com/acme/widgets/milestone/7=2026-09-06T12:50:00Z` | `placement;;next_action` | The milestone is edited: only the placement fact carries it. |
| `decision-issue-edit` | `metadata` | `issue:github.com/acme/widgets#7=2026-09-06T12:22:00Z` | `authority;;next_action` | The decision issue's own metadata changes (its title, say): the authority fact recorded that issue's version and is stale; the re-read finds the same decision records. |
| `decision-issue-relationship` | `relationship` | `issue:github.com/acme/widgets#7=2026-09-06T12:23:00Z` | `authority;;next_action` | A relationship of the decision issue changes: the same token fires, and only the authority fact carries it. |
| `gate-edit` | `metadata` | `issue:github.com/acme/widgets#41=2026-09-06T12:30:00Z` | `placement,graph,acceptance;;next_action` | The implemented issue's updated_at moved: placement, graph and the acceptance contract read from it are stale. |
| `ruleset-edited` | `ruleset` | `ruleset:github.com/acme/widgets=digest(1001@2026-09-01T08:00:00Z;1002@2026-09-06T12:05:00Z)` | `checks;;next_action` | A ruleset is edited: its updated_at moves, the membership digest differs from the recorded one, and the checks fact is stale (which checks are required may have changed). |
| `ruleset-created` | `ruleset` | `ruleset:github.com/acme/widgets=digest(1001@2026-09-01T08:00:00Z;1002@2026-08-15T09:00:00Z;1003@2026-09-06T12:05:00Z)` | `checks;;next_action` | A ruleset is created: the two existing rulesets' timestamps stand, the membership grew, the digest differs; the checks fact is stale. |
| `ruleset-deleted` | `ruleset` | `ruleset:github.com/acme/widgets=digest(1001@2026-09-01T08:00:00Z)` | `checks;;next_action` | A ruleset is deleted: the remaining ruleset's timestamp stands, the membership shrank, the digest differs; the checks fact is stale — a maximum-timestamp rule would have missed this. |
| `permission-loss` | `repository` | `observer.permission=none` | `repository;work_unit,placement,graph,authority,acceptance,head,review,checks;next_action` | The observer's permission, re-read before use, is not the recorded write: a repository event — the repository fact is stale and, under F13, every other source-read fact is re-read before use; each re-read answers 403 and yields UNKNOWN (Example 7 of the fact model). |
| `unchanged` | `none` | `pull_request:github.com/acme/widgets#42=2026-09-06T12:00:00Z,observer.permission=write,ruleset:github.com/acme/widgets=digest(1001@2026-09-01T08:00:00Z;1002@2026-08-15T09:00:00Z)` | `;;` | A control: the observation equals the recorded versions and permission, so no token fires and nothing is stale — freshness never expires by age. |

## Rules

Rendered verbatim from the `rule` records of `preferences/fact-freshness.tsv`;
the behavioral suite checks the two never drift.

- **F1** Freshness is decided by identity and version, never by age. Every fact
  records, for each token it carries, the version it observed for that node
  (fact model R20); a fact is current while every recorded version equals the
  node's current version — the commit for head: and ref:, the updated_at for
  every other kind — and nothing else keeps it current. A time-based check may
  trigger the comparison but never replaces it.
- **F2** An event record lists the kinds of token the event can fire; which
  tokens fire is decided by the observation — the tokens whose recorded version
  differs from the current one (F1). A fact is stale exactly when a fired token
  is one it carries. The class × event matrix states reachability: a class is
  stale under an event when it carries a kind the event fires, so the event can
  reach it; it is derived from the class kinds and the event kinds and never
  edited by hand.
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
- **F13** Readability is a property of the snapshot. Every source-read fact of a
  set was read by one observing identity under the set's repository's
  permissions, and every such fact belongs to that repository (R17); a complete
  snapshot records that observer — login, permission, checked_at (R21). Before a
  cached snapshot is used, the observer's permission is re-read and compared
  with the record: a difference is a repository event. A repository event makes
  the repository fact stale and re-reads every other source-read fact of the
  set, so a permission loss cannot leave a cached fact usable: the re-read
  yields UNKNOWN through the unreadable records.
- **F14** A token that names a collection records the collection's digest, not a
  member's timestamp: for ruleset:, the SHA-256 of the sorted lines <ruleset
  id>@<updated_at>, each newline-terminated (the collection record). Membership
  changes are therefore detected even when every remaining member's version
  stands, and any consumer with sort and sha256sum computes the same version.
- **F12** Every event that can change a fact's value reaches the fact through a
  token it carries: the depends record of each class names those events, and the
  matrix cell for each is stale or re-read (derived for the derived class). A
  fact whose value depends on which records a node carries lists the node
  itself, so a record created after the fact was read fires a token the fact
  already has.

## Relation to the rest of the model

This contract adds no field to the envelope: it reads `invalidators`,
`source.version`, `observed_at`, `status` and `detail` as the fact model defines
them. It is versioned with the model — a new fact-model schema version is a new
contract version — and it changes how nothing is stored: `.spark/state.json`
stays the committed work state ([state.md](state.md)), and mutable GitHub truth
is re-read from its source (R10).
