# review — collaboration protocol

How the 8 agents share findings, coordinate reads, and produce a coherent final report.
Like Spark's other crews, the main loop is the sole orchestrator and the agents
coordinate only through shared notes — the general pattern lives in
the architecture map;
this file covers what's specific to `review`.

---

## Execution order

Agents run sequentially, not in parallel:

```
00 Project Mapper        (reads: nothing yet)
   ↓ outputs to .review-notes/00-project-map.md
01 Documentation Reviewer (reads: 00)
   ↓ outputs to .review-notes/01-documentation.md
02 Architecture Reviewer  (reads: 00, 01)
   ↓ outputs to .review-notes/02-architecture.md
03 Code Quality Reviewer  (reads: 00, 02)
   ↓ outputs to .review-notes/03-code-quality.md
04 Testing & Reliability  (reads: 00, 02, 03)
   ↓ outputs to .review-notes/04-testing-reliability.md
05 Security & Config      (reads: 00, 01, 04)
   ↓ outputs to .review-notes/05-security-config.md
06 Product Readiness      (reads: 00, 01, 02, 05)
   ↓ outputs to .review-notes/06-product-readiness.md
07 Custom Focus (optional) (reads: all prior)
   ↓ outputs to .review-notes/07-custom-focus.md
08 Synthesis Lead         (reads: 00–07)
   ↓ outputs to .review-notes/08-final-report.md
```

---

## Shared notes structure

Each agent writes one markdown file to `.review-notes/` with the following sections.
Use consistent formatting so Synthesis Lead can parse and cross-reference.

### Header

```markdown
# [Agent Name]

**Date:** [ISO 8601 date]
**Reviewer:** jwogrady
```

### Finding section

```markdown
## Finding

[Your assessment of this dimension. 2–3 paragraphs. Be specific: link to files,
line numbers, code snippets. Avoid vague claims.]
```

### Evidence section

```markdown
## Evidence

- **File `src/main.ts` lines 42–67:** [Describe what you found here.]
- **Test coverage:** 67% (from `npm run coverage`); missing coverage in error handlers.
- **Linting:** 3 ESLint violations (function too complex, unused var, missing docstring).
- **Architecture:** Layers are MVC; controllers tightly coupled to service layer.
```

### Scoring section

```markdown
## Scoring

**Dimension:** [Agent-specific focus; e.g., "Code Readability"]

**Score:** [1–10]

**Rationale:** [2–3 sentences explaining the score. Be harsh but fair.]
```

### Notes for next agent

```markdown
## Notes to Next Agent

- [Key finding that affects your downstream analysis.]
- [Question you had; maybe the next agent can answer it.]
- [Recommendation or caution.]

**Critical:** Flag if something is a blocker or urgently needs attention.
```

---

## Scoring rubric (universal)

All agents use the same 1–10 scale:

| Score | Meaning | Examples |
|-------|---------|----------|
| 1–2 | Critical | Broken, unusable, dangerous. Code doesn't run. Security holes. |
| 3 | Severe | Major issues that must be fixed before shipping. 50%+ work needed. |
| 4–5 | Weak | Solid foundation but gaps remain. Needs work before production. |
| 6–7 | Good | Functional and mostly complete. Minor polish or debt. |
| 8–9 | Strong | Well-engineered, best practices, production-ready. Rare polish issues. |
| 10 | Excellent | Rare. Best-in-class, zero known issues, exemplary. |

**Harsh but fair:** If something is broken, score it 1–3, don't soften it. If it's solid
but has gaps, score it 4–6. Don't score 10 unless it's truly excellent.

---

## Evidence requirements

Every finding must cite evidence. No vague claims.

**Required for each claim:**
- **File path** (relative to project root).
- **Line numbers** (if applicable).
- **Code snippet or exact observation** (quote what you found).
- **Impact** (why does this matter?).

**Examples:**

❌ Bad: "The code is hard to read."
✅ Good: "Function `parseResponse()` in `src/api.ts` lines 42–87 has 8 nested if-statements and a cognitive complexity of 24 (vs. recommended 10). This makes it hard to reason about and test all paths."

❌ Bad: "There are no tests."
✅ Good: "`src/utils/date.ts` has no test file. Functions `parseDate()` and `formatDate()` handle edge cases (leap years, DST) but no tests cover them. Recommend `src/utils/__tests__/date.test.ts`."

---

## Collaboration patterns

### "Notes to next agent" are the handoff mechanism

- **Agent 00** notes: "Monorepo detected (3 packages). This affects dependency analysis."
- **Agent 01** reads Agent 00, notes: "README covers the main app but not the 3 internal packages. Consider separate READMEs."
- **Agent 02** reads Agents 00 & 01, notes: "Module boundaries are unclear between packages. See missing interfaces."

This chain of notes becomes the narrative Synthesis Lead weaves together.

### Questions agents can't answer

If you can't answer something, ask in "Notes to next agent". Example:

> "**Question for later agent:** The TypeScript `strict` mode is on, but I see a few
> `any` types in `src/api/client.ts`. Are these intentional? Should strict be enforced
> everywhere?"

Synthesis Lead will integrate questions and uncertainties into the final report.

---

## The Synthesis Lead's job

After reading all 7 agents:

1. **Identify cross-cutting themes:**
   - If multiple agents mention testing gaps, that's a critical issue.
   - If architecture and code quality agents both mention coupling, highlight it.

2. **Resolve conflicts:**
   - If Agent 02 says "design is scalable" but Agent 04 says "no load testing," note the gap.

3. **Score each dimension:**
   - Average the relevant agent scores, weighted by severity.
   - Architecture score = Agent 02 + weighted implications from Agents 04, 05, 06.

4. **Identify critical risks:**
   - Severity = High (blocks shipping), Medium (needs fix before 1.0), Low (nice to fix).
   - Examples: "No auth (High)", "Linting disabled (Medium)", "Missing API docs (Low)".

5. **Extract top 20 actions:**
   - Each action is a specific, actionable item.
   - Format: **[Action title]** (Effort: S/M/L, Impact: S/M/H, Owner: [Which agent found it]).
   - Sort by: Impact / Effort, then urgency.

6. **Produce the final report:**
   - See agent-specs.md for the 14 required sections.

---

## Attribution

- **Every section authored by:** `jwogrady` (the human, the author of this codebase).
- **Never credit** Claude, Anthropic, ChatGPT, Copilot, or any AI system.
- **In `.review-notes/`, use:** "**Reviewer:** jwogrady" (or omit if implied by context).
- **In the final report, if attribution is needed,** write: "Reviewed by jwogrady."

This is a human-led audit that uses AI agents as tools. The human owns the findings.

---

## Output and handoff

- Durable outcomes leave the scratch: critical risks and top actions become
  GitHub issues (with the evidence pasted in), and anything else worth keeping
  is folded into committed docs.
- `.review-notes/` is scratch — gitignored, not committed. It holds the audit's
  working evidence for the duration of a run; the next audit regenerates it.
