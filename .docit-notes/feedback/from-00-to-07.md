# Feedback from 00 (Cartographer) to 07 (Contributing / Contributor)

Reviewer: 00-cartographer (honest-hype enforcement). Procedural claims must trace
to ground truth, `bin/spark`, or `CLAUDE.md`.

## Verdict: PASS with one correction

A faithful, well-grounded contributor guide. One citation is wrong and a couple
of line-number references are too precise to ship.

### Must fix

1. **"6 codify agents under `agents/codify/`" — verify the rename.** Ground truth
   says codify is `00-intake`..`05-editor` (6 agents). `ls agents/codify/`
   confirms exactly: `00-intake, 01-architect, 02-product, 03-ops, 04-librarian,
   05-editor`. The "6 codify agents" claim is CORRECT — keep it. (No fix; flagged
   only because the count is load-bearing.)

2. **Line-number citations are brittle.** The Claims table cites `bin/spark` lines
   140-165, 34-138, 37-45, 185-200, and `guard-bash.sh` 47-58. Ground truth cites
   functions by name (`cmd_new_skill`, `cmd_doctor`, `check_json`,
   `cmd_install_git_hooks`), not line ranges, because line numbers drift with every
   edit. The guard force-push logic is actually at lines 49-51 and trunk at 56-57
   in the current file, not a clean "47-58 block." Replace line ranges with the
   function names from ground truth so the citations don't rot.

### Verified-good

- `spark new-skill`, `spark doctor` (validates manifests/hooks/skill+agent
  frontmatter, exits non-zero on error, graceful jq/python3 degradation),
  `install-git-hooks` (copies commit-msg + pre-commit) — all trace to ground truth
  CLI section. Correct.
- commit-msg / pre-commit / PreToolUse guard behavior — all correct.
- "16 skills, each with valid frontmatter" — correct.
- "SKILL.md ≤ 100 lines or split" cited to `write-a-skill/SKILL.md` — acceptable
  (this is a CLAUDE.md / skill-authoring convention, not invented).
- Self-contained skills, feature-branch discipline, one-PR-per-concern — all trace
  to CLAUDE.md.

No overclaims. Just swap the line numbers for function names.
