# Feedback from 00 (Cartographer) to 02 (Quickstart / Adopter)

Reviewer: 00-cartographer (honest-hype enforcement). Claims must trace to
`00-ground-truth.md` or to a command/file that proves them.

## Verdict: PASS with two corrections

### Must fix

1. **`spark doctor` does NOT print all skills as "✓ … 16 skills"-style summary,
   and there is no "19 agents verified" line.** Verified by reading `bin/spark`:
   doctor emits a green `✓ <name>` per skill and per agent file, then a final
   `Healthy — 0 errors, N warning(s)` line. It does not print a "16 skills" or
   "19 agents" tally. Reword "You should see all 16 skills listed as ✓ and all
   docit/codify agents verified (13 + 6 = 19 agents)" to: "You should see a green
   ✓ next to each skill and each agent, ending in `Healthy — 0 errors`." The
   16/19 counts are true facts (ground truth) but are not what doctor prints — do
   not put words in the tool's mouth.

### Should verify / soften

2. **"GitHub token for PR creation … `gh auth login`" (gotcha 2) is not in ground
   truth.** It is a reasonable inference (ship opens a PR, which needs `gh`), but
   ground truth does not document a `gh`/token requirement. Either (a) trace it to
   `skills/ship/SKILL.md` if that skill states the `gh` dependency, or (b) soften
   to "PR creation uses the GitHub CLN (`gh`); make sure you're authenticated."
   Do not assert a specific auth command as a Spark requirement unless the ship
   skill says so.

3. **"the lifecycle skills will error" in a non-git directory (gotcha 1) is an
   unverified specific.** Ground truth confirms `install-git-hooks` requires a git
   repo, but does not say every lifecycle skill hard-errors outside one. Soften to
   "Spark's git-level guardrails and several skills assume a git repo" unless you
   can cite the failure.

### Verified-good

- Install commands, `install-git-hooks` copying commit-msg + pre-commit,
  conventional-commit enforcement, force-push/trunk-push block, AI-attribution
  stripping — all trace correctly to ground truth. Claims 4–6 are solid.
