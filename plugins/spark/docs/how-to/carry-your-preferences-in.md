# How to carry your preferences in

> How-to — task-oriented.

Do this once, right after [installing Spark](install.md). Spark's promise is
your standards **loaded once, carried everywhere** — this is the loading. The
standard bag has two halves: your engineering preferences and your permission
baseline. Declare them here, and every project after this starts from *your*
standard instead of asking again.

## 1. Review the shipped defaults

Spark works with zero setup because a full set of defaults ships inside the
plugin — [`preferences/defaults.json`](../../preferences/defaults.json), the
machine form of the
[engineering-preferences standard](../reference/engineering-preferences.md)
(the prose carries the *why*; the JSON carries *what to apply*). See what you
would get as-is:

```bash
spark preferences
```

Each row shows a key, its resolved value, and the tier it came from in
brackets: `default` (shipped with the plugin), `operator` (yours), or
`project` (a committed per-repo exception). On a fresh install every key
reads `default`.

## 2. Override what isn't yours

The defaults are Spark's opinions (Python + `uv`, Release Please, GitHub
Actions). Where yours differ, say so once — in your operator override file,
which lives with you, not with any repo:

```bash
mkdir -p ~/.config/spark
$EDITOR ~/.config/spark/preferences.json
```

(Spark honors `$XDG_CONFIG_HOME` if you point your config elsewhere.) Flat
JSON, string values, only the keys you are changing — key names are exactly
those in `defaults.json`, so copy from there:

```json
{
  "stack.default": "typescript-bun"
}
```

Run `spark preferences` again: overridden keys now show `operator` as their
source, and every key you left out keeps its shipped default. You never fork
the whole bag.

## 3. Apply the permission baseline

The second half of the bag is what Claude may do without asking. Spark ships a
conservative allowlist as a versioned artifact
([`settings/permission-baseline.json`](../../settings/permission-baseline.json));
apply it to a project with:

```bash
spark apply-permissions
```

To carry the same allowlist into *every* project, merge the baseline into
`~/.claude/settings.json` instead. Flags, merge rules, and what the baseline
deliberately excludes are covered in
[install.md](install.md#apply-the-permission-baseline-optional).

## 4. Enter a project

The bag is packed. Carrying it into a repo is always an explicit motion —
nothing copies itself silently:

- **New project** — `/spark:bootstrap` resolves all three tiers at
  generation, so the repo conforms to your standard from commit one.
- **Existing repo** — run `spark preferences --apply` from inside it. The
  apply is create-only: what the repo already has is kept and reported, never
  overwritten (`+ created`, `= exists, kept`, `! needs a manual decision`).

When one project must deviate ("this one is TypeScript because it is a
frontend"), record only the exception in that repo's committed
`.spark/preferences.json` — the deviation stays visible and reviewable instead
of tribal.

**Done when** `spark preferences` shows your values sourced from `operator`,
the permission baseline is applied where you work, and a new or existing
project picks up your standard without you restating it. From here, run the
lifecycle — start with the
[tutorial](../tutorials/build-your-first-project.md) or go straight to
[ideate](ideate.md).
