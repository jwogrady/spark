# Reference — Spark v1 stability contract

> Reference — information-oriented.

This page defines exactly what Spark's semantic version protects, surface by
surface, from v1.0.0 onward. It is the companion to the
[supported-environment matrix](compatibility.md): that page says what Spark
needs from your machine, this one says what you can build on without a change
breaking it.

Spark follows [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.
The core plugin and each companion version independently, so a companion's
major bump does not force the core's.

## What the version numbers mean

- **Patch (`0.0.x`)** — bug fixes and wording changes that keep every surface
  below behaving as its classification promises. No stable surface changes
  shape.
- **Minor (`0.x.0`)** — new commands, flags, skills, or preferences added
  without breaking an existing stable surface. Additive only. A
  compatible-with-migration surface may change *if* the release ships the
  migration and the changelog documents it.
- **Major (`x.0.0`)** — a breaking change to a stable surface: a removed or
  renamed command/flag/skill, a changed exit-code contract, an enforcement rule
  that newly blocks what it used to allow, or a preferences change with no
  automatic migration.

Advisory, internal, and experimental surfaces (defined below) can change in a
**minor** release without a major bump. That is the point of classifying them:
they are explicitly *not* under the compatibility promise, so nobody has to
guess.

## Surface classification

| Surface | Class | What that guarantees |
| --- | --- | --- |
| CLI command **names** (`spark setup`, `doctor`, `preferences`, `brief`, `resume`, `state`, `footprint`, `list-skills`, `new-skill`, `install-git-hooks`, `apply-permissions`, `profiles`, `orient`, `version`) | **Stable** | A name in v1 keeps working through the v1 line; removal or rename is a major bump |
| CLI **flags** documented in the [CLI reference](cli.md) and their **exit-code contract** (`0` success, non-zero failure; `doctor` error/warn levels; documented gate codes) | **Stable** | Documented flags and exit semantics do not change meaning within v1 |
| Undocumented flags, output *phrasing*, and log formatting | **Advisory** | Human-readable text may be reworded in a minor release; do not parse it — use `--json` where offered |
| **Plugin skill names and invocation** (`/spark:<skill>` for the nine core skills; `/spark-audit:*`, `/spark-connect:*`, `/spark-docs:*`) | **Stable** | An invocation string in v1 keeps resolving to the same skill through the v1 line |
| **Hook behavior** — the `PreToolUse` git guard and the `commit-msg` / `pre-commit` git hooks | **Stable** | What they block (force-push, pushes to trunk, non-conventional or AI-attributed commits, direct commits to trunk) is a contract; *widening* what a guard blocks is a breaking change and waits for a major bump |
| **Preferences schema** — the keys in `~/.config/spark/preferences.json` and `<repo>/.spark/preferences.json`, and the three-tier resolution order | **Compatible-with-migration** | A key may be renamed or restructured only in a release that migrates existing files and documents it in the changelog; unmigrated breakage waits for a major bump |
| **Companion-plugin compatibility** — the core and each companion | **Compatible-with-migration** | Companions version independently; a companion states its minimum core version in its own changelog when one is required |
| **`.spark/` runtime file formats** — `state.json` and any future session-state files | **Internal** | Operational artifacts a Spark session reads and rewrites, **not a public API**. The schema is documented in [state.md](state.md) for tooling, but its shape can change in a minor release. Do not build external automation on it |
| **Evaluation formats** — the TSV contracts under `evaluations/`, the evidence index, rubric/rate tables | **Internal** | Repository-governance and research surfaces, not a consumer API; they can change with the governance that owns them |
| **Governance and internal repository files** — ADRs, the product Constitution, `docs/` (dev docs, never shipped), CI scripts under `.github/` | **Internal** | Belong to this repository's own engineering; they carry no external compatibility promise |
| Anything explicitly labeled experimental in its own docs | **Experimental** | May change or be withdrawn in any release; opt in knowingly |

## Known limitations (stated, not hidden)

These are real boundaries of what v1 proves. They are recorded here so the
version number does not imply more than the evidence supports.

- **Spark is optimized for a solo operator, not multi-user workflow
  governance.** It has no team roles, approvals, or shared-state coordination,
  and v1 does not promise any. This is a scope decision, not a gap to be closed
  later.
- **Skill behavioral quality is ultimately validated through use, not fully
  proven by static CI.** The behavioral test suites and `spark doctor` verify
  the CLI, the enforcement doors, and every skill's structure and budgets — but
  a skill's *judgment* on a real task is exercised in use, not asserted by a
  gate. Treat the skills as strong, tested defaults, not formally verified
  agents.
- **Routing evidence may remain model-judged and limited in sample size.** The
  skill-routing evaluation is decision evidence for the description surface, not
  a benchmark; where it is single-grader or single-run, its own scorecard says
  so. It is not a portability or accuracy guarantee.
- **`.spark/` project state files are operational artifacts, not durable public
  APIs.** They record where a session left off so the next one can resume. They
  are not a data-exchange format, and external tools should not depend on their
  shape.

## When this contract and reality disagree

`spark doctor` mechanically enforces several of the promises above (skill
taxonomy parity, the CLI-verb table matching the implementation, the
release-component set matching Release Please's packages, enforcement parity
across both git doors). If this page claims something `doctor` or the code
contradicts, treat it as a bug in this page and open an issue — the same rule
[compatibility.md](compatibility.md) states for itself.
