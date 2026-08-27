# ADR: The governance model is a versioned record artifact, not JSON through the preference resolver

Date: 2026-08-26
Status: Accepted
Owner: jwogrady

## Alignment

- **Identity / prior decisions served:** ADR-0010 (three-tier preference resolution — shipped → operator → project), ADR-0008 (one canonical source per class of fact), ADR-0020 (prose standards are the readable contract, `.spark/preferences.json` the machine layer), ADR-0029 (four-tier artifact separation).
- **Supersedes / Superseded by:** nothing. It extends ADR-0010's *resolution model* to a new *representation* without changing the resolver.
- **Status tracks evidence:** Accepted on implementation. Shipped as `preferences/governance-models/spark-default.tsv`, `resolve_governance`, and `spark governance`; covered by `tests/test-governance-schema.sh` and validated on doctor's hot path.

## Context

Spark taught repository governance partly through prose (`docs/reference/metadata-governance.md`) and partly through individual commands. An agent could hold the doctrine correctly and still recreate labels, priorities, milestone conventions, and metadata rules inconsistently from repo to repo, because nothing was the machine-readable authority. Worse, some rules already had *two* homes: the per-category label colour and description were hard-coded in `bin/spark`, restating what `preferences/defaults.json` and the prose reference also described.

The obvious reading of "resolve the governance model through Spark's existing preference tiers" fights the architecture. The resolver is deliberately flat by design:

- `read_flat_json` emits `key<TAB>value` pairs and **drops anything that is not a scalar member of a top-level object**;
- `resolve_prefs` layers shipped → operator → project and keeps first-seen key order;
- `pref_get` returns exactly one string.

A governance model is not scalar. Label definitions carry colours and descriptions, families carry cardinality and requirement, structure records carry an authority verdict, surfaces carry a provisioning owner. None of that survives the pipeline.

Three options were real:

1. **Widen `read_flat_json` into a general nested-JSON reader.** It would rework the most load-bearing function in `bin/spark` — every preference, profile, and standards read goes through it — for the benefit of one consumer.
2. **Ship the model as nested JSON and parse it with `jq`.** Spark's coding standard is zero runtime dependencies, with JSON parsing that *degrades gracefully* when `jq` and `python3` are absent. For a file that is the governance authority, "degrades gracefully" would have to mean "degrades to no governance model at all" — a repo without `jq` would silently have no schema. That is the exact silent-no-op class of defect this repo keeps removing.
3. **Give the model its own versioned record artifact.**

## Decision

**The governance model is its own versioned, line-oriented, tab-separated artifact.** Records are `version`, `model`, `family`, `member`, `structure`, `separation`, `surface`, `enforce`; comments and blank lines are tolerated. It parses in `awk` alone, diffs line-by-line in review, and carries an explicit `version` that a reader checks against `GOVERNANCE_SCHEMA_VERSION` and rejects when unknown. The plan skill's issue manifest already proves the shape in this codebase.

**The resolution model is unchanged.** Three tiers, later winning, every resolved record naming its source: shipped `preferences/governance-models/<governance.model>.tsv`, operator `$XDG_CONFIG_HOME/spark/governance.tsv`, project `.spark/governance.tsv`. What changed is the representation, not the resolution — which is precisely the boundary #470 asked us to hold.

**Scalar preferences select and override aspects of it.** `governance.model` names which shipped model is the base, and must be a bare model id — a value carrying a path separator fails closed rather than letting a preference point governance authority at an arbitrary file.

**One authority per fact, and the split is explicit.** `issue.taxonomy` already owned the category *name set* across all three tiers and keeps owning it; the model owns each category's *colour, description, cardinality, and requirement* — the values formerly hard-coded in `bin/spark`. Because two shipped files now describe adjacent halves of one subject, `spark doctor` holds them in **parity**: if the shipped model's category family and the shipped `issue.taxonomy` disagree about which categories exist, that is an error. Parity is not a second authority; it is the mechanical proof that there is only one.

**Parity is compared as a set, and it is needed at two levels.** Shipped-vs-shipped
parity is a `spark doctor` error: if the shipped model's category family and the
shipped `issue.taxonomy` name different categories, one of them is lying. It is a
*set* comparison, because the question is which categories exist and member
declaration order is meaningful elsewhere in the artifact — a string compare failed
on a semantically neutral reordering and then printed two lines holding the same
seven names, which reads as a tooling bug rather than a finding.

Shipped parity is not sufficient, because the two authorities resolve
independently through three tiers each. A *resolved* model can be perfectly valid
and still contradict the resolved taxonomy — an operator model that replaces the
category family with `feature` alone leaves six categories with no declared
colour, and nothing about that fails to parse. The two readings of that gap are
different facts and are told apart by which tier won the member set: if the shipped
set won, a category it does not name was **added** to `issue.taxonomy`, which is the
supported extension path and resolves to neutral grey; if an overlay tier replaced
the set, two of the operator's own declarations **disagree**, and Spark reports the
tier and the categories and refuses to write them. Create-only is what makes the
refusal necessary rather than merely tidy: a guess written once is never corrected.

**A family replacement is whole-set, not per-member.** A tier that declares any member of a family replaces that family's entire member set. A per-member merge can only add, never remove, and a governance overlay that cannot remove a member cannot express a real project decision.

**Fail closed.** Any tier that is syntactically invalid, or a resolved model that is not closed (a member whose family nobody declared; either side of a separation naming neither a declared family nor a declared structure aspect or surface — both sides are checked, because the one thing a separation asserts is that X is never derived from Y), is reported as one precise `<file>:<line>: <problem>` per finding, and resolution returns non-zero. An unreadable governance model never degrades to a partial one.

**A new governed label family is data.** Adding a `family` record and its `member` records to any tier is enough; generic consumers pick it up with no schema code change.

## Consequences

**Good.** There is one place to read what shape a Spark-managed repository's governance may take, and it is machine-readable without a dependency. The hard-coded colours and descriptions have one home. The separations that matter most — delivery order is never derived from `blocked-by` or from priority; a theme label never satisfies the category requirement — became *data a test can assert* rather than prose a reader has to honour. `spark doctor` validates the artifact the same way it validates the shipped defaults, so a malformed model cannot ship.

**Costs, accepted.** The repo now carries two serialization formats for configuration: flat JSON for scalars, records for the governance model. That is a real cost, and the mitigation is that the boundary is stated rather than incidental — scalars are preferences, structure is the governance model. A hand-edited artifact can also break on an invisible space-versus-tab error; the validator's per-line field-count message is what makes that a two-second fix instead of a mystery.

**Where the directory could not go.** ADR-0029's tier boundary errors on any directory named `governance` anywhere under `plugins/`, because a decision record filed there would ship this repo's internal history. The shipped artifact therefore lives in `preferences/governance-models/`, not `governance/`. The guard shaped the layout, which is the guard working.

**Not decided here.** Diffing the resolved model against live GitHub state, and provisioning it there, are separate capabilities that consume this render. Nothing in this ADR touches GitHub: it remains the durable authority for execution state, and this schema only describes the shape that state may take.
