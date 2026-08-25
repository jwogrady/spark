# How to get started with Spark

> How-to — task-oriented.

Do this once. Spark's promise is your standards **loaded once, carried
everywhere** — this is the loading. The normal path is two commands and then
the lifecycle:

```text
install Spark  →  /spark:onboard  →  /spark:ideate
```

**`/spark:onboard` is the one first-run command.** It sequences the whole
first run as a narrative — orient the repo, choose a setup profile, seed
hooks + permissions + the standards docs, report GitHub-side enforcement when
it can, and close with a brief of what was created, kept, and still open —
stopping at each human decision rather than guessing. You do not need to learn
`orient`, `setup`, `profiles`, `preferences`, or `brief` first; onboard
composes them, and every decision still stops for you. The rest of this guide
walks the same ground by hand for when you want the granular verbs.

The flow always opens with `spark orient` — it classifies the repo as **new**
(safe to scaffold), **existing** (discover and adopt create-only, never scaffold
over), or **ambiguous** (it asks rather than guess). This guide follows the
new-project path; orient keeps you honest about which path you are on before
anything is written. See [cli.md](../reference/cli.md#spark-orient---set-newexisting)
for the full breakdown.

**Prefer to follow a full worked example?** Take the tutorial that matches your
classification — each runs the whole first run start to finish against real
output:

- Classified **new** → [scaffold a new project](../tutorials/scaffold-a-new-project.md).
- Classified **existing** → [adopt Spark in an existing repository](../tutorials/adopt-an-existing-repo.md).

Before starting, check the machine meets the
[supported-environment contract](../reference/compatibility.md) — or just run
`spark doctor --requirements` after step 1 and follow its remediation lines.
And before arming a repo, `spark profiles` shows the available setup profiles
— pick one with `spark setup --profile <name>` when the shipped Python + uv
default isn't the project's stack.

## 1. Install the plugin

Point `/plugin marketplace add` at the Spark repo — the repo carries its own
`marketplace.json` — then install the core plugin from it. In Claude Code:

```text
/plugin marketplace add jwogrady/spark
/plugin install spark
```

The shorthand resolves to the repo's Git URL; the explicit equivalent is
`/plugin marketplace add https://github.com/jwogrady/spark.git`. A local clone
works the same way: `/plugin marketplace add ~/src/spark`.

After install, the nine core skills are available everywhere
(`/spark:ideate` … `/spark:ship`, `/spark:onboard`, `/spark:bootstrap`,
`/spark:knowledge`, `/spark:agents-md`) and the `spark` CLI is on your `$PATH`.
Verify:

```bash
spark doctor
```

The same marketplace also carries the companion plugins — `spark-audit`,
`spark-connect`, and `spark-docs` — each installable with
`/plugin install <name>` when you need it.

This whole path is verified end to end from a clean environment — including
companion install, marketplace update, and a real skill invocation — by
`tests/e2e-marketplace-install.sh` in the Spark repo, which doubles as the
release-readiness check.

### If the install misbehaves

- **`marketplace add` fails** — it clones the repo, so it needs network and
  GitHub access (an SSH key, or use the HTTPS form above). Retry with the
  explicit URL.
- **Plugins or skills look stale or missing** — refresh the marketplace and
  reinstall: `/plugin marketplace update spark`, then `/plugin install spark`
  again (also available headlessly: `claude plugin marketplace update spark`).
- **Start over cleanly** — remove and re-add:
  `/plugin marketplace remove spark`, then `/plugin marketplace add
  jwogrady/spark` and reinstall the plugins you use.
- **`spark` not on `$PATH`** — the CLI rides the plugin; confirm the plugin is
  enabled (`/plugin` → installed list, or `claude plugin list`) and start a
  new session.

## 2. Review the defaults, override what isn't yours

Spark works with zero setup because a full set of defaults ships inside the
plugin — [`preferences/defaults.json`](../../preferences/defaults.json), the
machine form of the
[engineering-preferences standard](../reference/engineering-preferences.md).
See what you would get as-is:

```bash
spark preferences
```

Each row shows a key, its resolved value, and the tier it came from:
`default` (shipped), `operator` (yours), or `project` (a committed per-repo
exception). Where Spark's opinions (Python + `uv`, Release Please, GitHub
Actions) differ from yours, say so once — in your operator override file,
which lives with you, not with any repo:

```bash
mkdir -p ~/.config/spark
$EDITOR ~/.config/spark/preferences.json
```

Flat JSON, string values, only the keys you are changing — key names are
exactly those in `defaults.json`:

```json
{
  "stack.default": "typescript-bun"
}
```

Run `spark preferences` again: overridden keys now show `operator`, and every
key you left out keeps its shipped default. You never fork the whole bag.
(Spark honors `$XDG_CONFIG_HOME` if you point your config elsewhere.)

## 3. Arm a repo: `spark setup`

Carrying your standard into a repo is always an explicit motion — nothing
copies itself silently. The guided `/spark:onboard` flow runs this step for you
(and orients + briefs around it); the raw verb below is what it calls. From
inside the repo:

```bash
spark setup
```

One idempotent run does the whole carry-in:

- **Git hooks** — `commit-msg` and `pre-commit` enforce the commit rules and
  block direct commits to trunk. Existing non-Spark hooks are left untouched.
- **Permission baseline** — the default `delivery` preset
  ([`settings/permission-baseline.json`](../../settings/permission-baseline.json))
  is merged into `.claude/settings.json` after you confirm; `--yes` skips the
  prompt. (`delivery` is the default trust tier; the separate `conservative`
  preset is the read-only/minimal-mutation tier — `spark apply-permissions
  --preset conservative`.)
- **Resolved standard** — your three-tier preferences materialize as project
  files, create-only: what the repo already has is kept and reported
  (`+ created`, `= exists, kept`, `! needs a manual decision`), never
  overwritten. This includes two repo-root docs — `CONVENTIONS.md` and
  `ENGINEERING-STANDARDS.md` — your project's editable working contract.

**Changing your conventions and standards after setup** happens right in those
two root docs: edit `CONVENTIONS.md` and `ENGINEERING-STANDARDS.md` to match how
this repository actually works. They are prose you own — Spark never overwrites
them. A line marked `<!-- spark:pref key=value -->` mirrors a machine fact in
`.spark/preferences.json`; to change automation, change the preference too, not
just the prose. See
[reference/project-standards.md](../reference/project-standards.md).

A second run reports everything as already present. Starting a brand-new
project instead? `/spark:bootstrap` scaffolds the runtime and ends by running
`spark setup` for you — see [bootstrap.md](bootstrap.md).

When one project must deviate ("this one is TypeScript because it is a
frontend"), record only the exception in that repo's committed
`.spark/preferences.json` — the deviation stays visible and reviewable instead
of tribal.

## 4. Run the lifecycle

The repo is armed. Take an idea through the five stages:

```text
/spark:ideate → /spark:plan → /spark:codify → /spark:validate → /spark:ship
```

**Done when** `spark preferences` shows your values sourced from `operator`,
`spark setup` reports the repo armed, and `spark doctor` is healthy. Start with
the [tutorial](../tutorials/build-your-first-project.md) or go straight to
[ideate](ideate.md).

---

## Afterward: the granular verbs

`spark setup` fronts three verbs you can also run on their own:

- `spark install-git-hooks` — just the git hooks.
- `spark apply-permissions` — just the permission baseline. Existing rules are
  never changed or removed, so re-running is a no-op once every rule is
  present. To carry the allowlist across every project, merge the same
  baseline into `~/.claude/settings.json` instead. The merge behaviour, the
  two trust tiers, and how a tier resolves are in the `apply-permissions`
  section of [cli.md](../reference/cli.md).
- `spark preferences --apply` — just the resolved standard.

The default `delivery` baseline is deliberately narrow: read-only git
inspection, commits and branch pushes (the PreToolUse guard still blocks
force-pushes and pushes to trunk), read-only `gh` queries plus `gh pr create`,
and the `spark` setup verbs. Nothing destructive — no `rm`, no `git reset`, no
`gh pr merge`, no releases. The stricter `conservative` preset drops even the
mutating subset to a read-only tier.

Two housekeeping notes:

- **Published-marketplace install** — the Git-URL marketplace path above is
  validated end to end (`tests/e2e-marketplace-install.sh`, run by hand as the
  release-readiness check). A one-click install from a *published marketplace
  listing* — a distribution channel beyond the Git URL — is a separate,
  not-yet-validated path; until one exists, the Git URL or a local clone is
  the supported install.
- **Developing Spark itself** — test changes without publishing:
  `claude --plugin-dir /path/to/spark`, then `/reload-plugins` to pick up
  edits.
