# Spark v1 launch checklist

> Canonical launch record. Created during the v0.14.0 proving release
> (2026-07-23). Evidence-first: every "done" below cites what proves it.

## Version reality (read this first)

The v0.15 milestone and the `cycle/v0.15-hardening` branch were named for a
*planning wave*, not a version number. Release Please computes the version from
the conventional commits since the last tag (`v0.13.0`): 10 `feat` + 12 `fix`,
no breaking changes, no `Release-As` directive ⇒ a **minor bump to `v0.14.0`**.

**The proving release is `v0.14.0`.** There is no `v0.15.0` unless a human
deliberately forces one with a `Release-As: 0.15.0` commit — a decision that has
not been made and is not required.

## Completed engineering work

| Area | Evidence |
| --- | --- |
| v0.15 hardening wave merged | PR #314 rebase-merged to `master`; HEAD `581a5d0`; 20 commits |
| Release-truth controls | milestone-gate + per-component release-notes verification + platform-compat gate, all live-green on PR #287 |
| Evaluation surface hardened | single-snapshot validate/score, metric-range + magnitude + CRLF guards (#304, #306) |
| Capability traceability enforced | issue-form `required: true` + `traceability` CI job (#301) |
| Release-component parity | `check_release_component_parity` in doctor (#291) — a new package can no longer ship unverified notes |
| v1 stability contract | `docs/reference/stability.md` — every surface classified; known limits stated |
| Launch-surface claims aligned | README breaking-changes hedge removed; behavioral-tests scope corrected; `gh`/requirements placement fixed |
| Community health | `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1) added and linked |

Issues auto-closed on merge (per-commit `Closes`): #291, #292, #294, #301,
#304, #305, #306, #312, #313. Closed earlier with recorded verdicts: #206,
#211, #214, #223, #288, #309.

**Open, by intent:** #284 (release-readiness epic — stays open until the
proving release actually ships) and #298 (CEF epic — all children closed;
awaits an explicit close). Neither was closed automatically because the PR body
used the phrase "Closes on merge:", which GitHub's parser does not treat as a
closing keyword — a cosmetic parser miss, not a work gap.

## Completed release work

| Step | Evidence |
| --- | --- |
| Final merge verification | head `0ddd394` matched the reviewed implementation; `MERGEABLE`/`CLEAN`; doctor ✓ tests ✓ gate ✓ traceability ✓ |
| Merge #314 | rebase-merge (preserves conventional commits for Release Please); `master` → `581a5d0` |
| Release Please ran | workflow `completed/success` on `581a5d0`; release PR #287 refreshed |
| Computed version | `v0.14.0` (`.release-please-manifest.json` and `plugins/spark/.claude-plugin/plugin.json` both bumped in #287) |
| Release-gate verification on #287 | doctor ✓ gate ✓ milestone-gate ✓ platform-compat ✓ release-notes ✓ tests ✓ traceability ✓ |

## Evidence collected during production validation

| Check | Result |
| --- | --- |
| `spark doctor` on merged `master` | Healthy — 0 errors, 0 warnings |
| `spark doctor --requirements` | Ready — every capability has what it needs |
| `tests/run.sh` | all 31 suites passed |
| Install-from-scratch e2e (`e2e-marketplace-install.sh`) | 12 passed, 0 skipped — marketplace install, CLI, companion install, skill load all verified |
| Plugin metadata | marketplace.json + all 4 plugin.json valid; core plugin.json bumps to 0.14.0 in #287 |
| Documentation links | no broken relative links |
| Skill inventory | 9 core skills on disk; install e2e now asserts all 9 (was 8 — missing `onboard`, fixed in this checklist's PR) |

## Known limitations (from the stability contract)

- Solo-operator scope; no multi-user governance.
- Skill *judgment* is validated through use, not fully proven by CI.
- Routing evidence is single-grader / limited-sample; labeled, not a benchmark.
- `.spark/` state files are operational artifacts, not a public API.
- Manifest state-file corruption recovery is documented but not behaviorally
  tested (off the release path; a human-invoked plan tool).

## Remaining release actions

1. **Human decision — version:** accept the computed `v0.14.0`, or force
   `v0.15.0` via a `Release-As: 0.15.0` commit before merging #287. (Recommended:
   accept `v0.14.0`; the number should follow the commits, which is Spark's own
   doctrine.)
2. **Human merges release PR #287** — this is the point-of-no-return publish;
   Release Please cuts the tag + GitHub Release. Spark's guard blocks hand-cut
   tags by design; the release-PR merge is the human gate.
3. Post-release: confirm the tag, the GitHub Release, and that
   `/plugin marketplace add jwogrady/spark` installs the new version.
4. Close #298 (done) and, once the release ships, #284.

## Go / No-Go criteria

**Go** requires all of:
- [x] `master` green (doctor, 31 suites, install e2e)
- [x] Release PR #287 exists with the correct computed version and changelog
- [x] All seven gates green on #287
- [x] Plugin metadata bumps with the release
- [x] Docs match reality (stability contract + README reconciled)
- [ ] Human has chosen the version number (0.14.0 vs forced 0.15.0)
- [ ] Human approves the irreversible publish

**No-Go** if any gate on #287 goes red, the install e2e regresses, or a
Critical defect surfaces. None is currently present.

## Rollback procedure

- **Before #287 is merged:** nothing to roll back — no tag or Release exists.
  Close #287 or push a corrective commit to `master`; Release Please regenerates
  the release PR.
- **After #287 is merged (tag + Release cut):**
  1. Mark the GitHub Release as a pre-release or delete it (`gh release delete
     vX.Y.Z`) to unpublish the assets.
  2. Delete the tag only with explicit maintainer instruction (the guard blocks
     hand-cut tags; deletion is equally deliberate).
  3. Ship a follow-up `fix:` so Release Please cuts a corrected patch — prefer
     rolling *forward* to rewriting a published tag.
  4. The marketplace serves whatever the latest tag points to; a corrected
     patch release is the fastest clean recovery.

## Criteria for declaring Spark v1.0.0

Declare v1.0.0 only after the proving release provides the evidence:
- [ ] `v0.14.0` (or the chosen number) is actually cut — tag + Release exist.
- [ ] `/plugin marketplace add jwogrady/spark` installs the released version
      from scratch (the e2e run against the *published* tag, not a local build).
- [ ] The Release Please workflow, changelog, and version bumps behaved exactly
      as designed on a real release (not just the release PR).
- [ ] No release-critical defect appeared during or after the cut.
- [ ] The stability contract still matches reality after the release.

When those hold, cut v1.0.0 with a `Release-As: 1.0.0` commit — no new features,
just the promotion. Until then, Spark is a healthy `v0.14.0`, not yet a proven
`v1.0.0`.
