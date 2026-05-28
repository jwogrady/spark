# fork-init

**Feature ID:** FEAT-SPARK-FORK-INIT-001
**Namespace:** spark.skills.fork-init
**Bounded Context:** Spark project inception workflow
**Status:** Draft — documents workflow only; runtime command not yet implemented

---

## Purpose

`fork-init` guides you through turning a fresh Spark clone into a new downstream
project repo. Spark stays connected as an upstream remote so the downstream project
can pull engine improvements later.

---

## Mental Model

```
github.com/jwogrady/spark        ← upstream (Spark engine)
         │
         │  git clone → rename remote to upstream
         ▼
my-new-project/                  ← downstream (your project)
  remote: upstream → spark
  remote: origin   → your-org/my-new-project
         │
         │  spark init → commit → PR
         ▼
inception/my-new-project branch
```

- **Spark** is the upstream project-inceptor engine. Improvements to Spark tooling,
  skills, and templates belong here.
- **Your project** is the downstream initialized repo. Generated project artifacts,
  domain code, and project-specific configuration belong there.
- The downstream project can pull Spark engine updates at any time via:

  ```bash
  git fetch upstream
  git merge upstream/master --allow-unrelated-histories
  ```

  Review and resolve conflicts before merging. Not every Spark update will be
  appropriate for every downstream project.

---

## Before You Start — Gather These Values

The skill will ask for these if not provided upfront:

| Value | Description | Example |
|---|---|---|
| `PROJECT_NAME` | Directory and repo name | `my-new-project` |
| `GITHUB_OWNER` | GitHub user or org | `acme-corp` |
| `REPO_URL` | SSH or HTTPS remote URL | `git@github.com:acme-corp/my-new-project.git` |
| `DEFAULT_BRANCH` | Project default branch | `main` or `master` |

> SSH remote URLs are preferred (`git@github.com:...`). HTTPS (`https://github.com/...`)
> works too — use whichever matches your GitHub auth setup.

> **Prerequisite:** Create the empty GitHub repo for your project before running
> step 3. Do not initialize it with a README or `.gitignore` — start it empty.

---

## Workflow

### Step 1 — Clone Spark into a new project directory

```bash
git clone https://github.com/jwogrady/spark.git my-new-project
cd my-new-project
```

Confirm you are now inside the new directory before continuing:

```bash
pwd
# expected: .../my-new-project
git remote -v
# expected: origin  https://github.com/jwogrady/spark.git (fetch)
```

### Step 2 — Rename the Spark remote to `upstream`

```bash
git remote rename origin upstream
git remote -v
# expected:
# upstream  https://github.com/jwogrady/spark.git (fetch)
# upstream  https://github.com/jwogrady/spark.git (push)
```

### Step 3 — Add the new project repo as `origin`

> Make sure the GitHub repo exists and is empty before this step.
> If `origin` already exists, check with `git remote -v` before proceeding.
> Never overwrite an existing `origin` without removing it first intentionally.

```bash
git remote add origin git@github.com:OWNER/my-new-project.git
git remote -v
# expected:
# origin    git@github.com:OWNER/my-new-project.git (fetch)
# upstream  https://github.com/jwogrady/spark.git (fetch)
```

Replace `OWNER` and `my-new-project` with your values.

### Step 4 — Create an inception branch

```bash
git checkout -b inception/my-new-project
```

Use your actual project name, not the literal `my-new-project`.

### Step 5 — Run Spark inception

```bash
spark init
```

> **Note:** `spark init` is not yet implemented. This step is a placeholder.
> When implemented, it will scaffold project structure and configuration from
> Spark templates.

### Step 6 — Commit the generated project foundation

Review generated files before committing:

```bash
git status
git diff --staged
```

Then commit:

```bash
git add .
git commit -m "initialize project with spark"
```

Keep the commit small and reviewable. If `spark init` generates a large set of
files, consider splitting into logical groups (structure, config, docs).

### Step 7 — Push the inception branch

```bash
git push -u origin inception/my-new-project
```

### Step 8 — Open a pull request

Open a pull request from `inception/my-new-project` into your project's default
branch (`main` or `master`). Do this through the GitHub UI or CLI.

PR title suggestion:

```
initialize project with spark
```

Include in the PR body:
- What Spark version (commit SHA or tag) was used
- Any configuration choices made during `spark init`
- What the next steps are after merge

---

## Pulling Spark Updates Later

```bash
git fetch upstream
git log upstream/master --oneline -10   # review what changed
git merge upstream/master
```

Resolve any conflicts carefully. Spark engine changes may affect templates and
skills that your project has already customized. Review diffs before merging.

---

## Safety Guardrails

These rules apply when using or teaching this workflow:

- **Confirm directory first.** Before any destructive git command, verify `pwd`
  and `git remote -v` match expectations.
- **Never overwrite `origin` silently.** Check `git remote -v` before `git remote add origin`.
  If `origin` exists, stop and ask the user what to do.
- **Never force push.** Do not use `git push --force` or `git push -f`.
- **Never delete remotes automatically.** Removing a remote (`git remote remove`) is a
  user decision, not an automated one.
- **Never assume the GitHub repo exists.** Always remind the user to create the empty
  repo before adding the `origin` remote.
- **Never credit AI systems.** Do not add `Co-Authored-By` lines for AI tools.
  Do not mention Claude, ChatGPT, OpenAI, Anthropic, Copilot, or any AI system in
  commit messages, PRs, comments, docs, changelogs, or generated files unless the
  author explicitly requests it. Credit belongs to the author.
- **Keep commits small.** One logical change per commit. Write commit messages in
  imperative mood.

---

## Outputs This Skill Can Produce

Given user inputs, this skill can generate one of the following:

| Output Type | When to Use |
|---|---|
| **Guided shell sequence** | User wants copy-paste commands for their specific project |
| **Migration checklist** | User wants a step-by-step checklist to follow manually |
| **GitHub-ready issue** | User wants to track this setup as a GitHub issue |
| **Claude Code prompt** | User wants Claude Code to walk through the setup interactively |
| **Troubleshooting guide** | User hit an error and needs to diagnose it |

Ask the user which output they want if not specified.

---

## Troubleshooting

**`origin` already exists when I try to add it**

```bash
git remote -v      # confirm what origin points to
git remote remove origin   # only if you are sure it is safe to remove
git remote add origin git@github.com:OWNER/my-new-project.git
```

**Push rejected — remote has commits mine doesn't**

The empty GitHub repo was initialized with a README or other file. Either:
- Delete and recreate the repo empty, or
- Use `git pull origin main --allow-unrelated-histories` first, then push again.

Do not use `--force`.

**`spark init` command not found**

The `spark init` runtime is not yet implemented. Skip step 5 for now and manually
add your project scaffolding, then commit it.

**Merge conflict when pulling upstream Spark updates**

Review the conflicting files carefully. Upstream Spark changes may touch templates
or skills you have already customized. Resolve manually; do not blindly accept
either side.

---

## Non-Goals

- This skill does not implement `spark init` as a CLI command.
- This skill does not call GitHub APIs to create repos or open PRs.
- This skill does not manage remotes automatically.
- This skill does not enforce a specific project directory structure beyond what
  Spark templates provide.
