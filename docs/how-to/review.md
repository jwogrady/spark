# How to conduct a project review

> How-to — task-oriented.

Use this to perform a comprehensive quality audit of a project's codebase. Run this
during the **Validate** stage (after major changes) or as a milestone checkpoint.

## 1. Invoke the review

```bash
/spark:review
```

This sets up the `.review-notes/` directory and launches 8 specialist agents in order.

## 2. Agents run sequentially

Each agent (00–07) reads all prior findings, inspects the codebase, and writes their
findings to `.review-notes/`:

- **00 Project Mapper** — understanding the structure and tech stack.
- **01 Documentation Reviewer** — README, API docs, guides.
- **02 Architecture Reviewer** — design, patterns, scalability.
- **03 Code Quality Reviewer** — style, readability, complexity.
- **04 Testing & Reliability** — coverage, edge cases, error handling.
- **05 Security & Configuration** — secrets, auth, CVEs, compliance.
- **06 Product Readiness** — features, performance, UX, observability.
- **07 (Optional)** — custom focus (accessibility, SEO, performance, etc.).

## 3. Synthesis Lead consolidates

Agent 08 (Synthesis Lead) reads all reports and produces `.review-notes/08-final-report.md`
with:

- Executive summary
- Scores by dimension (1–10 scale, harsh but fair)
- Critical risks and blockers
- Architectural debt
- Top 20 actions (prioritized by impact / effort)
- Quick wins
- Strategic recommendations

## 4. Review the final report

Open `.review-notes/08-final-report.md`. Look for:

- **Critical risks** — fix before shipping.
- **Architectural debt** — plan refactors.
- **Top 20 actions** — prioritize by impact × urgency / effort.
- **Quick wins** — do immediately.

## 5. Act on findings

Create GitHub issues for:

- Each critical risk (link to `.review-notes/` evidence).
- Each architectural debt item.
- Top 10–20 actions (depending on team capacity).

File out-of-scope findings as backlog items.

## 6. Capture what's durable

`.review-notes/` is disposable process exhaust — it is gitignored and never
committed. Before moving on, capture anything worth keeping: file the critical
risks as GitHub issues and fold durable findings into committed docs. The notes
themselves are regenerated on the next audit.

**Done when** the critical risks are triaged into issues, and the team has
reviewed and discussed the findings.
