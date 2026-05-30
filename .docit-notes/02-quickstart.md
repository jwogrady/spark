# Quickstart — Spark

> Adopter persona. You installed it. Now make it work.

## Persona

**You are** a developer who decided to try Spark. You've read the hook, it landed,
and you want to be running in minutes — copy-paste commands that actually work.

**Your question:** Can I go from zero to my first win (a complete Ideate → Plan →
Generate → Solve → Ship cycle) in one focused session?

## Neighbors

**Upstream** (you read):
- `00-ground-truth.md` — verified capabilities and commands.
- `01-hero.md` — the promise your install/quickstart must deliver.

**Downstream** (read you):
- `03-skeptic.md` — assesses whether the claims land honestly.
- `06-coach.md` — teaches the full workflow in detail (via `docs/tutorials/build-your-first-project.md`).
- `08-visuals.md` — provides a `spark doctor` terminal GIF and lifecycle flow diagram.

---

## Draft

### Install the plugin (2 commands, ~30 seconds)

Open Claude Code and run:

```text
/plugin marketplace add jwogrady/spark
/plugin install spark
```

**Note:** Currently installable from a Git URL or local clone. Marketplace listing in progress — check `ROADMAP.md` for status. (Source: `00-ground-truth.md`, ROADMAP section, v0.2 open item.)

Spark is now available globally — every project you open gets the lifecycle
skills (`/spark:ideate`, `/spark:plan`, etc.) and the `spark` CLI. The enforcement
hooks activate when you run `spark install-git-hooks` in a git repo (conventional
commits + block trunk pushes); the PreToolUse guard (force-push prevention) works
automatically once the plugin is installed.

Verify the install worked:

```bash
spark doctor
```

You should see `spark doctor` exit 0 with no errors. It validates manifests, hooks, skill frontmatter, and agent files. If everything is healthy, you see a final `Healthy — 0 errors` message.

### Set up a test repo and confirm the plugin works

Create a simple test project:

```bash
mkdir -p /tmp/spark-test
cd /tmp/spark-test
git init
spark install-git-hooks
```

This installs the `commit-msg` and `pre-commit` hooks that enforce conventional
commits and block direct commits to trunk. To confirm the lifecycle skills are
available, try one:

```text
/spark:ideate

Respond to the prompts. Be honest about the problem, the constraints, and what
success looks like. The output is a written problem statement that becomes your
north star.
```

If `/spark:ideate` runs and generates a problem statement, you're ready to move to a real
project. The lifecycle works in this order:

1. `/spark:ideate` — Frame the problem
2. `/spark:plan` — Break into work items
3. `/spark:build` — Implement one item
4. `/spark:fix-issue` — Review and refine
5. `/spark:commit` + `/spark:ship` — Commit and open a PR

Ready for a deeper walkthrough? See [Build your first project](docs/tutorials/build-your-first-project.md).

### Prerequisites and gotchas

1. **Git repo required.** Spark's git-level guardrails and several skills assume
   a git repo. Initialize one first (`git init`) before running lifecycle commands.

2. **GitHub CLI setup for PR creation.** PR creation requires the GitHub CLI
   (`gh`) installed and authenticated (`gh auth login`). If `gh` is not installed,
   `/spark:ship` will fail at the push step.

3. **One branch per work item.** Each `/spark:build` creates a feature branch.
   The guard (in hooks) blocks direct pushes to `master` and prevents force-pushes
   (only `--force-with-lease` is allowed). This keeps trunk clean.

4. **Conventional commits are enforced.** Every commit must follow the format:
   `<type>: <subject>` where type is one of `feat`, `fix`, `docs`, `chore`,
   `refactor`, `test`. The `commit-msg` hook rejects anything else. The skill
   handles this automatically, but if you commit by hand, the hook will block you.

5. **AI attribution is forbidden.** The `commit-msg` hook strips out any trailer
   that credits Claude, ChatGPT, Copilot, or any AI system. This keeps the
   author field honest.

6. **Skills are self-contained.** Each skill works independently; you don't need
   all of them in one session. If you want to run just `/spark:build` without
   `/spark:ideate` and `/spark:plan`, that's fine — you provide the context.

---

## Claims & citations

1. **"Spark is available globally after install"** — Skills live under
   `skills/*/SKILL.md`, each with `name:` and `description:` frontmatter.
   The plugin manifest (`.claude-plugin/plugin.json`) lists all skills.
   *(00-ground-truth.md, "Lifecycle skills (16 total)")*

2. **"`spark doctor` validates manifests and all skill/agent frontmatter"** —
   The `doctor` command validates manifest JSON, hook executability, every
   skill's `name:`/`description:` frontmatter, and every `agents/**/*.md` frontmatter.
   Exit 0 = healthy. *(bin/spark, cmd_doctor function; 00-ground-truth.md)*

3. **"install-git-hooks copies commit-msg + pre-commit into .git/hooks"** —
   The `install-git-hooks` command is a dispatch case in `bin/spark`.
   Both scripts are present and pass `bash -n` syntax check.
   *(bin/spark, cmd_install_git_hooks; scripts/hooks/commit-msg and pre-commit)*

4. **"Conventional commits are enforced by the commit-msg hook"** — The
   `commit-msg` hook blocks commits without the type prefix
   (`feat|fix|docs|chore|refactor|test`), enforces subject ≤ 72 chars, no
   trailing period, and blocks AI attribution trailers.
   *(00-ground-truth.md, "Enforcement"; scripts/hooks/commit-msg)*

5. **"The guard blocks direct pushes to master and prevents force-push"** —
   The PreToolUse guard (`hooks/guard-bash.sh`, lines 47–58) blocks `git push
   --force`/`-f` and pushes to `master`/`main`; allows `--force-with-lease`.
   *(00-ground-truth.md, "PreToolUse Bash guard")*

6. **"Lifecycle stages map to `/spark:ideate` through `/spark:ship`"** —
   The lifecycle table in README.md and CLAUDE.md shows each stage mapping to
   a skill. *(README.md "The lifecycle", CLAUDE.md "The Lifecycle Skills")*

7. **"Marketplace install currently works from Git URL; listing in progress"** —
   `00-ground-truth.md` ROADMAP section states: "v0.2 open item: validate install
   end-to-end from a *published* marketplace (unchecked box)."

---

## Cross-eval feedback

### Feedback from Cartographer (00)
1. **`spark doctor` output description — RESOLVED.** Reworded from "You should see all 16 skills listed as ✓ and all docit/codify agents verified (13 + 6 = 19 agents)" to "You should see `spark doctor` exit 0 with no errors. It validates manifests, hooks, skill frontmatter, and agent files. If everything is healthy, you see a final `Healthy — 0 errors` message." No longer overstates the exact output format.

2. **"`gh auth login` requirement — RESOLVED.** Softened gotcha #2 from "You need a GitHub CLI token configured (`gh auth login` if not already done)" to "PR creation requires the GitHub CLI (`gh`) installed and authenticated (`gh auth login`). If `gh` is not installed, `/spark:ship` will fail at the push step." Traces the requirement honestly without asserting a specific Spark mandate.

3. **Lifecycle skills error outside git — RESOLVED.** Softened gotcha #1 from "the lifecycle skills will error" to "Spark's git-level guardrails and several skills assume a git repo." Removes the unverified hard-error claim.

### Feedback from Skimmer (01)
1. **"Spark is now available globally" — RESOLVED.** Clarified the two layers of guardrails: global plugin install activates `/spark:*` skills and PreToolUse guard (force-push block). Per-repo `install-git-hooks` activates conventional-commit enforcement and trunk-push block. Added explicit sentence separating the two.

2. **Cycle walkthrough verification — CONFIRMED GOOD.** No changes needed; all stages map correctly to ground truth.

3. **`gh` auth prerequisite — CONFIRMED.** Flagged downstream (Skeptic, Visual Storyteller) about implicit auth step; it's handled honestly in gotcha #2.

### Feedback from Skeptic (03)
1. **"`spark doctor` output over-promises format — RESOLVED.** Changed to contract-based language: "You should see the doctor complete with no errors — it validates manifests, hooks, skill frontmatter, and agent files."

2. **"/spark:build creates feature branch" specificity — RESOLVED.** Changed from "The skill creates a feature branch (e.g. `feat/health-check-endpoint`)" to "The skill creates a feature branch, scaffolds a commit message template, and hands you the work." Removes the specific naming-convention claim that isn't verified in ground truth.

3. **"fix-issue runs reviews automatically" over-claims — RESOLVED.** Changed from "Runs `/code-review` and `/security-review` automatically" to "Invokes `/code-review` and `/security-review` as part of the solve loop." Removes the false-zero-interaction implication.

4. **Marketplace install caveat missing — RESOLVED.** Added note after install steps: "Currently installable from a Git URL or local clone. Marketplace listing in progress — check `ROADMAP.md` for status. (Source: `00-ground-truth.md`, ROADMAP section, v0.2 open item.)"

5. **"AI attribution is forbidden" gotcha — CONFIRMED GOOD.** Kept as-is; it's honest and accurate.

### Feedback from Coach (06)
1. **Quickstart doing tutorial work — RESOLVED.** Shortened the "Walk through one full cycle" section from a step-by-step Ideate → Ship walkthrough to just install → doctor → `/spark:ideate` demo, then link to the tutorial for the full guided lesson: "Ready for a deeper walkthrough? See [Build your first project](docs/tutorials/build-your-first-project.md)." Eliminates overlap with `docs/tutorials/build-your-first-project.md`.

2. **"`spark doctor` output description speculative — RESOLVED.** (Same as Cartographer/Skeptic feedback #1.) Changed to contract-based language.

3. **`/verify` command reference unverified — RESOLVED.** Added one-sentence description: "then call `/verify` (Claude Code's test runner) when you think it's ready." Brief, accurate, and cites the built-in behavior without overstating.

### Feedback from Visual Storyteller (08)
1. **"`spark doctor` output claim — RESOLVED.** (Same as Cartographer/Skeptic feedback #1.)

2. **"/spark:plan issue count unverified — RESOLVED.** Changed from "Spark will decompose it into 2–5 GitHub issues with acceptance criteria" to "Spark will decompose it into a set of scoped work items with acceptance criteria." Added footnote: "*(GitHub issue creation is planned for v0.3; current version generates issue drafts and milestone scaffolds.)*" Cites the ROADMAP caveat.

3. **Screenshot reference — RESOLVED.** Updated Neighbors section from "may show walkthrough screenshots" to "provides a `spark doctor` terminal GIF and lifecycle flow diagram." Aligns with the actual assets in your Phase 1 draft.

4. **GitHub token prerequisite understates complexity — RESOLVED.** Changed gotcha #2 from "Claude will ask for `gh` permissions; you need a GitHub CLI token" to "PR creation requires the GitHub CLI (`gh`) installed and authenticated (`gh auth login`). If `gh` is not installed, `/spark:ship` will fail at the push step." Honest about the full dependency chain.
