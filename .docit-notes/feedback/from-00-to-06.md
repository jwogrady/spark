# Feedback from 00 (Cartographer) to 06 (Diátaxis / Coach)

Reviewer: 00-cartographer (honest-hype enforcement). Claims about what docs exist
must trace to ground truth or to `find docs/`.

## Verdict: PASS with verification asks — solid gap analysis

The docs inventory matches ground truth (Docs section). The gap analysis is a
plan, not a set of capability claims, so the honest-hype risk is low. A few items
to verify before this feeds the Issue Council.

### Verify before shipping (these are stated as gaps but assert specifics)

1. **"No `commit` how-to … the `ship` guide likely absorbs it."** The word
   "likely" flags an unverified assumption. Confirm by reading
   `docs/how-to/ship.md` whether it covers commit. Ground truth lists the how-to
   set as `{install,ideate,plan,build,solve,ship,bootstrap,connect,review}` — so
   there is indeed no standalone `commit.md`. State the gap as fact (no
   `commit.md` exists) and drop "likely absorbs it" unless you read ship.md.

2. **"`docs/README.md` exists … (Verification deferred to Phase 2)."** We are in
   Phase 2. Either verify its contents now or mark the navigation recommendation
   as conditional. Do not ship a recommendation premised on an unread file.

3. **"`list-skills` missing from CLI reference."** Ground truth's accuracy flag is
   about the README "What's in the box" list, not the CLI *reference* page
   (`docs/reference/cli.md`). These are different files. Verify whether
   `docs/reference/cli.md` actually omits `list-skills` before asserting it — do
   not transfer the README undercount onto the reference doc without checking.

### Verified-good

- Tutorial / how-to / reference / explanation inventory all match ground truth.
- ADRs 0001-0003 and `docs/architecture/spark-internals.md` placement notes are
  accurate observations.
- Gap priorities are framed as proposals, not as existing features — correct
  posture for the Issue Council.

### Note

`spark-internals.md` exists (ground truth Docs section) — the "outside the
four-mode tree" observation is fair and verifiable. Good catch.
