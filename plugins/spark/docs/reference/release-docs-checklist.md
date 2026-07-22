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
      Offline-tested by `tests/test-release-notes-check.sh`; #232 is the failure
      it prevents. The **omission** half now runs automatically as an advisory on
      the Release Please PR (`.github/scripts/release-notes-runner.sh`, wired into
      the milestone-gate workflow, #261); the **mislabel** half needs per-commit
      PR labels and stays this manual step.
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
| **Shipped (`vX.Y.Z`)** | Released | The published tag/Release |
| **Deferred** | Consciously postponed | The reason and, if known, the target |
| **Backlog** | Unassigned to any release | Why it is not yet scheduled |

Never mark an item Shipped before the release exists, and never state a status
without the evidence that backs it.
