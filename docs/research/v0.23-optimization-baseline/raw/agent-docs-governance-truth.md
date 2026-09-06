I have enough verified material. Writing the report.

---

# Docs/Governance Duplicate-Truth Baseline — issue #737

Worktree `/home/john/code/spark/.claude/worktrees/baseline-921c982`. Read-only; no files modified. Git commands against that path were blocked by session isolation, so the HEAD SHA is taken from the task statement (921c982) and **not independently verified** — everything below is verified against the *files on disk* at that path.

## A) Inventory

| Bucket | Files | Lines (`wc -l`) |
|---|---:|---:|
| `AGENTS.md` (284) + `CLAUDE.md` (8) | 2 | 292 |
| `plugins/spark/docs/` **total** | 33 | 5908 |
| — `README.md` | 1 | 92 |
| — `glossary.md` | 1 | 167 |
| — `tutorials/` | 3 | 552 |
| — `how-to/` | 10 | 544 |
| — `reference/` | 11 | 3711 (`cli.md` alone = 2238) |
| — `explanation/` | 6 | 842 |
| `plugins/spark/skills/*/SKILL.md` | 9 | 766 |
| `plugins/spark/skills/*/references/` | 13 | 1015 |
| `plugins/spark/skills/*/scripts/` (not prose) | 5 | 2055 |
| `plugins/spark/preferences/**` | 14 | 600 |
| `docs/adr/` | 32 (31 ADRs + `0000-template.md`) | 3106 |
| `docs/ops/` | 18 | 4286 |
| `docs/architecture/` | 1 | 243 |
| `docs/releases/` | 13 | 1849 |
| `docs/governance/` | 3 | 506 |
| `docs/research/` | 2 | 101 |
| `docs/alpha/` | 6 | 697 |
| `docs/*.md` (README 65, problem-statement 145, product-constitution 187) | 3 | 397 |
| `README.md` / `ROADMAP.md` / `CHANGELOG.md` | 3 | 325 / 672 / 879 |

**ADR status-line analysis** (line 4 of each ADR). **Zero ADRs carry a bare `Status: Superseded`.** Instead:
- **Partially superseded (7):** 0003, 0004, 0005, 0006, 0007 (four of these only "vocabulary superseded by ADR-0015"), 0011 ("superseded in part by ADR-0018"), 0013 ("extraction-as-removal disposition superseded by ADR-0014").
- **Accepted-but-retired/unimplemented machinery (4):** 0023 ("implementation deferred… not adopted, never measured"), 0024 ("the policy stands, infrastructure unbuilt"), 0025 ("gate machinery retired 2026-08-11"), 0026 ("enforcement retired 2026-08-11").
- **Plain `Status: Accepted` (20)**, plus the template.

Shipped-docs total (5908 + 766 + 1015 = 7689 prose lines) vs never-shipped dev prose (3106+4286+243+1849+506+101+697+397 = 11185 lines) — dev prose is ~1.45× the shipped surface.

## B) Duplicate current-truth concepts

### 1. Five lifecycle stages + nine core skills
**Surfaces: 13 manually maintained current.**
Most authoritative: `plugins/spark/docs/reference/skills.md:8-14` — self-declares "This page is the **canonical skill taxonomy**… if they ever disagree, this page wins", and `spark doctor` mechanically enforces core-skill presence here.
Others: `AGENTS.md:18` + `AGENTS.md:78-104` (OPERATIVE AUTHORITY for agents); `README.md:268-274` (CURRENT REFERENCE-PROJECTION); `plugins/spark/docs/README.md:22` (PROJECTION); `plugins/spark/docs/glossary.md:98-103` (PROJECTION, "Always written with this exact stage order"); `plugins/spark/docs/explanation/sdlc-doctrine.md:11` (EXPLANATION); `plugins/spark/docs/explanation/identity.md:74` (EXPLANATION); `plugins/spark/docs/reference/stability.md:60` ("nine core skills", PROJECTION); `plugins/spark/docs/how-to/get-started.md:57` (PROJECTION); the stage banner repeated verbatim in 6 SKILL.md files (`ideate:8`, `plan:8`, `codify:8`, `validate:8`, `ship:8`, `onboard:99`, `bootstrap:82`) — CURRENT REFERENCE-PROJECTION; `docs/architecture/spark-internals.md:42,82,123` (EXPLANATION); `ROADMAP.md:36` (HISTORICAL — v0.2 section); `docs/governance/is-state-baseline-pre-v020.md:57` (HISTORICAL-RELEASE EVIDENCE); `evaluations/skill-routing/fixtures/routing/task.md:22` (test fixture).
Contradiction: **none found.** All say nine, all use the identical arrow string. Verified: 9 `SKILL.md` files exist and match the named nine.
Fan-out risk: **HIGH by count, LOW by volatility** — 13 copies of a string that has been stable for many releases; the cost is only realized if the stage set or skill count ever changes.

### 2. The four tiers
**Surfaces: 4 manually maintained current.**
Most authoritative: `docs/adr/0029-four-tier-artifact-separation.md:27` ("**Every artifact belongs to exactly one of four tiers:**") — OPERATIVE AUTHORITY.
Others: `AGENTS.md:60-76` (full re-tabulated copy — OPERATIVE AUTHORITY for agents); `docs/README.md:43` (one-line CURRENT REFERENCE-PROJECTION); `ROADMAP.md:371` (HISTORICAL-RELEASE EVIDENCE, v0.19 outcome statement); `tests/test-doctor-tier-boundary.sh:4` (code comment, mechanical enforcement).
Contradiction: **partial-coverage drift, not a conflict.** `AGENTS.md:69` names the prose tier as "repo-root `docs/` — ADRs, ops, releases, research" while the same file's Repo Map at `AGENTS.md:48-53` correctly adds `architecture/`, `governance/`, `alpha/`. Neither mentions `evaluations/`, which exists at repo root and is classified only in `plugins/spark/docs/reference/stability.md` ("Evaluation formats… **Internal**").
Fan-out risk: **MEDIUM** — the AGENTS.md table is a hand-maintained duplicate of the ADR's normative table.

### 3. Delivery model / ordering invariant / one-writer-per-worktree (ADR-0027)
**Surfaces: 4 manually maintained current.**
Most authoritative: `docs/adr/0027-delivery-model.md:34-80` (Decision; one-writer at :65, integration-branch exception at :70) — OPERATIVE AUTHORITY.
Others: `AGENTS.md:106-124` (full restatement — OPERATIVE AUTHORITY for agents); `plugins/spark/docs/explanation/sdlc-doctrine.md` delivery section (EXPLANATION, referenced by AGENTS.md:110); `docs/README.md:41` (PROJECTION); `plugins/spark/preferences/templates/standards/conventions.md:26-38` (seeded into every downstream repo — CURRENT REFERENCE-PROJECTION); `ROADMAP.md:261-262, 421-436` (HISTORICAL-RELEASE EVIDENCE).
**Observed contradiction (soft but real):**
- `AGENTS.md:115-117`: "Record true prerequisites with GitHub's native `blocked-by` relationship; codify's preflight treats that native graph as the executable dependency authority. **Prose may explain the dependency but does not create one.**"
- `plugins/spark/preferences/templates/standards/conventions.md:38`: "Declare the dependency on the issue (`Blocked by #A`)." — the issue-**body-prose** form, which `docs/releases/v0.20.md:44` explicitly demotes: "Native GitHub `blocked-by` is the **one** executable prerequisite authority; **disagreeing body prose is reported as drift, never enforced**."
The template is ambiguous between the native relationship and the body-prose form; a downstream repo seeded from it can record a dependency Spark will not honor. Classify template line as **FALSE-OR-STALE (candidate)**.
Fan-out risk: **HIGH** — the invariant is restated in a shipped *template* that is copied into other repositories, so drift propagates outward.

### 4. Attribution roles (author / worker / governor)
**Surfaces: 5 manually maintained current + 1 code authority.**
Most authoritative: `plugins/spark/scripts/hooks/commit-msg:51-147` (the mechanism; `spark.governorBin` local pin at :69) — OPERATIVE AUTHORITY.
Others: `AGENTS.md:238-265` (three-role list, verbatim-parallel); `plugins/spark/docs/explanation/enforcement-model.md:159-194` (near-verbatim restatement of the same three bullets, including the identical "#711 is out of scope" paragraph) — EXPLANATION; `plugins/spark/docs/reference/hooks.md:116-148` (CURRENT REFERENCE-PROJECTION); `plugins/spark/skills/ship/SKILL.md:46,82` (OPERATIVE, PR-body projection); `CONTRIBUTING.md:185-186` (PROJECTION); the literal `jwogrady` rule additionally in `plugins/spark/skills/knowledge/SKILL.md:74`, `plugins/spark/agents/knowledge/00-intake.md:31`, and 6 files under `plugins/spark-docs/`.
Contradiction: **none.** `AGENTS.md:255-265` and `enforcement-model.md:180-194` are paraphrases of each other with matching semantics.
Fan-out risk: **HIGH** — the "literal string `jwogrady`, never credit an AI" rule alone has **10** hand-maintained copies across two plugins.

### 5. Commit rules (types, 72-char subject)
**Surfaces: 8 manually maintained current + 1 code authority + 1 machine default.**
Most authoritative: `plugins/spark/scripts/hooks/commit-msg:36-37` (regex `^(feat|fix|docs|chore|refactor|test)…`) — OPERATIVE AUTHORITY; and `plugins/spark/preferences/defaults.json` (`"commit.subject-max": "72"`) — machine authority.
Others: `AGENTS.md:211-217`; `CONTRIBUTING.md:81`; `plugins/spark/docs/reference/hooks.md:117-118`; `plugins/spark/docs/explanation/release-ownership.md:48` ("exactly six conventional types"); `plugins/spark/docs/reference/engineering-preferences.md:123`; `plugins/spark/docs/how-to/ship.md:17`; `plugins/spark/skills/ship/SKILL.md:29,84`; `plugins/spark/skills/agents-md/references/contract-and-sections.md:15`; `plugins/spark/preferences/templates/standards/conventions.md:40-43` (templated to `{{commit.subject-max}}` — the only surface that does **not** hard-code 72).
Contradiction: **none.** All six types and the 72 bound agree with the hook regex, verified by reading it.
Fan-out risk: **HIGH** — `72` is hard-coded literally in **8** prose surfaces while `defaults.json` treats it as a preference key; changing the preference would silently falsify all eight.

### 6. Release process (Release Please, milestone declares version, Release-As, release gate)
**Surfaces: 7 manually maintained current.**
Most authoritative: `plugins/spark/docs/explanation/release-ownership.md:19,155` — the shipped doc that owns the `ship` ↔ Release Please boundary — OPERATIVE AUTHORITY (shipped).
Others: `AGENTS.md:203-205`; `plugins/spark/docs/reference/engineering-preferences.md:47`; `plugins/spark/skills/ship/SKILL.md:66` + `plugins/spark/skills/ship/references/release-please.md:24,49`; `plugins/spark/docs/reference/metadata-governance.md:150,221-227` (the `release-gate` role); `docs/ops/release-gate-role.md:8,13-24` (dev-side operative procedure); `ROADMAP.md:277,535-537`; `docs/adr/0009-spark-release-mechanism.md:4,99` (SUPERSEDED-in-part: its own status line says the version-ladder pointer "is superseded"); `plugins/spark/docs/reference/release-docs-checklist.md`; `docs/ops/release-merge-convention.md` and `docs/ops/release-token-governance.md` (dev-side, linked from the shipped explanation by full GitHub URL).
Contradiction: **none directly conflicting**, but note the split authority: the `release-gate` **role** is normative in a *shipped* reference (`metadata-governance.md:221`) while the *procedure* for assigning it lives dev-side (`docs/ops/release-gate-role.md`). `release-ownership.md:19` also carries a Spark-specific carve-out ("this repo itself runs Release Please's default bump semantics") that the other surfaces do not repeat.
Fan-out risk: **HIGH** — 7+ surfaces, split across shipped/dev tiers, with one ADR whose status line already declares part of it superseded.

### 7. Merge authority / bounded / routine merge / #677
**Surfaces: 4 manually maintained current — and they are near-disjoint, not duplicative.**
Most authoritative for merge authority: `plugins/spark/docs/explanation/sdlc-doctrine.md:125-151` ("A Crossroad is a missing authority, not a feeling"; "a **routine merge under standing authority**, with exact-head protection") — OPERATIVE AUTHORITY (shipped), and `spark crossroad` encodes it mechanically.
Others: `docs/ops/openai-reviewer-lane.md:8,60` ("It is advisory: `PASS`… **not merge authority**") — a *different* claim about the reviewer; `docs/ops/existing-implementation.md:47` ("An open PR is **evidence to inspect, not merge authority**") — a third, distinct claim; `docs/ops/bounded-execution.md:6` (bounded convergence, the v0.21/v0.22 failure behind #558) — EXPLANATION/HISTORICAL.
"#677 standing orchestration": appears as a *test fixture string* (`tests/test-crossroad.sh:59`), a governing-grant citation (`docs/ops/execution-configuration-surface.md:32`), a milestone-direction citation (`ROADMAP.md:653`), a dispositioning citation (`docs/releases/v0.23-usage-evidence.md:379`), and an unrelated benchmark-vocab issue number (`tests/test-benchmark-vocab.sh:50`). There is **no single doc that defines what "#677 standing orchestration" is** — every use is a citation.
Contradiction: none between surfaces; the risk is the opposite — **no canonical definition**. Classify "#677 standing orchestration" as **UNKNOWN** (definition not present in the tree at this SHA).
Fan-out risk: **MEDIUM**, with a definitional gap rather than a duplication problem.

### 8. OpenAI reviewer lane + verdict vocabulary
**Surfaces: 3 manually maintained current, all in lockstep.**
Most authoritative: `.github/scripts/openai-review/lib.sh:18-25` — "The verdict vocabulary is closed. Anything outside it is NOT ASSESSED", with the literal closed case list — OPERATIVE AUTHORITY (code).
Others: `.github/scripts/openai-review/reviewer-instructions.txt:8-16` (the prompt — OPERATIVE, sent to the model); `docs/ops/openai-reviewer-lane.md:57-73` (CURRENT REFERENCE-PROJECTION, dev-only).
Adjacent non-duplicating uses: `ROADMAP.md:513,543`; `README.md:92-95` (`spark crossroad`'s own `DECISION REQUIRED`); `docs/ops/repository-boundary.md:42-46` — this one **explicitly declines to duplicate**: "rather than borrowing `DECISION REQUIRED` or `NOT ASSESSED`". `docs/ops/telemetry-baseline.md:42,66-86` uses `NOT ASSESSED` as a measurement value, a different sense.
Contradiction: **none.** All four verdict strings match exactly across code, prompt and doc.
Fan-out risk: **LOW** — vocabulary is closed in code and only projected once.

### 9. CLI verb list
**Surfaces: 4 manually maintained — mechanically checked, and they agree.**
Most authoritative: `plugins/spark/preferences/cli-stability.tsv` — self-declares "This file is the MACHINE-READABLE AUTHORITY. reference/stability.md renders the same facts for a reader and is checked against this data; prose is never the classification."
Verified counts: dispatcher `VERBS` table (`plugins/spark/bin/spark:253-284`) = **31 verbs**; `cli-stability.tsv` = **31 rows**; `plugins/spark/docs/reference/cli.md` `## \`spark <verb>\`` headings = **31**; all three name the identical set. `spark doctor` (`bin/spark:1167-1224`) compares VERBS ↔ tsv ↔ the *Stable* row of `stability.md`.
`README.md` mentions only a curated subset (`orient/triage/reconcile/course/next` at :80-84, `doctor` at :192) and points at `cli.md:242` for the full list — correctly a projection, not a duplicate list.
**Observed contradiction — see C1.** `stability.md`'s *Experimental* row is stale and is **not** covered by doctor's check.
Fan-out risk: **MEDIUM** — three of four surfaces are mechanically locked; the one unlocked row has already drifted.

### 10. Benchmark / measurement vocabulary
**Surfaces: 2 manually maintained current, plus a dedicated parity guard.**
Most authoritative: `tests/bench.sh:8-35` — the "WHAT THE COUNTS ACTUALLY ARE" header defining `shimmed` / `parsers` / `gh` — OPERATIVE AUTHORITY.
Other: `AGENTS.md:145-149` (the only prose duplicate), enforced in lockstep by `tests/test-benchmark-vocab.sh` (issue #666), which forbids "external process"/"remote request" in AGENTS.md and requires the bounded framing tied to the count it bounds.
`docs/ops/telemetry-baseline.md`, `docs/ops/context-efficiency.md`, `docs/ops/evaluation.md`: **do not** restate the shimmed/parser/gh vocabulary — grep for `shimmed|lower bound|not a count of HTTP` returns hits only in `AGENTS.md`. They are separate vocabularies (run telemetry, evidence reuse, evaluation formats).
Contradiction: **none.** This is the healthiest concept measured — two surfaces, mechanically tied.
Fan-out risk: **LOW.**

### 11. Naming (Status26)
**Surfaces: 1 manually maintained current.**
Most authoritative and sole: `AGENTS.md:267-284` — OPERATIVE AUTHORITY, enforced by `tests/test-naming.sh` (which at :47 asserts the rule is *in AGENTS.md*) and by `tests/lib.sh:143-144` (no plugin may hard-code `cosmos|status26`).
Other appearances are all HISTORICAL-RELEASE EVIDENCE or incidental: `docs/releases/v0.18.md:25`, `ROADMAP.md:359`, `docs/adr/0028:20,63`, `docs/problem-statement.md:98`, `docs/releases/v0.17-plan.md:81`.
Soft observation: `AGENTS.md:270-271` says "In LICENSE files… the legal form is `Status26, Inc.`", while this repo's `LICENSE:3` reads `Copyright (c) 2026 jwogrady`. The AGENTS.md sentence is a *spelling* rule conditional on using the org name, not a claim about this LICENSE — so **not** a contradiction, but worth noting the rule has no instance in-tree.
Fan-out risk: **LOW** — single authority + two mechanical guards. This is the model the other concepts are not following.

### 12. Which Spark version is "released" / "installed governor"
**Surfaces: 4 manually maintained current — coherent.**
Most authoritative: `.release-please-manifest.json` (`".": "0.22.0"`) + `plugins/spark/.claude-plugin/plugin.json:4` (`"version": "0.22.0"`) — OPERATIVE AUTHORITY (machine).
Others: `ROADMAP.md:7` "`v0.22.0` is the published baseline" — CURRENT REFERENCE-PROJECTION, agrees; `ROADMAP.md:491` "Shipped (`v0.22.0`) — published 2026-08-30 at `f364d42`"; `ROADMAP.md:562-564` and `docs/releases/v0.23.md:3-7` both state v0.23 is **"In progress — not released"** with gate #480 open — consistent.
`plugins/spark/docs/reference/stability.md:57` describes five verbs as "introduced in v0.23" while 0.23 is unreleased — accurate as a forward statement about the tree, not a released-state claim.
`tests/test-commit-msg.sh:60` comments that the fixture models "an installed v0.23 governor developing a v0.24 checkout… the exact Spark self-development shape" — at this SHA the actual shape is an installed **v0.22** governor developing a **v0.23** checkout. This is illustrative test prose, not a current-truth doc. Classify **FALSE-OR-STALE (low severity, test comment only)**.
Contradiction: **none in current-truth docs.** The v0.22-released / v0.23-in-progress story holds across manifest, ROADMAP and the release record.
Fan-out risk: **LOW–MEDIUM** — version claims are concentrated in ROADMAP + the release records, which explicitly own chronology (`docs/releases/README.md:9-24`).

## C) FALSE-OR-STALE candidates (each verified by grep/ls)

1. **`plugins/spark/docs/reference/stability.md:57`** — Experimental row lists only 5 verbs; `cli-stability.tsv` classifies **7** as experimental.
   Doc: "CLI command names introduced in v0.23 (`telemetry`, `budget`, `evidence`, `route`, `ci`) | **Experimental**".
   TSV also has `repo experimental Introduced in v0.23; contract still under validation` and `crossroad experimental Introduced in v0.23; stop-classification contract under validation`.
   The page claims at :50-52 it "is checked against it", but `bin/spark:1219` greps only `'CLI command \*\*names\*\*'` — the Stable row. The Experimental row is unchecked and has drifted. **Confirmed stale.**
2. **`plugins/spark/docs/README.md:66-77`** — the shipped Reference index omits `reference/compatibility.md` (75 lines) and `reference/stability.md` (100 lines), both of which exist and are linked from root `README.md:311-312`. Two shipped reference pages are unreachable from the shipped docs index. **Confirmed incomplete.**
3. **`docs/README.md:15-45`** — the ADR index lists 0001–0029 and 0031 but **omits ADR-0030** (`docs/adr/0030-governance-model-representation.md`, `Status: Accepted`). `grep -c 0030 docs/README.md` = 0. **Confirmed incomplete.**
4. **`plugins/spark/docs/reference/skills.md:115`**, **`plugins/spark/skills/ideate/SKILL.md:22`**, **`plugins/spark/docs/how-to/ideate.md:9`** — all three assert a **Claude Code native `grill-me` skill**: "Invoke the **`grill-me`** skill (Claude-native)". `grep -rn grill-me` finds it in *only* these three files; there is no such skill in the tree, and it is absent from this session's available-skills roster. If it is not a current Claude Code built-in, `ideate`'s step 3 instructs an agent to invoke a nonexistent skill. **LIKELY-STALE — marked UNKNOWN** because the built-in roster cannot be authoritatively enumerated from inside the repo.
5. **`AGENTS.md:69`** — tier table names the prose tier as "ADRs, ops, releases, research", omitting `architecture/`, `governance/`, `alpha/`, which the same file's Repo Map (`AGENTS.md:48-53`) does list and which all exist on disk. **Confirmed incomplete (internal to one file).**
6. **`AGENTS.md:31-58`** — the Repo Map omits `plugins/spark/lib/` even though `AGENTS.md:157-164` describes it as a core runtime location, and omits repo-root `evaluations/` (5 entries: `evidence-index.tsv`, `lib`, `orchestration`, `provenance-promotion`, `skill-routing`). **Confirmed incomplete.**
7. **`plugins/spark/preferences/templates/standards/conventions.md:38`** — "Declare the dependency on the issue (`Blocked by #A`)" conflicts with `AGENTS.md:115-117` ("Prose may explain the dependency but does not create one") and with `docs/releases/v0.20.md:44` ("disagreeing body prose is reported as drift, never enforced"). Seeded into downstream repos. **Confirmed contradiction.**
8. **`plugins/spark/docs/README.md:44-56`** — no how-to entry for `onboard`; `ls plugins/spark/docs/how-to/` confirms no `onboard.md`, yet `onboard` is one of the nine skills and `reference/skills.md` documents it. Every other skill has a how-to. **Confirmed gap** (a gap, not a false statement).
9. **`tests/test-commit-msg.sh:60`** — "the exact Spark self-development shape: an installed v0.23 governor developing a v0.24 checkout". At this SHA the manifest is `0.22.0` and v0.23 is unreleased. **Confirmed stale comment**, low severity (test prose only).

Negative results worth recording (checked, **no** defect found):
- All relative `.md` links in `AGENTS.md`, `README.md`, `ROADMAP.md`, `docs/README.md`, `docs/ops/**` and `plugins/spark/docs/**` resolve on disk — **zero broken links**.
- Every `/spark:<skill>` mention across current-truth docs resolves to one of the 9 shipped skills; every `` `spark <verb>` `` mention resolves to one of the 31 dispatcher verbs. **No phantom verbs or skills.**
- `SKILL_MD_MAX_LINES=100` / `SKILL_DESC_MAX_CHARS=1024` (`bin/spark:664-665`) match `AGENTS.md:182,184`; no SKILL.md exceeds 100 lines (max observed 100).
- The `docs/ops/release-process.md` reference at `plugins/spark/skills/knowledge/references/glossary.md:79` points at a nonexistent file, **but** it sits inside a fictional worked example (`[[acmeos]]`, "ship-it Friday"). Not a false claim — excluded.

## D) Historical evidence on the current reading path

| Historical/evidence doc | Linking current-truth surface |
|---|---|
| `docs/governance/self-conformance-audit-v020.md` (v0.20-era audit) | `ROADMAP.md:417`; `docs/README.md:53` |
| `docs/governance/is-state-baseline-pre-v020.md` (explicitly "pre-dogfood", "immediately before the v0.20 changes") | `ROADMAP.md:419`; `docs/README.md:54` |
| `docs/research/v0.12-orchestration-recommendation.md` | `ROADMAP.md:179` ("the #198 decision gate") |
| `docs/releases/v0.17.md`, `v0.17-plan.md`, `v0.18.md`, `v0.19.md`, `v0.20.md`, `v0.21.md`, `v0.22.md`, `v0.23-usage-evidence.md` | `ROADMAP.md:17, 295, 301, 339, 406, 453, 496, 578, 621` |
| `docs/ops/release-token-governance.md`, `docs/ops/release-merge-convention.md` (dev-only ops records) | **shipped** `plugins/spark/docs/explanation/release-ownership.md:133,147` (full GitHub URLs, labelled developer-only) |
| `docs/ops/reconciliation-runbook.md` | **shipped** `plugins/spark/docs/reference/cli.md:428` |
| `docs/governance/capability-evaluation.md` (the entry test whose gate machinery ADR-0025 records as retired 2026-08-11) | **shipped** `plugins/spark/docs/reference/release-docs-checklist.md:72` |
| `docs/alpha/alpha-program.md` | root `README.md:298`; `ROADMAP.md:10` |
| `docs/alpha/` (as a directory) | **shipped** `plugins/spark/docs/reference/stability.md:9` |
| `docs/ops/v0.21-dogfood-evaluation.md` | **`.github/scripts/ledger-truth-check.sh:54`** — live CI machinery defaults to reading this v0.21-era evaluation as its ledger |
| `docs/ops/evaluation.md` (its own header at :9-14 says "Nothing enforces this contract on ordinary changes anymore") | `evaluations/orchestration/README.md:18`, `evaluations/*/run.sh`, `evaluations/lib/eval.sh:9` |
| `docs/adr/0004/0005/0006/0007` (vocabulary superseded by ADR-0015) | `docs/README.md:18-21` — listed inline in the ADR index with parenthetical supersession notes, i.e. on the normal reading path |

Orphan in the other direction: **`docs/ops/openai-reviewer-lane.md` has no inbound link from any Markdown surface** — not `docs/README.md`, not `ROADMAP.md`, not `CONTRIBUTING.md`. Its only referents are `.github/workflows/openai-review.yml` and `tests/test-openai-review.sh`. Same pattern for most of `docs/ops/`: 11 of the 18 ops docs are reachable only from a `tests/test-*.sh` existence assertion (`bounded-execution`, `ci-handoff`, `claude-coding-lane`, `context-efficiency`, `existing-implementation`, `read-only-assessment`, `repository-boundary`, `telemetry-baseline`), which pins the file path but puts it on no reading path.

## Summary of fan-out ranking (measurement only)

| Rank | Concept | Manual current surfaces | Risk |
|---|---|---:|---|
| 1 | Lifecycle stages + nine skills (1) | 13 | HIGH count / LOW volatility |
| 2 | Attribution, `jwogrady` rule (4) | 10 | HIGH |
| 3 | Commit rules, `72` hard-coded (5) | 8 | HIGH |
| 4 | Release process (6) | 7 | HIGH |
| 5 | Delivery model / ordering invariant (3) | 4 (+1 exported template) | HIGH — propagates downstream |
| 6 | Four tiers (2) | 4 | MEDIUM |
| 7 | CLI verb list (9) | 4 (3 mechanically locked) | MEDIUM |
| 8 | Merge authority / #677 (7) | 4 (near-disjoint; no canonical #677 definition) | MEDIUM |
| 9 | Version-released claims (12) | 4 | LOW–MEDIUM |
| 10 | OpenAI verdict vocabulary (8) | 3 (closed in code) | LOW |
| 11 | Benchmark vocabulary (10) | 2 (guarded by a parity test) | LOW |
| 12 | Naming / Status26 (11) | 1 (two mechanical guards) | LOW |

Concepts 10, 11 and 12 are the three that already carry a single authority plus a mechanical lockstep guard; concepts 1, 4 and 5 carry the most hand-maintained copies with no parity check between them.
