# audit — assess-mode briefs

What each assess-mode role examines and reports. Every role reads
`.audit-notes/00-map.md` (and any earlier notes) before writing its own file,
cites files and line numbers for every finding, and ends with a "notes to the
next role" section.

## 00 Mapper → `.audit-notes/00-map.md`

Static intake, no judgments: directory structure (2 levels, ignoring
node_modules/.git/venv), runtime and package manager, entry points, project
type, approximate LOC, top dependencies, build and test tools,
generated/vendor/build paths, branch inventory (local vs remote, merged vs
unmerged, protected/default). Flag anything unusual for downstream roles.

## 01 Health Assessor → `.audit-notes/01-health.md`

Three dimensions, each scored 1–10:

- **Documentation** — README (purpose/setup/usage), CLAUDE.md/AGENTS.md,
  contribution guide, API and architecture docs, ops docs. What could a new
  developer not figure out? Is anything documented that the code disproves?
  Also: does any current-state document keep a second account of change over
  time that a record or Git already owns? Classify with
  [`provenance-leakage.md`](provenance-leakage.md) and its producer rather than
  judging by eye — a document that merely *cites* history is not a finding.
- **Architecture** — layer/module structure, patterns, coupling and cohesion,
  state management, error-handling strategy, scalability assumptions, code
  reuse, testability (mockable dependencies, clean seams), architectural debt.
- **Code quality** — run the repo's linter if present; formatting consistency,
  complexity hotspots, code smells (dead code, magic numbers, deep nesting),
  naming clarity, comment quality (*why*, not *what*), quick wins. Where a
  branch diff exists, carry the native `/code-review` results rather than
  re-deriving them.

## 02 Reliability Assessor → `.audit-notes/02-reliability.md`

Three dimensions, each scored 1–10:

- **Testing & reliability** — coverage and gaps in critical paths, test-type
  balance, error and null handling, async/concurrency risks, logging quality,
  type safety, single points of failure.
- **Security & config** — secrets in code or logs, authn/authz, input
  validation, dependency CVEs (`npm audit`, `safety`, …), secrets-management
  strategy, environment separation, insecure defaults. Where a branch diff
  exists, carry the native `/security-review` results rather than re-deriving
  the vulnerability pass.
- **Product readiness** — feature completeness vs what the README promises,
  core user flows, performance vs targets, observability, operational
  readiness (health checks, deploys), known TODOs/hacks.

## 04 Synthesis Lead → `.audit-notes/04-report.md`

Reads every note and produces the deliverable:

1. **Executive summary** — one paragraph: overall health, critical blockers,
   readiness.
2. **Scores by dimension** — the six dimensions above, each 1–10, plus an
   overall health score. Harsh but fair: 1–3 critical work needed; 4–6 solid
   foundation with gaps; 7–9 strong with minor polish; 10 rare —
   production-ready with best practices.
3. **Critical risks** — what blocks shipping or threatens production.
4. **Debt lists** — architectural debt, testing gaps, security findings,
   documentation gaps.
5. **Top actions** (up to 20) — ranked by impact × urgency / effort, each with
   effort (S/M/L) and impact (S/M/H).
6. **Quick wins** and strategic recommendations.

Every score and risk cites its evidence. The report is presented in-session;
durable findings are filed as GitHub issues with the evidence pasted in.
