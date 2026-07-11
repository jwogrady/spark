# ADR: The plugin ships only carry surfaces — consolidate the audit, extract the rest

Date: 2026-07-11
Status: Accepted
Owner: jwogrady

## Context

The conformance audit (ADR-0008's required test, recorded in
`docs/architecture/conformance.md`) classifies four of the plugin's twelve
skills — `review`, `cleanup`, `docit`, `connect` — as support serving none of
the three carry motions. Together they account for nineteen of the plugin's
nineteen subagent definitions, three near-duplicate orchestration protocols,
and the only skill that emits a prompt instead of acting. Adjacent dead
weight: the agent-contract skill carries reference files from a pre-plugin
skill format nothing consumes, the operator knowledge store's `decisions.md`
half has no reader by its own documentation, and the committed work state has
no defined end-of-loop, so it goes stale the moment its recorded pull request
merges. The operator reviewed a feature-by-feature verdict table and the
repositioned README (the solo-developer force-multiplier framing) and
directed consolidation.

## Decision

- **One `audit` skill replaces `review` and `cleanup`.** It audits a whole
  project on demand and acts directly — no copy-paste orchestrator prompt.
  It keeps cleanup's evidence table (claim, evidence, confidence, action,
  risk, validation), deletion-safety categories, and human approval gate,
  and review's assessment dimensions; diff-level review stays with the
  native reviewers.
- **`docit` leaves the plugin.** Public positioning, launch copy, and the
  thirteen-persona council are a separate product; its new home is seeded
  from this repository's git history, not maintained here.
- **`connect` leaves the plugin; `shred-env` stays.** The 1Password service
  bootstrap is provider-specific and carries security weight unrelated to
  the lifecycle. Secure deletion of transient secrets files is generic CLI
  hygiene and remains.
- **`knowledge` keeps glossary promotion; `decisions.md` is deferred.** No
  shipped surface reads the decisions store, so the protocol stops shipping
  an accumulating file until a reader earns it.
- **`agents-md` drops its pre-plugin relics** (structured I/O schema, system
  prompt, examples, `openai.yaml`), and repo templates stop demanding
  artifacts skills do not ship.
- **The work state gets a defined loop close.** When the recorded pull
  request is merged, the state names the loop restart rather than a stale
  next action.

Why: the plugin's identity is the operator's standard, carried. Every
shipped surface is something the operator must understand, doctor must
validate, and the docs must explain — so surface that serves no motion is
not neutral, it is dilution. Consolidation makes the repositioned README's
promise literally true.

## Alternatives Considered

- **Keep everything (status quo).** Rejected: four skills and nineteen
  agents of non-motion surface is the dilution the identity doc warns
  against; the maintenance cost recurs every release.
- **Delete review and cleanup without merging them.** Rejected: whole-repo
  evidence-based hygiene is real value the native diff reviewers do not
  cover; the discipline is worth one skill.
- **Ship docit/connect as additional plugins in this marketplace.**
  Deferred, not rejected: the marketplace can list more than one plugin,
  but a second product deserves its own cadence and repo; deciding its home
  here would couple the two.

## Consequences

- Skill count drops from twelve to nine (five lifecycle, `bootstrap`,
  `knowledge`, `agents-md`, `audit`); subagent definitions from nineteen to
  six.
- The taxonomy, chooser, conformance table, native-overlap audit, glossary
  crew counts, and every doc surface must be updated together — doctor's
  link scan and the one-canonical-source rule are the guard.
- Removal is recoverable: extraction PRs are the seed commits for the
  extracted products' future repos.
- The CHANGELOG records the removals as user-facing changes, as it did for
  `caveman`, `handoff`, and `commit`.

## Open Questions

- Where the extracted docit and connect products live (separate repos vs.
  additional plugins in this marketplace) — owner: jwogrady.

## Related Docs

- [0008-information-architecture.md](0008-information-architecture.md) — the motion test this applies
- [0002-additive-to-anthropic-spec.md](0002-additive-to-anthropic-spec.md) — why diff review stays native
- `docs/architecture/conformance.md` — the audit whose verdicts this implements
