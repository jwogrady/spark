# Persona 07 — Contributor

## Persona

I am the Contributor: a motivated developer who wants to extend Spark and needs
to know exactly where to start and what gates a contribution. My question is:
*"How do I add something new to Spark, and what does my work have to clear before
it lands?"*

## Neighbors

- **Upstream (I read):** `00-ground-truth.md`, `05-philosophy.md` (not yet
  present — drafted from ground truth), `06-diataxis.md` (not yet present —
  drafted from ground truth).
- **Downstream (read me):** Aggregators (10/11) and the Editor only. No direct
  neighbor to reconcile with.

## Draft

### Contributing to Spark

Spark is a Claude Code plugin. Contributing means adding to the plugin itself —
skills, agents, enforcement scripts, CLI subcommands, or docs — so that every
downstream project that installs it gets the improvement automatically. The
contribution path has four legs: scaffold, implement, validate, and open a PR on
a feature branch.

#### The canonical extension: authoring a skill

The most common contribution is a new skill. The lifecycle is mechanical:

1. **Scaffold the skill directory.**

   ```bash
   spark new-skill <your-skill-name>
   ```

   This creates `skills/<your-skill-name>/SKILL.md` with the required frontmatter
   stub. The description field is the only thing Claude reads when deciding which
   skill to invoke — write it as a concrete trigger sentence:
   *"Use when [specific context]."* Keep SKILL.md under 100 lines; split to
   `REFERENCE.md` / `EXAMPLES.md` / `scripts/` when you need more.

2. **Implement the skill.** Required frontmatter: `name:` and `description:`.
   Optional layout:

   ```
   skills/<name>/
   ├── SKILL.md        # required — instructions + frontmatter
   ├── REFERENCE.md    # optional — extended docs when SKILL.md would exceed 100 lines
   ├── EXAMPLES.md     # optional — worked examples
   └── scripts/        # optional — deterministic helpers (validation, formatting)
   ```

   Skills must be self-contained. No cross-skill imports at runtime.

3. **Validate before pushing.**

   ```bash
   spark doctor
   bash -n hooks/guard-bash.sh          # or any shell script you touched
   ```

   `spark doctor` checks plugin manifests, hooks JSON, guard-script
   executability, every skill's `name:`/`description:` frontmatter, and
   every agent frontmatter. It exits non-zero on any error, so use it as a
   pre-push gate. JSON validation degrades gracefully when `jq`/`python3` are
   absent — it skips rather than false-fails.

4. **Install Spark's git hooks in your local clone** (once, if you haven't):

   ```bash
   spark install-git-hooks
   ```

   This copies `scripts/hooks/commit-msg` and `scripts/hooks/pre-commit` into
   `.git/hooks/`. The `commit-msg` hook enforces conventional type prefixes
   (`feat|fix|docs|chore|refactor|test`), subject ≤ 72 characters, no trailing
   period, and blocks AI-attribution trailers. The `pre-commit` hook blocks
   direct commits to `master`/`main`.

5. **Work on a feature branch, never `master`.** The PreToolUse Bash guard
   (`hooks/guard-bash.sh`) actively blocks `git push --force`/`-f` and any push
   to `master`/`main` — these are mechanical stops, not advisory notes.

6. **Open a PR.** One concern per PR. Use the `.github/PULL_REQUEST_TEMPLATE.md`
   and the `skill.yml` issue template when your PR implements a new skill.

#### Adding agents (docit / codify crews)

Agents live under `agents/<crew>/`. Each `.md` file must carry `name:` and
`description:` frontmatter — `spark doctor` validates all of them. Follow the
pattern in `agents/docit/` (13 personas) or `agents/codify/` (6 agents) for
structure and the orchestrating SKILL.md for how the orchestrator dispatches them.

#### Extending the CLI

New subcommands go in `bin/spark` as `cmd_<subcommand>()` functions and are
wired in the `case` block at the bottom. All scripts use `set -euo pipefail`.
Syntax-check with `bash -n bin/spark` before pushing.

#### Contributing docs — the four-mode rule

All doc contributions must land in exactly one of four mode directories under
`docs/`:

- `tutorials/` — learning-oriented, guides a reader through a concrete task by
  doing it.
- `how-to/` — task-oriented, answers "how do I achieve X?" with steps, no
  teaching detour.
- `reference/` — information-oriented, factual and structured for lookup.
- `explanation/` — understanding-oriented, explores concepts, rationale, and
  trade-offs.

Mixing modes in a single file is a quality failure. Before adding or editing a
doc, read the Diátaxis plan (`06-diataxis.md`, or its eventual published form in
`docs/`) to understand which mode applies and what rules govern it. When a
`docs/how-to/add-a-doc.md` guide exists, follow it; until then the mode
descriptions above are the gate.

#### Contribution standards in one list

These standards are enforced mechanically (hooks, `spark doctor`) and explained
in `docs/PHILOSOPHY.md`. If you want to understand *why* the rules are what they
are, start there.

- Skills: valid `name:` + `description:` frontmatter; SKILL.md ≤ 100 lines or
  split to companion files (rule sourced from `CLAUDE.md §Skill Authoring`);
  self-contained; tested in a real project before merging.
- Scripts: POSIX-friendly Bash; `set -euo pipefail`; zero runtime dependencies;
  graceful degradation when `jq`/`python3` are absent; syntax-check passes.
- Commits: conventional type prefix; subject ≤ 72 chars; no trailing period;
  no AI-attribution trailers. Attribution field: `jwogrady` (see note below).
- Branches: one concern per branch; never commit to `master`/`main` directly.
- Validation: `spark doctor` returns 0; shell scripts pass `bash -n`.
- PRs: one concern; use the repo's PR and issue templates.

**Attribution policy:** This is a single-author project; attribution in commit
metadata, manifests, and author fields is always `jwogrady`. If that changes as
the project accepts external contributions, this policy will be documented here.

#### Your first contribution

Not sure where to start? Three good entry points:

1. **Write a skill for something you do repeatedly.** Use `spark new-skill` to
   scaffold. A dedicated how-to guide for skill authoring is a known gap
   (`docs/how-to/write-a-skill.md` does not yet exist); follow the patterns in
   `skills/write-a-skill/SKILL.md` until it does.
2. **Fix a known gap.** The `ROADMAP.md` has unchecked items; so does the
   accuracy-flags section of `00-ground-truth.md` (e.g. the `list-skills`
   omission in the README "What's in the box" list).
3. **Improve a doc.** The Diátaxis tree (`docs/`) uses tutorial / how-to /
   reference / explanation categories — read the Diátaxis plan before writing to
   ensure your contribution lands in the right mode. See "Contributing docs —
   the four-mode rule" above.

## Claims & citations

| Claim | Source in 00-ground-truth.md or file |
|---|---|
| `spark new-skill <name>` scaffolds a skill | ground-truth §"The `spark` CLI" — `cmd_new_skill` function in `bin/spark` |
| Required frontmatter: `name:` + `description:` | ground-truth §"Lifecycle skills (16 total…)" and §CLI `cmd_doctor` check |
| `spark doctor` validates manifests, hooks, skill/agent frontmatter, exits non-zero on error | ground-truth §CLI `cmd_doctor` function in `bin/spark` |
| JSON validation degrades gracefully without `jq`/`python3` | ground-truth §CLI ("degrades gracefully when `jq`/`python3` are absent"); `bin/spark` `check_json` function |
| `spark install-git-hooks` copies commit-msg + pre-commit | ground-truth §CLI `cmd_install_git_hooks` function in `bin/spark` |
| `commit-msg` enforces type prefix, ≤72 chars, no trailing period, blocks AI-attribution | ground-truth §"Enforcement" — `commit-msg` git hook; `scripts/hooks/commit-msg` |
| `pre-commit` blocks direct commits to master/main | ground-truth §"Enforcement" — `pre-commit` git hook; `scripts/hooks/pre-commit` |
| PreToolUse guard blocks force-push and trunk push | ground-truth §"Enforcement" — `hooks/guard-bash.sh` (force-push logic and trunk check) |
| 16 skills, each with valid frontmatter | ground-truth §"Lifecycle skills (16 total…)" |
| 13 docit agents under agents/docit/, 6 codify agents under agents/codify/ | ground-truth §"Review / knowledge skills" — docit + codify entries |
| Skills must be self-contained, no cross-skill imports | `CLAUDE.md` §"Skill Authoring" |
| SKILL.md ≤ 100 lines or split; companion files optional | `CLAUDE.md` §"Skill Authoring" (authoritative rule; `skills/write-a-skill/SKILL.md` illustrates) |
| `list-skills` omission in README | ground-truth §"Accuracy flags" — "README…omits `list-skills`" |
| Work on feature branch, never master; one PR per concern | `CLAUDE.md` §"Development Workflow" |
| Diátaxis four-mode tree exists under `docs/` | ground-truth §"Docs (Diátaxis, under `docs/`)" |
| No `docs/how-to/write-a-skill.md` — known gap | ground-truth §Docs (file not listed); `06-diataxis.md` §How-to gaps |
| Attribution is always `jwogrady` | ground-truth §Plugin packaging (author field); `CLAUDE.md` §Attribution |

## Cross-eval feedback

### From 00 (Cartographer)

**Item 1 — "6 codify agents" claim accuracy.** Cartographer confirmed the count
is correct (`agents/codify/` has exactly `00-intake..05-editor`). No fix needed;
flag noted.
> RESOLVED: count was already correct; no change required.

**Item 2 — Line-number citations are brittle.** Claims table cited `bin/spark`
by line ranges (140-165, 34-138, 37-45, 185-200) and `guard-bash.sh` lines
47-58. Ground truth cites functions by name, not line numbers, because lines
drift with edits.
> RESOLVED: replaced all line-number citations with function names
> (`cmd_new_skill`, `cmd_doctor`, `check_json`, `cmd_install_git_hooks`) and
> a plain file reference for `guard-bash.sh`.

---

### From 05 (Believer)

**Issue 1 — Standards list had no rationale link.** The contribution standards
read as a compliance checklist with no pointer to the doctrine behind them.
> RESOLVED: added an intro sentence before the standards list: "These standards
> are enforced mechanically (hooks, `spark doctor`) and explained in
> `docs/PHILOSOPHY.md`. If you want to understand why the rules are what they
> are, start there."

**Issue 2 — "Your first contribution" sent contributors to a SKILL.md as if it
were a human how-to.** SKILL.md files are AI instruction sets; routing humans
there without caveat is misleading.
> RESOLVED: reworded bullet 1 to flag the gap honestly: "a how-to guide for
> skill authoring is a known gap (`docs/how-to/write-a-skill.md` does not yet
> exist); follow the patterns in `skills/write-a-skill/SKILL.md` until it
> does."

**Issue 3 — Attribution standard was ambiguous for external contributors.** The
line "Attribution field: `jwogrady`" is correct but implies a policy that needs
to be stated explicitly for anyone who is not `jwogrady`.
> RESOLVED: added an "Attribution policy" callout after the standards list
> stating this is a single-author project and the policy will be documented
> here if it changes.

---

### From 06 (Coach)

**Issue 1 — "Improve a doc" entry point lacked a Diátaxis pointer.** Bullet 3
said "pick the right quadrant" but gave contributors nowhere to learn which
quadrant applies.
> RESOLVED: added a "read the Diátaxis plan before writing" directive to
> bullet 3, and a forward-reference to the four-mode rule section above.

**Issue 2 — `SKILL.md ≤ 100 lines` citation chain stopped at a secondary
source.** The rule appeared cited to `skills/write-a-skill/SKILL.md`, which is
a peer artifact, not policy. The authoritative source is `CLAUDE.md §Skill
Authoring`.
> RESOLVED: updated the standards list and the claims table to cite
> `CLAUDE.md §Skill Authoring` as the primary source; `write-a-skill/SKILL.md`
> is now noted only as an illustration.

**Issue 3 — No doc contribution path with four-mode constraint.** The guide
explained how to add a skill, agent, and CLI command but only gestures at doc
contributions without stating the mode constraint.
> RESOLVED: added a dedicated "Contributing docs — the four-mode rule" section
> that names all four modes, explains each in one sentence, states that mode-
> mixing is a quality failure, and points to the Diátaxis plan.
