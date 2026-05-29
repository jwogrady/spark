---
name: connect
description: Bootstrap a project's external service connectivity and secrets — capture API keys, load them into 1Password, verify each connection, and shred the plaintext. Use when setting up GitHub/Google Cloud/Vultr/Linode access, wiring API keys, configuring 1Password (op), or connecting a new project to its providers.
---

# connect — connectivity & secrets bootstrap

`connect` stands up a project's access to external services (GitHub, Google
Cloud, Vultr, Linode, …) with every credential sourced from **1Password** via the
`op` CLI. The repo only ever holds references (`op://…`), never values. 1Password
holds truth; secrets are injected at runtime and stay revocable.

Service-specific connect + smoke-test recipes live in
[references/recipes.md](references/recipes.md).

## The secret lifecycle: capture → ingest → shred → inject

1. **Capture.** Make sure `.gitignore` covers `.env`, `.env.local`, and
   `sa.json` *first*. Then have the developer paste the raw provider keys into a
   transient `.env`. This file is temporary — it exists only until step 3.
2. **Ingest.** Read `.env` and, for each key, **propose the exact
   `op item create` command and wait for the developer to confirm** before
   anything is written to their vault (see Guardrails). Create one item per
   service. Then write/update a committed **`.env.tmpl`** holding only the
   `op://<vault>/<item>/<field>` references.
3. **Shred.** Only after each key is confirmed readable from `op`
   (`op read op://…` succeeds) **and** its smoke-test passes, securely delete the
   raw file: `spark shred-env .env`. Verify it's gone.
4. **Inject (steady state).** Run the app with secrets injected from 1Password,
   never from a plaintext file:
   ```bash
   op run --env-file=.env.tmpl -- <command>
   ```

## Key policy: one set of keys per project

Encourage **per-project keys** — give each project its own credentials (its own
1Password vault, or its own item set), so a project's keys can be rotated or
revoked without affecting anything else. If a key genuinely must be shared across
projects, make that a conscious, documented choice — never the silent default.

## Auth modes (recipes detect which is present)

- **Local dev:** interactive `op signin` against the desktop app.
- **CI / non-interactive:** `OP_SERVICE_ACCOUNT_TOKEN` in the environment.

## Guardrails — non-negotiable

- **Never echo a secret value.** Not in logs, not in smoke-test output. Smoke
  tests check status (`gh api user`, an HTTP 200), never print the token.
- **Propose, don't auto-write.** Writing to the developer's personal 1Password is
  hard to reverse. Always show the `op item create` command and get explicit
  confirmation before running it.
- **Shred only after verify.** Never delete the raw `.env` until every key reads
  back from `op` and its smoke-test passes. Use `spark shred-env` (secure delete +
  verification), never a bare `rm`.
- **Never commit secrets.** Confirm `.gitignore` covers `.env*`/`sa.json` before
  capture. Only `.env.tmpl` (references) is committed.

## Outputs

- A committed `.env.tmpl` of `op://` references.
- One 1Password item per connected service (created with your confirmation).
- A report of which connections are live (smoke-tests passed), with no secret
  values shown.

## Fits the lifecycle

`connect` is project setup — run it alongside runtime bootstrap, before
[`ideate`](../ideate/SKILL.md). Once connections are live and the plaintext is
shredded, you're ready to build.
