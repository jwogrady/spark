# review — agent specifications

Detailed mission, tasks, required reads, outputs, and handoff notes for each agent.

---

## Agent 00 — Project Mapper

**Mission:** Static analysis of project structure, tech stack, and complexity.

**Tasks:**
- List directory structure (up to 2 levels), ignoring node_modules, .git, venv, etc.
- Identify runtime (Bun, Node, Python, Go, Rust) and package manager.
- List top-level dependencies (packages, frameworks, libraries).
- Identify entry points: main(), index.ts, server.py, app.js, etc.
- Classify project type: library, app, monorepo, service, etc.
- Count approximate lines of code (via `cloc` or `find | wc`).
- Note any build system (Webpack, Vite, tsc, Cargo, etc.).
- Detect test framework (Jest, Vitest, pytest, Mocha, etc.).

**Required reads:**
- None (first agent).

**Outputs to `.review-notes/00-project-map.md`:**
- Project type and purpose (inferred from package.json, Cargo.toml, pyproject.toml).
- Tech stack summary (language, runtime, key frameworks).
- File structure (tree, 2 levels).
- Approximate LOC.
- Entry points.
- Dependencies list (top 10–15).
- Build and test tools.

**Scoring rubric (1–10):**
- Clarity of structure (1 = chaotic, 10 = crystal-clear).

**Notes to next agent:**
- Highlight any unusual structure or missing typical files.
- Flag if it's a monorepo (multiple projects) vs. single project.

---

## Agent 01 — Documentation Reviewer

**Mission:** Assess whether the project is self-documenting and easy to onboard into.

**Tasks:**
- Check for README (exists, quality, completeness).
- Review CLAUDE.md (if exists): project guide, standards, guardrails.
- Check CONTRIBUTING.md or similar (setup, workflow, standards).
- Review API docs (docstrings, API reference, examples).
- Check for architecture docs (design decisions, patterns, migrations).
- Assess tutorial/getting-started guides.
- Look for deployment or operations docs.
- Grade the docs by completeness and accuracy.

**Required reads:**
- 00-project-map.md (understand the tech stack and structure).

**Outputs to `.review-notes/01-documentation.md`:**
- README assessment (exists, quality, covers purpose/setup/usage).
- API documentation (level of detail, examples).
- Architecture and design docs (exist, current, useful).
- Contribution guide (exists, clear).
- Deployment/ops docs (exist, up-to-date).
- Major gaps (what a new dev couldn't figure out).

**Scoring rubric (1–10):**
- How quickly can a developer get productive? (1 = lost, 10 = fully guided).

**Notes to next agent:**
- Link to any architecture docs the Architecture Reviewer should read.
- Note if README is out of sync with actual code.

---

## Agent 02 — Architecture Reviewer

**Mission:** Evaluate design patterns, module boundaries, and long-term sustainability.

**Tasks:**
- Understand the layer/module structure (presentation, logic, data, etc.).
- Identify design patterns used (MVC, Redux, MVVM, layered, etc.).
- Assess module coupling and cohesion (are boundaries clean?).
- Review state management approach (global state, local state, database).
- Check error handling strategy (exceptions, result types, fallbacks).
- Evaluate scalability assumptions (threading, async, DB queries, caching).
- Look for code reuse (DRY, no copy-paste classes).
- Assess testability (mockable dependencies, clear seams).

**Required reads:**
- 00-project-map.md (understand the structure).
- 01-documentation.md (architecture design docs, if any).

**Outputs to `.review-notes/02-architecture.md`:**
- Layer structure and design pattern.
- Coupling assessment (tight/loose, justified).
- State management approach (appropriate for the project?).
- Error handling strategy (consistent, complete).
- Scalability considerations (will this design hold at 10x traffic?).
- Code reuse health (DRY, no duplication hotspots).
- Testability (are dependencies mockable, are there clean seams?).
- Architectural debt (design decisions that need rethinking).

**Scoring rubric (1–10):**
- Is the design coherent, sustainable, and scalable? (1 = spaghetti, 10 = textbook).

**Notes to next agent:**
- Flag layers that are hard to test (Code Quality Reviewer will care).
- Note any state-management complexities the Testing Reviewer should inspect.

---

## Agent 03 — Code Quality Reviewer

**Mission:** Inspect code readability, style consistency, and maintainability —
*on top of* Claude Code's native `/code-review`, never re-running its analysis.

**Tasks:**
- **Delegate to native first.** Run Claude Code's built-in `/code-review` for
  correctness bugs and reuse/simplification/efficiency findings, and carry its
  results into your report rather than re-deriving them by hand. Then add only the
  dimensions native review does not focus on (below).
- Run linter (ESLint, Ruff, Clippy, etc.) and document violations.
- Assess code formatting (consistent indentation, naming conventions).
- Check complexity metrics (cyclomatic, cognitive; flag high-complexity functions).
- Review for code smells (large functions, deep nesting, magic numbers).
- Assess naming (are variables, functions, classes clearly named?).
- Look for dead code, unused variables, or commented-out blocks.
- Check for consistent error messages and logging.
- Assess code comments (only on *why*, not *what*?).

**Required reads:**
- 00-project-map.md (understand the tech stack and tools).
- 02-architecture.md (what module boundaries should we respect?).

**Outputs to `.review-notes/03-code-quality.md`:**
- Linting results (passes, or major violations).
- Formatting consistency (good, needs work).
- Complexity hotspots (flagged files/functions, recommended refactors).
- Code smell assessment (dead code, unused vars, magic numbers).
- Naming clarity (good, inconsistent, unclear).
- Comment quality (appropriate, over-commented, sparse).
- Quick wins (low-effort refactors that improve clarity).

**Scoring rubric (1–10):**
- Is the code clean, consistent, and easy to read? (1 = hard to parse, 10 = delightful).

**Notes to next agent:**
- Link specific files that need testing focus (Testing Reviewer).
- Note if linting is not automated (should be added to CI).

---

## Agent 04 — Testing & Reliability Reviewer

**Mission:** Assess test coverage, edge-case handling, and production resilience.

**Tasks:**
- Check test coverage (% of code covered, gaps in critical paths).
- Review test types (unit, integration, e2e; are they balanced?).
- Inspect error handling (exceptions, edge cases, boundaries).
- Check null/undefined handling (is the code defensive?).
- Review async/concurrency handling (race conditions, timeouts).
- Assess logging (are errors logged with enough context?).
- Look for timeout logic (are there deadlock risks?).
- Check type safety (TS strict mode, mypy, runtime checks).

**Required reads:**
- 00-project-map.md (understand test tools and structure).
- 02-architecture.md (understand layers and dependencies).
- 03-code-quality.md (hotspots flagged by Code Quality Reviewer).

**Outputs to `.review-notes/04-testing-reliability.md`:**
- Test coverage (% covered, gaps in critical paths).
- Test balance (unit/integration/e2e ratio, reasonable?).
- Error handling (comprehensive, missing edge cases?).
- Null/undefined safety (defensive coding, trust boundaries).
- Async handling (race conditions, timeouts, deadlocks).
- Logging quality (is debugging possible in production?).
- Type safety (strict mode, or runtime holes?).
- Reliability risks (single points of failure, cascading failures).

**Scoring rubric (1–10):**
- Can we run this in production without fear? (1 = fragile, 10 = battle-tested).

**Notes to next agent:**
- Flag any secrets or credentials visible in logs.
- Note if there's no monitoring/observability (Security Reviewer will follow up).

---

## Agent 05 — Security & Configuration Reviewer

**Mission:** Protect user data, secrets, and system integrity — *on top of* Claude
Code's native `/security-review`, never re-running its analysis.

**Tasks:**
- **Delegate to native first.** Run Claude Code's built-in `/security-review` for
  the core vulnerability pass (injection, auth, input validation, CVEs), and carry
  its results into your report rather than re-deriving them. Then add the
  configuration and secrets-lifecycle dimensions it does not cover (below).
- Check for secrets in code or config (API keys, passwords, tokens).
- Review authentication/authorization (is access controlled?).
- Assess input validation (are user inputs sanitized?).
- Check for injection vulnerabilities (SQL, XSS, command injection).
- Review dependency CVEs (using a tool like `npm audit`, `safety`, etc.).
- Assess compliance readiness (GDPR, PCI-DSS if relevant).
- Check for insecure defaults (is security the default, not an afterthought?).
- Review secrets management strategy (1Password, env vars, vaults).
- Check for environment-specific config (dev/test/prod properly separated?).

**Required reads:**
- 00-project-map.md (understand dependencies and entry points).
- 01-documentation.md (any security or compliance requirements mentioned?).
- 04-testing-reliability.md (error messages; any secrets in logs?).

**Outputs to `.review-notes/05-security-config.md`:**
- Secrets exposure (if any found, severity and remediation).
- Authentication/authorization approach (is it robust?).
- Input validation (comprehensive, gaps?).
- Known CVEs (outstanding vulnerabilities, patch strategy).
- Compliance posture (what standards apply; are we meeting them?).
- Secrets management (how are credentials stored and rotated?).
- Environment separation (dev/test/prod properly isolated?).
- Security misconfiguration (insecure defaults, permissions, CORS).

**Scoring rubric (1–10):**
- Is user data and the system protected? (1 = full of holes, 10 = hardened).

**Notes to next agent:**
- Flag critical vulnerabilities that Product Readiness Reviewer should know.
- Note if there's no secrets rotation policy.

---

## Agent 06 — Product Readiness Reviewer

**Mission:** Ensure the product is complete, performant, and ready to ship.

**Tasks:**
- Check feature completeness (are core features done?).
- Assess user flows (can users accomplish their goals?).
- Benchmark performance (load time, API latency, resource usage).
- Check observability (logging, metrics, error tracking).
- Review user experience (UI/UX, accessibility basics).
- Assess operational readiness (health checks, graceful shutdown, restarts).
- Check for known issues or TODOs in code.
- Verify deployment process (clear steps, no manual hacks).

**Required reads:**
- 00-project-map.md (understand the project type and tech).
- 01-documentation.md (what was promised in the README?).
- 02-architecture.md (scalability assumptions).
- 05-security-config.md (are there blocking security issues?).

**Outputs to `.review-notes/06-product-readiness.md`:**
- Feature completeness (what's done, what's TODO?).
- UX assessment (are core flows smooth?).
- Performance baseline (latency, throughput, resource usage vs. targets).
- Observability (can we see what's happening in production?).
- Accessibility (basic checks: keyboard nav, labels, contrast).
- Operational readiness (health checks, graceful shutdown, alerts).
- Known issues (TODOs, hacks, stopgaps that will need fixing).
- Deployment story (is it automated, tested, repeatable?).

**Scoring rubric (1–10):**
- Is this ready to ship and support in production? (1 = many blockers, 10 = ship it).

**Notes to next agent:**
- Flag any major features that are incomplete but shipped.
- Note if there's no observability (critical for production support).

---

## Agent 07 — (Reserved)

Leave this for custom focus. Examples:
- **A11y focus:** Deep dive into accessibility (WCAG 2.1 AA compliance).
- **Performance focus:** Profiling, flame graphs, optimization opportunities.
- **SEO focus:** For marketing/content sites; crawlability, schema, rankings.
- **Mobile focus:** Device testing, touch, responsive design, offline support.

If not used, skip this file.

---

## Agent 08 — Synthesis Lead

**Mission:** Consolidate the 7 agent reports into a single comprehensive audit and
produce a final report with executive summary, critical risks, and top 20 actions.

**Tasks:**
- Read all 7 agent reports (00–06, optionally 07).
- Synthesize findings into a unified narrative.
- Identify cross-cutting themes (e.g., "architecture enables security issues").
- Score each dimension (architecture, code quality, testing, security, product).
- Identify critical risks (severity: high/medium/low, priority for remediation).
- Extract top 20 actionable items (ranked by impact and effort).
- Compile a final report with all required sections (see below).

**Required reads:**
- All reports from agents 00–07.

**Outputs to `.review-notes/08-final-report.md`:**

1. **Executive Summary** — one paragraph: overall health, critical blockers, readiness.
2. **Scores by dimension** — table with Architecture, Code Quality, Testing, Security, Product (each 1–10).
3. **Overall health score** — 1–10 (average, weighted by risk).
4. **Critical risks** — issues that block shipping or threaten production.
5. **Architectural debt** — design decisions that will cost (refactors needed).
6. **Testing gaps** — uncovered scenarios, untested edge cases.
7. **Security findings** — vulnerabilities, misconfigurations, compliance gaps.
8. **Product readiness** — feature gaps, performance targets, UX issues.
9. **Documentation gaps** — what a new dev would struggle with.
10. **Performance baselines** — latency, throughput, resource usage vs. targets.
11. **Observability & ops** — what's missing for production support.
12. **Top 20 actions** — prioritized by impact × urgency / effort. Format:
    - **Priority X:** [Action] (Effort: S/M/L, Impact: S/M/H, Owner: [Agent]).
13. **Quick wins** — low-effort changes with immediate benefit.
14. **Recommendations** — strategic guidance (e.g., "adopt Ruff for linting", "migrate to async/await", "add E2E tests").

**Scoring rubric for final report:**
- Overall health: 1–3 (critical work needed) | 4–6 (solid foundation with gaps) | 7–9 (strong with minor polish) | 10 (rare: production-ready, best practices).

**Notes:**
- Never credit Claude, Anthropic, or any AI system. All analysis is authored by
  `jwogrady` (the human).
