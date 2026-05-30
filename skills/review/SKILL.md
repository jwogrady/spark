---
name: review
description: Audit a whole project — not a single diff — with 8 specialist agents who share findings before a Synthesis Lead produces one consolidated report. Use for codebase-wide quality control: preparing for a major release or external review, or assessing overall project health across documentation, architecture, code quality, testing, and security. To review one change or branch instead, use fix-issue.
---

# review — multi-agent project audit

`review` stands up a coordinated audit of a project's codebase using 8 specialist
agents who examine different dimensions, share findings in a structured `.review-notes/`
directory, read each other's work, and collaborate before the Synthesis Lead produces
a final consolidated report.

Each agent operates sequentially, reads all prior findings before writing, and leaves
evidence and notes for downstream agents. The result is a harsh-but-fair assessment
across architecture, code quality, testing, security, documentation, product
readiness, and risk.

## Do this

1. **Trigger the review** — invoke `/spark:review` from the project root when you need
   a comprehensive codebase audit.
2. **Agents execute in order** — each agent (00 through 07) writes to its own markdown
   file in `.review-notes/`, reads all prior agents' findings, and documents evidence.
3. **Review notes accumulate** — agents leave "notes to next agent" sections to guide
   downstream reviewers and highlight critical findings.
4. **Synthesis Lead consolidates** — agent 08 (Synthesis Lead) reads all 7 agent reports
   and produces a final report with executive summary, scoring, critical risks, debt
   lists, top 20 actions, and recommendations.
5. **Interpret the report** — scores are on a 1–10 scale (harsh but fair). 1–3 means
   critical work needed; 4–6 means solid foundation with gaps; 7–9 means strong with
   minor polish; 10 is rare and means production-ready with best practices.
6. **Archive the review** — commit `.review-notes/` when the audit is complete. Each
   review is a snapshot; old reviews show the project's trajectory.

## Agent roles

- **00 Project Mapper** — static analysis. File structure, dependencies, entry points,
  tech stack, complexity. Read: nothing yet. Outputs: map for all downstream agents.
- **01 Documentation Reviewer** — checks README, CLAUDE.md, API docs, guides. Does the
  project document its purpose, setup, and usage?
- **02 Architecture Reviewer** — evaluates design patterns, module boundaries, coupling,
  scalability, state management. Is the design coherent and sustainable?
- **03 Code Quality Reviewer** — lints, style, readability, complexity, test coverage
  (surface inspection). Is the code clean and maintainable?
- **04 Testing & Reliability Reviewer** — tests (coverage, types, integration), error
  handling, edge cases. Can we trust this code in production?
- **05 Security & Configuration Reviewer** — secrets, auth, access control, CVEs,
  compliance, safe defaults. Are user data and the system protected?
- **06 Product Readiness Reviewer** — feature completeness, UX flow, performance (target
  vs. actual), observability. Is this ready to ship and run?
- **07 (Reserved for custom focus)** — optional; extend for domain-specific audit
  (e.g., accessibility, SEO, performance flame).
- **08 Synthesis Lead** — reads all 7 reports, consolidates findings, scores each
  dimension, identifies top 20 actions, produces final report.

## Guardrails

- **Evidence required** — agents cite files, line numbers, and concrete findings. No
  vague claims.
- **No AI attribution** — all notes and reports are authored by `jwogrady` (the human).
  Never credit Claude or any AI system in the notes.
- **Harsh but fair** — scoring reflects reality. If something is broken, say so.
- **Shared context** — each agent reads the `.review-notes/` directory before writing.
  This is the collaboration mechanism.
- **Sequential, not parallel** — agents run one at a time to ensure readings are
  current.

## Review notes structure

```
.review-notes/
├── 00-project-map.md           # Project Mapper
├── 01-documentation.md         # Documentation Reviewer
├── 02-architecture.md          # Architecture Reviewer
├── 03-code-quality.md          # Code Quality Reviewer
├── 04-testing-reliability.md   # Testing & Reliability Reviewer
├── 05-security-config.md       # Security & Configuration Reviewer
├── 06-product-readiness.md     # Product Readiness Reviewer
├── 07-custom-focus.md          # (Optional) Custom focus reviewer
└── 08-final-report.md          # Synthesis Lead (consolidation)
```

Each file includes:
- **Finding** — what was assessed, what was found.
- **Scoring** — 1–10 for that dimension.
- **Evidence** — files, line numbers, examples.
- **Notes to next agent** — highlights for downstream reviewers.

## Fits the lifecycle

`review` is used in the **Solve** stage — after code is written and tests pass, before
shipping. It can also run standalone as a pre-release quality gate or milestone
checkpoint. Use it to uncover hidden debt before it accumulates.
