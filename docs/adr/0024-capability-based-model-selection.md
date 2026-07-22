# ADR: Capability-based model selection — profiles per group, not hard-coded names

Date: 2026-07-21
Status: Accepted (2026-07-21, at the #198 decision gate — capability-based selection is the ratified policy; no selection infrastructure is built until an orchestration slice is adopted. Verdict annotated 2026-07-22: no slice was adopted (#206 closed unmeasured) and the build trigger has not fired (#288 closed as a standing conditional); the policy stands, infrastructure unbuilt)
Owner: jwogrady

> This ADR records an **Accepted** decision (issue #204, the second deliverable of
> the #190 orchestration epic, ratified at the #198 gate on 2026-07-21). It adopts a
> selection *policy*. It is an architectural decision only: it builds **no** routing
> or selection infrastructure, and none has shipped. It stands on ADR-0023's
> topology (the three groups it selects for).

## Context

ADR-0023 organized the five lifecycle stages into three execution groups —
**Shape** (`Ideate → Plan`), **Build** (`Codify`), and **Assure & Deliver**
(`Validate → Ship`) — with lead roles, artifact handoffs, human gates, and
mandatory no-subagent / single-model fallbacks. It deliberately deferred one
question: which model runs which role. #190's principle names it: *"pick the
strongest available capability for the job, not a permanently hard-coded model
name that will drift with provider availability."* That is a durable
architectural decision independent of the topology, and #198 keeps it separately
reviewable. This ADR records it.

**The shipped precedent (fact, in the repo today).** The knowledge crew
(`plugins/spark/agents/knowledge/`) already tiers models per role through the
`model:` frontmatter field on each subagent: Intake `sonnet`, Author `sonnet`,
Librarian-Editor `opus`. The heavy synthesis role gets the stronger model; the
structured-extraction and drafting roles get the faster one. This proves the
mechanism (per-role tiering via native frontmatter) and the instinct (spend the
strong model where reasoning is hardest) — but it hard-codes two provider names
at two points, which is exactly the drift #190 warns against. This ADR
generalizes that instinct into a naming-independent policy.

**The constraint from ADR-0010.** Preferences resolve through three tiers —
shipped defaults (`plugins/spark/preferences/defaults.json`) → operator overrides
(`~/.config/spark/preferences.json`) → committed project facts
(`.spark/preferences.json`), later tiers winning — as flat, one-level-deep JSON
readable without `jq`. Any configuration this ADR introduces must fit that
schema and that resolution order.

**The boundary from ADR-0019.** The human directs; Spark orchestrates; Claude
supplies capability; GitHub is the record. Model selection is a lever inside
"Claude supplies capability" and may never touch "the human directs."

## Decision

Select every role's model **by required capability, never by a hard-coded model
name.** Spark ships a fixed map from each ADR-0023 group to a **required
capability profile**; a separate, operator-tunable **binding** resolves each
capability tier to whatever model currently satisfies it. Provider model names
are current illustrative examples only — never normative policy.

### Capability tiers

Four naming-independent tiers describe *what a role needs*, not *what it runs*:

- **Deep reasoning** — hard multi-constraint synthesis, adversarial critique,
  ambiguity resolution. The scarce, expensive capability.
- **Code execution** — reading and writing code, running tools and tests,
  mechanical transformation with tight feedback loops.
- **Independent review** — a fresh adversarial perspective that must be
  *distinct from the author's context*; its value is independence, not raw
  strength.
- **Long-context synthesis** — holding a large body of material (a codebase and
  its prior art; a roadmap and policy set; several review outputs at once) in one
  window without losing the thread.

Tiers are additive: a role may require a profile of more than one.

### Group → required capability profile

| Group | Required profile | Why | Cost / latency trade-off |
| --- | --- | --- | --- |
| **Shape** (`Ideate → Plan`) | **deep reasoning** + **long-context synthesis** | The Lead's framing and the adversarial critique are the hardest reasoning in the lifecycle; the evidence/constraint helpers must hold the codebase, prior art, roadmap, and policy at once. | Highest reasoning cost, but tolerable latency — Shape runs once per problem, up front, with a human in the loop, not on a hot path. Spend the strong model here. Mirrors the knowledge crew's `opus` synthesis role. |
| **Build** (`Codify`) | **code execution** (+ moderate reasoning) | One implementation agent per issue turns an approved, scoped issue into a branch with running verification evidence. Tool-driven, tight loop. | The highest-volume, most-repeated work — cost and latency dominate here. Favor the strongest **code-execution** tier that keeps the loop fast; do not pay deep-reasoning cost on every mechanical edit. Mirrors the crew's `sonnet` author. |
| **Assure & Deliver** (`Validate → Ship`) | **independent review** + **deep reasoning** + **long-context synthesis** | Reviews are reused native capability (`/code-review`, `/security-review`, `verify`) whose independence matters most; the Assure Lead's synthesis/fix loop reconciles conflicting findings (deep reasoning) while holding every reviewer's output at once (long context). | Parallel reviewers trade **cost** for **latency and coverage** — running them concurrently is faster and broader but multiplies spend; the sequential fix loop wants the strong reasoning tier. Independence is a hard requirement: the reviewer's perspective must not collapse into the Build author's. |

The **group → profile** map is shipped policy (rarely changes). The **tier →
model** binding is expected to drift as providers ship new models, so it lives in
the operator-tunable layer — the operator updates one binding when a better model
appears, and every group that requires that tier picks it up, with no fork and no
edit to the policy.

### Where the configuration lives (ADR-0010)

Flat, one-level keys under a `model.` namespace, resolved shipped → operator →
project like every other preference:

**Group profiles (shipped policy; generic defaults).**

- `model.shape.profile` — default `deep-reasoning,long-context`
- `model.build.profile` — default `code-execution`
- `model.assure.profile` — default `independent-review,deep-reasoning,long-context`

**Tier bindings (operator-tunable; generic defaults, never a provider name).**
Each binds a capability tier to a resolvable model identifier. The **shipped
default is the token `auto`** — defer to the platform's current best model for
that class — so the plugin never hard-codes a provider name. The operator *may*
override with a concrete identifier to pin a model when they choose; that
override is where a provider name legitimately appears (an operator's current
choice, still not normative Spark policy).

- `model.tier.deep-reasoning` — default `auto`
- `model.tier.code-execution` — default `auto`
- `model.tier.independent-review` — default `auto` (must resolve to a context
  *distinct from* the Build author, not necessarily a distinct model)
- `model.tier.long-context` — default `auto`

**Fallback controls.**

- `model.fallback.order` — default `deep-reasoning>code-execution` — the declared
  downgrade path when a required tier cannot be satisfied.
- `model.single-model` — default empty; when set to one identifier, forces
  single-model mode (every role runs on it), the machine form of ADR-0023's
  first-class single-model fallback.

The `auto` default matters: it keeps ADR-0010's contract intact (shipped defaults
are generic and useful with zero setup; the operator makes them specific without
forking) *and* satisfies #204's rule that no provider name is normative. The
current shipped realization point for a resolved tier is the native `model:`
frontmatter field the knowledge crew already uses — this ADR does not change that
mechanism, only the policy that decides what value belongs there.

### Observability

Selection is never silent. At each dispatch Spark reports a one-line rationale:
**the group, its required profile, the tier(s) resolved, the concrete model the
binding produced, and whether a fallback was taken** (and which). These lines are
surfaced in the session brief so a run's model choices — and every downgrade —
are auditable after the fact, not reconstructed. "Green" and "single-model" and
"downgraded" are always stated, never assumed.

### Fallback behavior

- **Capability-unavailable.** If a required tier's binding cannot be satisfied
  (model unavailable, erroring, or unauthorized), downgrade along
  `model.fallback.order` to the next tier that can still produce the group's
  artifact, and **record the downgrade** in the observability line. If no tier
  can run the role, **block and report** — never fabricate an artifact and never
  silently continue on a tier that cannot do the work.
- **Single-model mode.** When only one tier is available, or `model.single-model`
  is set, or the environment has no subagents, every role runs on the one
  available model. Per-group profiles collapse to that model; the topology still
  functions because ADR-0023 makes single-model a first-class mode, not a degraded
  path. The run is reported as single-model so no one mistakes it for the tiered
  path.

### The non-approval boundary, in policy terms

Capability selection is a **performance and quality lever only.** It changes *how
well* a proposal is drafted, a change is reviewed, or a branch is built — never
*who approves it*. Restated against ADR-0019 and the ADR-0023 gates:

- Capability selection can **never** move a **scope**, **priority**,
  **release-assignment (#188)**, **merge**, or **release (#185)** decision away
  from the human.
- A stronger tier does not earn an agent approval authority; a weaker tier or a
  degraded fallback does not lower a human gate. Every ADR-0019 human decision
  point stands unchanged in the tiered path, in single-model mode, and in every
  downgrade.
- Selection may be granted no authority to bypass a gate as an "optimization."
  There is no capability tier at which a merge or release becomes automatic.

*Why this shape.* It keeps the knowledge crew's proven instinct — spend the
strong model on the hardest reasoning, the fast model on the tight loops — while
removing the two hard-coded names that would rot. It rides ADR-0010's existing
three-tier resolution instead of inventing a config surface, so "install once,
tune once, carry everywhere" stays true and every deviation is reviewable. It
binds naming-independent tiers so a new provider model is a one-line binding
change, not a code change. And it treats selection as strictly beneath the
ADR-0019 human authority, so no amount of capability ever buys an agent a
decision that belongs to the human.

## Alternatives Considered

- **Hard-code model names per role (extend the knowledge-crew pattern as-is).**
  Rejected: it is exactly the drift #190 warns against — the names rot as
  providers change, and every fork must chase them. The precedent proves the
  instinct, not the naming.
- **A single global model for the whole lifecycle.** Rejected as the default: it
  either overspends deep-reasoning cost on every mechanical Build edit or
  underpowers the Shape synthesis. It survives only as the explicit single-model
  fallback, which the policy already makes first-class.
- **A dynamic router that picks a model per task at runtime from live
  benchmarks.** Rejected: #198 forbids building a generic platform without a
  validated need and an explicit boundary. Fixed group profiles plus an
  operator-tunable binding are auditable and zero-dependency; a live router is
  neither, and it is unfalsifiable at the gate.
- **Put the config in env vars or a new bespoke file.** Rejected: ADR-0010 already
  decided the canonical preferences source and its resolution order; env vars are
  not durable, reviewable, or visible to a session brief (ADR-0010 rejected them
  for the same reason).
- **Ship concrete provider names as the defaults.** Rejected: it makes a provider
  name normative Spark policy and breaks the moment the provider renames or
  retires it. The `auto` default keeps the shipped layer generic; concrete names
  belong only in an operator's own override.

## Consequences

- **Commits us to** a fixed group→profile map, four naming-independent capability
  tiers, an operator-tunable tier→model binding under `model.*` in the ADR-0010
  preferences, a declared downgrade order, and mandatory reporting of every
  selection and fallback.
- **New constraint:** any future orchestration work must select by capability and
  keep provider names out of shipped policy; adding a role means naming its
  profile, not a model. The knowledge crew's two hard-coded `model:` values become
  a documented migration target (fold them under this policy) *if and when* this
  ADR is accepted — not touched by this proposal.
- **Maintenance burden:** the group→profile map and the tier definitions need an
  owner as the lifecycle evolves; the `auto` token needs a defined resolution
  rule at implementation time (what "the platform's current best model for a
  class" means concretely).
- **Becomes easier:** a new provider model is a one-line binding change;
  single-model and no-subagent environments have a defined, first-class path; and
  the #198 gate gets a second reviewable artifact that pairs with ADR-0023's
  topology.
- **Nothing ships from this ADR.** No selection infrastructure is built, no
  preference keys are added to `defaults.json`, and no skill or lifecycle doc is
  touched. Until the maintainer records Accepted, the knowledge crew's per-role
  `model:` values remain the only shipped model tiering, and representing this
  policy as shipped is forbidden (#198, #180).

## Open Questions

- **The concrete resolution rule for `auto`** — how Spark maps a capability tier
  to "the platform's current best model for that class" without a hard-coded name,
  given only native model identifiers. Owner: the implementation issue, once
  ratified.
- **How `independent-review` guarantees independence** — whether a distinct
  context on the same model is sufficient, or a distinct model is required, and
  how that is verified. Owner: #206 (validate-as-independent-review-roles) design.
- **Whether group profiles should be operator-tunable too**, or stay fixed shipped
  policy. This ADR fixes them and makes only the bindings tunable; the #198 gate
  may revisit. Owner: jwogrady, at the #198 gate.

## Related Docs

- [0023-lifecycle-orchestration-topology.md](0023-lifecycle-orchestration-topology.md) — the three groups this policy selects a capability profile for
- [0019-human-directed-product-model.md](0019-human-directed-product-model.md) — the human authority selection sits strictly beneath
- [0010-preferences-source-model.md](0010-preferences-source-model.md) — the three-tier preferences source and flat-JSON schema the `model.*` keys ride on
- [0002-additive-to-anthropic-spec.md](0002-additive-to-anthropic-spec.md) — select the native model; do not reinvent a routing platform
- [../../plugins/spark/agents/knowledge/01-author.md](../../plugins/spark/agents/knowledge/01-author.md) — the shipped per-role `model:` tiering precedent this generalizes
- [../../plugins/spark/skills/knowledge/SKILL.md](../../plugins/spark/skills/knowledge/SKILL.md) — the crew that tiers models per role today
