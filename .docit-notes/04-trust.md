# 04 — Trust (Evaluator)

> Author/credit: `jwogrady`. All claims cite `00-ground-truth.md` or the command that proves them.

---

## Persona

I am the Evaluator: a senior dev or tech lead deciding whether to bet a team on this project. I read for liveness, honest maturity, and risk — not feature lists. My question: **Can my team depend on this, and what do we sign up for when we do?**

---

## Neighbors

- **Upstream I read:** `00-ground-truth.md`, `03-positioning.md`
- **Downstream that reads me:** `05-philosophy.md`, `09-changelog.md`

---

## Draft

### Maturity statement

Spark is pre-1.0, at `v0.2.0`. That is not a caveat — it is the honest contract. The `v0.2` milestone shipped its full scope (plugin packaging, all 16 lifecycle skills, enforcement hooks, Diátaxis docs), with one open item: end-to-end install validation from a published marketplace. The gap is documented in `ROADMAP.md` and the `CHANGELOG.md` `[Unreleased]` block. No breaking-change policy is documented; callers should treat any `v0.x` release as potentially breaking.

**Scope: single-developer tool.** Spark today is designed for one developer carrying the same plugin into every project. The Git backend handles repository concurrency naturally, but the plugin itself has no team coordination layer, no shared-state sync, and no team dashboard. Teams evaluating adoption should know this upfront: this is currently a single-developer productivity tool, not a team platform.

The repo is **actively developed at early stage**: 31 commits in three days (2026-05-28 – 2026-05-30), all work done on feature branches (5 merge commits, pull requests up to #13), conventional commits enforced at the git-hook level. The three-day burst reflects initial build velocity; there is no long-run maintenance cadence to evaluate yet. The log is clean and auditable — that is the honest signal available right now.

### License status

**No enforceable open-source license is in place.** `plugin.json` and the README badge both declare MIT. The actual `LICENSE` file reads: *"License TBD. Copyright belongs to the author."* The manifests overclaim a license the repo has not adopted. Do not incorporate Spark into a project with legal review requirements until a license file is formally adopted and the `LICENSE` file updated. This is the single highest-trust risk in the repo.

### CI / automated testing

**No CI workflows exist.** There is no `.github/workflows/` directory. There are no automated test files in the repository.

For this project type — a collection of Bash scripts and Markdown skill definitions — the enforcement model *is* the intentional quality mechanism, not a gap-filler. The PreToolUse Bash guard and git-level commit-msg and pre-commit hooks enforce workflow integrity mechanically before Claude or the author can deviate (`00-ground-truth.md`, "Genuine differentiators": "Guardrails are mechanical, not advisory"). `spark doctor` validates plugin layout, manifest JSON, and every skill/agent frontmatter on demand; all shell scripts pass `bash -n` syntax check. For a project whose entire risk surface is malformed Markdown frontmatter or mis-wired hooks, this enforcement posture is a deliberate architectural choice consistent with the domain — not a traditional test suite.

The honest gap remains: no automated regression on skill behavior or CLI output. This is a real limitation for contributors.

### Security posture

A `SECURITY.md` is present and accurate. It correctly characterizes the current attack surface as effectively zero: no runtime, no server, no published registry package, no network calls. The stated policy (private disclosure before public issue) is appropriate for the anticipated future surface when runtime tooling lands. The `connect` skill handles secrets via 1Password and includes a `shred-env` subcommand (`scripts/shred-env.sh`) to destroy transient credential files after use.

### Release / tag cadence

One tag exists: `v0.2.0`. The repo is single-author and early-stage; there is no release cadence to evaluate yet. The `CHANGELOG.md` is maintained with Keep-a-Changelog format and the `[Unreleased]` section is populated — a positive signal that the author intends to track changes formally as the project matures.

### Badge row (honest state only)

The following badges reflect **current, verified repo state**:

| Badge | Status | Rationale |
|---|---|---|
| Version | `v0.2.0` | `.claude-plugin/plugin.json` |
| License | **NOT READY** — omit until resolved | `LICENSE` says "TBD" |
| CI | **NOT READY** — omit until CI exists | No `.github/workflows/` |
| Maintained | Yes | 31 commits, PRs to #13, May 2026 |

Only the version and maintained signals should appear in the README until the license is formally adopted and CI is wired. Displaying an MIT badge now is an overclaim.

---

## Claims & citations

| Claim | Evidence |
|---|---|
| Version is `v0.2.0` | `00-ground-truth.md` — `plugin.json` `"version": "0.2.0"` |
| License field says MIT | `00-ground-truth.md` — Accuracy flags: "`plugin.json` declares `"license": "MIT"`" |
| `LICENSE` file says "TBD" | `00-ground-truth.md` — Accuracy flags: "the `LICENSE` file contains only 'License TBD. Copyright belongs to the author.'" — verified by reading `LICENSE` |
| No CI workflows | `bash: ls .github/workflows/ → NO_WORKFLOWS_DIR` |
| No automated test files | `bash: find . -name "*.test.*" -o -name "*.spec.*"` — no output |
| 31 commits, date span 2026-05-28–2026-05-30 | `bash: git log --format=%ad --date=short \| sort \| uniq -c → 13+16+2` |
| 5 merge commits, PRs up to #13 | `bash: git log --oneline \| grep "Merge pull request"` → 5 entries, highest #13 |
| SECURITY.md exists | `bash: ls SECURITY.md → present`; content verified |
| Single git tag `v0.2.0` | `bash: git tag --sort=-creatordate \| head -20 → v0.2.0` |
| CHANGELOG present, Keep-a-Changelog | `bash: head -40 CHANGELOG.md` — format header confirmed |
| v0.2 open item: marketplace install validation | `00-ground-truth.md` ROADMAP section; `ROADMAP.md` unchecked box |
| `spark doctor` validates plugin layout | `00-ground-truth.md` — CLI section |
| All shell scripts pass `bash -n` | `00-ground-truth.md` — "All four shell scripts pass `bash -n` syntax check (verified)" |
| SECURITY.md attack surface characterization | read `SECURITY.md` directly — "no runtime, no server, no API, no package published" |
| Enforcement model is intentional architecture | `00-ground-truth.md` "Genuine differentiators" — "Guardrails are mechanical, not advisory" |

---

## Cross-eval feedback

### from-00-to-04.md (Cartographer)

**Item 1 — "13 merged PRs" overclaim.**
RESOLVED. Changed to "5 merge commits, pull requests up to #13" — verified by `git log --oneline | grep "Merge pull request"` (5 entries, highest #13). The PR number reflects numbering history, not a count of merges in this log.

**Item 2 — Date-span verification.**
RESOLVED. Confirmed `git log --format=%ad --date=short | sort | uniq -c` → 13 commits on 2026-05-28, 16 on 2026-05-29, 2 on 2026-05-30. Three-day span 2026-05-28–2026-05-30 is correct; kept as-is.

### from-03-to-04.md (Skeptic / Positioning)

**Item 1 — Solo-tool dimension missing from maturity statement.**
RESOLVED. Added explicit paragraph to maturity statement: "Scope: single-developer tool" — naming no team coordination layer, no shared-state sync, no team dashboard. Directly answers the senior-dev audience question.

**Item 2 — License risk language undersells blocking severity.**
RESOLVED. Hardened to: "No enforceable open-source license is in place. Do not incorporate Spark into a project with legal review requirements until a license file is formally adopted." Removed advisory "should not proceed" hedge.

**Item 3 — 03-positioning.md reference stale ("not yet present").**
RESOLVED. Updated Neighbors section — `03-positioning.md` now exists and is referenced without the stale caveat.

**Item 4 — Activity signal: burst vs. sustained cadence.**
RESOLVED. Changed "actively maintained" to "actively developed at early stage." Added explicit note: "The three-day burst reflects initial build velocity; there is no long-run maintenance cadence to evaluate yet."

### from-05-to-04.md (Believer / Philosophy)

**Item 1 — Enforcement posture framed as gap-filler rather than intentional architecture.**
RESOLVED. Added explicit sentence in CI/testing section: "For this project type — a collection of Bash scripts and Markdown skill definitions — the enforcement model *is* the intentional quality mechanism, not a gap-filler." Cited `00-ground-truth.md` differentiators. Honest gap language retained alongside.

**Item 2 — License warning: do not soften.**
RESOLVED (no change needed). Confirmed: language was strengthened in response to 03 feedback; the Believer's note was advisory ("no change required — dependency noted"). Warning is now harder, not softer.

**Item 3 — "Actively maintained" weak claim.**
RESOLVED. Same fix as from-03 Item 4 above — reframed to "actively developed at early stage" with explicit cadence caveat.

### from-09-to-04.md (Returning User / Changelog)

**Item 1 — License carryover into v0.3 upgrade path.**
RESOLVED. The trust note already blocks on license as the #1 risk; the carryover is now implicit in the hardened license language. No separate action needed in 04's note — the Editor and 09 own the upgrade-path framing. Noted for coordination: the license risk is a constant, not a v0.3-specific regression.

**Item 2 — CI/testing caution for future over-promises.**
RESOLVED (confirmed alignment). The trust note retains the honest CI gap alongside the intentional-architecture framing. 09's dependency noted; no text change needed beyond what Item 1 from 05 already addressed.
