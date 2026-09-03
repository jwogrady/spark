# GitHub control plane and versioned project Blueprints

This document records the product architecture that separates Spark's **generic GitHub-native automation control plane** from the **versioned project Blueprints** that feed that control plane.

> **Blueprint is Spark's canonical word for a project template.**
>
> A Blueprint is a version-controlled project template / operating pattern that defines what well-governed looks like for a class of project.

Use **Blueprint** in Spark product language, commands, docs, issues, and machine contracts. `template` remains the generic explanatory word: a Blueprint is Spark's versioned project template.

This document is a roadmap/architecture contract, not evidence that unreleased behavior already exists. Executable product contracts remain on their owning issues and release gates:

- v0.23 gate: #480
- released-governor provenance primitive: #710
- v0.24 gate: #481
- v0.24 execution-provenance projection: #711
- v0.24 governance projection/reconciliation: #713
- v0.25 gate: #701
- v0.25 Blueprint contract: #714

Provider-neutral Claude/OpenAI parity is not part of v0.25 under this architecture; it remains a Later candidate preserved historically on #700.

---

## 1. Product layering

The intended sequence is:

```text
v0.23 — Never automate inefficiency
        establish the efficient/truthful execution floor

v0.24 — GitHub-native automation control plane
        make GitHub-native governed automation trustworthy

v0.25 — Versioned Blueprints for the control plane
        feed reusable project templates/patterns into v0.24

Later — re-evaluate from field evidence
```

The critical distinction is:

```text
Spark v0.24
= generic governance + trustworthy automation engine

Spark Blueprint
= version-controlled project template / expected operating pattern

Spark v0.25
= machinery for adopting, compiling, migrating, and conforming to Blueprints
```

A workflow is only one possible kind of automation, and only one optional thing a Blueprint may describe.

---

## 2. v0.24: GitHub-native automation control plane

v0.24 is about using Spark to leverage GitHub's native project-management and delivery features as a trustworthy control plane.

The control plane is not a giant workflow definition. It is the reusable machinery that lets Spark derive project truth, apply already-authorized decisions to canonical GitHub surfaces, verify the result, and continue operating until a genuine authority boundary is reached.

The core transition is:

```text
DECIDE
  authorized human/governed surface establishes what should be true

PROJECT / EXECUTE
  Spark performs the routine authorized mutation or action

VERIFY
  Spark reads the resulting state back and proves it is true

OPERATE
  downstream selection, automation, review, and release logic consume
  that same verified state
```

A human should not have to approve the same decision twice. If project authority has already approved a priority, milestone, true blocker, or parent/sub-issue relationship, Spark's job is to project that approved truth mechanically and verify it.

### 2.1 Canonical GitHub control-plane surfaces

Where GitHub provides a native governed surface, Spark should use it rather than reconstructing the fact from prose.

```text
work category/type       -> governed label

documentation impact    -> governed docs-impact labels

priority                 -> governed priority field/label

release placement        -> milestone

deferred disposition    -> backlog/future disposition

scope/hierarchy          -> native parent/sub-issue relationship

true prerequisite        -> native blocked-by / blocking relationship

delivery order           -> governed sub-issue order

ownership                -> assignee when authority establishes one

implementation           -> linked PR / closing relationship

current implementation   -> exact PR + exact HEAD

verification             -> checks/reviews bound to exact state

release readiness        -> release-gate issue carrying milestone scope

governance provenance    -> durable governor fact

execution provenance     -> durable role/worker/provider/surface records
```

Prose can explain **why** a relationship exists. Prose is not a substitute for the native relationship.

### 2.2 What Spark may count on

Spark relies only on facts that are mechanically established or durably authorized.

It may count on:

1. a released Spark governor can be identified through its canonical released-version authority;
2. repository/work-unit identity can be mechanically established before mutation;
3. GitHub-native governed surfaces have defined ownership semantics;
4. human decisions consumed by automation are persisted to authoritative surfaces;
5. Spark has only the credentials and mutation authority actually granted to it;
6. an owning issue or equivalent governed surface defines the authorized outcome;
7. unreadable, missing, conflicting, stale, or unassessed state is not truth.

```text
UNKNOWN != PASS
NOT ASSESSED != PASS
```

### 2.3 What Spark must never assume

Spark must not infer that:

- prose is equivalent to native GitHub metadata;
- recommendation is approval;
- milestone or priority is authorized because it seems logical;
- a related issue is automatically a blocker;
- preferred order is equivalent to a true prerequisite;
- a prior review remains current after HEAD changes;
- a command named `check`, `validate`, or `doctor` is read-only by name;
- available credentials grant authority to use them;
- visibility into another repository grants mutation authority there;
- PASS grants human-owned merge/release/admin/destructive authority;
- model/provider identity implies authorship or governance;
- an installed integration proves it participated in a work unit.

Permanent rule:

> **Availability is not authority. Presence is not participation. Recommendation is not decision.**

### 2.4 Forms of automation

The v0.24 control plane is broader than workflow execution.

#### Guard

```text
invalid governed state -> reject
```

#### Governed projection

```text
authorized decision
  -> calculate canonical mutation
  -> preview
  -> apply
  -> read back
  -> verify
```

#713 owns the generic approved-plan -> native GitHub projection/reconciliation behavior.

#### Reconciliation

```text
expected truth
      vs
actual truth
  -> classify drift
  -> derive authorized repairs
  -> apply or escalate only where required
```

#### Reactive automation

```text
PR HEAD changes
  -> prior exact-HEAD evidence becomes historical
  -> new HEAD becomes NOT ASSESSED
  -> required evidence runs again
```

#### One-shot governed action

Examples include applying an approved label, recording durable state, attaching a native blocker, updating a parent/sub-issue relationship, or persisting a checkpoint.

#### Repair loop

```text
review
  -> CHANGES REQUIRED
  -> writer repair
  -> new HEAD
  -> fresh verification
  -> fresh review
```

#### Multi-stage workflow

```text
issue
  -> implementation
  -> verification
  -> review
  -> repair if required
  -> close-out
```

The workflow is composed from trustworthy primitives; workflow is not the definition of Spark.

### 2.5 Derive before asking

The v0.24 default motion is:

```text
OBSERVE -> DERIVE -> RECONCILE -> ACT
```

not:

```text
ASK HUMAN -> later discover the answer was already in durable truth
```

Before producing `DECISION REQUIRED`, Spark should exhaust what can be mechanically established within the bounded assessment contract.

### 2.6 Exact-state evidence

Current evidence is bound to the mutable state it describes.

```text
PR #712
HEAD abc123
review PASS
checks PASS
```

If HEAD becomes `def456`:

```text
abc123 PASS = historical evidence

def456 = NOT ASSESSED until fresh evidence exists
```

Spark must never silently combine evidence from incompatible HEADs, release targets, repository states, or other mutable work bindings.

### 2.7 Repository authority

Before mutation Spark establishes:

```text
Which repository/work unit is targeted?
What authority covers it?
Which mutation transport is being used?
Does that authority cover this transport and target?
Did authority explicitly transfer across a repository boundary?
```

If those facts cannot be established:

```text
DO NOT MUTATE
```

Visibility is not authority. Tool capability is not permission.

### 2.8 Machine interfaces

Trustworthy automation needs machine contracts that do not require scraping terminal prose.

Supported machine surfaces should provide:

- structured output where promised;
- stable field semantics;
- truthful, distinguishable exit states;
- clean stdout for machine payloads;
- diagnostics on the appropriate channel;
- controlled ANSI/color behavior;
- explicit PASS / FAIL / INVALID / DECISION_REQUIRED / NOT_ASSESSED distinctions.

### 2.9 Human boundary

Spark continues routine, reversible, already-authorized work.

It stops for genuine authority boundaries such as:

- `DECISION REQUIRED`;
- materially different product/governance semantics;
- new authority grants;
- unresolved repository mutation authority;
- destructive or irreversible external action;
- ruleset/secrets/admin boundaries not already granted;
- final human-owned release approval.

When uncertain about **facts**, Spark gathers evidence. When uncertain about **authority**, Spark stops.

---

## 3. #710 and #711: governor provenance versus execution provenance

The v0.23/v0.24 boundary requires a precise provenance split.

### 3.1 #710 owns the released-governor primitive

#710 answers exactly one question:

> **Which released Spark version actually governed this work?**

Canonical machine-readable commit provenance:

```text
Spark-Governed-By: v0.23.0
```

Canonical human wording:

```text
Governed by Spark v0.23.0
```

The value identifies the installed/released Spark control plane that actually exercised governance. It must never be taken from the unreleased target working tree merely because that tree advertises the next version.

Keep these concepts separate:

```text
Author/owner = ordinary human/project Git authority
Governor     = released Spark control plane
Execution    = role/model/provider/surface/run facts owned by #711
```

### 3.2 #710 includes a minimal mechanical PR projection

Governor provenance must survive commit-topology changes such as squash/rebase merges. Therefore #710 includes both:

1. the canonical commit trailer; and
2. a **minimal durable PR-level projection** of the same governor value.

That PR projection is part of #710 only to preserve the governor fact independently of commit topology.

It must be mechanical, not a manual prose convention:

```text
repository-local canonical governor resolver
        |
        +--> commit trailer
        |
        +--> PR-level governor projection
```

The PR path must, at minimum:

- derive from the same repository-local canonical governor authority as the commit trailer;
- emit/update the canonical governor value deterministically;
- reject or reconcile conflicting/duplicate governor claims according to the owning contract;
- verify commit/PR agreement where both apply;
- remain independently retrievable through normal GitHub/API surfaces after merge;
- remain idempotent when already correct.

This does **not** imply a new public Spark verb, GitHub App, rich card, or multi-actor execution system. The smallest deterministic helper integrated into the existing ship/projection path is sufficient if it satisfies #710.

### 3.3 #711 owns the richer GitHub provenance facility

#711 begins after the #710 governor primitive exists in released v0.23.

It owns the human-visible Spark provenance card/check and repeatable execution provenance for multiple actors.

Example:

```text
Governed by Spark v0.23.0

Execution provenance
Writer       Claude Sonnet 5 · Anthropic · Claude Code
Reviewer     GPT-5.6 Sol · OpenAI · GitHub Actions
Orchestrator GPT-5.6 Sol · OpenAI · ChatGPT

HEAD: abc1234
```

The durable model keeps these dimensions separate:

```text
Role     != Worker
Worker   = model
Provider = model supplier
Surface  = execution host/product
Governor = Spark control plane
Author   = ordinary project/Git authorship
Run      = mechanically known execution identity when available
```

One work unit may have multiple execution records. A later reviewer must not overwrite an earlier writer record. A changed HEAD supersedes current presentation while preserving historical provenance.

### 3.4 The boundary

```text
#710 / v0.23
  canonical released governor
  commit trailer
  minimal mechanical durable PR projection

#711 / v0.24
  Spark GitHub card/check
  role + worker/model + provider + surface + run
  multiple execution participants
  exact-HEAD visible provenance
  richer GitHub-native presentation
```

Therefore:

- a **manual PR-body instruction is too weak for #710**;
- a **full Spark provenance card/check is too broad for #710**.

The correct implementation is the smallest mechanical PR-level governor projection that satisfies #710 without pulling #711 forward.

---

## 4. v0.25: versioned project Blueprints

Once v0.24 provides a trustworthy control plane, v0.25 feeds reusable, version-controlled Blueprints into that control plane.

The model is:

```text
Blueprint definition @ version
        |
        v
project authority adopts/pins Blueprint version
        |
        v
compile expected governed state
        |
        v
released v0.24 control plane
  derive -> diff -> project -> verify -> operate
        |
        v
verified project conformance
```

The Blueprint supplies **what a class of project should look like**. v0.24 supplies **how authorized state is safely realized and verified in GitHub**.

### 4.1 Blueprint is Spark's project template

A Blueprint is a version-controlled project template / operating pattern.

It may define:

- project type / Blueprint identity;
- Blueprint version;
- expected GitHub governance topology;
- governed labels/categories and issue taxonomy;
- release-gate / milestone pattern;
- parent/sub-issue structure;
- true prerequisite relationships;
- governed delivery ordering;
- required project facts and metadata;
- validation commands/capabilities;
- required evidence;
- documentation expectations;
- authority/risk boundaries;
- lifecycle invariants;
- reusable templates/content;
- standard automation triggers/actions;
- optional multi-step workflows.

Workflow is optional.

An infrastructure Blueprint may primarily define invariants, validation, authority boundaries, and recovery expectations without defining a long sequential workflow.

### 4.2 Blueprint availability is not authority

The authority model is:

```text
AVAILABLE Blueprint
  !=
ADOPTED Blueprint
  !=
AUTHORIZED migration
  !=
VERIFIED project conformance
```

A Blueprint existing in Spark or in a repository is not authority to reshape a project.

- publication makes a Blueprint/version available;
- project authority adopts/pins that version;
- deterministic consequences already authorized by adoption may then be projected through v0.24;
- a future upgrade that introduces a new human-owned semantic choice stops at that choice;
- project-local exceptions/overrides must be explicit, durable, and precedence-defined.

### 4.3 Versioning and migration

A project should be able to record a durable Blueprint identity such as:

```text
Blueprint: website.service-area-business
version: 2.3.0
```

When a newer version exists, Spark derives a migration delta instead of silently changing the project:

```text
current Blueprint 2.1.0
        vs
candidate Blueprint 2.3.0
        |
        v
added / changed / removed expectations
        |
        +--> mechanically authorized transition
        +--> DECISION REQUIRED
        +--> NOT ASSESSED
        +--> incompatible / blocked
```

Blueprint migrations use the same v0.24 preview -> apply -> read-back -> verify discipline.

Once converged, a second run should be a no-op.

### 4.4 Composition and specialization

Real projects should not require copy/pasting entire Blueprint contracts.

The Blueprint layer should support deterministic composition/inheritance, or deliberately prove a smaller equivalent sufficient.

Representative shapes include:

```text
website
  + service-area-business
  + mobile-truck-repair
```

```text
website
  + professional-services
  + attorney
```

```text
cosmic-tenant
  + website.service-area-business
  + business-specific policy
```

```text
infrastructure
  + zonedock
```

Conflicting Blueprint requirements must have deterministic precedence/conflict behavior. Silent load-order resolution is not acceptable.

### 4.5 Representative Blueprint classes

The following are proving examples, not hard-coded Spark core types.

#### Service-area business website

Likely expectations include:

- business identity;
- primary domain;
- locations/service areas;
- services;
- GBP/local-search facts;
- analytics/search access;
- technical baseline;
- schema;
- conversion forms;
- accessibility/compliance;
- launch validation.

#### Attorney website

Builds on general website expectations and may add:

- jurisdiction;
- attorney/bar identity;
- practice areas;
- advertising-rule review;
- testimonial/results constraints;
- disclaimers;
- intake/privacy requirements.

#### ZoneDock infrastructure

Likely emphasizes:

- infrastructure inventory;
- authoritative DNS;
- IaC ownership;
- secrets boundary;
- environment separation;
- deployment/recovery path;
- service health;
- backup/recovery;
- destructive-action classification.

#### CosmOS platform

Likely emphasizes:

- module boundaries;
- ADR requirements;
- tenancy;
- authentication;
- schema migrations;
- API compatibility;
- integration contracts;
- data provenance;
- release compatibility.

#### Individual Cosmic

An individual tenant can compose the platform/tenant contract with a business/project Blueprint instead of becoming a giant one-off governance definition.

---

## 5. Relationship between control plane and Blueprints

The long-term model is:

```text
Spark
= governance + trustworthy automation engine

GitHub
= control plane

Blueprint
= version-controlled project template / expectations for a class of project

Project
= an instance/composition of adopted Blueprints

Observed state
= what is actually true now

Reconcile
= Blueprint/governance expectation vs observed truth

Plan
= authorized transition toward desired state

Execute
= governed mutation/action through v0.24 primitives

Verify
= prove resulting durable truth

Workflow
= optional orchestration of multiple transitions
```

The separation matters because Spark core should not need to hard-code the business semantics of every attorney site, plumber site, DNS cluster, platform, or tenant.

Spark core needs to understand authority, state, transitions, evidence, provenance, repository boundaries, validation contracts, and safe automation.

Blueprints provide reusable domain-specific expectations.

---

## 6. Release-boundary consequences

### v0.23

**Never automate inefficiency.**

Establish the truthful/efficient execution floor and ship #710 so later governed work can mechanically identify its released governor from the beginning.

### v0.24

**GitHub-native automation control plane.**

Make GitHub-native governed automation trustworthy enough that the operator no longer has to be the routine courier or safety monitor.

This includes generic mechanics for:

- truth derivation;
- governance projection and read-back verification;
- native hierarchy/dependencies/order;
- executable-work selection;
- exact-state evidence;
- review/repair loops;
- repository/mutation authority;
- read-only containment;
- machine interfaces;
- governance/execution provenance;
- release truth.

v0.24 must remain useful with **no Blueprint at all**. A human or another governed source may authorize state and Spark can still operate the control plane safely.

### v0.25

**Versioned Blueprints for the GitHub control plane.**

Package reusable project templates so multiple project classes can drive the same released v0.24 control plane consistently.

v0.25 must not build a second GitHub governance/mutation engine. Blueprints compile to expectations; v0.24 primitives realize and verify them.

### Later

Re-evaluate from field evidence after the control-plane and Blueprint layers are real and dogfooded. Provider-neutral execution parity is one preserved candidate, not a current v0.25 requirement.

---

## 7. Short product statement

A compact statement of the architecture is:

> **Spark turns authorized intent into verified project truth using GitHub as the control plane. Blueprints are Spark's version-controlled project templates that tell the control plane what well-governed looks like for a particular class of project.**

Or, by release:

```text
v0.23 — make execution efficient and truthful
v0.24 — build the GitHub-native control plane
v0.25 — feed the control plane versioned Blueprints
Later — learn what comes next from field evidence
```