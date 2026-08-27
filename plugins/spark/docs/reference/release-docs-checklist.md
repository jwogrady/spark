# Release-docs checklist

A lightweight, repeatable review that keeps the public record coherent at
release time. Run it **before a human approves the Release Please PR** (or, in a
manual-release repo, before `ship` cuts the tag). It pairs with the changelog
policy in the [`ship` skill](../../skills/ship/SKILL.md) and the milestone-gate
readiness signal; it does not replace either.

Release Please owns version calculation, the released changelog sections, tags,
and GitHub Releases (ADR-0006, ADR-0009). This checklist verifies the *prose
record* around that machinery — it never recreates release management.

## Before approval

- [ ] **Changelog input is truthful.** Every user-facing change in the release
      range is expressed in a conventional commit subject/body (Release Please
      repos) or under `## [Unreleased]` (manual repos). No entry describes work
      that has not merged; none is a process-journal note.
- [ ] **Changelog input is complete** — no user-facing change is silently
      dropped. Of Spark's six committed types, `feat`/`fix`/`docs` are visible in
      the generated notes; `chore`/`refactor`/`test` are hidden, so a feature
      merged under one of them vanishes. `.github/scripts/release-notes-check.sh`
      mechanizes this: feed it the range's commits (type, subject, PR labels) and
      the generated notes, and it flags any visible commit missing from the notes
      and any commit merged under a hidden type whose PR is labeled `feature`.
      Offline-tested by `tests/test-release-notes-check.sh`. The failure it
      prevents: a user-facing change merged under a hidden type never
      reaching the notes. Its exit status carries the release consequence —
      `1` blocking, `3` duplicate-only (non-blocking, disclosed in the status
      description), `0` clean — so the GitHub status never shows a blocking
      omission and an accepted duplicate as the same red. Both halves now run automatically as an advisory on the
      Release Please PR (`.github/scripts/release-notes-runner.sh`, wired into
      the milestone-gate workflow): the **omission** half per component against
      its own tag range and notes section, and the **mislabel** half using
      per-commit PR labels fetched from the API — with any commit whose
      labels could not be retrieved reported as unassessed rather than passed.
      This checkbox is now a review of that advisory's output, not a manual
      re-derivation.
- [ ] **README and reference docs describe only merged behavior.** Nothing
      planned is presented as shipped.
- [ ] **Companion docs** (spark-audit, spark-connect, spark-docs) match their
      shipped behavior if the release touches them.
- [ ] **Roadmap status is current.** Every roadmap item the release affects
      links to its issue/PR and uses a status from the vocabulary below. Items
      are *not* marked Shipped yet — that waits until the release exists.
- [ ] **Manifests and release config agree** — plugin `plugin.json` versions,
      `.release-please-manifest.json`, and `release-please-config.json` are
      consistent with the intended release scope.
- [ ] **Scope is bounded.** Every entry maps to merged evidence and belongs in
      this release; anything that does not is split out.
- [ ] **Blockers vs follow-ups are named.** Release blockers are called out;
      safe post-release follow-ups are recorded as issues, not held.

## Platform compatibility — the manual release census

These are the **checks a human performs before approving each release**,
because they are judgment calls against surfaces that live outside this
repository. Do not expect a script to cover them; none does — the scripted
half that once accompanied this census (the Platform Compatibility Review
gate, originally mandated by the now-archived constitution's Article VII) was
retired by the governance deletion test, so this manual census is the
whole of the practice.

- [ ] **Deletion-Test census against the *current* platform surfaces.** For
      each Spark club (skill, hook, CLI verb), ask: does a native Claude Code
      or GitHub tool *now* duplicate it? If yes, Spark retires its club — the
      host evolving is the signal to update Spark, not a break. This cannot be
      automated deterministically: the oracle is Anthropic's and GitHub's
      currently shipping feature set, which changes without leaving any signal
      in this repo, and "duplicates" is a product judgment (Mission and User
      Value can outvote a Deletion-Test failure — see
      `docs/governance/capability-evaluation.md` in the Spark repo).
- [ ] **External host guidance still exists.** Every upstream document, spec,
      or platform behavior Spark's docs and skills reference is still published
      and still says what Spark claims it says. Again human judgment: link
      liveness could be scripted, but "the guidance still supports the claim"
      cannot.

One clause is **not** on this manual list because it is already mechanical:
*"every enforced mechanism still fires"* is covered by the milestone gate,
which requires the `doctor` and `tests` CI checks green on the Release
Please PR head before reporting ready. It is not re-checked by hand here.
Checking that experiment-gated ADR statuses still match their experiments'
verdicts is part of the same manual census — the scripted advisory that once
prompted it was retired by the governance deletion test.

Record the outcome of the manual checks in the release approval (a PR
comment is enough): what was censused, what was retired or kept, and why.

## After Release Please releases

- [ ] **Verify the release incorporated the intended content** — version,
      changelog section, tag, and GitHub Release match what was approved.
- [ ] **Move roadmap items to Shipped** only now that the release exists,
      stamping the version (e.g. `Shipped (v0.10.0)`).
- [ ] **Historical changelog sections stay immutable** except a factual
      correction with clear evidence.

## Roadmap status vocabulary

One status per roadmap item, backed by evidence:

| Status | Meaning | Required evidence |
| --- | --- | --- |
| **Planned** | Intended, not started | A linked issue |
| **In progress** | Being implemented now | A linked issue/PR |
| **Merged (awaiting release)** | Work merged to the trunk; the release is not yet cut | The merged PR(s) / closed issues and the pending release |
| **Shipped (`vX.Y.Z`)** | Released | The published tag/Release |
| **Complete (no release)** | Deliverables merged; the milestone intentionally cut no version | The merged artifacts and the decision record |
| **Deferred** | Consciously postponed | The reason and, if known, the target |
| **Backlog** | Unassigned to any release | Why it is not yet scheduled |

Never mark an item Shipped before the release exists, and never state a status
without the evidence that backs it.
