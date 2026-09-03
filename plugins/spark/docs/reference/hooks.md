# Reference — hooks

> Reference — information-oriented.

Spark enforces its guardrails through three independent doors — the
Claude-driven path, the human-driven local path, and the remote itself — each
needing its own gate. This page documents the two local doors the plugin
carries (the PreToolUse guard and the git hooks). The third door is a GitHub
ruleset on the trunk: Spark ships the policy
(`settings/github-ruleset-trunk.json`) and `spark doctor --requirements`
inspects and reports drift, but applying it is always an explicit human act —
see [../explanation/enforcement-model.md](../explanation/enforcement-model.md).

## Plugin hook (Claude-driven path)

Defined in `hooks/hooks.json`, fires on Claude Code's `PreToolUse` event for the
`Bash` tool, running `hooks/guard-bash.sh`.

| Blocks | Condition | Allows instead |
|---|---|---|
| Force-push | `--force`, `-f` (also inside short-option bundles like `-fu`), or a `+refspec` | `--force-with-lease` |
| Push to trunk | any push whose refspec *destination* resolves to `master`/`main` — bare names, `HEAD:main`, `feat:master`, `refs/heads/…` forms, and deletes (`:main`) — **except when the push's remote is a wiki** (see below) | Push a feature branch |
| Hand-cut release | `git tag <name>` (creation forms, including `-a`/`-s`/`-m`), `gh release create`, a push refspec targeting `refs/tags/…` (create, update, or delete), `git push --tags`/`--follow-tags`, or `git update-ref refs/tags/…` — **only when Release Please is configured** (`release-please-config.json` or a `release-please` workflow at the repo root). Non-creating local tag forms (`git tag`, `-l`, `-v`, `-d`) and non-creating `gh release` subcommands stay allowed | Merge the Release Please release PR — that human merge is the release act. Repos without the marker keep the ship skill's manual fallback |

The guard tokenizes the command rather than substring-matching, so it sees
through leading git options (`git -C <path> push`, `-c k=v`, `--git-dir …`),
compound commands (`… && git push …`), and full refspecs. Push options that
take a value (`-o`, `--push-option`, `--repo`, `--receive-pack`, `--exec`)
are skipped so their arguments are not misread as refspecs.

**Quoted text and heredoc bodies are data, not commands.** Writing about a push —
`echo "do not git push origin master"`, `grep -r "git push origin master" docs/`,
a heredoc that documents the rule — runs no push and is not refused. The same
words **unquoted** are a real invocation and still are.

There is one deliberate exception, and it is the bypass-free direction: **when the
command invokes a shell**, quoted text and heredoc bodies may themselves be
commands — `sh -c 'git push origin master'`, `sh <<EOF … EOF` — so nothing is
treated as data and the whole string is scanned. That can over-block a shell
invocation that merely quotes the words, and the refusal says so rather than
leaving the reader to guess:

```text
Spark guard: pushing to master/main is blocked. … (this command invokes a shell,
so quoted text and heredoc bodies are read as commands)
```

An unquoted `git push` still refuses whatever precedes it, so `xargs git push
origin master`, `find … -exec git push …`, `env FOO=1 git push …` and a leading
assignment are all still blocked. The rule narrows *where* the guard looks, never
*what* it forbids.

One destination is exempt from the trunk rule: a **GitHub wiki** repository
(`<owner>/<repo>.wiki.git`). A wiki has exactly one branch, renders only from
`master`, and has no pull request mechanism, so "push a feature branch and open
a PR" is not a remedy that can be performed there — the rule could only ever be
bypassed. The guard recognizes a wiki from a literal URL or path; a bare remote
**name** is always resolved (`git remote get-url`, in the `-C` repository when
one is given) rather than believed, so a remote merely *named* `x.wiki` while
pointing at the trunk repo does not relax anything. The exemption is keyed on
the push's **remote** — git's first positional after `push` — and on nothing
else, so a wiki-looking string elsewhere in the command line cannot relax a
trunk push. Force-push and the release rules are unaffected
on a wiki.

The enforcement boundary, precisely: the guard analyzes the command *text*.
It cannot know the current branch, so a bare `git push` (no refspec) while
standing on trunk is allowed here — that push is caught by the `pre-commit`
door and branch discipline. Git aliases and commands assembled at runtime
(`$(…)`) are likewise out of scope, as are raw API paths (`gh api …/releases`)
and refs fed over stdin (`git update-ref --stdin`).
Ambiguity resolves toward blocking: a quoted argument that splits oddly or a
remote literally named `main` can over-block, never under-block.

The release rule is deliberately conditional: it fires only where a
`release-please-config.json` or a `release-please` workflow marks tags and
Releases as Release Please's (the same two markers the ship skill names,
resolved from the repo root via `git rev-parse`, so it holds from any
subdirectory). Everywhere else the ship skill's documented manual fallback —
tag and Release with explicit human go-ahead — remains available.

Protocol: the guard reads the tool call as JSON on stdin, extracts
`.tool_input.command`, and exits `2` to block (feeding the reason back to
Claude) or `0` to allow. It only ever *blocks* on a match — it never
auto-approves — so it fails safe if JSON parsing is unavailable. When
`SPARK_AUDIT_LOG` points at a writable file, every block is appended there.

Regression tests: `tests/test-guard-bash.sh` (run `bash tests/run.sh`).

## Session brief (SessionStart)

Also defined in `hooks/hooks.json`: on Claude Code's `SessionStart` event the
plugin runs `bin/spark brief --short`. This is not an enforcement door — it
blocks nothing. It prints at most three plain-text lines into the session
context: branch and working-tree state (orient), the lifecycle position
derived from repo shape plus the dated `next_action` recorded in
`.spark/state.json` (locate), and the
resolved-preferences headline (load) — the carry-in and carry-forward motions
applied at session entry. The entry has no matcher, so the brief also re-fires
when a session resumes, clears, or compacts — exactly the moments context was
lost.

Outside a git repo the command prints nothing and exits `0`, so sessions in
non-project directories start clean. The full sectioned briefing is available
on demand as `spark brief` (see [cli.md](cli.md)).

## Git hooks (human-driven path)

Installed into a repo's `.git/hooks/` by `spark install-git-hooks`. Source lives
in `scripts/hooks/`.

### `commit-msg`

Rejects a commit when its message:

- contains AI attribution (e.g. `Co-Authored-By: Claude`, "generated by AI")
- lacks a conventional type prefix (`feat|fix|docs|chore|refactor|test`)
- has a subject longer than 72 characters
- has a subject ending in a period

**Governance provenance.** On a repository governed by installed Spark, the hook
also stamps one canonical trailer recording *which released governor produced the
work* — provenance, never authorship, and never an AI/worker credit:

```text
Spark-Governed-By: vX.Y.Z
Spark-Run: <run-id>        # only when SPARK_RUN_ID is set; never invented
```

The version is the **installed governor's** own `spark version` (resolved via the
`spark.governorBin` git config that `install-git-hooks` records, then
`SPARK_ROOT`, then `spark` on `PATH`), **not** the target repo's own — possibly
unreleased — manifest. So a checkout being developed under an earlier installed
governor is stamped with that governor. The trailer is added once and de-duped on
amend/re-run; a supplied `Spark-Governed-By` that disagrees with the resolved
governor **fails closed** rather than recording false provenance. A repository
that resolves no governor (not Spark-governed) is left untouched — attribution is
recorded, never fabricated. This is orthogonal to the AI-attribution ban above and
never changes the Git author or committer. See the author/worker/governor
distinction in [enforcement-model.md](../explanation/enforcement-model.md).

### `pre-commit`

Rejects a commit made directly on `master` or `main`.

## Relationship to settings

A plugin cannot bundle a full `settings.json`. The PreToolUse guard ships *in*
the plugin; the permission baselines ship under `settings/` and are applied
separately by `spark apply-permissions` (see
[../how-to/get-started.md](../how-to/get-started.md)).

## The permission ↔ guard trust boundary

The `delivery` preset allows `Bash(git push:*)` — deliberately broader than
the rules it wants enforced. That is not an oversight; it is a two-layer
design:

- **Permissions** decide what Claude may attempt without a prompt. Rules are
  prefix-shaped, so no permission rule can express "push, but never to trunk
  and never forced."
- **The guard** decides what actually runs. Every `Bash` call passes through
  `guard-bash.sh` before execution, which blocks exactly that subset —
  through leading git options, full refspecs, bundled short options,
  per-refspec forces, and compound commands (the table above).

So the broad allow is safe *only because* the guard is load-bearing, and the
guard's behavior is pinned by its regression suite
(`tests/test-guard-bash.sh`) — the one authority that proves what it blocks. A
push-capable preset must never ship without that suite green, and the GitHub
ruleset (the third door) backstops whatever a local bypass could still reach.

The `conservative` preset does not rely on the guard at all: nothing
push-capable is pre-approved, and every mutating command falls back to Claude
Code's per-command permission prompt.

What each tier grants, and how a tier is selected, belongs to the
`apply-permissions` section of [cli.md](cli.md); this page covers only why the
broad `delivery` allow is safe.

## See also

- Why the doors exist — the enforcement rationale:
  [../explanation/enforcement-model.md](../explanation/enforcement-model.md)
- The local-doors decision (developer-only):
  [ADR-0003](https://github.com/jwogrady/spark/blob/master/docs/adr/0003-zero-dependency-bash-and-enforcement-hooks.md);
  the delivery/third-door decision:
  [ADR-0027](https://github.com/jwogrady/spark/blob/master/docs/adr/0027-delivery-model.md)
- Why the hand-cut-release guard exists and how the boundary plays out: [../explanation/release-ownership.md](../explanation/release-ownership.md)
