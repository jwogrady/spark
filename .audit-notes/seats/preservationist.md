# Preservationist — Phase 2 Verdicts

Seat lens: defend artifacts that add real project-specific value Claude-native
cannot. Argue LIVE where killing it would lose something genuine. Concede
cleanly where value is duplicated.

Author's law applied throughout: one job, one place; reference native don't
reimplement; keep only what adds Spark-specific value.

---

## The Blocking Decision First: codify vs. build

The author's new law says codify=CODING/IMPLEMENTATION. The actual codify
SKILL.md does INTERNAL KNOWLEDGE CAPTURE — a 6-agent crew for ADRs, SOPs,
product specs, and glossary entries. CODING is already owned by build (Generate
stage). The law as stated creates a three-way collision: codify (current
reality), build (existing owner of CODING), and the law's redefinition.

Preservationist position: the knowledge-capture function of codify is REAL,
IRREPLACEABLE, and has NO Claude-native equivalent. Claude can write documents,
but it has no native specialist crew with intake barriers, fact/assumption
separation, librarian dedup, and Status26 vocabulary enforcement. Killing
knowledge-capture to satisfy a naming collision would destroy genuine value.

Resolution I argue for: codify's lane name is KNOWLEDGE (not CODING). Build
owns CODING. The law must be amended on the lane label, not on the function.
Both skills survive in distinct lanes.

---

## Verdicts

### ideate — LIVE
Lane: exploration
Reason: Lifecycle stage 1. The EXPLORATION lane per author law. Its job is
crisp and unique: turn fuzzy intent into a written problem statement with
success criteria. Claude brainstorms natively, but it does not enforce "no code,
no file layout, no tickets yet" — that discipline is the Spark-specific value.
The confirm-before-handing-off guardrail prevents the most common failure mode
(jumping to implementation before the problem is understood). No native
equivalent enforces this scope boundary. LIVE.

### plan — LIVE
Lane: planning
Reason: Lifecycle stage 2. Converts a problem statement into GitHub-ready issues
using the repo's own .github/ISSUE_TEMPLATE/ files, with a mandatory
confirm-before-creating-on-GitHub guardrail. Claude can draft issues natively
and call gh CLI, but it will not enforce the confirm barrier or automatically
use Spark's issue templates. The discipline (3–7 features, acceptance criteria as
verifiable contracts, no inventing label taxonomies) is Spark-specific value
that prevents low-quality issues polluting the backlog. LIVE.

### build — LIVE
Lane: coding (Generate stage)
Reason: Lifecycle stage 3. Implements exactly one issue, scoped to its
acceptance criteria, on a feature branch. Claude codes natively — this is the
thinnest skill in the set. BUT: the one-issue-per-branch discipline, the
"go back to plan if AC are missing/vague" rule, and the explicit "stop and open
a new issue for anything out of scope" guardrail are Spark enforcement, not
native behavior. Without this skill, Claude will expand scope opportunistically.
The guardrail cost is very low (it's a short skill) and the scoping value is
real. LIVE — but this is the weakest LIVE in the roster. If the council decides
to consolidate, build is the first candidate for absorption into a short section
of CLAUDE.md rather than a standalone skill.

### fix-issue — LIVE
Lane: solve
Reason: The gold-standard reference pattern. It explicitly references /code-review,
/security-review, and verify rather than reimplementing them. Its unique value is
the triage taxonomy (must-fix / should-fix / out-of-scope), the mandate that
out-of-scope findings become new issues rather than silent drops, and the
definition-of-done check against acceptance criteria. This is precisely the
behavior the author's law asks for: reference native, add Spark-specific value.
LIVE. Use this as the template for any skill that touches native capabilities.

### commit — LIVE
Lane: git-guardrails
Reason: The hooks enforce rules mechanically; this skill enforces them
doctrinally — it tells Claude why the rules exist and how to produce a passing
message the first time. The "no AI attribution" rule in particular is Spark/
jwogrady-specific and is not a Claude default. Without this skill, Claude will
add Co-Authored-By lines for itself. The conventional commit enforcement,
imperative subject, and why-body requirement are all Spark doctrine, not
native behavior. Justified. LIVE.

### ship — LIVE
Lane: git-guardrails
Reason: Same argument as commit. The no-force-push and no-trunk-push guardrails
are enforced by hooks mechanically, but this skill is the doctrine that tells
Claude how to produce a passing push+PR the first time. The "no AI attribution
in the PR body" and "one concern per PR" rules are Spark-specific, not native
Claude defaults. Claude will open PRs natively but will not self-enforce these
constraints without the doctrine. LIVE.

### review — LIVE
Lane: solve/qc
Reason: The breadth argument wins. Native /code-review + /security-review cover
correctness and security. review adds architecture, testing, documentation,
product readiness, and risk — five dimensions with no native equivalent. The
shared .review-notes/ mechanism enabling sequential agents to read each other's
work is a real orchestration pattern that Claude-native does not provide. The
docit crew borrows this same pattern. LIVE — with the caveat that the two
agents whose dimensions overlap native (code quality, security) should
explicitly delegate to /code-review and /security-review rather than
re-analyzing independently. That is a calibration fix inside the skill, not
a kill.

### docit + agents/docit/ crew (13) — LIVE
Lane: documentation
Reason: The persona-crew orchestration is irreplaceable. Claude writes docs
natively — no dispute. What it does not provide: 13 specialized personas each
owning a distinct audience perspective (Skimmer, Adopter, Skeptic, Evaluator,
Believer, Coach, Contributor, Visual Storyteller, Returning User, Discoverer,
Amplifier, Editor-in-Chief, Cartographer), cross-evaluation between neighbors,
an Issue Council vote, and a ground-truth barrier that prevents honest-hype
violations. This is a genuine multi-agent orchestration that produces
qualitatively different output than "Claude, write me a README." The Diátaxis
structure (tutorials/how-to/reference/explanation), launch copy, changelog
ownership, and SEO persona are each Spark-specific value layers. LIVE. The
crew is treated as a single artifact with the skill.

### codify + agents/codify/ crew (6) — LIVE
Lane: knowledge (NOT coding — see blocking decision above)
Reason: The knowledge-capture function is real and irreplaceable. Claude can
write documents natively. What it does not provide: an intake barrier that
structures messy founder notes into facts/assumptions/open-questions before
any drafting; specialist routing (architect vs. product vs. ops) based on doc
type; a librarian that enforces dedup against existing docs, canonical placement,
and glossary consistency; an editor that enforces internal vs. external tone
and Status26 vocabulary; the "capture truth, mark uncertainty" discipline with
explicit fact/assumption separation. This is the inward counterpart to docit,
not a duplication of build. LIVE — but only if the council accepts my
resolution of the codify-vs-build collision: codify's lane is KNOWLEDGE, not
CODING. The crew is treated as a single artifact with the skill.

### connect — LIVE
Lane: setup
Reason: The secrets lifecycle (capture → ingest → shred → inject) via 1Password
op CLI with the shred-env safety step is entirely Spark/jwogrady-specific. No
Claude-native capability handles 1Password vault creation, op item create
commands, .env.tmpl reference files, smoke-test verification, or secure
plaintext deletion. The "propose, don't auto-write to vault" guardrail
prevents irreversible vault writes. This is the highest-specificity skill in
the set: it encodes a concrete tool (1Password op CLI), a concrete workflow
(per-project keys, shred-only-after-verify), and concrete outputs (.env.tmpl,
vault items). LIVE.

### bootstrap — LIVE
Lane: setup
Reason: The Bun-for-TS / uv-for-Python defaults with non-interactive scaffolder
flags are Spark-opinionated choices that Claude-native does not enforce. Claude
will happily use npm, pip, or poetry if the project doesn't specify. bootstrap
pins the runtime/PM choice and provides the per-framework quality-gate defaults
(formatter/linter, test runner) via references/profiles.md. The "runtime/PM is
fixed" guardrail is the Spark value: it prevents drift across projects in the
portfolio. The layering sequence (scaffold → quality gates → Spark wiring via
claude-md/agents-md/connect) is also Spark-specific. LIVE.

### claude-md — LIVE (scope-narrowed)
Lane: documentation (agent-config)
Reason: This skill has real Spark-specific value in the maintenance and
Spark-doctrine-injection job. A CLAUDE.md without the attribution rules, the
Spark guardrails section, the conventional commits doctrine, and the agent safety
rules is a lesser artifact than one with them. However, the inventory is correct
that native /init handles net-new creation. This skill's description must be
updated to say: "maintain and inject Spark doctrine into CLAUDE.md; for
net-new creation, defer to /init." The content rules (required sections, section
content standards, behavior rules) are Spark-specific doctrine with no native
equivalent. LIVE — but must narrow its description to maintenance+injection,
explicitly deferring to /init for creation.

### agents-md — LIVE
Lane: documentation (agent-config)
Reason: No native equivalent exists for AGENTS.md. /init only creates CLAUDE.md.
agents-md generates and maintains the tool-agnostic behavioral contract that
applies to any AI agent (not just Claude Code). The sync-audit output type
(comparing AGENTS.md against CLAUDE.md to find drift) is unique value. The
Spark attribution rules, GitHub write-boundary rules, and scope-discipline rules
encoded in agents-md are the same Spark-specific doctrine as claude-md — they
just target all agents. LIVE.

### fork-init — DIE (architecturally obsolete)
Lane: setup
Reason: The plugin model documented in CLAUDE.md supersedes fork-init's premise.
CLAUDE.md says: "install it (`/plugin marketplace add jwogrady/spark` → `/plugin
install spark`)." fork-init's mental model is "clone Spark, rename remote to
upstream, wire downstream project." These are two incompatible distribution
models. Furthermore: fork-init is Draft — runtime not yet implemented, spark init
does not exist, and Step 5 is explicitly a placeholder. It documents a workflow
that conflicts with the live distribution model and has never been implemented.
The guidance it contains (git remote rename, inception branch, upstream pull
pattern) is standard git knowledge that Claude provides natively without a skill.
The project-inception job is handled by bootstrap + connect under the plugin
model. DIE — killed by architectural obsolescence and zero implementation.

### grill-me — DIE (verbatim native duplicate)
Lane: exploration
Reason: The overlap map is definitive: Spark's grill-me SKILL.md is word-for-word
identical to the Claude-native grill-me available-skill (description field,
trigger language, body). Zero Spark-specific value. ideate correctly invokes
grill-me; it should reference the native skill directly. The directory is dead
weight. DIE — covered by native grill-me.

### write-a-skill — DIE (Spark-naivete, no Spark-specific value beyond what CLI stamps)
Lane: other
Reason: The authoring doctrine in write-a-skill (description format rules,
100-line limit, progressive disclosure, when-to-split, review checklist) is
Anthropic's skill spec doctrine, not Spark's. It does not reference Spark
conventions beyond what spark new-skill already stamps in the scaffold. The
content ("description is the only thing your agent sees," the template, the
review checklist) is generic plugin-spec guidance that belongs in the Spark
CLAUDE.md or as a reference appendix in spark new-skill's help text — not as a
separate skill. The CLI already creates the file tree; this skill adds a
design-conversation layer whose content is not Spark-specific. Killing it loses
nothing that isn't already covered by: (a) spark new-skill for file creation,
(b) Claude-native capability for drafting any markdown file, and (c) Spark's
CLAUDE.md "Skill Authoring" section for doctrine. DIE — covered by spark new-skill
CLI + Claude-native + CLAUDE.md skill authoring section.

---

## CLI Subcommand Verdicts

### spark doctor — LIVE
Validates plugin layout, manifest/hook JSON, skill frontmatter. No native
equivalent. Spark-specific integrity check.

### spark new-skill — LIVE
Deterministic file scaffold for a new skill directory. Stamps correct structure.
No native equivalent (native /init is for CLAUDE.md, not skill scaffolding).
Absorbs the file-creation job from write-a-skill.

### spark install-git-hooks — LIVE
Wires commit-msg and pre-commit hooks into the downstream project. No native
equivalent. Critical for guardrail enforcement.

### spark shred-env — LIVE
Secure deletion of plaintext .env after connect ingests to vault. No native
equivalent. Security-critical, referenced by connect.

### spark list-skills / help — LIVE
Discovery and CLI hygiene. No overlap concern.

---

## Summary Table

| artifact | verdict | reason |
|---|---|---|
| ideate | LIVE | Lifecycle stage 1; scope-discipline guardrail has no native equivalent |
| plan | LIVE | Lifecycle stage 2; confirm-before-create + template discipline |
| build | LIVE | Lifecycle stage 3; one-issue-scoped branch discipline |
| fix-issue | LIVE | Gold-standard reference pattern; triage taxonomy + AC check |
| commit | LIVE | No-AI-attribution + conventional commit doctrine |
| ship | LIVE | No-force-push + one-concern-per-PR doctrine |
| review | LIVE | Five breadth dimensions have no native equivalent |
| docit + crew | LIVE | 13-persona crew + ground-truth barrier + Issue Council |
| codify + crew | LIVE | Knowledge-capture crew; lane = KNOWLEDGE not CODING |
| connect | LIVE | 1Password secrets lifecycle; highest specificity skill |
| bootstrap | LIVE | Bun/uv pinning + quality gates + Spark wiring sequence |
| claude-md | LIVE (scope-narrow) | Maintenance + Spark-doctrine injection; defer creation to /init |
| agents-md | LIVE | No native AGENTS.md equivalent exists |
| fork-init | DIE | Conflicts with plugin model; unimplemented; native git covers the steps |
| grill-me | DIE | Verbatim native duplicate; zero Spark-specific value |
| write-a-skill | DIE | Generic plugin-spec doctrine; absorbed by spark new-skill + CLAUDE.md |
