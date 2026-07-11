# How to connect a project to its services

> How-to — task-oriented.

Use this to give a project authenticated access to GitHub / Google Cloud / Vultr
/ Linode, with every secret stored in 1Password and nothing plaintext left on
disk. Recipes per service: [../skills/connect/references/recipes.md](../skills/connect/references/recipes.md).

## 1. Prepare (before any key touches disk)

Confirm `.gitignore` covers the transient files:

```gitignore
.env
.env.local
sa.json
```

## 2. Capture

Paste the raw provider keys into a temporary `.env`. This file is short-lived.

## 3. Ingest into 1Password (you confirm each write)

Invoke `/spark:connect`. For each key it will **show you the `op item create`
command and wait for your confirmation** before writing to your vault. Use a
per-project vault so this project's keys are independently revocable. It then
writes a committed `.env.tmpl` of `op://…` references.

## 4. Verify

For each service, the skill reads the key back from `op` (without printing it)
and runs one smoke-test (e.g. `gh api user`, or an HTTP 200 from the provider).

## 5. Shred

Only after every key verifies, securely delete the plaintext:

```bash
# via the connect skill, which runs the plugin's shred-env.sh; by hand:
shred -u -z .env   # or: scripts/shred-env.sh .env from this plugin's root
```

This overwrites and removes the file, then confirms it's gone. It refuses to
touch `*.tmpl` (those are references, meant to be kept).

## 6. Run with injected secrets (steady state)

```bash
op run --env-file=.env.tmpl -- <command>
```

Local dev uses `op signin`; CI uses `OP_SERVICE_ACCOUNT_TOKEN`.

**Done when** every needed service smoke-tests green, the repo holds only
`.env.tmpl`, and no plaintext secret remains on disk.
