# codify — default doc templates

The crew writes into these shapes unless the target repo already has a house
template for that doc type (then match the repo). Every template is markdown.
Fill what you know; for any section you can't source, write the heading and a
single line — `_Unknown — see open questions._` — rather than inventing content.

The intake summary's **Suggested Doc Type** is what selects the template below.

---

## Intake Summary

Owned by **intake**. The structured source material every other role builds on.

```markdown
# Intake Summary: [Topic]

## Source
<where this came from: notes, transcript, session, repo finding — link/cite it>

## Key Facts
<verified, atomic facts. One per line. Cite the source for each.>

## Decisions
<choices already made, with who/when if known>

## Assumptions
<things treated as true but not verified — kept separate from facts on purpose>

## Open Questions
<what's missing or contradictory; blockers to a complete doc>

## Recommended Doc Type
<adr | system-doc | product-spec | sop | runbook | onboarding | glossary | mixed>

## Suggested Next Actions
<concrete follow-ups, owners if known>
```

---

## Decision Record (ADR)

Owned by **architect** (with product/ops input when the decision spans domains).

```markdown
# ADR: [Decision Title]

Date: YYYY-MM-DD
Status: Proposed | Accepted | Superseded
Owner:

## Context
## Decision
## Why
## Alternatives Considered
## Consequences
## Open Questions
## Related Docs
```

---

## Technical System Doc

Owned by **architect**.

```markdown
# [System Name]

## Purpose
## Current State
## Intended State
## Components
## Data Model
## Data Flow
## External Dependencies
## Operational Notes
## Risks / Unknowns
## Next Steps
```

Add a Mermaid diagram under **Components** or **Data Flow** only when it makes the
doc easier to follow — never as decoration.

---

## Product Spec

Owned by **product**.

```markdown
# [Product / Feature Name]

## Customer Problem
## Target User
## Business Goal
## User Workflow
## Required Objects / Data
## MVP Scope
## Later Scope
## Acceptance Criteria
## Open Questions
## Launch Notes
```

---

## SOP / Process Doc

Owned by **ops**.

```markdown
# SOP: [Process Name]

## Purpose
## Owner
## Trigger
## Required Access / Tools
## Steps
## Output
## Escalation
## Quality Checklist
## Related Docs
```

A **runbook** is an SOP whose Steps are incident/operational response; same shape.
An **onboarding** or **role guide** is an SOP whose audience is a new team member.

---

## Codify Notes (appended to any output, when useful)

Not a standalone template — a trailer the writing role adds to its doc when there's
something the reader or the next agent should know:

```markdown
## Codify Notes
- **Uncertainty:** <claims that need verification>
- **Missing context:** <what would make this doc complete>
- **Suggested location:** <path/filename the librarian recommends>
- **Related docs:** <links to reconcile or cross-link>
- **Follow-up questions:** <open items for the owner>
```

Omit the section entirely when the doc is clean and self-contained — don't pad.
